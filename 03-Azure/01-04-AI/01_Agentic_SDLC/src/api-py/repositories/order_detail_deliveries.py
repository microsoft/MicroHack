from __future__ import annotations

from database.sqlite import get_connection
from models.order_detail_delivery import (
    CreateOrderDetailDeliveryRequest,
    OrderDetailDelivery,
    UpdateOrderDetailDeliveryRequest,
)
from repositories._helpers import build_update_statement, execute_with_changes
from utils.errors import DatabaseException, NotFoundException


class OrderDetailDeliveriesRepository:
    async def find_all(self) -> list[OrderDetailDelivery]:
        async with get_connection() as connection:
            cursor = await connection.execute(
                "SELECT * FROM order_detail_deliveries ORDER BY order_detail_delivery_id;"
            )
            rows = await cursor.fetchall()
        return [self._map_row(row) for row in rows]

    async def find_by_id(self, relation_id: int) -> OrderDetailDelivery | None:
        async with get_connection() as connection:
            cursor = await connection.execute(
                "SELECT * FROM order_detail_deliveries WHERE order_detail_delivery_id = ?;",
                (relation_id,),
            )
            row = await cursor.fetchone()
        return self._map_row(row) if row else None

    async def create(self, request: CreateOrderDetailDeliveryRequest) -> OrderDetailDelivery:
        async with get_connection() as connection:
            cursor = await connection.execute(
                """
                INSERT INTO order_detail_deliveries (order_detail_id, delivery_id, quantity, notes)
                VALUES (?, ?, ?, ?);
                """,
                (request.orderDetailId, request.deliveryId, request.quantity, request.notes),
            )
            await connection.commit()
            created_id = int(cursor.lastrowid)

        created = await self.find_by_id(created_id)
        if created is None:
            raise DatabaseException("Failed to retrieve created OrderDetailDelivery")
        return created

    async def update(self, relation_id: int, request: UpdateOrderDetailDeliveryRequest) -> OrderDetailDelivery:
        updates, parameters = build_update_statement(
            {
                "orderDetailId": "order_detail_id",
                "deliveryId": "delivery_id",
                "quantity": "quantity",
                "notes": "notes",
            },
            request.model_dump(exclude_unset=True),
        )
        parameters.append(relation_id)

        async with get_connection() as connection:
            changes = await execute_with_changes(
                connection,
                f"UPDATE order_detail_deliveries SET {updates} WHERE order_detail_delivery_id = ?;",
                parameters,
            )
        if changes == 0:
            raise NotFoundException("OrderDetailDelivery", relation_id)

        updated = await self.find_by_id(relation_id)
        if updated is None:
            raise DatabaseException("Failed to retrieve updated OrderDetailDelivery")
        return updated

    async def delete(self, relation_id: int) -> None:
        async with get_connection() as connection:
            changes = await execute_with_changes(
                connection,
                "DELETE FROM order_detail_deliveries WHERE order_detail_delivery_id = ?;",
                (relation_id,),
            )
        if changes == 0:
            raise NotFoundException("OrderDetailDelivery", relation_id)

    @staticmethod
    def _map_row(row: object) -> OrderDetailDelivery:
        return OrderDetailDelivery(
            orderDetailDeliveryId=row["order_detail_delivery_id"],
            orderDetailId=row["order_detail_id"],
            deliveryId=row["delivery_id"],
            quantity=row["quantity"],
            notes=row["notes"],
        )
