from __future__ import annotations

import os
from functools import lru_cache


class Config:
    DB_HOST: str = os.getenv("DB_HOST", "localhost")
    DB_PORT: int = int(os.getenv("DB_PORT", "5432"))
    DB_NAME: str = os.getenv("DB_NAME", "bodegas")
    DB_USER: str = os.getenv("DB_USER", "app_rw")
    DB_PASSWORD: str = os.getenv("DB_PASSWORD", "")
    API_PORT: int = int(os.getenv("API_PORT", "8000"))
    CORS_ORIGINS: str = os.getenv("CORS_ORIGINS", "http://localhost:8080")


@lru_cache
def get_config() -> Config:
    return Config()
