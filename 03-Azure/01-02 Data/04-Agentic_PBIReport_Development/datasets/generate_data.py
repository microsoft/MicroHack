"""Deterministic, dependency-free synthetic finance source and exact controls."""

import argparse
import calendar
import csv
import hashlib
import io
import json
import re
from collections import defaultdict
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path

SEED = 20241119
ALGORITHM = "microhack-finance-synth-v1"
SCHEMA_VERSION = "1.0.0"
DATASET_VERSION = "1.0.0"
START, END = date(2024, 1, 1), date(2025, 12, 31)
MONTHS = [date(y, m, calendar.monthrange(y, m)[1])
          for y in (2024, 2025) for m in range(1, 13)]
MONTH_NAMES = ("January February March April May June July August September "
               "October November December").split()


def h(label, identifier):
    value = f"{SEED}|{label}|{identifier}".encode("utf-8")
    return int.from_bytes(hashlib.sha256(value).digest()[:8], "big")


def key(day):
    return int(day.strftime("%Y%m%d"))


def canonical(value):
    """Canonical identity bytes: sorted keys, compact JSON, ASCII escaping, no LF."""
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=True).encode("utf-8")


def digest(value):
    return hashlib.sha256(value).hexdigest()


def spec(columns, pk, grain, count, alternate=()):
    return {
        "columns": [{"name": n, "type": t, "nullable": False}
                    for n, t in (part.split(":") for part in columns.split())],
        "primaryKey": pk.split(), "alternateKeys": [[x] for x in alternate],
        "foreignKeys": [], "grain": grain, "expectedRows": count,
    }


DATE_SPEC = spec(
    "DateKey:int32 Date:date DayOfMonth:int32 MonthNumber:int32 MonthName:string "
    "MonthKey:int32 QuarterNumber:int32 Year:int32 MonthEndDate:date IsMonthEnd:boolean",
    "DateKey", "One Gregorian calendar day", 731, ["Date"])


def contracts(scenario):
    banking = scenario == "banking"
    tables = {"DimDate": json.loads(json.dumps(DATE_SPEC))}
    tables["DimCustomer"] = spec(
        "CustomerKey:int32 " + ("CustomerId:string Segment:string AgeBand:string "
                               "TenureBand:string" if banking else
                               "PolicyholderId:string Segment:string TenureBand:string"),
        "CustomerKey", "One frozen synthetic customer (Type 0)", 400,
        ["CustomerId" if banking else "PolicyholderId"])
    if banking:
        tables.update({
            "DimProduct": spec("ProductKey:int32 ProductCode:string ProductName:string "
                               "ProductFamily:string", "ProductKey", "One lending product", 4,
                               ["ProductCode"]),
            "DimBranch": spec("BranchKey:int32 BranchCode:string BranchName:string Region:string",
                              "BranchKey", "One synthetic branch", 12, ["BranchCode"]),
            "DimChannel": spec("ChannelKey:int32 ChannelCode:string ChannelName:string",
                               "ChannelKey", "One activity channel", 4, ["ChannelCode"]),
            "DimRiskBand": spec("RiskBandKey:int32 RiskBandCode:string RiskBandName:string "
                                "RiskSort:int32", "RiskBandKey", "One illustrative risk band",
                                3, ["RiskBandCode"]),
            "FactTransactions": spec(
                "TransactionKey:int32 TransactionId:string DateKey:int32 CustomerKey:int32 "
                "ProductKey:int32 BranchKey:int32 ChannelKey:int32 Category:string "
                "AmountCents:int64 FeeCents:int64", "TransactionKey",
                "One posted gross activity; not a signed ledger entry", 14620, ["TransactionId"]),
            "FactLoanMonthlySnapshot": spec(
                "LoanId:string DateKey:int32 CustomerKey:int32 ProductKey:int32 BranchKey:int32 "
                "RiskBandKey:int32 OutstandingCents:int64 RateUnits:int32 IsNonperforming:boolean",
                "LoanId DateKey", "One active loan per month-end; balance semi-additive", 14400),
        })
    else:
        tables.update({
            "DimInsuranceProduct": spec(
                "ProductKey:int32 ProductCode:string ProductName:string LineOfBusiness:string",
                "ProductKey", "One illustrative insurance product", 4, ["ProductCode"]),
            "DimGeography": spec("GeographyKey:int32 GeographyCode:string MarketName:string",
                                 "GeographyKey", "One broad synthetic market", 8, ["GeographyCode"]),
            "DimDistributionChannel": spec("ChannelKey:int32 ChannelCode:string ChannelName:string",
                                           "ChannelKey", "One distribution channel", 4,
                                           ["ChannelCode"]),
            "DimClaimType": spec("ClaimTypeKey:int32 ClaimTypeCode:string ClaimTypeName:string",
                                 "ClaimTypeKey", "One illustrative claim category", 4,
                                 ["ClaimTypeCode"]),
            "FactPremiumMonthly": spec(
                "PolicyId:string DateKey:int32 CustomerKey:int32 ProductKey:int32 GeographyKey:int32 "
                "ChannelKey:int32 WrittenPremiumCents:int64 EarnedPremiumCents:int64 "
                "ExposureDays:int32 IsActive:boolean", "PolicyId DateKey",
                "One active policy per month-end; premiums are period flows", 19200),
            "FactClaimTransactions": spec(
                "MovementKey:int32 TransactionId:string ClaimId:string PolicyId:string DateKey:int32 "
                "CustomerKey:int32 ProductKey:int32 GeographyKey:int32 ChannelKey:int32 "
                "ClaimTypeKey:int32 PaidCents:int64 RecoveryCents:int64 ReserveMovementCents:int64",
                "MovementKey", "One signed-reserve financial movement; not first notification",
                2400, ["TransactionId"]),
        })
    targets = {v["primaryKey"][0]: name for name, v in tables.items()
               if name.startswith("Dim")}
    for name, table in tables.items():
        if name.startswith("Fact"):
            table["foreignKeys"] = [
                {"columns": [c["name"]], "referencedTable": targets[c["name"]],
                 "referencedColumns": [c["name"]]}
                for c in table["columns"] if c["name"] in targets]
    return tables


