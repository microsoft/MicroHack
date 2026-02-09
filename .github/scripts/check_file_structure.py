#!/usr/bin/env python3
"""
File Structure Compliance Checker for MicroHack Repository

This script analyzes the file structure of changed files in a pull request
to ensure challenges and walkthrough directories comply with standards.

Exit codes:
    0 - All checks passed (compliant)
    1 - One or more checks failed (non-compliant)
"""

import os
import sys
import re
from pathlib import Path
from typing import List, Dict, Tuple, Set


class ComplianceChecker:
    """Checks challenges and walkthrough compliance for the MicroHack repository."""

    def __init__(self, changed_files: List[str]):
        self.changed_files = [f for f in changed_files if f.strip()]
        self.issues: List[Dict] = []
        self.warnings: List[Dict] = []
        # Track check results per project
        self.check_results: Dict[str, Dict[str, Dict]] = {}  # project -> check_name -> result

    def _get_project_roots(self) -> Set[str]:
        """Get unique project roots that contain challenges or walkthrough directories."""
        project_roots: Set[str] = set()
        
        for file_path in self.changed_files:
            parts = Path(file_path).parts
            
            for i, part in enumerate(parts):
                if part.lower() in ("challenges", "walkthrough"):
                    project_root = str(Path(*parts[:i])) if i > 0 else "."
                    project_roots.add(project_root)
                    break
        
        return project_roots

    def _init_project_result(self, project_root: str):
        """Initialize result tracking for a project."""
        if project_root not in self.check_results:
            self.check_results[project_root] = {}

    def _record_check(self, project_root: str, check_name: str, passed: bool, details: str = ""):
        """Record the result of a check for a project."""
        self._init_project_result(project_root)
        self.check_results[project_root][check_name] = {
            "passed": passed,
            "details": details
        }

    def check_challenges_numbering(self) -> bool:
        """
        Check that challenges directories have properly numbered challenge files.
        Expected format: challenge-01.md, challenge-02.md, etc. with no gaps.
        """
        all_valid = True
        project_roots = self._get_project_roots()
        
        for project_root in project_roots:
            challenges_path = Path(project_root) / "challenges"
            
            if not challenges_path.exists():
                self._record_check(project_root, "challenges_numbering", True, "No challenges directory")
                continue
            
            # Get all challenge files
            challenge_pattern = re.compile(r"^challenge-(\d+)\.md$", re.IGNORECASE)
            challenge_numbers = []
            
            for item in challenges_path.iterdir():
                if item.is_file():
                    match = challenge_pattern.match(item.name)
                    if match:
                        challenge_numbers.append(int(match.group(1)))
            
            if not challenge_numbers:
                self._record_check(project_root, "challenges_numbering", True, "No challenge files found")
                continue
            
            challenge_numbers.sort()
            project_valid = True
            
            # Check if numbering starts at 1
            if challenge_numbers[0] != 1:
                self.issues.append({
                    "file": str(challenges_path),
                    "type": "numbering",
                    "message": f"Challenge numbering should start at 01, but starts at {challenge_numbers[0]:02d}",
                })
                all_valid = False
                project_valid = False
            
            # Check for gaps in numbering
            expected = list(range(1, len(challenge_numbers) + 1))
            if challenge_numbers != expected:
                missing = set(expected) - set(challenge_numbers)
                if missing:
                    missing_str = ", ".join(f"{n:02d}" for n in sorted(missing))
                    self.issues.append({
                        "file": str(challenges_path),
                        "type": "numbering",
                        "message": f"Gap in challenge numbering. Missing: challenge-{missing_str}.md",
                    })
                    all_valid = False
                    project_valid = False
            
            if project_valid:
                self._record_check(
                    project_root, 
                    "challenges_numbering", 
                    True, 
                    f"{len(challenge_numbers)} challenges (01-{challenge_numbers[-1]:02d})"
                )
            else:
                self._record_check(project_root, "challenges_numbering", False, "Numbering issues")
        
        return all_valid

    def check_walkthrough_numbering(self) -> bool:
        """
        Check that walkthrough directories have properly numbered solution files.
        
        Two allowed formats:
        1. walkthrough/solution-01.md, walkthrough/solution-02.md, ...
        2. walkthrough/challenge-01/solution-01.md, walkthrough/challenge-02/solution-02.md, ...
        """
        all_valid = True
        project_roots = self._get_project_roots()
        
        for project_root in project_roots:
            walkthrough_path = Path(project_root) / "walkthrough"
            
            if not walkthrough_path.exists():
                self._record_check(project_root, "walkthrough_numbering", True, "No walkthrough directory")
                continue
            
            # Check for format 1: direct solution files
            solution_pattern = re.compile(r"^solution-(\d+)\.md$", re.IGNORECASE)
            format_1_numbers = []
            
            # Check for format 2: challenge subdirectories
            dir_pattern = re.compile(r"^challenge-(\d+)$", re.IGNORECASE)
            format_2_dirs = []
            
            for item in walkthrough_path.iterdir():
                if item.is_file():
                    match = solution_pattern.match(item.name)
                    if match:
                        format_1_numbers.append(int(match.group(1)))
                elif item.is_dir():
                    match = dir_pattern.match(item.name)
                    if match:
                        format_2_dirs.append((item, int(match.group(1))))
            
            has_format_1 = len(format_1_numbers) > 0
            has_format_2 = len(format_2_dirs) > 0
            project_valid = True
            
            if has_format_1 and has_format_2:
                self.issues.append({
                    "file": str(walkthrough_path),
                    "type": "structure",
                    "message": "Mixed walkthrough formats. Use either solution-XX.md OR challenge-XX/solution-XX.md, not both.",
                })
                all_valid = False
                self._record_check(project_root, "walkthrough_numbering", False, "Mixed formats")
                continue
            
            if has_format_1:
                # Validate format 1
                format_1_numbers.sort()
                
                if format_1_numbers[0] != 1:
                    self.issues.append({
                        "file": str(walkthrough_path),
                        "type": "numbering",
                        "message": f"Solution numbering should start at 01, but starts at {format_1_numbers[0]:02d}",
                    })
                    all_valid = False
                    project_valid = False
                
                expected = list(range(1, len(format_1_numbers) + 1))
                if format_1_numbers != expected:
                    missing = set(expected) - set(format_1_numbers)
                    if missing:
                        missing_str = ", ".join(f"{n:02d}" for n in sorted(missing))
                        self.issues.append({
                            "file": str(walkthrough_path),
                            "type": "numbering",
                            "message": f"Gap in solution numbering. Missing: solution-{missing_str}.md",
                        })
                        all_valid = False
                        project_valid = False
                
                if project_valid:
                    self._record_check(
                        project_root, 
                        "walkthrough_numbering", 
                        True, 
                        f"{len(format_1_numbers)} solutions (format: solution-XX.md)"
                    )
                else:
                    self._record_check(project_root, "walkthrough_numbering", False, "Numbering issues")
            
            elif has_format_2:
                # Validate format 2
                dir_numbers = [num for _, num in format_2_dirs]
                dir_numbers.sort()
                
                if dir_numbers[0] != 1:
                    self.issues.append({
                        "file": str(walkthrough_path),
                        "type": "numbering",
                        "message": f"Walkthrough directories should start at challenge-01, but starts at challenge-{dir_numbers[0]:02d}",
                    })
                    all_valid = False
                    project_valid = False
                
                expected = list(range(1, len(dir_numbers) + 1))
                if dir_numbers != expected:
                    missing = set(expected) - set(dir_numbers)
                    if missing:
                        missing_str = ", ".join(f"{n:02d}" for n in sorted(missing))
                        self.issues.append({
                            "file": str(walkthrough_path),
                            "type": "numbering",
                            "message": f"Gap in walkthrough directory numbering. Missing: challenge-{missing_str}/",
                        })
                        all_valid = False
                        project_valid = False
                
                # Check each directory has matching solution file
                for dir_path, num in format_2_dirs:
                    expected_solution = dir_path / f"solution-{num:02d}.md"
                    if not expected_solution.exists():
                        solution_files = list(dir_path.glob("solution-*.md"))
                        if solution_files:
                            self.issues.append({
                                "file": str(dir_path),
                                "type": "numbering",
                                "message": f"Solution file should be 'solution-{num:02d}.md' to match directory 'challenge-{num:02d}'",
                            })
                            all_valid = False
                            project_valid = False
                        else:
                            self.warnings.append({
                                "file": str(dir_path),
                                "type": "structure",
                                "message": f"Directory 'challenge-{num:02d}' should contain 'solution-{num:02d}.md'",
                            })
                
                if project_valid:
                    self._record_check(
                        project_root, 
                        "walkthrough_numbering", 
                        True, 
                        f"{len(format_2_dirs)} solutions (format: challenge-XX/solution-XX.md)"
                    )
                else:
                    self._record_check(project_root, "walkthrough_numbering", False, "Numbering issues")
            else:
                self._record_check(project_root, "walkthrough_numbering", True, "No solution files found")
        
        return all_valid

    def check_challenges_walkthrough_count_match(self) -> bool:
        """
        Check that the number of challenge files matches the number of solution files.
        """
        all_valid = True
        project_roots = self._get_project_roots()
        
        for project_root in project_roots:
            challenges_path = Path(project_root) / "challenges"
            walkthrough_path = Path(project_root) / "walkthrough"
            
            if not challenges_path.exists() or not walkthrough_path.exists():
                self._record_check(project_root, "count_match", True, "Missing challenges or walkthrough directory")
                continue
            
            # Count challenge files
            challenge_pattern = re.compile(r"^challenge-\d+\.md$", re.IGNORECASE)
            challenge_count = sum(
                1 for item in challenges_path.iterdir()
                if item.is_file() and challenge_pattern.match(item.name)
            )
            
            # Count solution files (handle both formats)
            solution_count = 0
            solution_pattern = re.compile(r"^solution-\d+\.md$", re.IGNORECASE)
            dir_pattern = re.compile(r"^challenge-\d+$", re.IGNORECASE)
            
            # Format 1: direct solution files
            for item in walkthrough_path.iterdir():
                if item.is_file() and solution_pattern.match(item.name):
                    solution_count += 1
            
            # Format 2: challenge-XX subdirectories
            if solution_count == 0:
                for item in walkthrough_path.iterdir():
                    if item.is_dir() and dir_pattern.match(item.name):
                        if list(item.glob("solution-*.md")):
                            solution_count += 1
            
            # Compare counts
            if challenge_count > 0 and solution_count > 0 and challenge_count != solution_count:
                self.issues.append({
                    "file": project_root,
                    "type": "count-mismatch",
                    "message": f"Mismatch: {challenge_count} challenge(s) but {solution_count} solution(s). Each challenge should have a corresponding solution.",
                })
                self._record_check(
                    project_root, 
                    "count_match", 
                    False, 
                    f"{challenge_count} challenges ≠ {solution_count} solutions"
                )
                all_valid = False
            elif challenge_count > 0 and solution_count > 0:
                self._record_check(
                    project_root, 
                    "count_match", 
                    True, 
                    f"{challenge_count} challenges = {solution_count} solutions"
                )
            else:
                self._record_check(project_root, "count_match", True, "No files to compare")
        
        return all_valid

    def check_readme_exists(self) -> bool:
        """
        Check that the project root contains a non-empty Readme.md file.
        """
        all_valid = True
        project_roots = self._get_project_roots()
        
        for project_root in project_roots:
            project_path = Path(project_root)
            
            # Look for Readme.md (case-insensitive)
            readme_file = None
            if project_path.exists():
                for item in project_path.iterdir():
                    if item.is_file() and item.name.lower() == "readme.md":
                        readme_file = item
                        break
            
            if readme_file is None:
                self.issues.append({
                    "file": project_root,
                    "type": "missing-readme",
                    "message": "Project root must contain a Readme.md file",
                })
                self._record_check(project_root, "readme_exists", False, "Readme.md not found")
                all_valid = False
            elif readme_file.stat().st_size == 0:
                self.issues.append({
                    "file": str(readme_file),
                    "type": "empty-readme",
                    "message": "Readme.md file is empty",
                })
                self._record_check(project_root, "readme_exists", False, "Readme.md is empty")
                all_valid = False
            else:
                # Get file size for details
                size_bytes = readme_file.stat().st_size
                if size_bytes < 1024:
                    size_str = f"{size_bytes} bytes"
                else:
                    size_str = f"{size_bytes / 1024:.1f} KB"
                self._record_check(project_root, "readme_exists", True, f"Readme.md ({size_str})")
        
        return all_valid

    def run_all_checks(self) -> Tuple[bool, str]:
        """Run all compliance checks."""
        challenges_valid = self.check_challenges_numbering()
        walkthrough_valid = self.check_walkthrough_numbering()
        count_match_valid = self.check_challenges_walkthrough_count_match()
        readme_valid = self.check_readme_exists()
        
        all_passed = challenges_valid and walkthrough_valid and count_match_valid and readme_valid and len(self.issues) == 0
        
        summary = self.generate_markdown_summary()
        return all_passed, summary

    def generate_markdown_summary(self) -> str:
        """Generate a markdown summary of the compliance check results."""
        lines = []
        lines.append("## 📋 Challenges & Walkthrough Compliance Check\n")

        issue_count = len(self.issues)
        warning_count = len(self.warnings)

        # Overall status
        if issue_count == 0:
            lines.append("### ✅ Status: COMPLIANT\n")
            if warning_count > 0:
                lines.append(f"*{warning_count} warning(s) found but not blocking.*\n")
        else:
            lines.append("### ❌ Status: NON-COMPLIANT\n")
            lines.append(f"*{issue_count} issue(s) must be resolved.*\n")

        # Check results per project
        if self.check_results:
            lines.append("### 📁 Projects Checked\n")
            
            for project_root in sorted(self.check_results.keys()):
                checks = self.check_results[project_root]
                project_passed = all(c["passed"] for c in checks.values())
                status_icon = "✅" if project_passed else "❌"
                
                lines.append(f"#### {status_icon} `{project_root}`\n")
                lines.append("| Check | Status | Details |")
                lines.append("|-------|--------|---------|")
                
                check_names = {
                    "readme_exists": "Readme.md",
                    "challenges_numbering": "Challenge Numbering",
                    "walkthrough_numbering": "Walkthrough Numbering", 
                    "count_match": "Count Match"
                }
                
                for check_key, display_name in check_names.items():
                    if check_key in checks:
                        result = checks[check_key]
                        icon = "✅" if result["passed"] else "❌"
                        details = result["details"] or "-"
                        lines.append(f"| {display_name} | {icon} | {details} |")
                
                lines.append("")

        # List issues
        if self.issues:
            lines.append("### ❌ Issues (Must Fix)\n")
            for issue in self.issues:
                lines.append(f"- **{issue['file']}**")
                lines.append(f"  - {issue['message']}")
            lines.append("")

        # List warnings
        if self.warnings:
            lines.append("### ⚠️ Warnings\n")
            for warning in self.warnings:
                lines.append(f"- **{warning['file']}**")
                lines.append(f"  - {warning['message']}")
            lines.append("")

        return "\n".join(lines)


