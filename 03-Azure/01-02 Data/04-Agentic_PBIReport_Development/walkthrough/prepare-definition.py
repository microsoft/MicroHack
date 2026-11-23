"""Prepare a Fabric item-definition payload locally. This script makes no HTTP calls."""
import argparse
import base64
import json
from pathlib import Path
import uuid


def prepare(kind, source, display_name, model_id=None):
    source = Path(source)
    if kind == "Notebook":
        if source.suffix != ".ipynb" or not source.is_file():
            raise ValueError("Notebook source must be a reviewed .ipynb file.")
        files = [("notebook-content.ipynb", source.read_bytes())]
    else:
        if not source.is_dir():
            raise ValueError("Source must be the item root directory.")
        paths = ([source / "definition.pbism", source / "model.bim"] if kind == "SemanticModel"
                 else [source / "definition.pbir"] + sorted((source / "definition").rglob("*.json"))
                 + sorted(p for p in (source / "StaticResources").rglob("*") if p.is_file()))
        if any(not p.is_file() for p in paths):
            raise ValueError("Missing required definition part or invalid resource path.")
        if any(not p.resolve().is_relative_to(source.resolve()) for p in paths):
            raise ValueError("Definition parts must stay inside the reviewed source directory.")
        files = [(p.relative_to(source).as_posix(), p.read_bytes()) for p in paths]
        if kind == "Report":
            if model_id is None:
                raise ValueError("Report service transport requires the actual semantic model ID.")
            model_id = str(uuid.UUID(model_id))
            root = json.loads(files[0][1])
            root["datasetReference"] = {
                "byConnection": {"connectionString": f"semanticmodelid={model_id}"}}
            files[0] = ("definition.pbir", json.dumps(root).encode("utf-8"))
            if len(files) < 6:
                raise ValueError("Empty/scaffold-only report definition rejected.")
    parts = [{"path": name, "payload": base64.b64encode(content).decode("ascii"),
              "payloadType": "InlineBase64"} for name, content in files]
    definition = {"parts": parts}
    if kind == "Notebook":
        definition["format"] = "ipynb"
    return {"displayName": display_name, "definition": definition}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kind", choices=["Notebook", "SemanticModel", "Report"], required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--display-name", required=True)
    parser.add_argument("--model-id")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    payload = prepare(args.kind, args.source, args.display_name, args.model_id)
    with args.output.open("x", encoding="utf-8") as file:
        json.dump(payload, file, indent=2)
        file.write("\n")
