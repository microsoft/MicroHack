"""Run the existing repository structure checker without writing reports into cwd."""
import importlib.util
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = ROOT.parents[2]
checker_path = REPOSITORY / ".github" / "scripts" / "check_file_structure.py"
spec = importlib.util.spec_from_file_location("repository_structure", checker_path)
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
scan = Path("\\\\?\\" + str(ROOT)) if os.name == "nt" else ROOT
paths = [
    str(ROOT.relative_to(REPOSITORY) / path.relative_to(scan))
    for path in scan.rglob("*")
    if path.is_file() and "__pycache__" not in path.parts
]
checks = checker.ComplianceChecker(paths)
passed, summary = checks.run_all_checks()
print(summary)
sys.exit(0 if passed else 1)
