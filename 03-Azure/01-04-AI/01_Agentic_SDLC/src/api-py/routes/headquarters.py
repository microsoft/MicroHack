from __future__ import annotations

from fastapi import APIRouter

from models.headquarters import (
    CreateHeadquartersRequest,
    Headquarters,
    HeadquartersMetrics,
    UpdateHeadquartersRequest,
)
from repositories.headquarters import HeadquartersRepository
from utils.errors import NotFoundException, ValidationException

router = APIRouter(prefix="/api/headquarters", tags=["Headquarters"])
repository = HeadquartersRepository()


@router.get("", response_model=list[Headquarters])
async def get_all() -> list[Headquarters]:
    return await repository.find_all()


@router.get("/{headquarters_id}", response_model=Headquarters)
async def get_by_id(headquarters_id: int) -> Headquarters:
    headquarters = await repository.find_by_id(headquarters_id)
    if headquarters is None:
        raise NotFoundException("Headquarters", headquarters_id)
    return headquarters


@router.get("/{headquarters_id}/metrics", response_model=HeadquartersMetrics)
async def get_metrics(headquarters_id: int) -> HeadquartersMetrics:
    return await repository.get_metrics(headquarters_id)


@router.get("/{headquarters_id}/label")
async def get_label(headquarters_id: int) -> dict[str, str]:
    headquarters = await repository.find_by_id(headquarters_id)
    if headquarters is None:
        raise NotFoundException("Headquarters", headquarters_id)
    return {"label": f"Location:{headquarters.name}City:Country:"}


@router.post("", response_model=Headquarters, status_code=201)
async def create(request: CreateHeadquartersRequest) -> Headquarters:
    if not request.name.strip():
        raise ValidationException("name is required")
    return await repository.create(request)


@router.put("/{headquarters_id}", response_model=Headquarters)
async def update(headquarters_id: int, request: UpdateHeadquartersRequest) -> Headquarters:
    return await repository.update(headquarters_id, request)


@router.delete("/{headquarters_id}", status_code=204)
async def delete(headquarters_id: int) -> None:
    await repository.delete(headquarters_id)
