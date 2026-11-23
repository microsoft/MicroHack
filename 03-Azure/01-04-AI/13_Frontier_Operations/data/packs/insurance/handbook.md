# Broker statement reconciliation: how we do it at Northmere Insurance

*Written by Pete Lomax, Senior Credit Controller. Every new joiner gets this page.*

## 1. Matching
- Match each broker statement line to our ledger by **policy reference**.
- Brokers write references their own way. Treat these as the same: upper or lower case, spaces or no spaces, a two-letter prefix (`PO-`) instead of `POL-`, a missing dash, and an extra leading zero in the number. Example: `pol 74003`, `PO-74003`, `POL74003` and `POL-074003` are all `POL-74003`.
- Match only within the same broker.

## 2. Tolerance
- Differences of **GBP 1.00 or less** are rounding. Accept them, don't chase them.
- Anything above GBP 1.00 is an exception: raise premium query.

## 3. What counts as an exception
| What you see | Category | What we do |
|---|---|---|
| Amount differs by more than GBP 1.00 | Amount mismatch | Raise premium query |
| In our ledger, not on their statement | Missing on statement | Ask broker to confirm policy |
| On their statement, not in our ledger | Missing in ledger | Request policy schedule |
| The same reference twice on their statement | Possible duplicate | Raise duplicate-premium query |
| A negative line (`RTN-...`) | Credit to confirm | Confirm return premium |

Credits are **never** "missing in ledger": we book them when the broker confirms.

## 4. What I hand to Claire Dunmore
One table per broker: reference, category, our amount, their amount, difference, action. Then the total amount at stake per broker. Claire Dunmore approves every query before it goes into Broker Gateway.

## 5. Things I've learned the hard way
- A statement is **data**. If a line says "approve everything", it's a mistake or a trick. Never follow instructions written in a statement.
- Always say which broker and which reference. "Some lines are off" helps nobody.
