# Oracle ADB Network Testing Container - Final Production Version
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
        # Java for adbping
        java-11-openjdk-devel \
    && dnf clean all

# Install Oracle Instant Client
RUN dnf install -y oracle-instantclient-basic oracle-instantclient-sqlplus && \
    dnf clean all

# Set environment variables
ENV ORACLE_HOME=/usr/lib/oracle/21/client64 \
    JAVA_HOME=/usr/lib/jvm/java-11-openjdk \
    TNS_ADMIN=/opt/oracle/wallet \
    PATH="/usr/local/bin:$PATH:/usr/lib/oracle/21/client64/bin" \
    LD_LIBRARY_PATH="/usr/lib/oracle/21/client64/lib" \
    CLASSPATH="/usr/local/lib/ojdbc8.jar:/usr/local/lib/ucp.jar:/usr/local/lib/oraclepki.jar:/usr/local/lib/osdt_cert.jar:/usr/local/lib/osdt_core.jar:/usr/local/lib"

# Create directories
RUN mkdir -p /opt/adbping /opt/oracle/wallet /usr/local/lib

# Copy and extract adbping tools
COPY 2863450.1-ADBPING_LINUX.X64-adbping_Linux.X64_230127.zip /tmp/adbping.zip

# Extract adbping and install to system paths for immediate use
RUN cd /tmp && \
    unzip adbping.zip && \
    find . -name "adbping" -type f -executable -exec cp {} /usr/local/bin/adbping \; && \
    find . -name "*.jar" -exec cp {} /usr/local/lib/ \; && \
    find . -name "*.class" -exec cp {} /usr/local/lib/ \; && \
    chmod +x /usr/local/bin/adbping && \
    rm -rf /tmp/adbping.zip /tmp/adbping* && \
    echo "adbping installed to /usr/local/bin/adbping"

# Copy support scripts
COPY network-test.sh /opt/adbping/
COPY entrypoint.sh /opt/adbping/
RUN chmod +x /opt/adbping/*.sh

# Create non-root user for security
RUN groupadd -r adbping && useradd -r -g adbping adbping && \
    chown -R adbping:adbping /opt/adbping /opt/oracle

# Switch to non-root user
USER adbping
WORKDIR /opt/adbping

# Default entrypoint
ENTRYPOINT ["/opt/adbping/entrypoint.sh"]
CMD ["--help"]