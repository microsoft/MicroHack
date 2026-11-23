# Synthetic finance source package

These are **invented, educational CHF datasets**, not production banking,
insurance, regulatory or actuarial calculations. No real records, people,
accounts, policies or tenant identifiers are used.

The implementation proposes 2024–2025 with 30,174 banking and 22,751 insurance
business rows. This is a **smaller-size deviation from the initial indicative
planning volume**, retaining six dimensions and two facts per scenario. The
volume and financial definitions remain an implementation proposal pending
business approval; this implementation is **not approval of Q-05**.

## Reproduce and validate

Python 3.11+ standard library only. From the lab root:

```powershell
python datasets\generate-data.py --validate
python datasets\generate-data.py --validate --scenario banking
python -m unittest discover -s tests -p test_data.py -v
# Existing canonical files are protected. Explicit replacement:
python datasets\generate-data.py --force
# Or generate a new, empty location:
python datasets\generate-data.py --output .\local-generated-data
```

Default generation refuses to overwrite any existing generated CSV or manifest.
`--force` replaces only the known generated files, not unrelated files or docs.
Validation does not modify inputs. Tests generate two isolated scratch packages
in a unique OS temporary directory, compare every CSV and manifest byte-for-byte, test explicit
replacement and corruption, and remove their scratch directories. No network,
packages, cloud credentials, wall-clock timestamps or Python random state are used.

The checked-in CSVs are ready for a loader; running the generator is optional.
`generate_data.py` is the importable implementation and `generate-data.py` the CLI.
`dictionary.md` specifies grains, column meanings, formulas and semantic limits.

For a coach notebook staging only one scenario, copy `generate_data.py`, the full
manifest and the selected scenario folder under a common root. Import the module
and call `manifest = generate_data.verify_dataset(root, scenario="banking")`
(or `"insurance"`). Omit scenario to verify both. It returns the full decoded
manifest, reads only the selected CSVs, writes nothing, and raises `ValueError`
or `OSError` on failure. `read_table(path, table_metadata)` returns typed row
dictionaries. `controls({table_name: typed_rows, ...})` recomputes exact controls
from parsed/curated rows without calling source generation; include all dimensions
for bank Region slices. The tests use a separate scalar/Decimal reference path.

## Manifest interface (schema 1.0.0)

`manifest.json` has common `schemaVersion`, `datasetVersion`, `algorithm`, `seed`,
`currency`, `serialization` and `scenarios` fields. `scenarios.banking` and
`scenarios.insurance` contain:

* Common version/algorithm/seed/currency, `configuration` (date window,
  `currencyScale:100`, `rateScale:1000000`, all 24 `snapshotDateKeys`).
* `tableOrder`: dimensions before facts, in the documented catalogue order.
  `tables` is an insertion-ordered map keyed by CSV stem/logical table name.
* Each table: ordered `columns:[{name,type,nullable:false}]`; `primaryKey`
  (ordered column names), `alternateKeys` (arrays of names), `foreignKeys`
  (`{columns,referencedTable,referencedColumns}`), `grain`, `expectedRows`,
  `file` (datasets-relative, e.g. `banking/DimDate.csv`), actual `rows`, actual
  uncompressed `bytes`, `sha256` and `dateBounds` (`min`/`max` integer DateKeys,
  or null for a dimension without dates).
* Types are `int32`, `int64`, `string`, `date`, `boolean`. Dates use ISO text;
  flags serialize as 0/1. Integer cents and rate units never use floating point.
* Actual scenario `rows`, `bytes` and independently testable `controls`.
  CSVs must each be strictly below 25,000,000 bytes; each scenario's CSV byte
  sum strictly below 50,000,000 bytes. Manifest/docs are excluded from that sum.
* `datasetHash`: SHA-256 of the entire scenario object **excluding only
  `datasetHash`**. Canonical encoding is UTF-8 of Python-compatible JSON with
  sorted object keys, compact `,`/`:` separators, ASCII escaping, no final LF.
  Array order is significant. Hash covers schemas, versions, configuration,
  filenames, byte hashes, counts and controls. No timestamps or environment IDs.

Do not treat matching schema version alone as matching data identity. Carry
scenario plus dataset hash when tracking provenance. Scenario namespaces are
independent; never join the two scenarios because dimensions share names.

### Exact reference controls

`controls.<FactTable>` has `totals`, `byDate` (`YYYYMMDD`), `byMonth` (`YYYYMM`),
`byYear` (`YYYY`) and `byDimension` (`Column=value`, including derived bank
`Region=Region-n`). Dimension slices include customer/product/channel and any
branch/geography/risk/claim-type/category actually present on that fact. These
are independent single-dimension slices, not precomputed multidimensional cubes.
All 24 calendar months are present in `byMonth`, including zero-activity claim
months; `byDate` records actual fact dates (daily activity or available snapshots).

Each summary has `sourceRows` (all selected source rows), `rows` (rows used for
money aggregation), exact integer cents/ExposureDays totals, and:

* Loan snapshots: first choose latest DateKey **inside the control's selection**;
  then `AsOfDateKey`, `ActiveLoans`, `NonperformingBalanceCents`,
  `WeightedRateNumerator` (sum OutstandingCents × RateUnits) and
  `WeightedRateDenominator` (sum OutstandingCents). Thus yearly/overall balance
  controls are closing balances, **not sums of month-end balances**.
* Premiums: written/earned/exposure are full selected-period flows;
  `ActivePolicies` counts at `AsOfDateKey` only.
* Claims: `IncurredCents = PaidCents - RecoveryCents + ReserveMovementCents`;
  `ClaimsWithActivity` is distinct ClaimId in the selected rows.

Counts are exact; divide cents by 100 only after summing. Weighted rate equals
numerator / denominator / 1,000,000. Ratios with zero denominators are blank.
Decimal money displays use two decimals with half-away-from-zero if rounding is
necessary. Controls remain unrounded integers.

`--validate` checks exact scenario-folder file sets, schema, parse/type/range rules, PKs/alternate keys, all FKs,
sort order, date bounds, counts, sizes, SHA-256, scenario identity and controls.
The unittest suite additionally evaluates every generated fact against a separate
scalar/daily formula path and recomputes every control using Decimal/integer
arithmetic. Hashes detect corruption, not authenticity; this is not a signature.

## Reporting boundaries

Bank transaction amounts are gross activity, not revenue, signed ledger entries,
principal reconciliation or yield. Loan balances are semi-additive. Snapshot
selection uses the latest declared month end within selected dates, before
business filtering; never silently carry forward outside the selection or fall
back when the selected branch has no rows. Channel is unsupported for loan
snapshots; risk is unsupported for transactions.

Insurance flows require a nonempty union of complete calendar months, including
all days in each month. A leap-day-only selection is invalid for insurance flows
even though banking daily flows and that day's month-end snapshot are valid.
ClaimType only filters claims; premium, policy count and loss ratio are blank
with a scope warning under claim-type filtering. Recoveries are positive and
subtracted once. Claims with activity are not “reported claims.” There is no
combined ratio, expense, premium cash collection or ultimate loss dataset.

Default report year is 2025. February 2025 bank prior-year date is 2024-02-29;
2024 has no prior-year comparator. Insurance prior-year comparisons require
every shifted complete month available. Missing/unsupported contexts and
zero-denominator ratios remain blank with a reason, not zero-filled.
