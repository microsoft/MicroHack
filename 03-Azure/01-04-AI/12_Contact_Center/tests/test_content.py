import json
import re
from pathlib import Path
from urllib.parse import unquote

LAB = Path(__file__).resolve().parents[1]
PACKS = LAB / "data" / "packs"
INDUSTRIES = ["telco", "energy", "bank", "insurance", "retail"]
SKIP = {".venv", "out", "dist", "node_modules", ".pytest_cache", "__pycache__"}
MARKDOWN = [p for p in LAB.rglob("*.md") if not SKIP & set(p.relative_to(LAB).parts)]
TEXT_FILES = [p for p in LAB.rglob("*") if p.is_file() and not SKIP & set(p.relative_to(LAB).parts)
              and p.suffix in {".md", ".py", ".json", ".jsonl", ".html", ".bicep", ".ps1", ".toml", ".txt"}]


def crm(pack):
    return json.loads((PACKS / pack / "crm.json").read_text(encoding="utf-8"))


def test_markdown_links_resolve_inside_the_lab():
    errors = []
    for path in MARKDOWN:
        text = re.sub(r"```.*?```", "", path.read_text(encoding="utf-8"), flags=re.DOTALL)
        for target in re.findall(r"!?\[[^\]]*\]\(([^)]+)\)", text):
            target = unquote(target.strip("<>").split("#", 1)[0])
            if not target or re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target):
                continue
            destination = (path.parent / target).resolve()
            if not destination.is_relative_to(LAB):
                errors.append(f"{path.relative_to(LAB)} escapes the lab: {target}")
            elif not destination.exists():
                errors.append(f"{path.relative_to(LAB)} broken link: {target}")
    assert not errors, "\n".join(errors)


def test_every_challenge_has_a_solution():
    for challenge in sorted((LAB / "challenges").glob("challenge-0*.md")):
        number = challenge.stem.split("-")[1]
        assert (LAB / "walkthrough" / f"challenge-{number}" / f"solution-{number}.md").is_file(), challenge.name
    assert (LAB / "walkthrough" / "finish" / "solution-finish.md").is_file()


def test_screenshot_placeholders_are_named_and_unique():
    names = []
    for path in MARKDOWN:
        text = path.read_text(encoding="utf-8")
        names += re.findall(r"Screenshot to add:\*\* `(images/[a-z0-9-]+\.png)`: \S", text)
        assert "Screenshot to add" not in text or text.count("Screenshot to add") == len(
            re.findall(r"Screenshot to add:\*\* `images/[a-z0-9-]+\.png`: \S", text)), f"Malformed placeholder in {path.name}"
    images = [m for path in MARKDOWN for m in re.findall(r"!\[[^\]]*\]\((?:\.\./)?(images/[a-z0-9-]+\.png)\)", path.read_text(encoding="utf-8"))
              if not m.startswith("images/readme-")]
    assert len(names) + len(images) >= 17, "Every planned screenshot needs a placeholder or an image"
    assert len(names + images) == len(set(names + images)), "Each screenshot needs its own file name"
    already_taken = [name for name in names if (LAB / name).is_file()]
    assert not already_taken, f"Replace these placeholders with the image: {already_taken}"


def test_no_em_dashes_anywhere():
    offenders = [f"{p.relative_to(LAB)}:{n}" for p in TEXT_FILES
                 for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1) if "\u2014" in line]
    assert not offenders, offenders


