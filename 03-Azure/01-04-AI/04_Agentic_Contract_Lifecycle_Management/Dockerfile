# syntax=docker/dockerfile:1
# =============================================================================
# Challenge 4 — container image for the CLM MCP server (remote / streamable-HTTP)
# -----------------------------------------------------------------------------
# The build CONTEXT must be the REPO ROOT — the image needs requirements.txt and
# src/. Deploy it with one command (builds in the cloud, no local Docker needed):
#
#     az containerapp up -n clm-mcp -g <rg> --source . \
#         --target-port 8000 --ingress external \
#         --env-vars AZURE_AI_PROJECT_ENDPOINT=<your-project-endpoint>
#
# The server then exposes the MCP tools at:
#     https://<app-name>.<region>.azurecontainerapps.io/mcp
# which a Foundry agent (portal Playground or orchestrator_mcp.py with CLM_MCP_URL)
# connects to as an MCP client. See challenges/challenge-04.md · Task 4.
# =============================================================================
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    MCP_TRANSPORT=streamable-http \
    MCP_HOST=0.0.0.0 \
    MCP_PORT=8000

WORKDIR /app

# unixodbc is only needed if you wire AZURE_SQL_CONNECTION_STRING (pyodbc);
# harmless otherwise. curl is used by the container HEALTHCHECK below.
RUN apt-get update \
    && apt-get install -y --no-install-recommends unixodbc curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install -r requirements.txt

COPY src/ ./src/

EXPOSE 8000

# Liveness: the streamable-HTTP endpoint answers on /mcp once the app is up.
# (A bare GET returns 4xx without a session — that still proves it's serving, so
# we don't use `-f`; any HTTP response means the process is alive.)
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl -s -o /dev/null "http://127.0.0.1:${MCP_PORT}/mcp" || exit 1

# Run the Challenge 4 MCP server over streamable HTTP on :8000.
CMD ["python", "src/mcp_server/server.py", "--http"]
