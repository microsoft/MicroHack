from __future__ import annotations

from pydantic import BaseModel


class Delivery(BaseModel):
    deliveryId: int
    supplierId: int
    deliveryDate: str
    name: str
    description: str | None = None
    status: str


class CreateDeliveryRequest(BaseModel):
    supplierId: int
    deliveryDate: str
    name: str
    description: str | None = None
    status: str = "pending"


class UpdateDeliveryRequest(BaseModel):
    supplierId: int | None = None
    deliveryDate: str | None = None
    name: str | None = None
    description: str | None = None
    status: str | None = None


class UpdateDeliveryStatusRequest(BaseModel):
    status: str
    deliveryPartner: str | None = None
