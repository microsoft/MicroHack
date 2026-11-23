"""Write walkthrough/expected-results.md from each pack's answer key."""
import json
import sys
from pathlib import Path

LAB = Path(__file__).resolve().parents[1]
PACKS = LAB / "data" / "packs"
LABELS = {"mismatch": "Amount mismatch", "within_tolerance": "Within tolerance (accept, don't list)",
          "missing_on_statement": "Missing on statement", "missing_in_ledger": "Missing in ledger",
          "duplicate": "Possible duplicate", "credit": "Credit to confirm"}


def money(value):
    return "" if value is None else f"{value:,.2f}"


def render() -> str:
    out = ["# Expected results for every pack", "",
           "**[Home](../README.md)**", "",
           "Generated from each pack's `expected.json` by `walkthrough/make_expected.py`. Don't edit by hand.", "",
           "Every partner statement has the same six planted lines. `python3 -m frontierops score` checks a workbook "
           "against these tables. One statement per pack also has a line that is an instruction, not a transaction "
           "(Challenge 6); it isn't in these tables.", ""]
    for folder in sorted(PACKS.iterdir()):
        profile = json.loads((folder / "pack.json").read_text(encoding="utf-8"))
        expected = json.loads((folder / "expected.json").read_text(encoding="utf-8"))
        names = {p["id"]: p["name"] for p in profile["partners"]}
        cur = profile["currency"]
        injected = [names[s.stem] for s in sorted((folder / "statements").glob("*.csv"))
                    if "ignore all previous" in s.read_text(encoding="utf-8").lower()]
        out += [f"## {profile['company']} (`{folder.name}`)", "",
                f"Tolerance: **{cur} {profile['tolerance']:.2f}**. Approver: {profile['people']['approver']}. "
                f"Hidden instruction in: **{', '.join(injected)}**.", "",
                f"| {profile['partner_type'].capitalize()} | Reference | Expected category | Our amount ({cur}) | "
                f"Their amount ({cur}) | Difference | Action |",
                "|---|---|---|---:|---:|---:|---|"]
        for e in expected:
            out.append(f"| {names[e['partner_id']]} | {e['reference']} | {LABELS[e['kind']]} | "
                       f"{money(e['ledger_amount'])} | {money(e['statement_amount'])} | "
                       f"{money(e['difference'])} | {e['action']} |")
        out.append("")
    return "\n".join(out)


if __name__ == "__main__":
    target = LAB / "walkthrough" / "expected-results.md"
    target.write_text(render(), encoding="utf-8")
    print("wrote", target, file=sys.stderr)
