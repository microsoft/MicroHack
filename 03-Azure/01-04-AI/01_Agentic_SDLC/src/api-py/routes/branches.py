from __future__ import annotations

from fastapi import APIRouter

from models.branch import Branch, CreateBranchRequest, UpdateBranchRequest
from repositories.branches import BranchesRepository
from utils.errors import NotFoundException, ValidationException

router = APIRouter(prefix="/api/branches", tags=["Branches"])
repository = BranchesRepository()


@router.get("", response_model=list[Branch])
async def get_all() -> list[Branch]:
    return await repository.find_all()


@router.get("/{branch_id}", response_model=Branch)
async def get_by_id(branch_id: int) -> Branch:
    branch = await repository.find_by_id(branch_id)
    if branch is None:
        raise NotFoundException("Branch", branch_id)
    return branch


@router.post("", response_model=Branch, status_code=201)
async def create(request: CreateBranchRequest) -> Branch:
    if not request.name.strip():
        raise ValidationException("name is required")
    if request.headquartersId <= 0:
        raise ValidationException("headquartersId is required")
    return await repository.create(request)


@router.put("/{branch_id}", response_model=Branch)
async def update(branch_id: int, request: UpdateBranchRequest) -> Branch:
    return await repository.update(branch_id, request)


@router.delete("/{branch_id}", status_code=204)
async def delete(branch_id: int) -> None:
    await repository.delete(branch_id)
