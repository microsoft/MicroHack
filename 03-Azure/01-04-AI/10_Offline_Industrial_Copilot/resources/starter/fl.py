"""Small helpers shared by every challenge: find the local Foundry Local endpoint and load models."""
import json
import os
import shutil
import subprocess
from pathlib import Path

from openai import OpenAI

def _find_data():
    """Find resources/data by walking up from this file, so the same helper works in any lab sub-folder."""
    if os.environ.get("LAB_DATA"):
        return Path(os.environ["LAB_DATA"])
    for parent in Path(__file__).resolve().parents:
        if (parent / "resources" / "data").is_dir():
            return parent / "resources" / "data"
    raise SystemExit("Could not find resources/data. Set the LAB_DATA environment variable to its path.")


DATA = _find_data()


def _foundry(*args, as_json=True):
    exe = shutil.which("foundry")
    if exe is None:
        raise SystemExit("The 'foundry' command was not found. Install Foundry Local first (challenge 1).")
    cmd = [exe, *args] + (["-o", "json"] if as_json else [])
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if out.returncode != 0:
        raise SystemExit(f"'{' '.join(cmd)}' failed:\n{out.stdout}{out.stderr}")
    return json.loads(out.stdout) if as_json else out.stdout


def base_url():
    """Return the OpenAI-compatible URL of the local service, starting the service if needed."""
    if os.environ.get("FOUNDRY_LOCAL_URL"):
        return os.environ["FOUNDRY_LOCAL_URL"].rstrip("/")
    status = _foundry("server", "status")
    if not status.get("running"):
        _foundry("server", "start", as_json=False)
        status = _foundry("server", "status")
    return status["webUrls"][0].rstrip("/") + "/v1"


def client():
    # The local service ignores the key, but the OpenAI library requires a value.
    return OpenAI(base_url=base_url(), api_key="local")


SERVED = Path(os.environ.get("FOUNDRY_SERVED_MODELS", Path.home() / ".foundry" / "served_models.json"))


def loaded_models():
    # A service started by serve_offline.py lists what it serves in a small file (the CLI cannot see that service).
    if os.environ.get("FOUNDRY_LOCAL_URL") and SERVED.exists():
        return {a: {"alias": a, "id": i, "device": "see serve_offline.py", "fileSizeMb": 0}
                for a, i in json.loads(SERVED.read_text(encoding="utf-8")).items()}
    return {m["alias"]: m for m in _foundry("model", "list", "--loaded")["models"]}


def load(alias):
    """Load a model (downloading it first if needed) and return the model id the service expects."""
    if alias not in loaded_models():
        if os.environ.get("FOUNDRY_LOCAL_URL"):
            raise SystemExit(f"'{alias}' is not served. Start serve_offline.py with this alias.")
        _foundry("model", "download", alias, as_json=False)
        _foundry("model", "load", alias, as_json=False)
    return loaded_models()[alias]["id"]
