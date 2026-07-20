from __future__ import annotations

from typing import Any

import aiosqlite

from utils.errors import ValidationException


def build_update_statement(field_to_column: dict[str, str], updates: dict[str, Any]) -> tuple[str, list[Any]]:
    provided = {k: v for k, v in updates.items() if v is not None}
    if not provided:
        raise ValidationException("No fields provided for update")

    assignments: list[str] = []
    parameters: list[Any] = []
    for field_name, value in provided.items():
        assignments.append(f"{field_to_column[field_name]} = ?")
        parameters.append(value)

    return ", ".join(assignments), parameters


async def execute_with_changes(
    connection: aiosqlite.Connection,
    sql: str,
    params: tuple[Any, ...] | list[Any] = (),
) -> int:
    cursor = await connection.execute(sql, params)
    await connection.commit()
    if cursor.rowcount is not None and cursor.rowcount >= 0:
        return cursor.rowcount

    changes_cursor = await connection.execute("SELECT changes();")
    row = await changes_cursor.fetchone()
    return int(row[0]) if row else 0
