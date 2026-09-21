# Runtime attestation web UI for AKS CC nodes

A Flask web app that wraps [Azure/cvm-attestation-tools](https://github.com/Azure/cvm-attestation-tools)
to perform a **runtime SEV-SNP attestation** against Microsoft Azure Attestation (MAA) and
present the resulting signed token claims with human-readable explanations.

Deployed automatically by [`../Deploy-VotingAppCC.ps1`](../Deploy-VotingAppCC.ps1) alongside
the voting app, on the same AMD SEV-SNP node pool.

## What it does

When the user clicks **Attest**, the pod:

1. Reads the AMD SEV-SNP attestation report from the node's vTPM (HCL report) via `/dev/tpmrm0`.
2. POSTs the hardware evidence + a freshly generated nonce to the regional MAA endpoint
   (auto-discovered from IMDS).
3. Receives a signed JWT and decodes it.
4. Renders every claim in a table with a plain-English explanation of what it means - SEV-SNP
   measurement registers, TCB SVNs, VMPL, REPORT_DATA binding, MAA policy hash, etc.

Because the JWT is signed by MAA after MAA itself verified the hardware evidence, a green
`x-ms-compliance-status: azure-compliant-cvm` is your end-to-end proof that the workload is
running inside a genuine, policy-compliant AMD SEV-SNP TEE in Azure right now.

## Requirements at runtime

| Requirement | Why |
|-------------|-----|
| Pod scheduled on an SEV-SNP node | Otherwise the vTPM doesn't expose an SNP HCL report |
| `/dev/tpmrm0` mounted (privileged) | Upstream tool reads the HCL report via tpm2-tools |
| Egress to `*.attest.azure.net` + `169.254.169.254` (IMDS) | MAA endpoint discovery and call |

The Deploy script handles all of the above.

## Building a real image (optional)

The default deployment uses runtime bootstrap (no registry needed). To bake an image instead:

```bash
docker build -t <your-registry>/cc-attestation-web:1.0 .
docker push <your-registry>/cc-attestation-web:1.0
```

Then edit the Deployment in `Deploy-VotingAppCC.ps1` to use that image and drop the bootstrap
`command`/`args`.

## Files

| File | Purpose |
|------|---------|
| `app.py` | Flask app + JWT decode + claim-explanation dictionary |
| `templates/index.html` | Single-page UI with the **Attest** button and result rendering |
| `config_snp.json` | MAA SEV-SNP config consumed by the upstream client (nonce injected per request) |
| `requirements.txt` | Python deps for the Flask app + upstream client |
| `Dockerfile` | Optional pre-built image |
