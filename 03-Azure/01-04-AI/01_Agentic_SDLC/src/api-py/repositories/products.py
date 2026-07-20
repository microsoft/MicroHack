from __future__ import annotations

from database.sqlite import get_connection
from models.product import CreateProductRequest, Product, UpdateProductRequest
from repositories._helpers import build_update_statement, execute_with_changes
from utils.errors import DatabaseException, NotFoundException


class ProductsRepository:
    async def find_all(self) -> list[Product]:
        async with get_connection() as connection:
            cursor = await connection.execute("SELECT * FROM products ORDER BY product_id;")
            rows = await cursor.fetchall()
        return [self._map_row(row) for row in rows]

    async def find_by_id(self, product_id: int) -> Product | None:
        async with get_connection() as connection:
            cursor = await connection.execute(
                "SELECT * FROM products WHERE product_id = ?;",
                (product_id,),
            )
            row = await cursor.fetchone()
        return self._map_row(row) if row else None

    async def create(self, request: CreateProductRequest) -> Product:
        async with get_connection() as connection:
            cursor = await connection.execute(
                """
                INSERT INTO products (supplier_id, name, description, price, sku, unit, img_name, discount)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?);
                """,
                (
                    request.supplierId,
                    request.name,
                    request.description,
                    request.price,
                    request.sku,
                    request.unit,
                    request.imgName,
                    request.discount,
                ),
            )
            await connection.commit()
            created_id = int(cursor.lastrowid)

        created = await self.find_by_id(created_id)
        if created is None:
            raise DatabaseException("Failed to retrieve created Product")
        return created

    async def update(self, product_id: int, request: UpdateProductRequest) -> Product:
        updates, parameters = build_update_statement(
            {
                "supplierId": "supplier_id",
                "name": "name",
                "description": "description",
                "price": "price",
                "sku": "sku",
                "unit": "unit",
                "imgName": "img_name",
                "discount": "discount",
            },
            request.model_dump(exclude_unset=True),
        )
        parameters.append(product_id)

        async with get_connection() as connection:
            changes = await execute_with_changes(
                connection,
                f"UPDATE products SET {updates} WHERE product_id = ?;",
                parameters,
            )

        if changes == 0:
            raise NotFoundException("Product", product_id)

        updated = await self.find_by_id(product_id)
        if updated is None:
            raise DatabaseException("Failed to retrieve updated Product")
        return updated

    async def delete(self, product_id: int) -> None:
        async with get_connection() as connection:
            changes = await execute_with_changes(
                connection,
                "DELETE FROM products WHERE product_id = ?;",
                (product_id,),
            )
        if changes == 0:
            raise NotFoundException("Product", product_id)

    @staticmethod
    def _map_row(row: object) -> Product:
        return Product(
            productId=row["product_id"],
            supplierId=row["supplier_id"],
            name=row["name"],
            description=row["description"],
            price=row["price"],
            sku=row["sku"],
            unit=row["unit"],
            imgName=row["img_name"],
            discount=row["discount"],
        )
