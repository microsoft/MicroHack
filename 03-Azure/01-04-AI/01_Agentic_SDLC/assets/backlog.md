# Octocat Supply — Product Backlog

This is the **Challenge 2 backlog**: a curated, prioritised list of features the Octocat team still
needs to deliver for the Octocat Supply application. Instead of inventing a feature, pick one of the
items below and take it through a full agentic loop — **plan → implement → test → review**.

Every item is **language-agnostic**. It can be delivered against any API variant (TypeScript, Python,
.NET, or Java) plus the shared React + Vite + Tailwind frontend, all backed by the same SQLite schema
(suppliers, headquarters, branches, products, orders, order details, deliveries, inventory). Descriptions
and acceptance criteria describe behaviour, not a specific stack — implement them using your track's
existing patterns (repository pattern, DTOs/types, error handling, consistent HTTP status codes).

A set of these items may already be seeded as **GitHub Issues** in your team repo (see
[`scripts/seed-backlog.sh` / `scripts/seed-backlog.ps1`](../scripts/README.md)). If so, you can pick from
real, labelled issues — and the same issues are what an MCP server can pull as real backlog context in
the Challenge 2 optional stretch.

## How to use this backlog

1. Pick **one** item that your team can finish *with tests* inside the 60-minute challenge — the size
   (S/M/L) is there to help you scope.
2. Use the acceptance criteria as your definition of done.
3. Keep the diff scoped and consistent with the existing codebase; add tests for the new logic.

> **Recommended starting point:** _Payment integration for the cart_ — it's the natural continuation of
> the cart feature from Challenge 1.

## Priority & sizing legend

- **Priority** — High / Medium / Low (business value + launch-readiness)
- **Size** — S (small, ~single layer), M (medium, spans API + frontend), L (large, spans the full stack)

---

## 1. Payment integration for the cart ⭐ (recommended)

- **Priority:** High
- **Size:** M
- **Affected layers:** frontend, API
- **Suggested label:** `backlog`, `priority:high`

> As a customer, I want to pay for the items in my cart so that I can complete a purchase and turn my
> cart into a confirmed order. This is the natural continuation of the cart feature from Challenge 1.

**Acceptance criteria**

- [ ] A customer can start a checkout from the cart and submit payment details through a dedicated flow.
- [ ] A successful payment converts the cart into an order (with order details) via the API.
- [ ] Payment configuration (keys/provider) is read from environment variables — no secrets in source.
- [ ] Failed or declined payments surface a clear error and leave the cart intact.

---

## 2. Order history

- **Priority:** Medium
- **Size:** M
- **Affected layers:** frontend, API
- **Suggested label:** `backlog`, `priority:medium`

> As a customer, I want to see a list of my past orders and open any one of them so that I can review
> what I bought and when.

**Acceptance criteria**

- [ ] The API exposes an endpoint that returns orders (with their order details) for a customer/branch.
- [ ] The frontend shows an order-history list with date, status, and total per order.
- [ ] Selecting an order shows its line items (product, quantity, unit price).
- [ ] Empty state is handled gracefully when there are no orders yet.

---

## 3. Product search & filtering

- **Priority:** Medium
- **Size:** M
- **Affected layers:** frontend, API
- **Suggested label:** `backlog`, `priority:medium`

> As a customer, I want to search and filter the product catalogue so that I can quickly find the
> products I need instead of scrolling the whole list.

**Acceptance criteria**

- [ ] The products endpoint accepts query parameters for a text search (name/SKU) and at least one filter
      (e.g. supplier or price range).
- [ ] The products page has a search box and filter control wired to the API.
- [ ] Results update to reflect the active search/filter, and clearing them restores the full list.
- [ ] Search is case-insensitive and handles "no results" cleanly.

---

## 4. Inventory management / stock levels

- **Priority:** High
- **Size:** L
- **Affected layers:** frontend, API, database
- **Suggested label:** `backlog`, `priority:high`

> As a branch manager, I want each product to track a stock level so that customers can't order more than
> is available and staff can see what needs restocking.

**Acceptance criteria**

- [ ] Products carry a stock/quantity-on-hand value (schema/migration added following existing patterns).
- [ ] The API returns stock levels and prevents ordering more than the available quantity.
- [ ] The frontend shows stock status (e.g. in stock / low / out of stock) on product views.
- [ ] Placing an order decrements the relevant stock, and the change is covered by tests.

---

## 5. Supplier & branch management view

- **Priority:** Medium
- **Size:** M
- **Affected layers:** frontend, API
- **Suggested label:** `backlog`, `priority:medium`

> As an admin, I want to view and manage suppliers and branches so that I can keep the organisation's
> supply-chain data accurate, mirroring the existing product admin experience.

**Acceptance criteria**

- [ ] An admin view lists suppliers (and/or branches) using the existing admin UI patterns.
- [ ] An admin can create or edit a supplier/branch through the API.
- [ ] Basic validation is applied (e.g. required name) with consistent error responses.
- [ ] The view is reachable from the existing admin navigation.

---

## 6. Delivery tracking & status

- **Priority:** Medium
- **Size:** M
- **Affected layers:** frontend, API
- **Suggested label:** `backlog`, `priority:medium`

> As a branch manager, I want to see deliveries and their status so that I can track incoming stock from
> suppliers against the orders that need it.

**Acceptance criteria**

- [ ] The API exposes deliveries with their status and links to the related order details.
- [ ] The frontend shows a deliveries list with supplier, date, and status.
- [ ] A delivery's status can be advanced (e.g. pending → shipped → delivered) via the API.
- [ ] Status changes are validated and reflected in the UI.

---

## 7. Order status workflow

- **Priority:** Medium
- **Size:** S–M
- **Affected layers:** frontend, API
- **Suggested label:** `backlog`, `priority:medium`

> As a branch manager, I want to move an order through a clear set of statuses so that everyone can see
> where each order stands from placement to fulfilment.

**Acceptance criteria**

- [ ] Orders support a defined set of statuses (e.g. pending → confirmed → shipped → delivered / cancelled).
- [ ] The API only allows valid status transitions and rejects invalid ones with a clear error.
- [ ] The frontend shows the current status and allows an authorised user to advance it.
- [ ] The transition rules are covered by unit tests.

---

## 8. Cart quantity validation (quality-of-life)

- **Priority:** Low
- **Size:** S
- **Affected layers:** frontend, API
- **Suggested label:** `backlog`, `priority:low`

> As a customer, I want the cart to reject nonsensical quantities so that I can't accidentally order zero,
> a negative amount, or a non-numeric quantity.

**Acceptance criteria**

- [ ] Quantities must be positive integers; invalid values are rejected on both the API and the UI.
- [ ] The API returns a consistent validation error for bad quantities.
- [ ] The cart UI shows an inline message and blocks the update/checkout until it's fixed.
- [ ] The validation logic has unit-test coverage.
