from __future__ import annotations

import os
from functools import lru_cache
from typing import Any

import jwt
from fastapi import Header, HTTPException, status
from jwt import PyJWKClient


def _truthy(value: str | None) -> bool:
    return value is not None and value.lower() in {"1", "true", "yes", "y", "on"}


def auth_enabled() -> bool:
    if _truthy(os.getenv("DEV_BYPASS_AUTH")):
        return False
    return _truthy(os.getenv("AUTH_ENABLED")) or bool(os.getenv("ENTRA_AUDIENCE"))


def expected_issuer() -> str:
    issuer = os.getenv("ENTRA_ISSUER")
    if issuer:
        return issuer.rstrip("/")
    tenant_id = os.getenv("ENTRA_TENANT_ID", "common")
    return f"https://login.microsoftonline.com/{tenant_id}/v2.0"


def expected_audience() -> list[str]:
    audience = os.getenv("ENTRA_AUDIENCE")
    if not audience:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="auth_misconfigured")
    audiences = [audience]
    if audience.startswith("api://"):
        audiences.append(audience.removeprefix("api://"))
    return audiences


def required_scope() -> str | None:
    return os.getenv("ENTRA_REQUIRED_SCOPE") or os.getenv("MCP_REQUIRED_SCOPE")


def required_role() -> str | None:
    """App role accepted for application (managed-identity) callers."""
    return os.getenv("ENTRA_REQUIRED_ROLE")


@lru_cache(maxsize=4)
def _jwks_client(jwks_url: str) -> PyJWKClient:
    return PyJWKClient(jwks_url)


def _jwks_url() -> str:
    configured = os.getenv("ENTRA_JWKS_URL")
    if configured:
        return configured
    issuer = expected_issuer()
    base = issuer.removesuffix("/v2.0")
    return f"{base}/discovery/v2.0/keys"


async def validate_bearer_token(authorization: str | None = Header(default=None)) -> dict[str, Any]:
    if not auth_enabled():
        return {"auth": "bypassed" if _truthy(os.getenv("DEV_BYPASS_AUTH")) else "disabled"}
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="missing_bearer_token")
    token = authorization.split(" ", 1)[1].strip()
    try:
        signing_key = _jwks_client(_jwks_url()).get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=expected_audience(),
            issuer=expected_issuer(),
            options={"require": ["exp", "iat"]},
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid_token") from exc
    scope = required_scope()
    role = required_role()
    if scope or role:
        scopes = set(str(claims.get("scp", "")).split())
        roles = set(claims.get("roles", []) or [])
        allowed = (
            (scope is not None and (scope in scopes or scope in roles))
            or (role is not None and role in roles)
        )
        if not allowed:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="insufficient_scope")
    return {"auth": "entra", "oid": claims.get("oid"), "tid": claims.get("tid")}
