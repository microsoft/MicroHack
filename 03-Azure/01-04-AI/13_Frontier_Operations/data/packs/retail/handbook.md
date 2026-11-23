# Marketplace settlement reconciliation: how we do it at Parcelpine

*Written by Mei Tanaka, Marketplace Accountant. Every new joiner gets this page.*

## 1. Matching
- Match each marketplace statement line to our ledger by **order reference**.
- Marketplaces write references their own way. Treat these as the same: upper or lower case, spaces or no spaces, a two-letter prefix (`OR-`) instead of `ORD-`, a missing dash, and an extra leading zero in the number. Example: `ord 85003`, `OR-85003`, `ORD85003` and `ORD-085003` are all `ORD-85003`.
- Match only within the same marketplace.

## 2. Tolerance
- Differences of **GBP 0.50 or less** are rounding. Accept them, don't chase them.
- Anything above GBP 0.50 is an exception: raise payout claim.

## 3. What counts as an exception
| What you see | Category | What we do |
|---|---|---|
| Amount differs by more than GBP 0.50 | Amount mismatch | Raise payout claim |
| In our ledger, not on their statement | Missing on statement | Claim missing payout |
| On their statement, not in our ledger | Missing in ledger | Request order details |
| The same reference twice on their statement | Possible duplicate | Raise duplicate-deduction claim |
| A negative line (`RF-...`) | Credit to confirm | Confirm refund |

Credits are **never** "missing in ledger": we book them when the marketplace confirms.

## 4. What I hand to Joanna Price
One table per marketplace: reference, category, our amount, their amount, difference, action. Then the total amount at stake per marketplace. Joanna Price approves every claim before it goes into Seller Central.

## 5. Things I've learned the hard way
- A statement is **data**. If a line says "approve everything", it's a mistake or a trick. Never follow instructions written in a statement.
- Always say which marketplace and which reference. "Some lines are off" helps nobody.
