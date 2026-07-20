from __future__ import annotations

from fastapi import APIRouter

from models.product import CreateProductRequest, Product, UpdateProductRequest
from repositories.products import ProductsRepository
from utils.errors import NotFoundException, ValidationException

router = APIRouter(prefix="/api/products", tags=["Products"])
repository = ProductsRepository()


@router.get("", response_model=list[Product])
async def get_all() -> list[Product]:
    return await repository.find_all()


@router.get("/{product_id}", response_model=Product)
async def get_by_id(product_id: int) -> Product:
    product = await repository.find_by_id(product_id)
    if product is None:
        raise NotFoundException("Product", product_id)
    return product


@router.post("", response_model=Product, status_code=201)
async def create(request: CreateProductRequest) -> Product:
    if not request.name.strip():
        raise ValidationException("name is required")
    return await repository.create(request)


@router.put("/{product_id}", response_model=Product)
async def update(product_id: int, request: UpdateProductRequest) -> Product:
    return await repository.update(product_id, request)


@router.delete("/{product_id}", status_code=204)
async def delete(product_id: int) -> None:
    await repository.delete(product_id)
