FROM mcr.microsoft.com/devcontainers/base:ubuntu

RUN curl -fsSL \
        https://raw.githubusercontent.com/microsoft/modernize-cli/main/scripts/install.sh \
        -o /tmp/install-modernize.sh \
    && MODERNIZE_INSTALL_DIR=/usr/local/lib/modernize \
        MODERNIZE_BIN_DIR=/usr/local/bin \
        sh /tmp/install-modernize.sh \
    && modernize --version \
    && rm /tmp/install-modernize.sh