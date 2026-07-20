from __future__ import annotations

from pydantic import BaseModel


class Order(BaseModel):
    orderId: int
    branchId: int
    orderDate: str
    name: str
    description: str | None = None
    status: str


class CreateOrderRequest(BaseModel):
    branchId: int
    orderDate: str
    name: str
    description: str | None = None
    status: str = "pending"


class UpdateOrderRequest(BaseModel):
    branchId: int | None = None
    orderDate: str | None = None
    name: str | None = None
    description: str | None = None
    status: str | None = None
