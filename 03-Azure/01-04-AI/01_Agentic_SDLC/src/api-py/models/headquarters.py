from __future__ import annotations

from pydantic import BaseModel


class Headquarters(BaseModel):
    headquartersId: int
    name: str
    description: str | None = None
    address: str | None = None
    contactPerson: str | None = None
    email: str | None = None
    phone: str | None = None


class CreateHeadquartersRequest(BaseModel):
    name: str
    description: str | None = None
    address: str | None = None
    contactPerson: str | None = None
    email: str | None = None
    phone: str | None = None


class UpdateHeadquartersRequest(BaseModel):
    name: str | None = None
    description: str | None = None
    address: str | None = None
    contactPerson: str | None = None
    email: str | None = None
    phone: str | None = None


class HeadquartersMetrics(BaseModel):
    score: int
    average: float
    display: str
