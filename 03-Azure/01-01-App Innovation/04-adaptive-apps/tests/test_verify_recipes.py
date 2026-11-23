"""Offline expected-versus-available recipe checks using a mocked Radius CLI."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which("bash")


@unittest.skipUnless(BASH, "Bash is required")
class VerifyRecipes(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="adaptive-recipes-")
        self.addCleanup(self.temporary.cleanup)
        self.lab = Path(self.temporary.name)
        (self.lab / "resources").mkdir()
        shutil.copyfile(ROOT / "resources/verify-recipes.sh",
                        self.lab / "resources/verify-recipes.sh")
        (self.lab / "mock-bin").mkdir()
        mock = self.lab / "mock-bin/rad"
        mock.write_text(
            '#!/usr/bin/env bash\nprintf "%s\\n" "$*" > command.log\n'
            'if [[ "${QUERY_FAIL:-false}" == true ]]; then\n'
            '  echo "Radius query failed" >&2; exit 17\nfi\ncat recipes.json\n',
            newline="\n",
        )
        mock.chmod(0o755)

    def verify(self, recipes, *types, **overrides):
        payload = recipes if isinstance(recipes, str) else json.dumps(recipes)
        (self.lab / "recipes.json").write_text(payload)
        return subprocess.run(
            [BASH, "-c", 'export PATH="$PWD/mock-bin:$PATH"; '
             'bash resources/verify-recipes.sh test-workspace test-environment "$@"',
             "verify", *types],
            cwd=self.lab, env={**os.environ, "MSYS_NO_PATHCONV": "1", **overrides},
            capture_output=True, text=True, timeout=30,
        )

    def recipe(self, resource_type):
        return {"resourceType": resource_type, "name": "default",
                "templateKind": "bicep", "templatePath": "registry/recipe:1.0.6"}

    def test_complete_set_allows_extra_recipes_and_scopes_query(self):
        result = self.verify([self.recipe("expected"), self.recipe("extra")],
                             "expected", RADIUS_GROUP="custom-group")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("All 1 expected default Bicep recipes", result.stdout)
        self.assertEqual(
            (self.lab / "command.log").read_text().strip(),
            "recipe list --workspace test-workspace --group custom-group "
            "--environment test-environment --output json",
        )

    def test_reports_every_missing_recipe_not_just_the_first(self):
        result = self.verify([self.recipe("present")], "missing-one", "present", "missing-two")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("WARNING: Missing usable default Bicep recipe for missing-one", result.stderr)
        self.assertIn("WARNING: Missing usable default Bicep recipe for missing-two", result.stderr)
        self.assertNotIn("recipe for present", result.stderr)
        self.assertIn("2 expected recipe(s) missing", result.stderr)

    def test_unusable_recipes_are_reported(self):
        for field, value in (("name", "not-default"), ("templateKind", "terraform"),
                             ("templatePath", ""), ("templatePath", None)):
            with self.subTest(field=field, value=value):
                recipe = {**self.recipe("expected"), field: value}
                result = self.verify([recipe], "expected")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("WARNING:", result.stderr)

    def test_invalid_query_output_fails_explicitly(self):
        for payload in ("", "not-json", "null", "{}", "[]\n[]"):
            with self.subTest(payload=payload):
                result = self.verify(payload, "expected")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("cannot validate registrations", result.stderr)
                self.assertNotIn("All 1 expected", result.stdout)

    def test_walkthrough_checks_match_the_complete_platform_recipe_sets(self):
        walkthrough = (ROOT / "walkthrough/challenge-05/solution-05.md").read_text()
        validation = walkthrough.split("## Validate", 1)[1]
        for workspace, environment, template, count in (
            ("ws-azure-prod", "env-azure-prod", "aks-env.bicep", 8),
            ("ws-local-prod", "env-local-prod", "local-env.bicep", 7),
        ):
            with self.subTest(workspace=workspace):
                command = validation.split(
                    f"bash resources/verify-recipes.sh {workspace} {environment}", 1
                )[1].split("```", 1)[0]
                expected = re.findall(r"Radius\.Resources/\w+", command)
                declared = re.findall(r"'(Radius\.Resources/\w+)':", (ROOT / "iac" / template).read_text())
                self.assertEqual(len(expected), count)
                self.assertEqual(set(expected), set(declared))
                complete = self.verify([self.recipe(kind) for kind in expected], *expected)
                self.assertEqual(complete.returncode, 0, complete.stderr)
                self.assertIn(f"All {count} expected", complete.stdout)
                missing = self.verify([], *expected)
                self.assertNotEqual(missing.returncode, 0)
                self.assertEqual(missing.stderr.count("WARNING:"), count)
                for kind in expected:
                    self.assertIn(f"recipe for {kind} in", missing.stderr)

    def test_query_error_is_not_reported_as_missing_recipes(self):
        result = self.verify([], "expected", QUERY_FAIL="true")
        self.assertEqual(result.returncode, 17)
        self.assertIn("Radius query failed", result.stderr)
        self.assertNotIn("WARNING:", result.stderr)


if __name__ == "__main__":
    unittest.main()
