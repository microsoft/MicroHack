# Source dictionary and generation contract

Version 1.0.0, algorithm `microhack-finance-synth-v1`, seed `20241119`.
This is a proposed synthetic lab contract, not approved financial practice.
Only Swiss francs (CHF) are supplied. Monetary columns retain the `Cents` suffix
and store integer minor units (rappen): 100 units equal CHF 1.
Every column is required/non-null; empty fields fail.
Dimensions are frozen Type 0 within a dataset version; no SCD2, late arrivals,
incremental inserts or historical customer-band inference is implied.

## Serialization and exact primitives

UTF-8 without BOM, comma-delimited CSV, one ordered header, ordinary CSV escaping,
LF endings including final row, ISO `YYYY-MM-DD` dates. Integers use unpadded
base-10, no decimal/exponent/grouping; flags use `0`/`1`. Rows sort ascending by
their listed PK (strings sort lexicographically, including synthetic IDs).
No business nulls or sentinel guessing.

`H(label,id)` is the unsigned big-endian first eight bytes of SHA-256 of UTF-8
`20241119|label|id`, where id is an unpadded integer. All modulo results are
nonnegative. `d=1` is 2024-01-01; `m=0` is January 2024. The window ends
2025-12-31, with 731 days and 24 Gregorian month ends including leap day.
All cents are signed int64 physically; except ReserveMovementCents, generated
monetary values are nonnegative. Keys/counts/RateUnits are int32; flags boolean.
All strings are nonempty with a maximum of 128 characters.

## Table inventory

PKs, alternate unique keys, exact ordered columns/types, FK edges, actual rows,
sizes and checksums are machine-readable in `manifest.json`.

| Scenario/table | Rows | Grain and primary key |
|---|---:|---|
| banking/DimDate | 731 | Calendar day; DateKey |
| banking/DimCustomer | 400 | Customer; CustomerKey |
| banking/DimProduct | 4 | Lending product; ProductKey |
| banking/DimBranch | 12 | Branch; BranchKey |
| banking/DimChannel | 4 | Activity channel; ChannelKey |
| banking/DimRiskBand | 3 | Illustrative risk band; RiskBandKey |
| banking/FactTransactions | 14,620 | Posted activity; TransactionKey |
| banking/FactLoanMonthlySnapshot | 14,400 | Loan/month-end; LoanId, DateKey |
| insurance/DimDate | 731 | Calendar day; DateKey |
| insurance/DimCustomer | 400 | Policyholder; CustomerKey |
| insurance/DimInsuranceProduct | 4 | Insurance product; ProductKey |
| insurance/DimGeography | 8 | Synthetic market; GeographyKey |
| insurance/DimDistributionChannel | 4 | Distribution channel; ChannelKey |
| insurance/DimClaimType | 4 | Claim category; ClaimTypeKey |
| insurance/FactPremiumMonthly | 19,200 | Policy/month-end; PolicyId, DateKey |
| insurance/FactClaimTransactions | 2,400 | Financial movement; MovementKey |

Within each scenario every fact's DateKey, CustomerKey, ProductKey and any
BranchKey/ChannelKey/RiskBandKey/GeographyKey/ClaimTypeKey references the matching
dimension PK by exact value (many-to-one, single-direction dimension-to-fact).
Insurance ProductKey targets DimInsuranceProduct; ChannelKey targets
DimDistributionChannel. Fact IDs are degenerate dimensions, not relationships
between facts. No loan-to-transaction relationship or bank-to-insurance join.

## Shared date columns

| Column | Meaning/expression |
|---|---|
| DateKey | Positive YYYYMMDD integer PK |
| Date | Unique Gregorian ISO date |
| DayOfMonth | Day number 1–31 |
| MonthNumber | Calendar month 1–12 |
| MonthName | Fixed English January–December; sort by MonthNumber |
| MonthKey | YYYYMM integer; chronological month sorting |
| QuarterNumber | 1 + floor((MonthNumber−1)/3) |
| Year | Calendar year 2024/2025 |
| MonthEndDate | ISO last Gregorian day in Date's month |
| IsMonthEnd | 1 exactly when Date equals MonthEndDate |

