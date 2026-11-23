# LocalBox TEST14: section timings and recovered warnings

## Verified result and scope

The `sov-cloud-full-automation-test-14` LocalBox guest run on `traininglab-44`
finished successfully at **07:26:19 UTC on 8 November 2026**. An independent
read-only probe verified the exact run, package, event group and Azure scope,
matching Full health JSON and both NUnit XML reports, and report timestamps.
**12/12 upstream and 14/14 Sovereign tests passed**, with none failed, skipped
or unrun. Update assessment succeeded at 07:18:55.558 UTC.

- **Guest preparation and verification:** 03:40:08.758 to 07:26:19.066,
  **3h 46m 10s**.
- **Initial LocalBox ARM start to guest completion:** 20:50:40.749 on
  7 November to 07:26:19.066 on 8 November, **10h 35m 38s**.
- This second interval excludes Console setup before ARM and all subsequent
  shared/participant stages. It is **not the total Console job duration**.
- The participant resource group was empty at the earlier post-guest checks.
  Subsequently supplied Console output confirms completion of the global,
  shared and participant deployment stages; those earlier checks were not
  evidence of a downstream failure.
- Defender cloud reporting and real participant sign-in remain manual checks.

The guest completed without operator resubmission or infrastructure recreation.
Automatic validation retry, Blob propagation handling, AKS submission
reconciliation and MetalLB recovery were all exercised. The historical startup
report still records the BGInfo failure described below; it was not rewritten
to disguise that failure.

## Console completion

The operator subsequently supplied Console output for the same TEST14 event
and subscription. It reports successful completion of all three deployment
stages, including the single participant job:

| Console stage | Reported duration | Outcome |
|---|---:|---|
| Global event deployment | 10h43m | Completed, 1/1 |
| Shared deployment | 6m01s | Completed, 1/1 |
| Participant deployment | 11m29s | Completed, 1/1 |
| **Sum of reported stage durations** | **Approximately 11h00m30s** | **All deployment stages completed** |

This closes the earlier uncertainty about the Console handoff and downstream
deployment stages. The global duration includes LocalBox work; do not add the
guest or ARM-to-guest duration to this total. The global duration is only
reported to minute precision, and the sum excludes initial Console setup and
gaps between stages. Without job start/end timestamps, it is not an exact
end-to-end wall-clock duration. Completion messages establish Console-reported
deployment success, not independent validation of participant access or
Defender cloud reporting.

## Comparison with previous observations

These are individual observations, not an SLA or a controlled benchmark.
TEST06 was a serial cold guest run; TEST13 was an explicitly repaired/resumed
instance with substantial earlier operator pauses. Only equivalent guest work
is compared with TEST13.

| Section | TEST06, 4 November | TEST13 resumed, 7 November | TEST14, 7-8 November |
|---|---:|---:|---:|
| Initial LocalBox ARM deployment | 19m40s | Not compared | 11m55s |
| Post-ARM bootstrap to first validation start | 1h14m30s | Not compared | 1h18m48s |
| Validation window, including retry/handoff where applicable | 46m24s | Not compared | **2h48m18s** |
| Azure Local cluster deployment | 2h34m25s | Not compared | 2h28m10s |
| **Guest preparation through verified tests/finalization** | **5h24m09s** | **4h15m05s** | **3h46m10s** |
| AKS ARM deployment, overlapping image import in TEST13/14 | 1h10m59s | 47m09s | 1h01m05s |
| Image import window | 2h58m44s | 2h55m23s | 2h45m26s |
| Reference VM ARM deployment | 8m30s | Not separately retained | 8m51s |
| Reference VM ARM completion to MDE installation success | 47m44s | Not separately retained | 31m50s |
| Initial ARM start to guest completion, excluding Console setup/downstream | 10h22m23s | Not comparable | **10h35m38s** |

TEST14's guest phase was **28m55s faster than TEST13** and **1h37m59s faster
than TEST06**. However, the comparable ARM-to-guest interval was **13m15s
longer than TEST06**: the failed validation download offset the guest-stage
improvements.

Image durations for TEST13/14 use explicit guest timestamps immediately before
image preparation and after its readiness wait. TEST06 uses the image ARM
write interval. These are similar end-to-end import windows, but not identical
instrumentation or pure network-transfer measurements. Bootstrap intervals
are bounded between milestones, not exclusive timers for each internal step.

## Additive TEST14 timeline

All times are UTC; midnight separates 7 and 8 November. Durations below are
differences between independently rounded second-resolution boundaries, so
they add to exactly **10:35:38**. A duration rounded directly from fractional
timestamps may differ by one second.

**M** means an operation/report interval; **B** means a bounded interval between
milestones, potentially containing several activities. Overlapping AKS/image
work appears once in this additive table.