def policy_attributes(p):
    return [1 + h("ip-" + label, p) % size
            for label, size in (("customer", 400), ("product", 4),
                                ("geography", 8), ("channel", 4))]


def monthly_earned(annual_cents, year, month):
    """Allocate annual cents to calendar days, first remainder days receiving +1."""
    days = calendar.monthrange(year, month)[1]
    last_ordinal = date(year, month, days).timetuple().tm_yday
    first_ordinal = last_ordinal-days+1
    quotient, remainder = divmod(annual_cents, 366 if calendar.isleap(year) else 365)
    return quotient*days + max(0, min(last_ordinal, remainder)-first_ordinal+1)


def ratio(numerator, denominator):
    """Undefined ratios are blank, not zero; callers enforce supported filter scope."""
    return Decimal(numerator)/Decimal(denominator) if denominator else None


def make_rows(scenario):
    banking = scenario == "banking"
    data = {name: [] for name in contracts(scenario)}

    def add(table, values):
        names = [c["name"] for c in contracts_cache[table]["columns"]]
        data[table].append(dict(zip(names, values)))

    contracts_cache = contracts(scenario)
    for offset in range(731):
        day = START + timedelta(days=offset)
        end = date(day.year, day.month, calendar.monthrange(day.year, day.month)[1])
        add("DimDate", [key(day), day.isoformat(), day.day, day.month,
                        MONTH_NAMES[day.month - 1], day.year * 100 + day.month,
                        (day.month - 1) // 3 + 1, day.year, end.isoformat(), int(day == end)])
    for c in range(1, 401):
        values = [c, f"SYN-{'BC' if banking else 'PH'}-{c}", f"Segment-{1+(c-1)%3}"]
        if banking:
            values.append(("18-34", "35-49", "50-64", "65+")[(c-1) % 4])
        add("DimCustomer", values + [("0-2y", "3-5y", "6+y")[(c-1) % 3]])
    if banking:
        for i, label in enumerate(("PersonalLoan", "AutoLoan", "HomeLoan",
                                   "SmallBusinessLoan"), 1):
            add("DimProduct", [i, f"SYN-BP-{i}", label, "Lending"])
        for b in range(1, 13):
            add("DimBranch", [b, f"SYN-BR-{b}", f"Synthetic Branch {b}", f"Region-{1+(b-1)%4}"])
        for i, label in enumerate(("Branch", "Web", "Mobile", "Partner"), 1):
            add("DimChannel", [i, f"SYN-BCH-{i}", label])
        for i, label in enumerate(("Low", "Elevated", "High"), 1):
            add("DimRiskBand", [i, f"SYN-RISK-{i}", label, i])
        for d in range(1, 732):
            day = START + timedelta(days=d-1)
            for slot in range(1, 21):
                t = 20 * (d-1) + slot
                amount = (1000 + h("bt-amount", t) % 99001)
                amount *= 2 if day.month == 12 else 1
                amount *= 10 if slot == 20 and d % 31 == 0 else 1
                add("FactTransactions", [t, f"SYN-BTX-{t}", key(day)] +
                    [1+h("bt-"+label, t) % size for label, size in
                     (("customer", 400), ("product", 4), ("branch", 12), ("channel", 4))] +
                    ["Repayment" if slot <= 12 else "Disbursement", amount, amount // 200])
        for loan in range(1, 601):
            attributes = [1+h("bl-"+label, loan) % size for label, size in
                          (("customer", 400), ("product", 4), ("branch", 12))]
            for m, day in enumerate(MONTHS):
                risk = 1 + (loan-1 + m//6) % 3
                add("FactLoanMonthlySnapshot", [f"SYN-LOAN-{loan}", key(day)] + attributes +
                    [risk, 100000+h("bl-balance", loan) % 4900001-1000*m,
                     20000+h("bl-rate", loan) % 80000, int(risk == 3 and loan % 5 == 0)])
    else:
        for i, label in enumerate(("Motor", "Home", "Travel", "SmallBusiness"), 1):
            add("DimInsuranceProduct", [i, f"SYN-IP-{i}", label, label])
        for i in range(1, 9):
            add("DimGeography", [i, f"SYN-GEO-{i}", f"Market-{i}"])
        for i, label in enumerate(("Direct", "Broker", "Partner", "Online"), 1):
            add("DimDistributionChannel", [i, f"SYN-ICH-{i}", label])
        for i, label in enumerate(("Damage", "Theft", "Liability", "Other"), 1):
            add("DimClaimType", [i, f"SYN-CT-{i}", label])
        for p in range(1, 801):
            for day in MONTHS:
                annual = 12000+h("ip-premium", p) % 108001 + (600 if day.year == 2025 else 0)
                earned = monthly_earned(annual, day.year, day.month)
                add("FactPremiumMonthly", [f"SYN-POL-{p}", key(day)] + policy_attributes(p) +
                    [annual if day.month == 1 else 0, earned, day.day, 1])
        for claim in range(1, 601):
            p = 1+h("ic-policy", claim) % 800
            reserve = 25000+h("ic-reserve", claim) % 225001
            a, b = reserve//3, reserve//4
            c = reserve-a-b
            for j, (offset, paid, recovery, movement) in enumerate(
                    ((19, 0, 0, reserve), (79, a, 0, -a), (149, b, 0, -b),
                     (229, c, reserve//10, -c)), 1):
                movement_key = 4*(claim-1)+j
                day = date(2024+(claim-1) % 2, 1, 1)+timedelta(days=offset)
                add("FactClaimTransactions", [movement_key, f"SYN-CTX-{movement_key}",
                    f"SYN-CLM-{claim}", f"SYN-POL-{p}", key(day)] + policy_attributes(p) +
                    [1+h("ic-type", claim) % 4, paid, recovery, movement])
    for name, rows in data.items():
        rows.sort(key=lambda row: tuple(row[c] for c in contracts_cache[name]["primaryKey"]))
    return data


def summarize(rows, table):
    snapshot = table == "FactLoanMonthlySnapshot"
    active = table == "FactPremiumMonthly"
    source_count = len(rows)
    if snapshot and rows:
        latest = max(r["DateKey"] for r in rows)
        rows = [r for r in rows if r["DateKey"] == latest]
    result = {"sourceRows": source_count, "rows": len(rows)}
    measures = {
        "FactTransactions": ("AmountCents", "FeeCents"),
        "FactLoanMonthlySnapshot": ("OutstandingCents",),
        "FactPremiumMonthly": ("WrittenPremiumCents", "EarnedPremiumCents", "ExposureDays"),
        "FactClaimTransactions": ("PaidCents", "RecoveryCents", "ReserveMovementCents"),
    }
    for column in measures[table]:
        result[column] = sum(r[column] for r in rows)
    if snapshot:
        result.update(
            AsOfDateKey=max((r["DateKey"] for r in rows), default=None),
            ActiveLoans=len({r["LoanId"] for r in rows}),
            NonperformingBalanceCents=sum(r["OutstandingCents"] for r in rows
                                         if r["IsNonperforming"]),
            WeightedRateNumerator=sum(r["OutstandingCents"]*r["RateUnits"] for r in rows),
            WeightedRateDenominator=sum(r["OutstandingCents"] for r in rows))
    if active:
        latest = max((r["DateKey"] for r in rows), default=None)
        result["AsOfDateKey"] = latest
        result["ActivePolicies"] = len({r["PolicyId"] for r in rows
                                        if r["DateKey"] == latest and r["IsActive"]})
    if table == "FactClaimTransactions":
        result["ClaimsWithActivity"] = len({r["ClaimId"] for r in rows})
        result["IncurredCents"] = (result.get("PaidCents", 0)-result.get("RecoveryCents", 0)
                                   + result.get("ReserveMovementCents", 0))
    return result


def controls(data):
    result = {}
    branches = {r["BranchKey"]: r["Region"] for r in data.get("DimBranch", [])}
    for name, rows in data.items():
        if not name.startswith("Fact"):
            continue
        groups = {"byDate": defaultdict(list), "byMonth": defaultdict(list),
                  "byYear": defaultdict(list), "byDimension": defaultdict(list)}
        for row in rows:
            day = str(row["DateKey"])
            groups["byDate"][day].append(row)
            groups["byMonth"][day[:6]].append(row)
            groups["byYear"][day[:4]].append(row)
            for column in ("ProductKey", "BranchKey", "ChannelKey", "GeographyKey",
                           "RiskBandKey", "ClaimTypeKey", "CustomerKey", "Category"):
                if column in row:
                    groups["byDimension"][f"{column}={row[column]}"].append(row)
            if "BranchKey" in row:
                groups["byDimension"]["Region="+branches[row["BranchKey"]]].append(row)
        result[name] = {"totals": summarize(rows, name)}
        for month in MONTHS:
            groups["byMonth"].setdefault(str(key(month))[:6], [])
        for grouping, buckets in groups.items():
            result[name][grouping] = {k: summarize(v, name) for k, v in sorted(buckets.items())}
    return result


def csv_bytes(rows, columns):
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(stream, fieldnames=[c["name"] for c in columns], lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return stream.getvalue().encode("utf-8")


def generate(output, force=False):
    output = Path(output)
    names = [output / scenario / (name+".csv") for scenario in ("banking", "insurance")
             for name in contracts(scenario)] + [output / "manifest.json"]
    if not force and any(p.exists() for p in names):
        raise FileExistsError("Output already exists; use --force to replace generated files")
    manifest = {
        "schemaVersion": SCHEMA_VERSION, "datasetVersion": DATASET_VERSION,
        "algorithm": ALGORITHM, "seed": SEED, "currency": "CHF",
        "serialization": {"encoding": "UTF-8", "bom": False, "lineEnding": "LF",
                          "delimiter": ",", "null": "", "allBusinessColumnsRequired": True},
        "scenarios": {},
    }
    for scenario in ("banking", "insurance"):
        data = make_rows(scenario)
        tables = contracts(scenario)
        for name, table in tables.items():
            content = csv_bytes(data[name], table["columns"])
            filename = scenario+"/"+name+".csv"
            target = output / scenario / (name+".csv")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
            dates = [r["DateKey"] for r in data[name] if "DateKey" in r]
            table.update(file=filename, rows=len(data[name]), bytes=len(content), sha256=digest(content),
                         dateBounds={"min": min(dates), "max": max(dates)} if dates else None)
            if len(content) >= 25000000:
                raise ValueError("CSV size limit exceeded")
        entry = {
            "schemaVersion": SCHEMA_VERSION, "datasetVersion": DATASET_VERSION,
            "algorithm": ALGORITHM, "seed": SEED, "currency": "CHF",
            "configuration": {"startDate": START.isoformat(), "endDate": END.isoformat(),
                              "rateScale": 1000000, "currencyScale": 100,
                              "snapshotDateKeys": [key(d) for d in MONTHS]},
            "tableOrder": list(tables), "tables": tables,
            "rows": sum(t["rows"] for t in tables.values()),
            "bytes": sum(t["bytes"] for t in tables.values()), "controls": controls(data),
        }
        if entry["bytes"] >= 50000000:
            raise ValueError("Scenario size limit exceeded")
        entry["datasetHash"] = digest(canonical(entry))
        manifest["scenarios"][scenario] = entry
    (output / "manifest.json").write_bytes(
        (json.dumps(manifest, indent=2, ensure_ascii=True)+"\n").encode("utf-8"))
    return manifest


def read_table(path, table):
    raw = Path(path).read_bytes()
    if b"\r" in raw or raw.startswith(b"\xef\xbb\xbf") or not raw.endswith(b"\n"):
        raise ValueError("Noncanonical CSV encoding or line endings")
    reader = csv.reader(io.StringIO(raw.decode("utf-8"), newline=""))
    columns = table["columns"]
    if next(reader, None) != [c["name"] for c in columns]:
        raise ValueError("Schema/header mismatch")
    rows = []
    for values in reader:
        if len(values) != len(columns):
            raise ValueError("Column count mismatch")
        row = {}
        for column, value in zip(columns, values):
            kind, name = column["type"], column["name"]
            if not value:
                raise ValueError("Null business value")
            if kind in ("int32", "int64", "boolean"):
                if not re.fullmatch(r"0|-?[1-9][0-9]*", value):
                    raise ValueError("Malformed integer")
                value = int(value)
                bits = 64 if kind == "int64" else 32
                if not -(2**(bits-1)) <= value < 2**(bits-1):
                    raise ValueError("Integer overflow")
                if kind == "boolean" and value not in (0, 1):
                    raise ValueError("Malformed boolean")
                if name.endswith("Key") and value <= 0:
                    raise ValueError("Nonpositive key")
                if name.endswith("Cents") and name != "ReserveMovementCents" and value < 0:
                    raise ValueError("Negative unsigned monetary value")
            elif kind == "date":
                if date.fromisoformat(value).isoformat() != value:
                    raise ValueError("Malformed date")
            elif kind != "string" or len(value) > 128:
                raise ValueError("Invalid string or type")
            row[name] = value
        rows.append(row)
    return rows


def validate_package(output, verify_checksums=True, scenario=None):
    """Reject structural/integrity errors independently of source construction."""
    output = Path(output)
    manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
    if any(manifest.get(k) != v for k, v in (
            ("schemaVersion", SCHEMA_VERSION), ("datasetVersion", DATASET_VERSION),
            ("algorithm", ALGORITHM), ("seed", SEED), ("currency", "CHF"))):
        raise ValueError("Unsupported manifest identity")
    if scenario is not None and scenario not in ("banking", "insurance"):
        raise ValueError("Unknown scenario")
    for scenario in ((scenario,) if scenario else ("banking", "insurance")):
        entry = manifest["scenarios"][scenario]
        for field in ("schemaVersion", "datasetVersion", "algorithm", "seed", "currency"):
            if entry[field] != manifest[field]:
                raise ValueError("Scenario metadata mismatch")
        identity = {k: v for k, v in entry.items() if k != "datasetHash"}
        if verify_checksums and digest(canonical(identity)) != entry["datasetHash"]:
            raise ValueError("Scenario identity checksum mismatch")
        expected = contracts(scenario)
        if entry["tableOrder"] != list(expected) or set(entry["tables"]) != set(expected):
            raise ValueError("Unexpected table set or order")
        if {p.name for p in (output / scenario).iterdir()} != {name+".csv" for name in expected}:
            raise ValueError("Unexpected source file set")
        data = {}
        for name, contract in expected.items():
            table = entry["tables"][name]
            for field in ("columns", "primaryKey", "alternateKeys", "foreignKeys", "grain",
                          "expectedRows"):
                if table[field] != contract[field]:
                    raise ValueError("Table contract mismatch")
            if table["file"] != scenario+"/"+name+".csv":
                raise ValueError("Unsafe or unexpected source file")
            path = output / scenario / (name+".csv")
            raw = path.read_bytes()
            if verify_checksums and digest(raw) != table["sha256"]:
                raise ValueError("CSV checksum mismatch")
            if len(raw) != table["bytes"] or len(raw) >= 25000000:
                raise ValueError("Byte size mismatch or limit")
            rows = read_table(path, table)
            if len(rows) != table["rows"] or len(rows) != contract["expectedRows"]:
                raise ValueError("Row count mismatch")
            pk_values = [tuple(r[c] for c in table["primaryKey"]) for r in rows]
            if len(set(pk_values)) != len(rows):
                raise ValueError("Duplicate primary key")
            if pk_values != sorted(pk_values):
                raise ValueError("Rows not in primary-key order")
            dates = [r["DateKey"] for r in rows if "DateKey" in r]
            bounds = {"min": min(dates), "max": max(dates)} if dates else None
            if table["dateBounds"] != bounds:
                raise ValueError("Date bounds mismatch")
            for alternate in table["alternateKeys"]:
                if len({tuple(r[c] for c in alternate) for r in rows}) != len(rows):
                    raise ValueError("Duplicate alternate key")
            data[name] = rows
        for name, table in expected.items():
            for fk in table["foreignKeys"]:
                target = {tuple(r[c] for c in fk["referencedColumns"])
                          for r in data[fk["referencedTable"]]}
                if any(tuple(r[c] for c in fk["columns"]) not in target for r in data[name]):
                    raise ValueError("Orphan foreign key")
        if (sum(t["bytes"] for t in entry["tables"].values()) != entry["bytes"]
                or entry["bytes"] >= 50000000
                or sum(len(r) for r in data.values()) != entry["rows"]):
            raise ValueError("Scenario size or count mismatch")
        if controls(data) != entry["controls"]:
            raise ValueError("Reference controls mismatch")
    return manifest


def verify_dataset(root, scenario=None):
    """Read-only verification; selected scenario needs only its CSVs plus full manifest.

    Return the full decoded manifest on success; raise ValueError/OSError on failure.
    No generation, downloads, writes, or imports beyond the standard library.
    """
    return validate_package(root, scenario=scenario)


def as_of(selected_dates, available_dates):
    return max(set(selected_dates).intersection(available_dates), default=None)


def complete_months(selected_dates):
    days = set(selected_dates)
    return bool(days) and all(
        {date(d.year, d.month, n) for n in range(1, calendar.monthrange(d.year, d.month)[1]+1)}
        <= days for d in days)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path(__file__).parent)
    parser.add_argument("--force", action="store_true", help="Replace generated CSVs/manifest explicitly")
    parser.add_argument("--validate", action="store_true", help="Validate existing files; do not generate")
    parser.add_argument("--scenario", choices=("banking", "insurance"),
                        help="Verify just one scenario (requires --validate)")
    args = parser.parse_args()
    if args.scenario and not args.validate:
        parser.error("--scenario requires --validate")
    try:
        manifest = (verify_dataset(args.output, args.scenario) if args.validate
                    else generate(args.output, args.force))
    except (ValueError, FileExistsError, OSError) as exc:
        parser.exit(1, str(exc)+"\n")
    for scenario, entry in manifest["scenarios"].items():
        if args.scenario and args.scenario != scenario:
            continue
        print(f"{scenario}: {entry['rows']} rows, {entry['bytes']} bytes, {entry['datasetHash']}")


if __name__ == "__main__":
    main()
