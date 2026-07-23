"""Function tools the hosted agents call to reason over the governed inventory data.

Each function is a plain, typed, documented Python callable. When registered with
the Foundry Agent Service ``FunctionTool``, the SDK introspects the type hints and
docstrings to build the tool schema the model sees — so keep the signatures and
docstrings meaningful.

The data lives in a per-attendee **Cosmos DB** (provisioned by labautomation, read
via ``inventory_store.get_store``). Every tool is read-only *except*
``submit_purchase_order``, which performs a real, durable write to the ``orders``
container — gated behind human approval by the orchestrator.
"""

from __future__ import annotations

import json
from datetime import date

from inventory_store import get_store

# Flag a product/location as CRITICAL when on-hand is below safety stock.
CRITICAL = "CRITICAL"
AT_RISK = "AT_RISK"
OK = "OK"


def _status(on_hand: int, reorder_point: int, safety_stock: int) -> str:
    if on_hand < safety_stock:
        return CRITICAL
    if on_hand <= reorder_point:
        return AT_RISK
    return OK


def query_inventory(sku: str = "", location: str = "") -> str:
    """Return current stock rows (onHand, reorderPoint, safetyStock, status).

    :param sku: Optional product id such as ``P004`` to filter by a single SKU.
    :param location: Optional store/warehouse id such as ``ST03`` or ``WH01``.
    :return: JSON array of inventory rows, each enriched with a stock ``status``.
    """
    store = get_store()
    rows = []
    for r in store.inventory_rows(sku=sku or None, location=location or None):
        product = store.product(r["productId"])
        location_doc = store.store(r["storeId"])
        rows.append(
            {
                "sku": r["productId"],
                "productName": product["name"] if product else r["productId"],
                "location": r["storeId"],
                "locationName": location_doc["name"] if location_doc else r["storeId"],
                "onHand": r["onHand"],
                "reorderPoint": r["reorderPoint"],
                "safetyStock": r["safetyStock"],
                "status": _status(r["onHand"], r["reorderPoint"], r["safetyStock"]),
            }
        )
    return json.dumps(rows)


def list_low_stock() -> str:
    """Return every product/location that is AT_RISK or CRITICAL on stock.

    A row is CRITICAL when onHand < safetyStock and AT_RISK when onHand is at or
    below the reorderPoint. Use this to find replenishment candidates.

    :return: JSON array of at-risk / critical inventory rows.
    """
    rows = json.loads(query_inventory())
    flagged = [r for r in rows if r["status"] in (CRITICAL, AT_RISK)]
    flagged.sort(key=lambda r: (r["status"] != CRITICAL, r["onHand"]))
    return json.dumps(flagged)


def get_product(sku: str = "", name: str = "") -> str:
    """Look up a product's catalogue details, including unit cost and lead time.

    :param sku: Product id such as ``P005``.
    :param name: Product name such as ``Chainsaw 16in`` (used if sku is empty).
    :return: JSON object with the product and its supplier, or an ``error`` field.
    """
    store = get_store()
    product = store.product(sku) if sku else None
    if product is None and name:
        product = store.product_by_name(name)
    if product is None:
        return json.dumps({"error": f"No product found for sku='{sku}' name='{name}'"})
    supplier = store.supplier(product.get("supplierId", ""))
    return json.dumps({**product, "supplier": supplier})


def get_external_signals(category: str = "", region: str = "") -> str:
    """Return pre-loaded market signals (weather, search trends, competitor, news).

    These stand in for a live web-signal feed so the demand-sensing agent works
    even without the optional Web Search tool.

    :param category: Optional product category to filter by, e.g. ``outdoor_power_tools``.
    :param region: Optional region filter, e.g. ``Pacific Northwest``.
    :return: JSON array of matching external signals.
    """
    signals = get_store().signals
    if category:
        signals = [s for s in signals if category in s.get("affectedCategories", "")]
    if region:
        signals = [s for s in signals if region.lower() in s.get("region", "").lower()]
    return json.dumps(signals)


def calc_reorder(sku: str, location: str = "") -> str:
    """Compute the suggested reorder quantity for a SKU using the planning rule.

    reorder_qty = max(0, average_daily_sales * 30 - current_stock)

    :param sku: Product id such as ``P004``.
    :param location: Optional location id; if omitted, computed per location.
    :return: JSON array of reorder suggestions with the numbers used.
    """
    store = get_store()
    avg_daily = store.average_daily_sales(sku)
    thirty_day_demand = round(avg_daily * 30)
    suggestions = []
    for r in store.inventory_rows(sku=sku, location=location or None):
        reorder_qty = max(0, thirty_day_demand - r["onHand"])
        suggestions.append(
            {
                "sku": sku,
                "location": r["storeId"],
                "currentStock": r["onHand"],
                "avgDailySales": avg_daily,
                "thirtyDayDemand": thirty_day_demand,
                "suggestedReorderQty": reorder_qty,
                "priority": _status(r["onHand"], r["reorderPoint"], r["safetyStock"]),
            }
        )
    return json.dumps(suggestions)


def submit_purchase_order(items_json: str, approved_by: str = "Planner") -> str:
    """ACT: persist an approved purchase order to Cosmos and return a confirmation.

    This is the only side-effecting tool and it performs a REAL, durable write to the
    ``orders`` container. The orchestrator only calls it AFTER a human approves the
    proposal, so it is the human-in-the-loop gate's payload.

    :param items_json: JSON array of line items, each ``{"sku","location","quantity"}``.
    :param approved_by: Name of the human approver, recorded on the order.
    :return: JSON confirmation with the generated PO number and stored order.
    """
    try:
        items = json.loads(items_json) if isinstance(items_json, str) else items_json
    except json.JSONDecodeError as exc:
        return json.dumps({"error": f"items_json was not valid JSON: {exc}"})

    store = get_store()
    today = date.today()
    seq = sum(1 for o in store.orders if o["orderId"].startswith(f"PO-{today:%Y%m%d}")) + 1
    order = {
        "orderId": f"PO-{today:%Y%m%d}-{seq:03d}",
        "type": "purchase",
        "status": "submitted",
        "requestedBy": "Replenishment Action Agent",
        "approvedBy": approved_by,
        "createdDate": today.isoformat(),
        "items": items,
    }
    store.append_order(order)
    return json.dumps(
        {
            "confirmation": f"Purchase order {order['orderId']} submitted and recorded in the order book.",
            "order": order,
        }
    )


# Read-only tools every agent may safely use.
READ_TOOLS = [query_inventory, list_low_stock, get_product, get_external_signals, calc_reorder]

# The single side-effecting tool, kept separate so the runtime can gate it.
ACT_TOOLS = [submit_purchase_order]
