"""Cosmos DB-backed governed inventory store.

``labautomation`` provisions a per-attendee **Azure Cosmos DB for NoSQL** account
(serverless) with the database and containers already created, and grants the
attendee **data-plane RBAC** (Cosmos DB Built-in Data Contributor). This module:

* connects **keyless** with ``DefaultAzureCredential`` (the same identity the agents
  use for Foundry — no keys, no connection strings),
* **seeds** the containers from the bundled Zava seed data on first run (idempotent,
  data-plane upserts only — the containers themselves are created by labautomation),
* caches the mostly-static reference data in memory for fast tool calls, and
* persists **orders** as real writes — so the replenishment agent's approved action
  is a genuine, durable side effect, not a simulation.

The store is created lazily via :func:`get_store` so the planner console still loads
before you have configured ``COSMOS_ENDPOINT`` / run ``az login``.
"""

from __future__ import annotations

import json
import math
import uuid
from datetime import date, timedelta
from pathlib import Path
from typing import Any

from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential

import config

DATA_DIR = Path(__file__).parent / "data"

# Anchor date for the derived 6-week demand history — matches the seed logic.
_ANCHOR_MONDAY = date(2026, 7, 6)
_DEMAND_WEEKS = 6

# Containers created by labautomation (name -> partition key path). The app never
# creates these (that is a control-plane op); it only reads/writes items.
CONTAINERS = ("products", "stores", "suppliers", "signals", "inventory", "demand", "orders")


def _load(name: str) -> list[dict[str, Any]]:
    with open(DATA_DIR / f"{name}.json", "r", encoding="utf-8") as handle:
        return json.load(handle)


