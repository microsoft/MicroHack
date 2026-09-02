#!/usr/bin/env python3
"""Populate the Foundry IQ crash-statements index from every statement image under data/claims/.

Runs Mistral Document AI OCR against each `data/claims/*/raw/statements/*.jpeg` file and
uploads the extracted text (plus any claimant/policy fields Mistral recognizes) as a document
in the Azure AI Search index used by the Claims Intake Agent's Foundry IQ tool.
"""

import base64
import json
import os
import sys
import time
from pathlib import Path
from typing import Any

import httpx
from dotenv import load_dotenv

REPO_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(REPO_ROOT / ".env")
STATEMENTS_GLOB = "data/claims/*/raw/statements/*.jpeg"
SEARCH_API_VERSION = "2023-11-01"


def _search_config() -> tuple[str, str, str]:
    search_endpoint = os.getenv("FOUNDRY_IQ_SEARCH_ENDPOINT", "").rstrip("/")
    search_key = os.getenv("FOUNDRY_IQ_SEARCH_KEY", "")
    index_name = os.getenv("FOUNDRY_IQ_SEARCH_INDEX_NAME", "crash-statements")

    if not search_endpoint or not search_key:
        raise RuntimeError("Missing FOUNDRY_IQ_SEARCH_ENDPOINT or FOUNDRY_IQ_SEARCH_KEY in .env")

    return search_endpoint, search_key, index_name


def ensure_search_index(client: httpx.Client) -> None:
    search_endpoint, search_key, index_name = _search_config()
    index_url = f"{search_endpoint}/indexes/{index_name}?api-version={SEARCH_API_VERSION}"
    headers = {"api-key": search_key, "Content-Type": "application/json"}

    response = client.get(index_url, headers=headers)
    if response.status_code == 200:
        return
    if response.status_code != 404:
        response.raise_for_status()

    index = {
        "name": index_name,
        "fields": [
            {"name": "id", "type": "Edm.String", "key": True, "filterable": True},
            {"name": "content", "type": "Edm.String", "searchable": True},
            {"name": "source_file", "type": "Edm.String", "filterable": True},
            {
                "name": "claimant_name",
                "type": "Edm.String",
                "searchable": True,
                "filterable": True,
            },
            {"name": "policy_number", "type": "Edm.String", "filterable": True},
        ],
    }
    response = client.put(index_url, headers=headers, json=index)
    response.raise_for_status()
    print(f"Created Azure AI Search index {index_name}.")


def _document_annotation_format() -> dict[str, Any]:
    """Ask Mistral to also extract claimant_name/policy_number alongside the OCR text."""
    return {
        "type": "json_schema",
        "json_schema": {
            "name": "ClaimAnnotation",
            "schema": {
                "type": "object",
                "properties": {
                    "claimant_name": {"type": ["string", "null"]},
                    "policy_number": {"type": ["string", "null"]},
                },
            },
            "strict": False,
        },
    }


def _encode_image_as_data_url(image_path: Path) -> str:
    encoded = base64.b64encode(image_path.read_bytes()).decode("utf-8")
    return f"data:image/jpeg;base64,{encoded}"


def run_mistral_ocr(image_path: Path, client: httpx.Client) -> dict[str, Any]:
    endpoint = os.getenv("MISTRAL_DOCUMENT_AI_ENDPOINT", "").rstrip("/")
    api_key = os.getenv("MISTRAL_DOCUMENT_AI_KEY", "")
    model = os.getenv("MISTRAL_DOCUMENT_AI_DEPLOYMENT_NAME", "mistral-document-ai-2512")

    if not endpoint or not api_key:
        raise RuntimeError("Missing Mistral Document AI configuration in .env")

    payload = {
        "model": model,
        "document": {"type": "image_url", "image_url": _encode_image_as_data_url(image_path)},
        "document_annotation_format": _document_annotation_format(),
    }

    api_version = os.getenv("MISTRAL_DOCUMENT_AI_API_VERSION", "2024-05-01-preview")
    ocr_endpoint = f"{endpoint}/providers/mistral/azure/ocr?api-version={api_version}"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}

    max_attempts = 5
    for attempt in range(1, max_attempts + 1):
        response = client.post(ocr_endpoint, headers=headers, json=payload)
        if response.status_code != 429:
            break
        retry_after = float(response.headers.get("Retry-After", 2 ** attempt))
        print(f"  Rate limited (429), waiting {retry_after:.0f}s before retry {attempt}/{max_attempts}...")
        time.sleep(retry_after)
    response.raise_for_status()
    body = response.json()

    pages = body.get("pages", [])
    text = "\n\n".join(page.get("markdown", "") for page in pages if isinstance(page, dict)) if pages else ""

    annotation_raw = body.get("document_annotation")
    annotation: dict[str, Any] = {}
    if isinstance(annotation_raw, str):
        try:
            annotation = json.loads(annotation_raw)
        except json.JSONDecodeError:
            annotation = {}
    elif isinstance(annotation_raw, dict):
        annotation = annotation_raw

    return {"text": text, "annotation": annotation}


def upload_document(client: httpx.Client, doc_id: str, source_file: str, ocr_result: dict[str, Any]) -> None:
    search_endpoint, search_key, index_name = _search_config()

    annotation = ocr_result["annotation"]
    document = {
        "@search.action": "mergeOrUpload",
        "id": doc_id,
        "content": ocr_result["text"],
        "source_file": source_file,
        "claimant_name": annotation.get("claimant_name"),
        "policy_number": annotation.get("policy_number"),
    }

    response = client.post(
        f"{search_endpoint}/indexes/{index_name}/docs/index?api-version={SEARCH_API_VERSION}",
        headers={"api-key": search_key, "Content-Type": "application/json"},
        json={"value": [document]},
    )
    response.raise_for_status()


def main() -> int:
    image_paths = sorted(REPO_ROOT.glob(STATEMENTS_GLOB))
    if not image_paths:
        print(f"No statement images found under {STATEMENTS_GLOB}")
        return 1

    with httpx.Client(timeout=300.0) as client:
        ensure_search_index(client)
        for image_path in image_paths:
            doc_id = image_path.stem
            print(f"Processing {image_path.relative_to(REPO_ROOT)} -> id={doc_id}")
            ocr_result = run_mistral_ocr(image_path, client)
            upload_document(client, doc_id, image_path.name, ocr_result)
            print(f"  Uploaded {doc_id} ({len(ocr_result['text'])} chars)")

    print(f"\nDone. Indexed {len(image_paths)} statement documents.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
