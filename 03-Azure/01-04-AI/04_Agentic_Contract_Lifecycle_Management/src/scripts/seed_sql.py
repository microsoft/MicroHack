#!/usr/bin/env python
"""Challenge 1 (optional) — seed the contract-status table in Azure SQL.

Only needed if you deployed Azure SQL (`./labautomation/deploy.sh --with-sql`). If
AZURE_SQL_CONNECTION_STRING is empty, the contract-status function tool falls
back to src/data/contracts_seed.json, so this step is optional for the hack.

Run:  python src/scripts/seed_sql.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from clm_common.config import settings  # noqa: E402
from clm_common.tools import load_contracts  # noqa: E402

DDL = """
IF OBJECT_ID('dbo.contracts', 'U') IS NULL
CREATE TABLE dbo.contracts (
    contract_id   NVARCHAR(20) PRIMARY KEY,
    counterparty  NVARCHAR(100),
    type          NVARCHAR(10),
    status        NVARCHAR(20),
    effective_date DATE,
    renewal_date  DATE,
    auto_renew    BIT,
    notice_days   INT,
    risk          NVARCHAR(10),
    owner         NVARCHAR(100)
);
"""

MERGE = """
MERGE dbo.contracts AS t
USING (SELECT ? AS contract_id) AS s ON t.contract_id = s.contract_id
WHEN MATCHED THEN UPDATE SET
    counterparty=?, type=?, status=?, effective_date=?, renewal_date=?,
    auto_renew=?, notice_days=?, risk=?, owner=?
WHEN NOT MATCHED THEN INSERT
    (contract_id, counterparty, type, status, effective_date, renewal_date, auto_renew, notice_days, risk, owner)
    VALUES (?,?,?,?,?,?,?,?,?,?);
"""


def main() -> None:
    if not settings.sql_connection_string:
        print("· AZURE_SQL_CONNECTION_STRING not set — nothing to seed (tool uses the JSON fallback).")
        return

    import pyodbc

    rows = load_contracts()  # evergreen: dates materialized relative to today
    conn = pyodbc.connect(settings.sql_connection_string)
    cur = conn.cursor()
    cur.execute(DDL)
    for c in rows:
        vals = (
            c["counterparty"], c["type"], c["status"], c["effective_date"], c["renewal_date"],
            int(c["auto_renew"]), c["notice_days"], c["risk"], c["owner"],
        )
        cur.execute(MERGE, (c["contract_id"], *vals, c["contract_id"], *vals))
    conn.commit()
    print(f"  ✓ seeded {len(rows)} rows into dbo.contracts")


if __name__ == "__main__":
    main()
