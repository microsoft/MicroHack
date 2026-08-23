#!/usr/bin/env python3
"""Claims intake agent that combines Mistral Document AI OCR with Foundry IQ retrieval."""

import argparse
import base64
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import (
    AISearchIndexResource,
    AzureAISearchTool,
    AzureAISearchToolResource,
    ConnectionType,
    PromptAgentDefinition,
)
from azure.core.exceptions import ResourceNotFoundError
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv
from pydantic import BaseModel, Field

REPO_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(REPO_ROOT / ".env")

FOUNDRY_AGENT_NAME = "claims-intake-agent"
FOUNDRY_AGENT_INSTRUCTIONS = (
    "You are the Claims Intake Agent. Before answering, you MUST call the azure_ai_search "
    "tool exactly once to search the crash statements index using key identifying details "
    "from the OCR text (claimant name, date, location). Always perform this search first, "
    "even if you believe you already know the answer. Then, in 2-3 sentences, summarize the "
    "claimant, vehicle, and incident from the new OCR text, and note whether the retrieved "
    "match is consistent with it."
)


class VehicleInfo(BaseModel):
    make: str | None = None
    model: str | None = None
    year: str | None = None
    license_plate: str | None = None
    vin: str | None = None


class Witness(BaseModel):
    name: str | None = None
    phone: str | None = None


class ClaimAnnotation(BaseModel):
    """Document annotation schema: structured claim data extracted from the full accident statement."""

    claimant_name: str = Field(..., description="Full name of the person filing the claim")
    claim_date: str | None = Field(None, description="Date when the claim was filed or incident occurred (MM/DD/YYYY format)")
    policy_number: str | None = Field(None, description="Insurance policy number")
    incident_description: str = Field(..., description="Description of what happened during the incident")
    vehicle_info: VehicleInfo | None = None
    damage_description: str | None = Field(None, description="Description of damage to the vehicle")
    estimated_damage_amount: str | None = Field(None, description="Estimated cost of damages")
    witnesses: list[Witness] = Field(default_factory=list)
    signature_present: bool | None = Field(None, description="Whether a signature is present on the document")
    date_signed: str | None = Field(None, description="Date when the document was signed")


def _document_annotation_format() -> dict[str, Any]:
    """Build the document_annotation_format payload requesting structured claim extraction."""
    return {
        "type": "json_schema",
        "json_schema": {
            "name": "ClaimAnnotation",
            "schema": ClaimAnnotation.model_json_schema(),
            "strict": True,
        },
    }


def _encode_image_as_data_url(image_path: Path) -> tuple[str, str]:
    suffix = image_path.suffix.lower()
    mime_type = "image/jpeg"
    url_type = "image_url"

    if suffix == ".png":
        mime_type = "image/png"
    elif suffix == ".pdf":
        mime_type = "application/pdf"
        url_type = "document_url"

    encoded = base64.b64encode(image_path.read_bytes()).decode("utf-8")
    return f"data:{mime_type};base64,{encoded}", url_type


def run_mistral_ocr(image_path: Path) -> dict[str, Any]:
    endpoint = os.getenv("MISTRAL_DOCUMENT_AI_ENDPOINT", "").rstrip("/")
    api_key = os.getenv("MISTRAL_DOCUMENT_AI_KEY", "")
    model = os.getenv("MISTRAL_DOCUMENT_AI_DEPLOYMENT_NAME", "mistral-document-ai-2512")

    if not endpoint or not api_key:
        raise RuntimeError("Missing Mistral Document AI configuration in .env")

    data_url, url_type = _encode_image_as_data_url(image_path)

    payload = {
        "model": model,
        "document": {
            "type": url_type,
            url_type: data_url,
        },
        "document_annotation_format": _document_annotation_format(),
    }

    api_version = os.getenv("MISTRAL_DOCUMENT_AI_API_VERSION", "2024-05-01-preview")
    ocr_endpoint = f"{endpoint}/providers/mistral/azure/ocr?api-version={api_version}"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}

    with httpx.Client(timeout=300.0) as client:
        response = client.post(ocr_endpoint, headers=headers, json=payload)
        response.raise_for_status()
        body = response.json()

    pages = body.get("pages", [])
    if pages:
        text = "\n\n".join(page.get("markdown", "") for page in pages if isinstance(page, dict))
    else:
        text = body.get("content") or body.get("text") or ""

    document_annotation_raw = body.get("document_annotation")
    document_annotation: dict[str, Any] | None = None
    if isinstance(document_annotation_raw, str):
        try:
            document_annotation = json.loads(document_annotation_raw)
        except json.JSONDecodeError:
            document_annotation = None
    elif isinstance(document_annotation_raw, dict):
        document_annotation = document_annotation_raw

    return {
        "model": model,
        "text": text,
        "character_count": len(text),
        "pages_processed": len(pages) if pages else 1,
        "document_annotation": document_annotation,
    }


