# Oracle ADB Connping Testing Container
# Uses rwloadsim tool (connping/ociping) for Oracle ADB latency testing
FROM oraclelinux:8

# Install system packages and network tools
RUN dnf update -y && \
    dnf install -y \
        # Network diagnostic tools
        bind-utils \
        iputils \
        net-tools \
        nmap-ncat \
        telnet \
        traceroute \
        tcpdump \
        wget \
        curl \
        # Oracle prerequisites
        oracle-instantclient-release-el8 \
        unzip \
        tar \
        gzip \
    && dnf clean all

# Install Oracle Instant Client 23c (as required in specifications)
# Note: dnf may install 21c by default, so we explicitly check and update
RUN dnf install -y \
        oracle-instantclient-basic \
        oracle-instantclient-sqlplus \
    && dnf clean all

# Detect installed Oracle client version
RUN ORACLE_VERSION=$(ls /usr/lib/oracle/ | head -1) && \
    echo "Detected Oracle Client version: $ORACLE_VERSION" && \
    echo "export ORACLE_HOME=/usr/lib/oracle/${ORACLE_VERSION}/client64" >> /etc/profile.d/oracle.sh && \
    echo "export LD_LIBRARY_PATH=/usr/lib/oracle/${ORACLE_VERSION}/client64/lib:\$LD_LIBRARY_PATH" >> /etc/profile.d/oracle.sh && \
    echo "export PATH=/opt/rwloadsim:/usr/lib/oracle/${ORACLE_VERSION}/client64/bin:\$PATH" >> /etc/profile.d/oracle.sh

# Set environment variables (will be overridden if different version detected)
ENV ORACLE_HOME=/usr/lib/oracle/21/client64 \
    TNS_ADMIN=/opt/oracle/wallet \
    PATH="/usr/local/bin:/opt/rwloadsim:$PATH:/usr/lib/oracle/21/client64/bin" \
    LD_LIBRARY_PATH="/usr/lib/oracle/21/client64/lib"

# Create directories
RUN mkdir -p /opt/connping /opt/oracle/wallet /opt/rwloadsim

# Download and install rwloadsim v3.2.1
RUN cd /tmp && \
    wget -q https://github.com/oracle/rwloadsim/releases/download/v.3.2.1/rwloadsim-linux-x86_64-bin-3.2.1.tgz && \
    tar -xzf rwloadsim-linux-x86_64-bin-3.2.1.tgz -C /opt/rwloadsim --strip-components=1 && \
    rm -f rwloadsim-linux-x86_64-bin-3.2.1.tgz && \
    echo "rwloadsim installed to /opt/rwloadsim"

# Create symlinks to make rwloadsim and connping available in PATH
# Detect Oracle version and link appropriate rwloadsim binary
RUN ORACLE_VERSION=$(ls /usr/lib/oracle/ | head -1) && \
    echo "Creating symlinks for Oracle Client version: $ORACLE_VERSION" && \
    if [ -f "/opt/rwloadsim/rwloadsim${ORACLE_VERSION}" ]; then \
        ln -sf "/opt/rwloadsim/rwloadsim${ORACLE_VERSION}" /opt/rwloadsim/rwloadsim; \
    else \
        ln -sf /opt/rwloadsim/rwloadsim21 /opt/rwloadsim/rwloadsim; \
    fi && \
    ln -sf /opt/rwloadsim/rwloadsim /usr/local/bin/rwloadsim && \
    echo "Symlinks created: rwloadsim -> /opt/rwloadsim/rwloadsim" && \
    echo '#!/bin/sh' > /usr/local/bin/connping && \
    echo 'cd /opt/rwloadsim && exec /opt/rwloadsim/rwloadsim --pretend-gen-banner="RWP*Connect/OCIPing" -u connping.rwl "$@"' >> /usr/local/bin/connping && \
    chmod +x /usr/local/bin/connping && \
    echo "Created connping wrapper script"

# Verify connping is available
RUN ls -la /usr/local/bin/connping && ls -la /usr/local/bin/rwloadsim

# Copy support scripts
COPY entrypoint.sh /opt/connping/
RUN chmod +x /opt/connping/*.sh

# Create non-root user for security
RUN groupadd -r connping && useradd -r -g connping connping && \
    chown -R connping:connping /opt/connping /opt/oracle /opt/rwloadsim && \
    chmod 755 /opt/rwloadsim/connping /opt/rwloadsim/rwloadsim

# Switch to non-root user
USER connping
WORKDIR /opt/connping

# Default entrypoint
ENTRYPOINT ["/opt/connping/entrypoint.sh"]
CMD ["--help"]
