FROM mcr.microsoft.com/devcontainers/base:ubuntu

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        make \
        sqlite3 \
    && rm -rf /var/lib/apt/lists/*
