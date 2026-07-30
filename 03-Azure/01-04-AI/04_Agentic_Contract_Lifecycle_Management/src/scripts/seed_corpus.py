#!/usr/bin/env python
"""Challenge 1 — seed the CLM corpus from SharePoint.

The original contract PDFs (executed contracts, approved templates, clause
library, policy, and inbound counterparty drafts) live in a **SharePoint
document library** — the corpus source of truth. This script wires that library
into Foundry IQ by creating, in Azure AI Search:

1. a **SharePoint Online data source** that connects to the library (app-only
   Microsoft Entra auth),
2. the **`clm-corpus` index** (semantic configuration `clm-semantic`), and
3. an **indexer** that crawls the library, extracts text + metadata, and
   populates the index.

Foundry IQ (Challenge 2) then grounds the agents on that index with cited
answers — no document upload happens here; SharePoint stays the system of
record. Populate the library first (bring-your-own), then run:

    python src/scripts/seed_corpus.py

Prerequisites (see the Challenge 1 README):
    - A SharePoint site + document library holding the corpus PDFs, arranged in
      the subfolders below.
    - A Microsoft Entra app registration (Graph app-only: Sites.Read.All /
      Files.Read.All, admin-consented) whose id/secret authorize the indexer.
    - .env values: SHAREPOINT_SITE_URL, SHAREPOINT_DOC_LIBRARY,
      SHAREPOINT_APP_ID, SHAREPOINT_APP_SECRET, SHAREPOINT_TENANT_ID.

Local-PDF fallback (no SharePoint):
    If the SHAREPOINT_* values are not set, this script instead extracts text
    from the local src/data/**/*.pdf corpus (pypdf) and pushes those
    documents straight into the clm-corpus index via the Search SDK — the same
    Foundry IQ grounding outcome without SharePoint. Use this in sandbox tenants
    that have no SharePoint Online license or where you can't grant the app's
    Graph admin consent.

Note: the Azure AI Search SharePoint Online indexer is a preview feature. If
your search SDK/service rejects the `sharepoint` data-source type, install a
preview `azure-search-documents` build (or create the data source in the portal)
and re-run.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# Make `clm_common` importable regardless of the working directory.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from clm_common.config import settings, credential, DATA_DIR  # noqa: E402
from clm_common.documents import read_document_text  # noqa: E402

# The corpus subfolders expected inside the SharePoint document library (they
# mirror the local `src/data/` layout the PDFs are authored from):
# contract_templates, clause_library, policies, contracts, counterparty_drafts,
# playbooks. The indexer crawls the whole library, so nested folders are fine.
DATA_SOURCE_NAME = "clm-corpus-sharepoint"
INDEXER_NAME = "clm-corpus-indexer"


def _sharepoint_connection_string() -> str | None:
    """Build the SharePoint Online data-source connection string (app auth)."""
    site = settings.sharepoint_site_url
    app_id = settings.sharepoint_app_id
    secret = settings.sharepoint_app_secret
    tenant = settings.sharepoint_tenant_id
    if not (site and app_id and secret and tenant):
        return None
    return (
        f"SharePointOnlineEndpoint={site};"
        f"ApplicationId={app_id};"
        f"ApplicationSecret={secret};"
        f"TenantId={tenant}"
    )


def create_index() -> None:
    """Create/update the clm-corpus index (fields the SharePoint indexer fills)."""
    from azure.search.documents.indexes import SearchIndexClient
    from azure.search.documents.indexes.models import (
        SearchIndex,
        SimpleField,
        SearchableField,
        SearchFieldDataType,
        SemanticConfiguration,
        SemanticPrioritizedFields,
        SemanticField,
        SemanticSearch,
    )

    fields = [
        # Key = the SharePoint item id (base64-encoded via an indexer mapping).
        SimpleField(name="id", type=SearchFieldDataType.String, key=True),
        SearchableField(name="title", type=SearchFieldDataType.String),
        SearchableField(name="content", type=SearchFieldDataType.String),
        SimpleField(name="source", type=SearchFieldDataType.String, filterable=True, facetable=True),
        SimpleField(name="url", type=SearchFieldDataType.String),
        SimpleField(
            name="last_modified",
            type=SearchFieldDataType.DateTimeOffset,
            filterable=True,
            sortable=True,
        ),
    ]
    semantic = SemanticSearch(
        configurations=[
            SemanticConfiguration(
                name="clm-semantic",
                prioritized_fields=SemanticPrioritizedFields(
                    title_field=SemanticField(field_name="title"),
                    content_fields=[SemanticField(field_name="content")],
                ),
            )
        ]
    )

    idx_client = SearchIndexClient(endpoint=settings.search_endpoint, credential=credential())
    idx_client.create_or_update_index(
        SearchIndex(name=settings.search_index, fields=fields, semantic_search=semantic)
    )
    print(f"  ✓ index '{settings.search_index}' created/updated (semantic config: clm-semantic)")


def create_sharepoint_indexer() -> bool:
    """Create the SharePoint data source + indexer that populates the index."""
    conn = _sharepoint_connection_string()
    if not conn:
        print(
            "· SharePoint settings not set — skipping the SharePoint indexer.\n"
            "  Set SHAREPOINT_SITE_URL / SHAREPOINT_DOC_LIBRARY / SHAREPOINT_APP_ID /\n"
            "  SHAREPOINT_APP_SECRET / SHAREPOINT_TENANT_ID in .env (see challenge-0 README)."
        )
        return False

    from azure.search.documents.indexes import SearchIndexerClient
    from azure.search.documents.indexes.models import (
        SearchIndexerDataSourceConnection,
        SearchIndexerDataContainer,
        SearchIndexer,
        FieldMapping,
        FieldMappingFunction,
        IndexingParameters,
        IndexingParametersConfiguration,
    )

    client = SearchIndexerClient(endpoint=settings.search_endpoint, credential=credential())

    # Target the default document library ("Documents"/"Shared Documents") or a
    # named library via a crawl query.
    lib = (settings.sharepoint_doc_library or "").strip()
    if lib in ("", "Documents", "Shared Documents"):
        container = SearchIndexerDataContainer(name="defaultSiteLibrary")
    else:
        include = f"{settings.sharepoint_site_url.rstrip('/')}/{lib}"
        container = SearchIndexerDataContainer(name="useQuery", query=f"includeLibrary={include}")

    data_source = SearchIndexerDataSourceConnection(
        name=DATA_SOURCE_NAME,
        type="sharepoint",
        connection_string=conn,
        container=container,
    )
    client.create_or_update_data_source_connection(data_source)
    print(f"  ✓ SharePoint data source '{DATA_SOURCE_NAME}' created/updated")

    # Map SharePoint item metadata into the clm-corpus fields. The key is the
    # base64-encoded SharePoint item id; content is the extracted document text.
    field_mappings = [
        FieldMapping(
            source_field_name="metadata_spo_site_library_item_id",
            target_field_name="id",
            mapping_function=FieldMappingFunction(name="base64Encode"),
        ),
        FieldMapping(source_field_name="metadata_spo_item_name", target_field_name="title"),
        FieldMapping(source_field_name="metadata_spo_item_path", target_field_name="source"),
        FieldMapping(source_field_name="metadata_spo_item_weburi", target_field_name="url"),
        FieldMapping(source_field_name="metadata_spo_item_last_modified", target_field_name="last_modified"),
    ]

    indexer = SearchIndexer(
        name=INDEXER_NAME,
        data_source_name=DATA_SOURCE_NAME,
        target_index_name=settings.search_index,
        field_mappings=field_mappings,
        parameters=IndexingParameters(
            configuration=IndexingParametersConfiguration(
                data_to_extract="contentAndMetadata",
                parsing_mode="default",
            )
        ),
    )
    client.create_or_update_indexer(indexer)
    print(f"  ✓ indexer '{INDEXER_NAME}' created/updated")

    client.run_indexer(INDEXER_NAME)
    print(f"  ✓ indexer '{INDEXER_NAME}' run started — crawling the SharePoint library")
    return True


def _safe_key(rel_path: str) -> str:
    """Turn a relative corpus path into a valid Azure AI Search document key.

    Keys may contain only letters, digits, underscore, dash, and equals.
    """
    return re.sub(r"[^0-9A-Za-z_\-=]", "_", rel_path)


def seed_local_pdfs() -> int:
    """Fallback: push the local corpus PDFs straight into the clm-corpus index.

    For tenants with no SharePoint Online license (or where you can't grant the
    app's Graph admin consent): extract text from src/data/**/*.pdf with
    pypdf and upload documents via the Search SDK — the same grounding outcome as
    the SharePoint indexer, minus SharePoint. Requires the caller to hold the
    'Search Index Data Contributor' role on the search service (the deploy grants
    it to the deploying user).
    """
    from datetime import datetime, timezone

    from azure.search.documents import SearchClient

    pdfs = sorted(DATA_DIR.rglob("*.pdf"))
    if not pdfs:
        print(f"  ! no PDFs found under {DATA_DIR} — nothing to seed.")
        return 0

    client = SearchClient(
        endpoint=settings.search_endpoint,
        index_name=settings.search_index,
        credential=credential(),
    )

    docs: list[dict] = []
    for pdf in pdfs:
        rel = pdf.relative_to(DATA_DIR)
        try:
            content = read_document_text(pdf)
        except Exception as exc:  # noqa: BLE001
            print(f"  ! skipped {rel.as_posix()} ({exc})")
            continue
        mtime = datetime.fromtimestamp(pdf.stat().st_mtime, tz=timezone.utc)
        docs.append(
            {
                "id": _safe_key(rel.as_posix()),
                "title": pdf.stem,
                "content": content,
                "source": rel.parts[0] if len(rel.parts) > 1 else "root",
                "url": rel.as_posix(),
                "last_modified": mtime,
            }
        )

    if not docs:
        print("  ! no readable PDFs — nothing uploaded.")
        return 0

    results = client.upload_documents(documents=docs)
    ok = sum(1 for r in results if r.succeeded)
    print(f"  ✓ uploaded {ok}/{len(docs)} local PDF(s) into '{settings.search_index}'")
    if ok < len(docs):
        print(
            "  ! some documents failed — confirm you have the 'Search Index Data "
            "Contributor' role on the search service, then re-run."
        )
    return ok


def build_search_index() -> None:
    if not settings.search_endpoint:
        print("· AZURE_SEARCH_ENDPOINT not set — skipping search index.")
        return
    create_index()
    if _sharepoint_connection_string():
        create_sharepoint_indexer()
    else:
        print(
            "· SharePoint settings not set — using the LOCAL-PDF fallback\n"
            "  (extracting src/data/**/*.pdf straight into the index; no\n"
            "  SharePoint needed — see the challenge-0 README)."
        )
        seed_local_pdfs()


def main() -> None:
    print("Seeding CLM corpus…")
    build_search_index()
    print(
        "Done. Expected: the 'clm-corpus' index populated — via the SharePoint "
        "indexer (check its run status in the Azure portal) or, in the local-PDF "
        "fallback, directly by this script."
    )


if __name__ == "__main__":
    main()
