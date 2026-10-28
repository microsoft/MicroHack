"""Offline notebook regressions; no Fabric credentials or Spark required."""

import ast
import json
from pathlib import Path
import sqlite3
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch


ROOT = Path(__file__).resolve().parents[1]
NOTEBOOK = json.loads((ROOT / "setup" / "Setup-InventoryDataAgent.ipynb").read_text(encoding="utf-8"))
CELLS = {cell["id"]: "".join(cell["source"]) for cell in NOTEBOOK["cells"]}
SETUP = ast.parse(CELLS["88b3cac5"])


def setup_namespace():
    names = {"AGENT_INSTRUCTIONS", "DATA_SOURCE_INSTRUCTIONS", "EXAMPLE_QUERIES", "EXPECTED_TABLES"}
    nodes = [
        node for node in SETUP.body
        if isinstance(node, ast.FunctionDef)
        or isinstance(node, ast.Assign)
        and any(isinstance(target, ast.Name) and target.id in names for target in node.targets)
    ]
    namespace = {}
    exec(compile(ast.Module(body=nodes, type_ignores=[]), "<setup-definitions>", "exec"), namespace)
    return namespace


class DataSource:
    def __init__(self, tables):
        self.tables = tables
        self.selected = set()
        self.instructions = None
        self.examples = {}

    def get_elements(self, root_id=None, **kwargs):
        if root_id is None:
            return {"value": [{"id": "schemas", "type": "Schemas", "hasSubElements": True}]}
        if root_id == "schemas":
            return {"value": [{"id": "dbo", "type": "Schema", "hasSubElements": True}]}
        return {"value": [
            {"id": name, "displayName": name, "type": "Table", "hasSubElements": False}
            for name in self.tables
        ]}

    def update_element(self, element_id, is_selected):
        if not is_selected:
            raise AssertionError("Expected selected table")
        self.selected.add(element_id)

    def update_configuration(self, instructions):
        self.instructions = instructions

    def get_fewshots(self):
        records = [
            {"id": question, "question": question, "query": query}
            for question, query in self.examples.items()
        ]
        return SimpleNamespace(to_dict=lambda orient: records)

    def add_fewshot(self, question, query):
        if question in self.examples:
            raise AssertionError("Duplicate example")
        self.examples[question] = query

    def update_fewshot(self, fewshot_id, query):
        self.examples[fewshot_id] = query


class Agent:
    def __init__(self, sources):
        self.sources = sources
        self.reads = 0
        self.published = False

    def update_settings(self, **kwargs):
        self.settings = kwargs

    def add_staging_datasource(self, **kwargs):
        self.datasource_settings = kwargs

    def list_datasources(self):
        source = self.sources[min(self.reads, len(self.sources) - 1)]
        self.reads += 1
        return [source]

    def publish_staging(self, **kwargs):
        self.published = True


def response(body, status=200, headers=None):
    return SimpleNamespace(
        json=lambda: body, status_code=status, headers=headers or {},
        raise_for_status=lambda: None, text=json.dumps(body),
    )


def metadata_namespace():
    namespace = setup_namespace()
    namespace.update(
        time=SimpleNamespace(sleep=lambda seconds: None),
        notebookutils=SimpleNamespace(credentials=SimpleNamespace(getToken=lambda audience: "test-token")),
    )
    tables = [{"tableName": name, "status": "Success"} for name in namespace["EXPECTED_TABLES"]]
    namespace["requests"] = Mock(
        get=Mock(return_value=response({"properties": {"sqlEndpointProperties": {"id": "endpoint"}}})),
        post=Mock(return_value=response({"value": tables})),
    )
    return namespace


def configure(agent, namespace=None):
    namespace = namespace if namespace is not None else metadata_namespace()
    namespace.update(agent=agent, lakehouse_id="lakehouse", workspace_id="workspace")
    start = next(
        index for index, node in enumerate(SETUP.body)
        if isinstance(node, ast.Expr) and isinstance(node.value, ast.Call)
        and isinstance(node.value.func, ast.Attribute) and node.value.func.attr == "update_settings"
    )
    exec(compile(ast.Module(body=SETUP.body[start:], type_ignores=[]), "<configure>", "exec"), namespace)


