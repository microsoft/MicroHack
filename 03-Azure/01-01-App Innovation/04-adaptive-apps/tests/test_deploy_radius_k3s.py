"""Offline K3s Radius setup tests with stateful CLI mocks."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which("bash")
MOCK = r"""#!/usr/bin/env bash
set -euo pipefail
command="${0##*/}"
printf '%s %s\n' "$command" "$*" >> commands.log
if [[ -n "${FAIL_COMMAND:-}" && "$command $*" == "$FAIL_COMMAND"* ]]; then
  echo "Injected command failure" >&2
  exit 17
fi
arg() {
  local name="$1"
  shift
  while (($#)); do
    if [[ "$1" == "$name" ]]; then printf '%s' "$2"; return; fi
    shift
  done
  echo "Missing argument: $name" >&2
  exit 19
}
if [[ "$command" == kubectl ]]; then
  case "$1 ${2:-}" in
    "config current-context") printf '%s\n' "${CURRENT_CONTEXT:-k3s-azure-vm}" ;;
    "get namespace") [[ ! -f installed ]] || echo namespace/radius-system ;;
    "--request-timeout=15s get") echo ok ;;
  esac
  exit 0
fi
case "$1 $2" in
  "install kubernetes") touch installed ;;
  "workspace create") arg --context "$@" > context ;;
  "workspace switch") printf '%s' "$3" > workspace ;;
  "workspace show")
    if [[ -n "${WORKSPACE_JSON:-}" ]]; then
      printf '%s\n' "$WORKSPACE_JSON"
      exit 0
    fi
    jq -n --arg context "$(cat context)" --arg group "$(cat group-selection)" \
      --arg environment "$(cat environment-selection)" '
      {connection: {kind: "kubernetes", context: $context},
       scope: ("/planes/radius/local/resourceGroups/" + $group),
       environment: ("/planes/radius/local/resourceGroups/" + $group +
         "/providers/Applications.Core/environments/" + $environment)}'
    ;;
  "group list")
    if [[ -n "${GROUP_JSON:-}" ]]; then printf '%s\n' "$GROUP_JSON"
    elif [[ -f group ]]; then jq -n --arg name "$(cat group)" '[{name: $name}]'
    else echo '[]'; fi
    ;;
  "group create") printf '%s' "$3" > group ;;
  "group switch") [[ -f group ]]; printf '%s' "$3" > group-selection ;;
  "group show") [[ -f group ]] ;;
  "env list")
    if [[ -n "${ENV_JSON:-}" ]]; then printf '%s\n' "$ENV_JSON"
    elif [[ -f environment.json ]]; then jq -s '.' environment.json
    else echo '[]'; fi
    ;;
  "env create")
    if [[ "${DROP_ENV_CREATE:-false}" != true ]]; then
      jq -n --arg name "$3" --arg namespace "$(arg --kubernetes-namespace "$@")" \
        '{name: $name, properties: {compute: {kind: "kubernetes", namespace: $namespace}}}' \
        > environment.json
    fi
    ;;
  "env switch") printf '%s' "$3" > environment-selection ;;
  "env show") cat environment.json ;;
  *) echo "Unexpected Radius command: $*" >&2; exit 90 ;;
