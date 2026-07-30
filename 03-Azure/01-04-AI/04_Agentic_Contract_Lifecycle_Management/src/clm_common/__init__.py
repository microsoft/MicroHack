"""Shared helpers for the Foundry CLM microhack (importable as `clm_common`)."""

# Ensure UTF-8 stdout/stderr so emoji status markers (✓ ✅ 🔴) print on any
# console (Windows cp1252 included). Harmless on Linux/Codespaces where it's
# already UTF-8. Guarded so it never breaks import.
import sys as _sys

for _stream in (_sys.stdout, _sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[union-attr]
    except (AttributeError, ValueError):
        pass

from .config import settings, credential  # noqa: E402,F401
