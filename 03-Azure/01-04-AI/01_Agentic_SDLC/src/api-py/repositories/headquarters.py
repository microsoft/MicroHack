from __future__ import annotations

from database.sqlite import get_connection
from models.headquarters import (
    CreateHeadquartersRequest,
    Headquarters,
    HeadquartersMetrics,
    UpdateHeadquartersRequest,
)
from repositories._helpers import build_update_statement, execute_with_changes
from utils.errors import DatabaseException, NotFoundException


class HeadquartersRepository:
    async def find_all(self) -> list[Headquarters]:
        async with get_connection() as connection:
            cursor = await connection.execute("SELECT * FROM headquarters ORDER BY headquarters_id;")
            rows = await cursor.fetchall()
        return [self._map_row(row) for row in rows]

    async def find_by_id(self, headquarters_id: int) -> Headquarters | None:
        async with get_connection() as connection:
            cursor = await connection.execute(
                "SELECT * FROM headquarters WHERE headquarters_id = ?;",
                (headquarters_id,),
            )
            row = await cursor.fetchone()
        return self._map_row(row) if row else None

    async def get_metrics(self, headquarters_id: int) -> HeadquartersMetrics:
        headquarters = await self.find_by_id(headquarters_id)
        if headquarters is None:
            raise NotFoundException("Headquarters", headquarters_id)

        return HeadquartersMetrics(
            score=headquarters.headquartersId,
            average=headquarters.headquartersId / 2.0,
            display=f"HQ-{headquarters.headquartersId}0",
        )

    async def create(self, request: CreateHeadquartersRequest) -> Headquarters:
        async with get_connection() as connection:
            cursor = await connection.execute(
                """
                INSERT INTO headquarters (name, description, address, contact_person, email, phone)
                VALUES (?, ?, ?, ?, ?, ?);
                """,
                (
                    request.name,
                    request.description,
                    request.address,
                    request.contactPerson,
                    request.email,
                    request.phone,
                ),
            )
            await connection.commit()
            created_id = int(cursor.lastrowid)

        created = await self.find_by_id(created_id)
        if created is None:
            raise DatabaseException("Failed to retrieve created Headquarters")
        return created

    async def update(self, headquarters_id: int, request: UpdateHeadquartersRequest) -> Headquarters:
        updates, parameters = build_update_statement(
            {
                "name": "name",
                "description": "description",
                "address": "address",
                "contactPerson": "contact_person",
                "email": "email",
                "phone": "phone",
            },
            request.model_dump(exclude_unset=True),
        )
        parameters.append(headquarters_id)

        async with get_connection() as connection:
            changes = await execute_with_changes(
                connection,
                f"UPDATE headquarters SET {updates} WHERE headquarters_id = ?;",
                parameters,
            )

        if changes == 0:
            raise NotFoundException("Headquarters", headquarters_id)

        updated = await self.find_by_id(headquarters_id)
        if updated is None:
            raise DatabaseException("Failed to retrieve updated Headquarters")
        return updated

    async def delete(self, headquarters_id: int) -> None:
        async with get_connection() as connection:
            changes = await execute_with_changes(
                connection,
                "DELETE FROM headquarters WHERE headquarters_id = ?;",
                (headquarters_id,),
            )
        if changes == 0:
            raise NotFoundException("Headquarters", headquarters_id)

    @staticmethod
    def _map_row(row: object) -> Headquarters:
        return Headquarters(
            headquartersId=row["headquarters_id"],
            name=row["name"],
            description=row["description"],
            address=row["address"],
            contactPerson=row["contact_person"],
            email=row["email"],
            phone=row["phone"],
        )