def test_every_pack_is_complete():
    for pack in INDUSTRIES:
        folder = PACKS / pack
        profile = json.loads((folder / "pack.json").read_text(encoding="utf-8"))
        prefix = profile["prefix"]
        assert sorted(p.name for p in (folder / "knowledge").glob("*.md")) == [f"KB-{prefix}-00{i}.md" for i in range(1, 9)]
        for i in range(1, 4):
            assert (folder / "calls" / f"{prefix}-CALL-0{i}.txt").is_file()
            assert (folder / "calls" / f"{prefix}-CALL-0{i}.mp3").stat().st_size > 50_000
        assert (folder / "insights" / f"{prefix}-CONTACTS.md").is_file()
        contacts = [json.loads(line) for line in (folder / "contacts.jsonl").read_text(encoding="utf-8").splitlines()]
        assert len(contacts) == 30
        assert sum(c["qa_scores"]["verification"] == 1 for c in contacts) == 2, pack
        rows = [json.loads(line) for line in (folder / "evaluation.jsonl").read_text(encoding="utf-8").splitlines()]
        assert len(rows) == 10 and all(r["query"] and r["ground_truth"] for r in rows)


def test_every_article_paragraph_has_its_label():
    for article in PACKS.glob("*/knowledge/KB-*.md"):
        labelled = [p for p in article.read_text(encoding="utf-8").split("\n\n") if p.startswith("[")]
        assert len(labelled) >= 3, article.name
        for n, paragraph in enumerate(labelled, 1):
            assert paragraph.startswith(f"[{article.stem} p{n}] "), f"{article.name} paragraph {n}"


def test_evaluation_answers_cite_articles_that_exist():
    for pack in INDUSTRIES:
        articles = {p.stem for p in (PACKS / pack / "knowledge").glob("*.md")}
        for line in (PACKS / pack / "evaluation.jsonl").read_text(encoding="utf-8").splitlines():
            for cited in re.findall(r"KB-[A-Z]{2}-\d{3}", json.loads(line)["ground_truth"]):
                assert cited in articles, (pack, cited)


def test_test_customers_in_the_challenges_exist():
    customers = {(c["account_number"], c["postcode"]) for pack in INDUSTRIES for c in crm(pack)["customers"]}
    for name in ["challenge-03.md", "challenge-05.md"]:
        text = (LAB / "challenges" / name).read_text(encoding="utf-8")
        pairs = re.findall(r"`([A-Z]{2}\d{6})`,\s*(?:postcode\s*)?`(ZZ\d \d[A-Z]{2})`", text)
        assert pairs, name
        for pair in pairs:
            assert pair in customers, (name, pair)


def test_vulnerable_test_customers_have_support_flags():
    text = (LAB / "challenges" / "challenge-05.md").read_text(encoding="utf-8")
    flagged = {c["account_number"] for pack in INDUSTRIES for c in crm(pack)["customers"] if c.get("flags")}
    accounts = re.findall(r"\| `([A-Z]{2}\d{6})`, `ZZ", text)
    assert len(accounts) == 5
    assert set(accounts) <= flagged


def test_challenge_instruction_blocks_have_no_leftover_placeholders():
    for challenge in (LAB / "challenges").glob("challenge-0*.md"):
        for block in re.findall(r"```text\n(.*?)```", challenge.read_text(encoding="utf-8"), re.S):
            assert not re.search(r"<(?!Company>)[A-Za-z]+>", block), challenge.name


def test_ai_readme_lists_this_hack():
    readme = (LAB.parent / "Readme.md").read_text(encoding="utf-8")
    assert "12_Contact_Center" in readme


def test_codespaces_config_points_at_this_lab():
    config = LAB.parents[2] / ".devcontainer" / "03-azure-01-04-ai-12-contact-center" / "devcontainer.json"
    data = json.loads(config.read_text(encoding="utf-8"))
    assert data["workspaceFolder"].endswith("03-Azure/01-04-AI/12_Contact_Center")
    assert 8000 in data["forwardPorts"]


def test_template_creates_every_container_the_lab_uses():
    template = (LAB / "infra" / "main.bicep").read_text(encoding="utf-8")
    declared = set(re.findall(r"'([a-z-]+)'", re.search(r"var containers = \[(.*?)\]", template).group(1)))
    assert {"knowledge", "insights", "calls", "evaluation", "crm-state", "crm-package", "cu-projects"} <= declared
    readme = (LAB / "labautomation" / "README.md").read_text(encoding="utf-8")
    assert all(f"`{name}`" in readme for name in declared)
