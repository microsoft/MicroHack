"""Enrich a real service-exported TMSL model; preserve its Direct Lake bindings."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import sys
import uuid
from urllib.parse import urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parent))
from business_measures import measures, measure_table

TABLES = {
    "banking": [
        "DimDate", "DimCustomer", "DimProduct", "DimBranch", "DimChannel", "DimRiskBand",
        "FactTransactions", "FactLoanMonthlySnapshot",
    ],
    "insurance": [
        "DimDate", "DimCustomer", "DimInsuranceProduct", "DimGeography",
        "DimDistributionChannel", "DimClaimType", "FactPremiumMonthly", "FactClaimTransactions",
    ],
}
BASES = {
    "banking": ["bank_dim_date", "bank_dim_customer", "bank_dim_product", "bank_dim_branch",
                "bank_dim_channel", "bank_dim_risk_band", "bank_fact_transactions",
                "bank_fact_loan_monthly_snapshot"],
    "insurance": ["ins_dim_date", "ins_dim_customer", "ins_dim_insurance_product", "ins_dim_geography",
                  "ins_dim_distribution_channel", "ins_dim_claim_type", "ins_fact_premium_monthly",
                  "ins_fact_claim_transactions"],
}


def physical_tables(scenario, generation):
    if not re.fullmatch("[0-9a-f]{64}", generation):
        raise ValueError("Generation must be the full lowercase SHA-256.")
    return dict(zip(TABLES[scenario], [base + "_g" + generation for base in BASES[scenario]]))


def stable_id(text):
    return str(uuid.UUID(bytes=hashlib.sha256(text.encode("utf-8")).digest()[:16]))


def validate_onelake_sources(expressions, tables):
    """Accept only the bounded source-expression forms reviewed for this coach tool."""
    by_name = {expression["name"]: expression for expression in expressions}
    referenced = {p["source"]["expressionSource"] for table in tables for p in table["partitions"]}
    if not expressions or len(by_name) != len(expressions) or referenced != set(by_name):
        raise ValueError("Missing, duplicate or unused shared source expressions.")
    call = (r'AzureStorage\.DataLake\(\s*"(?P<url>[^"]+)"\s*,\s*'
            r'\[\s*HierarchicalNavigation\s*=\s*true\s*\]\s*\)')
    patterns = (
        r"\s*" + call + r"\s*",
        r"\s*let\s+(?P<variable>[A-Za-z_][A-Za-z_0-9]*)\s*=\s*"
        + call + r"\s+in\s+(?P=variable)\s*",
    )
    roots = set()
    for name in sorted(referenced):
        expression = by_name[name]["expression"]
        text = "\n".join(expression) if isinstance(expression, list) else expression
        match = next((found for pattern in patterns
                      if (found := re.fullmatch(pattern, text))), None)
        if match is None:
            raise ValueError(f"Unreviewed source expression shape for {name}; OneLake seed required.")
        url = urlsplit(match["url"])
        parts = url.path.strip("/").split("/")
        if (url.scheme != "https" or url.netloc != "onelake.dfs.fabric.microsoft.com"
                or url.query or url.fragment or len(parts) != 2):
            raise ValueError(f"Unexpected OneLake source URI for {name}")
        roots.add(tuple(str(uuid.UUID(part)) for part in parts))
    if len(roots) != 1:
        raise ValueError("This lab requires one intended Lakehouse, not mixed OneLake sources.")


def enrich(seed, scenario, generation, manifest):
    result = copy.deepcopy(seed)
    if "model" not in result or result.get("compatibilityLevel", 0) < 1604:
        raise ValueError("Expected a complete exported model.bim with compatibilityLevel >=1604.")
    model = result["model"]
    expected = physical_tables(scenario, generation)
    contract = manifest["scenarios"][scenario]
    if contract["datasetHash"] != generation:
        raise ValueError("Generation does not match the reviewed manifest.")
    reverse = {value: key for key, value in expected.items()}
    tables = model.get("tables", [])
    if len(tables) != 8:
        raise ValueError("Seed must contain exactly the eight intended generation tables.")
    found = set()
    for table in tables:
        partitions = table.get("partitions", [])
        if len(partitions) != 1:
            raise ValueError("Exactly one service-generated Direct Lake entity partition per table required.")
        partition = partitions[0]
        source = partition.get("source", {})
        physical = source.get("entityName")
        if (partition.get("mode") != "directLake" or source.get("type") != "entity"
                or source.get("schemaName") != "dbo" or physical not in reverse):
            raise ValueError(f"Unexpected Direct Lake generation binding: {table.get('name')}")
        logical = reverse[physical]
        if logical in found:
            raise ValueError("Duplicate physical table binding.")
        found.add(logical)
        table["name"] = logical
        metadata = contract["tables"][logical]
        table["description"] = "Synthetic lab. Grain: " + metadata["grain"]
        table["measures"] = []
        columns = table.get("columns", [])
        if not columns or len({c["name"] for c in columns}) != len(columns):
            raise ValueError("Seed columns are absent or duplicated.")
        expected_columns = {c["name"]: c for c in metadata["columns"]}
        actual_columns = {c["name"] for c in columns}
        technical = {"_DatasetVersion", "_DatasetHash", "_SourceFile", "_SourceRowKey"}
        if not (set(expected_columns) <= actual_columns <= set(expected_columns) | technical):
            raise ValueError(f"Unexpected columns in service seed: {logical}")
        for column in columns:
            name = column["name"]
            if column.get("sourceColumn", name) != name:
                raise ValueError(f"Unexpected renamed source column: {logical}.{name}")
            if name in expected_columns:
                kind = expected_columns[name]["type"]
                expected_type = {"int32": "int64", "int64": "int64", "date": "dateTime",
                                 "boolean": "boolean", "string": "string"}[kind]
                if column.get("dataType") != expected_type:
                    raise ValueError(f"Unexpected service type for {logical}.{name}")
            column["description"] = (
                f"Synthetic {logical}.{name}; "
                + ("integer CHF rappen" if name.endswith("Cents") else
                   "annual rate in millionths" if name == "RateUnits" else
                   "date/key/attribute as defined in the dataset dictionary"))
            column["summarizeBy"] = "none"
            column["isHidden"] = (
                name.endswith(("Key", "Id", "Cents", "Units")) or name.startswith("_")
                or name in {"IsNonperforming", "IsActive", "IsMonthEnd"})
            if column.get("dataType") == "dateTime":
                column["formatString"] = "yyyy-MM-dd"
            if logical == "DimDate" and name == "Date":
                column["isKey"] = True
            if name == "MonthName":
                column["sortByColumn"] = "MonthNumber"
            if logical == "DimRiskBand" and name == "RiskBandName":
                column["sortByColumn"] = "RiskSort"
        if logical == "DimDate":
            table["dataCategory"] = "Time"
    if found != set(expected):
        raise ValueError("Missing intended model tables.")
    expressions = model.get("expressions", [])
    validate_onelake_sources(expressions, tables)
    model["culture"] = "en-US"
    model["discourageImplicitMeasures"] = True
    by_name = {t["name"]: t for t in tables}
    for name, (dax, fmt, description) in measures(scenario).items():
        by_name[measure_table(scenario, name)]["measures"].append({
            "name": name, "expression": dax.splitlines(), "formatString": fmt,
            "description": description, "lineageTag": stable_id(f"{scenario}-{name}"),
        })
    edges = {
        "FactTransactions": ["DimDate", "DimCustomer", "DimProduct", "DimBranch", "DimChannel"],
        "FactLoanMonthlySnapshot": ["DimDate", "DimCustomer", "DimProduct", "DimBranch", "DimRiskBand"],
    } if scenario == "banking" else {
        "FactPremiumMonthly": ["DimDate", "DimCustomer", "DimInsuranceProduct",
                               "DimGeography", "DimDistributionChannel"],
        "FactClaimTransactions": ["DimDate", "DimCustomer", "DimInsuranceProduct",
                                  "DimGeography", "DimDistributionChannel", "DimClaimType"],
    }
    key_map = {"DimInsuranceProduct": "ProductKey", "DimDistributionChannel": "ChannelKey"}
    model["relationships"] = []
    for fact, dimensions in edges.items():
        for dimension in dimensions:
            key = key_map.get(dimension, dimension.removeprefix("Dim") + "Key")
            for table in (fact, dimension):
                if key not in {c["name"] for c in by_name[table]["columns"]}:
                    raise ValueError(f"Missing relationship column {table}.{key}")
            model["relationships"].append({
                "name": stable_id(f"{scenario}-{fact}-{dimension}"),
                "fromTable": fact, "fromColumn": key, "fromCardinality": "many",
                "toTable": dimension, "toColumn": key, "toCardinality": "one",
                "crossFilteringBehavior": "oneDirection", "isActive": True,
            })
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scenario", required=True, choices=list(TABLES))
    parser.add_argument("--seed-model", type=Path, required=True)
    parser.add_argument("--generation", required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error("Output exists; use a new reviewed revision, never overwrite blindly.")
    transformed = enrich(json.loads(args.seed_model.read_text(encoding="utf-8")),
                         args.scenario, args.generation,
                         json.loads(args.manifest.read_text(encoding="utf-8")))
    args.output.mkdir(parents=True)
    (args.output / "model.bim").write_text(json.dumps(transformed, indent=2) + "\n", encoding="utf-8")
    (args.output / "definition.pbism").write_text(json.dumps({
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/semanticModel/definitionProperties/1.0.0/schema.json",
        "version": "5.0", "settings": {},
    }, indent=2) + "\n", encoding="utf-8")
