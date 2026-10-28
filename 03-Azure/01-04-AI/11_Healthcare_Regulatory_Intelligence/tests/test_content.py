import json
import os
import re
import tomllib
from pathlib import Path
from urllib.parse import unquote

LAB = Path(__file__).resolve().parents[1]
MARKDOWN = [p for p in LAB.rglob("*.md") if not {".venv", "out", "node_modules", ".pytest_cache"} & set(p.relative_to(LAB).parts)]


def exact_exists(path: Path) -> bool:
    absolute = Path(os.path.abspath(path))
    if not absolute.exists():
        return False
    current = Path(absolute.anchor)
    for part in absolute.parts[1:]:
        if part not in {child.name for child in current.iterdir()}:
            return False
        current /= part
    return True


def test_markdown_links_resolve_inside_the_lab():
    errors = []
    for path in MARKDOWN:
        text = path.read_text(encoding="utf-8")
        assert not re.search(r"^(<<<<<<< |=======\s*$|>>>>>>> )", text, re.MULTILINE), path
        for target in re.findall(r"!?\[[^\]]*\]\(([^)]+)\)", re.sub(r"```.*?```", "", text, flags=re.DOTALL)):
            target = unquote(target.strip("<>").split("#", 1)[0])
            if not target or re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target):
                continue
            destination = (path.parent / target).resolve()
            if not destination.is_relative_to(LAB):
                errors.append(f"{path.relative_to(LAB)} escapes the lab: {target}")
            elif not exact_exists(destination):
                errors.append(f"{path.relative_to(LAB)} broken link: {target}")
    assert not errors, "\n".join(errors)


def test_screenshot_placeholders_are_named_and_unique():
    placeholders, images = [], []
    for path in MARKDOWN:
        text = path.read_text(encoding="utf-8")
        placeholders += re.findall(r"Screenshot to add:\*\* `(images/[a-z0-9-]+\.png)`", text)
        images += [m.lstrip("./") for m in re.findall(r"!\[[^\]]*\]\(((?:\.\./)?images/[a-z0-9-]+\.png)\)", text)]
    names = placeholders + images
    assert len(names) >= 27, "Every planned screenshot needs a placeholder or an image"
    assert len(names) == len(set(names)), "Each screenshot needs its own file name"
    already_taken = [name for name in placeholders if (LAB / name).is_file()]
    assert not already_taken, f"Replace these placeholders with the image: {already_taken}"


def test_only_the_simple_cast_remains():
    banned = re.compile(r"\b(Aster|Juniper|Linden|Moorland|Cedar|Northstar|Maya|Jordan|healthcare_intelligence|Cosmos)\b", re.I)
    offenders = [str(p.relative_to(LAB)) for p in LAB.rglob("*")
                 if p.is_file() and p.suffix in {".md", ".py", ".json", ".html", ".bicep", ".ps1", ".yaml", ".yml"}
                 and not {".venv", "out"} & set(p.relative_to(LAB).parts) and p.name != "test_content.py"
                 and banned.search(p.read_text(encoding="utf-8"))]
    assert not offenders, offenders


def test_readme_covers_every_part_of_the_case_overview():
    readme = (LAB / "README.md").read_text(encoding="utf-8")
    for phrase in [
        "Regulatory Web & Change Monitor", "Document & Citation Agent", "Obligation & Impact Extractor",
        "Regulatory Q&A Assistant", "Executive Briefing", "regulations", "guidance", "safety alerts",
        "enforcement letters", "coverage decisions", "pricing rules", "effective dates", "geographies",
        "clinical", "labelling", "manufacturing", "vigilance", "market access", "products", "studies",
        "submissions", "standard operating procedures", "quality records", "histories", "owners",
        "drafts emails", "change requests", "label updates", "by region and portfolio", "deadlines",
        "progress tracking", "approval", "audit", "events", "de-duplicate", "normalise", "metadata enrichment",
        "citation anchoring", "Regulatory affairs", "quality leadership", "pharmacovigilance", "post-market surveillance",
    ]:
        assert phrase.lower() in readme.lower(), phrase


