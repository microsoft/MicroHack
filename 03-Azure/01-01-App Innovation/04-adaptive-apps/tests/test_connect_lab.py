"""Offline connection orchestration tests; no Azure or Kubernetes access."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which("bash")
AZ = r"""#!/usr/bin/env bash
printf 'az %s\n' "$*" >> commands.log
case "$1 $2" in
  "account show") [[ "${AUTH_FAIL:-false}" != true ]] ;;
  "group show") [[ "${GROUP_FAIL:-false}" != true ]] ;;
  "aks show") printf 'westeurope\n' ;;
  "aks get-credentials")
    [[ "${AKS_FAIL:-false}" != true ]] || exit 17
    touch "$HOME/.kube/config"
    ;;
  "account set") ;;
  *) echo "Unexpected Azure command: $*" >&2; exit 90 ;;
esac
"""
KUBECTL = r"""#!/usr/bin/env bash
printf 'kubectl %s\n' "$*" >> commands.log
if [[ "$*" == *--raw=/readyz* ]]; then
  printf '%s\n' "${AKS_READY:-ok}"
fi
"""
K3S = r"""#!/usr/bin/env bash
printf 'k3s %s refresh=%s\n' "$*" "$K3S_REFRESH_KUBECONFIG" >> commands.log
[[ "${K3S_FAIL:-false}" != true || "$1" == disconnect ]]
"""


@unittest.skipUnless(BASH, "Bash is required")
class LabConnection(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="adaptive-connect-")
        self.addCleanup(self.temporary.cleanup)
        self.lab = Path(self.temporary.name) / "lab with spaces"
        shutil.copytree(ROOT / "resources", self.lab / "resources")
        self.bin = self.lab / "mock-bin"
        self.bin.mkdir()
        for path, content in (
            (self.bin / "az", AZ),
            (self.bin / "kubectl", KUBECTL),
            (self.lab / "resources/prepare-k3s-azure-vm.sh", K3S),
        ):
            path.write_text(content, newline="\n")
            path.chmod(0o755)
        if os.name == "nt":
            # Git Bash install cannot apply POSIX directory modes on Windows.
            (self.bin / "install").write_text(
                '#!/usr/bin/env bash\nmkdir -p "${@: -1}"\n', newline="\n"
            )
        self.env = {
            **os.environ,
            "AZURE_SUBSCRIPTION": "test-subscription",
            "RESOURCE_GROUP": "rg-test-$HOME",
            "AKS_CLUSTER": "custom-aks",
            "AKS_CONTEXT": "custom-aks-context",
            "K3S_CONTEXT": "custom-k3s-context",
            "K3S_VM_NAME": "custom-vm",
            "BASTION_NAME": "custom-bastion",
            "K3S_LOCAL_PORT": "26443",
            "KUBECONFIG": "stale-kubeconfig",
        }
        for name in ("K3S_KUBECONFIG", "K3S_TUNNEL_STATE_DIR"):
            self.env.pop(name, None)

    def shell(self, command, **overrides):
        return subprocess.run(
            [BASH, "-c", 'export HOME="$PWD/home" PATH="$PWD/mock-bin:$PATH"; ' + command],
            cwd=self.lab, env={**self.env, **overrides},
            capture_output=True, text=True, timeout=30,
        )

    def connect(self, success=True, **overrides):
        result = self.shell("bash resources/connect-lab.sh", **overrides)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertFalse((self.lab / "artifacts/lab-env.sh").exists())
        return result

    def log(self):
        path = self.lab / "commands.log"
        return path.read_text() if path.exists() else ""

    def test_connections_refresh_credentials_and_export_custom_settings(self):
        self.connect()
        log = self.log()
        self.assertIn("k3s connect refresh=true", log)
        self.assertIn("--name custom-aks --context custom-aks-context", log)
        self.assertTrue(log.rstrip().endswith("kubectl config use-context custom-aks-context"))
        result = self.shell(
            'source artifacts/lab-env.sh; '
            'printf "%s|%s|%s|%s|%s|%s|%s|%s|%s" "$RESOURCE_GROUP" '
            '"$AZURE_LOCATION" "$AKS_CONTEXT" "$K3S_CONTEXT" "$K3S_VM_NAME" '
            '"$BASTION_NAME" "$K3S_LOCAL_PORT" "${KUBECONFIG-unset}" "$RADIUS_REINSTALL"'
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout,
            "rg-test-$HOME|westeurope|custom-aks-context|custom-k3s-context|"
            "custom-vm|custom-bastion|26443|unset|false",
        )
        self.assertNotIn("az login", log)
        self.assertNotIn("provision", log)
        if os.name != "nt":
            self.assertEqual((self.lab / "artifacts/lab-env.sh").stat().st_mode & 0o777, 0o600)

    def test_auth_resource_and_aks_errors_stop_before_k3s(self):
        for overrides in (
            {"AUTH_FAIL": "true"}, {"GROUP_FAIL": "true"},
            {"AKS_FAIL": "true"}, {"AKS_READY": "not-ready"},
        ):
            with self.subTest(overrides=overrides):
                self.connect(success=False, **overrides)
                self.assertNotIn("k3s connect", self.log())

    def test_auth_failure_removes_previous_environment(self):
        self.connect()
        self.connect(success=False, AUTH_FAIL="true")

    def test_default_resource_names_are_exported(self):
        for name in (
            "AKS_CLUSTER", "AKS_CONTEXT", "K3S_CONTEXT", "K3S_VM_NAME",
            "BASTION_NAME", "K3S_LOCAL_PORT",
        ):
            self.env.pop(name)
        self.connect()
        result = self.shell(
            'source artifacts/lab-env.sh; printf "%s|%s|%s|%s|%s|%s" '
            '"$AKS_CLUSTER" "$AKS_CONTEXT" "$K3S_CONTEXT" "$K3S_VM_NAME" '
            '"$BASTION_NAME" "$K3S_LOCAL_PORT"'
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout,
            "aks-adaptive-apps|aks-adaptive-apps|k3s-azure-vm|"
            "vm-adaptive-apps-k3s|bas-adaptive-apps|16443",
        )

    def test_k3s_failure_cleans_tunnel_and_stale_environment(self):
        self.connect()
        result = self.connect(success=False, K3S_FAIL="true")
        self.assertIn("k3s disconnect refresh=true", self.log())
        self.assertIn("ERROR: Lab connection failed", result.stderr)
        self.assertEqual(list((self.lab / "artifacts").glob("lab-env.*")), [])

    def test_usage_error_stops_before_azure_calls(self):
        result = self.shell("bash resources/connect-lab.sh provision")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.log(), "")


if __name__ == "__main__":
    unittest.main()
