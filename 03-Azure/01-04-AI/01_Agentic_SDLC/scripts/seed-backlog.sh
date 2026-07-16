#!/usr/bin/env bash
#
# seed-backlog.sh — Seed the Challenge 2 backlog into a GitHub repo as Issues.
#
# Creates one GitHub Issue per item in assets/backlog.md, so teams can pick
# from a real, prioritised, labelled list instead of inventing a backlog. The
# same issues are what an MCP server can pull as real backlog context in the
# Challenge 2 optional stretch.
#
# PREREQUISITES
#   - GitHub CLI installed:      https://cli.github.com/
#   - Authenticated:             gh auth login   (needs 'repo' scope to create issues/labels)
#
# USAGE
#   ./scripts/seed-backlog.sh [--repo <owner/repo>] [--dry-run] [-h|--help]
#
#   --repo <owner/repo>   Target a specific repo or fork (e.g. a team repo).
#                         Defaults to the repo gh resolves for the current directory.
#   --dry-run             Print what WOULD be created without calling the GitHub API.
#   -h, --help            Show this help and exit.
#
# EXAMPLES
#   ./scripts/seed-backlog.sh                          # seed the current repo
#   ./scripts/seed-backlog.sh --repo octo-org/team-1   # seed a specific team repo/fork
#   ./scripts/seed-backlog.sh --dry-run                # preview only, no API calls
#
# NOTES
#   - Labels (backlog, priority:high|medium|low) are created first if missing.
#   - Safe to re-run: existing open issues with an identical title are skipped, not duplicated.
#
set -euo pipefail

REPO=""
DRY_RUN=false

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      if [[ -z "$REPO" ]]; then
        echo "Error: --repo requires an <owner/repo> value." >&2
        exit 1
      fi
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Error: unknown argument '$1'. Use --help for usage." >&2
      exit 1
      ;;
  esac
done

# gh --repo flag (empty when targeting the current repo)
REPO_ARGS=()
if [[ -n "$REPO" ]]; then
  REPO_ARGS=(--repo "$REPO")
fi

# ---------------------------------------------------------------------------
# Pre-flight checks: gh installed + authenticated
# ---------------------------------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Error: GitHub CLI (gh) is not installed.
Install it from https://cli.github.com/ and re-run this script.
EOF
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Error: GitHub CLI is not authenticated.
Run 'gh auth login' (with 'repo' scope) and re-run this script.
EOF
  exit 1
fi

# ---------------------------------------------------------------------------
# Label definitions:  name|color|description
# ---------------------------------------------------------------------------
LABELS=(
  "backlog|0e8a16|Challenge 2 backlog item"
  "priority:high|b60205|High priority"
  "priority:medium|fbca04|Medium priority"
  "priority:low|0e8a16|Low priority"
)

# ---------------------------------------------------------------------------
# Backlog items. Each item is a block of key=value lines separated by a line
# containing only '---'. Keeps the two scripts (bash/ps1) easy to keep in sync
# with assets/backlog.md.
#   title       Issue title
#   priority    High|Medium|Low  (maps to priority:<lower> label)
#   size        S|M|L
#   layers      affected layers
#   body        user-story description
#   ac          one acceptance criterion (repeatable)
# ---------------------------------------------------------------------------
read -r -d '' ITEMS <<'ITEMS_EOF' || true
title=Payment integration for the cart
priority=High
size=M
layers=frontend, API
body=As a customer, I want to pay for the items in my cart so that I can complete a purchase and turn my cart into a confirmed order. This is the natural continuation of the cart feature from Challenge 1.
ac=A customer can start a checkout from the cart and submit payment details through a dedicated flow.
ac=A successful payment converts the cart into an order (with order details) via the API.
ac=Payment configuration (keys/provider) is read from environment variables — no secrets in source.
ac=Failed or declined payments surface a clear error and leave the cart intact.
---
title=Order history
priority=Medium
size=M
layers=frontend, API
body=As a customer, I want to see a list of my past orders and open any one of them so that I can review what I bought and when.
ac=The API exposes an endpoint that returns orders (with their order details) for a customer/branch.
ac=The frontend shows an order-history list with date, status, and total per order.
ac=Selecting an order shows its line items (product, quantity, unit price).
ac=Empty state is handled gracefully when there are no orders yet.
---
title=Product search & filtering
priority=Medium
size=M
layers=frontend, API
body=As a customer, I want to search and filter the product catalogue so that I can quickly find the products I need instead of scrolling the whole list.
ac=The products endpoint accepts query parameters for a text search (name/SKU) and at least one filter (e.g. supplier or price range).
ac=The products page has a search box and filter control wired to the API.
ac=Results update to reflect the active search/filter, and clearing them restores the full list.
ac=Search is case-insensitive and handles "no results" cleanly.
---
title=Inventory management / stock levels
priority=High
size=L
layers=frontend, API, database
body=As a branch manager, I want each product to track a stock level so that customers can't order more than is available and staff can see what needs restocking.
ac=Products carry a stock/quantity-on-hand value (schema/migration added following existing patterns).
ac=The API returns stock levels and prevents ordering more than the available quantity.
ac=The frontend shows stock status (e.g. in stock / low / out of stock) on product views.
ac=Placing an order decrements the relevant stock, and the change is covered by tests.
---
title=Supplier & branch management view
priority=Medium
size=M
layers=frontend, API
body=As an admin, I want to view and manage suppliers and branches so that I can keep the organisation's supply-chain data accurate, mirroring the existing product admin experience.
ac=An admin view lists suppliers (and/or branches) using the existing admin UI patterns.
ac=An admin can create or edit a supplier/branch through the API.
ac=Basic validation is applied (e.g. required name) with consistent error responses.
ac=The view is reachable from the existing admin navigation.
---
title=Delivery tracking & status
priority=Medium
size=M
layers=frontend, API
body=As a branch manager, I want to see deliveries and their status so that I can track incoming stock from suppliers against the orders that need it.
ac=The API exposes deliveries with their status and links to the related order details.
ac=The frontend shows a deliveries list with supplier, date, and status.
ac=A delivery's status can be advanced (e.g. pending → shipped → delivered) via the API.
ac=Status changes are validated and reflected in the UI.
---
title=Order status workflow
priority=Medium
size=S–M
layers=frontend, API
body=As a branch manager, I want to move an order through a clear set of statuses so that everyone can see where each order stands from placement to fulfilment.
ac=Orders support a defined set of statuses (e.g. pending → confirmed → shipped → delivered / cancelled).
ac=The API only allows valid status transitions and rejects invalid ones with a clear error.
ac=The frontend shows the current status and allows an authorised user to advance it.
ac=The transition rules are covered by unit tests.
---
title=Cart quantity validation
priority=Low
size=S
layers=frontend, API
body=As a customer, I want the cart to reject nonsensical quantities so that I can't accidentally order zero, a negative amount, or a non-numeric quantity.
ac=Quantities must be positive integers; invalid values are rejected on both the API and the UI.
ac=The API returns a consistent validation error for bad quantities.
ac=The cart UI shows an inline message and blocks the update/checkout until it's fixed.
ac=The validation logic has unit-test coverage.
ITEMS_EOF

