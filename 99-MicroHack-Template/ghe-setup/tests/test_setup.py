import argparse
import base64
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("setup_ghe", ROOT / "setup-ghe.py")
setup = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(setup)


def arguments(**overrides):
    values = {
        "apply": False, "check": False, "organization": "lab-org",
        "enterprise": "lab-enterprise", "tenant_id": None,
        "confirm_organization": None, "budget_alert_login": None,
        "skip_azure_verification": False, "report": None,
    }
    return argparse.Namespace(**dict(values, **overrides))


def error(status):
    return setup.ApiError("GET", "test", subprocess.CompletedProcess(
        [], 1, "", f"gh: Request rejected (HTTP {status})",
    ))


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.config = json.loads((ROOT / "baseline.json").read_text())
        self.gh = Mock()
        self.target = setup.Setup(self.gh, arguments(), self.config)
        self.target.org = "lab-org"
        self.target.enterprise = "lab-enterprise"
        self.target.repo = "lab-org/microhack"

    def test_baseline_matches_reference_amounts_and_access(self):
        self.assertEqual(self.config["budgets_usd"], {"codespaces": 6000, "actions": 100})
        self.assertEqual(self.config["codespaces_access"], "all_members")
        self.assertEqual(self.config["copilot"]["enterprise_team"], "GHCPUsers")
        self.assertEqual(self.config["teams"]["admins"]["permission"], "admin")

    def test_plan_never_invokes_mutation_callback(self):
        callback = Mock()
        self.target.change("test operation", callback)
        callback.assert_not_called()

    def test_check_never_invokes_mutation_callback(self):
        self.target.args.check = True
        callback = Mock()
        self.target.change("test operation", callback)
        callback.assert_not_called()

    def test_apply_invokes_mutation_callback(self):
        self.target.args.apply = True
        callback = Mock()
        self.target.change("test operation", callback)
        callback.assert_called_once_with()

    def test_ensure_does_not_write_matching_settings(self):
        self.gh.api.return_value = {"allowed_actions": "all", "extra": True}
        self.target.ensure("settings", {"allowed_actions": "all"})
        self.gh.api.assert_called_once_with("settings")
        self.assertEqual(self.target.changes, [])

    def test_apply_checks_readback(self):
        self.target.args.apply = True
        self.gh.api.side_effect = [{"value": 1}, {}, {"value": 1}]
        with self.assertRaisesRegex(setup.SetupError, "Read-back verification"):
            self.target.ensure("settings", {"value": 2})
        self.assertEqual(self.gh.api.call_args_list[1].args, (
            "settings", "PUT", {"value": 2},
        ))

    def test_patch_omits_unchanged_enterprise_inherited_settings(self):
        self.target.args.apply = True
        desired = {
            "members_can_fork_private_repositories": True,
            "members_can_create_public_repositories": False,
        }
        self.gh.api.side_effect = [
            dict(desired, members_can_create_public_repositories=True), {}, desired,
        ]
        self.target.ensure("orgs/lab-org", desired, "PATCH")
        self.assertEqual(self.gh.api.call_args_list[1].args, (
            "orgs/lab-org", "PATCH", {"members_can_create_public_repositories": False},
        ))

    def test_optional_does_not_hide_authorization_failure(self):
        github = setup.GitHub()
        github.api = Mock(side_effect=error(403))
        with self.assertRaises(setup.ApiError):
            github.optional("private/settings")
        github.api = Mock(side_effect=error(404))
        self.assertIsNone(github.optional("missing"))

    def test_pages_decodes_all_paginated_objects(self):
        with patch.object(setup, "run", return_value=(
            '{"seats":[{"id":1}]} \n {"seats":[{"id":2}]}'
        )):
            self.assertEqual(setup.GitHub().pages("seats", "seats"), [{"id": 1}, {"id": 2}])

    def test_pages_decodes_paginated_arrays(self):
        with patch.object(setup, "run", return_value='[{"id":1}]\n[{"id":2}]'):
            self.assertEqual(setup.GitHub().pages("teams"), [{"id": 1}, {"id": 2}])

    def test_budget_pagination_does_not_depend_on_link_header(self):
        github = setup.GitHub()
        github.api = Mock(side_effect=[
            {"budgets": [{"id": i} for i in range(100)], "has_next_page": True},
            {"budgets": [{"id": 100}], "has_next_page": False},
        ])
        rows = github.budget_pages("enterprise/budgets")
        self.assertEqual(len(rows), 101)
        self.assertEqual(rows[-1]["id"], 100)
        self.assertTrue(github.api.call_args_list[1].args[0].endswith("page=2"))

    def test_empty_budget_page_with_next_page_is_an_error(self):
        github = setup.GitHub()
        github.api = Mock(return_value={"budgets": [], "has_next_page": True})
        with self.assertRaisesRegex(setup.SetupError, "empty page"):
            github.budget_pages("enterprise/budgets")

    def test_apply_requires_exact_organization_confirmation(self):
        self.target.args.apply = True
        self.gh.graphql.side_effect = [
            {"enterprise": {"id": "E_1", "ownerInfo": {"some": "value"}}},
            {"enterprise": {"organizations": {
                "nodes": [{"login": "lab-org"}],
                "pageInfo": {"hasNextPage": False},
            }}},
        ]
        self.gh.api.return_value = {"role": "admin", "state": "active"}
        with self.assertRaisesRegex(setup.SetupError, "--confirm-organization"):
            self.target.discover()

    def test_discover_rejects_wrong_enterprise(self):
        self.gh.graphql.side_effect = [
            {"enterprise": {"id": "E_1", "ownerInfo": {"some": "value"}}},
            {"enterprise": {"organizations": {
                "nodes": [{"login": "another-org"}],
                "pageInfo": {"hasNextPage": False},
            }}},
        ]
        with self.assertRaisesRegex(setup.SetupError, "does not belong"):
            self.target.discover()
        self.gh.api.assert_not_called()

    def test_apply_cannot_skip_azure_verification(self):
        self.target.args = arguments(
            apply=True, tenant_id="00000000-0000-0000-0000-000000000001",
            skip_azure_verification=True,
        )
        with self.assertRaisesRegex(setup.SetupError, "cannot be skipped"):
            self.target.preflight()
        self.gh.api.assert_not_called()

    def test_wrong_azure_group_prevents_all_github_writes(self):
        self.target.args.tenant_id = "00000000-0000-0000-0000-000000000001"
        self.gh.api.return_value = {
            "Resources": [{"displayName": "GHCPAdmins", "externalId": "wrong"}],
        }
        with patch.object(setup, "azure_groups", return_value={"GHCPAdmins": "correct"}):
            with self.assertRaisesRegex(setup.SetupError, "does not match"):
                self.target.preflight()
        self.assertTrue(all(len(call.args) == 1 for call in self.gh.api.call_args_list))

    def test_mirror_token_requires_deletion_scope(self):
        with patch.dict(os.environ, {"MIRROR_TOKEN": "not-a-real-token"}):
            with patch.object(setup, "run", return_value=(
                "HTTP/2 200 OK\nX-OAuth-Scopes: repo, workflow, admin:org\n\n{}"
            )):
                with self.assertRaisesRegex(setup.SetupError, "classic PAT"):
                    self.target.validate_mirror_token()

    def test_existing_mirror_secret_can_be_reused_without_reading_value(self):
        self.target.repo_exists = True
        self.gh.optional.return_value = {"name": "MIRROR_TOKEN"}
        with patch.dict(os.environ, {}, clear=True):
            self.target.validate_mirror_token()
        self.gh.optional.assert_called_once_with(
            "repos/lab-org/microhack/actions/secrets/MIRROR_TOKEN",
        )
        self.assertTrue(any("only secret existence" in item for item in self.target.manual))

    def test_missing_mirror_secret_fails_before_apply(self):
        self.target.repo_exists = True
        self.gh.optional.return_value = None
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(setup.SetupError, "gh secret set"):
                self.target.validate_mirror_token()

    def test_absent_repository_does_not_allow_missing_mirror_token(self):
        self.target.repo_exists = False
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(setup.SetupError, "gh secret set"):
                self.target.validate_mirror_token()
        self.gh.optional.assert_not_called()

    def budget(self, product, recipients=None):
        return {
            "id": f"budget-{product}", "budget_scope": "enterprise",
            "budget_type": "ProductPricing", "budget_product_sku": product,
            "budget_entity_name": "lab-enterprise",
            "budget_amount": self.config["budgets_usd"][product],
            "prevent_further_usage": True,
            "budget_alerting": {
                "will_alert": True, "alert_recipients": recipients or ["existing-owner"],
            },
        }

    def test_budget_rerun_preserves_existing_recipients_without_writes(self):
        self.gh.budget_pages.return_value = [self.budget("codespaces"), self.budget("actions")]
        self.gh.api.return_value = {"login": "current-owner"}
        self.target.budgets()
        self.assertEqual(self.target.changes, [])
        self.gh.api.assert_called_once_with("user")

    def test_duplicate_budget_is_error_not_another_creation(self):
        self.gh.budget_pages.return_value = [self.budget("codespaces"), self.budget("codespaces")]
        self.gh.api.return_value = {"login": "owner"}
        with self.assertRaisesRegex(setup.SetupError, "Duplicate"):
            self.target.budgets()
        self.gh.api.assert_called_once_with("user")

    def test_apply_creates_required_budget_shape(self):
        self.config["budgets_usd"] = {"codespaces": 6000}
        self.target.args.apply = True
        self.gh.api.return_value = {"login": "owner"}
        self.gh.budget_pages.side_effect = [[], [self.budget("codespaces", ["owner"])]]
        self.target.budgets()
        body = self.gh.api.call_args_list[1].args[2]
        self.assertEqual(body, {
            "budget_amount": 6000, "prevent_further_usage": True,
            "budget_alerting": {"will_alert": True, "alert_recipients": ["owner"]},
            "budget_scope": "enterprise", "budget_entity_name": "lab-enterprise",
            "budget_type": "ProductPricing", "budget_product_sku": "codespaces",
        })

    def test_budget_update_does_not_send_immutable_scope_fields(self):
        self.config["budgets_usd"] = {"codespaces": 6000}
        self.target.args.apply = True
        old = dict(self.budget("codespaces"), budget_amount=1)
        self.gh.api.return_value = {"login": "owner"}
        self.gh.budget_pages.side_effect = [[old], [self.budget("codespaces")]]
        self.target.budgets()
        path, method, body = self.gh.api.call_args_list[1].args
        self.assertEqual(method, "PATCH")
        self.assertTrue(path.endswith("/budget-codespaces"))
        self.assertEqual(set(body), {"budget_amount", "prevent_further_usage", "budget_alerting"})

    def test_copilot_uses_enterprise_team_not_org_unconfigured_seats(self):
        self.gh.optional.return_value = {"id": 7}
        self.gh.pages.side_effect = [
            [
                {"assignee": {"login": "participant"}, "assigning_team": {"id": 7, "name": "GHCPUsers"},
                 "pending_cancellation_date": None},
                {"assignee": {"login": "old-user"}, "assigning_team": None,
                 "pending_cancellation_date": "2026-10-31"},
            ],
            [{"login": "participant"}],
        ]
        self.gh.api.side_effect = [
            {"public_code_suggestions": "allow", "ide_chat": "enabled",
             "cli": "enabled", "platform_chat": "enabled"},
            {"enabled_repositories": "all"},
        ]
        self.target.copilot()
        self.assertEqual(self.target.changes, [])
        self.assertFalse(any("outside GHCPUsers" in item for item in self.target.manual))

    def configure_identity_test(self, members):
        self.target.args.apply = True
        self.target.groups = {"GHCPUsers": {"id": "scim-group"}}
        self.target.external_groups = {"GHCPUsers": {"group_id": 123}}
        self.target.config["teams"] = {
            "participants": {"group": "GHCPUsers", "permission": "pull"},
        }
        self.gh.optional.side_effect = [{"group_id": "scim-group"}, {"slug": "participants"}]
        self.gh.pages.return_value = [{"login": login} for login in members]
        linked = False

        def api(path, method="GET", body=None):
            nonlocal linked
            if path == "enterprises/lab-enterprise/teams/ghcpusers":
                return {"group_id": "scim-group"}
            if path == "user":
                return {"login": "creator"}
            if path.endswith("/external-groups"):
                if method == "PATCH":
                    linked = True
                    return {}
                if linked:
                    return {"groups": [{"group_id": 123}]}
                raise setup.ApiError("GET", path, subprocess.CompletedProcess(
                    [], 1, "", "gh: This team cannot be externally managed since "
                    "it has explicit members. (HTTP 400)",
                ))
            return {}
        self.gh.api.side_effect = api

    def test_team_bootstrap_owner_is_removed_before_scim_linking(self):
        self.configure_identity_test(["creator"])
        self.target.identity()
        writes = [call.args for call in self.gh.api.call_args_list if len(call.args) > 1]
        self.assertEqual(writes[0], (
            "orgs/lab-org/teams/participants/memberships/creator", "DELETE",
        ))
        self.assertEqual(writes[1], (
            "orgs/lab-org/teams/participants/external-groups", "PATCH", {"group_id": 123},
        ))

    def test_team_with_other_explicit_members_requires_review(self):
        self.configure_identity_test(["creator", "participant"])
        with self.assertRaisesRegex(setup.SetupError, "Review and remove"):
            self.target.identity()
        self.assertFalse(any(len(call.args) > 1 for call in self.gh.api.call_args_list))

    def test_copilot_pending_cancellation_is_not_active(self):
        self.gh.optional.return_value = {"id": 7}
        self.gh.pages.side_effect = [
            [{"assignee": {"login": "participant"}, "assigning_team": {"id": 7},
              "pending_cancellation_date": "2026-10-31"}],
            [{"login": "participant"}],
        ]
        self.gh.api.side_effect = [
            {"public_code_suggestions": "allow", "ide_chat": "enabled",
             "cli": "enabled", "platform_chat": "enabled"},
            {"enabled_repositories": "all"},
        ]
        self.target.copilot()
        self.assertIn("1 current members missing active team seats", self.target.changes[0])
        self.assertFalse(any(len(c.args) > 1 for c in self.gh.api.call_args_list))

    def test_org_local_copilot_values_do_not_claim_effective_enterprise_drift(self):
        self.gh.optional.return_value = {"id": 7}
        self.gh.pages.side_effect = [[], []]
        self.gh.api.side_effect = [
            {"public_code_suggestions": "allow", "ide_chat": "enabled",
             "cli": "unconfigured", "platform_chat": "enabled"},
            {"enabled_repositories": "all"},
        ]
        self.target.copilot()
        self.assertTrue(any(
            "policy cli: baseline 'enabled', found 'unconfigured'" in item
            and "not effective-policy drift" in item
            for item in self.target.manual
        ))

    def test_matching_workflows_do_not_create_commit(self):
        files = setup.workflow_files()
        self.gh.optional.side_effect = [
            {"content": base64.b64encode(content).decode()} for content in files.values()
        ]
        self.target.install_workflows("head")
        self.gh.api.assert_not_called()
        self.assertEqual(self.target.changes, [])

    def test_enterprise_policy_mutations_use_typed_inputs_and_readback(self):
        self.target.args.apply = True
        self.target.enterprise_id = "E_1"
        self.target.owner_info = dict(self.config["enterprise_policies"])
        self.target.owner_info["repositoryDeployKeySetting"] = "ENABLED"
        self.target.owner_info["allowPrivateRepositoryForkingSettingPolicyValue"] = "EVERYWHERE"
        self.gh.graphql.side_effect = [
            {}, {}, {"enterprise": {"ownerInfo": self.config["enterprise_policies"]}},
        ]
        self.gh.api.side_effect = lambda path, *args: {
            **self.config["organization"], **self.config["organization_observed"],
            **self.config["enterprise_actions"], **self.config["organization_actions"],
            **self.config["workflow_permissions"], **self.config["enterprise_security"],
            "approval_policy": "first_time_contributors",
        }
        self.target.policies()
        calls = self.gh.graphql.call_args_list
        self.assertIn("UpdateEnterpriseAllowPrivateRepositoryForkingSettingInput", calls[0].args[0])
        self.assertEqual(calls[0].args[1]["input"]["policyValue"], "ENTERPRISE_ORGANIZATIONS")
        self.assertIn("UpdateEnterpriseDeployKeySettingInput", calls[1].args[0])
        self.assertEqual(calls[1].args[1]["input"]["settingValue"], "DISABLED")

    def test_unsupported_organization_fields_are_not_sent_to_update_api(self):
        self.target.args.apply = True
        self.target.enterprise_id = "E_1"
        self.target.owner_info = dict(self.config["enterprise_policies"])
        self.gh.graphql.return_value = {
            "enterprise": {"ownerInfo": self.config["enterprise_policies"]},
        }
        reads = {
            "orgs/lab-org": dict(self.config["organization"],
                                 **self.config["organization_observed"]),
            "enterprises/lab-enterprise/actions/permissions": self.config["enterprise_actions"],
            "enterprises/lab-enterprise/actions/permissions/workflow": self.config["workflow_permissions"],
            "enterprises/lab-enterprise/code_security_and_analysis": self.config["enterprise_security"],
            "orgs/lab-org/actions/permissions": self.config["organization_actions"],
            "orgs/lab-org/actions/permissions/workflow": self.config["workflow_permissions"],
            "orgs/lab-org/actions/permissions/fork-pr-contributor-approval": {
                "approval_policy": "first_time_contributors",
            },
        }
        first_org_read = True

        def api(path, method="GET", body=None):
            nonlocal first_org_read
            if path == "orgs/lab-org" and method == "GET" and first_org_read:
                first_org_read = False
                return {}
            if method != "GET":
                self.assertFalse(set(body) & set(self.config["organization_observed"]))
                return {}
            return reads[path]
        self.gh.api.side_effect = api
        self.target.policies()
        self.assertEqual(self.target.changes, ["orgs/lab-org"])

    def test_workflow_install_is_atomic_and_never_force_pushes(self):
        self.target.args.apply = True
        self.gh.optional.return_value = None
        self.gh.api.side_effect = [
            {"tree": {"sha": "base-tree"}}, {"sha": "new-tree"}, {"sha": "new-commit"}, {},
        ]
        self.target.install_workflows("head")
        calls = self.gh.api.call_args_list
        self.assertEqual(calls[1].args[2]["base_tree"], "base-tree")
        self.assertEqual(len(calls[1].args[2]["tree"]), 2)
        self.assertEqual(calls[2].args[2]["parents"], ["head"])
        self.assertEqual(calls[3].args[2], {"sha": "new-commit", "force": False})

    def test_seed_pushes_complete_snapshot_without_shallow_history(self):
        original_run = setup.run
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            upstream, destination = root / "upstream", root / "destination.git"
            original_run(["git", "init", "--initial-branch", "main", str(upstream)])
            original_run(["git", "init", "--bare", str(destination)])
            (upstream / "README.md").write_text("Upstream content\n")
            original_run(["git", "add", "."], cwd=upstream)
            original_run([
                "git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                "commit", "-m", "Upstream",
            ], cwd=upstream)

            def local_run(args, **kwargs):
                args = list(args)
                if args[:2] == ["git", "clone"]:
                    args[-2] = upstream.as_uri()
                if args[0] == "git" and "push" in args:
                    args[-2] = str(destination)
                return original_run(args, **kwargs)

            with patch.object(setup, "run", side_effect=local_run):
                self.target.seed()
            git = ["git", "--git-dir", str(destination)]
            for name, content in setup.workflow_files().items():
                actual = original_run([*git, "show", f"main:{name}"])
                self.assertEqual(actual.encode(), content)
            self.assertEqual(
                original_run([*git, "show", "main:README.md"]),
                "Upstream content\n",
            )
            self.assertEqual(
                original_run([*git, "rev-list", "--count", "main"]).strip(), "1",
            )

    def test_cli_rejects_invalid_tenant_and_conflicting_modes(self):
        with self.assertRaises(SystemExit):
            setup.parse_args(["--tenant-id", "not-a-guid"])
        with self.assertRaises(SystemExit):
            setup.parse_args(["--check", "--apply"])

    def test_check_report_explicitly_requires_manual_verification(self):
        with tempfile.TemporaryDirectory() as directory:
            self.target.args.check = True
            self.target.args.report = str(Path(directory) / "report.json")
            for method in (
                "discover", "preflight", "policies", "identity", "copilot",
                "budgets", "repository", "codespaces",
            ):
                setattr(self.target, method, Mock())
            self.assertEqual(self.target.execute(), 2)
            report = json.loads(Path(self.target.args.report).read_text())
            self.assertEqual(report["status"], "manual_verification_required")
            self.assertTrue(report["manual_verification"])
            self.assertNotIn("MIRROR_TOKEN", report)


