# Release gates and evidence

**Testing; no live acceptance criterion has passed.** Proposed baseline IDs are
retained for traceability. Local tests are builder evidence, not an independent
release verdict. Do not put participant identities, private IDs, tokens,
screenshots or internal documents in this public file.

| ID | Evidence required before release | Initial live state |
| --- | --- | --- |
| AC-01 | Three challenge/solution pairs, finish, contributor guide, repository structure and link checks | NOT VALIDATED |
| AC-02 | Both deterministic scenarios, six dimensions/two facts, schema/keys/FKs/dates and independent controls | NOT VALIDATED |
| AC-03 | Fresh VM has both checksum-valid scenarios; each CSV <25 MB and scenario <50 MB | NOT VALIDATED |
| AC-04 | Workspace assignment, uploaded files, successful notebook job, Delta count/control queries, identical second run | NOT VALIDATED |
| AC-05 | Deployed explicit Direct Lake model, dates/relationships/formats/descriptions, six-plus measures and executed DAX assertions | NOT VALIDATED |
| AC-06 | Two populated PBIR pages, actual model binding, reconciled totals, rendered/filter evidence and review iteration | NOT VALIDATED |
| AC-07 | Shared run then at least two participant deployments/reruns, interrupted recovery and private credential output | NOT VALIDATED |
| AC-08 | Every pilot identity has Copilot/model availability, workspace assignment and enabled author license | NOT VALIDATED |
| AC-09 | Actual supported ItemCreation policy allows four types and denies another through each route; managed SQL endpoint verified | NOT VALIDATED |
| AC-10 | A cannot read/write/list B's workspace or log on to B's VM; no shared capacity admin/secrets | NOT VALIDATED |
| AC-11 | Complete path through CLI and separately configured VS Code Agent; tested versions retained | NOT VALIDATED |
| AC-12 | Independent static/live/cleanup evidence and measured F16 concurrency; approved event-duration gate | NOT VALIDATED |

Keep a private row per assertion: ID, source ref, dataset hash, configuration/host,
expected, actual, status (PASS/FAIL/NOT VALIDATED), timestamp and evidence location.
Record exact count comparisons; currency comparisons round independent values to
two decimals, not an arbitrary percentage tolerance. Record zero/invalid denominators
and date/scope cases. Successful REST 202/upload is not execution/query/render proof.

## Unresolved event decisions

Q-01: language, duration, participant count and concurrent notebooks.
Q-02: managed platform versus customer-tenant delivery scope.
Q-03: account tenant, E5/Pro stock, approved models, processing locations and budget.
Q-04: item-policy availability/route coverage and managed SQL endpoint dependency.
Q-05: CHF is confirmed; business approval of proposed sizes/grains/KPIs and
AC thresholds remains outstanding.
Q-06: image/OS license, VM size/access, regions, budget and retention.
Access is now shared Azure Bastion with private VMs (user-confirmed). The source
defaults to licensed Windows Server, but image/SKU availability, regional quota,
cost and retention still need event-specific validation and approval.
Q-07: maintainer approval of the requested legacy-style folder.
Q-08: explicit requirements baseline sign-off.

FR-10 is a launch blocker when enforcement is unsupported unless an explicit
exception is approved; instructions or workspace roles cannot waive it.
No measured F16 cohort limit or validated prices exist. Before promotion from
Testing, attach authorized pilot results and have an independent reviewer assess
the complete Must set. Builders do not self-certify release.
