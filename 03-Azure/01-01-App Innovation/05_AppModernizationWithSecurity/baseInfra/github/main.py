"""GitHub organization access check (GH CLI auth only).

Purpose: Verify that the currently logged-in GitHub CLI user has access to the
organization specified by `ORG_NAME` in `.env` (or environment). Output kept
intentionally minimal for scripting.

Exit codes:
 0 success (org accessible)
 1 configuration / auth / general failure
 2 organization not found or no access

Environment:
    ORG_NAME (required) – target organization login.
    SOURCE_REPO (optional) – public source repo 'owner/name' to copy into org.
    USERS_FILE (optional) – YAML file of users to invite (default users.yaml) (login required per entry)

Prerequisites:
    - GitHub CLI installed & authenticated (`gh auth login`).
"""

from __future__ import annotations

import os
import sys
import shutil
import subprocess
import tempfile
from pathlib import Path
from contextlib import contextmanager

from dotenv import load_dotenv  # hard requirement
from github import Github, GithubException, Auth
from git import Repo, GitCommandError  # GitPython
import yaml

GREEN = "\x1b[32m"
RESET = "\x1b[0m"


def print_step(message: str, end: str = " ") -> None:
    print(f"{message} ", end=end, flush=True)


def print_ok() -> None:
    check = "✔"
    if sys.stdout.isatty():
        print(f"{GREEN}{check}{RESET}")
    else:
        print(check)



__all__ = [
    "main",
]


@contextmanager
def _tempdir(prefix: str):
    path = tempfile.mkdtemp(prefix=prefix)
    try:
        yield path
    finally:
        shutil.rmtree(path, ignore_errors=True)


def _sync_repo_contents(source_full: str, dest_full: str, default_branch: str, token: str) -> None:
    """Clone public source repo and push its default branch to destination.

    The destination is assumed empty. We only push the default branch to keep
    operation quick; tags and additional branches can be added manually later
    if needed. History is preserved (full clone) to retain commit lineage.
    """
    with _tempdir(prefix="gh-copy-") as tmp:
        local_src = Path(tmp) / "src"
        Repo.clone_from(f"https://github.com/{source_full}.git", local_src)
        repo = Repo(local_src)
        dest_url = f"https://x-access-token:{token}@github.com/{dest_full}.git"
        if "dest" in repo.remotes:
            repo.delete_remote("dest")
        repo.create_remote("dest", dest_url)
        try:
            repo.remotes.dest.push(refspec=f"{default_branch}:{default_branch}")
        except GitCommandError as exc:
            raise RuntimeError(f"git push failed: {exc}") from exc


def load_configuration() -> str:
    """Load required ORG_NAME (fail fast if missing).

    The `.env` load is best-effort; if python-dotenv is missing, environment
    variables set externally still work.
    """
    load_dotenv()
    org = os.getenv("ORG_NAME")
    if not org:
        print("ERROR: ORG_NAME not set in environment or .env", file=sys.stderr)
        sys.exit(1)
    return org


def _ensure_gh_cli() -> None:
    if shutil.which("gh") is None:
        print("ERROR: GitHub CLI 'gh' not found in PATH. Install from https://cli.github.com/", file=sys.stderr)
        sys.exit(1)
    status = subprocess.run(["gh", "auth", "status"], capture_output=True, text=True)
    # gh exits 0 even when already logged in; non-zero when no auth configured
    if status.returncode != 0 or "Logged in" not in status.stdout:
        print("ERROR: 'gh auth status' indicates you are not logged in. Run 'gh auth login' first.", file=sys.stderr)
        combined = (status.stderr + "\n" + status.stdout).strip()
        if combined:
            print(combined)
        sys.exit(1)


def _retrieve_token() -> str:
    proc = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True)
    if proc.returncode != 0:
        print("ERROR: Failed to retrieve token via 'gh auth token'.", file=sys.stderr)
        print(proc.stderr.strip())
        sys.exit(1)
    token = proc.stdout.strip()
    if not token:
        print("ERROR: Received empty token from GitHub CLI.", file=sys.stderr)
        sys.exit(1)
    return token


def authenticate(token: str) -> Github:
    """Authenticate and return a Github client instance (non-deprecated)."""
    return Github(auth=Auth.Token(token), per_page=100)


