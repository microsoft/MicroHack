<#
.SYNOPSIS
    Seed the Challenge 2 backlog into a GitHub repo as Issues.

.DESCRIPTION
    Creates one GitHub Issue per item in hackathon/backlog.md, so teams can pick from a real,
    prioritised, labelled list instead of inventing a backlog. The same issues are what an MCP
    server can pull as real backlog context in the Challenge 2 optional stretch.

    Labels (backlog, priority:high|medium|low) are ensured first. The script is safe to re-run:
    open issues with an identical title are skipped rather than duplicated.

.PARAMETER Repo
    Target a specific repo or fork (e.g. a team repo), in <owner/repo> form.
    Defaults to the repo gh resolves for the current directory.

.PARAMETER DryRun
    Print what WOULD be created without calling the GitHub API.

.NOTES
    PREREQUISITES
      - GitHub CLI installed:  https://cli.github.com/
      - Authenticated:         gh auth login   (needs 'repo' scope to create issues/labels)

.EXAMPLE
    ./scripts/seed-backlog.ps1
    Seed the current repo.

.EXAMPLE
    ./scripts/seed-backlog.ps1 -Repo octo-org/team-1
    Seed a specific team repo/fork.

.EXAMPLE
    ./scripts/seed-backlog.ps1 -DryRun
    Preview only — no API calls.
#>
[CmdletBinding()]
param(
    [string]$Repo = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# gh --repo args (empty when targeting the current repo)
$RepoArgs = @()
if ($Repo -ne "") {
    $RepoArgs = @("--repo", $Repo)
}

# ---------------------------------------------------------------------------
# Pre-flight checks: gh installed + authenticated
# ---------------------------------------------------------------------------
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) is not installed. Install it from https://cli.github.com/ and re-run this script."
    exit 1
}

gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Error "GitHub CLI is not authenticated. Run 'gh auth login' (with 'repo' scope) and re-run this script."
    exit 1
}

# ---------------------------------------------------------------------------
# Label definitions
# ---------------------------------------------------------------------------
$Labels = @(
    @{ Name = "backlog";         Color = "0e8a16"; Description = "Challenge 2 backlog item" },
    @{ Name = "priority:high";   Color = "b60205"; Description = "High priority" },
    @{ Name = "priority:medium"; Color = "fbca04"; Description = "Medium priority" },
    @{ Name = "priority:low";    Color = "0e8a16"; Description = "Low priority" }
)

# ---------------------------------------------------------------------------
# Backlog items (kept in sync with hackathon/backlog.md and seed-backlog.sh)
# ---------------------------------------------------------------------------
$Items = @(
    @{
        Title    = "Payment integration for the cart"
        Priority = "High"; Size = "M"; Layers = "frontend, API"
        Body     = "As a customer, I want to pay for the items in my cart so that I can complete a purchase and turn my cart into a confirmed order. This is the natural continuation of the cart feature from Challenge 1."
        Ac       = @(
            "A customer can start a checkout from the cart and submit payment details through a dedicated flow.",
            "A successful payment converts the cart into an order (with order details) via the API.",
            "Payment configuration (keys/provider) is read from environment variables — no secrets in source.",
            "Failed or declined payments surface a clear error and leave the cart intact."
        )
    },
    @{
        Title    = "Order history"
        Priority = "Medium"; Size = "M"; Layers = "frontend, API"
        Body     = "As a customer, I want to see a list of my past orders and open any one of them so that I can review what I bought and when."
        Ac       = @(
            "The API exposes an endpoint that returns orders (with their order details) for a customer/branch.",
            "The frontend shows an order-history list with date, status, and total per order.",
            "Selecting an order shows its line items (product, quantity, unit price).",
            "Empty state is handled gracefully when there are no orders yet."
        )
    },
    @{
        Title    = "Product search & filtering"
        Priority = "Medium"; Size = "M"; Layers = "frontend, API"
        Body     = "As a customer, I want to search and filter the product catalogue so that I can quickly find the products I need instead of scrolling the whole list."
        Ac       = @(
            "The products endpoint accepts query parameters for a text search (name/SKU) and at least one filter (e.g. supplier or price range).",
            "The products page has a search box and filter control wired to the API.",
            "Results update to reflect the active search/filter, and clearing them restores the full list.",
            "Search is case-insensitive and handles ""no results"" cleanly."
        )
    },
    @{
        Title    = "Inventory management / stock levels"
        Priority = "High"; Size = "L"; Layers = "frontend, API, database"
        Body     = "As a branch manager, I want each product to track a stock level so that customers can't order more than is available and staff can see what needs restocking."
        Ac       = @(
            "Products carry a stock/quantity-on-hand value (schema/migration added following existing patterns).",
            "The API returns stock levels and prevents ordering more than the available quantity.",
            "The frontend shows stock status (e.g. in stock / low / out of stock) on product views.",
            "Placing an order decrements the relevant stock, and the change is covered by tests."
        )
    },
    @{
        Title    = "Supplier & branch management view"
        Priority = "Medium"; Size = "M"; Layers = "frontend, API"
        Body     = "As an admin, I want to view and manage suppliers and branches so that I can keep the organisation's supply-chain data accurate, mirroring the existing product admin experience."
        Ac       = @(
            "An admin view lists suppliers (and/or branches) using the existing admin UI patterns.",
            "An admin can create or edit a supplier/branch through the API.",
            "Basic validation is applied (e.g. required name) with consistent error responses.",
            "The view is reachable from the existing admin navigation."
        )
    },
    @{
        Title    = "Delivery tracking & status"
        Priority = "Medium"; Size = "M"; Layers = "frontend, API"
        Body     = "As a branch manager, I want to see deliveries and their status so that I can track incoming stock from suppliers against the orders that need it."
        Ac       = @(
            "The API exposes deliveries with their status and links to the related order details.",
            "The frontend shows a deliveries list with supplier, date, and status.",
            "A delivery's status can be advanced (e.g. pending → shipped → delivered) via the API.",
            "Status changes are validated and reflected in the UI."
        )
    },
    @{
        Title    = "Order status workflow"
        Priority = "Medium"; Size = "S–M"; Layers = "frontend, API"
        Body     = "As a branch manager, I want to move an order through a clear set of statuses so that everyone can see where each order stands from placement to fulfilment."
        Ac       = @(
            "Orders support a defined set of statuses (e.g. pending → confirmed → shipped → delivered / cancelled).",
            "The API only allows valid status transitions and rejects invalid ones with a clear error.",
            "The frontend shows the current status and allows an authorised user to advance it.",
            "The transition rules are covered by unit tests."
        )
    },
    @{
        Title    = "Cart quantity validation"
        Priority = "Low"; Size = "S"; Layers = "frontend, API"
        Body     = "As a customer, I want the cart to reject nonsensical quantities so that I can't accidentally order zero, a negative amount, or a non-numeric quantity."
        Ac       = @(
            "Quantities must be positive integers; invalid values are rejected on both the API and the UI.",
            "The API returns a consistent validation error for bad quantities.",
            "The cart UI shows an inline message and blocks the update/checkout until it's fixed.",
            "The validation logic has unit-test coverage."
        )
    }
)

