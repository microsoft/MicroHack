FROM python:3.13-slim

# Install uv from the official distroless image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV UV_SYSTEM_PYTHON=1     UV_COMPILE_BYTECODE=1     UV_LINK_MODE=copy

WORKDIR /app
COPY requirements.txt .
RUN uv pip install --system --no-cache --prerelease=if-necessary-or-explicit -r requirements.txt
RUN python -c "from pydantic._internal._typing_extra import eval_type_backport; import mcp; from agent_framework_foundry_hosting import ResponsesHostServer; print('dependency smoke ok')"

COPY main.py .
COPY policies/ ./policies/

EXPOSE 8088

CMD ["python", "main.py"]
