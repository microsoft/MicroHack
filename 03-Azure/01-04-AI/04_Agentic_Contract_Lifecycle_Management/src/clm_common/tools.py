"""Shared function tools for CLM agents.

These plain Python functions become **Foundry function tools**: the Agents SDK
generates a JSON schema from the type hints + docstring, and the model calls
them during a run. Used by the Intake & Drafting agent (Ch2) and the Obligation
& Renewal agent (Ch5).

Both the status lookup (`get_contract_status`) and the renewal scan
(`list_upcoming_renewals`) prefer Azure SQL (if AZURE_SQL_CONNECTION_STRING is
set) and otherwise fall back to src/data/contracts_seed.json so the hack
works with no database. The seed stores renewal/effective dates as day-offsets
from *today*, materialized by `load_contracts()`, so the "upcoming renewals"
demo stays non-empty no matter when the microhack is run.
"""
from __future__ import annotations

import json
from datetime import date, datetime, timedelta
from functools import lru_cache
from pathlib import Path
from typing import Any

from .config import DATA_DIR, settings


@lru_cache(maxsize=1)
def _seed_raw() -> list[dict[str, Any]]:
    data = json.loads((DATA_DIR / "contracts_seed.json").read_text(encoding="utf-8"))
    return data["contracts"]


def _materialize_dates(rec: dict[str, Any]) -> dict[str, Any]:
    """Return a copy of a seed record with absolute effective/renewal dates.

    Seed rows store *relative* day-offsets (``effective_in_days`` /
    ``renewal_in_days``) so the demo dataset stays evergreen: renewal windows are
    always computed relative to ``date.today()``, so "upcoming renewals" is never
    empty no matter when the microhack is run. A row that already carries an
    absolute ``effective_date`` / ``renewal_date`` (legacy schema) is used as-is.
    """
    today = date.today()
    out = {k: v for k, v in rec.items() if not k.endswith("_in_days")}
    if "renewal_date" not in out and "renewal_in_days" in rec:
        out["renewal_date"] = (today + timedelta(days=int(rec["renewal_in_days"]))).isoformat()
    if "effective_date" not in out and "effective_in_days" in rec:
        out["effective_date"] = (today + timedelta(days=int(rec["effective_in_days"]))).isoformat()
    return out


def load_contracts() -> list[dict[str, Any]]:
    """All seed contracts with effective/renewal dates materialized for *today*.

    Shared by the function tools and by ``src/scripts/seed_sql.py`` so the JSON
    fallback and the Azure SQL table are seeded from one evergreen source.
    """
    return [_materialize_dates(c) for c in _seed_raw()]


def _seed() -> list[dict[str, Any]]:
    """Seed contracts with dates materialized relative to today (JSON fallback)."""
    return load_contracts()


def _from_sql(contract_id: str) -> dict[str, Any] | None:
    import pyodbc

    conn = pyodbc.connect(settings.sql_connection_string)
    cur = conn.cursor()
    cur.execute(
        "SELECT contract_id, counterparty, type, status, effective_date, renewal_date, "
        "auto_renew, notice_days, risk, owner FROM dbo.contracts WHERE contract_id = ?",
        contract_id,
    )
    row = cur.fetchone()
    if not row:
        return None
    cols = [d[0] for d in cur.description]
    return {c: (v.isoformat() if isinstance(v, (date, datetime)) else v) for c, v in zip(cols, row)}


def _all_from_sql() -> list[dict[str, Any]] | None:
    """Return every contract row from Azure SQL (or None if the query fails)."""
    import pyodbc

    conn = pyodbc.connect(settings.sql_connection_string)
    cur = conn.cursor()
    cur.execute(
        "SELECT contract_id, counterparty, type, status, effective_date, renewal_date, "
        "auto_renew, notice_days, risk, owner FROM dbo.contracts"
    )
    rows = cur.fetchall()
    if not rows:
        return None
    cols = [d[0] for d in cur.description]
    return [
        {c: (v.isoformat() if isinstance(v, (date, datetime)) else v) for c, v in zip(cols, row)}
        for row in rows
    ]


def _all_contracts() -> tuple[list[dict[str, Any]], str]:
    """Return (contracts, source note), preferring Azure SQL when configured.

    Mirrors ``get_contract_status``' data-source precedence so the renewal tool
    and the status tool always read from the SAME place (SQL if provisioned,
    otherwise the evergreen JSON seed).
    """
    if settings.sql_connection_string:
        try:
            records = _all_from_sql()
        except Exception:  # noqa: BLE001 — fall back to JSON on any DB error
            records = None
        if records:
            return records, "(source: Azure SQL)"
    return load_contracts(), "(source: contracts_seed.json)"


def get_contract_status(contract_id: str) -> str:
    """Look up a contract's status, renewal date, risk and owner by its ID.

    :param contract_id: The contract identifier, e.g. "CT-4821".
    :return: A JSON string with the contract's fields, or an error message if not found.
    """
    contract_id = (contract_id or "").strip().upper()
    record: dict[str, Any] | None = None
    if settings.sql_connection_string:
        try:
            record = _from_sql(contract_id)
        except Exception as exc:  # noqa: BLE001 — fall back to JSON on any DB error
            record = None
            note = f"(SQL lookup failed, used seed data: {exc})"
        else:
            note = "(source: Azure SQL)"
    else:
        note = "(source: contracts_seed.json)"

    if record is None:
        record = next((c for c in _seed() if c["contract_id"].upper() == contract_id), None)

    if record is None:
        known = ", ".join(c["contract_id"] for c in _seed())
        return json.dumps({"error": f"Contract '{contract_id}' not found.", "known_ids": known})

    return json.dumps({**record, "_note": note})


def list_upcoming_renewals(within_days: int = 90) -> str:
    """List contracts whose renewal date falls within the next N days.

    :param within_days: Look-ahead window in days (default 90).
    :return: A JSON string with a list of contracts sorted by renewal date.
    """
    today = date.today()
    contracts, source = _all_contracts()
    rows = []
    for c in contracts:
        try:
            rdate = datetime.strptime(str(c["renewal_date"])[:10], "%Y-%m-%d").date()
        except (KeyError, ValueError, TypeError):
            continue
        delta = (rdate - today).days
        if 0 <= delta <= within_days:
            rows.append({**c, "days_until_renewal": delta})
    rows.sort(key=lambda r: r["days_until_renewal"])
    return json.dumps(
        {"within_days": within_days, "count": len(rows), "contracts": rows, "_source": source}
    )
