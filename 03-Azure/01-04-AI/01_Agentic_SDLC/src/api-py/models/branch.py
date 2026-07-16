from __future__ import annotations

from pydantic import BaseModel


class Branch(BaseModel):
    branchId: int
    headquartersId: int
    name: str
    description: str | None = None
    address: str | None = None
    contactPerson: str | None = None
    email: str | None = None
    phone: str | None = None


class CreateBranchRequest(BaseModel):
    headquartersId: int
    name: str
    description: str | None = None
    address: str | None = None
    contactPerson: str | None = None
    email: str | None = None
    phone: str | None = None


class UpdateBranchRequest(BaseModel):
    headquartersId: int | None = None
    name: str | None = None
    description: str | None = None
    address: str | None = None
    contactPerson: str | None = None
    email: str | None = None
    phone: str | None = None
