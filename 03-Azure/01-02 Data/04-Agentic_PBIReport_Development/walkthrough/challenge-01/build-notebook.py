"""Create a notebook definition locally with private actual Lakehouse bindings."""
import argparse
import hashlib
import json
from pathlib import Path
import uuid


def build(scenario, landing, datasets, workspace_id, lakehouse_id, lakehouse_name):
    workspace_id = str(uuid.UUID(workspace_id))
    lakehouse_id = str(uuid.UUID(lakehouse_id))
    datasets = Path(datasets)
    verifier_hash = hashlib.sha256((datasets / "generate_data.py").read_bytes()).hexdigest()
    manifest_hash = hashlib.sha256((datasets / "manifest.json").read_bytes()).hexdigest()
    parameters = (
        f"SCENARIO = {scenario!r}\nLANDING_ROOT = {landing!r}\n"
        f"VERIFIER_SHA256 = {verifier_hash!r}\nMANIFEST_SHA256 = {manifest_hash!r}\n")
    source = (Path(__file__).parent / "loader.py").read_text(encoding="utf-8")
    cells = []
    for index, code in enumerate((parameters, source,
                                  "result = run(spark, LANDING_ROOT, SCENARIO, "
                                  "VERIFIER_SHA256, MANIFEST_SHA256)\n")):
        cells.append({"cell_type": "code", "execution_count": None,
                      "metadata": {"tags": ["parameters"]} if index == 0 else {},
                      "outputs": [], "source": code.splitlines(keepends=True)})
    return {
        "nbformat": 4, "nbformat_minor": 5, "cells": cells,
        "metadata": {
            "kernelspec": {"display_name": "Synapse PySpark", "language": "python",
                           "name": "synapse_pyspark"},
            "language_info": {"name": "python"},
            "dependencies": {"lakehouse": {
                "default_lakehouse": lakehouse_id, "default_lakehouse_name": lakehouse_name,
                "default_lakehouse_workspace_id": workspace_id,
                "known_lakehouses": [{"id": lakehouse_id}],
            }},
        },
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scenario", required=True, choices=["banking", "insurance"])
    parser.add_argument("--landing", required=True)
    parser.add_argument("--datasets", required=True, type=Path)
    parser.add_argument("--workspace-id", required=True)
    parser.add_argument("--lakehouse-id", required=True)
    parser.add_argument("--lakehouse-name", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    notebook = build(args.scenario, args.landing, args.datasets, args.workspace_id,
                     args.lakehouse_id, args.lakehouse_name)
    with args.output.open("x", encoding="utf-8") as file:
        json.dump(notebook, file, indent=2)
        file.write("\n")
