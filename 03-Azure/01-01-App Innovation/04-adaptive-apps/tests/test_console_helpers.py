"""Offline Console helper tests. Azure, Radius and Kubernetes network calls are mocked."""

import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
KUBECTL = shutil.which("kubectl")
MOCK = r'''#!/usr/bin/env python3
import base64
import json
import os
from pathlib import Path
import socket
import subprocess
import sys

command = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["MOCK_LOG"], "a") as log:
    log.write(json.dumps([command, *args]) + "\n")

def arg(name):
    return args[args.index(name) + 1]

def kubeconfig(name):
    return {
        "apiVersion": "v1", "kind": "Config",
        "clusters": [{"name": name, "cluster": {"server": "https://127.0.0.1:6443"}}],
        "users": [{"name": name, "user": {"token": "mock-token-not-a-credential"}}],
        "contexts": [{"name": name, "context": {"cluster": name, "user": name}}],
        "current-context": name,
    }

if os.environ.get("FAIL_COMMAND") == command + " " + " ".join(args[:2]):
    print("Injected command failure", file=sys.stderr)
    sys.exit(17)
if command == "kubectl":
    if args[0] == "config":
        sys.exit(subprocess.call([os.environ["REAL_KUBECTL"], *args]))
    if args[:3] == ["get", "namespace", "radius-system"]:
        print(os.environ.get("MOCK_RADIUS_NAMESPACE", "namespace/radius-system"))
    elif args[:2] == ["get", "deployments,statefulsets"]:
        print(os.environ.get("CORE_OBJECTS", "deployment.apps/core-keycloak"))
    elif "get" in args and '--raw=/readyz' in args:
        print("ok")
    sys.exit(0)
if command == "az":
    if args[:2] == ["account", "show"]:
        if os.environ.get("AUTH_FAIL") == "true":
            sys.exit(1)
        print("test-subscription")
    elif args[0] in ("ad", "login"):
        print("Unexpected Graph or interactive login", file=sys.stderr)
        sys.exit(90)
    elif args[:2] == ["group", "show"]:
        print(json.dumps({"location": "westeurope", "tags": {
            "adaptiveAppsInfrastructureReady": os.environ.get("READY", "true"),
            "adaptiveAppsReady": os.environ.get("LEGACY_READY", "false"),
            "adaptiveAppsAcr": "acrtest"}}))
    elif args[:2] == ["aks", "get-credentials"]:
        Path(arg("--file")).write_text(json.dumps(kubeconfig("aks-adaptive-apps")))
    elif args[:2] == ["aks", "show"]:
        print("https://mock-issuer/" if arg("--query") == "oidcIssuerProfile.issuerUrl" else "westeurope")
    elif args[:2] == ["vm", "show"] and "--query" in args:
        print("/subscriptions/test/resourceGroups/test/providers/Microsoft.Network/networkInterfaces/test")
    elif args[:3] == ["vm", "run-command", "invoke"]:
        config = """apiVersion: v1
kind: Config
clusters:
- name: default
  cluster:
    server: https://127.0.0.1:6443
users:
- name: default
  user:
    token: mock-token-not-a-credential
contexts:
- name: default
  context:
    cluster: default
    user: default
current-context: default
"""
        encoded = base64.b64encode(config.encode()).decode()
        if "K3S_LENGTH:" in arg("--scripts"):
            message = "K3S_LENGTH:" + str(len(encoded))
        else:
            message = "K3S_CHUNK_BEGIN\n" + encoded + "\nK3S_CHUNK_END"
        print(json.dumps({"value": [{"message": message}]}))
    elif args[:3] == ["network", "bastion", "show"]:
        print('{"state":"Succeeded","sku":"Standard","tunneling":true}')
    elif args[:3] == ["network", "bastion", "tunnel"]:
        server = socket.socket()
        server.bind(("127.0.0.1", int(arg("--port"))))
        server.listen()
        while True:
            client, _ = server.accept()
            client.close()
    elif args[:2] == ["identity", "show"]:
        print("mock-identity")
    elif args[:3] == ["role", "assignment", "list"]:
        print("mock-role-assignment")
    sys.exit(0)
if command == "rad":
    if args[:2] == ["recipe", "list"]:
        types = ["postgreSqlDatabases", "mqttBrokers", "idProviders", "workloadIdentities",
                 "aiModels", "governance", "agentGuardrails", "sqlDatabases"]
        recipes = [{"name": os.environ.get("RECIPE_NAME", "default"),
                    "resourceType": "Radius.Resources/" + kind, "templateKind": "bicep",
                    "templatePath": "mock.azurecr.io/recipe:1.0.7"} for kind in types]
        print(os.environ.get("RECIPE_JSON", json.dumps(recipes)))
    elif args[:2] == ["bicep", "publish-extension"]:
        Path(arg("--target")).write_text("mock-extension")
    sys.exit(0)
if command == "curl":
    Path(arg("--output")).write_text("types: {}")
    sys.exit(0)
print("Unexpected mock command: " + command, file=sys.stderr)
sys.exit(91)
'''


