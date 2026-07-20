from __future__ import annotations

import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database.migrate import initialize_database
from routes.branches import router as branches_router
from routes.deliveries import router as deliveries_router
from routes.headquarters import router as headquarters_router
from routes.order_detail_deliveries import router as order_detail_deliveries_router
from routes.order_details import router as order_details_router
from routes.orders import router as orders_router
from routes.products import router as products_router
from routes.suppliers import router as suppliers_router
from utils.errors import register_exception_handlers

app = FastAPI(title="OctoSupply API (Python)", version="1.0.0")

configured_origins = os.getenv("API_CORS_ORIGINS")
if configured_origins:
    allow_origins = [origin.strip() for origin in configured_origins.split(",") if origin.strip()]
    allow_origin_regex = None
else:
    allow_origins = [
        "http://localhost:5137",
        "http://127.0.0.1:5137",
    ]
    allow_origin_regex = r"^https://.*\.(app\.github\.dev|azurecontainerapps\.io)$"

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_origin_regex=allow_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

register_exception_handlers(app)

app.include_router(deliveries_router)
app.include_router(order_detail_deliveries_router)
app.include_router(products_router)
app.include_router(order_details_router)
app.include_router(orders_router)
app.include_router(branches_router)
app.include_router(headquarters_router)
app.include_router(suppliers_router)


@app.on_event("startup")
async def startup() -> None:
    await initialize_database(seed_on_startup=True)


@app.get("/")
async def root() -> str:
    return "Hello, world!"
