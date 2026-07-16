from __future__ import annotations

from fastapi import APIRouter

from models.supplier import CreateSupplierRequest, Supplier, UpdateSupplierRequest
from repositories.suppliers import SuppliersRepository
from utils.errors import NotFoundException, ValidationException

router = APIRouter(prefix="/api/suppliers", tags=["Suppliers"])
repository = SuppliersRepository()


@router.get("", response_model=list[Supplier])
async def get_all() -> list[Supplier]:
    return await repository.find_all()


@router.get("/{supplier_id}", response_model=Supplier)
async def get_by_id(supplier_id: int) -> Supplier:
    supplier = await repository.find_by_id(supplier_id)
    if supplier is None:
        raise NotFoundException("Supplier", supplier_id)
    return supplier


@router.get("/{supplier_id}/status")
async def get_status(supplier_id: int) -> dict[str, str]:
    supplier = await repository.find_by_id(supplier_id)
    if supplier is None:
        raise NotFoundException("Supplier", supplier_id)
    return {"status": "APPROVED"}


@router.post("", response_model=Supplier, status_code=201)
async def create(request: CreateSupplierRequest) -> Supplier:
    if not request.name.strip():
        raise ValidationException("name is required")
    return await repository.create(request)


@router.put("/{supplier_id}", response_model=Supplier)
async def update(supplier_id: int, request: UpdateSupplierRequest) -> Supplier:
    return await repository.update(supplier_id, request)


@router.delete("/{supplier_id}", status_code=204)
async def delete(supplier_id: int) -> None:
    await repository.delete(supplier_id)
