FROM mcr.microsoft.com/devcontainers/python:1-3.11-bullseye

# Remove Yarn apt repo entirely to avoid expired GPG key errors during feature installs
USER root
RUN rm -f /etc/apt/sources.list.d/yarn.list \
    && rm -f /usr/share/keyrings/yarn.gpg