def _get_ai_search_connection_id(client: AIProjectClient) -> str:
    """Find the Azure AI Search connection attached to the Foundry project (Foundry IQ)."""
    connection = next(
        (c for c in client.connections.list() if c.type == ConnectionType.AZURE_AI_SEARCH),
        None,
    )
    if connection is None:
        raise RuntimeError(
            "No Azure AI Search connection found on the Foundry project. Complete Task 2 "
            "(create + populate the crash-statements index) and ensure the AI Search resource "
            "is connected to your Foundry project."
        )
    return connection.id


def _build_foundry_iq_tool(client: AIProjectClient, index_name: str) -> AzureAISearchTool:
    """Build the Foundry IQ (Azure AI Search) tool that grounds the agent in crash statements."""
    connection_id = _get_ai_search_connection_id(client)
    return AzureAISearchTool(
        azure_ai_search=AzureAISearchToolResource(
            indexes=[
                AISearchIndexResource(
                    project_connection_id=connection_id,
                    index_name=index_name,
                    query_type="simple",
                    top_k=3,
                )
            ]
        )
    )


def _ensure_foundry_agent(client: AIProjectClient, model_deployment: str, index_name: str) -> None:
    """Register the Claims Intake Agent or update it when its model changes."""
    try:
        client.agents.get(FOUNDRY_AGENT_NAME)
        versions = list(client.agents.list_versions(FOUNDRY_AGENT_NAME))
        latest_version = max(versions, key=lambda version: int(version.version))
        if latest_version.definition.model == model_deployment:
            return
    except ResourceNotFoundError:
        pass

    definition = PromptAgentDefinition(
        model=model_deployment,
        instructions=FOUNDRY_AGENT_INSTRUCTIONS,
        tools=[_build_foundry_iq_tool(client, index_name)],
    )
    client.agents.create_version(agent_name=FOUNDRY_AGENT_NAME, definition=definition)


def _extract_foundry_iq_matches(response: Any, index_name: str) -> dict[str, Any]:
    """Pull the Foundry IQ (Azure AI Search) tool call results out of the agent response."""
    matches: list[dict[str, Any]] = []
    for item in getattr(response, "output", []) or []:
        if getattr(item, "type", None) != "azure_ai_search_call_output":
            continue
        try:
            payload = json.loads(item.output)
        except (json.JSONDecodeError, TypeError):
            continue
        for doc in payload.get("documents", []):
            matches.append(
                {
                    "id": doc.get("id", "unknown"),
                    "content": doc.get("content", ""),
                    "score": doc.get("score"),
                }
            )

    return {"index_name": index_name, "match_count": len(matches), "matches": matches}


def run_claims_intake(image_path: Path) -> dict[str, Any]:
    if not image_path.exists():
        raise FileNotFoundError(f"Image not found: {image_path}")

    ocr = run_mistral_ocr(image_path)

    project_endpoint = os.getenv("AI_FOUNDRY_PROJECT_ENDPOINT", "").strip()
    if not project_endpoint:
        raise RuntimeError("AI_FOUNDRY_PROJECT_ENDPOINT is not set. Complete Task 1 first.")

    index_name = os.getenv("FOUNDRY_IQ_SEARCH_INDEX_NAME", "crash-statements")
    model_deployment = os.getenv("MODEL_DEPLOYMENT_NAME", "gpt-5.4")

    client = AIProjectClient(endpoint=project_endpoint, credential=DefaultAzureCredential(), allow_preview=True)
    _ensure_foundry_agent(client, model_deployment, index_name)

    openai_client = client.get_openai_client(agent_name=FOUNDRY_AGENT_NAME)
    response = openai_client.responses.create(
        model=model_deployment,
        input=f"New OCR statement:\n{ocr.get('text', '')}",
    )

    return {
        "status": "success",
        "image_path": str(image_path),
        "processed_at_utc": datetime.now(timezone.utc).isoformat(),
        "ocr": ocr,
        "extracted_data": ocr.get("document_annotation"),
        "foundry_iq": _extract_foundry_iq_matches(response, index_name),
        "foundry_agent": {"name": FOUNDRY_AGENT_NAME},
        "agent_summary": response.output_text,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Run claims intake OCR + Foundry IQ retrieval")
    parser.add_argument("image_path", help="Path to the claim image or PDF")
    parser.add_argument(
        "--output",
        default="",
        help="Optional output JSON path. Defaults to next to input file with .intake.json suffix",
    )
    args = parser.parse_args()

    image_path = Path(args.image_path).expanduser().resolve()
    output_path = (
        Path(args.output).expanduser().resolve()
        if args.output
        else image_path.with_suffix(".intake.json")
    )

    result = run_claims_intake(image_path)
    output_path.write_text(json.dumps(result, indent=2), encoding="utf-8")

    print(json.dumps(result, indent=2))
    print(f"\nSaved intake output to: {output_path}")


if __name__ == "__main__":
    main()
