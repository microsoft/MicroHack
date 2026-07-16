FROM mcr.microsoft.com/devcontainers/base:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        make \
        sqlite3 \
    && rm -rf /var/lib/apt/lists/*
