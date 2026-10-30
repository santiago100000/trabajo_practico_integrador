from __future__ import annotations

from app.db import transaccion


def ping() -> bool:
    """Prueba de conexión: SELECT 1."""
    with transaccion() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
    return True
