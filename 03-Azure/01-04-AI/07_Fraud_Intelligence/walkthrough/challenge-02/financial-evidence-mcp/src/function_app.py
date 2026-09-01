import json
import logging
from functools import lru_cache
from typing import Any, Callable

import azure.functions as func

from cosmos_repository import CosmosRepository


app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)
logger = logging.getLogger(__name__)


@lru_cache(maxsize=1)
def _repository() -> CosmosRepository:
    logger.info("Initializing Cosmos repository")
    return CosmosRepository.from_environment()


def _response(operation_name: str, operation: Callable[[], Any]) -> str:
    logger.info("MCP operation started: %s", operation_name)
    try:
        result = operation()
        logger.info("MCP operation completed: %s", operation_name)
        return json.dumps({"ok": True, "data": result}, default=str)
    except ValueError as exc:
        logger.warning("MCP operation rejected: %s error=%s", operation_name, exc)
        return json.dumps({"ok": False, "error": str(exc)})
    except Exception:
        logger.exception("MCP operation failed: %s", operation_name)
        return json.dumps(
            {"ok": False, "error": "The financial evidence service is unavailable."}
        )


@app.mcp_tool()
@app.mcp_tool_property(
    arg_name="bank_id",
    description="Bank identifier. Leading zeroes are normalized for the bank dimension.",
    is_required=True,
)
def get_bank_information(bank_id: str) -> str:
    """Get a bank's name and country from the bank dimension."""

    def operation() -> dict[str, Any]:
        bank = _repository().get_bank(bank_id)
        return {"found": bank is not None, "bank": bank}

    return _response("get_bank_information", operation)


@app.mcp_tool()
@app.mcp_tool_property(
    arg_name="bank_id",
    description="Exact bank identifier. Pass it as a string to preserve leading zeroes.",
    is_required=True,
)
@app.mcp_tool_property(
    arg_name="account_id",
    description="Exact account identifier at the bank.",
    is_required=True,
)
@app.mcp_tool_property(
    arg_name="start_time",
    description="Optional inclusive ISO 8601 transaction timestamp.",
    is_required=False,
)
@app.mcp_tool_property(
    arg_name="end_time",
    description="Optional exclusive ISO 8601 transaction timestamp.",
    is_required=False,
)
@app.mcp_tool_property(
    arg_name="limit",
    description="Maximum transactions to return, from 1 to 200.",
    is_required=False,
)
def list_account_transactions(
    bank_id: str,
    account_id: str,
    start_time: str = "",
    end_time: str = "",
    limit: int = 50,
) -> str:
    """List transactions where the bank and account are either party."""

    def operation() -> dict[str, Any]:
        transactions = _repository().list_account_transactions(
            bank_id=bank_id,
            account_id=account_id,
            start_time=start_time or None,
            end_time=end_time or None,
            limit=limit,
        )
        return {"count": len(transactions), "transactions": transactions}

    return _response("list_account_transactions", operation)


@app.mcp_tool()
@app.mcp_tool_property(
    arg_name="transaction_id",
    description="Transaction document id or pattern transaction surrogate key.",
    is_required=True,
)
def get_transaction(transaction_id: str) -> str:
    """Get one transaction by its identifier."""

    def operation() -> dict[str, Any]:
        transaction = _repository().get_transaction(transaction_id)
        return {"found": transaction is not None, "transaction": transaction}

    return _response("get_transaction", operation)


@app.mcp_tool()
@app.mcp_tool_property(
    arg_name="attempt_id",
    description="Money-laundering pattern attempt identifier.",
    is_required=True,
)
@app.mcp_tool_property(
    arg_name="limit",
    description="Maximum timeline steps to return, from 1 to 200.",
    is_required=False,
)
def get_laundering_attempt(attempt_id: int, limit: int = 100) -> str:
    """Get an ordered transaction timeline for a laundering attempt."""

    def operation() -> dict[str, Any]:
        transactions = _repository().get_laundering_attempt(attempt_id, limit)
        return {
            "attempt_id": attempt_id,
            "count": len(transactions),
            "transactions": transactions,
        }

    return _response("get_laundering_attempt", operation)