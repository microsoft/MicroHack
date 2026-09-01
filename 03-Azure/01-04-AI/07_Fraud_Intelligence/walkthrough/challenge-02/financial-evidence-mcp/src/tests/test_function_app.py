import json
import logging

from function_app import _response


def test_response_logs_operation_start_and_completion(caplog):
    with caplog.at_level(logging.INFO, logger="function_app"):
        response = _response("test_operation", lambda: {"found": True})

    assert json.loads(response) == {"ok": True, "data": {"found": True}}
    assert "MCP operation started: test_operation" in caplog.text
    assert "MCP operation completed: test_operation" in caplog.text


def test_response_logs_validation_errors(caplog):
    def invalid_operation():
        raise ValueError("invalid input")

    with caplog.at_level(logging.INFO, logger="function_app"):
        response = _response("test_operation", invalid_operation)

    assert json.loads(response) == {"ok": False, "error": "invalid input"}
    assert "MCP operation rejected: test_operation error=invalid input" in caplog.text
