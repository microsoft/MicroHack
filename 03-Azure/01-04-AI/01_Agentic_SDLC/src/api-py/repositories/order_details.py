from __future__ import annotations

from database.sqlite import get_connection
from models.order_detail import CreateOrderDetailRequest, OrderDetail, UpdateOrderDetailRequest
from repositories._helpers import build_update_statement, execute_with_changes
from utils.errors import DatabaseException, NotFoundException


class OrderDetailsRepository:
    async def find_all(self) -> list[OrderDetail]:
        async with get_connection() as connection:
            cursor = await connection.execute("SELECT * FROM order_details ORDER BY order_detail_id;")
            rows = await cursor.fetchall()
        return [self._map_row(row) for row in rows]

    async def find_by_id(self, order_detail_id: int) -> OrderDetail | None:
        async with get_connection() as connection:
            cursor = await connection.execute(
                "SELECT * FROM order_details WHERE order_detail_id = ?;",
                (order_detail_id,),
            )
            row = await cursor.fetchone()
        return self._map_row(row) if row else None

    async def create(self, request: CreateOrderDetailRequest) -> OrderDetail:
        async with get_connection() as connection:
            cursor = await connection.execute(
                """
                INSERT INTO order_details (order_id, product_id, quantity, unit_price, notes)
                VALUES (?, ?, ?, ?, ?);
                """,
                (
                    request.orderId,
                    request.productId,
                    request.quantity,
                    request.unitPrice,
                    request.notes,
                ),
            )
            await connection.commit()
            created_id = int(cursor.lastrowid)

        created = await self.find_by_id(created_id)
        if created is None:
            raise DatabaseException("Failed to retrieve created OrderDetail")
        return created

    async def update(self, order_detail_id: int, request: UpdateOrderDetailRequest) -> OrderDetail:
        updates, parameters = build_update_statement(
            {
                "orderId": "order_id",
                "productId": "product_id",
                "quantity": "quantity",
                "unitPrice": "unit_price",
                "notes": "notes",
            },
            request.model_dump(exclude_unset=True),
        )
        parameters.append(order_detail_id)

        async with get_connection() as connection:
            changes = await execute_with_changes(
                connection,
                f"UPDATE order_details SET {updates} WHERE order_detail_id = ?;",
                parameters,
            )

        if changes == 0:
            raise NotFoundException("OrderDetail", order_detail_id)

        updated = await self.find_by_id(order_detail_id)
        if updated is None:
            raise DatabaseException("Failed to retrieve updated OrderDetail")
        return updated

    async def delete(self, order_detail_id: int) -> None:
        async with get_connection() as connection:
            changes = await execute_with_changes(
                connection,
                "DELETE FROM order_details WHERE order_detail_id = ?;",
                (order_detail_id,),
            )
        if changes == 0:
            raise NotFoundException("OrderDetail", order_detail_id)

    @staticmethod
    def _map_row(row: object) -> OrderDetail:
        return OrderDetail(
            orderDetailId=row["order_detail_id"],
            orderId=row["order_id"],
            productId=row["product_id"],
            quantity=row["quantity"],
            unitPrice=row["unit_price"],
            notes=row["notes"],
        )
