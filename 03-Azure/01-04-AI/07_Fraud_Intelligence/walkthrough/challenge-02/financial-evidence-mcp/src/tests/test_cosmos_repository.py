import logging

from cosmos_repository import CosmosRepository


class FakeContainer:
    def __init__(self, items=None):
        self.items = items or []
        self.read_arguments = None
        self.query_arguments = None

    def read_item(self, **kwargs):
        self.read_arguments = kwargs
        return self.items[0]

    def query_items(self, **kwargs):
        self.query_arguments = kwargs
        return iter(self.items)


def test_get_bank_normalizes_leading_zeroes_for_point_read(caplog):
    banks = FakeContainer(
        [
            {
                "id": "121",
                "partition_key": "121",
                "bank_id": "121",
                "bank_name": "Bank #121",
                "country": "United States",
                "_etag": "secret-metadata",
            }
        ]
    )
    repository = CosmosRepository(banks, FakeContainer())

    with caplog.at_level(logging.INFO, logger="cosmos_repository"):
        bank = repository.get_bank("0121")

    assert banks.read_arguments == {"item": "121", "partition_key": "121"}
    assert bank == {
        "bank_id": "121",
        "bank_name": "Bank #121",
        "country": "United States",
        "id": "121",
        "partition_key": "121",
    }
    assert "Cosmos get_bank started: bank_id=0121 normalized_bank_id=121" in caplog.text
    assert "Cosmos get_bank completed: bank_id=0121 found=true" in caplog.text


def test_account_query_matches_originator_and_destination_with_time_bounds():
    transactions = FakeContainer([{"id": "1", "_rid": "metadata"}])
    repository = CosmosRepository(FakeContainer(), transactions)

    result = repository.list_account_transactions(
        bank_id="0046617",
        account_id="8217EF2F0",
        start_time="2026-09-01T00:00:00Z",
        end_time="2026-10-01T00:00:00Z",
        limit=25,
    )

    query = transactions.query_arguments["query"]
    assert "c.from_bank_id = @bank_id AND c.from_account = @account_id" in query
    assert "c.to_bank_id = @bank_id AND c.to_account = @account_id" in query
    assert "c.txn_ts >= @start_time" in query
    assert "c.txn_ts < @end_time" in query
    assert transactions.query_arguments["enable_cross_partition_query"] is True
    assert {item["name"]: item["value"] for item in transactions.query_arguments["parameters"]} == {
        "@limit": 25,
        "@bank_id": "0046617",
        "@account_id": "8217EF2F0",
        "@start_time": "2026-09-01T00:00:00Z",
        "@end_time": "2026-10-01T00:00:00Z",
    }
    assert result == [{"id": "1"}]


def test_attempt_query_targets_its_partition_and_orders_steps():
    transactions = FakeContainer([{"id": "2", "step_in_attempt": 1}])
    repository = CosmosRepository(FakeContainer(), transactions)

    result = repository.get_laundering_attempt(2220, limit=100)

    assert transactions.query_arguments["partition_key"] == "2220"
    assert "ORDER BY c.step_in_attempt ASC" in transactions.query_arguments["query"]
    assert result == [{"step_in_attempt": 1, "id": "2"}]


def test_transaction_lookup_uses_document_and_numeric_surrogate_keys():
    transactions = FakeContainer([{"id": "111669149723"}])
    repository = CosmosRepository(FakeContainer(), transactions)

    result = repository.get_transaction("111669149723")

    assert "c.id = @transaction_id" in transactions.query_arguments["query"]
    assert "c.pattern_txn_sk = @pattern_txn_sk" in transactions.query_arguments["query"]
    assert transactions.query_arguments["parameters"] == [
        {"name": "@transaction_id", "value": "111669149723"},
        {"name": "@pattern_txn_sk", "value": 111669149723},
    ]
    assert result == {"id": "111669149723"}


def test_limit_is_bounded():
    repository = CosmosRepository(FakeContainer(), FakeContainer())

    try:
        repository.list_account_transactions("bank", "account", limit=201)
    except ValueError as exc:
        assert str(exc) == "limit must be an integer from 1 to 200"
    else:
        raise AssertionError("Expected an invalid limit to fail")