# ---------------------------------------------------------------------------
# Ensure labels exist
# ---------------------------------------------------------------------------
Write-Host "==> Ensuring labels exist..."
$LabelsEnsured = 0
foreach ($label in $Labels) {
    if ($DryRun) {
        Write-Host "    [dry-run] would ensure label: $($label.Name)"
        $LabelsEnsured++
        continue
    }
    # 'gh label create --force' creates or updates, so it tolerates existing labels.
    gh label create $label.Name --color $label.Color --description $label.Description --force @RepoArgs *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ensured label: $($label.Name)"
        $LabelsEnsured++
    }
    else {
        Write-Warning "could not ensure label '$($label.Name)' (continuing)"
    }
}

# ---------------------------------------------------------------------------
# Fetch existing open issue titles once (for duplicate detection)
# ---------------------------------------------------------------------------
$ExistingTitles = @()
if (-not $DryRun) {
    $raw = gh issue list --state open --limit 200 --json title --jq ".[].title" @RepoArgs 2>$null
    if ($LASTEXITCODE -eq 0 -and $raw) {
        $ExistingTitles = @($raw -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
    }
}

# ---------------------------------------------------------------------------
# Create issues
# ---------------------------------------------------------------------------
Write-Host "==> Seeding backlog issues..."
$Created = 0
$Skipped = 0

foreach ($item in $Items) {
    $prioLabel = "priority:" + $item.Priority.ToLower()

    $acBlock = ($item.Ac | ForEach-Object { "- [ ] $_" }) -join "`n"
    $issueBody = @"
$($item.Body)

**Priority:** $($item.Priority)  |  **Size:** $($item.Size)

**Affected layers:** $($item.Layers)

**Acceptance criteria**

$acBlock

_Seeded from hackathon/backlog.md for Challenge 2._
"@

    if ($ExistingTitles -contains $item.Title) {
        Write-Host "    skip (already exists): $($item.Title)"
        $Skipped++
        continue
    }

    if ($DryRun) {
        Write-Host "    [dry-run] would create issue: $($item.Title)  [backlog, $prioLabel]"
        $Created++
        continue
    }

    gh issue create --title $item.Title --body $issueBody --label "backlog" --label $prioLabel @RepoArgs *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    created: $($item.Title)"
        $Created++
    }
    else {
        Write-Warning "failed to create issue '$($item.Title)' (continuing)"
        $Skipped++
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
$target = if ($Repo -ne "") { $Repo } else { "current repo" }
Write-Host ""
Write-Host "==> Summary ($target)"
if ($DryRun) {
    Write-Host "    Mode:            DRY RUN (no changes made)"
}
Write-Host "    Labels ensured:  $LabelsEnsured"
Write-Host "    Issues created:  $Created"
Write-Host "    Issues skipped:  $Skipped"
Write-Host "Done."
