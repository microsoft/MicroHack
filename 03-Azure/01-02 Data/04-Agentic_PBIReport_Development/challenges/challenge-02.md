# Challenge 2 - Engineer the business model

[Home](README.md) | [Previous](challenge-01.md) | [Next](challenge-03.md)

## Goal

Use Copilot to author, deploy and query an explicit semantic model with meaningful,
defensible DAX. Do not depend on a default semantic model.

## Actions

1. Ask Copilot to explain both fact grains and draw the star. Review the dictionary:
   one-to-many, single-direction dimension-to-fact relationships; no fact-to-fact
   join. Explain why Channel cannot filter loan snapshots and ClaimType cannot
   filter premiums.
2. With the coach, pass the Direct Lake on OneLake capability gate. Resolve actual
   Delta URLs from the completed generation. Create an explicit model from those
   tables, export its supported TMDL or TMSL definition and inspect source/partitions.
   Stop if OneLake Direct Lake is unavailable; a SQL endpoint connector or Import
   partition is a different design, not an automatic fallback.
3. Have Copilot author all relationships, descriptions, display formats and date
   metadata. Mark the complete date table, sort month names, hide keys/raw cents,
   and discourage implicit aggregation. Preserve a reviewable source definition.
4. Implement at least six business measures from the brief, plus status/as-of
   measures. Banking snapshots, NPL numerator/denominator and weighted rate must
   use the same selected month-end. Insurance loss ratios require aligned complete
   months and paid minus recoveries plus signed reserve movement.
5. Review the diff, deploy the complete model definition, verify connection/SSO
   and source access, and refresh/frame. Execute DAX reconciliations, not just
   deployment. Compare exact counts and CHF rounded to two decimals with the
   independently computed manifest controls.
6. Test 2024, 2025, leap February, a single month, multiple months, empty supported
   slices, unsupported dimensions and missing prior year. Capture blanks and
   scope reasons rather than substituting zero for invalid contexts.

Suggested prompt:

> Explain the model before writing it. Separate additive flows from as-of stocks.
> Generate reviewable TMDL or the supported model.bim equivalent using the
> service-exported Direct Lake source seed.
> Propose DAX and independent reconciliation queries. Show how unsupported filters,
> partial insurance months and missing prior year behave. Do not deploy until review.

## Hints

First: `SUM(balance)` over two years is not a portfolio balance.
Next: derive the snapshot from the selected **date dimension**, independent of
filtered fact availability. Stronger: test February 2025 against February 29, 2024;
do not use a fixed 365-day offset. For ratios, align numerator and denominator
and return blank on zero/invalid denominator.

## Success criteria

An explicit deployed model reads the intended completed Delta generation, retains
source, dates, formats, descriptions and valid relationships, and executes the
reconciliation suite. Source upload alone does not satisfy AC-05. Save private
query results and a human-reviewed diff checkpoint.

## Learning resources

- [Star schema guidance](https://learn.microsoft.com/en-us/power-bi/guidance/star-schema)
- [Direct Lake overview](https://learn.microsoft.com/en-us/fabric/fundamentals/direct-lake-overview)
- [TMDL overview](https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-overview)
