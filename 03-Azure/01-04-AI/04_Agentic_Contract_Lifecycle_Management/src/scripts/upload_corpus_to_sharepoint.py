#!/usr/bin/env python
"""Challenge 1 (coach/setup) — upload the CLM corpus PDFs into SharePoint.

`src/scripts/seed_corpus.py` wires a SharePoint document library into Azure AI
Search, but it does **not** put any files there — SharePoint is the corpus
"source of truth" that you populate first. This script automates that one-time
population: it uploads every PDF under `src/data/` into your SharePoint
document library via Microsoft Graph, recreating the folder layout the corpus
expects (`contract_templates/`, `clause_library/`, `policies/`, `contracts/`,
`counterparty_drafts/`, `playbooks/`). Non-PDF corpus files (`evaluation/*.jsonl`,
`contracts_seed.json`) are read locally by the challenges and are **not**
uploaded.

Run it once, before participants reach Challenge 1 / Task 6:

    python src/scripts/upload_corpus_to_sharepoint.py            # upload
    python src/scripts/upload_corpus_to_sharepoint.py --dry-run  # list, no calls

Auth / permissions
------------------
Uses the same `SHAREPOINT_*` app registration as `seed_corpus.py`, but uploading
needs **write** access, so the app must have a Microsoft Graph *Application*
permission of `Sites.ReadWrite.All` (or `Files.ReadWrite.All`), admin-consented —
the indexer only needs the read equivalents. Required .env values:

    SHAREPOINT_SITE_URL     e.g. https://contoso.sharepoint.com/sites/CLMCorpus
    SHAREPOINT_DOC_LIBRARY  e.g. Documents   (the default document library)
    SHAREPOINT_APP_ID
    SHAREPOINT_APP_SECRET
    SHAREPOINT_TENANT_ID
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from urllib.parse import urlparse

# Make `clm_common` importable regardless of the working directory.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from clm_common.config import DATA_DIR, settings  # noqa: E402

GRAPH = "https://graph.microsoft.com/v1.0"
GRAPH_SCOPE = "https://graph.microsoft.com/.default"

# Corpus subfolders that hold the grounding PDFs (mirrors src/data/).
# `evaluation/` (jsonl) and top-level json are intentionally excluded.
SKIP_DIRS = {"evaluation"}


def _fail(msg: str) -> "NoReturn":  # type: ignore[name-defined]
    print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(1)


def collect_pdfs(data_dir: Path) -> list[tuple[str, Path]]:
    """Return (relative_posix_path, local_path) for every corpus PDF to upload."""
    items: list[tuple[str, Path]] = []
    for path in sorted(data_dir.rglob("*.pdf")):
        rel = path.relative_to(data_dir)
        if rel.parts and rel.parts[0] in SKIP_DIRS:
            continue
        items.append((rel.as_posix(), path))
    return items


def get_token() -> str:
    """Acquire an app-only Microsoft Graph token via client credentials."""
    missing = [
        name
        for name, val in (
            ("SHAREPOINT_SITE_URL", settings.sharepoint_site_url),
            ("SHAREPOINT_APP_ID", settings.sharepoint_app_id),
            ("SHAREPOINT_APP_SECRET", settings.sharepoint_app_secret),
            ("SHAREPOINT_TENANT_ID", settings.sharepoint_tenant_id),
        )
        if not val
    ]
    if missing:
        _fail(
            "Missing SharePoint settings: "
            + ", ".join(missing)
            + ".\n  Set them in .env (see .env.example / challenge-0 README)."
        )

    from azure.identity import ClientSecretCredential

    cred = ClientSecretCredential(
        tenant_id=settings.sharepoint_tenant_id,
        client_id=settings.sharepoint_app_id,
        client_secret=settings.sharepoint_app_secret,
    )
    return cred.get_token(GRAPH_SCOPE).token


def resolve_site(session, site_url: str) -> dict:
    """Resolve a SharePoint site URL to its Graph site resource."""
    parsed = urlparse(site_url)
    host = parsed.netloc
    server_path = parsed.path.strip("/")
    lookup = f"{GRAPH}/sites/{host}:/{server_path}" if server_path else f"{GRAPH}/sites/{host}"
    resp = session.get(lookup)
    if resp.status_code == 404:
        _fail(f"SharePoint site not found for '{site_url}'. Check SHAREPOINT_SITE_URL.")
    resp.raise_for_status()
    return resp.json()


def resolve_drive(session, site_id: str, library: str) -> dict:
    """Resolve the target document library (drive) by name, or the default one."""
    lib = (library or "").strip()
    if lib in ("", "Documents", "Shared Documents"):
        resp = session.get(f"{GRAPH}/sites/{site_id}/drive")
        resp.raise_for_status()
        return resp.json()

    resp = session.get(f"{GRAPH}/sites/{site_id}/drives")
    resp.raise_for_status()
    drives = resp.json().get("value", [])
    for drive in drives:
        if drive.get("name", "").lower() == lib.lower():
            return drive
    names = ", ".join(d.get("name", "?") for d in drives) or "(none)"
    _fail(f"Document library '{library}' not found on the site. Available: {names}.")


def ensure_folder_path(session, drive_id: str, folder_path: str, created: set[str]) -> None:
    """Create each folder segment in `folder_path` if it does not already exist."""
    current = ""
    for part in folder_path.split("/"):
        parent_ref = "root" if not current else f"root:/{current}:"
        key = f"{current}/{part}" if current else part
        if key not in created:
            resp = session.post(
                f"{GRAPH}/drives/{drive_id}/{parent_ref}/children",
                json={"name": part, "folder": {}, "@microsoft.graph.conflictBehavior": "fail"},
            )
            if resp.status_code not in (200, 201, 409):
                resp.raise_for_status()
            created.add(key)
        current = key


def upload_file(session, drive_id: str, rel_path: str, local_path: Path) -> str:
    """Upload one small file (<4 MB) by path; replaces an existing item."""
    url = f"{GRAPH}/drives/{drive_id}/root:/{rel_path}:/content"
    with local_path.open("rb") as handle:
        resp = session.put(
            url,
            params={"@microsoft.graph.conflictBehavior": "replace"},
            headers={"Content-Type": "application/pdf"},
            data=handle,
        )
    if resp.status_code == 403:
        _fail(
            "403 Forbidden uploading to SharePoint. The app registration needs a "
            "Microsoft Graph *Application* permission of Sites.ReadWrite.All "
            "(or Files.ReadWrite.All), admin-consented."
        )
    resp.raise_for_status()
    return resp.json().get("webUrl", "")


def main() -> None:
    parser = argparse.ArgumentParser(description="Upload the CLM corpus PDFs to SharePoint.")
    parser.add_argument(
        "--data-dir",
        default=str(DATA_DIR),
        help="Corpus root to upload from (default: src/data).",
    )
    parser.add_argument(
        "--library",
        default=settings.sharepoint_doc_library,
        help="Target document library name (default: SHAREPOINT_DOC_LIBRARY).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List what would be uploaded without contacting SharePoint.",
    )
    args = parser.parse_args()

    data_dir = Path(args.data_dir).resolve()
    if not data_dir.is_dir():
        _fail(f"Data directory not found: {data_dir}")

    files = collect_pdfs(data_dir)
    if not files:
        _fail(f"No PDFs found under {data_dir}. Run src/scripts/make_corpus_pdfs.py first.")

    print(f"CLM corpus upload -> SharePoint library '{args.library}'")
    print(f"  source: {data_dir}")
    print(f"  files:  {len(files)} PDF(s)\n")

    if args.dry_run:
        for rel_path, _ in files:
            print(f"  would upload  {rel_path}")
        print(f"\nDry run: {len(files)} file(s) would be uploaded. No changes made.")
        return

    import requests

    token = get_token()
    session = requests.Session()
    session.headers.update({"Authorization": f"Bearer {token}"})

    site = resolve_site(session, settings.sharepoint_site_url)
    drive = resolve_drive(session, site["id"], args.library)
    drive_id = drive["id"]
    print(f"  site:   {site.get('webUrl', site['id'])}")
    print(f"  drive:  {drive.get('name', drive_id)}\n")

    created_folders: set[str] = set()
    uploaded = 0
    for rel_path, local_path in files:
        folder = str(Path(rel_path).parent.as_posix())
        if folder and folder != ".":
            ensure_folder_path(session, drive_id, folder, created_folders)
        upload_file(session, drive_id, rel_path, local_path)
        uploaded += 1
        print(f"  uploaded  {rel_path}")

    print(
        f"\nDone. Uploaded {uploaded} PDF(s) to '{drive.get('name', args.library)}'.\n"
        f"Next: run 'python src/scripts/seed_corpus.py' to index the library into clm-corpus."
    )


if __name__ == "__main__":
    main()
