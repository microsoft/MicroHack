#!/usr/bin/env python3
"""Reconcile a disposable MicroHack EMU enterprise using gh and Azure CLI."""

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parent
API_VERSION = "2022-11-28"
POLICY_MUTATIONS = {
    "repositoryDeployKeySetting": "updateEnterpriseDeployKeySetting",
}
MANUAL_SETTINGS = [
    "Verify Entra SAML/OIDC SSO, SCIM provisioning, enterprise application group "
    "assignments and provisioning health in the target Azure tenant.",
    "Verify enterprise Copilot subscription/feature/model policies in GitHub "
    "settings. Public APIs cannot enroll an enterprise or set all Copilot policies.",
    "Verify Codespaces access, allowed repositories, machine types, retention and "
    "idle-timeout policies in GitHub settings. The access API has no GET endpoint.",
    "Verify MIRROR_TOKEN expiry and SSO authorization; existing secret values "
    "cannot be read back. Run both workflows manually after setup.",
    "Verify Azure billing linkage/payment method and premium-request/AI-credit "
    "spending controls; these are not implied by Actions/Codespaces budgets.",
]


class SetupError(RuntimeError):
    pass


class ApiError(SetupError):
    def __init__(self, method, path, result):
        self.status = None
        match = re.search(r"\(HTTP (\d+)\)", result.stderr)
        if match:
            self.status = int(match.group(1))
        super().__init__(f"{method} {path}: {result.stderr.strip()}")


def run(args, *, data=None, env=None, cwd=None):
    result = subprocess.run(
        args, input=data, text=True, capture_output=True, env=env, cwd=cwd,
        check=False,
    )
    if result.returncode:
        raise SetupError(f"{args[0]} {args[1]} failed: {result.stderr.strip()}")
    return result.stdout


class GitHub:
    def __init__(self, env=None):
        self.env = env

    def api(self, path, method="GET", body=None):
        args = [
            "gh", "api", "--hostname", "github.com", "--method", method, path,
            "-H", "Accept: application/vnd.github+json",
            "-H", f"X-GitHub-Api-Version: {API_VERSION}",
        ]
        data = None
        if body is not None:
            args += ["--input", "-"]
            data = json.dumps(body)
        result = subprocess.run(
            args, input=data, text=True, capture_output=True, env=self.env,
            check=False,
        )
        if result.returncode:
            raise ApiError(method, path, result)
        return json.loads(result.stdout) if result.stdout.strip() else None

    def optional(self, path):
        try:
            return self.api(path)
        except ApiError as error:
            if error.status != 404:
                raise
            return None

    def pages(self, path, key=None):
        # gh follows Link headers, including the cursor used by external groups.
        output = run([
            "gh", "api", "--hostname", "github.com", "--paginate", path,
            "-H", f"X-GitHub-Api-Version: {API_VERSION}",
        ], env=self.env)
        decoder = json.JSONDecoder()
        rows = []
        while output.strip():
            page, end = decoder.raw_decode(output.lstrip())
            output = output.lstrip()[end:]
            rows.extend(page[key] if key else page)
        return rows

    def graphql(self, query, variables=None):
        result = self.api("graphql", "POST", {
            "query": query, "variables": variables or {},
        })
        if result.get("errors"):
            raise SetupError(f"GraphQL: {json.dumps(result['errors'])}")
        return result["data"]

    def budget_pages(self, path):
        rows = []
        page = 1
        while True:
            result = self.api(f"{path}?per_page=100&page={page}")
            rows.extend(result["budgets"])
            if not result.get("has_next_page", False):
                return rows
            if not result["budgets"]:
                raise SetupError("Budget API reported another page after an empty page.")
            page += 1


def subset(actual, desired):
    return all(actual.get(key) == value for key, value in desired.items())


def unique(items, label):
    if len(items) != 1:
        raise SetupError(f"Expected exactly one {label}; found {len(items)}.")
    return items[0]