def validate_org_access(client: Github, org_name: str) -> None:
    print_step(f"Checking organization {org_name} exists")
    try:
        org = client.get_organization(org_name)
        _ = org.id  # force attribute access
    except GithubException as exc:
        print(f"ERROR ({exc.status})")
        sys.exit(2)
    print_ok()


def main() -> None:
    org_name = load_configuration()
    _ensure_gh_cli()
    token = _retrieve_token()
    client = authenticate(token)
    validate_org_access(client, org_name)
    source_repo_slug = os.getenv("SOURCE_REPO")
    if source_repo_slug:
        _ensure_org_template_repo(client, org_name, source_repo_slug, token)
    users_file = os.getenv("USERS_FILE", "users.yaml")
    if os.path.isfile(users_file):
        stats = _handle_users_file(users_file, client, org_name, source_repo_slug)
        if stats:
            print_step("---")
            print_ok()
            print_step("Run summary")
            print(
                f"Members invited: {stats['invited']} | Already members: {stats['already_members']} | "
                f"Per-user repos created: {stats['repos_created']} | Repos skipped: {stats['repos_skipped']}"
            )
            print_ok()


def _handle_users_file(path: str, client: Github, org_name: str, source_repo_slug: str | None):
    """Process users file: invite users and create per-user repos.

    Accepts simplified format: list of usernames (strings) or legacy list of
    dicts with a 'login' key. Returns a dict of summary statistics.
    """
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = yaml.safe_load(fh) or []
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR reading users file {path}: {exc}")
        return
    if not isinstance(data, list):
        print(f"Users file {path} root must be a list; skipping")
        return
    try:
        org = client.get_organization(org_name)
    except GithubException as exc:
        print(f"ERROR (org reload {exc.status})")
        return
    existing = set()
    try:
        for m in org.get_members():
            existing.add(m.login.lower())
    except GithubException:
        pass
    print_step(f"Processing users file {path} ({len(data)} entries)")
    print_ok()
    template_repo_name = source_repo_slug.split("/", 1)[-1] if source_repo_slug else None
    # Precompute valid user entries for remaining counter
    # Support new simplified format: list of usernames (strings) OR legacy dicts with 'login'
    def _extract_login(entry):
        if isinstance(entry, str):
            return entry.strip()
        if isinstance(entry, dict):
            return (entry.get("login") or "").strip()
        return ""
    valid_entries = [e for e in data if _extract_login(e)]
    order_map = {id(e): idx for idx, e in enumerate(valid_entries)}
    total_valid = len(valid_entries)
    # Copilot automation removed: script no longer manages Copilot seats or subscription policies.
    invited_count = 0
    already_members_count = 0
    repos_created = 0
    repos_skipped = 0

    for entry in data:
        login_raw = _extract_login(entry)
        if not login_raw:
            print_step("Skipping entry (login missing)")
            print_ok()
            continue
        resolved_login = login_raw
        order_index = order_map.get(id(entry), 0)
        remaining = total_valid - order_index - 1
        # Delimiter & per-user header
        print_step("---")
        print_ok()
        print_step(f"Processing {resolved_login} ({remaining} remaining)")
        print_ok()
        invite_needed = resolved_login.lower() not in existing
        if invite_needed:
            try:
                _invite(org.login, resolved_login, client=client)
                invited_count += 1
            except Exception as exc:  # noqa: BLE001
                print(f"Invite failed for {resolved_login}: {exc}")
                continue
        else:
            already_members_count += 1
        if template_repo_name:
            per_name = f"{resolved_login}-{template_repo_name}"
            try:
                try:
                    org.get_repo(per_name)
                    print_step(f"Skipping existing per-user repo {per_name}")
                    print_ok()
                    repos_skipped += 1
                except GithubException:
                    # Does not exist; proceed to generate
                    # Server-side template generation (snapshot: no original history preserved)
                    print_step(f"Generating per-user repo {per_name} from template")
                    try:
                        _generate_from_template(org.login, template_repo_name, per_name, True, client)
                        print_ok()
                        repos_created += 1
                    except GithubException as exc:  # noqa: PERF401
                        print(f"ERROR (generate {per_name}: {exc.status})")
                        continue
                    # Fetch repo object after generation for collaborator assignment
                    try:
                        new_repo = org.get_repo(per_name)
                    except GithubException as exc:
                        print(f"ERROR (post-generate fetch {per_name}: {exc.status})")
                        continue
                    try:
                        print_step(f"Granting access to {resolved_login} on {per_name}")
                        new_repo.add_to_collaborators(resolved_login, permission="push")
                        print_ok()
                    except GithubException as exc:  # pragma: no cover
                        print(f"ERROR (collaborator add {resolved_login}: {exc.status})")
            except GithubException as exc:
                print(f"Repo creation failed for {resolved_login}: {exc.status}")
        # Copilot seat handling intentionally omitted.
    return {
        "invited": invited_count,
        "already_members": already_members_count,
        "repos_created": repos_created,
        "repos_skipped": repos_skipped,
    }


