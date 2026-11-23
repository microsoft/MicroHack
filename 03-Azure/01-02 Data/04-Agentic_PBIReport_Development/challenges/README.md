# Participant guide - Agentic Power BI Report Development

Build a management report with GitHub Copilot and prove its numbers. Choose a
wholly synthetic bank or insurer; both use CHF and cover 2024-2025. Your journey
is CSVs, a Lakehouse, validated Delta tables, an explicit semantic model, then a
populated two-page report. Manual Fabric experimentation is welcome.

Start with [participant readiness](../resources/host-readiness.md), then read the
[banking](../resources/banking-business-brief.md) or
[insurance](../resources/insurance-business-brief.md) brief and
[data dictionary](../datasets/dictionary.md). Use Copilot CLI or the separately
prepared VS Code Agent host. Review plans, source and diffs before approving
changes; never use real customer data or another participant's resources.

## Published lessons

1. [From CSV to a trusted Lakehouse](challenge-01.md)
2. [Engineer the business model](challenge-02.md)
3. [Brief the management team](challenge-03.md)
4. [Finish and cleanup](finish.md)

The platform's Student download contains data and supporting resources, not these
lesson pages or coach solutions. Keep the published lessons open beside your
exercise folder. On the prepared VM, that folder is `C:\MicroHack\student`;
both datasets are under `datasets` and the briefs are under `briefs`.
In the Student download, supporting briefs are under `resources`.

**Testing:** source checks are not live event acceptance. Report unsupported
capabilities or missing access to the coach; do not bypass policy or claim
deployment, query or rendering success without evidence.
