# Base images are parameterized so the build can pull them from a registry that
# is not rate-limited (e.g. a copy imported into your ACR with `az acr import`).
# Defaults use the public images directly.
ARG BASE_IMAGE=python:3.13-slim
ARG UV_IMAGE=ghcr.io/astral-sh/uv:latest

FROM ${UV_IMAGE} AS uv
FROM ${BASE_IMAGE}

# Bring in uv (fast, reliable installs).
COPY --from=uv /uv /uvx /bin/

ENV UV_SYSTEM_PYTHON=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

WORKDIR /app
COPY requirements.txt .
RUN uv pip install --system --no-cache --prerelease=if-necessary-or-explicit -r requirements.txt
RUN python -c "import mcp, httpx; from mcp.client.streamable_http import streamable_http_client; from agent_framework import MCPStreamableHTTPTool; from agent_framework.foundry import FoundryChatClient; from agent_framework_foundry_hosting import ResponsesHostServer; print('dependency smoke ok')"

COPY main.py .

EXPOSE 8088

CMD ["python", "main.py"]
