FROM mcr.microsoft.com/devcontainers/python:1-3.12-bookworm

RUN python -m pip install --no-cache-dir \
    --index-url https://packagefeedproxy.microsoft.io/pypi/simple/ uv==0.12.10

ENV UV_PROJECT_ENVIRONMENT=/home/vscode/.venvs/regintel \
    UV_PYTHON_DOWNLOADS=never \
    PATH="/home/vscode/.venvs/regintel/bin:${PATH}"

RUN mkdir -p /home/vscode/.venvs && chown vscode:vscode /home/vscode/.venvs