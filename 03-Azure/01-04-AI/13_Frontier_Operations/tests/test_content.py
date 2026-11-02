import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote

LAB = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(LAB))
PACKS = LAB / "data" / "packs"
SKIP = {".venv", "my-files", ".pytest_cache", "__pycache__"}
MARKDOWN = [p for p in LAB.rglob("*.md") if not SKIP & set(p.relative_to(LAB).parts)]
TEXT_FILES = [p for p in LAB.rglob("*") if p.is_file() and not SKIP & set(p.relative_to(LAB).parts)
              and p.suffix in {".md", ".py", ".json", ".jsonl", ".html", ".bicep", ".ps1", ".csv", ".txt"}]


def profiles():
    return {p.name: json.loads((p / "pack.json").read_text(encoding="utf-8")) for p in sorted(PACKS.iterdir())}


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


def test_every_challenge_in_the_readme_exists_and_has_a_solution():
    readme = (LAB / "README.md").read_text(encoding="utf-8")
    linked = re.findall(r"\(challenges/((?:challenge-0\d|finish)\.md)\)", readme)
    assert linked == [f"challenge-0{i}.md" for i in range(1, 8)] + ["finish.md", "challenge-08.md"]
    for name in linked:
        stem = Path(name).stem
        solution = "finish/solution-finish.md" if stem == "finish" else f"{stem}/solution-{stem.split('-')[1]}.md"
        assert (LAB / "walkthrough" / solution).is_file(), solution
        assert f"walkthrough/{solution}" in (LAB / "challenges" / name).read_text(encoding="utf-8")


def test_screenshot_placeholders_are_named_and_unique():
    names = []
    for path in MARKDOWN:
        text = path.read_text(encoding="utf-8")
        found = re.findall(r"Screenshot to add:\*\* `(images/[a-z0-9-]+\.png)`: \S", text)
        assert text.count("Screenshot to add") == len(found), f"Malformed placeholder in {path.name}"
        names += found
    images = [m for path in MARKDOWN for m in re.findall(r"!\[[^\]]*\]\((?:\.\./)?(images/[a-z0-9-]+\.png)\)",
                                                         path.read_text(encoding="utf-8"))
              if not m.startswith("images/readme-")]
    assert len(names) + len(images) >= 20, "Every planned screenshot needs a placeholder or an image"
    assert len(names + images) == len(set(names + images)), "Each screenshot needs its own file name"
    already_taken = [name for name in names if (LAB / name).is_file()]
    assert not already_taken, f"Replace these placeholders with the image: {already_taken}"


def test_no_em_dashes_anywhere():
    offenders = [f"{p.relative_to(LAB)}:{n}" for p in TEXT_FILES
                 for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1) if "\u2014" in line]
    assert not offenders, offenders


def test_expected_results_are_generated_from_the_answer_keys():
    sys.path.insert(0, str(LAB / "walkthrough"))
    import make_expected
    current = (LAB / "walkthrough" / "expected-results.md").read_text(encoding="utf-8")
    assert current == make_expected.render(), "Run python walkthrough/make_expected.py"


def test_approver_table_matches_the_packs():
    text = (LAB / "challenges" / "challenge-05.md").read_text(encoding="utf-8")
    rows = dict(re.findall(r"^\| ([A-Z][^|]+?) \| ([^|]+?) \|$", text, re.M))
    for profile in profiles().values():
        assert rows.get(profile["company"]) == profile["people"]["approver"], profile["company"]


def test_hidden_instruction_table_matches_the_statements():
    text = (LAB / "challenges" / "challenge-06.md").read_text(encoding="utf-8")
    rows = dict(re.findall(r"^\| ([A-Z][^|]+?) \| ([^|]+?) \|$", text, re.M))
    for pack, profile in profiles().items():
        names = {p["id"]: p["name"] for p in profile["partners"]}
        injected = [names[s.stem] for s in (PACKS / pack / "statements").glob("*.csv")
                    if "ignore all previous" in s.read_text(encoding="utf-8").lower()]
        assert injected == [rows.get(profile["company"])], profile["company"]


def test_challenge_one_lists_every_pack():
    text = (LAB / "challenges" / "challenge-01.md").read_text(encoding="utf-8")
    for pack, profile in profiles().items():
        assert f"| `{pack}` | {profile['company']} |" in text


def test_commands_in_the_challenges_exist_in_the_setup_tool():
    import frontierops.__main__ as tool
    commands = set()
    for path in (LAB / "challenges").glob("*.md"):
        commands |= set(re.findall(r"python3 -m frontierops(?: --account \S+)? ([a-z][a-z-]*)", path.read_text(encoding="utf-8")))
    assert commands <= {"setup", "grant-agent", "publish-skill", "get-skill", "copy-agent", "download", "score"}
    for command in commands:
        assert command in tool.__doc__


def test_the_stretch_skill_name_is_used_consistently():
    text = (LAB / "challenges" / "challenge-08.md").read_text(encoding="utf-8")
    assert "skills/reconciliation-code" in text and "name: reconciliation-code" in text
    assert text.count("reconciliation-code") >= 8


def test_ai_readme_lists_this_hack():
    readme = (LAB.parent / "Readme.md").read_text(encoding="utf-8")
    assert "(13_Frontier_Operations/README.md)" in readme


def test_codespaces_config_points_at_this_lab_and_has_azd():
    config = LAB.parents[2] / ".devcontainer" / "03-azure-01-04-ai-13-frontier-operations" / "devcontainer.json"
    data = json.loads(config.read_text(encoding="utf-8"))
    assert data["workspaceFolder"].endswith("03-Azure/01-04-AI/13_Frontier_Operations")
    assert any("azd" in feature for feature in data["features"])
    assert data["containerEnv"]["AZD_ALPHA_ENABLE_AGENTS_MANAGED_HARNESS"] == "true"
    assert "Frontier Operations" in data["name"]
    assert data["name"] in (LAB / "challenges" / "challenge-08.md").read_text(encoding="utf-8")


def test_lab_readme_documents_every_container_and_output():
    template = (LAB / "infra" / "main.bicep").read_text(encoding="utf-8")
    declared = set(re.findall(r"'([a-z-]+)'", re.search(r"var containers = \[(.*?)\]", template).group(1)))
    outputs = set(re.findall(r"^output (\w+) ", template, re.M))
    readme = (LAB / "labautomation" / "README.md").read_text(encoding="utf-8")
    assert all(f"`{name}`" in readme for name in declared)
    assert all(f"`{name}`" in readme for name in outputs)


def test_the_starter_skill_and_canvas_are_shipped():
    starter = (LAB / "templates" / "SKILL.md").read_text(encoding="utf-8")
    assert starter.startswith("---\nname: reconciliation\n") and "TODO" in starter
    assert "## 6. First step" in (LAB / "templates" / "process-canvas.md").read_text(encoding="utf-8")