## Banking dimension columns

Keys are consecutive integers beginning at 1.

| Table | Columns beyond PK and definitions |
|---|---|
| DimCustomer | CustomerId=`SYN-BC-c` (unique); Segment=`Segment-`+(1+(c−1)%3); AgeBand cycles `18-34`,`35-49`,`50-64`,`65+`; TenureBand cycles `0-2y`,`3-5y`,`6+y`. Bands are frozen, not derived birth dates. |
| DimProduct | ProductCode=`SYN-BP-i` (unique); ProductName in key order `PersonalLoan`,`AutoLoan`,`HomeLoan`,`SmallBusinessLoan`; ProductFamily=`Lending`. |
| DimBranch | BranchCode=`SYN-BR-b` (unique); BranchName=`Synthetic Branch b`; Region=`Region-`+(1+(b−1)%4). Region is an attribute, not another dimension hop. |
| DimChannel | ChannelCode=`SYN-BCH-i` (unique); ChannelName in key order `Branch`,`Web`,`Mobile`,`Partner`. |
| DimRiskBand | RiskBandCode=`SYN-RISK-i` (unique); RiskBandName `Low`,`Elevated`,`High`; RiskSort=i. These labels are illustrative, not regulatory. |

### FactTransactions columns and expressions

For each day d, slots s=1–20; t=20×(d−1)+s.

| Column | Meaning/expression |
|---|---|
| TransactionKey | t, positive PK |
| TransactionId | `SYN-BTX-t`, unique |
| DateKey | Day d posted date, YYYYMMDD |
| CustomerKey | 1+H(`bt-customer`,t)%400 |
| ProductKey | 1+H(`bt-product`,t)%4 |
| BranchKey | 1+H(`bt-branch`,t)%12 |
| ChannelKey | 1+H(`bt-channel`,t)%4 |
| Category | `Repayment` for s≤12, `Disbursement` otherwise |
| AmountCents | (1000+H(`bt-amount`,t)%99001) × (2 in December, else 1) × (10 if s=20 and d%31=0, else 1) |
| FeeCents | floor(AmountCents/200), synthetic fee income |

Amount is nonnegative gross business activity, not net cash, principal movement,
profit or revenue. The December factor and occasional slot-20 outlier are
deterministic teaching features. Transactions are independent of loan snapshots.

### FactLoanMonthlySnapshot columns and expressions

Loans l=1–600 remain active in all 24 month ends.

| Column | Meaning/expression |
|---|---|
| LoanId | `SYN-LOAN-l`, composite PK with DateKey |
| DateKey | Gregorian month-end for m=0–23 |
| CustomerKey | 1+H(`bl-customer`,l)%400; stable |
| ProductKey | 1+H(`bl-product`,l)%4; stable |
| BranchKey | 1+H(`bl-branch`,l)%12; stable |
| RiskBandKey | 1+((l−1+floor(m/6))%3); migrates every six months |
| OutstandingCents | 100000+H(`bl-balance`,l)%4900001−1000×m; strictly positive |
| RateUnits | 20000+H(`bl-rate`,l)%80000; stable, fractional annual rate = RateUnits/1,000,000 |
| IsNonperforming | 1 exactly when RiskBandKey=3 and l%5=0 |

Balance is additive across loans at one snapshot, never across time.
NPL ratio = nonperforming balance / total balance, **not** a count default rate.
Weighted annual rate = sum(OutstandingCents×RateUnits) /
sum(OutstandingCents) /1,000,000, not an average of displayed rates. Active loans
are distinct LoanId at the same selected snapshot. Prior-year balance uses the
same calendar month's prior-year month end, including February's leap-day change.
YoY=(current−prior)/prior. No 2023 comparator exists.

