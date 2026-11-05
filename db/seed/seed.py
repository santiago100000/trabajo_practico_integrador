from __future__ import annotations

import argparse
import csv
import os
import random
import time
from contextlib import contextmanager
from pathlib import Path

from psycopg_pool import ConnectionPool
from faker import Faker


ROOT = Path(__file__).resolve().parent
CATALOGOS = ROOT / "catalogos"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Carga catálogos semilla en Bodegas del Atuel (Etapa 3, Paso 1)."
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
def pool_owner():
    """Pool de conexiones como owner desde variables de entorno."""
    pool = ConnectionPool(
        conninfo=(
            f"host={os.getenv('DB_HOST', 'localhost')} "
            f"port={int(os.getenv('DB_PORT', '5432'))} "
            f"dbname={os.getenv('POSTGRES_DB', 'bodegas')} "
            f"user={os.getenv('POSTGRES_USER', 'bodegas_owner')} "
            f"password={os.getenv('POSTGRES_PASSWORD', '')}"
        ),
        open=False,
        min_size=1,
        max_size=3,
    )
    pool.open()
    try:
        yield pool
    finally:
        pool.close()


def asegurar_provincia_mendoza(pool) -> int:
    """Crea la provincia Mendoza si no existe y devuelve su id_provincia."""
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO provincia (nombre) VALUES ('Mendoza') "
                "ON CONFLICT (nombre) DO NOTHING "
                "RETURNING id_provincia;"
            )
            fila = cur.fetchone()
            if fila is not None:
                id_provincia = fila[0]
            else:
                cur.execute(
                    "SELECT id_provincia FROM provincia WHERE nombre = 'Mendoza';"
                )
                id_provincia = cur.fetchone()[0]
            conn.commit()
            return id_provincia


def leer_csv(nombre_archivo: str) -> list[dict]:
    """Lee un archivo CSV y devuelve lista de diccionarios."""
    ruta = CATALOGOS / nombre_archivo
    with ruta.open(encoding="utf-8") as f:
        lector = csv.DictReader(f)
        return [dict(fila) for fila in lector]


def cargar_cepas(pool) -> int:
    """Carga cepas desde catalogos/cepas.csv."""
    filas = leer_csv("cepas.csv")
    datos = [(f["nombre"], f["tipo"]) for f in filas if f.get("nombre")]
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO cepa (nombre, tipo) VALUES (%s, %s) "
                "ON CONFLICT (nombre) DO NOTHING;",
                datos,
            )
            conn.commit()
    return len(datos)


def cargar_maridajes(pool) -> int:
    """Carga maridajes desde catalogos/maridajes.csv."""
    filas = leer_csv("maridajes.csv")
    datos = [(f["nombre"], float(f["temperatura_servicio_c"])) for f in filas if f.get("nombre")]
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO maridaje (nombre, temperatura_servicio) VALUES (%s, %s) "
                "ON CONFLICT (nombre) DO NOTHING;",
                datos,
            )
            conn.commit()
    return len(datos)


def cargar_departamentos_mendoza(pool, id_provincia: int) -> int:
    """Carga departamentos de Mendoza desde catalogos/departamentos_mendoza.csv."""
    filas = leer_csv("departamentos_mendoza.csv")
    datos = [(id_provincia, f["departamento"]) for f in filas if f.get("departamento")]
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO departamento (id_provincia, nombre) VALUES (%s, %s) "
                "ON CONFLICT (id_provincia, nombre) DO NOTHING;",
                datos,
            )
            conn.commit()
    return len(datos)


def cargar_localidades(pool, id_provincia: int) -> int:
    """Carga localidades de Mendoza desde catalogos/localidades.csv."""
    filas = leer_csv("localidades.csv")
    datos = [
        (id_provincia, f["nombre"], f["codigo_postal"])
        for f in filas
        if f.get("nombre") and f.get("codigo_postal")
    ]
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO localidad (id_provincia, nombre, codigo_postal, encargado_regional) "
                "VALUES (%s, %s, %s, %s) "
                "ON CONFLICT (id_provincia, nombre, codigo_postal) DO NOTHING;",
                [(d[0], d[1], d[2], "Encargado " + d[1]) for d in datos],
            )
            conn.commit()
    return len(datos)


# Orden de dependencias: tablas sin FK primero, luego las que dependen de provincia.
FUNCIONES_CARGA = [
    ("cepas", cargar_cepas),
    ("maridajes", cargar_maridajes),
    ("departamentos_mendoza", cargar_departamentos_mendoza),
    ("localidades", cargar_localidades),
]


def contar_filas(pool, tabla: str) -> int:
    """Devuelve el conteo de filas de una tabla."""
    with pool.connection() as conn:
        with conn.cursor() as cur:
            cur.execute(f"SELECT COUNT(*) FROM {tabla};")
            return cur.fetchone()[0]


def main() -> None:
    args = parse_args()
    rng = random.Random(args.seed)
    fake = Faker("es_AR")
    Faker.seed(args.seed)

    print(f"Semilla: {args.seed}")
    print("=" * 60)
    print("ETAPA 3 - PASO 1: Carga de catálogos desde CSV (anexo B)")
    print("=" * 60)

    with pool_owner() as pool:
        # 1. Asegurar provincia Mendoza (dependencia de departamento y localidad)
        id_provincia = asegurar_provincia_mendoza(pool)
        print(f"Provincia Mendoza id_provincia={id_provincia} (listada para catálogos)")

        # 2. Cargar cada catálogo en orden de dependencias
        resultados = {}
        for nombre, func in FUNCIONES_CARGA:
            with medir_tiempo(nombre):
                if nombre in ("departamentos_mendoza", "localidades"):
                    cantidad = func(pool, id_provincia)
                else:
                    cantidad = func(pool)
            resultados[nombre] = cantidad
            print(f"  OK: {nombre} -> {cantidad} filas")

        # 3. Consultas de control: conteo por tabla
        print("\n" + "=" * 60)
        print("CONSULTAS DE CONTROL - conteo de filas por tabla")
        print("=" * 60)
        tablas_control = ["provincia", "cepa", "maridaje", "departamento", "localidad"]
        for tabla in tablas_control:
            n = contar_filas(pool, tabla)
            print(f"  {tabla:<20} {n:>6} filas")

    print("\nCarga de catálogos finalizada.")


if __name__ == "__main__":
    main()