class NotebookTests(unittest.TestCase):
    def test_installer_uses_current_python_and_propagates_failures(self):
        import subprocess
        import sys
        with patch("subprocess.run") as install:
            exec(CELLS["1b595b90"], {})
        command = install.call_args.args[0]
        self.assertEqual(command[:4], [sys.executable, "-m", "pip", "install"])
        self.assertIn("fabric-data-agent-sdk==0.1.33a0", command)
        self.assertEqual(install.call_args.kwargs, {"check": True, "timeout": 300})
        with patch("subprocess.run", side_effect=subprocess.CalledProcessError(1, command)):
            with self.assertRaises(subprocess.CalledProcessError):
                exec(CELLS["1b595b90"], {})

    def test_metadata_refresh_is_non_destructive_and_precedes_datasource_creation(self):
        namespace = metadata_namespace()
        agent = Agent([DataSource(sorted(namespace["EXPECTED_TABLES"]))])
        agent.add_staging_datasource = Mock(
            side_effect=lambda **kwargs: self.assertTrue(namespace["requests"].post.called)
        )
        configure(agent, namespace)
        call = namespace["requests"].post.call_args
        self.assertTrue(call.args[0].endswith("/sqlEndpoints/endpoint/refreshMetadata"))
        self.assertEqual(call.kwargs["json"], {"recreateTables": False})
        self.assertTrue(agent.published)

    def test_failed_or_missing_sql_table_prevents_publication(self):
        for tables in ([], [{"tableName": "products", "status": "Failure"}]):
            namespace = metadata_namespace()
            namespace["requests"].post.return_value = response({"value": tables})
            agent = Agent([DataSource(sorted(namespace["EXPECTED_TABLES"]))])
            with self.assertRaisesRegex(RuntimeError, "SQL metadata is incomplete"):
                configure(agent, namespace)
            self.assertFalse(agent.published)
            self.assertFalse(hasattr(agent, "datasource_settings"))

    def test_metadata_refresh_accepts_previously_synced_and_schema_qualified_tables(self):
        for prefix in ("", "dbo."):
            namespace = metadata_namespace()
            namespace["requests"].post.return_value = response({"value": [
                {"tableName": prefix + name, "status": "NotRun", "lastSuccessfulSyncDateTime": "2026-10-18T01:21:25Z"}
                for name in namespace["EXPECTED_TABLES"]
            ]})
            namespace["refresh_sql_metadata"]("workspace", "lakehouse")

    def test_metadata_refresh_long_running_operation(self):
        namespace = metadata_namespace()
        completed = namespace["requests"].post.return_value
        namespace["requests"].post.return_value = response(
            {}, 202, {"Location": "https://api.fabric.microsoft.com/v1/operations/operation"}
        )
        namespace["requests"].get.side_effect = [
            namespace["requests"].get.return_value,
            response({"status": "Running"}), response({"status": "Succeeded"}), completed,
        ]
        namespace["refresh_sql_metadata"]("workspace", "lakehouse")
        self.assertTrue(namespace["requests"].get.call_args.args[0].endswith("/operation/result"))

    def test_metadata_refresh_surfaces_operation_failure_and_timeout(self):
        for status, message in (("Failed", "refresh failed"), ("Running", "five minutes")):
            namespace = metadata_namespace()
            namespace["requests"].post.return_value = response({}, 202, {"Location": "operation"})
            namespace["requests"].get.side_effect = [
                namespace["requests"].get.return_value,
                *[response({"status": status}) for _ in range(60)],
            ]
            with self.assertRaisesRegex(RuntimeError, message):
                namespace["refresh_sql_metadata"]("workspace", "lakehouse")

    def test_code_cells_compile(self):
        for cell in NOTEBOOK["cells"]:
            if cell["cell_type"] == "code":
                source = "".join(cell["source"])
                source = "\n".join(line for line in source.splitlines() if not line.startswith("%"))
                compile(source, f"<cell {cell['id']}>", "exec", flags=ast.PyCF_ALLOW_TOP_LEVEL_AWAIT)

    def test_seed_and_case_sensitive_example_results(self):
        namespace = {}
        exec(CELLS["c1783b44"], namespace)
        exec(CELLS["babc0dba"], namespace)
        self.assertEqual(len(namespace["inventory"]), 72)
        self.assertEqual(len(namespace["demand"]), 288)
        self.assertEqual({row["type"] for row in namespace["stores"]}, {"retail", "warehouse"})
        connection = sqlite3.connect(":memory:")
        self.addCleanup(connection.close)
        connection.execute("ATTACH DATABASE ':memory:' AS dbo")
        for name, rows in (("Stores", namespace["stores"]), ("Products", namespace["products"]),
                           ("Inventory", namespace["inventory"])):
            columns = list(rows[0])
            definitions = ", ".join(
                f"[{key}] {'INTEGER' if isinstance(rows[0][key], int) else 'TEXT COLLATE BINARY'}"
                for key in columns
            )
            connection.execute(f"CREATE TABLE dbo.{name} ({definitions})")
            connection.executemany(
                f"INSERT INTO dbo.{name} VALUES ({','.join('?' for _ in columns)})",
                [tuple(row[key] for key in columns) for row in rows],
            )
        results = [connection.execute(sql).fetchall() for sql in setup_namespace()["EXAMPLE_QUERIES"].values()]
        self.assertEqual(results[0], [(4,)])
        self.assertEqual(results[1], [
            ("P004", "ST03", "Portland", 8, 30, "CRITICAL"),
            ("P004", "ST04", "Seattle", 6, 30, "CRITICAL"),
        ])
        self.assertEqual(results[2], [(232,)])
        self.assertEqual(results[3], [])
        self.assertEqual(connection.execute("SELECT COUNT(*) FROM dbo.Stores WHERE type = 'Retail'").fetchone(), (0,))

    def test_publishes_only_after_all_named_tables_and_grounding(self):
        expected = setup_namespace()["EXPECTED_TABLES"]
        partial = DataSource(sorted(expected)[:6])
        complete = DataSource(sorted(expected))
        agent = Agent([partial, complete])
        configure(agent)
        self.assertEqual(agent.reads, 2)
        self.assertTrue(agent.published)
        self.assertIn("Stores.type is 'retail' or 'warehouse'", complete.instructions)
        self.assertEqual(len(complete.examples), 4)
        configure(agent)
        self.assertEqual(len(complete.examples), 4)

    def test_extra_table_does_not_hide_missing_expected_table(self):
        expected = sorted(setup_namespace()["EXPECTED_TABLES"])
        agent = Agent([DataSource(expected[:6] + ["unrelated"])])
        with self.assertRaisesRegex(RuntimeError, "Missing tables"):
            configure(agent)
        self.assertFalse(agent.published)

    def test_zero_tables_never_publish(self):
        agent = Agent([DataSource([])])
        with self.assertRaisesRegex(RuntimeError, "Missing tables"):
            configure(agent)
        self.assertFalse(agent.published)

    def test_configuration_failure_never_publishes(self):
        class BrokenSource(DataSource):
            def update_configuration(self, instructions):
                raise RuntimeError("configuration denied")
        agent = Agent([BrokenSource(sorted(setup_namespace()["EXPECTED_TABLES"]))])
        with self.assertRaisesRegex(RuntimeError, "configuration denied"):
            configure(agent)
        self.assertFalse(agent.published)

    def test_schema_access_failure_is_not_hidden_as_sync_delay(self):
        class BrokenSource(DataSource):
            def get_elements(self, **kwargs):
                raise PermissionError("schema access denied")
        agent = Agent([BrokenSource([])])
        with self.assertRaisesRegex(PermissionError, "schema access denied"):
            configure(agent)
        self.assertFalse(agent.published)

    def test_manual_and_notebook_grounding_match(self):
        text = (ROOT / "challenges" / "challenge-01.md").read_text(encoding="utf-8")
        block = text.split("Use exact stored values in case-sensitive filters.", 1)[1].split("```", 1)[0]
        manual = "Use exact stored values in case-sensitive filters." + block
        expected = setup_namespace()["DATA_SOURCE_INSTRUCTIONS"]
        self.assertEqual(" ".join(manual.split()), " ".join(expected.split()))

    def test_local_markdown_file_links_resolve(self):
        import re
        from urllib.parse import unquote
        for path in ROOT.rglob("*.md"):
            if ".github" in path.parts:
                continue
            for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", path.read_text(encoding="utf-8")):
                if target.startswith(("https:", "http:", "#", "mailto:")):
                    continue
                target = unquote(target.split("#", 1)[0].strip("<>"))
                self.assertTrue((path.parent / target).exists(), f"{path}: broken link {target}")


if __name__ == "__main__":
    unittest.main()
