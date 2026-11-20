"""Reviewed coach loader. Invoke run() only inside the intended Fabric Spark notebook."""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
from datetime import date


def load_landing(root, scenario, verifier_sha256, manifest_sha256):
    root = Path(root)
    if scenario not in {"banking", "insurance"}:
        raise ValueError("Select exactly banking or insurance.")
    for filename, expected in (("generate_data.py", verifier_sha256),
                               ("manifest.json", manifest_sha256)):
        if not re.fullmatch("[0-9a-f]{64}", expected):
            raise ValueError(f"Invalid pinned digest for {filename}")
        if hashlib.sha256((root / filename).read_bytes()).hexdigest() != expected:
            raise ValueError(f"Landing checksum mismatch: {filename}")
    spec = importlib.util.spec_from_file_location("finance_source", root / "generate_data.py")
    finance = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(finance)
    manifest = finance.verify_dataset(root, scenario)
    entry = manifest["scenarios"][scenario]
    rows = {name: finance.read_table(root / entry["tables"][name]["file"], entry["tables"][name])
            for name in entry["tableOrder"]}
    if finance.controls(rows) != entry["controls"]:
        raise ValueError("Landing reference controls do not match.")
    return finance, entry, rows


def physical_name(scenario, logical, generation):
    if (scenario not in {"banking", "insurance"}
            or not re.fullmatch(r"(Dim|Fact)[A-Za-z]+", logical)
            or not re.fullmatch("[0-9a-f]{64}", generation)):
        raise ValueError("Unsafe physical table identifier.")
    prefix = "bank" if scenario == "banking" else "ins"
    base = re.sub(r"(?<!^)(?=[A-Z])", "_", logical).lower()
    return f"{prefix}_{base}_g{generation}"


def run(spark, root, scenario, verifier_sha256, manifest_sha256):
    from pyspark.sql.types import (
        BooleanType, DateType, IntegerType, LongType, StringType, StructField, StructType,
    )
    finance, entry, rows = load_landing(root, scenario, verifier_sha256, manifest_sha256)
    generation = entry["datasetHash"]
    if not spark.catalog.databaseExists("dbo"):
        raise ValueError("Expected dbo in the attached schema-enabled Lakehouse; do not use a fallback.")
    kinds = {"int32": IntegerType(), "int64": LongType(), "string": StringType(),
             "date": DateType(), "boolean": BooleanType()}
    candidates = {}
    names = {}
    for name in entry["tableOrder"]:
        table = entry["tables"][name]
        schema = StructType(
            [StructField(c["name"], kinds[c["type"]], False) for c in table["columns"]]
            + [StructField(c, StringType(), False) for c in (
                "_DatasetVersion", "_DatasetHash", "_SourceFile", "_SourceRowKey")])
        values = []
        for row in rows[name]:
            business_values = [
                date.fromisoformat(row[c["name"]]) if c["type"] == "date" else
                bool(row[c["name"]]) if c["type"] == "boolean" else row[c["name"]]
                for c in table["columns"]]
            row_key = json.dumps([row[k] for k in table["primaryKey"]], separators=(",", ":"))
            values.append(tuple(business_values + [
                entry["datasetVersion"], generation, table["file"], row_key]))
        candidates[name] = spark.createDataFrame(values, schema, verifySchema=True)
        if candidates[name].count() != table["rows"]:
            raise ValueError(f"Typed candidate count mismatch: {name}")
        names[name] = "dbo." + physical_name(scenario, name, generation)

    # All source/candidate checks precede any write. A partial new generation is never bound.
    written_rows = {}
    for name in entry["tableOrder"]:
        table = entry["tables"][name]
        expected = candidates[name]
        qualified = names[name]
        if not spark.catalog.tableExists(qualified):
            expected.write.format("delta").mode("errorifexists").saveAsTable(qualified)
        actual = spark.table(qualified)
        if [(c.name, c.dataType) for c in actual.schema] != [
                (c.name, c.dataType) for c in expected.schema]:
            raise ValueError(f"Persisted Delta schema mismatch: {qualified}")
        if (actual.count() != table["rows"]
                or expected.exceptAll(actual).limit(1).count()
                or actual.exceptAll(expected).limit(1).count()):
            raise ValueError(f"Persisted Delta rows differ from verified source: {qualified}")
        records = []
        for record in actual.select([c["name"] for c in table["columns"]]).collect():
            row = record.asDict()
            for column in table["columns"]:
                if column["type"] == "date":
                    row[column["name"]] = row[column["name"]].isoformat()
                elif column["type"] == "boolean":
                    row[column["name"]] = int(row[column["name"]])
            records.append(row)
        written_rows[name] = records
        print(json.dumps({"table": qualified, "rows": len(records), "status": "verified"}))
    if finance.controls(written_rows) != entry["controls"]:
        raise ValueError("Delta read-back financial controls mismatch; generation not published.")
    marker = Path("/lakehouse/default/Files/control/generations") / generation / "complete.json"
    content = {"datasetHash": generation, "datasetVersion": entry["datasetVersion"],
               "scenario": scenario, "tables": names, "controls": entry["controls"]}
    if marker.exists():
        if json.loads(marker.read_text(encoding="utf-8")) != content:
            raise ValueError("Existing completion marker conflicts; never overwrite it.")
    else:
        marker.parent.mkdir(parents=True, exist_ok=True)
        with marker.open("x", encoding="utf-8") as file:
            json.dump(content, file, sort_keys=True)
    print(json.dumps({"status": "complete", "datasetHash": generation, "marker": str(marker)}))
    return content
