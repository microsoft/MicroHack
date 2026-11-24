"""Generate populated, deterministic coach PBIR, never deploy it."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import uuid

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    "business_measures", HERE.parent / "challenge-02" / "business_measures.py")
business = importlib.util.module_from_spec(spec)
spec.loader.exec_module(business)
BASE = "https://developer.microsoft.com/json-schemas/fabric/item/report/"


def identity(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:20]


def literal(value):
    return {"expr": {"Literal": {"Value": value}}}


def field(table, prop, measure=False):
    return {
        "field": {"Measure" if measure else "Column": {
            "Expression": {"SourceRef": {"Entity": table}}, "Property": prop}},
        "queryRef": f"{table}.{prop}", "nativeQueryRef": prop,
    }


def write_json(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(content, indent=2) + "\n", encoding="utf-8")


def build(scenario, output, model_id=None):
    root = Path(output)
    if root.exists():
        raise FileExistsError(f"Refusing to overwrite {root}")
    if model_id:
        model_id = str(uuid.UUID(model_id))
    available = business.measures(scenario)
    report = root / f"{scenario}.Report"
    definition = report / "definition"
    reference = ({"byConnection": {"connectionString": f"semanticmodelid={model_id}"}}
                 if model_id else {"byPath": {"path": f"../{scenario}.SemanticModel"}})
    write_json(report / "definition.pbir", {
        "$schema": BASE + "definitionProperties/2.0.0/schema.json", "version": "4.0",
        "datasetReference": reference,
    })
    write_json(definition / "version.json", {
        "$schema": BASE + "definition/versionMetadata/1.0.0/schema.json", "version": "2.0.0"})
    write_json(definition / "report.json", {
        "$schema": BASE + "definition/report/3.1.0/schema.json",
        "themeCollection": {},
        "settings": {"useStylableVisualContainerHeader": True},
    })
    page_ids = [identity(f"{scenario}-{n}") for n in range(2)]
    write_json(definition / "pages" / "pages.json", {
        "$schema": BASE + "definition/pagesMetadata/1.0.0/schema.json",
        "pageOrder": page_ids, "activePageName": page_ids[0],
    })

    def projection(name):
        if name not in available:
            raise ValueError(f"Unknown business measure {name}")
        return field(business.measure_table(scenario, name), name, True)

    for index, page_id in enumerate(page_ids):
        page = definition / "pages" / page_id
        title = ("Executive portfolio overview" if scenario == "banking"
                 else "Executive underwriting overview") if index == 0 else (
                     "Portfolio and channel detail" if scenario == "banking"
                     else "Product and claims detail")
        # Year filter selects all daily members, not only month ends.
        write_json(page / "page.json", {
            "$schema": BASE + "definition/page/2.1.0/schema.json",
            "name": page_id, "displayName": title, "displayOption": "FitToPage",
            "height": 720, "width": 1280,
            "filterConfig": {"filters": [{
                "name": "Filter" + identity(page_id + "-year") + "0000",
                "field": field("DimDate", "Year")["field"], "type": "Categorical",
                "filter": {"Version": 2, "From": [{"Name": "d", "Entity": "DimDate", "Type": 0}],
                           "Where": [{"Condition": {"In": {
                               "Expressions": [{"Column": {
                                   "Expression": {"SourceRef": {"Source": "d"}}, "Property": "Year"}}],
                               "Values": [[{"Literal": {"Value": "2025L"}}]],
                           }}}]},
            }]},
        })
        count = 0
        visual_scopes = {}
        restricted_sources = {}

        def visual(kind, label, x, y, width, height, roles=None, objects=None, scope="shared"):
            nonlocal count
            count += 1
            vid = identity(f"{page_id}-{label}")
            visual_scopes[vid] = scope
            content = {
                "$schema": BASE + "definition/visualContainer/2.9.0/schema.json",
                "name": vid,
                "position": {"x": x, "y": y, "z": count * 1000,
                             "height": height, "width": width, "tabOrder": count * 1000},
                "visual": {"visualType": kind,
                           "visualContainerObjects": {
                               "title": [{"properties": {"show": literal("true"),
                                                         "text": literal("'" + label + "'")}}],
                               "general": [{"properties": {"altText": literal("'" + label + "'")}}],
                               "padding": [{"properties": {p: literal("8D")
                                                           for p in ("top", "bottom", "left", "right")}}],
                           }},
            }
            if roles:
                content["visual"]["query"] = {"queryState": {
                    role: {"projections": values} for role, values in roles.items()}}
            if objects:
                content["visual"]["objects"] = objects
            write_json(page / "visuals" / vid / "visual.json", content)
            return vid

        def text(label, text_value, y, height, size):
            visual("textbox", label, 24, y, 1232, height, objects={
                "general": [{"properties": {"paragraphs": [{
                    "textRuns": [{"value": text_value, "textStyle": {
                        "fontFamily": "Segoe UI", "fontSize": f"{size}px", "color": "#142D4E"}}],
                }]}}],
            })

        text("Page heading", title, 8, 62, 24)
        product = "DimProduct" if scenario == "banking" else "DimInsuranceProduct"
        for x, table, column, label in (
            (24, "DimDate", "Year", "Year"),
            (208, "DimDate", "MonthKey", "Month"),
            (392, product, "ProductName", "Product"),
        ):
            visual("slicer", label, x, 80, 176, 88,
                   {"Values": [field(table, column)]},
                   {"data": [{"properties": {"mode": literal("'Dropdown'")}}]})
        visual("cardVisual", "Scope status", 592, 80, 664, 88,
               {"Data": [projection("Scope Status")]})
        if index == 0:
            kpis = (["Outstanding Loan Balance", "Active Loans", "Nonperforming Balance Ratio",
                     "Weighted Average Loan Rate"] if scenario == "banking" else [
                         "Earned Premium", "Incurred Claims", "Loss Ratio", "Active Policies at Month-End"])
            for n, name in enumerate(kpis):
                visual("cardVisual", name, 24 + n * 312, 184, 296, 136,
                       {"Data": [projection(name)]})
            trends = ["Outstanding Loan Balance"] if scenario == "banking" else [
                "Earned Premium", "Incurred Claims"]
            visual("lineChart", "Monthly trend", 24, 336, 792, 264, {
                "Category": [field("DimDate", "MonthKey")],
                "Y": [projection(n) for n in trends],
            })
            second = ["Transaction Amount", "Fee Income", "As-of Date"] if scenario == "banking" else [
                "Written Premium", "Claims with Activity", "As-of Date"]
            visual("cardVisual", "Activity and reporting date", 840, 336, 416, 264,
                   {"Data": [projection(n) for n in second]})
        else:
            group = ("DimBranch", "Region") if scenario == "banking" else ("DimGeography", "MarketName")
            value = "Outstanding Loan Balance" if scenario == "banking" else "Earned Premium"
            visual("clusteredBarChart", "Regional comparison", 24, 184, 292, 220, {
                "Category": [field(*group)], "Y": [projection(value)],
            }, scope="portfolio" if scenario == "banking" else "premium")
            comparison = (("DimRiskBand", "RiskBandName", "Outstanding Loan Balance", "Risk mix")
                          if scenario == "banking" else
                          ("DimDistributionChannel", "ChannelName", "Earned Premium", "Distribution"))
            second_id = visual("clusteredBarChart", comparison[3], 332, 184, 292, 220, {
                "Category": [field(comparison[0], comparison[1])],
                "Y": [projection(comparison[2])],
            }, scope="portfolio" if scenario == "banking" else "premium")
            if scenario == "banking":
                restricted_sources[second_id] = "portfolio"
            detail = (["Outstanding Loan Balance", "Nonperforming Balance Ratio", "Active Loans"]
                      if scenario == "banking" else ["Earned Premium", "Incurred Claims", "Loss Ratio"])
            visual("pivotTable", "Product detail", 648, 184, 608, 416, {
                "Rows": [field(product, "ProductName")],
                "Values": [projection(n) for n in detail],
            }, {"columnHeaders": [{"properties": {
                "autoSizeColumnWidth": literal("true"),
                "columnAdjustment": literal("'growToFit'"),
            }}]}, scope="portfolio" if scenario == "banking" else "premium")
            if scenario == "banking":
                source_id = visual("clusteredBarChart", "Channel activity - not portfolio", 24, 420, 600, 180, {
                    "Category": [field("DimChannel", "ChannelName")],
                    "Y": [projection("Transaction Amount")],
                }, scope="activity")
                restricted_sources[source_id] = "activity"
            else:
                source_id = visual("clusteredBarChart", "Claim-type paid movements", 24, 420, 600, 180, {
                    "Category": [field("DimClaimType", "ClaimTypeName")],
                    "Y": [projection("Paid Claims")],
                }, scope="claims")
                restricted_sources[source_id] = "claims"
        text("Synthetic data label",
             "Synthetic data - amounts in CHF; educational use only; not a regulatory or actuarial model.",
             616, 44, 14)
        text("Scope guidance",
             ("Stocks use latest selected month-end; channel applies to activity only."
              if scenario == "banking" else
              "Select complete months. Claim type has no premium allocation; blank is not zero."),
             664, 40, 13)
        if restricted_sources:
            page_content = json.loads((page / "page.json").read_text(encoding="utf-8"))
            page_content["visualInteractions"] = [
                {"source": source, "target": target, "type": "NoFilter"}
                for source, scope in restricted_sources.items()
                for target, target_scope in visual_scopes.items()
                if source != target and target_scope != scope
            ]
            write_json(page / "page.json", page_content)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scenario", required=True, choices=["banking", "insurance"])
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--model-id", help="Actual returned model ID; omit for local byPath source.")
    args = parser.parse_args()
    print(build(args.scenario, args.output, args.model_id))
