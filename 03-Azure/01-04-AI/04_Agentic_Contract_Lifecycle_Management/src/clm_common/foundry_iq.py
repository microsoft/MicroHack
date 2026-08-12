"""Foundry IQ knowledge-source and knowledge-base provisioning helpers."""
from __future__ import annotations

from urllib.parse import urlparse

import requests

from clm_common.config import credential, settings

SEARCH_SCOPE = "https://search.azure.com/.default"
SEMANTIC_CONFIGURATION = "clm-semantic"


def model_resource_uri(project_endpoint: str) -> str:
    """Return the Azure OpenAI-compatible URI for a Foundry project endpoint."""
    host = urlparse(project_endpoint).hostname or ""
    account_name = host.partition(".")[0]
    if not account_name:
        raise ValueError(f"Invalid Foundry project endpoint: {project_endpoint!r}")
    return f"https://{account_name}.openai.azure.com"


def knowledge_source_payload() -> dict:
    """Build the search-index knowledge source definition."""
    return {
        "name": settings.foundry_iq_knowledge_source,
        "kind": "searchIndex",
        "description": (
            "Contoso CLM templates, clauses, policies, contracts, and counterparty "
            "drafts from the clm-corpus Azure AI Search index."
        ),
        "searchIndexParameters": {
            "searchIndexName": settings.search_index,
            "semanticConfigurationName": SEMANTIC_CONFIGURATION,
            "sourceDataFields": [
                {"name": "id"},
                {"name": "title"},
                {"name": "source"},
                {"name": "url"},
                {"name": "last_modified"},
            ],
            "searchFields": [
                {"name": "title"},
                {"name": "content"},
            ],
        },
    }


def knowledge_base_payload() -> dict:
    """Build the agentic Foundry IQ knowledge base definition."""
    project_endpoint = settings.require_project()
    return {
        "name": settings.foundry_iq_knowledge_base,
        "description": (
            "Shared Contract Lifecycle Management knowledge base for the Intake & "
            "Drafting and Clause & Risk agents."
        ),
        "retrievalInstructions": (
            "Use the CLM corpus for Contoso contract templates, approved clauses, "
            "contracting policy, negotiation fallbacks, approval authority, executed "
            "contracts, and counterparty drafts. Prefer the most specific source and "
            "return extractive passages with citation references. Do not invent an "
            "answer when the corpus does not contain it."
        ),
        "answerInstructions": None,
        "outputMode": "extractiveData",
        "knowledgeSources": [{"name": settings.foundry_iq_knowledge_source}],
        "models": [
            {
                "kind": "azureOpenAI",
                "azureOpenAIParameters": {
                    "resourceUri": model_resource_uri(project_endpoint),
                    "deploymentId": settings.model_drafting,
                    "modelName": settings.model_drafting,
                },
            }
        ],
        "retrievalReasoningEffort": {"kind": "low"},
    }


def mcp_tool_kwargs() -> dict:
    """Return the shared MCP tool configuration for Foundry IQ agents."""
    endpoint = settings.search_endpoint
    if not endpoint:
        raise RuntimeError("AZURE_SEARCH_ENDPOINT is required for Foundry IQ.")
    if not settings.foundry_iq_knowledge_base:
        raise RuntimeError("FOUNDRY_IQ_KNOWLEDGE_BASE is required for Foundry IQ.")
    return {
        "server_label": "clm-contract-knowledge",
        "server_url": (
            f"{endpoint.rstrip('/')}/knowledgebases/"
            f"{settings.foundry_iq_knowledge_base}/mcp"
            f"?api-version={settings.foundry_iq_api_version}"
        ),
        "require_approval": "never",
        "allowed_tools": ["knowledge_base_retrieve"],
        "project_connection_id": settings.foundry_iq_connection_name,
    }


def _put_search_object(path: str, payload: dict) -> None:
    endpoint = settings.search_endpoint
    if not endpoint:
        raise RuntimeError("AZURE_SEARCH_ENDPOINT is required to provision Foundry IQ.")
    token = credential().get_token(SEARCH_SCOPE).token
    response = requests.put(
        f"{endpoint.rstrip('/')}/{path}?api-version={settings.foundry_iq_api_version}",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json=payload,
        timeout=60,
    )
    response.raise_for_status()


def ensure_foundry_iq() -> None:
    """Create or update the Foundry IQ knowledge source and knowledge base."""
    if not settings.foundry_iq_enabled:
        print("· FOUNDRY_IQ_KNOWLEDGE_BASE is empty — using direct Azure AI Search grounding.")
        return
    _put_search_object(
        f"knowledgesources/{settings.foundry_iq_knowledge_source}",
        knowledge_source_payload(),
    )
    print(f"✓ Foundry IQ knowledge source: {settings.foundry_iq_knowledge_source}")
    _put_search_object(
        f"knowledgebases/{settings.foundry_iq_knowledge_base}",
        knowledge_base_payload(),
    )
    print(f"✓ Foundry IQ knowledge base: {settings.foundry_iq_knowledge_base}")
