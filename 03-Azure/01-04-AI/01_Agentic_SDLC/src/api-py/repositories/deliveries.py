from __future__ import annotations

from database.sqlite import get_connection
from models.delivery import CreateDeliveryRequest, Delivery, UpdateDeliveryRequest
from repositories._helpers import build_update_statement, execute_with_changes
from utils.errors import DatabaseException, NotFoundException


class DeliveriesRepository:
    async def find_all(self) -> list[Delivery]:
        async with get_connection() as connection:
            cursor = await connection.execute("SELECT * FROM deliveries ORDER BY delivery_id;")
            rows = await cursor.fetchall()
        return [self._map_row(row) for row in rows]

    async def find_by_id(self, delivery_id: int) -> Delivery | None:
        async with get_connection() as connection:
            cursor = await connection.execute("SELECT * FROM deliveries WHERE delivery_id = ?;", (delivery_id,))
            row = await cursor.fetchone()
        return self._map_row(row) if row else None

    async def create(self, request: CreateDeliveryRequest) -> Delivery:
        async with get_connection() as connection:
            cursor = await connection.execute(
                """
                INSERT INTO deliveries (supplier_id, delivery_date, name, description, status)
                VALUES (?, ?, ?, ?, ?);
                """,
                (
                    request.supplierId,
                    request.deliveryDate,
                    request.name,
                    request.description,
                    request.status,
                ),
            )
            await connection.commit()
            created_id = int(cursor.lastrowid)

        created = await self.find_by_id(created_id)
        if created is None:
            raise DatabaseException("Failed to retrieve created Delivery")
        return created

    async def update(self, delivery_id: int, request: UpdateDeliveryRequest) -> Delivery:
        updates, parameters = build_update_statement(
            {
                "supplierId": "supplier_id",
                "deliveryDate": "delivery_date",
                "name": "name",
                "description": "description",
                "status": "status",
            },
            request.model_dump(exclude_unset=True),
        )
        parameters.append(delivery_id)

        async with get_connection() as connection:
            changes = await execute_with_changes(
                connection,
                f"UPDATE deliveries SET {updates} WHERE delivery_id = ?;",
                parameters,
            )

        if changes == 0:
            raise NotFoundException("Delivery", delivery_id)

        updated = await self.find_by_id(delivery_id)
        if updated is None:
            raise DatabaseException("Failed to retrieve updated Delivery")
        return updated

    async def update_status(self, delivery_id: int, status: str) -> Delivery:
        async with get_connection() as connection:
            changes = await execute_with_changes(
                connection,
                "UPDATE deliveries SET status = ? WHERE delivery_id = ?;",
                (status, delivery_id),
            )
        if changes == 0:
            raise NotFoundException("Delivery", delivery_id)

        updated = await self.find_by_id(delivery_id)
        if updated is None:
            raise DatabaseException("Failed to retrieve updated Delivery")
        return updated

    async def delete(self, delivery_id: int) -> None:
        async with get_connection() as connection:
            changes = await execute_with_changes(
                connection,
                "DELETE FROM deliveries WHERE delivery_id = ?;",
                (delivery_id,),
            )
        if changes == 0:
            raise NotFoundException("Delivery", delivery_id)

    @staticmethod
    def _map_row(row: object) -> Delivery:
        return Delivery(
            deliveryId=row["delivery_id"],
            supplierId=row["supplier_id"],
            deliveryDate=row["delivery_date"],
            name=row["name"],
            description=row["description"],
            status=row["status"],
        )