esac
"""


@unittest.skipUnless(BASH, "Bash is required")
class K3sRadiusSetup(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="adaptive-radius-k3s-")
        self.addCleanup(self.temporary.cleanup)
        self.lab = Path(self.temporary.name) / "lab with spaces"
        (self.lab / "resources").mkdir(parents=True)
        shutil.copyfile(ROOT / "resources/deploy-radius-k3s.sh",
                        self.lab / "resources/deploy-radius-k3s.sh")
        bin_path = self.lab / "mock-bin"
        bin_path.mkdir()
        for name in ("kubectl", "rad"):
            path = bin_path / name
            path.write_text(MOCK, newline="\n")
            path.chmod(0o755)
        self.env = {**os.environ, "MSYS_NO_PATHCONV": "1"}
        for key in list(self.env):
            if key.startswith(("RADIUS_", "K3S_")) or key == "KUBECONFIG":
                self.env.pop(key)
        self.run_shell("command -v jq")

    def run_shell(self, command, success=True, **overrides):
        result = subprocess.run(
            [BASH, "-c", 'export PATH="$PWD/mock-bin:$PATH"; ' + command],
            cwd=self.lab, env={**self.env, **overrides},
            capture_output=True, text=True, timeout=30,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def run_setup(self, success=True, **overrides):
        result = self.run_shell("bash resources/deploy-radius-k3s.sh", success, **overrides)
        if not success:
            self.assertNotIn("Radius on K3s is healthy:", result.stdout)
        return result

    def commands(self):
        path = self.lab / "commands.log"
        return path.read_text().splitlines() if path.exists() else []

    def existing_environment(self, namespace="env-local-prod", **properties):
        (self.lab / "installed").touch()
        (self.lab / "group").write_text("rg-trading")
        config = {
            "name": "env-local-prod",
            "properties": {
                "compute": {"kind": "kubernetes", "namespace": namespace},
                "recipes": {"Radius.Resources/mqttBrokers": {"default": {"templatePath": "keep"}}},
                **properties,
            },
        }
        (self.lab / "environment.json").write_text(json.dumps(config))
        return config

    def test_first_run_installs_and_creates_all_scopes_after_readiness(self):
        result = self.run_setup()
        commands = self.commands()
        self.assertIn("rad install kubernetes --kubecontext k3s-azure-vm", commands)
        wait = commands.index(
            "kubectl wait --for=condition=Available deployments --all --namespace radius-system --timeout=10m"
        )
        create = commands.index(
            "rad workspace create kubernetes ws-local-prod --context k3s-azure-vm --force"
        )
        self.assertLess(wait, create)
        self.assertIn("rad group create rg-trading --workspace ws-local-prod", commands)
        self.assertIn(
            "rad env create env-local-prod --workspace ws-local-prod --group rg-trading "
            "--kubernetes-namespace env-local-prod", commands,
        )
        self.assertEqual((self.lab / "workspace").read_text(), "ws-local-prod")
        self.assertEqual((self.lab / "group-selection").read_text(), "rg-trading")
        self.assertEqual((self.lab / "environment-selection").read_text(), "env-local-prod")
        self.assertIn("workspace ws-local-prod, group rg-trading, environment env-local-prod", result.stdout)
        self.assertFalse(any("credential register" in c or "--azure-" in c for c in commands))

    def test_installed_radius_still_creates_missing_scopes_without_reinstall(self):
        (self.lab / "installed").touch()
        self.run_setup()
        commands = self.commands()
        self.assertFalse(any(c.startswith("rad install") for c in commands))
        self.assertTrue((self.lab / "environment.json").exists())
        self.assertIn("rad group create rg-trading --workspace ws-local-prod", commands)

    def test_rerun_preserves_existing_environment_and_recipes(self):
        config = self.existing_environment()
        self.run_setup()
        self.run_setup()
        self.assertEqual(json.loads((self.lab / "environment.json").read_text()), config)
        self.assertFalse(any(c.startswith(("rad install", "rad env create", "rad group create"))
                             for c in self.commands()))

    def test_explicit_reinstall_is_honored(self):
        self.existing_environment()
        self.run_setup(RADIUS_REINSTALL="true")
        self.assertIn("rad install kubernetes --kubecontext k3s-azure-vm --reinstall", self.commands())

    def test_custom_resource_names_and_namespace_are_scoped_explicitly(self):
        self.run_setup(K3S_CONTEXT="custom-k3s", CURRENT_CONTEXT="custom-k3s",
                       RADIUS_WORKSPACE="custom-workspace", RADIUS_GROUP="custom-group",
                       RADIUS_ENVIRONMENT="custom-env", RADIUS_NAMESPACE="custom-namespace")
        self.assertIn(
            "rad env show custom-env --workspace custom-workspace --group custom-group --output json",
            self.commands(),
        )
        config = json.loads((self.lab / "environment.json").read_text())
        self.assertEqual(config["properties"]["compute"]["namespace"], "custom-namespace")

    def test_wrong_cluster_stops_before_radius_changes(self):
        self.run_setup(success=False, CURRENT_CONTEXT="aks-adaptive-apps")
        self.assertFalse(any(c.startswith("rad ") for c in self.commands()))

    def test_namespace_and_readiness_errors_stop_before_scope_creation(self):
        for failure in (
            "kubectl get namespace", "kubectl wait --for=condition=Ready",
            "kubectl wait --for=condition=Available", "kubectl get crd",
        ):
            with self.subTest(failure=failure):
                result = self.run_setup(success=False, FAIL_COMMAND=failure)
                self.assertIn("setup is incomplete", result.stderr)
                self.assertFalse(any(c.startswith("rad workspace create") for c in self.commands()))

    def test_failed_lists_are_not_treated_as_missing_resources(self):
        for failure in ("rad group list", "rad env list"):
            with self.subTest(failure=failure):
                result = self.run_setup(success=False, FAIL_COMMAND=failure)
                self.assertIn("Injected command failure", result.stderr)
                command = "rad group create" if failure == "rad group list" else "rad env create"
                self.assertFalse(any(c.startswith(command) for c in self.commands()))

    def test_invalid_list_output_fails_instead_of_creating_resources(self):
        for payload in ("not-json", "null", "{}", "[{}]"):
            with self.subTest(payload=payload):
                self.run_setup(success=False, GROUP_JSON=payload)
                self.assertFalse(any(c.startswith("rad group create") for c in self.commands()))

    def test_invalid_environment_list_output_fails_before_creation(self):
        for payload in ("not-json", "null", "{}", "[{}]"):
            with self.subTest(payload=payload):
                self.run_setup(success=False, ENV_JSON=payload)
                self.assertFalse(any(c.startswith("rad env create") for c in self.commands()))

    def test_wrong_workspace_context_group_or_environment_fails_validation(self):
        scope = "/planes/radius/local/resourceGroups/rg-trading"
        for workspace in (
            {"connection": {"kind": "kubernetes", "context": "aks-adaptive-apps"},
             "scope": scope, "environment": scope + "/providers/Applications.Core/environments/env-local-prod"},
            {"connection": {"kind": "kubernetes", "context": "k3s-azure-vm"},
             "scope": scope + "-wrong", "environment": scope + "/providers/Applications.Core/environments/env-local-prod"},
            {"connection": {"kind": "kubernetes", "context": "k3s-azure-vm"},
             "scope": scope, "environment": scope + "/providers/Applications.Core/environments/wrong"},
        ):
            with self.subTest(workspace=workspace):
                result = self.run_setup(success=False, WORKSPACE_JSON=json.dumps(workspace))
                self.assertIn("The active workspace must target", result.stderr)

    def test_incompatible_namespace_is_reported_without_overwriting_environment(self):
        config = self.existing_environment(namespace="wrong-namespace")
        result = self.run_setup(success=False)
        self.assertIn("must use Kubernetes namespace env-local-prod", result.stderr)
        self.assertEqual(json.loads((self.lab / "environment.json").read_text()), config)

    def test_azure_provider_is_reported_without_removing_configuration(self):
        config = self.existing_environment(providers={"azure": {"scope": "unexpected"}})
        result = self.run_setup(success=False)
        self.assertIn("with no Azure provider", result.stderr)
        self.assertEqual(json.loads((self.lab / "environment.json").read_text()), config)

    def test_missing_environment_after_create_never_reports_success(self):
        self.run_setup(success=False, DROP_ENV_CREATE="true")

    def test_creation_errors_stop_without_success(self):
        for failure in ("rad group create", "rad env create"):
            with self.subTest(failure=failure):
                result = self.run_setup(success=False, FAIL_COMMAND=failure)
                self.assertIn("Injected command failure", result.stderr)


if __name__ == "__main__":
    unittest.main()
