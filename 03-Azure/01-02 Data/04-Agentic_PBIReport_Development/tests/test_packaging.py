"""Model this lab's documented platform rules, not the platform importer."""
import copy
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import re
import tempfile
import unittest
from urllib.parse import unquote, urlsplit
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SCAN = Path("\\\\?\\" + str(ROOT)) if os.name == "nt" else ROOT
CONFIG = json.loads((ROOT / "labautomation" / "lab-defaults.json").read_text(encoding="utf-8"))


def source_files():
    return {
        path.relative_to(SCAN).as_posix(): path.read_bytes()
        for path in SCAN.rglob("*")
        if path.is_file() and not set(path.relative_to(SCAN).parts).intersection(
            {"__pycache__", ".venv", "node_modules", ".pbi"})
    }


def excluding(files, removals):
    # This lab uses top-level names or exact paths, not recursive bare-name matches.
    return {name: content for name, content in files.items()
            if not any(name == target or name.startswith(target + "/") for target in removals)}


def prepare(files, audience, download=False, config=CONFIG):
    if audience not in ("student", "coach"):
        raise ValueError("Unknown package audience")
    side, lessons, opposite = (
        ("challenges", "challenges", "walkthrough") if audience == "student" else
        ("solutions", "walkthrough", "challenges"))
    base = excluding(files, ("labautomation", opposite))
    rules = config["contentPreparation"]
    if not download:
        return excluding(base, rules["alwaysRemove"][side])
    # Page removals and ZIP exclusions are independent platform settings.
    assets = {name: content for name, content in base.items()
              if len(PurePosixPath(name).parts) > 1
              and not (name.startswith(lessons + "/") and name.lower().endswith(".md"))}
    return excluding(assets, rules[audience + "ZipExclusions"])


def broken_links(files):
    broken = []
    for name, content in files.items():
        if not name.lower().endswith(".md"):
            continue
        text = re.sub(r"```.*?```", "", content.decode("utf-8"), flags=re.DOTALL)
        for target in re.findall(r"!?\[[^\]\n]*\]\(([^)\n]+)\)", text):
            url = urlsplit(target)
            if url.scheme or url.netloc or not url.path:
                continue
            destination = posixpath.normpath(posixpath.join(
                posixpath.dirname(name), unquote(url.path)))
            if destination not in files:
                broken.append(f"{name}: {target}")
    return broken


class PackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files = source_files()

    def test_published_sides_have_closed_navigation_and_no_author_files(self):
        for audience, lessons in (("student", "challenges"), ("coach", "walkthrough")):
            with self.subTest(audience=audience):
                prepared = prepare(self.files, audience)
                self.assertEqual(broken_links(prepared), [])
                self.assertIn(lessons + "/README.md", prepared)
                self.assertIn("resources/cleanup.md", prepared)
                self.assertNotIn("README.md", prepared)
                opposite = "walkthrough/" if audience == "student" else "challenges/"
                self.assertFalse(any(name.startswith(("labautomation/", "tests/", opposite))
                                     for name in prepared))
                self.assertNotIn("CONTRIBUTING.md", prepared)
                self.assertNotIn(".gitignore", prepared)
                side = "challenges" if audience == "student" else "solutions"
                self.assertFalse(CONFIG["contentPreparation"]["banners"][side]["parentReadme"])
                self.assertTrue(CONFIG["contentPreparation"]["banners"][side]["download"])
                prefix = "challenges/challenge-" if audience == "student" else "walkthrough/challenge-"
                lesson_pages = [name for name in prepared if name.startswith(prefix)
                                and name.endswith(".md")]
                self.assertEqual(len(lesson_pages), 3)

    def test_real_download_zips_keep_data_and_only_the_correct_audience_sources(self):
        expected_csv = {name for name in self.files if name.startswith("datasets/")
                        and name.endswith(".csv")}
        self.assertEqual(len(expected_csv), 16)
        for audience in ("student", "coach"):
            with self.subTest(audience=audience), tempfile.TemporaryDirectory(
                    prefix="microhack-package-") as folder:
                path = Path(folder) / f"download-{audience}.zip"
                with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
                    for name, content in prepare(self.files, audience, download=True).items():
                        archive.writestr(name, content)
                with zipfile.ZipFile(path) as archive:
                    self.assertIsNone(archive.testzip())
                    assets = {name: archive.read(name) for name in archive.namelist()}
                self.assertEqual(broken_links(assets), [])
                self.assertTrue(expected_csv.issubset(assets))
                for name in expected_csv | {
                    "datasets/manifest.json", "datasets/dictionary.md",
                    "datasets/generate_data.py", "datasets/generate-data.py",
                    "resources/banking-business-brief.md", "resources/insurance-business-brief.md",
                    "resources/report-design-brief.md", "resources/host-readiness.md",
                    "resources/copilot-instructions.md", "resources/cleanup.md",
                }:
                    self.assertEqual(assets[name], self.files[name])
                self.assertFalse(any(name.startswith(("labautomation/", "tests/", "challenges/"))
                                     for name in assets))
                self.assertFalse(any(name in assets for name in (
                    "README.md", "CONTRIBUTING.md", ".gitignore")))
                coach_sources = {
                    "walkthrough/challenge-01/loader.py",
                    "walkthrough/challenge-01/build-notebook.py",
                    "walkthrough/challenge-02/enrich-model.py",
                    "walkthrough/challenge-02/business_measures.py",
                    "walkthrough/challenge-02/banking-reconcile.dax",
                    "walkthrough/challenge-02/insurance-reconcile.dax",
                    "walkthrough/challenge-03/build-report.py",
                    "walkthrough/challenge-03/examples/banking/banking.Report/definition.pbir",
                    "walkthrough/challenge-03/examples/insurance/insurance.Report/definition.pbir",
                    "walkthrough/prepare-definition.py",
                }
                if audience == "student":
                    self.assertFalse(any(name.startswith("walkthrough/") for name in assets))
                else:
                    self.assertTrue(coach_sources.issubset(assets))
                    self.assertFalse(any(name.startswith("walkthrough/") and name.endswith(".md")
                                         for name in assets))
                    report_parts = {name for name in self.files
                                    if name.startswith("walkthrough/challenge-03/examples/")}
                    self.assertTrue(report_parts.issubset(assets))

    def test_checks_catch_removed_dependencies_and_case_sensitive_links(self):
        student = prepare(self.files, "student")
        for target in ("../labautomation/README.md", "../walkthrough/README.md",
                       "../datasets/Dictionary.md"):
            with self.subTest(target=target):
                changed = dict(student)
                changed["resources/banking-business-brief.md"] = f"[Required]({target})".encode()
                self.assertIn(f"resources/banking-business-brief.md: {target}", broken_links(changed))
        rules = copy.deepcopy(CONFIG)
        rules["contentPreparation"]["studentZipExclusions"] = []
        self.assertIn("tests/test_solutions.py", prepare(
            self.files, "student", download=True, config=rules))
        self.assertNotIn("tests/test_solutions.py", prepare(self.files, "student", config=rules))


if __name__ == "__main__":
    unittest.main()
