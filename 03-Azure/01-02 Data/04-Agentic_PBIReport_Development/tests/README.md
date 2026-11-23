# Local checks and live-evidence boundary

Run from the repository root with Python 3.11+ and PowerShell 7. No Azure/Fabric
sign-in is needed. Use OS temp for generated examples/evidence, not a tracked folder.

```powershell
$hack = '03-Azure\01-02 Data\04-Agentic_PBIReport_Development'
$env:PYTHONDONTWRITEBYTECODE = '1'
$env:PYTHONIOENCODING = 'utf-8'
python -B -m unittest discover -s "$hack\tests" -p 'test_*.py' -v
python -B "$hack\tests\check-structure.py"
& "$hack\tests\test_automation.ps1"
& "$hack\tests\test_platform_hooks.ps1"
az bicep build --file "$hack\labautomation\main.bicep" --outfile "$env:TEMP\agentic-pbi-main.json"
az bicep build --file "$hack\labautomation\shared.bicep" --outfile "$env:TEMP\agentic-pbi-shared.json"
git diff --check
```

The structure adapter calls the existing repository
`.github\scripts\check_file_structure.py` `ComplianceChecker` class over all new
source paths without its cwd-writing command-line wrapper. Use the pinned dependencies in
`.github\scripts\requirements-compliance.txt` in a temporary venv for `brokelink`;
set `PYTHONIOENCODING=utf-8` on Windows. Run `brokelink <file> --include="*.md"
--check-images` on each changed Markdown file. Do not repair unrelated existing
repository links. For deeply nested Windows worktrees, pass an absolute
`\\?\C:\...` filename to the checker to avoid false missing-file results at the
normal Windows path-length limit.

`test_platform_hooks.ps1` runs both actual hook scripts with Azure/platform
boundary doubles and `MHH_EVENT_CONFIG` absent. It exercises shared provisioning,
ordered region selection, retained exact image versions, two participant VMs,
stable retries, secure password parameters, complete guest payload construction,
RG metadata-region differences, preserved platform tags and explicit rejection
of bad scope/identity/context and unsuccessful deployment states. It also checks
empty region preferences, paginated/display-name SKU metadata, capacity Active
waiting, paused-capacity rejection and preservation of unrelated capacities.
Shared deployment uses the platform's Switzerland North default; the participant
hook exercises its matching empty-preference fallback, and explicit overrides
remain supported. Fabric starts unregistered in the fixture: registration must
complete before metadata/deployment. Already-registering, timeout and
permission-denied cases are also covered. ARM doubles return real .NET
`HttpResponseHeaders`, not just hashtables. No Azure call, authentication,
installation or machine configuration occurs.

`test_automation.ps1` checks runtime settings/pins, schemas and signatures,
ownership/implicit disks, ARM polling/failure paths and real temporary ZIP
extraction. Polling tests exercise real `HttpResponseHeaders` for empty headers,
`Azure-AsyncOperation`, `Location` and `Retry-After`, including transient failures
and ambiguous-header rejection, while retaining dictionary compatibility.
Its selective-downloader double stages the actual 25 allowlisted
source files from the pinned Git blobs in OS temp and verifies CSV bytes/checksums
and dictionary links. It checks canonical guest JSON and repeat skill-tree copying.
It does not install Windows tools, run the guest bootstrap, perform interactive
first-login initialization, test MCP connectivity or certify a live tenant.

`test_packaging.py` applies this lab's documented audience removals and separate
ZIP exclusions to the current source, checks local Markdown file targets with
case-sensitive paths on both published sides, and writes/reads representative
Student/Coach ZIPs in unique OS temp directories. It verifies all 16 CSVs,
manifest/dictionary/brief bytes, required coach source/report parts, absence of
coach content in Student output, and absence of author tests/automation in both.
It also checks retained downloadable Markdown links; lesson pages intentionally
stay on the published sides, not in the ZIPs. Its fixtures catch links to removed
automation/solutions and wrong-case targets. Scratch ZIPs are removed automatically.
These tests model the template contract, not the actual platform importer,
variants, injected banners, link fragments, external websites, private host
VM bootstrap execution. Inspect actual import/navigation/downloads
in the authorized pilot before claiming platform acceptance.

Generate both coach PBIR examples into fresh temporary output folders with
`walkthrough\challenge-03\build-report.py`; run
`powerbi-report-author validate <scenario.Report>` after each source batch.
The locally exercised authoring CLI is 0.1.1; Desktop bridge CLI is 0.1.2.
This is **not** an event-tested toolchain. Schema validation can retrieve public
schemas; cache/pin their hashes and the tested tools for a reproducible event image.

Dataset tests independently recompute controls and test corrupted input; solution
tests check enrichment preserves source bindings, rejects wrong sources and
generates populated, non-overlapping, model-bound reports. These do not execute
DAX, parse a model with TOM, execute Spark, or render Power BI. A fixture seed is
not a service-exported seed.

Live AC-03 through AC-12 still require explicit authorization, disposable pilot
identities and an independent reviewer. See [release gates](../resources/release-gates.md).