def main():
    """Main entry point."""
    # Get changed files from command line arguments, stdin, or environment variable
    if len(sys.argv) > 1:
        changed_files = sys.argv[1:]
    elif not sys.stdin.isatty():
        # Read from stdin (newline-separated)
        changed_files = [line.strip() for line in sys.stdin if line.strip()]
    else:
        changed_files_env = os.environ.get("CHANGED_FILES", "")
        if changed_files_env:
            changed_files = [f.strip() for f in changed_files_env.split('\n') if f.strip()]
        else:
            changed_files = []

    # Debug: Show received files
    print(f"DEBUG: Received {len(changed_files)} files from input")
    for i, f in enumerate(changed_files[:10]):
        print(f"  [{i+1}] {f}")
    if len(changed_files) > 10:
        print(f"  ... and {len(changed_files) - 10} more files")
    print()

    if not changed_files:
        summary = "## 📋 Challenges & Walkthrough Compliance Check\n\n### ✅ Status: COMPLIANT\n\n*No files to check.*\n"
        with open("structure-check-results.md", "w", encoding="utf-8") as f:
            f.write(summary)
        print(summary)
        sys.exit(0)

    # Filter to only include files from the relevant directories
    relevant_prefixes = (
        "01-Identity and Access Management/",
        "02-Security/",
        "03-Azure/",
        "04-Microsoft-365/",
    )

    filtered_files = [
        f for f in changed_files
        if any(f.startswith(prefix) for prefix in relevant_prefixes)
    ]

    # Debug: Show filtered files
    print(f"DEBUG: {len(filtered_files)} files after filtering for relevant directories")
    for i, f in enumerate(filtered_files[:10]):
        print(f"  [{i+1}] {f}")
    if len(filtered_files) > 10:
        print(f"  ... and {len(filtered_files) - 10} more files")
    print()

    if not filtered_files:
        summary = "## 📋 Challenges & Walkthrough Compliance Check\n\n### ✅ Status: COMPLIANT\n\n*No relevant files in monitored directories.*\n"
        with open("structure-check-results.md", "w", encoding="utf-8") as f:
            f.write(summary)
        print(summary)
        sys.exit(0)

    # Run compliance checks
    checker = ComplianceChecker(filtered_files)
    is_compliant, summary = checker.run_all_checks()

    # Write summary to file
    with open("structure-check-results.md", "w", encoding="utf-8") as f:
        f.write(summary)

    print(summary)
    sys.exit(0 if is_compliant else 1)


if __name__ == "__main__":
    main()
