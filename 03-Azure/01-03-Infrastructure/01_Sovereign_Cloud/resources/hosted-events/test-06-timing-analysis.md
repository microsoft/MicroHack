# LocalBox test-06: deployment timing and optimization assessment

## Result and scope

This report reconstructs the **4 November 2026** run from the live LocalBox,
Azure Resource Manager (ARM), Activity Log, original guest reports, and Console
completion screenshot. It is a single cold-deployment observation, not an SLA.

| Item | Observed value |
|---|---|
| Console event | `sov-cloud-full-automation-test-06` |
| Environment | `traininglab-23`, resource group `rg-localbox-shared` |
| Guest run ID | `c654cb11-7935-4a68-901a-5864c3ef4e7e` |
| Console start / finish | 05:21:32 / 15:52:16 |
| **Console elapsed time** | **10h 30m 44s (37,844 seconds)** |
| Managed guest start / finish, UTC | 10:27:47.0086285 / 15:51:56.2326884 |
| **Managed guest elapsed time** | **5h 24m 9.224s** |
| Guest outcome | Succeeded, exit code 0; upstream 12/12 and Sovereign 14/14 passed |
| Console outcome | Failed while retrieving guest results; subsequent shared and participant stages were skipped |

**This is not a successful end-to-end event-deployment benchmark.** The guest
finished successfully, but the Console Azure CLI wrapper attempted to parse
Blob-download progress output as JSON. The resulting failure occurred after the
expensive provisioning work. The host-only fix was subsequently published in
commit `002c28716a4437e417f881ee7851a1c64c67b328` and verified against this run's
actual reports. That verification does not retroactively make this Console job
successful, and a retry is a separate measurement.

ARM and guest timestamps are UTC. The Console screenshot does not label its
timezone; its displayed times align with the UTC milestones and are treated as
UTC in the combined timeline below. The screenshot's elapsed duration does not
depend on that timezone assumption.

## Additive timeline

Boundaries are rounded to the nearest second; each duration is the difference
between those rounded boundaries. Consequently, these rows sum to exactly
**10:30:44**, while a duration calculated from the original fractional timestamps
can differ by a second.

- **M**: measured operation/report interval. ARM deployment starts are derived
  from the deployment's terminal `properties.timestamp` minus `properties.duration`.
- **B**: bounded interval between observed milestones. The elapsed time is known,
  but its individual activities are not separately timed; it is not necessarily
  idle time or time spent exclusively on the named activity.

| Start | End | Duration | Work / interval | Evidence |
|---|---|---|---|---|
| 05:21:32 | 05:29:33 | 00:08:01 | Console setup and preflight before initial ARM deployment | B |
| 05:29:33 | 05:49:13 | 00:19:40 | Initial LocalBox ARM deployment | M |
| 05:49:13 | 07:03:43 | 01:14:30 | Post-ARM bootstrap and nested preparation before validation | B |
| 07:03:43 | 07:50:07 | 00:46:24 | Azure Local validation deployment | M |
| 07:50:07 | 07:51:49 | 00:01:42 | Validation-to-deployment transition | B |
| 07:51:49 | 10:26:14 | 02:34:25 | Azure Local cluster deployment | M |
| 10:26:14 | 10:27:47 | 00:01:33 | Readiness detection and managed guest launch | B |
| 10:27:47 | 10:34:51 | 00:07:04 | Guest startup, storage/logical networks and AKS pre-deployment work | B |
| 10:34:51 | 11:45:50 | 01:10:59 | AKS deployment | M |
| 11:45:50 | 11:49:18 | 00:03:28 | AKS post-deployment checks, proxy access/MetalLB and image submission | B |
| 11:49:18 | 14:48:02 | 02:58:44 | Windows Server marketplace image import | M |
| 14:48:02 | 14:48:33 | 00:00:31 | Image-to-reference-VM deployment transition | B |
| 14:48:33 | 14:57:03 | 00:08:30 | Reference VM ARM deployment | M |
| 14:57:03 | 15:41:35 | 00:44:32 | Reference VM completion to MDE extension submission; includes Arc/readiness work | B |
| 15:41:35 | 15:44:47 | 00:03:12 | MDE extension write to successful completion | M |
| 15:44:47 | 15:45:04 | 00:00:17 | Onboarding detection and assessment submission | B |
| 15:45:04 | 15:47:12 | 00:02:08 | Update assessment request to successful result timestamp | M |
| 15:47:12 | 15:48:40 | 00:01:28 | Assessment return, kubectl preparation and test startup | B |
| 15:48:40 | 15:49:02 | 00:00:22 | Upstream tests through XML report write | M |
| 15:49:02 | 15:49:40 | 00:00:38 | Sovereign health startup, including routing/client setup | B |
| 15:49:40 | 15:51:40 | 00:02:00 | Sovereign tests through final health report write | M |
| 15:51:40 | 15:51:56 | 00:00:16 | Finalization and managed command completion | B |
| 15:51:56 | 15:52:16 | 00:00:20 | Console completion detection and failed result retrieval | B |
| | **Total** | **10:30:44** | No downstream shared/participant deployment time included | |

