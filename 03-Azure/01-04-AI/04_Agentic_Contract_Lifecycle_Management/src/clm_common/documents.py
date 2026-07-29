"""Shared document-reading helpers for the CLM microhack.

The Challenge 1 corpus is delivered as **PDF** contract documents (approved
templates, clause library, policy, executed contracts, and inbound counterparty
drafts). `read_document_text` returns plain text for a PDF (or a Markdown/text
fallback), so the seeding script and the Clause & Risk agent can treat every
document the same way.
"""
from __future__ import annotations

from pathlib import Path


def read_document_text(path: str | Path) -> str:
    """Return the plain text of a corpus document.

    - `.pdf` is text-extracted with **pypdf** (install: `pip install pypdf`).
    - `.md` / `.txt` / `.markdown` are read directly as UTF-8.
    """
    path = Path(path)
    suffix = path.suffix.lower()

    if suffix == ".pdf":
        try:
            from pypdf import PdfReader
        except ImportError as exc:  # pragma: no cover - dependency hint
            raise RuntimeError(
                "Reading PDF documents requires 'pypdf'. Install it with "
                "`pip install pypdf` (it is listed in requirements.txt)."
            ) from exc

        reader = PdfReader(str(path))
        pages = [(page.extract_text() or "") for page in reader.pages]
        return "\n".join(pages).strip()

    return path.read_text(encoding="utf-8")
