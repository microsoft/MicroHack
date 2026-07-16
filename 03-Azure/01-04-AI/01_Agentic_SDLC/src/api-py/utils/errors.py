from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


class ApiException(Exception):
    def __init__(self, message: str, code: str, status_code: int) -> None:
        super().__init__(message)
        self.code = code
        self.status_code = status_code


class NotFoundException(ApiException):
    def __init__(self, entity: str, entity_id: int) -> None:
        super().__init__(f"{entity} with ID {entity_id} not found", "NOT_FOUND", 404)


class ValidationException(ApiException):
    def __init__(self, message: str) -> None:
        super().__init__(f"Validation error: {message}", "VALIDATION_ERROR", 400)


class ConflictException(ApiException):
    def __init__(self, message: str) -> None:
        super().__init__(f"Conflict: {message}", "CONFLICT", 409)


class DatabaseException(ApiException):
    def __init__(self, message: str) -> None:
        super().__init__(message, "DATABASE_ERROR", 500)


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(ApiException)
    async def handle_api_exception(_: Request, exc: ApiException) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"error": {"code": exc.code, "message": str(exc)}},
        )

    @app.exception_handler(Exception)
    async def handle_unexpected_exception(_: Request, __: Exception) -> JSONResponse:
        return JSONResponse(
            status_code=500,
            content={
                "error": {
                    "code": "INTERNAL_ERROR",
                    "message": "An unexpected error occurred",
                }
            },
        )
