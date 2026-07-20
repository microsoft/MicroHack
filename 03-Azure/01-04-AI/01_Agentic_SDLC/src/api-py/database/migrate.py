from __future__ import annotations

import os
from pathlib import Path

import aiosqlite

from database.sqlite import get_connection


def _resolve_path(relative_path: str) -> Path:
    configured = os.getenv("DB_MIGRATIONS_DIR")
    if configured and "migrations" in relative_path.lower():
        return Path(configured).resolve()
    return (Path.cwd() / relative_path).resolve()


def _parse_migration_version(filename: str) -> int:
    prefix = filename.split("_", 1)[0]
    return int(prefix) if prefix.isdigit() else 0


def _split_sql_script(sql_script: str) -> list[str]:
    return [statement.strip() for statement in sql_script.split(";") if statement.strip()]


async def _execute_sql_statements(connection: aiosqlite.Connection, sql_script: str) -> None:
    statements = _split_sql_script(sql_script)
    await connection.execute("BEGIN;")
    try:
        for statement in statements:
            await connection.execute(statement)
        await connection.commit()
    except Exception:
        await connection.rollback()
        raise


async def _ensure_migrations_table(connection: aiosqlite.Connection) -> None:
    await connection.execute(
        """
        CREATE TABLE IF NOT EXISTS migrations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            version INTEGER NOT NULL,
            filename TEXT NOT NULL UNIQUE,
            applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        """
    )
    await connection.commit()


async def _is_migration_applied(connection: aiosqlite.Connection, filename: str) -> bool:
    cursor = await connection.execute(
        "SELECT COUNT(*) FROM migrations WHERE filename = ?;",
        (filename,),
    )
    row = await cursor.fetchone()
    return bool(row and row[0] > 0)


async def _apply_migrations(connection: aiosqlite.Connection) -> None:
    migrations_dir = _resolve_path("../database/migrations")
    if not migrations_dir.exists():
        raise RuntimeError(f"Migrations directory not found: {migrations_dir}")

    migration_files = sorted(migrations_dir.glob("*.sql"), key=lambda f: f.name)
    for file_path in migration_files:
        if await _is_migration_applied(connection, file_path.name):
            continue

        sql = file_path.read_text(encoding="utf-8")
        await _execute_sql_statements(connection, sql)
        await connection.execute(
            "INSERT INTO migrations (version, filename) VALUES (?, ?);",
            (_parse_migration_version(file_path.name), file_path.name),
        )
        await connection.commit()


async def _seed_if_needed(connection: aiosqlite.Connection) -> None:
    should_seed = True
    try:
        cursor = await connection.execute("SELECT COUNT(*) FROM suppliers;")
        row = await cursor.fetchone()
        should_seed = bool(row and row[0] == 0)
    except (aiosqlite.OperationalError, aiosqlite.DatabaseError):
        should_seed = True

    if not should_seed:
        return

    seed_dir = _resolve_path("../database/seed")
    if not seed_dir.exists():
        return

    seed_files = sorted(seed_dir.glob("*.sql"), key=lambda f: f.name)
    for file_path in seed_files:
        await _execute_sql_statements(connection, file_path.read_text(encoding="utf-8"))


async def initialize_database(seed_on_startup: bool) -> None:
    async with get_connection() as connection:
        await _ensure_migrations_table(connection)
        await _apply_migrations(connection)
        if seed_on_startup:
            await _seed_if_needed(connection)
