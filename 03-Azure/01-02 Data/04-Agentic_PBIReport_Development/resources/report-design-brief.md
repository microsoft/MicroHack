# Report design brief

**Implementation proposal for review:** two 1280 x 720 pages, accessible light
background, dark readable text, restrained blue/teal accents and explicit CHF/%.
Use built-in visuals, no custom visuals or external images. This is participant
business input, not a completed solution.

| Page | Banking | Insurance |
| --- | --- | --- |
| Executive overview | Balance, active loans, NPL balance ratio, weighted rate; monthly balance trend; separate fees/activity; as-of/status | Written/earned premium, incurred claims, loss ratio, active policies; monthly earned/incurred trend; complete-month/status |
| Detail | Branch/product portfolio matrix and risk comparison; separate channel activity | Product/channel/market comparison and matrix; separate claim-type movement analysis |

Both pages have an obvious Year/MonthKey selector, product slicer, units, meaningful
titles, keyboard order, visible filter state and a synthetic-data label:
**Synthetic data - educational use only; not a regulatory or actuarial model.**
Initially display 2025 and allow reset/2024 comparison. Banking stocks must show
the as-of date. Insurance must explain why partial months are not supported.

Map every visual to the model's exact measure/column inventory before authoring.
Cross-filter conformed dimensions normally. Channel affects bank activity only,
risk affects portfolio only, and claim type affects claims-only visuals. If mixed
scope is unavoidable, show model-provided blank/status instead of misleading
totals. Do not reimplement business formulas in visuals.

Review four things: decision usefulness, readability, reconciled values, and
interaction behavior. Capture a before/after iteration with a concrete reason,
not only a color change. Source validation is necessary, but rendering and filter
testing in the service remain mandatory.