def azure_groups(tenant_id, names):
    token_result = json.loads(run([
        "az", "account", "get-access-token", "--tenant", tenant_id,
        "--resource", "https://graph.microsoft.com", "--output", "json",
    ]))
    if token_result["tenant"].lower() != tenant_id.lower():
        raise SetupError("Azure CLI returned a token for a different tenant.")
    groups = {}
    for name in names:
        query = urlencode({
            "$filter": f"displayName eq '{name}'", "$select": "id,displayName",
        })
        request = Request(
            f"https://graph.microsoft.com/v1.0/groups?{query}",
            headers={"Authorization": f"Bearer {token_result['accessToken']}"},
        )
        try:
            with urlopen(request, timeout=60) as response:
                result = json.load(response)
        except HTTPError as error:
            raise SetupError(
                f"Microsoft Graph group lookup failed (HTTP {error.code}); "
                "the Azure login needs Group.Read.All or Directory.Read.All."
            ) from error
        groups[name] = unique(result["value"], f"Entra group named {name}")["id"]
    return groups


def workflow_files():
    return {
        f".github/workflows/{path.name}": path.read_bytes()
        for path in sorted((ROOT / "workflows").glob("*.yml"))
    }


class Setup:
    def __init__(self, gh, args, config):
        self.gh, self.args, self.config = gh, args, config
        self.changes = []
        self.manual = list(MANUAL_SETTINGS)
        self.org = args.organization
        self.enterprise = args.enterprise
        self.repo = None
        self.repo_exists = False
        self.enterprise_id = None
        self.groups = {}
        self.external_groups = {}

    def change(self, label, callback):
        self.changes.append(label)
        print(f"{'APPLY' if self.args.apply else 'DRIFT'}: {label}")
        if self.args.apply:
            callback()

    def ensure(self, path, desired, method="PUT"):
        current = self.gh.api(path)
        if not subset(current, desired):
            payload = (
                {key: value for key, value in desired.items() if current.get(key) != value}
                if method == "PATCH" else desired
            )
            self.change(path, lambda: self.gh.api(path, method, payload))
        if self.args.apply and not subset(self.gh.api(path), desired):
            raise SetupError(f"Read-back verification failed: {path}")

    def discover(self):
        if not self.org:
            orgs = self.gh.pages("user/orgs?per_page=100")
            self.org = unique(orgs, "GitHub organization")["login"]
        if not self.enterprise:
            data = self.gh.graphql(
                "{ viewer { enterprises(first:100) { nodes { slug } } } }"
            )
            self.enterprise = unique(
                data["viewer"]["enterprises"]["nodes"], "GitHub enterprise",
            )["slug"]
        fields = " ".join(self.config["enterprise_policies"])
        data = self.gh.graphql(
            "query($slug:String!){ enterprise(slug:$slug){ id ownerInfo { "
            + fields + " } } }", {"slug": self.enterprise},
        )
        enterprise = data["enterprise"]
        if enterprise is None or enterprise["ownerInfo"] is None:
            raise SetupError("The authenticated account must be an enterprise owner.")
        self.enterprise_id = enterprise["id"]
        self.owner_info = enterprise["ownerInfo"]
        organizations = []
        cursor = None
        while True:
            result = self.gh.graphql(
                "query($slug:String!,$cursor:String){ enterprise(slug:$slug){ "
                "organizations(first:100,after:$cursor){ nodes { login } "
                "pageInfo { hasNextPage endCursor } } } }",
                {"slug": self.enterprise, "cursor": cursor},
            )["enterprise"]["organizations"]
            organizations.extend(row["login"].lower() for row in result["nodes"])
            if not result["pageInfo"]["hasNextPage"]:
                break
            cursor = result["pageInfo"]["endCursor"]
        if self.org.lower() not in organizations:
            raise SetupError("The organization does not belong to this enterprise.")
        self.repo = f"{self.org}/{self.config['repository']}"
        membership = self.gh.api(f"user/memberships/orgs/{self.org}")
        if membership["role"] != "admin" or membership["state"] != "active":
            raise SetupError("The authenticated account must be an active org owner.")
        if self.args.apply:
            if self.args.confirm_organization != self.org:
                raise SetupError(
                    f"Apply requires --confirm-organization {self.org}. This enables "
                    "permanent nightly deletion of EVERY other organization repository."
                )
            if not self.args.tenant_id:
                raise SetupError("--tenant-id is required for apply.")
        print(f"Target: enterprise={self.enterprise}, organization={self.org}, "
              f"repository={self.repo}, azure_tenant={self.args.tenant_id}")

    def preflight(self):
        group_names = {team["group"] for team in self.config["teams"].values()}
        azure = None
        if self.args.tenant_id and not self.args.skip_azure_verification:
            azure = azure_groups(self.args.tenant_id, sorted(group_names))
        else:
            if self.args.apply:
                raise SetupError("Azure tenant verification cannot be skipped on apply.")
            self.manual.append("Azure tenant/group ownership has NOT been verified.")
        for name in sorted(group_names):
            query = urlencode({"filter": f'displayName eq "{name}"'})
            result = self.gh.api(
                f"scim/v2/enterprises/{self.enterprise}/Groups?{query}"
            )
            group = unique(
                [g for g in result["Resources"] if g["displayName"] == name],
                f"provisioned SCIM group {name}",
            )
            if azure and group.get("externalId", "").lower() != azure[name].lower():
                raise SetupError(f"SCIM group {name} does not match the Azure tenant.")
            self.groups[name] = group
        external = self.gh.pages(
            f"orgs/{self.org}/external-groups?per_page=100", "groups",
        )
        for name in group_names:
            self.external_groups[name] = unique(
                [g for g in external if g["group_name"] == name],
                f"organization external group {name}",
            )
        self.gh.api(f"enterprises/{self.enterprise}/copilot/billing/seats")
        self.gh.api(f"enterprises/{self.enterprise}/settings/billing/budgets")
        repo = self.gh.optional(f"repos/{self.repo}")
        self.repo_exists = repo is not None
        if repo:
            if repo["archived"]:
                raise SetupError("The MicroHack repository is archived.")
            if repo["default_branch"] != self.config["branch"]:
                raise SetupError("Expected MicroHack default branch main; resolve manually.")
            marker = self.gh.optional(
                f"repos/{self.repo}/actions/variables/AZURE_TENANT_ID"
            )
            if (marker and self.args.tenant_id
                    and marker["value"].lower() != self.args.tenant_id.lower()):
                raise SetupError("Repository AZURE_TENANT_ID belongs to another tenant.")
        if self.args.apply:
            self.validate_mirror_token()

    def validate_mirror_token(self):
        token = os.environ.get("MIRROR_TOKEN")
        if not token:
            if (self.repo_exists and self.gh.optional(
                    f"repos/{self.repo}/actions/secrets/MIRROR_TOKEN") is not None):
                message = (
                    "Reusing existing MIRROR_TOKEN: only secret existence is verified; "
                    "validate its scopes, SSO authorization and expiry through workflow runs."
                )
                print(f"CREDENTIAL: {message}")
                self.manual.append(message)
                return
            raise SetupError(
                "Provide MIRROR_TOKEN in the environment, or create the target "
                "repository and store its MIRROR_TOKEN secret with gh secret set."
            )
        env = dict(os.environ, GH_TOKEN=token)
        headers = run(
            ["gh", "api", "--hostname", "github.com", "--include", "user"], env=env,
        )
        match = re.search(r"^x-oauth-scopes:\s*(.*)$", headers, re.I | re.M)
        scopes = {s.strip() for s in match.group(1).split(",")} if match else set()
        if not {"repo", "workflow", "delete_repo", "admin:org"} <= scopes:
            raise SetupError(
                "MIRROR_TOKEN must be a classic PAT with repo, workflow, "
                "delete_repo and admin:org scopes."
            )
        membership = GitHub(env).api(f"user/memberships/orgs/{self.org}")
        if membership["role"] != "admin" or membership["state"] != "active":
            raise SetupError("MIRROR_TOKEN must belong to an active target org owner.")

    def policies(self):
        desired = self.config["enterprise_policies"]
        for field, value in desired.items():
            if field == "allowPrivateRepositoryForkingSettingPolicyValue":
                continue
            payload = {"enterpriseId": self.enterprise_id, "settingValue": value}
            matches = self.owner_info[field] == value
            if field == "allowPrivateRepositoryForkingSetting":
                payload["policyValue"] = desired[field + "PolicyValue"]
                matches = matches and self.owner_info[field + "PolicyValue"] == payload["policyValue"]
            if matches:
                continue
            mutation = POLICY_MUTATIONS.get(field, "updateEnterprise" + field[0].upper() + field[1:])
            input_type = mutation[0].upper() + mutation[1:] + "Input"
            query = (
                f"mutation($input:{input_type}!){{ {mutation}(input:$input)"
                "{ clientMutationId } }"
            )
            self.change(
                f"enterprise policy {field}={value}",
                lambda q=query, p=payload: self.gh.graphql(q, {"input": p}),
            )
        if self.args.apply:
            fields = " ".join(desired)
            actual = self.gh.graphql(
                "query($slug:String!){ enterprise(slug:$slug){ ownerInfo { "
                + fields + " } } }", {"slug": self.enterprise},
            )["enterprise"]["ownerInfo"]
            if not subset(actual, desired):
                raise SetupError("Enterprise policy read-back verification failed.")
        ent = f"enterprises/{self.enterprise}"
        org = f"orgs/{self.org}"
        for path, key, method in [
            (f"{ent}/actions/permissions", "enterprise_actions", "PUT"),
            (f"{ent}/actions/permissions/workflow", "workflow_permissions", "PUT"),
            (f"{ent}/code_security_and_analysis", "enterprise_security", "PATCH"),
            (org, "organization", "PATCH"),
            (f"{org}/actions/permissions", "organization_actions", "PUT"),
            (f"{org}/actions/permissions/workflow", "workflow_permissions", "PUT"),
        ]:
            self.ensure(path, self.config[key], method)
        self.ensure(
            f"{org}/actions/permissions/fork-pr-contributor-approval",
            {"approval_policy": "first_time_contributors"},
        )
        observed = self.gh.api(org)
        for field, value in self.config["organization_observed"].items():
            if observed.get(field) != value:
                self.manual.append(
                    f"Organization policy {field}: expected {value!r}, "
                    f"found {observed.get(field)!r}. Set this in GitHub settings; "
                    "the public organization update API does not support it."
                )

    def identity(self):
        ent = f"enterprises/{self.enterprise}"
        for name, group in self.groups.items():
            path = f"{ent}/teams/{quote(name.lower())}"
            team = self.gh.optional(path)
            desired = {"group_id": group["id"]}
            if team is None:
                self.change(
                    f"create enterprise team {name} linked to SCIM",
                    lambda n=name, d=desired: self.gh.api(f"{ent}/teams", "POST", {
                        "name": n, "organization_selection_type": "selected", **d,
                    }),
                )
            elif not subset(team, desired):
                self.change(
                    f"link enterprise team {name} to SCIM",
                    lambda p=path, d=desired: self.gh.api(p, "PATCH", d),
                )
            if self.args.apply and not subset(self.gh.api(path), desired):
                raise SetupError(f"SCIM linkage verification failed for {name}.")
        for slug, settings in self.config["teams"].items():
            path = f"orgs/{self.org}/teams/{slug}"
            team = self.gh.optional(path)
            if team is None:
                self.change(
                    f"create organization team {slug}",
                    lambda s=slug: self.gh.api(f"orgs/{self.org}/teams", "POST", {
                        "name": s, "privacy": "secret",
                    }),
                )
            desired = {"group_id": self.external_groups[settings["group"]]["group_id"]}
            if team is not None or self.args.apply:
                try:
                    connections = self.gh.api(f"{path}/external-groups")["groups"]
                except ApiError as error:
                    if (error.status != 400
                            or "cannot be externally managed since it has explicit members" not in str(error)):
                        raise
                    login = self.gh.api("user")["login"]
                    members = self.gh.pages(f"{path}/members?per_page=100")
                    if [member["login"] for member in members] != [login]:
                        raise SetupError(
                            f"Team {slug} has explicit members other than its bootstrap "
                            "owner. Review and remove those memberships before SCIM linking."
                        ) from error
                    self.change(
                        f"remove bootstrap owner membership from {slug} before SCIM linking",
                        lambda p=path, user=login: self.gh.api(f"{p}/memberships/{user}", "DELETE"),
                    )
                    connections = []
            else:
                connections = []
            if [g["group_id"] for g in connections] != [desired["group_id"]]:
                self.change(
                    f"link {slug} to {settings['group']}",
                    lambda p=path, d=desired: self.gh.api(f"{p}/external-groups", "PATCH", d),
                )
            if self.args.apply:
                actual = self.gh.api(f"{path}/external-groups")["groups"]
                if [g["group_id"] for g in actual] != [desired["group_id"]]:
                    raise SetupError(f"External group linkage failed for {slug}.")

    def copilot(self):
        team_name = self.config["copilot"]["enterprise_team"]
        team_path = f"enterprises/{self.enterprise}/teams/{quote(team_name.lower())}"
        team = self.gh.optional(team_path)
        seats = self.gh.pages(
            f"enterprises/{self.enterprise}/copilot/billing/seats?per_page=100", "seats",
        )
        members = self.gh.pages(f"{team_path}/memberships?per_page=100") if team else []
        active = {
            seat["assignee"]["login"].lower()
            for seat in seats
            if (seat.get("assigning_team") or {}).get("id") == (team or {}).get("id")
            and not seat.get("pending_cancellation_date")
        }
        missing = [m["login"] for m in members if m["login"].lower() not in active]
        # Reassert team licensing even for empty groups: seat listings alone cannot
        # prove that future provisioned members will receive a license.
        if self.args.apply or missing or team is None:
            self.change(
                f"ensure enterprise Copilot entitlement for {team_name} "
                f"({len(missing)} current members missing active team seats)",
                lambda: self.gh.api(
                    f"enterprises/{self.enterprise}/copilot/billing/selected_enterprise_teams",
                    "POST", {"selected_enterprise_teams": [team_name]},
                ),
            )
        if self.args.apply:
            actual = self.gh.pages(
                f"enterprises/{self.enterprise}/copilot/billing/seats?per_page=100", "seats",
            )
            team_id = self.gh.api(team_path)["id"]
            assigned = {
                s["assignee"]["login"].lower() for s in actual
                if (s.get("assigning_team") or {}).get("id") == team_id
                and not s.get("pending_cancellation_date")
            }
            members = self.gh.pages(f"{team_path}/memberships?per_page=100")
            if any(m["login"].lower() not in assigned for m in members):
                raise SetupError("Copilot team assignment has not converged; rerun after SCIM sync.")
        unrelated = {
            s["assignee"]["login"] for s in seats
            if not s.get("pending_cancellation_date")
            and (s.get("assigning_team") or {}).get("name") != team_name
        }
        if unrelated:
            self.manual.append(
                f"{len(unrelated)} active Copilot users have grants outside {team_name}; "
                "review direct/other-team grants. They are NOT automatically revoked."
            )
        if not members and not self.args.apply:
            self.manual.append(
                f"{team_name} is empty or absent: seat listings cannot prove "
                "its team-level Copilot entitlement. Apply reasserts it."
            )
        settings = self.gh.api(f"orgs/{self.org}/copilot/billing")
        desired = {k: v for k, v in self.config["copilot"].items()
                   if k not in ("enterprise_team", "coding_agent_repositories")}
        for field, value in desired.items():
            if settings.get(field) != value:
                self.manual.append(
                    f"Organization-local Copilot policy {field}: baseline {value!r}, "
                    f"found {settings.get(field)!r}. This is not effective-policy "
                    "drift for enterprise-team-assigned licenses. Verify the enterprise "
                    "policy (Enabled everywhere), or Policies for enterprise-assigned "
                    "users when the enterprise delegates to organizations; "
                    "the organization billing API does not expose effective enterprise policies."
                )
        self.ensure(
            f"orgs/{self.org}/copilot/coding-agent/permissions",
            {"enabled_repositories": self.config["copilot"]["coding_agent_repositories"]},
        )

    def budgets(self):
        path = f"enterprises/{self.enterprise}/settings/billing/budgets"
        current = self.gh.budget_pages(path)
        login = self.gh.api("user")["login"]
        for product, amount in self.config["budgets_usd"].items():
            matches = [b for b in current if b["budget_scope"] == "enterprise"
                       and b["budget_type"] == "ProductPricing"
                       and b["budget_product_sku"] == product
                       and b.get("budget_entity_name", "").lower() == self.enterprise.lower()]
            if len(matches) > 1:
                raise SetupError(f"Duplicate enterprise {product} budgets; resolve manually.")
            recipients = sorted(set(
                self.args.budget_alert_login
                or (matches[0]["budget_alerting"]["alert_recipients"] if matches else [])
                or [login]
            ))
            desired = {
                "budget_amount": amount, "prevent_further_usage": True,
                "budget_alerting": {"will_alert": True, "alert_recipients": sorted(recipients)},
            }
            actual = matches[0] if matches else None
            if actual:
                actual = dict(actual, budget_alerting={
                    **actual["budget_alerting"],
                    "alert_recipients": sorted(actual["budget_alerting"]["alert_recipients"]),
                })
            if actual is None:
                self.change(
                    f"create enterprise {product} budget ${amount}/month",
                    lambda p=product, d=desired: self.gh.api(path, "POST", {
                        **d, "budget_scope": "enterprise",
                        "budget_entity_name": self.enterprise,
                        "budget_type": "ProductPricing", "budget_product_sku": p,
                    }),
                )
            elif not subset(actual, desired):
                self.change(
                    f"update enterprise {product} budget ${amount}/month",
                    lambda b=actual, d=desired: self.gh.api(f"{path}/{b['id']}", "PATCH", d),
                )
            if self.args.apply:
                rows = self.gh.budget_pages(path)
                verified = [b for b in rows if b["budget_scope"] == "enterprise"
                            and b["budget_product_sku"] == product
                            and b["budget_type"] == "ProductPricing"]
                if not any(
                    b["budget_amount"] == amount and b["prevent_further_usage"]
                    and b["budget_alerting"]["will_alert"]
                    and sorted(b["budget_alerting"]["alert_recipients"]) == sorted(recipients)
                    for b in verified
                ):
                    raise SetupError(f"Budget read-back verification failed for {product}.")

    def repository(self):
        path = f"repos/{self.repo}"
        if not self.repo_exists:
            self.change(
                f"create internal {self.repo}",
                lambda: self.gh.api(f"orgs/{self.org}/repos", "POST", {
                    "name": self.config["repository"], "visibility": "internal",
                    "auto_init": False,
                }),
            )
        if not self.repo_exists and not self.args.apply:
            self.change("seed main from microsoft/MicroHack and install both workflows", lambda: None)
            self.change("set MIRROR_TOKEN and AZURE_TENANT_ID; enable repository Actions", lambda: None)
            return
        self.ensure(path, {"visibility": "internal", "allow_forking": True}, "PATCH")
        # Configure credentials before publishing scheduled workflows.
        if self.args.apply and os.environ.get("MIRROR_TOKEN"):
            self.change(
                "store/refresh repository secret MIRROR_TOKEN",
                lambda: run([
                    "gh", "secret", "set", "MIRROR_TOKEN", "--repo", self.repo,
                ], data=os.environ["MIRROR_TOKEN"]),
            )
        elif not self.args.apply and self.gh.optional(f"{path}/actions/secrets/MIRROR_TOKEN") is None:
            self.change("set repository secret MIRROR_TOKEN", lambda: None)
        try:
            ref = self.gh.optional(f"{path}/git/ref/heads/main")
        except ApiError as error:
            if error.status != 409 or self.gh.api(path)["size"] != 0:
                raise
            ref = None
        if ref is None:
            self.change("seed main from microsoft/MicroHack with setup workflows", self.seed)
        else:
            self.install_workflows(ref["object"]["sha"])
        for slug, settings in self.config["teams"].items():
            teams = self.gh.pages(f"{path}/teams?per_page=100")
            if not any(t["slug"] == slug and t["permission"] == settings["permission"] for t in teams):
                self.change(
                    f"grant {slug} {settings['permission']} on {self.repo}",
                    lambda s=slug, p=settings["permission"]: self.gh.api(
                        f"orgs/{self.org}/teams/{s}/repos/{self.repo}",
                        "PUT", {"permission": p},
                    ),
                )
        for suffix, key in [
            ("permissions", "repository_actions"),
            ("permissions/workflow", "workflow_permissions"),
        ]:
            self.ensure(f"{path}/actions/{suffix}", self.config[key])
        if self.args.tenant_id:
            marker_path = f"{path}/actions/variables/AZURE_TENANT_ID"
            marker = self.gh.optional(marker_path)
            if marker is None or marker["value"] != self.args.tenant_id:
                self.change(
                    "set repository variable AZURE_TENANT_ID",
                    lambda: self.gh.api(
                        marker_path if marker else f"{path}/actions/variables",
                        "PATCH" if marker else "POST",
                        {"name": "AZURE_TENANT_ID", "value": self.args.tenant_id},
                    ),
                )
        if self.args.apply:
            self.verify_workflows()
            self.gh.api(f"{path}/actions/secrets/MIRROR_TOKEN")
            teams = self.gh.pages(f"{path}/teams?per_page=100")
            for slug, settings in self.config["teams"].items():
                if not any(t["slug"] == slug and t["permission"] == settings["permission"] for t in teams):
                    raise SetupError(f"Repository permission verification failed for {slug}.")
            marker = self.gh.api(f"{path}/actions/variables/AZURE_TENANT_ID")
            if marker["value"] != self.args.tenant_id:
                raise SetupError("Azure tenant marker read-back verification failed.")

    def seed(self):
        with tempfile.TemporaryDirectory(prefix="microhack-ghe-") as directory:
            checkout = Path(directory) / "microhack"
            run([
                "git", "clone", "--depth", "1", "--branch", "main",
                f"https://github.com/{self.config['upstream']}.git", str(checkout),
            ])
            # Seed a snapshot, not a shallow history that the destination may reject.
            run(["git", "checkout", "--orphan", "microhack-seed"], cwd=checkout)
            for name, content in workflow_files().items():
                target = checkout / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
            run(["git", "add", ".github/workflows"], cwd=checkout)
            staged = run(["git", "diff", "--cached", "--name-only"], cwd=checkout)
            if staged:
                run([
                    "git", "-c", "user.name=github-actions[bot]", "-c",
                    "user.email=github-actions[bot]@users.noreply.github.com",
                    "commit", "-m", "Configure MicroHack tenant workflows",
                ], cwd=checkout)
            run([
                "git", "-c", "credential.helper=", "-c",
                "credential.helper=!gh auth git-credential", "push",
                f"https://github.com/{self.repo}.git", "HEAD:refs/heads/main",
            ], cwd=checkout)

    def install_workflows(self, head):
        changed = []
        for name, content in workflow_files().items():
            actual = self.gh.optional(f"repos/{self.repo}/contents/{name}?ref=main")
            if actual is None or base64.b64decode(actual["content"]) != content:
                changed.append({"path": name, "mode": "100644", "type": "blob",
                                "content": content.decode("utf-8")})
        if not changed:
            return

        def commit():
            path = f"repos/{self.repo}/git"
            parent = self.gh.api(f"{path}/commits/{head}")
            tree = self.gh.api(f"{path}/trees", "POST", {
                "base_tree": parent["tree"]["sha"], "tree": changed,
            })
            new = self.gh.api(f"{path}/commits", "POST", {
                "message": "Configure MicroHack tenant workflows",
                "tree": tree["sha"], "parents": [head],
            })
            self.gh.api(f"{path}/refs/heads/main", "PATCH", {
                "sha": new["sha"], "force": False,
            })
        self.change("install reference sync and nightly deletion workflows", commit)

    def verify_workflows(self):
        for name, content in workflow_files().items():
            actual = self.gh.api(f"repos/{self.repo}/contents/{name}?ref=main")
            if base64.b64decode(actual["content"]) != content:
                raise SetupError(f"Workflow verification failed: {name}")

    def codespaces(self):
        visibility = self.config["codespaces_access"]
        self.change(
            f"reassert Codespaces access={visibility} (no read API available)",
            lambda: self.gh.api(f"orgs/{self.org}/codespaces/access", "PUT", {
                "visibility": visibility,
            }),
        )

    def execute(self):
        self.discover()
        self.preflight()
        self.policies()
        self.identity()
        self.copilot()
        self.budgets()
        self.repository()
        self.codespaces()
        for item in self.manual:
            print(f"MANUAL: {item}")
        print(f"\n{len(self.changes)} planned/applied operations; "
              f"{len(self.manual)} manual verification items. No repositories deleted by setup.")
        if self.args.report:
            Path(self.args.report).write_text(json.dumps({
                "enterprise": self.enterprise, "organization": self.org,
                "azure_tenant_id": self.args.tenant_id,
                "mode": "apply" if self.args.apply else "check" if self.args.check else "plan",
                "operations": self.changes, "manual_verification": self.manual,
                "status": "manual_verification_required",
            }, indent=2) + "\n")
        return 2 if self.args.apply or self.args.check else 0


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--check", action="store_true")
    parser.add_argument("--organization")
    parser.add_argument("--enterprise")
    parser.add_argument("--tenant-id", type=lambda value: str(uuid.UUID(value)))
    parser.add_argument("--confirm-organization")
    parser.add_argument("--budget-alert-login", action="append")
    parser.add_argument("--skip-azure-verification", action="store_true",
                        help="Read-only audit only; always reports incomplete tenant validation.")
    parser.add_argument("--report", help="Write a JSON report outside the repository.")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    try:
        config = json.loads((ROOT / "baseline.json").read_text())
        return Setup(GitHub(), args, config).execute()
    except (SetupError, FileNotFoundError, PermissionError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
