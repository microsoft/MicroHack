"""
Buggy Flask app for Azure Copilot Workshop - Challenge 02 (Observability Agent).

This app intentionally has issues that generate Application Insights alerts:
- /crash  -> raises unhandled exception (500 error)
- /slow   -> artificially slow response (>3s)  
- /leak   -> simulates memory-growing response
- /       -> healthy endpoint (200 OK)
- /health -> health check
"""
import time
import logging
from flask import Flask, jsonify
from azure.monitor.opentelemetry import configure_azure_monitor

configure_azure_monitor()

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# Accumulator to simulate growing memory usage
_data_store = []


@app.route("/")
def home():
    return jsonify({"status": "ok", "message": "Contoso Workshop App - Ch02 Observability"})


@app.route("/health")
def health():
    return jsonify({"status": "healthy"})


@app.route("/crash")
def crash():
    """Intentionally raises an unhandled exception -> 500 in App Insights."""
    app.logger.error("About to crash!")
    raise RuntimeError(
        "Simulated crash for Copilot workshop observability demo")


@app.route("/slow")
def slow():
    """Artificially slow endpoint -> triggers response-time alerts."""
    delay = 5  # seconds
    app.logger.warning(f"Slow endpoint hit, sleeping {delay}s")
    time.sleep(delay)
    return jsonify({"status": "ok", "delay_seconds": delay})


@app.route("/leak")
def leak():
    """Simulates growing memory usage per request."""
    _data_store.extend(["x" * 1024] * 500)  # ~500 KB per call
    return jsonify({"status": "ok", "accumulated_items": len(_data_store)})


@app.route("/api/orders")
def orders():
    """Simulates a database timeout for a business-critical endpoint."""
    app.logger.error("Database connection timeout on /api/orders")
    time.sleep(2)
    raise ConnectionError(
        "Simulated DB timeout: could not reach orders database")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
