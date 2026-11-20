"""Offline tests for the hosted and manual K3s guest installers."""

import os
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
PINNED_VERSION = "v1.33.13+k3s1"
BASH = shutil.which("bash")
GUEST_MOCKS = r"""
command() {
  [ "$1" = "-v" ] && [ "$2" = "k3s" ] && [ "$MOCK_PRESENT" = "true" ]
}
k3s() {
  if [ "$1" = "--version" ]; then
    printf 'k3s version %s (mock)\ngo version go1.24.0\n' "$MOCK_VERSION"
    return "${MOCK_VERSION_EXIT:-0}"
  fi
}
install() { echo MUTATION:directory; }
cat() {
  echo MUTATION:configuration
  while IFS= read -r line; do :; done
}
curl() { echo MUTATION:download; }
cd() { :; }
rm() { :; }
systemctl() { echo MUTATION:service; }
sh() { printf 'INSTALL_VERSION:%s\n' "${INSTALL_K3S_VERSION:-unpinned}"; }
"""


@unittest.skipUnless(BASH, "Bash is required for offline shell tests")
class K3sInstallation(unittest.TestCase):
    installers = ("resources/prepare-k3s-azure-vm.sh", "labautomation/install-k3s.sh")

    def guest_script(self, installer, env):
        source = (ROOT / installer).read_text()
        if installer.startswith("labautomation"):
            return source
        assignment = next(
            (line for line in source.splitlines() if line.startswith("K3S_VERSION=")), ""
        )
        payload = source.split('  --scripts "\n', 1)[1].split('\n" \\\n', 1)[0]
        result = subprocess.run(
            [BASH, "-s"],
            input=assignment + '\nVM_PRIVATE_IP=10.42.0.4\n'
            'emit_script() { printf "%s\\n" "$1"; }\nemit_script "\n' + payload + '\n"',
            env=env, capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def run_guest(self, installer, **overrides):
        env = {**os.environ, "MOCK_PRESENT": "false", "MOCK_VERSION": PINNED_VERSION}
        env.pop("K3S_VERSION", None)
        env.update(overrides)
        return subprocess.run(
            [BASH, "-c", "exec sh -s"],
            input=GUEST_MOCKS + self.guest_script(installer, env).replace(
                ">/etc/rancher/k3s/config.yaml", ">/dev/null",
            ),
            env=env, capture_output=True, text=True, timeout=10,
        )

    def test_fresh_install_passes_exact_version_to_installer(self):
        for installer in self.installers:
            with self.subTest(installer=installer):
                result = self.run_guest(installer)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("INSTALL_VERSION:" + PINNED_VERSION, result.stdout)

    def test_explicit_version_override_reaches_guest(self):
        for installer in self.installers:
            with self.subTest(installer=installer):
                result = self.run_guest(installer, K3S_VERSION="v1.33.12+k3s1")
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("INSTALL_VERSION:v1.33.12+k3s1", result.stdout)

    def test_matching_installation_is_reused_without_downloading(self):
        for installer in self.installers:
            with self.subTest(installer=installer):
                result = self.run_guest(installer, MOCK_PRESENT="true")
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertNotIn("INSTALL_VERSION:", result.stdout)
                self.assertNotIn("MUTATION:download", result.stdout)
                self.assertIn("MUTATION:service", result.stdout)

    def test_mismatch_fails_before_configuration_or_service_changes(self):
        for installer in self.installers:
            for version in ("v1.37.2+k3s1", "v1.32.13+k3s1"):
                with self.subTest(installer=installer, version=version):
                    result = self.run_guest(
                        installer, MOCK_PRESENT="true", MOCK_VERSION=version,
                    )
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn("K3S_VERSION_MISMATCH:", result.stderr)
                    self.assertIn(version, result.stderr)
                    self.assertIn(PINNED_VERSION, result.stderr)
                    self.assertNotIn("MUTATION:", result.stdout)
                    self.assertNotIn("INSTALL_VERSION:", result.stdout)
                    self.assertNotIn("K3S_INSTALL_OK", result.stdout)
                    self.assertNotIn("ADAPTIVE_K3S_READY", result.stdout)

    def test_version_query_failure_does_not_change_existing_installation(self):
        for installer in self.installers:
            with self.subTest(installer=installer):
                result = self.run_guest(
                    installer, MOCK_PRESENT="true", MOCK_VERSION_EXIT="17",
                )
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertNotIn("MUTATION:", result.stdout)

    def test_channels_and_partial_versions_are_rejected_before_changes(self):
        for installer in self.installers:
            for version in ("stable", "v1.33"):
                with self.subTest(installer=installer, version=version):
                    if installer.startswith("resources"):
                        source = (ROOT / installer).read_text().split("\nis_integer() {", 1)[0]
                        result = subprocess.run(
                            [BASH, "-s"], input=source, capture_output=True, text=True,
                            env={**os.environ, "K3S_VERSION": version}, timeout=10,
                        )
                    else:
                        result = self.run_guest(installer, K3S_VERSION=version)
                    self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                    self.assertIn("K3S_VERSION must be an exact release", result.stderr)
                    self.assertNotIn("MUTATION:", result.stdout)


if __name__ == "__main__":
    unittest.main()
