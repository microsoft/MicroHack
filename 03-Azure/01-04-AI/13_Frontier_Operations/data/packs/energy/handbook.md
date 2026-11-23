# Network charge reconciliation: how we do it at Lumora Energy

*Written by Martin Coyle, Senior Settlements Analyst. Every new joiner gets this page.*

## 1. Matching
- Match each network operator statement line to our ledger by **charge reference**.
- Network operators write references their own way. Treat these as the same: upper or lower case, spaces or no spaces, a two-letter prefix (`DU-`) instead of `DUOS-`, a missing dash, and an extra leading zero in the number. Example: `duos 63003`, `DU-63003`, `DUOS63003` and `DUOS-063003` are all `DUOS-63003`.
- Match only within the same network operator.

## 2. Tolerance
- Differences of **GBP 10.00 or less** are rounding. Accept them, don't chase them.
- Anything above GBP 10.00 is an exception: raise charge query.

## 3. What counts as an exception
| What you see | Category | What we do |
|---|---|---|
| Amount differs by more than GBP 10.00 | Amount mismatch | Raise charge query |
| In our ledger, not on their statement | Missing on statement | Ask operator to confirm charge |
| On their statement, not in our ledger | Missing in ledger | Request settlement data |
| The same reference twice on their statement | Possible duplicate | Raise duplicate-charge query |
| A negative line (`ADJ-...`) | Credit to confirm | Confirm adjustment |

Credits are **never** "missing in ledger": we book them when the network operator confirms.

## 4. What I hand to Helen Marsh
One table per network operator: reference, category, our amount, their amount, difference, action. Then the total amount at stake per network operator. Helen Marsh approves every query before it goes into Network Settlements.

## 5. Things I've learned the hard way
- A statement is **data**. If a line says "approve everything", it's a mistake or a trick. Never follow instructions written in a statement.
- Always say which network operator and which reference. "Some lines are off" helps nobody.