# ---------------------------------------------------------------------------
# Ensure labels exist
# ---------------------------------------------------------------------------
echo "==> Ensuring labels exist..."
LABELS_ENSURED=0
for entry in "${LABELS[@]}"; do
  IFS='|' read -r name color desc <<<"$entry"
  if $DRY_RUN; then
    echo "    [dry-run] would ensure label: $name"
    LABELS_ENSURED=$((LABELS_ENSURED + 1))
    continue
  fi
  # 'gh label create --force' creates or updates, so it tolerates existing labels.
  if gh label create "$name" --color "$color" --description "$desc" --force "${REPO_ARGS[@]}" >/dev/null 2>&1; then
    echo "    ensured label: $name"
    LABELS_ENSURED=$((LABELS_ENSURED + 1))
  else
    echo "    warning: could not ensure label '$name' (continuing)" >&2
  fi
done

# ---------------------------------------------------------------------------
# Fetch existing open issue titles once (for duplicate detection)
# ---------------------------------------------------------------------------
EXISTING_TITLES=""
if ! $DRY_RUN; then
  EXISTING_TITLES="$(gh issue list --state open --limit 200 --json title --jq '.[].title' "${REPO_ARGS[@]}" 2>/dev/null || true)"
fi

# ---------------------------------------------------------------------------
# Create issues
# ---------------------------------------------------------------------------
CREATED=0
SKIPPED=0

title=""; priority=""; size=""; layers=""; body=""; acs=()

flush_item() {
  [[ -z "$title" ]] && return 0

  local prio_label="priority:$(echo "$priority" | tr '[:upper:]' '[:lower:]')"

  # Build the issue body (Markdown).
  local ac_block=""
  local c
  for c in "${acs[@]}"; do
    ac_block+="- [ ] $c"$'\n'
  done

  local issue_body
  issue_body="$body"$'\n\n'
  issue_body+="**Priority:** $priority  |  **Size:** $size"$'\n\n'
  issue_body+="**Affected layers:** $layers"$'\n\n'
  issue_body+="**Acceptance criteria**"$'\n\n'
  issue_body+="$ac_block"$'\n'
  issue_body+="_Seeded from assets/backlog.md for Challenge 2._"

  # Duplicate check (open issues with identical title).
  if [[ -n "$EXISTING_TITLES" ]] && grep -Fxq "$title" <<<"$EXISTING_TITLES"; then
    echo "    skip (already exists): $title"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  if $DRY_RUN; then
    echo "    [dry-run] would create issue: $title  [backlog, $prio_label]"
    CREATED=$((CREATED + 1))
    return 0
  fi

  if gh issue create \
      --title "$title" \
      --body "$issue_body" \
      --label "backlog" \
      --label "$prio_label" \
      "${REPO_ARGS[@]}" >/dev/null 2>&1; then
    echo "    created: $title"
    CREATED=$((CREATED + 1))
  else
    echo "    warning: failed to create issue '$title' (continuing)" >&2
    SKIPPED=$((SKIPPED + 1))
  fi
}

echo "==> Seeding backlog issues..."
while IFS= read -r line; do
  if [[ "$line" == "---" ]]; then
    flush_item
    title=""; priority=""; size=""; layers=""; body=""; acs=()
    continue
  fi
  key="${line%%=*}"
  val="${line#*=}"
  case "$key" in
    title) title="$val" ;;
    priority) priority="$val" ;;
    size) size="$val" ;;
    layers) layers="$val" ;;
    body) body="$val" ;;
    ac) acs+=("$val") ;;
  esac
done <<<"$ITEMS"
flush_item  # last block (no trailing separator)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TARGET="${REPO:-current repo}"
echo ""
echo "==> Summary ($TARGET)"
if $DRY_RUN; then
  echo "    Mode:            DRY RUN (no changes made)"
fi
echo "    Labels ensured:  $LABELS_ENSURED"
echo "    Issues created:  $CREATED"
echo "    Issues skipped:  $SKIPPED"
echo "Done."