Before the managed guest started, **5h 6m 15s** had elapsed. The managed guest
then ran for **5h 24m 9s**, followed by approximately **20 seconds** before the
Console job ended.

## What the detailed evidence establishes

### Initial ARM and nested Azure Local

The initial deployment, `localbox-20261104-052907`, took
**19m 40.349s**. Its network module took **9m 32.406s**, host VM module
**9m 52.148s**, staging storage module **31.626s**, and management/policy module
**24.649s**. These modules are inside the parent deployment and can overlap:
**do not add them to the timeline again**.

Initial ARM success was not nested-cluster readiness. Bootstrap log evidence
helps characterize the following interval:

| Evidence | UTC timestamps | Interpretation |
|---|---|---|
| Bootstrap transcript/file | 05:41:21 to 05:48:49.646 | Runs inside initial ARM provisioning |
| WinGet provisioning log creation/last write | 05:49:50.508 to 05:58:02.147 | About 8m12s of log lifetime; not a precise exclusive installation timer |
| `New-LocalBoxCluster.log` transcript start | 05:58:28 | Nested cluster workflow had started |
| `Generate-ARM-Template.log` transcript start | 06:50:06 | Template-generation workflow had started |
| Validation deployment | Derived start 07:03:43.061; completion 07:50:06.713 | **46m23.652s** |
| Cluster deployment | Derived start 07:51:48.732; completion 10:26:14.224 | **2h34m25.491s** |

The cluster deployment's `clusters/deploymentSettings` operation accounts for
**2h34m12.476s** of its elapsed time. Role assignments, secrets and ancillary
resources took seconds and overlap that work. This points to the upstream
cluster deployment workflow, not those small ARM resources, as the major cost.
The collected logs do not establish exclusive durations for every internal
cluster action; further subdivision requires the upstream deployment's
step-level telemetry.

### AKS and image preparation

AKS deployment `pciDeployment-localbox-aks` took **1h10m59.340s**.
Its derived start, 10:34:51.026, agrees within about one second with the Activity
Log request start at 10:34:50.010. The terminal deployment timestamp is
11:45:50.366. An early successful ARM write/acceptance event is not evidence that
the whole AKS deployment has completed.

The Windows Server image `2025-datacenter-azure-edition-smalldisk-01` had:

- Initial write request: **11:49:18.2769539**.
- Resource creation: **11:49:19.5426047**.
- Successful write completion: **14:48:01.8995519**.
- Import interval: **2h58m43.623s**, approximately **28.3%** of the Console run.
- Reported download size: **16,654 MB**; final progress 100%, state Succeeded.

Dividing the reported size by the full import interval gives approximately
**1.55 MB/s end-to-end**. This is **not a measured network transfer rate**:
the interval can include download, storage processing, registration and
provider/controller waits. It does not by itself prove a bandwidth bottleneck.
Repeated image-write events during progress updates are not separate imports.

At the time of this run, the [preparation script](../prepare-localbox.ps1) ran AKS creation,
proxy access/MetalLB, image import, then reference VM creation **serially**.
That ordering is the clearest code-level optimization opportunity.

### Defender and update assessment

The reference VM ARM deployment completed at **14:57:02.908717**. The first
MDE extension write started at **15:41:34.8245541** and succeeded at
**15:44:46.5968808**:

- VM ARM completion to MDE submission: **44m31.916s**.
- MDE submission to extension success: **3m11.772s**.
- Combined interval: **47m43.688s**.

The first interval includes reference VM/Arc readiness as well as asynchronous
Defender onboarding scheduling. It is not a precisely measured pure Defender
queue time. Nevertheless, installation after submission was much shorter than
the preceding wait. Reinstalling the extension or tightening polling would not
address that larger interval.

Update assessment started at **15:45:04.491061**. The successful assessment
result timestamp was **15:47:11.7283261**, an interval of **2m7.237s**.
The assessment's `WindowsOsUpdateExtension` provisioning occurred within this
interval and must not be added separately. The result timestamp is not an exact
measurement of when the CLI returned to the guest script.

### Tests and finalization

The NUnit reports record **20.7468 seconds** for the 12 upstream tests and
**118.5527 seconds** for the 14 Sovereign tests. Together that is
**2m19.300s**, only **0.37%** of the full Console duration. Test startup, XML/JSON
export, routing and finalization are additional, separately bounded intervals
in the timeline.

The guest's final status timestamp was **15:51:40.0092555**; managed execution
ended at **15:51:56.2326884**. The final Console failure was therefore a
result-handling problem, not a provisioning or health-test timeout.

## Optimization priorities

These are recommendations, **not implemented runtime changes or promised
savings**. Preserve the final readiness gate and compare equivalent cold runs
before declaring an improvement.

