from __future__ import annotations

from fastapi import APIRouter

from models.delivery import (
    CreateDeliveryRequest,
    Delivery,
    UpdateDeliveryRequest,
    UpdateDeliveryStatusRequest,
)
from repositories.deliveries import DeliveriesRepository
from utils.errors import NotFoundException, ValidationException

router = APIRouter(prefix="/api/deliveries", tags=["Deliveries"])
repository = DeliveriesRepository()


@router.get("", response_model=list[Delivery])
async def get_all() -> list[Delivery]:
    return await repository.find_all()


@router.get("/{delivery_id}", response_model=Delivery)
async def get_by_id(delivery_id: int) -> Delivery:
    delivery = await repository.find_by_id(delivery_id)
    if delivery is None:
        raise NotFoundException("Delivery", delivery_id)
    return delivery


@router.post("", response_model=Delivery, status_code=201)
async def create(request: CreateDeliveryRequest) -> Delivery:
    if not request.name.strip():
        raise ValidationException("name is required")
    if not request.deliveryDate.strip():
        raise ValidationException("deliveryDate is required")
    return await repository.create(request)


@router.put("/{delivery_id}", response_model=Delivery)
async def update(delivery_id: int, request: UpdateDeliveryRequest) -> Delivery:
    return await repository.update(delivery_id, request)


@router.put("/{delivery_id}/status")
async def update_status(
    delivery_id: int,
    request: UpdateDeliveryStatusRequest,
) -> Delivery | dict[str, object]:
    if not request.status.strip():
        raise ValidationException("status is required")
    updated_delivery = await repository.update_status(delivery_id, request.status)
    if request.deliveryPartner and request.deliveryPartner.strip():
        return {"delivery": updated_delivery, "commandOutput": ""}
    return updated_delivery


@router.delete("/{delivery_id}", status_code=204)
async def delete(delivery_id: int) -> None:
    await repository.delete(delivery_id)
