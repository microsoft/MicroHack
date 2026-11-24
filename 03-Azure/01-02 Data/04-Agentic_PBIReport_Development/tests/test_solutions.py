import copy
import base64
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


model = load("enrich_model", ROOT / "walkthrough" / "challenge-02" / "enrich-model.py")
report = load("build_report", ROOT / "walkthrough" / "challenge-03" / "build-report.py")
loader = load("coach_loader", ROOT / "walkthrough" / "challenge-01" / "loader.py")
notebook = load("build_notebook", ROOT / "walkthrough" / "challenge-01" / "build-notebook.py")
transport = load("prepare_definition", ROOT / "walkthrough" / "prepare-definition.py")
MANIFEST = json.loads((ROOT / "datasets" / "manifest.json").read_text(encoding="utf-8"))


def seed_for(scenario):
    """Source-binding fixture only; not a service-created or TOM-parsed model."""
    tables = []
    generation = MANIFEST["scenarios"][scenario]["datasetHash"]
    for logical, physical in model.physical_tables(scenario, generation).items():
        columns = MANIFEST["scenarios"][scenario]["tables"][logical]["columns"]
        tables.append({
            "name": physical,
            "columns": [{"name": c["name"], "sourceColumn": c["name"], "dataType": {
                "int32": "int64", "int64": "int64", "date": "dateTime",
                "boolean": "boolean", "string": "string"}[c["type"]]} for c in columns],
            "partitions": [{"name": physical, "mode": "directLake", "source": {
                "type": "entity", "schemaName": "dbo", "entityName": physical,
                "expressionSource": "Source", "opaqueServiceProperty": "preserve-me",
            }}],
        })
    return {"compatibilityLevel": 1604, "model": {
        "tables": tables, "expressions": [{"name": "Source", "expression": [
            'let Source = AzureStorage.DataLake('
            '"https://onelake.dfs.fabric.microsoft.com/11111111-1111-4111-8111-111111111111/'
            '22222222-2222-4222-8222-222222222222", [HierarchicalNavigation = true]) in Source']}],
    }}


