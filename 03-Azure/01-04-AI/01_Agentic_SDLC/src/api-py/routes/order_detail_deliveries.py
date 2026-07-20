from __future__ import annotations

from fastapi import APIRouter

from models.order_detail_delivery import (
    CreateOrderDetailDeliveryRequest,
    OrderDetailDelivery,
    UpdateOrderDetailDeliveryRequest,
)
from repositories.order_detail_deliveries import OrderDetailDeliveriesRepository
from utils.errors import NotFoundException, ValidationException

router = APIRouter(prefix="/api/order-detail-deliveries", tags=["Order Detail Deliveries"])
repository = OrderDetailDeliveriesRepository()


@router.get("", response_model=list[OrderDetailDelivery])
async def get_all() -> list[OrderDetailDelivery]:
    return await repository.find_all()


@router.get("/{relation_id}", response_model=OrderDetailDelivery)
async def get_by_id(relation_id: int) -> OrderDetailDelivery:
    relation = await repository.find_by_id(relation_id)
    if relation is None:
        raise NotFoundException("OrderDetailDelivery", relation_id)
    return relation


@router.post("", response_model=OrderDetailDelivery, status_code=201)
async def create(request: CreateOrderDetailDeliveryRequest) -> OrderDetailDelivery:
    if request.orderDetailId <= 0 or request.deliveryId <= 0:
        raise ValidationException("orderDetailId and deliveryId are required")
    return await repository.create(request)


@router.put("/{relation_id}", response_model=OrderDetailDelivery)
async def update(relation_id: int, request: UpdateOrderDetailDeliveryRequest) -> OrderDetailDelivery:
    return await repository.update(relation_id, request)


@router.delete("/{relation_id}", status_code=204)
async def delete(relation_id: int) -> None:
    await repository.delete(relation_id)
