from __future__ import annotations

import os
from contextlib import asynccontextmanager
from pathlib import Path

import aiosqlite


def _resolve_db_file() -> str:
    db_file = os.getenv("DB_FILE", "./data/app.db")
    if db_file != ":memory:":
        db_path = Path(db_file).resolve()
        db_path.parent.mkdir(parents=True, exist_ok=True)
        return str(db_path)
    return db_file


@asynccontextmanager
async def get_connection() -> aiosqlite.Connection:
    connection = await aiosqlite.connect(_resolve_db_file())
    connection.row_factory = aiosqlite.Row
    await connection.execute("PRAGMA foreign_keys = ON;")
    await connection.execute("PRAGMA journal_mode = WAL;")
    await connection.execute("PRAGMA busy_timeout = 30000;")
    try:
        yield connection
    finally:
        await connection.close()
