from __future__ import annotations

from fastapi import APIRouter

from models.order_detail import CreateOrderDetailRequest, OrderDetail, UpdateOrderDetailRequest
from repositories.order_details import OrderDetailsRepository
from utils.errors import NotFoundException, ValidationException

router = APIRouter(prefix="/api/order-details", tags=["Order Details"])
repository = OrderDetailsRepository()


@router.get("", response_model=list[OrderDetail])
async def get_all() -> list[OrderDetail]:
    return await repository.find_all()


@router.get("/{order_detail_id}", response_model=OrderDetail)
async def get_by_id(order_detail_id: int) -> OrderDetail:
    order_detail = await repository.find_by_id(order_detail_id)
    if order_detail is None:
        raise NotFoundException("OrderDetail", order_detail_id)
    return order_detail


@router.post("", response_model=OrderDetail, status_code=201)
async def create(request: CreateOrderDetailRequest) -> OrderDetail:
    if request.orderId <= 0 or request.productId <= 0:
        raise ValidationException("orderId and productId are required")
    return await repository.create(request)


@router.put("/{order_detail_id}", response_model=OrderDetail)
async def update(order_detail_id: int, request: UpdateOrderDetailRequest) -> OrderDetail:
    return await repository.update(order_detail_id, request)


@router.delete("/{order_detail_id}", status_code=204)
async def delete(order_detail_id: int) -> None:
    await repository.delete(order_detail_id)
