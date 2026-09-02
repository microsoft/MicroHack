import logging
import os
from datetime import datetime, timezone
from itertools import islice
from typing import Any, Iterable

from azure.cosmos import CosmosClient
from azure.cosmos.exceptions import CosmosResourceNotFoundError
from azure.identity import DefaultAzureCredential


logger = logging.getLogger(__name__)

_BANK_FIELDS = ("bank_id", "bank_name", "country", "id", "partition_key")
_TRANSACTION_FIELDS = (
    "pattern_txn_sk",
    "attempt_id",
    "pattern_type",
    "step_in_attempt",
    "date_key",
    "txn_ts",
    "from_bank_id",
    "from_account",
    "to_bank_id",
    "to_account",
    "amount_received",
    "receiving_currency",
    "amount_paid",
    "payment_currency",
    "payment_format",
    "is_laundering",
    "id",
    "partition_key",
)


class CosmosRepository:
    def __init__(self, bank_container: Any, transaction_container: Any) -> None:
        self._bank_container = bank_container
        self._transaction_container = transaction_container

    @classmethod
    def from_environment(cls) -> "CosmosRepository":
        database_name = _required_environment("COSMOS_DATABASE_NAME")
        bank_container_name = os.getenv("COSMOS_BANK_CONTAINER", "dim-bank")
        transaction_container_name = os.getenv(
            "COSMOS_TRANSACTION_CONTAINER", "fact-laundering-pattern-txn"
        )

        connection_string = os.getenv("COSMOS_CONNECTION_STRING")
        if connection_string:
            logger.info(
                "Creating Cosmos repository: database=%s auth=connection_string",
                database_name,
            )
            client = CosmosClient.from_connection_string(connection_string)
        else:
            endpoint = _required_environment("COSMOS_ENDPOINT")
            logger.info(
                "Creating Cosmos repository: database=%s auth=managed_identity",
                database_name,
            )
            client = CosmosClient(endpoint, credential=DefaultAzureCredential())

        database = client.get_database_client(database_name)
        logger.info(
            "Cosmos repository ready: bank_container=%s transaction_container=%s",
            bank_container_name,
            transaction_container_name,
        )
        return cls(
            database.get_container_client(bank_container_name),
            database.get_container_client(transaction_container_name),
        )

    def get_bank(self, bank_id: str) -> dict[str, Any] | None:
        normalized_bank_id = _required_string(bank_id, "bank_id").lstrip("0") or "0"
        logger.info(
            "Cosmos get_bank started: bank_id=%s normalized_bank_id=%s",
            bank_id,
            normalized_bank_id,
        )
        try:
            item = self._bank_container.read_item(
                item=normalized_bank_id,
                partition_key=normalized_bank_id,
            )
        except CosmosResourceNotFoundError:
            logger.info("Cosmos get_bank completed: bank_id=%s found=false", bank_id)
            return None
        logger.info("Cosmos get_bank completed: bank_id=%s found=true", bank_id)
        return _select_fields(item, _BANK_FIELDS)

    def list_account_transactions(
        self,
        bank_id: str,
        account_id: str,
        start_time: str | None = None,
        end_time: str | None = None,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        normalized_bank_id = _required_string(bank_id, "bank_id")
        normalized_account_id = _required_string(account_id, "account_id")
        normalized_limit = _bounded_limit(limit)
        logger.info(
            "Cosmos list_account_transactions started: bank_id=%s account_id=%s "
            "start_time=%s end_time=%s limit=%s",
            normalized_bank_id,
            normalized_account_id,
            start_time,
            end_time,
            normalized_limit,
        )

        predicates = [
            "((c.from_bank_id = @bank_id AND c.from_account = @account_id)",
            "OR (c.to_bank_id = @bank_id AND c.to_account = @account_id))",
        ]
        parameters: list[dict[str, Any]] = [
            {"name": "@limit", "value": normalized_limit},
            {"name": "@bank_id", "value": normalized_bank_id},
            {"name": "@account_id", "value": normalized_account_id},
        ]

        if start_time:
            predicates.append("AND c.txn_ts >= @start_time")
            parameters.append(
                {"name": "@start_time", "value": _iso_timestamp(start_time, "start_time")}
            )
        if end_time:
            predicates.append("AND c.txn_ts < @end_time")
            parameters.append(
                {"name": "@end_time", "value": _iso_timestamp(end_time, "end_time")}
            )

        query = (
            "SELECT TOP @limit * FROM c WHERE "
            + " ".join(predicates)
            + " ORDER BY c.txn_ts DESC"
        )
        items = self._transaction_container.query_items(
            query=query,
            parameters=parameters,
            enable_cross_partition_query=True,
            max_item_count=normalized_limit,
        )
        transactions = _transactions(items, normalized_limit)
        logger.info(
            "Cosmos list_account_transactions completed: bank_id=%s account_id=%s count=%s",
            normalized_bank_id,
            normalized_account_id,
            len(transactions),
        )
        return transactions

    def get_transaction(self, transaction_id: str) -> dict[str, Any] | None:
        normalized_id = _required_string(transaction_id, "transaction_id")
        logger.info("Cosmos get_transaction started: transaction_id=%s", normalized_id)
        predicates = ["c.id = @transaction_id"]
        parameters: list[dict[str, Any]] = [
            {"name": "@transaction_id", "value": normalized_id}
        ]
        try:
            pattern_txn_sk = int(normalized_id)
        except ValueError:
            pass
        else:
            predicates.append("c.pattern_txn_sk = @pattern_txn_sk")
            parameters.append({"name": "@pattern_txn_sk", "value": pattern_txn_sk})

        items = self._transaction_container.query_items(
            query="SELECT TOP 1 * FROM c WHERE " + " OR ".join(predicates),
            parameters=parameters,
            enable_cross_partition_query=True,
            max_item_count=1,
        )
        transactions = _transactions(items, 1)
        transaction = transactions[0] if transactions else None
        logger.info(
            "Cosmos get_transaction completed: transaction_id=%s found=%s",
            normalized_id,
            str(transaction is not None).lower(),
        )
        return transaction

    def get_laundering_attempt(
        self, attempt_id: int, limit: int = 100
    ) -> list[dict[str, Any]]:
        try:
            normalized_attempt_id = int(attempt_id)
        except (TypeError, ValueError) as exc:
            raise ValueError("attempt_id must be an integer") from exc
        if normalized_attempt_id < 0:
            raise ValueError("attempt_id must be zero or greater")

        normalized_limit = _bounded_limit(limit)
        partition_key = str(normalized_attempt_id)
        logger.info(
            "Cosmos get_laundering_attempt started: attempt_id=%s limit=%s",
            normalized_attempt_id,
            normalized_limit,
        )
        items = self._transaction_container.query_items(
            query=(
                "SELECT TOP @limit * FROM c "
                "WHERE c.attempt_id = @attempt_id "
                "ORDER BY c.step_in_attempt ASC"
            ),
            parameters=[
                {"name": "@limit", "value": normalized_limit},
                {"name": "@attempt_id", "value": normalized_attempt_id},
            ],
            partition_key=partition_key,
            max_item_count=normalized_limit,
        )
        transactions = _transactions(items, normalized_limit)
        logger.info(
            "Cosmos get_laundering_attempt completed: attempt_id=%s count=%s",
            normalized_attempt_id,
            len(transactions),
        )
        return transactions


def _required_environment(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise ValueError(f"Required setting {name} is not configured")
    return value


def _required_string(value: Any, name: str) -> str:
    normalized = str(value).strip() if value is not None else ""
    if not normalized:
        raise ValueError(f"{name} is required")
    return normalized


def _bounded_limit(value: Any) -> int:
    try:
        limit = int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError("limit must be an integer from 1 to 200") from exc
    if not 1 <= limit <= 200:
        raise ValueError("limit must be an integer from 1 to 200")
    return limit


def _iso_timestamp(value: str, name: str) -> str:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError(f"{name} must be an ISO 8601 timestamp") from exc
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def _select_fields(item: dict[str, Any], fields: tuple[str, ...]) -> dict[str, Any]:
    return {field: item[field] for field in fields if field in item}


def _transactions(
    items: Iterable[dict[str, Any]], limit: int
) -> list[dict[str, Any]]:
    return [
        _select_fields(item, _TRANSACTION_FIELDS)
        for item in islice(items, limit)
    ]