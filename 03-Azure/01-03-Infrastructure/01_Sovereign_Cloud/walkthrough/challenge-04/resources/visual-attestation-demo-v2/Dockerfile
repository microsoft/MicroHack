# Visual Attestation Demo v2 image for Azure Container Instances.
#
# Single-container demo - no SKR sidecar. The Flask app:
#   1. runs the upstream `get-snp-report` tool (from
#      microsoft/confidential-sidecar-containers, compiled in stage 1) against
#      /dev/sev-guest to obtain a fresh AMD SEV-SNP attestation report,
#   2. loads the THIM cert chain + UVM endorsements from the
#      UVM_SECURITY_CONTEXT_DIR mount that the ACI control plane provides,
#   3. POSTs the SNP report + cert chain + runtime data to MAA's
#      /attest/SevSnpVm endpoint and renders the returned JWT claims.
#
#   - ACI Confidential SKU -> /dev/sev-guest exists, MAA returns sevsnpvm token
#   - ACI Standard   SKU   -> /dev/sev-guest is absent, fails before MAA call
#                             (educational failure mode)
#
# Built server-side by `az acr build`, no local Docker required.

FROM debian:bookworm-slim AS build
ARG SIDECAR_TAG=v2.14
RUN apt-get update \
 && apt-get install -y --no-install-recommends git make gcc libc6-dev ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch ${SIDECAR_TAG} \
        https://github.com/microsoft/confidential-sidecar-containers.git /src
WORKDIR /src/tools/get-snp-report
RUN make bin/get-snp-report

FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=80

WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY --from=build /src/tools/get-snp-report/bin/get-snp-report /usr/local/bin/get-snp-report
COPY app.py /app/app.py
COPY templates/ /app/templates/

EXPOSE 80
CMD ["python", "/app/app.py"]
