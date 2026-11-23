"""Independent scalar/Decimal oracles for the frozen synthetic source contract."""

import calendar
import copy
import csv
import hashlib
import importlib.util
import json
import shutil
import tempfile
import unittest
from collections import defaultdict
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "datasets"
SPEC = importlib.util.spec_from_file_location("finance_data", DATA / "generate_data.py")
GEN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GEN)


def oracle_hash(label, identifier):
    encoded = ("20241119|" + label + "|" + str(identifier)).encode("ascii")
    return int(hashlib.sha256(encoded).hexdigest()[:16], 16)


def iso_key(value):
    return date(int(str(value)[:4]), int(str(value)[4:6]), int(str(value)[6:]))


def read_csv(path):
    with path.open(encoding="utf-8", newline="") as stream:
        rows = list(csv.DictReader(stream))
    for row in rows:
        for column, value in row.items():
            if (column.endswith(("Key", "Cents", "Units")) or
                    column in ("DayOfMonth", "MonthNumber", "QuarterNumber", "Year",
                               "IsMonthEnd", "RiskSort", "IsActive", "IsNonperforming",
                               "ExposureDays")):
                row[column] = int(value)
    return rows


def independent_summary(rows, name):
    selected = rows
    result = {"sourceRows": len(rows), "rows": len(rows)}
    if name == "FactLoanMonthlySnapshot":
        last = max(r["DateKey"] for r in rows)
        selected = [r for r in rows if r["DateKey"] == last]
        result.update(
            rows=len(selected), AsOfDateKey=last,
            ActiveLoans=len({r["LoanId"] for r in selected}),
            NonperformingBalanceCents=sum(r["OutstandingCents"] for r in selected
                                         if r["IsNonperforming"] == 1),
            WeightedRateNumerator=sum(r["OutstandingCents"] * r["RateUnits"] for r in selected),
            WeightedRateDenominator=sum(r["OutstandingCents"] for r in selected))
    measure_columns = {
        "FactTransactions": ["AmountCents", "FeeCents"],
        "FactLoanMonthlySnapshot": ["OutstandingCents"],
        "FactPremiumMonthly": ["WrittenPremiumCents", "EarnedPremiumCents", "ExposureDays"],
        "FactClaimTransactions": ["PaidCents", "RecoveryCents", "ReserveMovementCents"],
    }[name]
    for column in measure_columns:
        # Decimal path intentionally separate from production integer aggregation.
        result[column] = int(sum((Decimal(str(r[column])) for r in selected), Decimal(0)))
    if name == "FactPremiumMonthly":
        last = max(r["DateKey"] for r in selected)
        result.update(AsOfDateKey=last, ActivePolicies=len({
            r["PolicyId"] for r in selected if r["DateKey"] == last and r["IsActive"] == 1}))
    if name == "FactClaimTransactions":
        result["ClaimsWithActivity"] = len({r["ClaimId"] for r in selected})
        result["IncurredCents"] = int(sum(
            (Decimal(r["PaidCents"])-Decimal(r["RecoveryCents"])+Decimal(r["ReserveMovementCents"])
             for r in selected), Decimal(0)))
    return result


class SourceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((DATA / "manifest.json").read_text(encoding="utf-8"))
        cls.rows = {scenario: {name: read_csv(DATA / table["file"])
                              for name, table in entry["tables"].items()}
                    for scenario, entry in cls.manifest["scenarios"].items()}

    def test_exact_schema_keys_types_and_relationships(self):
        bank_headers = {
            "DimDate": "DateKey Date DayOfMonth MonthNumber MonthName MonthKey QuarterNumber Year MonthEndDate IsMonthEnd",
            "DimCustomer": "CustomerKey CustomerId Segment AgeBand TenureBand",
            "DimProduct": "ProductKey ProductCode ProductName ProductFamily",
            "DimBranch": "BranchKey BranchCode BranchName Region",
            "DimChannel": "ChannelKey ChannelCode ChannelName",
            "DimRiskBand": "RiskBandKey RiskBandCode RiskBandName RiskSort",
            "FactTransactions": "TransactionKey TransactionId DateKey CustomerKey ProductKey BranchKey ChannelKey Category AmountCents FeeCents",
            "FactLoanMonthlySnapshot": "LoanId DateKey CustomerKey ProductKey BranchKey RiskBandKey OutstandingCents RateUnits IsNonperforming",
        }
        insurance_headers = {
            "DimDate": bank_headers["DimDate"],
            "DimCustomer": "CustomerKey PolicyholderId Segment TenureBand",
            "DimInsuranceProduct": "ProductKey ProductCode ProductName LineOfBusiness",
            "DimGeography": "GeographyKey GeographyCode MarketName",
            "DimDistributionChannel": "ChannelKey ChannelCode ChannelName",
            "DimClaimType": "ClaimTypeKey ClaimTypeCode ClaimTypeName",
            "FactPremiumMonthly": "PolicyId DateKey CustomerKey ProductKey GeographyKey ChannelKey WrittenPremiumCents EarnedPremiumCents ExposureDays IsActive",
            "FactClaimTransactions": "MovementKey TransactionId ClaimId PolicyId DateKey CustomerKey ProductKey GeographyKey ChannelKey ClaimTypeKey PaidCents RecoveryCents ReserveMovementCents",
        }
        expected_counts = {
            "banking": [731, 400, 4, 12, 4, 3, 14620, 14400],
            "insurance": [731, 400, 4, 8, 4, 4, 19200, 2400],
        }
        for scenario, headers in (("banking", bank_headers), ("insurance", insurance_headers)):
            tables = self.manifest["scenarios"][scenario]["tables"]
            self.assertEqual(list(tables), list(headers))
            self.assertEqual(sum(map(len, self.rows[scenario].values())),
                             30174 if scenario == "banking" else 22751)
            for (name, header), count in zip(headers.items(), expected_counts[scenario]):
                table, rows = tables[name], self.rows[scenario][name]
                self.assertEqual(list(rows[0]), header.split())
                self.assertEqual([c["name"] for c in table["columns"]], header.split())
                self.assertEqual(len(rows), count)
                self.assertTrue(all(not c["nullable"] for c in table["columns"]))
                expected_pk = (["LoanId", "DateKey"] if name == "FactLoanMonthlySnapshot" else
                               ["PolicyId", "DateKey"] if name == "FactPremiumMonthly" else
                               [header.split()[0]])
                self.assertEqual(table["primaryKey"], expected_pk)
                pks = [tuple(row[c] for c in expected_pk) for row in rows]
                self.assertEqual(len(pks), len(set(pks)))
                self.assertEqual(pks, sorted(pks))
                for alternate in table["alternateKeys"]:
                    self.assertEqual(len(rows), len({tuple(r[c] for c in alternate) for r in rows}))
                for column in table["columns"]:
                    c, kind = column["name"], column["type"]
                    expected_kind = (
                        "int64" if c.endswith("Cents") else
                        "boolean" if c in ("IsActive", "IsNonperforming", "IsMonthEnd") else
                        "date" if c in ("Date", "MonthEndDate") else
                        "int32" if isinstance(rows[0][c], int) else "string")
                    self.assertEqual(kind, expected_kind)
                    for row in rows:
                        self.assertNotEqual(row[c], "")
                        if kind == "boolean":
                            self.assertIn(row[c], (0, 1))
                        if kind in ("int32", "int64"):
                            bits = 32 if kind == "int32" else 64
                            self.assertTrue(-(2**(bits-1)) <= row[c] < 2**(bits-1))
                fact_keys = [c for c in header.split() if c.endswith("Key")
                             and c not in ("TransactionKey", "MovementKey")]
                if name.startswith("Fact"):
                    self.assertEqual({fk["columns"][0] for fk in table["foreignKeys"]}, set(fact_keys))
                for fk in table["foreignKeys"]:
                    target = {tuple(r[c] for c in fk["referencedColumns"])
                              for r in self.rows[scenario][fk["referencedTable"]]}
                    self.assertTrue(all(tuple(r[c] for c in fk["columns"]) in target for r in rows))

    def test_calendar_leap_month_ends_and_dimension_attributes(self):
        expected_dates = [date(2024, 1, 1)+timedelta(days=i) for i in range(731)]
        for scenario, data in self.rows.items():
            dates = data["DimDate"]
            self.assertEqual([r["Date"] for r in dates], [d.isoformat() for d in expected_dates])
            self.assertEqual(sum(r["IsMonthEnd"] for r in dates), 24)
            self.assertIn(20240229, [r["DateKey"] for r in dates])
            for r, day in zip(dates, expected_dates):
                last = calendar.monthrange(day.year, day.month)[1]
                self.assertEqual(r["DateKey"], int(day.strftime("%Y%m%d")))
                self.assertEqual((r["DayOfMonth"], r["MonthNumber"], r["Year"]),
                                 (day.day, day.month, day.year))
                self.assertEqual(r["MonthKey"], day.year*100+day.month)
                self.assertEqual(r["QuarterNumber"], (day.month+2)//3)
                self.assertEqual(r["MonthName"], calendar.month_name[day.month])
                self.assertEqual(r["MonthEndDate"], date(day.year, day.month, last).isoformat())
                self.assertEqual(r["IsMonthEnd"], int(day.day == last))
            for name in ("FactLoanMonthlySnapshot", "FactPremiumMonthly"):
                for row in data.get(name, []):
                    day = iso_key(row["DateKey"])
                    self.assertEqual(day.day, calendar.monthrange(day.year, day.month)[1])
            for r in data["DimCustomer"]:
                c = r["CustomerKey"]
                self.assertEqual(r["Segment"], f"Segment-{1+(c-1)%3}")
                self.assertEqual(r["TenureBand"], ("0-2y", "3-5y", "6+y")[(c-1)%3])
                if scenario == "banking":
                    self.assertEqual(r["AgeBand"], ("18-34", "35-49", "50-64", "65+")[(c-1)%4])
        self.assertEqual([r["Region"] for r in self.rows["banking"]["DimBranch"]],
                         [f"Region-{1+i%4}" for i in range(12)])

    def test_bank_all_transactions_match_scalar_specification(self):
        counts = defaultdict(int)
        for row in self.rows["banking"]["FactTransactions"]:
            t = row["TransactionKey"]
            offset, slot = divmod(t-1, 20)
            slot += 1
            day = date(2024, 1, 1)+timedelta(days=offset)
            counts[row["DateKey"]] += 1
            self.assertEqual(row["DateKey"], int(day.strftime("%Y%m%d")))
            self.assertEqual(row["TransactionId"], "SYN-BTX-"+str(t))
            for col, label, size in (("CustomerKey", "customer", 400), ("ProductKey", "product", 4),
                                     ("BranchKey", "branch", 12), ("ChannelKey", "channel", 4)):
                self.assertEqual(row[col], oracle_hash("bt-"+label, t) % size+1)
            cents = oracle_hash("bt-amount", t) % 99001+1000
            if day.month == 12:
                cents *= 2
            if slot == 20 and (offset+1) % 31 == 0:
                cents *= 10
            self.assertEqual(row["Category"], "Repayment" if slot < 13 else "Disbursement")
            self.assertEqual((row["AmountCents"], row["FeeCents"]), (cents, cents//200))
        self.assertEqual(set(counts.values()), {20})
        self.assertEqual(len(counts), 731)

    def test_bank_stability_risk_amortization_and_weighted_rate(self):
        grouped = defaultdict(list)
        for row in self.rows["banking"]["FactLoanMonthlySnapshot"]:
            grouped[row["LoanId"]].append(row)
        self.assertEqual(len(grouped), 600)
        for loan_id, rows in grouped.items():
            loan = int(loan_id.split("-")[-1])
            self.assertEqual(len(rows), 24)
            for column, label, size in (("CustomerKey", "customer", 400),
                                        ("ProductKey", "product", 4), ("BranchKey", "branch", 12)):
                self.assertEqual({r[column] for r in rows}, {oracle_hash("bl-"+label, loan) % size+1})
            self.assertEqual({r["RateUnits"] for r in rows},
                             {20000+oracle_hash("bl-rate", loan) % 80000})
            for month_index, row in enumerate(rows):
                risk = (loan-1+month_index//6) % 3+1
                self.assertEqual(row["RiskBandKey"], risk)
                self.assertEqual(row["IsNonperforming"], int(risk == 3 and loan % 5 == 0))
                self.assertEqual(row["OutstandingCents"],
                                 100000+oracle_hash("bl-balance", loan) % 4900001-1000*month_index)
                self.assertGreater(row["OutstandingCents"], 0)
        all_rows = self.rows["banking"]["FactLoanMonthlySnapshot"]
        feb24 = [r for r in all_rows if r["DateKey"] == 20240229]
        feb25 = [r for r in all_rows if r["DateKey"] == 20250228]
        self.assertEqual(sum(r["OutstandingCents"] for r in feb24) -
                         sum(r["OutstandingCents"] for r in feb25), 600*12000)
        selected = [r for r in all_rows if r["DateKey"] == 20251231]
        numerator = sum(Decimal(r["OutstandingCents"])*Decimal(r["RateUnits"]) for r in selected)
        denominator = sum(Decimal(r["OutstandingCents"]) for r in selected)
        rate = numerator/denominator/Decimal(1000000)
        self.assertTrue(Decimal(".02") <= rate < Decimal(".10"))
        controls = self.manifest["scenarios"]["banking"]["controls"]["FactLoanMonthlySnapshot"]
        self.assertEqual(Decimal(controls["totals"]["WeightedRateNumerator"]), numerator)
        self.assertEqual(Decimal(controls["totals"]["WeightedRateDenominator"]), denominator)
        self.assertEqual(controls["totals"]["OutstandingCents"], int(denominator))

    def test_insurance_independent_daily_earning_annual_parity(self):
        by_policy_year = defaultdict(list)
        for row in self.rows["insurance"]["FactPremiumMonthly"]:
            policy = int(row["PolicyId"].split("-")[-1])
            day = iso_key(row["DateKey"])
            by_policy_year[(policy, day.year)].append(row)
            for column, label, size in (("CustomerKey", "customer", 400), ("ProductKey", "product", 4),
                                        ("GeographyKey", "geography", 8), ("ChannelKey", "channel", 4)):
                self.assertEqual(row[column], oracle_hash("ip-"+label, policy) % size+1)
            annual = 12000+oracle_hash("ip-premium", policy) % 108001+600*(day.year-2024)
            year_days = (date(day.year+1, 1, 1)-date(day.year, 1, 1)).days
            base, extra = divmod(annual, year_days)
            first = (date(day.year, day.month, 1)-date(day.year, 1, 1)).days
            # Explicit daily allocation is independent of the closed-form generator.
            earned = sum(base+int(ordinal < extra) for ordinal in range(first, first+day.day))
            self.assertEqual(row["EarnedPremiumCents"], earned)
            self.assertEqual(row["WrittenPremiumCents"], annual if day.month == 1 else 0)
            self.assertEqual(row["ExposureDays"], day.day)
            self.assertEqual(row["IsActive"], 1)
        self.assertEqual(len(by_policy_year), 1600)
        for (policy, year), rows in by_policy_year.items():
            self.assertEqual(len(rows), 12)
            self.assertEqual(sum(r["EarnedPremiumCents"] for r in rows),
                             sum(r["WrittenPremiumCents"] for r in rows))
            self.assertEqual(sum(r["ExposureDays"] for r in rows), 366 if year == 2024 else 365)
            unearned = 0
            for row in sorted(rows, key=lambda r: r["DateKey"]):
                unearned += row["WrittenPremiumCents"]-row["EarnedPremiumCents"]
                self.assertGreaterEqual(unearned, 0)
            self.assertEqual(unearned, 0)

    def test_insurance_claim_cash_recovery_reserve_and_inheritance(self):
        policies = {r["PolicyId"]: r for r in self.rows["insurance"]["FactPremiumMonthly"]}
        claims = defaultdict(list)
        for row in self.rows["insurance"]["FactClaimTransactions"]:
            claims[row["ClaimId"]].append(row)
        self.assertEqual(len(claims), 600)
        for claim_id, rows in claims.items():
            claim = int(claim_id.split("-")[-1])
            rows.sort(key=lambda r: r["MovementKey"])
            policy_id = "SYN-POL-"+str(oracle_hash("ic-policy", claim) % 800+1)
            initial = 25000+oracle_hash("ic-reserve", claim) % 225001
            balance, paid, recovery, movement_total = 0, 0, 0, 0
            self.assertEqual(len(rows), 4)
            self.assertEqual([r["PaidCents"] for r in rows],
                             [0, initial//3, initial//4, initial-initial//3-initial//4])
            for j, (row, offset) in enumerate(zip(rows, (19, 79, 149, 229)), 1):
                self.assertEqual(row["MovementKey"], 4*(claim-1)+j)
                self.assertEqual(row["TransactionId"], f"SYN-CTX-{4*(claim-1)+j}")
                self.assertEqual(iso_key(row["DateKey"]),
                                 date(2024+(claim-1)%2, 1, 1)+timedelta(days=offset))
                self.assertEqual(row["PolicyId"], policy_id)
                self.assertEqual(row["ClaimTypeKey"], oracle_hash("ic-type", claim) % 4+1)
                for column in ("CustomerKey", "ProductKey", "GeographyKey", "ChannelKey"):
                    self.assertEqual(row[column], policies[policy_id][column])
                self.assertEqual(row["ReserveMovementCents"],
                                 initial if j == 1 else -row["PaidCents"])
                self.assertEqual(row["RecoveryCents"], initial//10 if j == 4 else 0)
                balance += row["ReserveMovementCents"]
                self.assertGreaterEqual(balance, 0)
                paid += row["PaidCents"]
                recovery += row["RecoveryCents"]
                movement_total += row["ReserveMovementCents"]
            self.assertEqual(balance, 0)
            self.assertEqual(paid-recovery+movement_total, initial-initial//10)

    def test_every_reference_slice_independently_recomputed(self):
        for scenario, data in self.rows.items():
            branch_regions = {r["BranchKey"]: r["Region"] for r in data.get("DimBranch", [])}
            for name, reference in self.manifest["scenarios"][scenario]["controls"].items():
                rows = data[name]
                self.assertEqual(reference["totals"], independent_summary(rows, name))
                for grouping in ("byDate", "byMonth", "byYear", "byDimension"):
                    independently_grouped = defaultdict(list)
                    for row in rows:
                        d = str(row["DateKey"])
                        if grouping == "byDimension":
                            for column in ("ProductKey", "BranchKey", "ChannelKey", "GeographyKey",
                                           "RiskBandKey", "ClaimTypeKey", "CustomerKey", "Category"):
                                if column in row:
                                    independently_grouped[f"{column}={row[column]}"].append(row)
                            if "BranchKey" in row:
                                independently_grouped["Region="+branch_regions[row["BranchKey"]]].append(row)
                        else:
                            prefix = {"byDate": 8, "byMonth": 6, "byYear": 4}[grouping]
                            independently_grouped[d[:prefix]].append(row)
                    if grouping == "byMonth":
                        for y in (2024, 2025):
                            for m in range(1, 13):
                                independently_grouped.setdefault(f"{y}{m:02}", [])
                    self.assertEqual(set(reference[grouping]), set(independently_grouped))
                    for slice_key, selected in independently_grouped.items():
                        self.assertEqual(reference[grouping][slice_key],
                                         independent_summary(selected, name),
                                         (scenario, name, grouping, slice_key))

    def test_actual_bytes_hashes_and_identity(self):
        for scenario, entry in self.manifest["scenarios"].items():
            total = 0
            for name, table in entry["tables"].items():
                raw = (DATA / table["file"]).read_bytes()
                self.assertNotIn(b"\r", raw)
                self.assertFalse(raw.startswith(b"\xef\xbb\xbf"))
                self.assertTrue(raw.endswith(b"\n"))
                self.assertEqual(len(raw), table["bytes"])
                self.assertLess(len(raw), 25000000)
                self.assertEqual(hashlib.sha256(raw).hexdigest(), table["sha256"])
                total += len(raw)
                if table["dateBounds"]:
                    dates = [r["DateKey"] for r in self.rows[scenario][name]]
                    self.assertEqual(table["dateBounds"], {"min": min(dates), "max": max(dates)})
            self.assertLess(total, 50000000)
            self.assertEqual(total, entry["bytes"])
            identity = {k: v for k, v in entry.items() if k != "datasetHash"}
            encoded = json.dumps(identity, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()
            self.assertEqual(hashlib.sha256(encoded).hexdigest(), entry["datasetHash"])
        GEN.validate_package(DATA)

    def test_regeneration_twice_and_explicit_overwrite_guard(self):
        # Unique OS-temp scratch is removed even on assertion failure.
        with tempfile.TemporaryDirectory(prefix="microhack-data-test-") as folder:
            path = Path(folder)
            GEN.generate(path / "first")
            GEN.generate(path / "second")
            first = path / "first"
            for reference in (DATA / "banking").glob("*.csv"):
                self.assertEqual(reference.read_bytes(), (first / "banking" / reference.name).read_bytes())
            for scenario in ("banking", "insurance"):
                for original in (DATA / scenario).glob("*.csv"):
                    self.assertEqual(original.read_bytes(), (first / scenario / original.name).read_bytes())
                    self.assertEqual(original.read_bytes(), (path / "second" / scenario / original.name).read_bytes())
            self.assertEqual((DATA / "manifest.json").read_bytes(), (first / "manifest.json").read_bytes())
            self.assertEqual((first / "manifest.json").read_bytes(),
                             (path / "second" / "manifest.json").read_bytes())
            before = (first / "manifest.json").read_bytes()
            with self.assertRaises(FileExistsError):
                GEN.generate(first)
            self.assertEqual(before, (first / "manifest.json").read_bytes())
            GEN.generate(first, force=True)
            self.assertEqual(before, (first / "manifest.json").read_bytes())
            GEN.validate_package(first)

    def test_tampering_checksum_duplicate_orphan_and_malformed_values(self):
        with tempfile.TemporaryDirectory(prefix="microhack-data-tamper-") as folder:
            dest = Path(folder)
            for scenario in ("banking", "insurance"):
                shutil.copytree(DATA / scenario, dest / scenario)
            shutil.copyfile(DATA / "manifest.json", dest / "manifest.json")
            path = dest / "banking" / "FactTransactions.csv"
            original = path.read_bytes()
            lines = original.decode().splitlines()
            baseline_manifest = copy.deepcopy(self.manifest)

            unsupported_currency = copy.deepcopy(baseline_manifest)
            unsupported_currency["currency"] = "USD"
            (dest / "manifest.json").write_text(json.dumps(unsupported_currency), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Unsupported manifest identity"):
                GEN.validate_package(dest)
            (dest / "manifest.json").write_text(json.dumps(baseline_manifest), encoding="utf-8")

            def replace_line(line):
                edited = lines.copy()
                edited[2] = line
                raw = ("\n".join(edited)+"\n").encode()
                path.write_bytes(raw)
                manifest = copy.deepcopy(baseline_manifest)
                table = manifest["scenarios"]["banking"]["tables"]["FactTransactions"]
                table["bytes"] = len(raw)
                # Structural corruption is tested even if an attacker updates metadata.
                (dest / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")

            path.write_bytes(original.replace(b"SYN-BTX-1,", b"SYN-BTX-X,", 1))
            with self.assertRaisesRegex(ValueError, "checksum"):
                GEN.validate_package(dest)
            replace_line(lines[1])
            with self.assertRaisesRegex(ValueError, "Duplicate primary"):
                GEN.validate_package(dest, verify_checksums=False)
            values = lines[2].split(",")
            values[3] = "999999"
            replace_line(",".join(values))
            with self.assertRaisesRegex(ValueError, "Orphan"):
                GEN.validate_package(dest, verify_checksums=False)
            for malformed in ("1.5", "1e3", "", "01", "-1", "9223372036854775808"):
                values = lines[2].split(",")
                values[8] = malformed
                replace_line(",".join(values))
                with self.subTest(malformed=malformed), self.assertRaises(ValueError):
                    GEN.validate_package(dest, verify_checksums=False)
            path.write_bytes(original)
            (dest / "manifest.json").write_text(json.dumps(baseline_manifest), encoding="utf-8")
            GEN.validate_package(dest)

    def test_selected_scenario_verifier_requires_no_other_scenario_files(self):
        with tempfile.TemporaryDirectory(prefix="microhack-data-selected-") as folder:
            dest = Path(folder)
            shutil.copyfile(DATA / "manifest.json", dest / "manifest.json")
            shutil.copytree(DATA / "insurance", dest / "insurance")
            manifest = GEN.verify_dataset(dest, "insurance")
            self.assertEqual(manifest["scenarios"]["insurance"]["rows"], 22751)
            self.assertFalse((dest / "banking").exists())
            extra = dest / "insurance" / "Unexpected.csv"
            extra.write_text("unexpected\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "source file set"):
                GEN.verify_dataset(dest, "insurance")
            extra.unlink()
            with self.assertRaises(OSError):
                GEN.verify_dataset(dest)
            with self.assertRaisesRegex(ValueError, "Unknown scenario"):
                GEN.verify_dataset(dest, "../insurance")

    def test_parser_rejects_noncanonical_dates_flags_headers_and_currency_values(self):
        with tempfile.TemporaryDirectory(prefix="microhack-data-parser-") as folder:
            path = Path(folder) / "rows.csv"
            for kind, good, bad_values in (
                ("date", "2024-02-29", ("2024-02-30", "20240229", "2024-2-29", "")),
                ("boolean", "1", ("2", "true", "-1", "01")),
                ("int64", "123", ("1.23", "1e2", "1,000", "null", "-1")),
                ("string", "Synthetic", ("", "x"*129)),
            ):
                name = "AmountCents" if kind == "int64" else "Value"
                table = {"columns": [{"name": name, "type": kind, "nullable": False}]}
                path.write_bytes((name+"\n"+good+"\n").encode())
                self.assertEqual(len(GEN.read_table(path, table)), 1)
                for bad in bad_values:
                    path.write_bytes((name+"\n"+bad+"\n").encode())
                    with self.subTest(kind=kind, value=bad), self.assertRaises(ValueError):
                        GEN.read_table(path, table)
                path.write_bytes(("WrongHeader\n"+good+"\n").encode())
                with self.assertRaisesRegex(ValueError, "header"):
                    GEN.read_table(path, table)
                path.write_bytes((name+"\r\n"+good+"\r\n").encode())
                with self.assertRaisesRegex(ValueError, "line endings"):
                    GEN.read_table(path, table)

    def test_hardcoded_small_financial_oracles(self):
        loans = [
            {"LoanId": "A", "DateKey": 20240229, "OutstandingCents": 50000,
             "RateUnits": 40000, "IsNonperforming": 1},
            {"LoanId": "A", "DateKey": 20250228, "OutstandingCents": 10000,
             "RateUnits": 40000, "IsNonperforming": 1},
            {"LoanId": "B", "DateKey": 20250228, "OutstandingCents": 30000,
             "RateUnits": 60000, "IsNonperforming": 0},
        ]
        result = GEN.summarize(loans, "FactLoanMonthlySnapshot")
        self.assertEqual(result["OutstandingCents"], 40000)
        self.assertEqual(result["ActiveLoans"], 2)
        self.assertEqual(result["NonperformingBalanceCents"], 10000)
        self.assertEqual(Decimal(result["NonperformingBalanceCents"])/40000, Decimal(".25"))
        self.assertEqual(Decimal(result["WeightedRateNumerator"]) /
                         result["WeightedRateDenominator"]/1000000, Decimal(".055"))
        self.assertEqual(GEN.ratio(400-500, 500), Decimal("-.2"))
        self.assertIsNone(GEN.ratio(100, 0))
        self.assertIsNone(GEN.ratio(0, 0))
        claim = [{"ClaimId": "A", "PaidCents": 6000, "RecoveryCents": 1000,
                  "ReserveMovementCents": 2000}]
        result = GEN.summarize(claim, "FactClaimTransactions")
        self.assertEqual(result["IncurredCents"], 7000)
        self.assertEqual(Decimal(result["IncurredCents"])/10000, Decimal(".70"))
        movements = [
            {"ClaimId": "B", "PaidCents": 0, "RecoveryCents": 0, "ReserveMovementCents": 9000},
            {"ClaimId": "B", "PaidCents": 3000, "RecoveryCents": 0, "ReserveMovementCents": -3000},
            {"ClaimId": "B", "PaidCents": 0, "RecoveryCents": 2000, "ReserveMovementCents": 0}]
        result = GEN.summarize(movements, "FactClaimTransactions")
        self.assertEqual((result["IncurredCents"], result["ReserveMovementCents"],
                          result["ClaimsWithActivity"]), (7000, 6000, 1))
        # 36,600 / 366: hand-computable leap-year earning fixture.
        self.assertEqual(GEN.monthly_earned(36600, 2024, 2), 2900)
        self.assertEqual(sum(GEN.monthly_earned(36600, 2024, m) for m in range(1, 13)), 36600)
        self.assertEqual(GEN.monthly_earned(36500, 2025, 2), 2800)
        self.assertEqual(GEN.monthly_earned(36601, 2024, 1), 3101)

    def test_temporal_scope_no_silent_carry_forward(self):
        available = {20240229, 20250228, 20250331}
        self.assertEqual(GEN.as_of({20240229, 20250228, 20250301}, available), 20250228)
        self.assertIsNone(GEN.as_of({20250301, 20250315}, available))
        self.assertEqual(GEN.as_of({20240229}, available), 20240229)
        feb = {date(2024, 2, n) for n in range(1, 30)}
        self.assertTrue(GEN.complete_months(feb))
        self.assertFalse(GEN.complete_months({date(2024, 2, 29)}))
        self.assertFalse(GEN.complete_months(set()))
        # The available-snapshot date is selected before any branch/risk filtering.
        t = GEN.as_of({20240229, 20250228}, available)
        only_earlier_branch = [{"DateKey": 20240229, "OutstandingCents": 50000}]
        self.assertEqual([r for r in only_earlier_branch if r["DateKey"] == t], [])


if __name__ == "__main__":
    unittest.main()