def test_no_em_dashes_anywhere():
    offenders = [f"{p.relative_to(LAB)}:{n}" for p in LAB.rglob("*")
                 if p.is_file() and p.suffix in {".md", ".py", ".json", ".html", ".bicep", ".ps1", ".yaml", ".yml", ".toml", ".txt"}
                 and not {".venv", "out"} & set(p.relative_to(LAB).parts)
                 for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1) if "\u2014" in line]
    assert not offenders, offenders


def test_platform_automation_layout():
    assert {p.name for p in (LAB / "labautomation").iterdir()} == {"deploy-lab.ps1", "lab-defaults.json", "README.md"}
    defaults = json.loads((LAB / "labautomation" / "lab-defaults.json").read_text(encoding="utf-8"))
    assert defaults["deploymentType"] in {"resourcegroup", "subscription", "resourcegroup-with-subscriptionowner"}
    assert defaults["$schema"].endswith("/lab-defaults-schema.json")


def test_containers_and_dependencies_are_reproducible():
    project = tomllib.loads((LAB / "pyproject.toml").read_text(encoding="utf-8"))
    assert project["project"]["dependencies"] == []
    assert project["tool"]["uv"]["index"][0]["url"] == "https://packagefeedproxy.microsoft.io/pypi/simple/"
    pins = (LAB / "orchestrator" / "requirements.txt").read_text(encoding="utf-8").split()
    assert pins == project["project"]["optional-dependencies"]["orchestrator"]
    local = json.loads((LAB / ".devcontainer" / "devcontainer.json").read_text(encoding="utf-8"))
    assert "target=/workspaces/regulatory-intelligence," in local["workspaceMount"]
    # Codespaces only reads configurations under the repository root .devcontainer folder.
    # It is absent when only this lab folder is mounted into the local devcontainer.
    codespaces = LAB.parents[2] / ".devcontainer" / "03-azure-01-04-ai-11-healthcare-regulatory-intelligence" / "devcontainer.json"
    if codespaces.is_file():
        repository = json.loads(codespaces.read_text(encoding="utf-8"))
        assert repository["workspaceFolder"].endswith("/03-Azure/01-04-AI/11_Healthcare_Regulatory_Intelligence")
        assert (codespaces.parent / repository["build"]["dockerfile"]).resolve() == (LAB / ".devcontainer" / "Dockerfile").resolve()
        for key in ("features", "postCreateCommand", "waitFor", "forwardPorts", "portsAttributes", "customizations", "remoteUser"):
            assert repository[key] == local[key], key
    assert local["postCreateCommand"] == "uv sync --frozen --all-extras && uv run --frozen --all-extras pytest -q"
    assert all(port["visibility"] == "private" for port in local["portsAttributes"].values())
    assert "out/" in (LAB / ".gitignore").read_text(encoding="utf-8").splitlines()


def test_template_role_ids_are_real_built_in_roles():
    # Deployment validation does not check role IDs; a typo only fails at deployment time.
    known = {
        "ba92f5b4-2d11-453d-a403-e96b0029c9fe": "Storage Blob Data Contributor",
        "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1": "Storage Blob Data Reader",
        "8ebe5a00-799e-43f5-93ac-243d3dce84a7": "Search Index Data Contributor",
        "1407120a-92aa-4202-b7e9-c0e197c71c8f": "Search Index Data Reader",
        "7ca78c08-252a-4471-8644-bb5ff32d4ba0": "Search Service Contributor",
        "53ca6127-db72-4b80-b1b0-d745d6d5456d": "Foundry User",
        "eadc314b-1a2d-4efa-be10-5d325db5065e": "Foundry Project Manager",
        "5e0bd9bd-7b93-4f28-af87-19fc36ad61bd": "Cognitive Services OpenAI User",
    }
    template = (LAB / "infra" / "main.bicep").read_text(encoding="utf-8")
    used = set(re.findall(r"'([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'", template))
    assert used == set(known), sorted(used ^ set(known))
