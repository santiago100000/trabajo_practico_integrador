from __future__ import annotations

import argparse
import os
import random
import time
from contextlib import contextmanager

from faker import Faker
import psycopg


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Carga catálogos semilla en Bodegas del Atuel."
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=int(os.getenv("SEED", "42")),
        help="Semilla aleatoria (default: env SEED o 42)",
    )
    return parser.parse_args()


def medir_tiempo(nombre: str):
    """Context manager para medir y reportar el tiempo de un bloque."""
    inicio = time.perf_counter()

    class _Cronometro:
        def __enter__(self):
            return self

        def __exit__(self, *exc):
            print(f"[{nombre}] {time.perf_counter() - inicio:.4f} segundos")

    return _Cronometro()


@contextmanager
def conexion_owner():
    """Conexión como owner desde variables de entorno."""
    conn = psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "5432")),
        dbname=os.getenv("POSTGRES_DB", "bodegas"),
        user=os.getenv("POSTGRES_USER", "bodegas_owner"),
        password=os.getenv("POSTGRES_PASSWORD", ""),
    )
    try:
        yield conn
    finally:
        conn.close()


def cargar_cepas(conn, fake: Faker, rng: random.Random) -> None:
    """TODO: insertar filas de la tabla cepas a partir de catalogos/cepas.csv."""
    raise NotImplementedError("Pendiente: grupo implementa la carga")


def cargar_maridajes(conn, fake: Faker, rng: random.Random) -> None:
    """TODO: insertar filas de la tabla maridajes."""
    raise NotImplementedError("Pendiente: grupo implementa la carga")


def cargar_departamentos_mendoza(conn, fake: Faker, rng: random.Random) -> None:
    """TODO: insertar filas de la tabla departamentos_mendoza."""
    raise NotImplementedError("Pendiente: grupo implementa la carga")


def cargar_tipos_vino(conn, fake: Faker, rng: random.Random) -> None:
    """TODO: insertar filas de la tabla tipos_vino."""
    raise NotImplementedError("Pendiente: grupo implementa la carga")


def cargar_presentaciones_ml(conn, fake: Faker, rng: random.Random) -> None:
    """TODO: insertar filas de la tabla presentaciones_ml."""
    raise NotImplementedError("Pendiente: grupo implementa la carga")


def cargar_localidades(conn, fake: Faker, rng: random.Random) -> None:
    """TODO: insertar filas de la tabla localidades (códigos postales reales)."""
    raise NotImplementedError("Pendiente: grupo implementa la carga")


# Orden de dependencias: tablas sin FK primero, luego las que dependen de ellas.
FUNCIONES_CARGA = [
    cargar_cepas,
    cargar_maridajes,
    cargar_departamentos_mendoza,
    cargar_tipos_vino,
    cargar_presentaciones_ml,
    cargar_localidades,
]


def main() -> None:
    args = parse_args()
    rng = random.Random(args.seed)
    fake = Faker("es_AR")
    Faker.seed(args.seed)

    print(f"Semilla: {args.seed}")

    with conexion_owner() as conn:
        for func in FUNCIONES_CARGA:
            nombre = func.__name__
            with medir_tiempo(nombre):
                func(conn, fake, rng)
            conn.commit()
            print(f"  OK: {nombre}")

    print("Carga de semillas finalizada.")


if __name__ == "__main__":
    main()
