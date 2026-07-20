from __future__ import annotations

from pydantic import BaseModel


class OrderDetailDelivery(BaseModel):
    orderDetailDeliveryId: int
    orderDetailId: int
    deliveryId: int
    quantity: int
    notes: str | None = None


class CreateOrderDetailDeliveryRequest(BaseModel):
    orderDetailId: int
    deliveryId: int
    quantity: int
    notes: str | None = None


class UpdateOrderDetailDeliveryRequest(BaseModel):
    orderDetailId: int | None = None
    deliveryId: int | None = None
    quantity: int | None = None
    notes: str | None = None
