"""Import model-pricing.json into Azure Cosmos DB.

Usage:
    python import-model-pricing.py --endpoint https://<your-cosmos-account>.documents.azure.com:443/

Authentication uses DefaultAzureCredential (Entra OAuth).
"""

import argparse
import json
from pathlib import Path

from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential

DATABASE_NAME = "ai-usage-db"
CONTAINER_NAME = "model-pricing"
DEFAULT_INPUT_FILE = Path(__file__).parent / "model-pricing.json"


def main():
    parser = argparse.ArgumentParser(description="Import model pricing data into Cosmos DB")
    parser.add_argument("--endpoint", required=True, help="Cosmos DB account endpoint URL")
    parser.add_argument("--input", default=str(DEFAULT_INPUT_FILE), help="Path to model-pricing.json")
    args = parser.parse_args()

    credential = DefaultAzureCredential()
    client = CosmosClient(url=args.endpoint, credential=credential, enable_endpoint_discovery=False)

    database = client.get_database_client(DATABASE_NAME)
    container = database.get_container_client(CONTAINER_NAME)

    with open(args.input, encoding="utf-8") as f:
        items = json.load(f)

    for item in items:
        container.upsert_item(item)
        print(f"Upserted: {item['model']} (id={item['id']})")

    print(f"\nDone. {len(items)} items imported to {DATABASE_NAME}/{CONTAINER_NAME}.")


if __name__ == "__main__":
    main()