**2026-11-05 implementation update:** Fresh AKS creation now uses the CLI's
`--no-wait` option before importing the VM image, and joins AKS/Arc/MetalLB
readiness afterwards. This implements the overlap in candidate 1 without
concurrent local CLI sessions. Existing-AKS retries remain serial, and manual
preparation offers `-SequentialProvisioning` as a fallback. The estimates below
remain historical estimates, not measured savings from this implementation.

**2026-11-08 measured update:** [TEST14](test-14-timing-analysis.md) verified
1h00m26s of actual AKS/image overlap and a 3h46m10s successful guest run.
Its validation retry nevertheless made the comparable initial-ARM-to-guest
interval longer than TEST06; the new report separates those effects.

| Priority | Candidate | Potential benefit from this run | Constraints / verification |
|---|---|---|---|
| 1 | Start image import alongside AKS after shared storage/network prerequisites are ready | With unchanged operation durations, overlapping the 71-minute AKS deployment with the 179-minute image import could remove roughly **71 minutes** of serial waiting | Both use the same nested environment. Storage, CPU or network contention could reduce or eliminate the saving. Use controlled concurrency, isolated CLI state, explicit error handling, and wait for both branches before full readiness |
| 2 | Profile and improve the image-import path | Targets the longest individually measured preparation stage: **2h59m** | Separate actual download from storage processing/controller waits; collect supported disk/network/CPU telemetry. No evidence yet justifies a larger VM, arbitrary storage changes, or bypassing the supported import workflow |
| 3 | Pre-provision/reuse a validated shared LocalBox and existing image for an event | Moves substantial cold provisioning off the event's critical path; the existing preparation logic supports reuse | This is scheduling/reuse, not a faster cold deployment. Track ongoing cost, clean up prior participant access, verify configuration/image compatibility, and rerun current health/security checks. Measure warm runs separately |
| 4 | Overlap update assessment and independent infrastructure checks with MDE onboarding | Can hide a few minutes of work inside the roughly 48-minute post-reference interval | Start only after the reference VM is Arc Connected. Keep the final MDE-success requirement; the complete Sovereign suite currently depends on it. Do not equate extension success with verified Defender cloud reporting |
| 5 | Investigate upstream bootstrap, validation and cluster deployment step timings | Targets the 1h14m pre-validation interval, 46-minute validation and 2h34m cluster deployment | Collect per-step evidence first. Do not bypass supported validation or shorten retries just to improve the stopwatch |
| 6 | Add durable timestamped phase/subphase history and surface it in Console | Makes future bottlenecks and apparent stalls observable | Instrumentation improves evidence and UX, not provisioning speed. Record run ID, UTC start/end, elapsed time, outcome and reuse/create decisions; never credentials. Streaming progress remains separate from the already implemented final summary |

An alternative experiment is to import the image and start the reference VM
before AKS, allowing Defender onboarding to overlap AKS work. This only helps if
the guest does not block on MDE before starting AKS, and it still needs benchmark
validation. It is an alternative/extension to the first recommendation, **not
an additional saving to add mechanically to its 71-minute estimate**.

Splitting "Infrastructure Ready" from "Defender Ready" could permit some later
work to start earlier, but changes the hosted lifecycle and its readiness
contract. It must explicitly report pending security checks and gate
security-dependent exercises. It is not equivalent to making the existing Full
readiness check faster; simply deleting the MDE wait would still fail the
current reference-VM health test.

Reducing polling intervals and optimizing Pester are low priority: the measured
test execution is under 0.4% of total time. The already-fixed Blob-output parsing
bug is important for reliability, but does not reduce the hours spent creating
resources.

## Evidence and measurement limitations

- ARM deployment metadata supplied terminal timestamps and durations; deployment
  operation metadata identified the long-running cluster deployment-settings
  operation. Child operation durations are not additional critical-path time.
- Read-only guest diagnostics read the original run's status, transcript, file
  metadata and NUnit reports. Live diagnostic executions themselves are not part
  of the original deployment timeline.
- Activity Log supplied initial image creation, terminal image completion, MDE
  extension start/success and assessment request times. The initial resource-group
  query hit its 1,000-event cap and covered only 12:03:51 to 15:59:14. Narrow
  resource/time-window queries recovered the earlier image and AKS starts; the
  capped export is **not** a complete history.
- The transcript records phase order but not a timestamp for every command;
  final status overwrites earlier phases. File creation/last-write times are
  supporting evidence, not exclusive phase timers. Bounded intervals must not be
  relabeled as precisely timed individual operations.
- Raw transcripts and credentials are not published with this report. Use the
  original run ID above to correlate retained private reports; do not substitute
  artifacts from a later retry.
- No shared/participant stage ran after the global failure. Their duration,
  participant-scale effects and complete event time remain unmeasured.

For the next baseline, retain the final Console result and all guest reports,
record whether resources were created or reused, and capture phase history.
Benchmark one optimization at a time against the same region, host sizing,
image/version and readiness requirements. A warm retry of this environment is
useful functional verification, but is not a replacement cold-run timing sample.
