#!/usr/bin/env python3
"""Create or update the CLM Foundry IQ knowledge source and knowledge base."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from clm_common.foundry_iq import ensure_foundry_iq  # noqa: E402


if __name__ == "__main__":
    print("Configuring Foundry IQ...")
    ensure_foundry_iq()

