# Challenge 3 - Brief the management team

[Home](README.md) | [Previous](challenge-02.md) | [Finish](finish.md)

## Goal

Turn the business and design briefs into a management-presentable, data-bound
two-page PBIR report. Inspect it, request a meaningful revision, and prove that
the deployed result works.

## Actions

1. Ask Copilot to read the selected business brief and
   [report design brief](../resources/report-design-brief.md). Review its page
   layout, field/measure inventory, accessible labels and interaction plan.
2. Have Copilot author actual visuals: KPI cards, trends, comparisons, a detail
   matrix, period/product slicers, as-of/status and a visible synthetic-data label.
   Page scaffolding or an empty connected report is not completion.
3. Validate PBIR with the tested authoring CLI. Inspect bindings and source/diff.
   Bind the service copy to the **returned semantic model ID**; a local `byPath`
   reference or a Lakehouse ID is not a service model binding.
4. Deploy the complete PBIR definition, inspect the rendered report in Power BI
   and save redacted screenshots privately. Test every slicer, reset state and
   cross-highlighting; compare displayed totals with Challenge 2 queries.
5. Give Copilot specific feedback, such as separating a channel-activity section
   from loan stocks or clarifying a partial-period warning. Review the diff and
   revalidate, redeploy, render and retest. Explain why the change improves decisions.
6. Present two defensible insights and one limitation. Distinguish an invented
   dataset pattern from a real business recommendation. Checkpoint reviewed source.

Suggested prompt:

> Propose two report pages for this management audience using only model measures.
> Map each visual to exact fields. Keep unsupported filter scopes separate, show
> as-of dates and synthetic-data caveats, and make period selection obvious.
> After approval, create populated PBIR, validate it, and wait for my visual review.

## Hints

First: choose a question for each chart, not a chart for each column.
Next: a claims-only ClaimType slice must not make loss ratio look filtered.
Stronger: use model scope guards as well as explicit visual interactions; demonstrate
that a total-row stock recomputes at the latest selected month-end.

## Success criteria

Two populated pages render without errors, slicers affect the intended visuals,
totals match executed DAX, and synthetic/CHF/as-of labels are visible. Keep complete
PBIR source plus before/after screenshots and a reviewed iteration. AC-06 remains
unproven until this happens in the actual event environment.

## Learning resources

- [Power BI report projects](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report)
- [Fabric skills](https://github.com/microsoft/skills-for-fabric)
