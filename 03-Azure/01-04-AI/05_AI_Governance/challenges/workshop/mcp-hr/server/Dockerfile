# The base image bundles both Python 3.13 and uv. It is parameterized so the
# build can pull it from a registry that is not rate-limited (e.g. a copy
# imported into your ACR with `az acr import`). The default uses GHCR, which is
# not subject to Docker Hub's anonymous pull-rate limit.
ARG BASE_IMAGE=ghcr.io/astral-sh/uv:python3.13-bookworm-slim

FROM ${BASE_IMAGE}

ENV UV_SYSTEM_PYTHON=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PORT=8080

WORKDIR /app/mcp-hr/server

# The build context is this directory (mcp-hr/server), so paths are local. This
# keeps the ACR upload small instead of tarring the whole workshop tree.
COPY requirements.txt .
RUN uv pip install --system --no-cache --prerelease=if-necessary-or-explicit -r requirements.txt

COPY . .

EXPOSE 8080

CMD ["python", "server.py"]
