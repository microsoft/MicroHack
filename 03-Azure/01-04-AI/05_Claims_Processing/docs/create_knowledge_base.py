#!/usr/bin/env python3
"""Create Foundry IQ knowledge sources and knowledge bases for the claims agents.

Without arguments, run this after `index_crash_statements.py` has populated the index. It:

1. Adds a semantic configuration to the existing `crash-statements` index (required for
   agentic retrieval knowledge sources).
2. Creates a `SearchIndexKnowledgeSource` that wraps the index.
3. Creates a `KnowledgeBase` that orchestrates retrieval from that knowledge source.

Pass `--policies` to create a Blob knowledge source over the policies container and the
knowledge base used by `claims-intelligence-agent`.
"""

import argparse
import os
from pathlib import Path

from azure.core.credentials import AzureKeyCredential
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import (
    AzureBlobKnowledgeSource,
    AzureBlobKnowledgeSourceParameters,
    KnowledgeBase,
    KnowledgeSourceReference,
    SearchIndexFieldReference,
    SearchIndexKnowledgeSource,
    SearchIndexKnowledgeSourceParameters,
    SemanticConfiguration,
    SemanticField,
    SemanticPrioritizedFields,
    SemanticSearch,
)
from dotenv import load_dotenv

REPO_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(REPO_ROOT / ".env")

SEMANTIC_CONFIG_NAME = "crash-statements-semantic-config"
POLICIES_KNOWLEDGE_SOURCE_NAME = "policies-blob-ks"
POLICIES_KNOWLEDGE_BASE_NAME = "policies-kb"


def _client_and_endpoint() -> tuple[SearchIndexClient, str]:
    endpoint = os.getenv("FOUNDRY_IQ_SEARCH_ENDPOINT") or os.getenv("SEARCH_SERVICE_ENDPOINT", "")
    key = os.getenv("FOUNDRY_IQ_SEARCH_KEY") or os.getenv("SEARCH_ADMIN_KEY", "")
    if not endpoint or not key:
        raise RuntimeError("Missing FOUNDRY_IQ_SEARCH_ENDPOINT/FOUNDRY_IQ_SEARCH_KEY in .env")
    return SearchIndexClient(endpoint=endpoint, credential=AzureKeyCredential(key)), endpoint


def ensure_index_ready_for_agentic_retrieval(client: SearchIndexClient, index_name: str) -> None:
    """Make the crash-statements index usable as a knowledge source: retrievable fields + semantic config.

    The index created by `infrastructure/azuredeploy.json`'s deployment script only marks `id` as
    retrievable, but a search index knowledge source needs every field it references
    (`source_data_fields`) to be retrievable, and agentic retrieval requires a semantic
    configuration. Both attributes can be changed on an existing index without rebuilding it.
    """
    index = client.get_index(index_name)
    changed = False

    for field in index.fields:
        if field.name != "id" and field.hidden:
            field.hidden = False
            changed = True

    existing_names = {c.name for c in (index.semantic_search.configurations if index.semantic_search else [])}
    if SEMANTIC_CONFIG_NAME not in existing_names:
        index.semantic_search = SemanticSearch(
            default_configuration_name=SEMANTIC_CONFIG_NAME,
            configurations=[
                SemanticConfiguration(
                    name=SEMANTIC_CONFIG_NAME,
                    prioritized_fields=SemanticPrioritizedFields(
                        title_field=SemanticField(field_name="source_file"),
                        content_fields=[SemanticField(field_name="content")],
                        keywords_fields=[SemanticField(field_name="claimant_name")],
                    ),
                )
            ],
        )
        changed = True

    if not changed:
        print(f"Index '{index_name}' is already retrievable and has semantic configuration '{SEMANTIC_CONFIG_NAME}'.")
        return

    client.create_or_update_index(index)
    print(f"Updated index '{index_name}': fields retrievable + semantic configuration '{SEMANTIC_CONFIG_NAME}'.")


