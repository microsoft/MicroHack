"""Optional: host the same assistant in Foundry so colleagues can chat with it."""
from __future__ import annotations

import logging
import os

from agent_framework_foundry_hosting import ResponsesHostServer
from azure.identity import DefaultAzureCredential, ManagedIdentityCredential
from dotenv import load_dotenv

from configuration import Configuration
from workflow import build_workflow, resolve_versions


def main() -> None:
    load_dotenv(override=False)
    config = Configuration.from_environment()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s %(message)s")
    if config.managed_identity:
        client_id = os.environ.get("AZURE_CLIENT_ID")
        credential = ManagedIdentityCredential(client_id=client_id) if client_id else ManagedIdentityCredential()
    else:
        credential = DefaultAzureCredential()
    try:
        versions = resolve_versions(config, credential)
        logging.getLogger(__name__).info("Regulatory Intelligence Assistant using %s", versions)
        ResponsesHostServer(build_workflow(config, credential, versions)).run(
            host="0.0.0.0" if config.managed_identity else "127.0.0.1")
    finally:
        credential.close()


if __name__ == "__main__":
    main()