## Insurance dimension columns

| Table | Columns beyond PK and definitions |
|---|---|
| DimCustomer | PolicyholderId=`SYN-PH-c` (unique); Segment and TenureBand use the banking cycles; no AgeBand. |
| DimInsuranceProduct | ProductCode=`SYN-IP-i` (unique); ProductName=`Motor`,`Home`,`Travel`,`SmallBusiness` in key order; LineOfBusiness equals ProductName. |
| DimGeography | GeographyCode=`SYN-GEO-i` (unique); MarketName=`Market-i`, i=1–8. |
| DimDistributionChannel | ChannelCode=`SYN-ICH-i` (unique); ChannelName=`Direct`,`Broker`,`Partner`,`Online` in key order. |
| DimClaimType | ClaimTypeCode=`SYN-CT-i` (unique); ClaimTypeName=`Damage`,`Theft`,`Liability`,`Other` in key order. |

### FactPremiumMonthly columns and expressions

Policies p=1–800 remain active throughout both years with annual January renewal.
Let annual A=12000+H(`ip-premium`,p)%108001+(600 in 2025, else 0).
For Y=366/365 calendar days, q=A div Y and r=A mod Y. Each of the year's first
r days earns q+1 cents; later days earn q cents.

| Column | Meaning/expression |
|---|---|
| PolicyId | `SYN-POL-p`, composite PK with DateKey |
| DateKey | Month-end, one row each policy/month |
| CustomerKey | 1+H(`ip-customer`,p)%400; stable |
| ProductKey | 1+H(`ip-product`,p)%4; stable |
| GeographyKey | 1+H(`ip-geography`,p)%8; stable |
| ChannelKey | 1+H(`ip-channel`,p)%4; stable |
| WrittenPremiumCents | A in January, zero in other months; renewal booking, not cash receipts |
| EarnedPremiumCents | For first/last year-day ordinals a/b: q×(b−a+1)+max(0,min(b,r)−a+1) |
| ExposureDays | Actual Gregorian days in month, including February 29, 2024 |
| IsActive | Always 1; count distinct policies at selected month-end, not sum over months |

For each policy/year earned equals written exactly to the cent. Opening unearned
premium is zero on 2024-01-01; cumulative written−earned is nonnegative and closes
zero annually. Earning is not one-twelfth of every year's premium.

### FactClaimTransactions columns and expressions

Claims k=1–600. Policy p=1+H(`ic-policy`,k)%800; claim year=2024+((k−1)%2).
R=25000+H(`ic-reserve`,k)%225001; A=R div 3; B=R div 4; C=R−A−B.

| Column | Meaning/expression |
|---|---|
| MovementKey | 4×(k−1)+j, j=1–4; PK |
| TransactionId | `SYN-CTX-`+MovementKey, unique |
| ClaimId | `SYN-CLM-k`, repeated across four movements |
| PolicyId | `SYN-POL-p`; not an FK to another fact |
| DateKey | January 1 of claim year +19,+79,+149,+229 days for j=1,2,3,4 |
| CustomerKey, ProductKey, GeographyKey, ChannelKey | Inherit the policy's stable dimension attributes |
| ClaimTypeKey | 1+H(`ic-type`,k)%4 |
| PaidCents | 0,A,B,C for j=1,2,3,4 |
| RecoveryCents | 0,0,0,R div 10; positive and subtracted once |
| ReserveMovementCents | +R,−A,−B,−C; signed change, not outstanding balance |

Opening claim reserve is zero, cumulative reserve is never negative and closes
zero after movement four. Incurred = paid−recovery+signed reserve movement;
full-life incurred per claim is R−(R div 10). Loss ratio uses incurred/earned
for the identical complete-month period and conformed dimension filters.
Claims with activity counts distinct ClaimId, not movement rows or first reports.

See README for period/as-of scope restrictions, blank handling, reference-control
semantics, canonical identity serialization and business-approval limitations.
