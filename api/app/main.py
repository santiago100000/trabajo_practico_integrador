from __future__ import annotations

from fastapi import APIRouter
from fastapi.responses import JSONResponse

from app.db import transaccion


router = APIRouter()


@router.get("/salud", tags=["salud"])
async def salud():
    """Estado de la API y de la base de datos.

    Devuelve 200 con {"api":"ok","db":"ok"} cuando conecta.
    Si la base no conecta (etapa inicial: stubs de migración, rol app_rw
    inexistente), devuelve 503 con mensaje claro.
    """
    try:
        with transaccion() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                cur.fetchone()
        return {"api": "ok", "db": "ok"}
    except Exception as exc:  # noqa: BLE001
        return JSONResponse(
            status_code=503,
            content={
                "api": "ok",
                "db": "error",
                "detalle": str(exc),
            },
        )


# -----------------------------------------------------------------------------
# Endpoints mínimos del PDF (como TODO por sección del enunciado)
# -----------------------------------------------------------------------------
# GET    /clientes        → listar clientes
# POST   /clientes        → crear cliente (I1)
# GET    /clientes/{id}   → obtener cliente
# PUT    /clientes/{id}   → actualizar cliente (U1)
# DELETE /clientes/{id}   → eliminar cliente (D1)
#
# GET    /vinos           → listar vinos
# POST   /vinos           → crear vino (I2)
# ...
#
# POST   /comprobantes    → crear comprobante (I3, invoca sp_procesar_ingreso)
# POST   /transferencias  → transferir stock (I4, invoca sp_procesar_transferencia)
# ...
# -----------------------------------------------------------------------------