class SolutionTests(unittest.TestCase):
    def test_notebook_landing_checks_and_control_totals_are_order_independent(self):
        root = ROOT / "datasets"
        hashes = [hashlib.sha256((root / p).read_bytes()).hexdigest()
                  for p in ("generate_data.py", "manifest.json")]
        for scenario in ("banking", "insurance"):
            finance, entry, rows = loader.load_landing(root, scenario, *hashes)
            self.assertEqual(finance.controls({k: list(reversed(v)) for k, v in rows.items()}),
                             entry["controls"])
            self.assertEqual(
                {name: loader.physical_name(scenario, name, entry["datasetHash"]) for name in rows},
                model.physical_tables(scenario, entry["datasetHash"]))
        with self.assertRaisesRegex(ValueError, "checksum mismatch"):
            loader.load_landing(root, "banking", "0" * 64, hashes[1])

    def test_notebook_binding_and_definition_transport_keep_source_unchanged(self):
        document = notebook.build(
            "banking", "/lakehouse/default/Files/landing/banking/hash", ROOT / "datasets",
            "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222",
            "lh_agentic_banking")
        for cell in document["cells"]:
            compile("".join(cell["source"]), "<notebook-cell>", "exec")
        self.assertEqual(document["metadata"]["dependencies"]["lakehouse"]["default_lakehouse"],
                         "22222222-2222-4222-8222-222222222222")
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "loader.ipynb"
            original = json.dumps(document).encode()
            path.write_bytes(original)
            payload = transport.prepare("Notebook", path, "Loader")
            self.assertEqual(payload["definition"]["format"], "ipynb")
            self.assertEqual(base64.b64decode(payload["definition"]["parts"][0]["payload"]), original)

    def test_enrichment_preserves_real_binding_seed_without_mutation(self):
        for scenario in ("banking", "insurance"):
            seed = seed_for(scenario)
            before = copy.deepcopy(seed)
            enriched = model.enrich(seed, scenario, MANIFEST["scenarios"][scenario]["datasetHash"], MANIFEST)
            self.assertEqual(seed, before)
            self.assertEqual(enriched["model"]["expressions"], seed["model"]["expressions"])
            for old, new in zip(seed["model"]["tables"], enriched["model"]["tables"]):
                self.assertEqual(old["partitions"], new["partitions"])
            edges = enriched["model"]["relationships"]
            self.assertEqual(len(edges), 10 if scenario == "banking" else 11)
            self.assertTrue(all(e["fromTable"].startswith("Fact")
                                and e["toTable"].startswith("Dim")
                                and e["crossFilteringBehavior"] == "oneDirection" for e in edges))
            self.assertGreaterEqual(sum(len(t["measures"]) for t in enriched["model"]["tables"]), 6)
            financial_names = (
                {"Transaction Amount", "Fee Income", "Outstanding Loan Balance",
                 "Nonperforming Balance", "Prior-Year Loan Balance"} if scenario == "banking" else
                {"Written Premium", "Earned Premium", "Paid Claims", "Recoveries",
                 "Change in Claim Reserves", "Incurred Claims", "Earned Premium Prior Year"})
            deployed_measures = {m["name"]: m for t in enriched["model"]["tables"] for m in t["measures"]}
            for name in financial_names:
                self.assertEqual(deployed_measures[name]["formatString"],
                                 '#,0.00 "CHF";-#,0.00 "CHF";0.00 "CHF"')

    def test_rejects_wrong_generation_import_sql_and_missing_source(self):
        mutations = [
            lambda s: s["model"]["tables"][0]["partitions"][0].update(mode="import"),
            lambda s: s["model"]["tables"][0]["partitions"][0]["source"].update(entityName="wrong"),
            lambda s: s["model"].update(expressions=[{"name": "Source", "expression": "Sql.Database(x,y)"}]),
            lambda s: s["model"].update(expressions=[]),
            lambda s: s["model"]["tables"][0]["columns"].pop(),
            lambda s: s["model"]["tables"][0]["columns"][0].update(dataType="double"),
        ]
        for mutate in mutations:
            seed = seed_for("banking")
            mutate(seed)
            with self.assertRaises(ValueError):
                model.enrich(seed, "banking", MANIFEST["scenarios"]["banking"]["datasetHash"], MANIFEST)

    def test_rejects_mixed_sql_binding_even_with_unused_onelake_expression(self):
        seed = seed_for("banking")
        seed["model"]["expressions"].append({
            "name": "SqlSource", "expression": 'Sql.Database("server", "database")'})
        seed["model"]["tables"][0]["partitions"][0]["source"]["expressionSource"] = "SqlSource"
        with self.assertRaisesRegex(ValueError, "source expression shape"):
            model.enrich(seed, "banking", MANIFEST["scenarios"]["banking"]["datasetHash"], MANIFEST)
        for table in seed["model"]["tables"]:
            table["partitions"][0]["source"]["expressionSource"] = "SqlSource"
        with self.assertRaisesRegex(ValueError, "unused"):
            model.enrich(seed, "banking", MANIFEST["scenarios"]["banking"]["datasetHash"], MANIFEST)

    def test_rejects_marker_in_comment_and_accepts_only_reviewed_onelake_shape(self):
        seed = seed_for("insurance")
        seed["model"]["expressions"][0]["expression"] = (
            '// AzureStorage.DataLake\nSql.Database("server", "database")')
        with self.assertRaisesRegex(ValueError, "source expression shape"):
            model.enrich(seed, "insurance", MANIFEST["scenarios"]["insurance"]["datasetHash"], MANIFEST)

    def test_reports_have_real_model_bindings_two_populated_pages_and_no_overlap(self):
        for scenario in ("banking", "insurance"):
            with tempfile.TemporaryDirectory() as temp:
                root = Path(temp) / "new"
                output = report.build(scenario, root, "11111111-1111-4111-8111-111111111111")
                ref = json.loads((output / "definition.pbir").read_text())["datasetReference"]
                self.assertNotIn("byPath", ref)
                self.assertIn("semanticmodelid=", ref["byConnection"]["connectionString"])
                pages_root = output / "definition" / "pages"
                pages = json.loads((pages_root / "pages.json").read_text())["pageOrder"]
                self.assertEqual(len(pages), 2)
                for page_id in pages:
                    visuals = [json.loads(p.read_text()) for p in (pages_root / page_id).glob(
                        "visuals/*/visual.json")]
                    self.assertGreaterEqual(len(visuals), 10)
                    self.assertTrue(any("Synthetic data" in json.dumps(v) for v in visuals))
                    self.assertTrue(any("amounts in CHF" in json.dumps(v) for v in visuals))
                    data_visuals = [v for v in visuals if "query" in v["visual"]]
                    self.assertGreaterEqual(len(data_visuals), 6)
                    for v in data_visuals:
                        for role in v["visual"]["query"]["queryState"].values():
                            for projection in role["projections"]:
                                if "Measure" in projection["field"]:
                                    m = projection["field"]["Measure"]
                                    self.assertIn(m["Property"], model.measures(scenario))
                                    self.assertEqual(
                                        m["Expression"]["SourceRef"]["Entity"],
                                        model.measure_table(scenario, m["Property"]))
                    for i, visual in enumerate(visuals):
                        a = visual["position"]
                        self.assertLessEqual(a["x"] + a["width"], 1280)
                        self.assertLessEqual(a["y"] + a["height"], 720)
                        for other in visuals[i + 1:]:
                            b = other["position"]
                            overlap = (a["x"] < b["x"] + b["width"] and b["x"] < a["x"] + a["width"]
                                       and a["y"] < b["y"] + b["height"]
                                       and b["y"] < a["y"] + a["height"])
                            self.assertFalse(overlap, (visual["name"], other["name"]))
                with self.assertRaises(FileExistsError):
                    report.build(scenario, root)
                local_binding = (output / "definition.pbir").read_bytes()
                transport.prepare("Report", output, "Report",
                                  "33333333-3333-4333-8333-333333333333")
                self.assertEqual((output / "definition.pbir").read_bytes(), local_binding)
                with self.assertRaises(ValueError):
                    transport.prepare("Report", output, "Report")


if __name__ == "__main__":
    unittest.main()
