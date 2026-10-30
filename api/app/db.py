from __future__ import annotations

from contextlib import contextmanager

from psycopg_pool import ConnectionPool

from app.config import get_config

_pool: ConnectionPool | None = None


def get_pool() -> ConnectionPool:
    """Devuelve el pool, creándolo de forma lazy."""
    global _pool
    if _pool is None:
        cfg = get_config()
        _pool = ConnectionPool(
            conninfo=(
                f"host={cfg.DB_HOST} port={cfg.DB_PORT} "
                f"dbname={cfg.DB_NAME} user={cfg.DB_USER} password={cfg.DB_PASSWORD}"
            ),
            open=False,
        )
        _pool.open()
    return _pool


@contextmanager
def transaccion():
    """Context manager con BEGIN/COMMIT/ROLLBACK explícitos."""
    pool = get_pool()
    with pool.connection() as conn:
        try:
            conn.execute("BEGIN")
            yield conn
            conn.execute("COMMIT")
        except Exception:
            conn.execute("ROLLBACK")
            raise