@unittest.skipUnless(KUBECTL, "kubectl is required for real offline kubeconfig operations")
class ConsoleHelpers(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="adaptive-console-test-")
        self.root = Path(self.temporary.name)
        self.lab = self.root / "lab with spaces"
        shutil.copytree(ROOT / "resources", self.lab / "resources")
        self.home = self.root / "home"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("az", "rad", "kubectl", "curl"):
            path = self.bin / name
            path.write_text(MOCK)
            path.chmod(0o755)
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            self.port = listener.getsockname()[1]
        self.log = self.root / "commands.jsonl"
        self.env = {
            **os.environ, "HOME": str(self.home), "PATH": f"{self.bin}:{os.environ['PATH']}",
            "MOCK_LOG": str(self.log), "REAL_KUBECTL": KUBECTL,
            "AZURE_SUBSCRIPTION": "test-subscription", "RESOURCE_GROUP": "rg-test",
            "ACR_NAME": "acrtest", "K3S_LOCAL_PORT": str(self.port),
            "RADIUS_IDENTITY_MODE": "managedidentity", "ADAPTIVE_APPS_NONINTERACTIVE": "true",
        }
        for key in ("KUBECONFIG", "K3S_KUBECONFIG", "K3S_TUNNEL_STATE_DIR", "RADIUS_WORKSPACE"):
            self.env.pop(key, None)

    def tearDown(self):
        subprocess.run(["bash", "resources/prepare-k3s-azure-vm.sh", "disconnect"],
                       cwd=self.lab, env=self.env, capture_output=True, timeout=30, check=True)
        self.temporary.cleanup()

    def run_script(self, name, *args, success=True, **overrides):
        result = subprocess.run(["bash", f"resources/{name}", *args], cwd=self.lab,
                                env={**self.env, **overrides}, capture_output=True, text=True, timeout=45)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def commands(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_platform_preparation_requires_explicit_azure_resource_group(self):
        for script, mode in (("prepare-aks.sh", ()),
                             ("prepare-k3s-azure-vm.sh", ("provision",)),
                             ("prepare-k3s-azure-vm.sh", ("connect",))):
            with self.subTest(script=script, mode=mode):
                result = self.run_script(script, *mode, success=False, RESOURCE_GROUP="")
                self.assertIn("Set RESOURCE_GROUP", result.stderr)
                self.assertEqual(self.commands(), [])

    def test_k3s_local_modes_without_recorded_tunnel_need_no_azure_configuration(self):
        for mode in ("--help", "status", "disconnect"):
            with self.subTest(mode=mode):
                result = self.run_script(
                    "prepare-k3s-azure-vm.sh", mode, success=mode != "status",
                    AZURE_SUBSCRIPTION="", RESOURCE_GROUP="")
                self.assertNotIn("Set RESOURCE_GROUP", result.stderr)
                self.assertEqual(self.commands(), [])

    def test_k3s_recorded_tunnel_requires_group_for_identity_verification(self):
        state = self.root / "recorded-tunnel"
        state.mkdir()
        (state / "tunnel.pid").write_text("99999999")
        for mode in ("status", "disconnect"):
            with self.subTest(mode=mode):
                result = self.run_script(
                    "prepare-k3s-azure-vm.sh", mode, success=False,
                    AZURE_SUBSCRIPTION="", RESOURCE_GROUP="",
                    K3S_TUNNEL_STATE_DIR=str(state))
                self.assertIn("Set RESOURCE_GROUP", result.stderr)
                self.assertTrue((state / "tunnel.pid").exists())
                self.assertEqual(self.commands(), [])

    def assert_no_provisioning(self):
        for command in self.commands():
            if command[0] == "az":
                self.assertNotIn(command[1], ("ad", "login", "deployment", "identity", "role"))
                self.assertNotIn("create", command)
                self.assertNotIn("delete", command)
            if command[0] == "rad":
                self.assertNotIn(command[1], ("install", "deploy"))
                self.assertNotEqual(command[1:3], ["resource-type", "create"])

    def test_fresh_participant_gets_both_contexts_and_quoted_environment_without_radius(self):
        self.env["RESOURCE_GROUP"] = "rg-test-$HOME"
        result = self.run_script("connect-console.sh")
        self.assert_no_provisioning()
        environment = self.lab / "artifacts/console-env.sh"
        self.assertEqual(environment.stat().st_mode & 0o777, 0o600)
        value = subprocess.check_output(
            ["bash", "-c", 'source artifacts/console-env.sh; printf "%s" "$RESOURCE_GROUP"'],
            cwd=self.lab, env=self.env, text=True)
        self.assertEqual(value, "rg-test-$HOME")
        self.assertFalse((self.lab / "artifacts/types.tgz").exists())
        self.assertFalse(any(c[0] == "rad" for c in self.commands()))
        self.assertFalse(any("radius-system" in c or "core" in c for c in self.commands()))
        self.assertIn("Challenge 03", result.stdout)
        identity_mode = subprocess.check_output(
            ["bash", "-c", 'source artifacts/console-env.sh; printf "%s:%s" "$RADIUS_IDENTITY_MODE" "$RADIUS_REINSTALL"'],
            cwd=self.lab, env=self.env, text=True)
        self.assertEqual(identity_mode, "managedidentity:false")
        merged = subprocess.check_output(
            [KUBECTL, "config", "view", "--raw", "--output", "json"],
            env={**self.env, "KUBECONFIG": str(self.home / ".kube/config")}, text=True)
        config = json.loads(merged)
        self.assertEqual(config["current-context"], "aks-adaptive-apps")
        self.assertEqual({c["name"] for c in config["contexts"]}, {"aks-adaptive-apps", "k3s-azure-vm"})
        self.assertTrue(all(u["user"]["token"] == "mock-token-not-a-credential" for u in config["users"]))
        self.assertNotIn("mock-token-not-a-credential", result.stdout + result.stderr)

    def test_not_ready_lab_stops_before_connecting(self):
        self.run_script("connect-console.sh", success=False, READY="false")
        self.assertFalse(any(c[1:3] == ["aks", "get-credentials"] for c in self.commands()))

    def test_failed_authentication_never_opens_interactive_login(self):
        self.run_script("connect-console.sh", success=False, AUTH_FAIL="true")
        self.assertFalse(any(c[:2] == ["az", "login"] for c in self.commands()))

    def test_old_ready_tag_does_not_substitute_for_infrastructure_verification(self):
        self.run_script("connect-console.sh", success=False, READY="false", LEGACY_READY="true")
        self.assertFalse(any(c[1:3] == ["aks", "get-credentials"] for c in self.commands()))

    def test_reconnect_preserves_existing_radius_state_and_does_not_require_recipes(self):
        self.run_script("connect-console.sh", CORE_OBJECTS="", RECIPE_JSON="[]",
                        FAIL_COMMAND="rad workspace")
        self.assertFalse(any(c[0] == "rad" for c in self.commands()))
        self.assertTrue((self.lab / "artifacts/console-env.sh").is_file())

    def test_recipe_verifier_rejects_empty_wrong_name_and_invalid_json(self):
        for payload in ("[]", "null", "invalid", '[{"resourceType":"Radius.Resources/mqttBrokers"}]'):
            with self.subTest(payload=payload):
                self.run_script("verify-recipes.sh", "ws-local-prod", "env-local-prod",
                                "Radius.Resources/mqttBrokers", success=False, RECIPE_JSON=payload)

    def test_valid_default_recipe_passes(self):
        self.run_script("verify-recipes.sh", "ws-local-prod", "env-local-prod",
                        "Radius.Resources/mqttBrokers")

    def test_unknown_bootstrap_phase_is_rejected_before_azure_calls(self):
        self.run_script("bootstrap-console.sh", "wrong", success=False)
        self.assertEqual(self.commands(), [])

    def test_retained_aks_bootstrap_preserves_existing_radius_without_graph(self):
        self.run_script("bootstrap-console.sh", "aks-radius")
        commands = self.commands()
        self.assertFalse(any(c[:2] == ["az", "ad"] for c in commands))
        self.assertFalse(any(c[:2] == ["rad", "install"] for c in commands))
        self.assertTrue(any(c[1:3] == ["identity", "federated-credential"] for c in commands))

    def test_retained_k3s_bootstrap_refreshes_kubeconfig_and_cleans_tunnel(self):
        self.run_script("bootstrap-console.sh", "k3s-radius")
        self.assertTrue((self.home / ".kube/adaptive-apps-k3s.yaml").is_file())
        self.assertFalse((self.home / ".kube/adaptive-apps-bastion/tunnel.pid").exists())
        self.assertFalse(any(c[:2] == ["rad", "install"] for c in self.commands()))

    def test_managed_identity_bootstrap_never_uses_graph_or_reinstalls_existing_radius(self):
        self.run_script("connect-console.sh")
        self.run_script("deploy-radius-aks.sh", RADIUS_REINSTALL="false")
        commands = self.commands()
        self.assertFalse(any(c[:2] == ["az", "ad"] for c in commands))
        self.assertFalse(any(c[:2] == ["rad", "install"] for c in commands))
        self.assertTrue(any(c[1:3] == ["identity", "federated-credential"] for c in commands))
        self.assertTrue(any(c[1:4] == ["credential", "register", "azure"] for c in commands))

    def test_missing_radius_is_installed_on_first_run(self):
        self.run_script("connect-console.sh")
        self.run_script("deploy-radius-aks.sh", MOCK_RADIUS_NAMESPACE="", RADIUS_REINSTALL="false")
        installs = [c for c in self.commands() if c[:2] == ["rad", "install"]]
        self.assertEqual(len(installs), 1)
        self.assertNotIn("--reinstall", installs[0])

    def test_namespace_lookup_error_is_not_interpreted_as_absence(self):
        self.run_script("connect-console.sh")
        self.run_script("deploy-radius-aks.sh", success=False, RADIUS_REINSTALL="false",
                        FAIL_COMMAND="kubectl get namespace")
        self.assertFalse(any(c[:2] == ["rad", "install"] for c in self.commands()))

    def test_k3s_connection_refreshes_missing_kubeconfig_without_installing_radius(self):
        self.run_script("connect-console.sh")
        self.assertTrue((self.home / ".kube/adaptive-apps-k3s.yaml").is_file())
        self.run_script("prepare-k3s-azure-vm.sh", "disconnect")
        self.assertFalse((self.home / ".kube/adaptive-apps-bastion/tunnel.pid").exists())
        self.assertFalse(any(c[:2] == ["rad", "install"] for c in self.commands()))

    def test_refresh_replaces_stale_default_context_credentials(self):
        self.run_script("connect-console.sh")
        default_file = self.home / ".kube/config"
        default_file.write_text(default_file.read_text().replace("mock-token-not-a-credential", "old-token"))
        self.run_script("prepare-k3s-azure-vm.sh", "connect", K3S_REFRESH_KUBECONFIG="true")
        config = json.loads(subprocess.check_output(
            [KUBECTL, "config", "view", "--raw", "--output", "json"],
            env={**self.env, "KUBECONFIG": str(default_file)}, text=True))
        users = {user["name"]: user["user"]["token"] for user in config["users"]}
        self.assertEqual(users["default"], "mock-token-not-a-credential")
        self.assertEqual(users["aks-adaptive-apps"], "old-token")

    def test_failure_after_tunnel_start_stops_only_recorded_tunnel(self):
        self.run_script("connect-console.sh", success=False, FAIL_COMMAND="kubectl --request-timeout=15s get")
        self.assertFalse((self.lab / "artifacts/console-env.sh").exists())
        self.assertFalse((self.home / ".kube/adaptive-apps-bastion/tunnel.pid").exists())

    def test_managed_identity_lookup_error_is_not_interpreted_as_absence(self):
        self.run_script("connect-console.sh")
        self.run_script("deploy-radius-aks.sh", success=False, RADIUS_REINSTALL="false",
                        FAIL_COMMAND="az identity list")
        self.assertFalse(any(c[:3] == ["az", "identity", "create"] for c in self.commands()))


if __name__ == "__main__":
    unittest.main()
