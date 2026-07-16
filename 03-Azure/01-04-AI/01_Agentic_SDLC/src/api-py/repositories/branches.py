from __future__ import annotations

from database.sqlite import get_connection
from models.branch import Branch, CreateBranchRequest, UpdateBranchRequest
from repositories._helpers import build_update_statement, execute_with_changes
from utils.errors import DatabaseException, NotFoundException


class BranchesRepository:
    async def find_all(self) -> list[Branch]:
        async with get_connection() as connection:
            cursor = await connection.execute("SELECT * FROM branches ORDER BY branch_id;")
            rows = await cursor.fetchall()
        return [self._map_row(row) for row in rows]

    async def find_by_id(self, branch_id: int) -> Branch | None:
        async with get_connection() as connection:
            cursor = await connection.execute("SELECT * FROM branches WHERE branch_id = ?;", (branch_id,))
            row = await cursor.fetchone()
        return self._map_row(row) if row else None

    async def create(self, request: CreateBranchRequest) -> Branch:
        async with get_connection() as connection:
            cursor = await connection.execute(
                """
                INSERT INTO branches (headquarters_id, name, description, address, contact_person, email, phone)
                VALUES (?, ?, ?, ?, ?, ?, ?);
                """,
                (
                    request.headquartersId,
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
            raise DatabaseException("Failed to retrieve created Branch")
        return created

    async def update(self, branch_id: int, request: UpdateBranchRequest) -> Branch:
        updates, parameters = build_update_statement(
            {
                "headquartersId": "headquarters_id",
                "name": "name",
                "description": "description",
                "address": "address",
                "contactPerson": "contact_person",
                "email": "email",
                "phone": "phone",
            },
            request.model_dump(exclude_unset=True),
        )
        parameters.append(branch_id)

        async with get_connection() as connection:
            changes = await execute_with_changes(
                connection,
                f"UPDATE branches SET {updates} WHERE branch_id = ?;",
                parameters,
            )

        if changes == 0:
            raise NotFoundException("Branch", branch_id)

        updated = await self.find_by_id(branch_id)
        if updated is None:
            raise DatabaseException("Failed to retrieve updated Branch")
        return updated

    async def delete(self, branch_id: int) -> None:
        async with get_connection() as connection:
            changes = await execute_with_changes(
                connection,
                "DELETE FROM branches WHERE branch_id = ?;",
                (branch_id,),
            )
        if changes == 0:
            raise NotFoundException("Branch", branch_id)

    @staticmethod
    def _map_row(row: object) -> Branch:
        return Branch(
            branchId=row["branch_id"],
            headquartersId=row["headquarters_id"],
            name=row["name"],
            description=row["description"],
            address=row["address"],
            contactPerson=row["contact_person"],
            email=row["email"],
            phone=row["phone"],
        )
