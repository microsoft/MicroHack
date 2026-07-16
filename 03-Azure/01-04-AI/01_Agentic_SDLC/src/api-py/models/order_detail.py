from __future__ import annotations

from pydantic import BaseModel


class OrderDetail(BaseModel):
    orderDetailId: int
    orderId: int
    productId: int
    quantity: int
    unitPrice: float
    notes: str | None = None


class CreateOrderDetailRequest(BaseModel):
    orderId: int
    productId: int
    quantity: int
    unitPrice: float
    notes: str | None = None


class UpdateOrderDetailRequest(BaseModel):
    orderId: int | None = None
    productId: int | None = None
    quantity: int | None = None
    unitPrice: float | None = None
    notes: str | None = None