def _invite(org_login: str, login: str, client: Github | None = None) -> None:
    """Invite a user (login required) as direct member (admin role removed for simplicity)."""
    if client is None:
        raise RuntimeError("Github client required for invitations")
    role = "direct_member"
    org = client.get_organization(org_login)
    print_step(f"Inviting {login} as {role}")
    try:
        user = client.get_user(login)
    except GithubException as exc:
        print(f"ERROR (lookup {login}: {exc.status})")
        raise
    post_parameters = {"role": role, "invitee_id": user.id}
    try:
        requester = org._requester  # type: ignore[attr-defined]
        requester.requestJsonAndCheck(
            "POST",
            f"/orgs/{org_login}/invitations",
            input=post_parameters,
        )
        print_ok()
    except GithubException as exc:
        if exc.status == 422:
            data = getattr(exc, 'data', {}) or {}
            lowered = (str(data) or '').lower()
            if any(token in lowered for token in ["already a member", "was already invited", "pending", "invitation exists"]):
                print_ok()
                return
        if exc.status == 403:
            print("ERROR (403 insufficient privileges for invite)")
        else:
            print(f"ERROR (invite {login}: {exc.status})")
        raise


def _ensure_org_template_repo(client: Github, org_name: str, source_repo_slug: str, token: str) -> None:
    target_repo_name = source_repo_slug.split("/", 1)[-1]
    try:
        owner, name = source_repo_slug.split("/", 1)
    except ValueError:
        print("ERROR (bad SOURCE_REPO format, expected owner/name)")
        sys.exit(1)
    try:
        src = client.get_repo(f"{owner}/{name}")
    except GithubException as exc:
        print(f"ERROR (source {exc.status})")
        sys.exit(1)
    try:
        org = client.get_organization(org_name)
        try:
            dest = org.get_repo(target_repo_name)
            repo_created = False
        except GithubException:
            print_step(f"Creating org repo {org_name}/{target_repo_name}")
            dest = org.create_repo(
                name=target_repo_name,
                description=src.description or "Copied from " + source_repo_slug,
                private=src.private,
                has_issues=src.has_issues,
                has_wiki=src.has_wiki,
                has_projects=src.has_projects,
                auto_init=False,
            )
            print_ok()
            repo_created = True
        # Template flag
        if not dest.is_template:
            print_step(f"Marking repo {dest.full_name} as template")
            try:
                dest.edit(is_template=True)
                print_ok()
            except GithubException as exc:
                print(f"ERROR (template {exc.status})")
                sys.exit(1)
        # Content sync if needed
        need_sync = repo_created
        if not need_sync:
            try:
                branches = dest.get_branches()
                for _b in branches:
                    break
                else:
                    need_sync = True
            except GithubException:
                need_sync = True
        if need_sync:
            print_step(f"Syncing content into {dest.full_name}")
            try:
                _sync_repo_contents(source_repo_slug, dest.full_name, src.default_branch, token)
                print_ok()
            except Exception as exc:  # noqa: BLE001
                print(f"ERROR (content sync failed: {exc})")
                sys.exit(1)
        else:
            print_step(f"Repo {dest.full_name} already populated")
            print_ok()
    except GithubException as exc:
        print(f"ERROR ({exc.status})")
        sys.exit(1)


def _generate_from_template(org_login: str, template_repo_name: str, new_name: str, private: bool, client: Github) -> None:
    """Generate a new repository from an existing template repository (snapshot, no history).

    Uses GitHub's template generation endpoint. Fails if repo already exists (caller should pre-check).
    """
    org = client.get_organization(org_login)
    requester = org._requester  # type: ignore[attr-defined]
    body = {"owner": org_login, "name": new_name, "private": private }
    requester.requestJsonAndCheck(
        "POST",
        f"/repos/{org_login}/{template_repo_name}/generate",
        input=body,
    )


if __name__ == "__main__":
    main()
