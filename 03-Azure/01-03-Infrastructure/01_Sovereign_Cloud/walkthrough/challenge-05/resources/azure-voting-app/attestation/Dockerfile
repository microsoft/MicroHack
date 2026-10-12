# Optional pre-built image for the attestation web UI.
#
# This image is NOT required by Deploy-VotingAppCC.ps1 - that script bootstraps
# the same code at pod startup from a ConfigMap so the sample works without an
# attached ACR. Use this Dockerfile if you want to bake the app into a real
# image and push it to your own registry.
#
# Build:   docker build -t <registry>/cc-attestation-web:1.0 .
# Run:     docker run --rm -p 8080:80 --device=/dev/tpmrm0 <image>
FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    CVM_TOOLS_DIR=/opt/cvm-tools/cvm-attestation

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        git ca-certificates tpm2-tools \
 && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/Azure/cvm-attestation-tools.git /opt/cvm-tools

WORKDIR /opt/cvm-tools/cvm-attestation
RUN pip install --no-cache-dir -r requirements.txt

WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY app.py /app/app.py
COPY config_snp.json /app/config_snp.json
COPY templates/ /app/templates/

EXPOSE 80
CMD ["python", "/app/app.py"]
