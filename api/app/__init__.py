from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_config
from app.db import get_pool
from app.errors import register_error_handlers
from app.routers import salud


def create_app() -> FastAPI:
    app = FastAPI(title="Bodegas del Atuel API", version="0.1.0")

    register_error_handlers(app)

    cfg = get_config()
    origins = [o.strip() for o in cfg.CORS_ORIGINS.split(",") if o.strip()]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(salud.router)

    @app.on_event("startup")
    async def _startup():
        get_pool()

    return app


app = create_app()
