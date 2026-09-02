import argparse
import json
import os
import random
import string
import uuid
from dataclasses import dataclass
from typing import Any

from azure.ai.projects import AIProjectClient
from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv

DEFAULT_AGENT_NAME = "fraud-intelligence-orchestration"
DEFAULT_DATABASE_NAME = "aml"
DEFAULT_BANK_CONTAINER = "dim-bank"
DEFAULT_PATTERN_CONTAINER = "fact-laundering-pattern-txn"
MAX_BANK_SELECTION_ATTEMPTS = 20

CURRENCIES = ("EUR", "USD", "GBP", "CHF", "JPY", "CAD", "AUD")
ORIGINATOR_NAMES = (
    "James Carter",
    "Sophia Bennett",
    "Liam Anderson",
    "Olivia Hughes",
    "Daniel Morgan",
    "Ava Richardson",
    "Lucas Thompson",
    "Mia Sullivan",
    "Alexander Wright",
    "Charlotte Evans",
    "Mateo Garcia",
    "Sofia Martinez",
    "Hugo Laurent",
    "Camille Bernard",
    "Luca Romano",
    "Giulia Conti",
    "Jonas Schneider",
    "Anna Fischer",
    "Kenji Sato",
    "Yuki Tanaka",
)
BENEFICIARY_NAMES = (
    "Emily Foster",
    "Noah Mitchell",
    "Isabella Reed",
    "Ethan Brooks",
    "Grace Campbell",
    "Henry Parker",
    "Amelia Ward",
    "Benjamin Cooper",
    "Victoria Bailey",
    "Samuel Turner",
    "Diego Lopez",
    "Valentina Torres",
    "Louis Moreau",
    "Manon Dubois",
    "Marco Bianchi",
    "Elena Rossi",
    "Felix Wagner",
    "Laura Becker",
    "Haruto Suzuki",
    "Aoi Nakamura",
)


@dataclass(frozen=True)
class Bank:
    bank_id: str
    bank_name: str
    country: str


class CosmosTransactionSampler:
    def __init__(
        self,
        client: CosmosClient,
        *,
        database_name: str,
        bank_container_name: str,
        pattern_container_name: str,
        random_source: random.Random,
    ) -> None:
        database = client.get_database_client(database_name)
        self._banks = database.get_container_client(bank_container_name)
        self._patterns = database.get_container_client(pattern_container_name)
        self._random = random_source
        self._bank_count = self._count(self._banks)
        self._pattern_count = self._count(self._patterns)

        if self._bank_count < 2:
            raise RuntimeError(f"Container {bank_container_name!r} must contain at least two banks")
        if self._pattern_count < 1:
            raise RuntimeError(f"Container {pattern_container_name!r} contains no transactions")

    @staticmethod
    def _count(container: Any) -> int:
        return int(
            next(
                iter(
                    container.query_items(
                        query="SELECT VALUE COUNT(1) FROM c",
                        enable_cross_partition_query=True,
                    )
                )
            )
        )

    def random_bank(self, *, exclude_bank_id: str | None = None) -> Bank:
        for _ in range(10):
            offset = self._random.randrange(self._bank_count)
            items = list(
                self._banks.query_items(
                    query=(
                        "SELECT c.bank_id, c.bank_name, c.country FROM c "
                        "ORDER BY c.bank_id OFFSET @offset LIMIT 1"
                    ),
                    parameters=[{"name": "@offset", "value": offset}],
                    enable_cross_partition_query=True,
                )
            )
            if items and str(items[0]["bank_id"]) != exclude_bank_id:
                return self._to_bank(items[0])
        raise RuntimeError("Could not select a distinct random bank")

    def pattern_account_for_bank(self, bank: Bank) -> tuple[str, str, str] | None:
        normalized_bank_id = bank.bank_id.lstrip("0") or "0"
        predicates = [
            "c.from_bank_id = @bank_id",
            "c.to_bank_id = @bank_id",
        ]
        parameters: list[dict[str, Any]] = [
            {"name": "@bank_id", "value": bank.bank_id},
        ]
        if normalized_bank_id.isdigit():
            predicates.extend(
                (
                    "StringToNumber(c.from_bank_id) = @numeric_bank_id",
                    "StringToNumber(c.to_bank_id) = @numeric_bank_id",
                )
            )
            parameters.append(
                {"name": "@numeric_bank_id", "value": int(normalized_bank_id)}
            )

        items = list(
            self._patterns.query_items(
                query=(
                    "SELECT TOP 1 c.from_bank_id, c.from_account, "
                    "c.to_bank_id, c.to_account FROM c WHERE "
                    + " OR ".join(predicates)
                ),
                parameters=parameters,
                enable_cross_partition_query=True,
            )
        )
        if not items:
            return None

        pattern = items[0]
        from_bank_id = str(pattern["from_bank_id"])
        if (from_bank_id.lstrip("0") or "0") == normalized_bank_id:
            return "origin", from_bank_id, str(pattern["from_account"])

        to_bank_id = str(pattern["to_bank_id"])
        return "destination", to_bank_id, str(pattern["to_account"])

    @staticmethod
    def _to_bank(item: dict[str, Any]) -> Bank:
        return Bank(
            bank_id=str(item["bank_id"]),
            bank_name=str(item["bank_name"]),
            country=str(item["country"]),
        )


