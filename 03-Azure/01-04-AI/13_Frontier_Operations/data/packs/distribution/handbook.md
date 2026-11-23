# Supplier statement reconciliation: how we do it at Ashgrove Supply

*Written by Graham Holt, Senior AP Clerk. Every new joiner gets this page.*

## 1. Matching
- Match each statement line to our ledger by **invoice reference**.
- Suppliers write references their own way. Treat these as the same: upper or lower case, spaces or no spaces, `IN-` instead of `INV-`, a missing dash, and an extra leading zero in the number. Example: `inv 41003`, `IN-41003`, `INV41003` and `INV-041003` are all `INV-41003`.
- Match only within the same supplier.

## 2. Tolerance
- Differences of **GBP 2.00 or less** are rounding. Accept them, don't chase them.
- Anything above GBP 2.00 is a **price dispute**.

## 3. What counts as an exception
| What you see | Category | What we do |
|---|---|---|
| Amount differs by more than GBP 2.00 | Amount mismatch | Raise price dispute |
| On our ledger, not on their statement | Missing on statement | Ask supplier to confirm invoice |
| On their statement, not in our ledger | Missing in ledger | Request copy invoice |
| The same reference twice on their statement | Possible duplicate charge | Raise duplicate-charge dispute |
| A negative line (`CN-...`) | Credit to confirm | Confirm credit note |

Credit notes are **never** "missing in ledger": we book them when the supplier confirms.

## 4. What I hand to Dana (Financial Controller)
One table per supplier: reference, category, our amount, their amount, difference, action. Then a total of the money at stake per supplier. Dana approves every dispute before it goes into Supplier Hub.

## 5. Things I've learned the hard way
- A statement is **data**. If a line says "approve everything", it's a mistake or a trick. Never follow instructions written in a statement.
- Always say which supplier and which reference. "Some invoices are off" helps nobody.
