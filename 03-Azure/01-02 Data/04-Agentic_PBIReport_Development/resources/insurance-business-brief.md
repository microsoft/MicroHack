# Synthetic insurance management brief

Audience: underwriting, distribution and claims management. Investigate premium
and loss performance, not solvency, reserving adequacy or actuarial compliance.
All values are invented CHF for 2024-2025.

Read [the dictionary](../datasets/dictionary.md). Six dimensions describe date,
policyholder, product, geography, distribution channel and claim type. Premium
rows are one policy per month-end; claims rows are financial **movements**.
All 800 policies are active for both years with annual January renewal.
PolicyId and ClaimId are degenerate identifiers, not a fact-to-fact relationship.

| Business measure | Definition |
| --- | --- |
| Written Premium | Sum WrittenPremiumCents / 100 over complete selected months |
| Earned Premium | Sum EarnedPremiumCents / 100 over the same months |
| Paid Claims | Sum PaidCents / 100 in that period |
| Recoveries | Sum positive RecoveryCents / 100 |
| Change in Claim Reserves | Sum signed ReserveMovementCents / 100; never sum reserve balances |
| Incurred Claims | Paid Claims - Recoveries + Change in Claim Reserves |
| Loss Ratio | Incurred Claims / Earned Premium under aligned periods/conformed dimensions |
| Claims with Activity | Distinct ClaimId with a movement in the period; not newly reported claims |
| Active Policies at Month-End | Distinct active policies at latest selected declared month-end |
| Earned Premium Prior Year / YoY % | Comparable calendar period; blank without nonzero comparator |

Period-flow measures require a nonempty union of **whole months** selected through
the date dimension. A month-end-only date filter is not a complete month.
Reject/blank partial-month loss ratios rather than compare daily claims with a
whole month's premium. Use year/month selectors in the report.

Show executive underwriting and product/channel/market detail. Keep claim-type
analysis in a claims-only panel: ClaimType does not filter premium, active policies
or loss ratio. Supply status explanations. Use blank for zero/invalid ratio
denominators; no Combined Ratio without expenses. Compare yearly changes,
seasonality and claim movements without treating synthetic patterns as advice.
