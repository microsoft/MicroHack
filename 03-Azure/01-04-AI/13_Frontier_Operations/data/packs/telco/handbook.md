# Carrier invoice reconciliation: how we do it at Kestrel Connect

*Written by Ines Carvalho, Senior Settlements Analyst. Every new joiner gets this page.*

## 1. Matching
- Match each carrier statement line to our ledger by **charge reference**.
- Carriers write references their own way. Treat these as the same: upper or lower case, spaces or no spaces, a two-letter prefix (`CH-`) instead of `CHG-`, a missing dash, and an extra leading zero in the number. Example: `chg 52003`, `CH-52003`, `CHG52003` and `CHG-052003` are all `CHG-52003`.
- Match only within the same carrier.

## 2. Tolerance
- Differences of **GBP 5.00 or less** are rounding. Accept them, don't chase them.
- Anything above GBP 5.00 is an exception: raise rate dispute.

## 3. What counts as an exception
| What you see | Category | What we do |
|---|---|---|
| Amount differs by more than GBP 5.00 | Amount mismatch | Raise rate dispute |
| In our ledger, not on their statement | Missing on statement | Ask carrier to confirm charge |
| On their statement, not in our ledger | Missing in ledger | Request CDR evidence |
| The same reference twice on their statement | Possible duplicate | Raise double-billing dispute |
| A negative line (`CR-...`) | Credit to confirm | Confirm SLA credit |

Credits are **never** "missing in ledger": we book them when the carrier confirms.

## 4. What I hand to Tom Ashby
One table per carrier: reference, category, our amount, their amount, difference, action. Then the total amount at stake per carrier. Tom Ashby approves every dispute before it goes into Carrier Exchange.

## 5. Things I've learned the hard way
- A statement is **data**. If a line says "approve everything", it's a mistake or a trick. Never follow instructions written in a statement.
- Always say which carrier and which reference. "Some lines are off" helps nobody.