def random_account(random_source: random.Random) -> str:
    return "".join(random_source.choices(string.hexdigits[:16].upper(), k=9))


def build_transaction(
    sampler: CosmosTransactionSampler,
    *,
    use_pattern_account: bool,
    random_source: random.Random,
) -> dict[str, Any]:
    origin_bank: Bank
    destination_bank: Bank

    if use_pattern_account:
        for _ in range(MAX_BANK_SELECTION_ATTEMPTS):
            selected_bank = sampler.random_bank()
            pattern_account = sampler.pattern_account_for_bank(selected_bank)
            if pattern_account is None:
                continue

            side, pattern_bank_id, account = pattern_account
            matched_bank = Bank(
                bank_id=pattern_bank_id,
                bank_name=selected_bank.bank_name,
                country=selected_bank.country,
            )
            if side == "origin":
                origin_bank = matched_bank
                origin_account = account
                destination_bank = sampler.random_bank(exclude_bank_id=selected_bank.bank_id)
                destination_account = random_account(random_source)
            else:
                destination_bank = matched_bank
                destination_account = account
                origin_bank = sampler.random_bank(exclude_bank_id=selected_bank.bank_id)
                origin_account = random_account(random_source)
            break
        else:
            raise RuntimeError(
                f"Could not find a bank with a laundering-pattern transaction "
                f"after {MAX_BANK_SELECTION_ATTEMPTS} attempts"
            )
    else:
        origin_bank = sampler.random_bank()
        destination_bank = sampler.random_bank(exclude_bank_id=origin_bank.bank_id)
        origin_account = random_account(random_source)
        destination_account = random_account(random_source)

    return {
        "transaction_id": f"TX-TEST-{uuid.uuid4().hex[:12].upper()}",
        "originator_name": random_source.choice(ORIGINATOR_NAMES),
        "origin_account": origin_account,
        "bank_origin": origin_bank.bank_id,
        "beneficiary_name": random_source.choice(BENEFICIARY_NAMES),
        "destination_account": destination_account,
        "bank_destination": destination_bank.bank_id,
        "amount": random_source.randint(10_000, 100_000),
        "currency": random_source.choice(CURRENCIES),
    }


def invoke_hosted_agent(
    project_client: AIProjectClient,
    *,
    agent_name: str,
    payload: dict[str, Any],
) -> str:
    openai_client = project_client.get_openai_client(agent_name=agent_name)
    response = openai_client.responses.create(
        input=json.dumps(payload),
    )
    return response.output_text


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate transactions from Cosmos DB and invoke the Fraud Intelligence hosted agent."
    )
    parser.add_argument("--count", type=int, default=1, help="Number of independent requests to send")
    parser.add_argument("--seed", type=int, help="Seed for reproducible data selection")
    parser.add_argument("--dry-run", action="store_true", help="Print payloads without invoking the agent")
    parser.add_argument("--project-endpoint", default=os.getenv("FOUNDRY_PROJECT_ENDPOINT"))
    parser.add_argument("--agent-name", default=os.getenv("FOUNDRY_HOSTED_AGENT_NAME", DEFAULT_AGENT_NAME))
    parser.add_argument("--cosmos-endpoint", default=os.getenv("AZURE_COSMOS_ENDPOINT"))
    parser.add_argument("--database", default=os.getenv("AZURE_COSMOS_DATABASE", DEFAULT_DATABASE_NAME))
    parser.add_argument("--bank-container", default=os.getenv("AZURE_COSMOS_BANK_CONTAINER", DEFAULT_BANK_CONTAINER))
    parser.add_argument(
        "--pattern-container",
        default=os.getenv("AZURE_COSMOS_PATTERN_CONTAINER", DEFAULT_PATTERN_CONTAINER),
    )
    args = parser.parse_args()
    if args.count < 1:
        parser.error("--count must be at least 1")
    if not args.cosmos_endpoint:
        parser.error("set AZURE_COSMOS_ENDPOINT or pass --cosmos-endpoint")
    if not args.project_endpoint and not args.dry_run:
        parser.error("set FOUNDRY_PROJECT_ENDPOINT or pass --project-endpoint")
    return args


def main() -> None:
    load_dotenv()
    args = parse_args()
    random_source = random.Random(args.seed)

    with DefaultAzureCredential() as credential:
        cosmos_client = CosmosClient(args.cosmos_endpoint, credential=credential)
        sampler = CosmosTransactionSampler(
            cosmos_client,
            database_name=args.database,
            bank_container_name=args.bank_container,
            pattern_container_name=args.pattern_container,
            random_source=random_source,
        )

        if args.dry_run:
            project_client = None
        else:
            project_client = AIProjectClient(
                endpoint=args.project_endpoint,
                credential=credential,
                allow_preview=True,
            )

        try:
            for request_index in range(args.count):
                use_pattern_account = request_index % 2 == 1
                payload = build_transaction(
                    sampler,
                    use_pattern_account=use_pattern_account,
                    random_source=random_source,
                )
                print(f"\nRequest {request_index + 1}/{args.count} (pattern account: {use_pattern_account})")
                print(json.dumps(payload, indent=2))

                if project_client is not None:
                    result = invoke_hosted_agent(
                        project_client,
                        agent_name=args.agent_name,
                        payload=payload,
                    )
                    print(f"Response:\n{result}")
        finally:
            if project_client is not None:
                project_client.close()
            cosmos_client.close()


if __name__ == "__main__":
    main()