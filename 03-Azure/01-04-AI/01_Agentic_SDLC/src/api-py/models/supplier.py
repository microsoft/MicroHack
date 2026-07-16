from __future__ import annotations

from pydantic import BaseModel


class Supplier(BaseModel):
    supplierId: int
    name: str
    description: str | None = None
    contactPerson: str | None = None
    email: str | None = None
    phone: str | None = None
    active: bool
    verified: bool


class CreateSupplierRequest(BaseModel):
    name: str
    description: str | None = None
    contactPerson: str | None = None
    email: str | None = None
    phone: str | None = None
    active: bool = True
    verified: bool = False


class UpdateSupplierRequest(BaseModel):
    name: str | None = None
    description: str | None = None
    contactPerson: str | None = None
    email: str | None = None
    phone: str | None = None
    active: bool | None = None
    verified: bool | None = None