class CleanupWorkflowTests(unittest.TestCase):
    def run_cleanup(self, repos, failure=None, ignore_delete=False):
        workflow = (ROOT / "workflows/delete-other-repositories.yml").read_text()
        script = "\n".join(
            line[10:] for line in workflow.split("        run: |\n", 1)[1].splitlines()
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / "state.json"
            state.write_text(json.dumps({
                "repos": repos, "deleted": [], "failure": failure,
                "ignore_delete": ignore_delete,
            }))
            fake = root / "gh"
            fake.write_text(f"#!{sys.executable}\n" + """
import json, os, sys
from pathlib import Path
p = Path(os.environ["TEST_STATE"])
s = json.loads(p.read_text())
a = sys.argv[1:]
if "--paginate" in a:
    print("\\n".join(s["repos"]))
elif "DELETE" in a:
    repo = a[-1].removeprefix("/repos/")
    if s["failure"]:
        print(f"gh: rejected (HTTP {s['failure']})", file=sys.stderr)
        sys.exit(1)
    s["deleted"].append(repo)
    if not s["ignore_delete"]:
        s["repos"].remove(repo)
    p.write_text(json.dumps(s))
else:
    sys.exit(9)
""")
            fake.chmod(0o755)
            env = dict(
                os.environ, PATH=directory + os.pathsep + os.environ["PATH"],
                TEST_STATE=str(state), ORG="lab-org",
                PROTECTED_REPOSITORY="lab-org/microhack",
            )
            result = subprocess.run(
                ["bash", "-c", script], env=env, text=True, capture_output=True,
                check=False,
            )
            return result, json.loads(state.read_text())

    def test_deletes_all_other_repos_and_keeps_host_case_insensitively(self):
        result, state = self.run_cleanup([
            "LAB-ORG/MicroHack", "lab-org/lab-1", "lab-org/important",
        ])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(state["repos"], ["LAB-ORG/MicroHack"])
        self.assertEqual(state["deleted"], ["lab-org/lab-1", "lab-org/important"])

    def test_permission_failure_is_not_hidden(self):
        result, state = self.run_cleanup(["lab-org/microhack", "lab-org/lab-1"], 403)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HTTP 403", result.stderr)
        self.assertEqual(state["deleted"], [])

    def test_final_readback_catches_failed_deletion(self):
        result, _ = self.run_cleanup(
            ["lab-org/microhack", "lab-org/lab-1"], ignore_delete=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Repository still exists", result.stdout)

    def test_404_is_logged_but_remaining_inaccessible_repo_still_fails_verification(self):
        result, _ = self.run_cleanup(["lab-org/microhack", "lab-org/lab-1"], 404)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already absent or no longer accessible", result.stdout)
        self.assertIn("Repository still exists", result.stdout)


class SyncWorkflowTests(unittest.TestCase):
    def test_sync_preserves_both_tenant_workflows_and_uses_reference_upstream(self):
        workflow = (ROOT / "workflows/sync-upstream.yml").read_text()
        block = workflow.split("      - name: Sync main from upstream\n", 1)[1]
        script = "\n".join(
            line[10:] for line in block.split("        run: |\n", 1)[1].splitlines()
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "git.log"
            fake = root / "git"
            fake.write_text(f"#!{sys.executable}\n" + """
import json, os, sys
with open(os.environ["TEST_GIT_LOG"], "a") as f:
    f.write(json.dumps(sys.argv[1:]) + "\\n")
sys.exit(1 if sys.argv[1:2] == ["diff"] else 0)
""")
            fake.chmod(0o755)
            env = dict(os.environ, PATH=directory + os.pathsep + os.environ["PATH"],
                       TEST_GIT_LOG=str(log))
            result = subprocess.run(
                ["bash", "-e", "-c", script], env=env, capture_output=True,
                text=True, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            self.assertEqual(calls[0], [
                "remote", "add", "upstream", "https://github.com/microsoft/microhack.git",
            ])
            self.assertIn(["fetch", "upstream", "main"], calls)
            for name in ("sync-upstream.yml", "delete-other-repositories.yml"):
                self.assertIn(["checkout", "HEAD", "--", f".github/workflows/{name}"], calls)
            self.assertEqual(calls[-1], ["push", "origin", "main"])


if __name__ == "__main__":
    unittest.main()
