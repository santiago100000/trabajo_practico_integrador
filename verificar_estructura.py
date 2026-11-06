#!/usr/bin/env python3
"""Script de verificación de estructura del proyecto.

Revisa que existan todos los archivos requeridos del proyecto Bodegas del Atuel.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent

ERRORS: list[str] = []
WARNINGS: list[str] = []


def check_exists(ruta: Path, descripcion: str) -> None:
    if not ruta.exists():
        ERRORS.append(f"MISSING: {descripcion} -> {ruta}")


def main() -> int:
    # Raiz
    for nombre in ["README.md", "docker-compose.yml", ".env.example", ".gitignore"]:
        check_exists(ROOT / nombre, nombre)

    # db/migrations (001 a 008)
    for i in range(1, 9):
        nombre = f"{i:03d}_*.sql"
        matches = list((ROOT / "db" / "migrations").glob(nombre))
        if not matches:
            ERRORS.append(f"MISSING migration {nombre} in db/migrations/")

    # db/tests
    check_exists(ROOT / "db" / "tests" / "db_tests.sql", "db/tests/db_tests.sql")

    # db/seed
    for nombre in ["seed.py", "Dockerfile", "requirements.txt", "README.md"]:
        check_exists(ROOT / "db" / "seed" / nombre, f"db/seed/{nombre}")
    for csv in ["cepas.csv", "maridajes.csv", "departamentos_mendoza.csv", "tipos_vino.csv", "presentaciones_ml.csv", "localidades.csv"]:
        check_exists(ROOT / "db" / "seed" / "catalogos" / csv, f"db/seed/catalogos/{csv}")

    # docs
    for nombre in ["README.md", "esquema_relacional.md", "diccionario_datos.md", "normalizacion.md", "decisiones_diseno.md", "trazabilidad.md"]:
        check_exists(ROOT / "docs" / nombre, f"docs/{nombre}")
    check_exists(ROOT / "docs" / "der" / ".gitkeep", "docs/der/.gitkeep")

    if ERRORS:
        print("ERRORS FOUND:")
        for e in ERRORS:
            print(f"  - {e}")
        return 1

    print("Structure OK")
    if WARNINGS:
        print("Warnings:")
        for a in WARNINGS:
            print(f"  - {a}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
