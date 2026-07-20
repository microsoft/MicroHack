from __future__ import annotations

from database.sqlite import get_connection
from models.supplier import CreateSupplierRequest, Supplier, UpdateSupplierRequest
from repositories._helpers import build_update_statement, execute_with_changes
from utils.errors import DatabaseException, NotFoundException


class SuppliersRepository:
    async def find_all(self) -> list[Supplier]:
        async with get_connection() as connection:
            cursor = await connection.execute("SELECT * FROM suppliers ORDER BY supplier_id;")
            rows = await cursor.fetchall()
        return [self._map_row(row) for row in rows]

    async def find_by_id(self, supplier_id: int) -> Supplier | None:
        async with get_connection() as connection:
            cursor = await connection.execute(
                "SELECT * FROM suppliers WHERE supplier_id = ?;",
                (supplier_id,),
            )
            row = await cursor.fetchone()
        return self._map_row(row) if row else None

    async def create(self, request: CreateSupplierRequest) -> Supplier:
        async with get_connection() as connection:
            cursor = await connection.execute(
                """
                INSERT INTO suppliers (name, description, contact_person, email, phone, active, verified)
                VALUES (?, ?, ?, ?, ?, ?, ?);
                """,
                (
                    request.name,
                    request.description,
                    request.contactPerson,
                    request.email,
                    request.phone,
                    int(request.active),
                    int(request.verified),
                ),
            )
            await connection.commit()
            created_id = int(cursor.lastrowid)

        created = await self.find_by_id(created_id)
        if created is None:
            raise DatabaseException("Failed to retrieve created Supplier")
        return created

    async def update(self, supplier_id: int, request: UpdateSupplierRequest) -> Supplier:
        updates, parameters = build_update_statement(
            {
                "name": "name",
                "description": "description",
                "contactPerson": "contact_person",
                "email": "email",
                "phone": "phone",
                "active": "active",
                "verified": "verified",
            },
            request.model_dump(exclude_unset=True),
        )
        parameters = [int(p) if isinstance(p, bool) else p for p in parameters]
        parameters.append(supplier_id)

        async with get_connection() as connection:
            changes = await execute_with_changes(
                connection,
                f"UPDATE suppliers SET {updates} WHERE supplier_id = ?;",
                parameters,
            )

        if changes == 0:
            raise NotFoundException("Supplier", supplier_id)

        updated = await self.find_by_id(supplier_id)
        if updated is None:
            raise DatabaseException("Failed to retrieve updated Supplier")
        return updated

    async def delete(self, supplier_id: int) -> None:
        async with get_connection() as connection:
            changes = await execute_with_changes(
                connection,
                "DELETE FROM suppliers WHERE supplier_id = ?;",
                (supplier_id,),
            )
        if changes == 0:
            raise NotFoundException("Supplier", supplier_id)

    @staticmethod
    def _map_row(row: object) -> Supplier:
        return Supplier(
            supplierId=row["supplier_id"],
            name=row["name"],
            description=row["description"],
            contactPerson=row["contact_person"],
            email=row["email"],
            phone=row["phone"],
            active=bool(row["active"]),
            verified=bool(row["verified"]),
        )
