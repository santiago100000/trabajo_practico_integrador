from __future__ import annotations

from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse
import psycopg

# Mapeo SQLSTATE -> código HTTP (según tabla del PDF)
SQLSTATE_TO_HTTP = {
    "23505": 409,   # unique_violation
    "23503": 409,   # foreign_key_violation
    "23514": 422,   # check_violation
    "23502": 422,   # not_null_violation
    "P0001": 409,   # plpgsql exception (regla de negocio)
    "22P02": 400,   # invalid_text_representation
    "40001": 503,   # serialization_failure
    "40P01": 503,   # deadlock_detected
}


async def db_error_handler(request: Request, exc: Exception) -> JSONResponse:
    """Traduce errores de psycopg a respuestas HTTP."""
    sqlstate = getattr(exc, "sqlstate", None) or getattr(
        getattr(exc, "__cause__", None), "sqlstate", None
    )
    status_code = SQLSTATE_TO_HTTP.get(str(sqlstate), 500)
    detail = str(exc)
    return JSONResponse(status_code=status_code, content={"detail": detail})


def register_error_handlers(app) -> None:
    app.add_exception_handler(psycopg.Error, db_error_handler)
