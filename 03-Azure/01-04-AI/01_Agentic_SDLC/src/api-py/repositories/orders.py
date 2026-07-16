from __future__ import annotations

from database.sqlite import get_connection
from models.order import CreateOrderRequest, Order, UpdateOrderRequest
from repositories._helpers import build_update_statement, execute_with_changes
from utils.errors import DatabaseException, NotFoundException


class OrdersRepository:
    async def find_all(self) -> list[Order]:
        async with get_connection() as connection:
            cursor = await connection.execute("SELECT * FROM orders ORDER BY order_id;")
            rows = await cursor.fetchall()
        return [self._map_row(row) for row in rows]

    async def find_by_id(self, order_id: int) -> Order | None:
        async with get_connection() as connection:
            cursor = await connection.execute("SELECT * FROM orders WHERE order_id = ?;", (order_id,))
            row = await cursor.fetchone()
        return self._map_row(row) if row else None

    async def create(self, request: CreateOrderRequest) -> Order:
        async with get_connection() as connection:
            cursor = await connection.execute(
                """
                INSERT INTO orders (branch_id, order_date, name, description, status)
                VALUES (?, ?, ?, ?, ?);
                """,
                (
                    request.branchId,
                    request.orderDate,
                    request.name,
                    request.description,
                    request.status,
                ),
            )
            await connection.commit()
            created_id = int(cursor.lastrowid)

        created = await self.find_by_id(created_id)
        if created is None:
            raise DatabaseException("Failed to retrieve created Order")
        return created

    async def update(self, order_id: int, request: UpdateOrderRequest) -> Order:
        updates, parameters = build_update_statement(
            {
                "branchId": "branch_id",
                "orderDate": "order_date",
                "name": "name",
                "description": "description",
                "status": "status",
            },
            request.model_dump(exclude_unset=True),
        )
        parameters.append(order_id)

        async with get_connection() as connection:
            changes = await execute_with_changes(
                connection,
                f"UPDATE orders SET {updates} WHERE order_id = ?;",
                parameters,
            )

        if changes == 0:
            raise NotFoundException("Order", order_id)

        updated = await self.find_by_id(order_id)
        if updated is None:
            raise DatabaseException("Failed to retrieve updated Order")
        return updated

    async def delete(self, order_id: int) -> None:
        async with get_connection() as connection:
            changes = await execute_with_changes(connection, "DELETE FROM orders WHERE order_id = ?;", (order_id,))
        if changes == 0:
            raise NotFoundException("Order", order_id)

    @staticmethod
    def _map_row(row: object) -> Order:
        return Order(
            orderId=row["order_id"],
            branchId=row["branch_id"],
            orderDate=row["order_date"],
            name=row["name"],
            description=row["description"],
            status=row["status"],
        )
