FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install additional tools
RUN apt-get update && apt-get install -y \
    jq \
    curl \
    unzip \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install OCI CLI
RUN pip3 install oci-cli --break-system-packages

# Create workspace directory
RUN mkdir -p /workspace

# Create OCI config directory
RUN mkdir -p /home/vscode/.oci

# Set working directory
WORKDIR /workspace
