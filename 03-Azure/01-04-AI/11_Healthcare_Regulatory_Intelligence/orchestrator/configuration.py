"""Settings for the event-driven Regulatory Intelligence Assistant."""
from __future__ import annotations

import os
import re
from dataclasses import dataclass, field
from typing import Dict, Optional
from urllib.parse import urlparse

# The three saved prompt agents chained by the assistant, in order.
ROLES = {"CITATION": "citation-agent", "IMPACT": "impact-agent", "BRIEFING": "briefing-agent"}
NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9]")


@dataclass(frozen=True)
class Configuration:
    endpoint: str
    names: Dict[str, str]
    versions: Dict[str, Optional[str]] = field(default_factory=dict)
    managed_identity: bool = False

    @classmethod
    def from_environment(cls) -> "Configuration":
        endpoint = os.environ.get("FOUNDRY_PROJECT_ENDPOINT", "").strip()
        parsed = urlparse(endpoint)
        if parsed.scheme != "https" or not parsed.hostname or "/api/projects/" not in parsed.path:
            raise ValueError("FOUNDRY_PROJECT_ENDPOINT must be your Foundry project endpoint from the lab dashboard "
                             "(https://<account>.services.ai.azure.com/api/projects/<project>).")
        if parsed.username or parsed.password or parsed.query or parsed.fragment:
            raise ValueError("FOUNDRY_PROJECT_ENDPOINT must not contain credentials, a query or a fragment.")
        names, versions = {}, {}
        for role, default in ROLES.items():
            name = os.environ.get(f"{role}_AGENT_NAME", default).strip()
            if not NAME.fullmatch(name):
                raise ValueError(f"{role}_AGENT_NAME '{name}' is not a valid agent name.")
            version = os.environ.get(f"{role}_AGENT_VERSION", "").strip() or None
            if version is not None and not re.fullmatch(r"[1-9][0-9]*", version):
                raise ValueError(f"{role}_AGENT_VERSION must be a saved version number, or empty to use the latest.")
            names[role], versions[role] = name, version
        identity = os.environ.get("REGINTEL_MANAGED_IDENTITY", "false").strip().lower()
        if identity not in {"true", "false"}:
            raise ValueError("REGINTEL_MANAGED_IDENTITY must be true or false.")
        return cls(endpoint, names, versions, identity == "true")