| Start | End | Duration | Section | Evidence |
|---|---|---|---|---|
| 20:50:41 | 21:02:36 | 00:11:55 | Initial LocalBox ARM deployment | M |
| 21:02:36 | 22:21:24 | 01:18:48 | Bootstrap and nested preparation before validation | B |
| 22:21:24 | 00:31:16 | 02:09:52 | First validation deployment; failed content download | M |
| 00:31:16 | 00:34:03 | 00:02:47 | Failure detection, retry launch and bounded delay | B |
| 00:34:03 | 01:09:42 | 00:35:39 | Successful validation retry | M |
| 01:09:42 | 01:09:56 | 00:00:14 | Validation-to-deployment transition | B |
| 01:09:56 | 03:38:06 | 02:28:10 | Azure Local cluster deployment | M |
| 03:38:06 | 03:40:09 | 00:02:03 | Connectivity/readiness detection and guest launch | B |
| 03:40:09 | 03:47:39 | 00:07:30 | Guest prerequisites, storage/networks and AKS preflight | B |
| 03:47:39 | 06:33:33 | 02:45:54 | AKS provisioning and image import, overlapping | B |
| 06:33:33 | 06:36:05 | 00:02:32 | AKS join, Arc/MetalLB checks and reference VM handoff | B |
| 06:36:05 | 06:44:55 | 00:08:50 | Reference VM ARM deployment | M |
| 06:44:55 | 07:09:23 | 00:24:28 | Reference VM/Arc readiness and MDE scheduling | B |
| 07:09:23 | 07:16:45 | 00:07:22 | MDE extension submission to success | M |
| 07:16:45 | 07:18:56 | 00:02:11 | Onboarding detection and successful update assessment | B |
| 07:18:56 | 07:20:29 | 00:01:33 | Assessment return, tooling and test startup | B |
| 07:20:29 | 07:20:47 | 00:00:18 | Upstream tests through XML write | M |
| 07:20:47 | 07:23:32 | 00:02:45 | Runtime-test setup and initial MetalLB reconciliation wait | B |
| 07:23:32 | 07:23:52 | 00:00:20 | Bounded MetalLB recovery, attempt 1/1 | M |
| 07:23:52 | 07:23:54 | 00:00:02 | Full test startup after recovery | B |
| 07:23:54 | 07:25:59 | 00:02:05 | Sovereign Full tests through XML write | M |
| 07:25:59 | 07:26:19 | 00:00:20 | Final status/report upload and command completion | B |
| | **Total** | **10:35:38** | Initial ARM start to guest completion | |

The first validation's deployment-settings operation ran from 22:29:35.165
to 00:31:03.732, within the longer parent deployment interval. Its reported
7200-second content-download timeout triggered exactly one automatic retry.
The successful retry's original-correlation check and remaining overall budget
were preserved. The retry command itself ran from 00:31:47.617 to 01:09:58.753,
including its 120-second delay, validation and deployment submission.

## Actual AKS/image overlap

- AKS ARM deployment: **03:47:39.478 to 04:48:44.628**.
- Guest accepted-submission log: **03:48:05.015**.
- Image preparation began: **03:48:06.910**.
- Image resource created: **03:48:18.998**.
- Image readiness observed: **06:33:33.348**; final provider state Succeeded,
  progress 100%, reported download size 16,654 MB.

From image creation until AKS completion, both operations were active for
**1h00m26s**. Thus the image did not wait for AKS to finish. Do not add the
61-minute AKS duration to the image duration when calculating the critical
path. This is measured overlap, not proof that all of the guest improvement
was caused by parallelization: image timing and onboarding also differed.

## Final warning/error assessment

| Finding | Final outcome | Follow-up |
|---|---|---|
| Validation content-download timeout | First attempt failed; automatic retry 1/1 succeeded | Largest remaining reliability/performance target. Investigate upstream download-stage telemetry; do not bypass validation or shorten its timeout without evidence |
| BGInfo command not found despite installation | Historical startup report remains Failed; later independent guest Full tests passed | Fixed for future deployments in `8f284c0b`: explicit binary discovery, early prerequisite check, persistent upstream test-runner patch and checked exit code. The current immutable payload was not changed |
| Startup watcher failed after task unregistration | Generic historical monitor failure did not prevent later ARM/guest progress | Fixed in `8f284c0b`: inspect the guarded process mutex, reread terminal reports on exit races, preserve bounded/redacted errors |
| Blob permission-propagation errors | Two initial retries, then successful reads/writes; final diagnostic upload succeeded | Existing bounded gate worked; no new role grants needed |
| `aksarc` post-submission `ResourceNotFound` | New matching ARM receipt accepted; original AKS deployment succeeded and runtime tests passed | Existing reconciliation worked; no duplicate create |
| Missing initial MetalLB runtime pool/L2 advertisement | One unchanged Azure-managed pool reapply succeeded in about 20 seconds; Full checks then passed | Keep bounded recovery and final Kubernetes checks. This remains an upstream/controller reconciliation concern, not justification for deleting/recreating the cluster |
| Reference VM inspection-only warning | VM is running, Arc connected, MDE installed and update assessment successful | Inspection-only is guidance, not read-only RBAC. Defender cloud reporting and actual participant sign-in still need verification |
| Az version advisory / `Get-AzStackHciCluster` breaking-change advisory | Current upstream tests passed; the latter warns about changes to `ICluster` output properties/types | Track upstream module compatibility before changing versions. Do not suppress these warnings or upgrade modules in the active run merely to remove them |

The BGInfo failure occurred before registration of the upstream future-logon
test task; it was not merely cosmetic logging. The next fresh deployment must
verify that startup and recurring-logon behavior complete with the published
fix. The current run's successful independent Full suites do not retroactively
repair that historical startup failure.

## Evidence and limits

Deployment start times are derived from ARM terminal timestamp minus duration.
The original failed validation was recovered from Activity Log using its original
correlation, because the retry replaced the deployment record. Extension activity
events, original guest transcript timestamps, report file times, NUnit metadata
and the correlated final status supply the remaining boundaries.

Managed Run Command output can be buffered: the monitor first displayed some
image-start lines hours after their embedded timestamps. This report uses the
embedded timestamps, not the later polling observation time.

Private reports and operational snapshots remain outside the repository.
Neither the earlier Console screenshot nor the subsequently supplied completion
output establishes a consistent UTC start/end pair. The stage-duration sum above
is therefore reported separately from the still-unmeasured total Console job
wall-clock duration.
See the [TEST06 analysis](test-06-timing-analysis.md) for the earlier baseline
and [hosted provisioning guidance](readme.md) for readiness and retry contracts.