def ensure_knowledge_source(client: SearchIndexClient, index_name: str, knowledge_source_name: str) -> None:
    knowledge_source = SearchIndexKnowledgeSource(
        name=knowledge_source_name,
        description="Crash statement evidence for the claims intake agent",
        search_index_parameters=SearchIndexKnowledgeSourceParameters(
            search_index_name=index_name,
            semantic_configuration_name=SEMANTIC_CONFIG_NAME,
            source_data_fields=[
                SearchIndexFieldReference(name="id"),
                SearchIndexFieldReference(name="content"),
                SearchIndexFieldReference(name="source_file"),
                SearchIndexFieldReference(name="claimant_name"),
                SearchIndexFieldReference(name="policy_number"),
            ],
        ),
    )
    client.create_or_update_knowledge_source(knowledge_source=knowledge_source)
    print(f"Knowledge source '{knowledge_source_name}' created or updated.")


def ensure_knowledge_base(
    client: SearchIndexClient,
    search_endpoint: str,
    knowledge_source_name: str,
    knowledge_base_name: str,
    description: str = "Grounds the claims intake agent in crash statement evidence",
) -> str:
    knowledge_base = KnowledgeBase(
        name=knowledge_base_name,
        description=description,
        knowledge_sources=[KnowledgeSourceReference(name=knowledge_source_name)],
    )
    client.create_or_update_knowledge_base(knowledge_base=knowledge_base)
    print(f"Knowledge base '{knowledge_base_name}' created or updated.")
    return f"{search_endpoint.rstrip('/')}/knowledgebases/{knowledge_base_name}/mcp?api-version=2026-04-01"


def ensure_policies_knowledge_source(
    client: SearchIndexClient,
    knowledge_source_name: str,
) -> None:
    """Create a Foundry IQ Blob knowledge source over the policy documents."""
    connection_string = os.getenv("AZURE_STORAGE_CONNECTION_STRING", "")
    container_name = os.getenv("AZURE_POLICIES_CONTAINER_NAME", "policies")
    if not connection_string:
        raise RuntimeError("Missing AZURE_STORAGE_CONNECTION_STRING in .env")

    knowledge_source = AzureBlobKnowledgeSource(
        name=knowledge_source_name,
        description="Insurance policy Markdown documents used for claims adjudication",
        azure_blob_parameters=AzureBlobKnowledgeSourceParameters(
            connection_string=connection_string,
            container_name=container_name,
        ),
    )
    client.create_or_update_knowledge_source(knowledge_source=knowledge_source)
    print(
        f"Knowledge source '{knowledge_source_name}' created or updated from "
        f"Blob container '{container_name}'."
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Create a Foundry IQ knowledge base")
    parser.add_argument(
        "--policies",
        action="store_true",
        help="Create the policies Blob knowledge source and policies knowledge base",
    )
    args = parser.parse_args()

    client, search_endpoint = _client_and_endpoint()
    if args.policies:
        knowledge_source_name = os.getenv(
            "FOUNDRY_IQ_POLICIES_KNOWLEDGE_SOURCE_NAME",
            POLICIES_KNOWLEDGE_SOURCE_NAME,
        )
        knowledge_base_name = os.getenv(
            "FOUNDRY_IQ_POLICIES_KNOWLEDGE_BASE_NAME",
            POLICIES_KNOWLEDGE_BASE_NAME,
        )
        ensure_policies_knowledge_source(client, knowledge_source_name)
        mcp_endpoint = ensure_knowledge_base(
            client,
            search_endpoint,
            knowledge_source_name,
            knowledge_base_name,
            description="Grounds the policy extraction agent in insurance policy documents",
        )
        print(f"\nPolicy knowledge base MCP endpoint:\n  {mcp_endpoint}")
        print("Blob ingestion starts asynchronously and can take several minutes.")
        return

    index_name = os.getenv("FOUNDRY_IQ_SEARCH_INDEX_NAME", "crash-statements")
    knowledge_source_name = os.getenv("FOUNDRY_IQ_KNOWLEDGE_SOURCE_NAME", "crash-statements-ks")
    knowledge_base_name = os.getenv("FOUNDRY_IQ_KNOWLEDGE_BASE_NAME", "crash-statements-kb")

    ensure_index_ready_for_agentic_retrieval(client, index_name)
    ensure_knowledge_source(client, index_name, knowledge_source_name)
    mcp_endpoint = ensure_knowledge_base(client, search_endpoint, knowledge_source_name, knowledge_base_name)

    print(f"\nKnowledge base MCP endpoint:\n  {mcp_endpoint}")
    print("Set FOUNDRY_IQ_KNOWLEDGE_BASE_NAME in .env if you used a non-default name.")


if __name__ == "__main__":
    main()
