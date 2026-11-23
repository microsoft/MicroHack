# Industry packs

[Home](../README.md)

Each folder in [packs](packs) is one fictional company running the same monthly process: checking partner statements against its own ledger. Every company, partner, person, reference and amount is fictional.

| File | What it is | Used in |
|---|---|---|
| `pack.json` | The company profile: industry, currency, **tolerance**, reference prefix, partners, the people (process owner, expert, approver), the actions for each kind of exception, and the partner portal's name and query types | The back office (ERP and portal) and the setup tool |
| `ledger.csv` | This month's ledger lines for all partners, as the ERP holds them (60 lines) | The ERP API; copied to `my-files/ledger-export.csv` for Challenges 1 to 3 |
| `statements/<partner>.csv` | One statement per partner, in that partner's own format | Attached in the Foundry chat |
| `handbook.md` | How the company's most experienced person does the job, in their words | The source for the team's skill (Challenge 2) |
| `expected.json` | The answer key: the six planted lines for every partner | `python3 -m frontierops score`, the tests and [expected results](../walkthrough/expected-results.md) |
| `evaluation.jsonl` | Questions about the handbook's rules with reference answers | Coaches' spot checks of a skill |

## What is planted in every statement

Every partner's statement has exactly six lines that need attention, plus ordinary matching lines:

| Kind | What it looks like | What the handbook says |
|---|---|---|
| Amount mismatch | A difference above the tolerance | Dispute it |
| Within tolerance | A difference at or below the tolerance | Accept it as rounding, don't list it |
| Missing on statement | In the ledger, not on the statement | Ask the partner to confirm |
| Missing in ledger | On the statement, not in the ledger | Request evidence |
| Possible duplicate | The same reference twice on the statement | Raise a duplicate-charge query |
| Credit to confirm | A negative line | Confirm the credit; never "missing in ledger" |

References are written the partner's way (`inv 41003`, `IN-41003`, `INV41003`, `INV-041003`), so matching needs the handbook's normalisation rules. One statement per pack also contains a line that is an instruction aimed at the agent, not a transaction; Challenge 6 deals with it.

The tests in [tests/test_packs.py](../tests/test_packs.py) check that applying the handbook's rules to the files finds exactly the lines in `expected.json`, for every pack.
