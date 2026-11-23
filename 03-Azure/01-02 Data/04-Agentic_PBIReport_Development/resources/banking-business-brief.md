# Synthetic banking management brief

Audience: portfolio and distribution management. Decide where to investigate loan
quality and channel activity, not how much regulatory capital to hold.
All values are invented, denominated in CHF, and cover 2024-2025.

Read [the dictionary](../datasets/dictionary.md). Six dimensions describe date,
customer, lending product, branch, transaction channel and illustrative risk.
Transactions are posted gross activity; monthly snapshots contain one loan per
month-end. All 600 loans remain active: balances amortize and risk migrates, not
new-customer acquisition. Customer descriptions are frozen within this dataset.

| Business measure | Definition |
| --- | --- |
| Transaction Count | Count posted transaction rows within selected dates |
| Transaction Amount | Sum nonnegative gross AmountCents / 100; not revenue or a signed ledger |
| Fee Income | Sum FeeCents / 100 |
| Outstanding Loan Balance | Sum outstanding at latest declared month-end selected in the date dimension |
| Active Loans | Distinct loans at that same month-end, not sum of monthly counts |
| Nonperforming Balance | Outstanding at that same date for IsNonperforming = true |
| Nonperforming Balance Ratio | Nonperforming balance / outstanding at the same date; not a default-count rate |
| Weighted Average Loan Rate | Sum(outstanding cents * rate units) / sum(outstanding cents) / 1,000,000 at that same date |
| Prior-Year Loan Balance | Corresponding calendar month-end one year earlier, including leap-day mapping |
| Loan Balance YoY % | (Current - prior-year balance) / prior-year balance; blank without comparator |

Show an executive overview and branch/product/risk detail with a separate
channel-activity panel. Channel does not describe snapshots; risk does not
describe transactions. Unsupported filtering/grouping must produce blanks and
an explanation, not apparently filtered totals. Ratios with zero denominators
are blank. Show the selected as-of date, including when a supported slice has
no rows; never fall back to another snapshot.

Ask: how do risk mix and amortization explain the balance change, and where do
seasonal activity/fee outliers occur? Reconcile full-period, year, month and
dimension slices using manifest reference controls before presenting.