def _derive_inventory(
    products: list[dict[str, Any]],
    stores: list[dict[str, Any]],
    overrides: dict[tuple[str, str], int],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for p in products:
        reorder_point = math.ceil(p["baseWeeklyUnits"] * p["leadTimeDays"] / 7)
        safety_stock = math.ceil(reorder_point * 0.5)
        for s in stores:
            on_hand = p["baseOnHand"] * 4 if s["type"] == "warehouse" else p["baseOnHand"]
            on_hand = overrides.get((p["productId"], s["storeId"]), on_hand)
            rows.append(
                {
                    "productId": p["productId"],
                    "storeId": s["storeId"],
                    "onHand": int(on_hand),
                    "reorderPoint": int(reorder_point),
                    "safetyStock": int(safety_stock),
                }
            )
    return rows


def _derive_demand(
    products: list[dict[str, Any]], stores: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    retail = [s for s in stores if s["type"] == "retail"]
    rows: list[dict[str, Any]] = []
    for p in products:
        per_store = max(1, round(p["baseWeeklyUnits"] / len(retail)))
        for week in range(_DEMAND_WEEKS):
            week_start = _ANCHOR_MONDAY - timedelta(weeks=(_DEMAND_WEEKS - 1 - week))
            for s in retail:
                units = per_store
                if p["category"] == "outdoor_power_tools" and week >= _DEMAND_WEEKS - 2:
                    units = round(units * 1.4)
                rows.append(
                    {
                        "productId": p["productId"],
                        "storeId": s["storeId"],
                        "weekStart": week_start.isoformat(),
                        "units": int(units),
                    }
                )
    return rows


class InventoryStore:
    """Connects to the provisioned Cosmos DB, seeds it once, and serves the tools."""

    def __init__(self) -> None:
        client = CosmosClient(
            config.require_cosmos_endpoint(), credential=DefaultAzureCredential()
        )
        db = client.get_database_client(config.COSMOS_DATABASE)
        self._c = {name: db.get_container_client(name) for name in CONTAINERS}

        self._seed_if_empty()

        # Cache the mostly-static reference data for fast tool calls.
        self.products = self._all("products")
        self.stores = self._all("stores")
        self.suppliers = self._all("suppliers")
        self.signals = self._all("signals")
        self.inventory = self._all("inventory")
        self.demand = self._all("demand")

    # ---- Cosmos helpers --------------------------------------------------

    def _all(self, name: str) -> list[dict[str, Any]]:
        return list(self._c[name].read_all_items())

    def _seed_if_empty(self) -> None:
        """One-time, idempotent seed. Data-plane upserts only (containers exist)."""
        if any(True for _ in self._c["products"].read_all_items()):
            return

        products = _load("products")
        stores = _load("stores")
        suppliers = _load("suppliers")
        signals = _load("external_signals")
        overrides = {(o["productId"], o["storeId"]): o["onHand"] for o in _load("inventory_overrides")}
        orders_seed = _load("replenishment_orders")

        inventory = _derive_inventory(products, stores, overrides)
        demand = _derive_demand(products, stores)

        for p in products:
            self._c["products"].upsert_item({**p, "id": p["productId"]})
        for s in stores:
            self._c["stores"].upsert_item({**s, "id": s["storeId"]})
        for s in suppliers:
            self._c["suppliers"].upsert_item({**s, "id": s["supplierId"]})
        for s in signals:
            self._c["signals"].upsert_item({**s, "id": s["signalId"]})
        for r in inventory:
            self._c["inventory"].upsert_item({**r, "id": f'{r["productId"]}_{r["storeId"]}'})
        for d in demand:
            self._c["demand"].upsert_item({**d, "id": f'{d["productId"]}_{d["storeId"]}_{d["weekStart"]}'})
        for o in orders_seed:
            self._c["orders"].upsert_item({**o, "id": o["orderId"]})

    # ---- Lookups used by the function tools ------------------------------

    def product(self, sku: str) -> dict[str, Any] | None:
        return next((p for p in self.products if p["productId"] == sku), None)

    def product_by_name(self, name: str) -> dict[str, Any] | None:
        needle = name.strip().lower()
        return next((p for p in self.products if p["name"].lower() == needle), None)

    def store(self, store_id: str) -> dict[str, Any] | None:
        return next((s for s in self.stores if s["storeId"] == store_id), None)

    def supplier(self, supplier_id: str) -> dict[str, Any] | None:
        return next((s for s in self.suppliers if s["supplierId"] == supplier_id), None)

    def average_daily_sales(self, sku: str) -> float:
        latest = max((d["weekStart"] for d in self.demand if d["productId"] == sku), default=None)
        if latest is None:
            return 0.0
        weekly = sum(d["units"] for d in self.demand if d["productId"] == sku and d["weekStart"] == latest)
        return round(weekly / 7, 2)

    def inventory_rows(
        self, sku: str | None = None, location: str | None = None
    ) -> list[dict[str, Any]]:
        rows = self.inventory
        if sku:
            rows = [r for r in rows if r["productId"] == sku]
        if location:
            rows = [r for r in rows if r["storeId"] == location]
        return rows

    def append_order(self, order: dict[str, Any]) -> None:
        """Persist an approved purchase order to Cosmos (a real, durable write)."""
        self._c["orders"].upsert_item({**order, "id": order["orderId"]})

    def append_signal(self, signal: dict[str, Any]) -> dict[str, Any]:
        """Persist a new external market signal to Cosmos (a real, durable write).

        This is the *independent insert* that the change-feed watcher reacts to — the
        console's Inject control, an MCP client, or any other system can call it, and
        the event-driven loop (Challenge 6) kicks off automatically. Returns the stored
        document (with the ``id``/``signalId`` it was given).
        """
        signal_id = signal.get("signalId") or signal.get("id") or f"SIG-{uuid.uuid4().hex[:8].upper()}"
        doc = {**signal, "id": signal_id, "signalId": signal_id}
        self._c["signals"].upsert_item(doc)
        self.signals.append(doc)  # keep the in-memory cache the tools read consistent
        return doc

    def signals_container(self) -> Any:
        """Return the raw ``signals`` container client (used by the change-feed watcher)."""
        return self._c["signals"]

    @property
    def orders(self) -> list[dict[str, Any]]:
        """Read the live order book from Cosmos (survives restarts)."""
        return list(self._c["orders"].read_all_items())


# Lazy singleton so importing this module never forces a Cosmos connection —
# the planner console loads before COSMOS_ENDPOINT / az login are configured.
_STORE: InventoryStore | None = None


def get_store() -> InventoryStore:
    global _STORE
    if _STORE is None:
        _STORE = InventoryStore()
    return _STORE
