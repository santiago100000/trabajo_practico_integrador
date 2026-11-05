#!/usr/bin/env python3
"""Script de verificación de estructura del scaffolding.

Revisa que existan todos los archivos requeridos y que los .sql de migración
solo contengan comentarios (pueden ejecutarse sin error sobre una base vacía).
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent

ERRORES: list[str] = []
AVISOS: list[str] = []


def existe(ruta: Path, descripcion: str) -> None:
    if not ruta.exists():
        ERRORES.append(f"FALTA: {descripcion} -> {ruta}")


def solo_comentarios(ruta: Path, descripcion: str) -> None:
    """Verifica que el archivo solo tenga comentarios (para migraciones de stub)."""
    if not ruta.exists():
        return
    texto = ruta.read_text(encoding="utf-8")
    lineas = [l.strip() for l in texto.splitlines() if l.strip()]
    solo = all(l.startswith("--") for l in lineas)
    if not solo:
        AVISOS.append(f"{descripcion} ({ruta}) contiene DDL real (esperado en etapa 1)")


def main() -> int:
    # Raiz
    for nombre in ["README.md", "docker-compose.yml", ".env.example", ".gitignore"]:
        existe(ROOT / nombre, nombre)

    # db/migrations
    for i in range(1, 9):
        nombre = f"{i:03d}_*.sql"
        matches = list((ROOT / "db" / "migrations").glob(nombre))
        if not matches:
            ERRORES.append(f"FALTA migracion {nombre} en db/migrations/")
        else:
            solo_comentarios(matches[0], f"migracion {matches[0].name}")

    # db/tests
    existe(ROOT / "db" / "tests" / "db_tests.sql", "db/tests/db_tests.sql")

    # consultas
    for nombre in ["insert.sql", "update.sql", "delete.sql", "select.sql"]:
        existe(ROOT / "consultas" / nombre, f"consultas/{nombre}")

    # db/seed
    for nombre in ["seed.py", "Dockerfile", "requirements.txt", "README.md"]:
        existe(ROOT / "db" / "seed" / nombre, f"db/seed/{nombre}")
    for csv in ["cepas.csv", "maridajes.csv", "departamentos_mendoza.csv", "tipos_vino.csv", "presentaciones_ml.csv", "localidades.csv"]:
        existe(ROOT / "db" / "seed" / "catalogos" / csv, f"db/seed/catalogos/{csv}")

    # api
    for nombre in ["Dockerfile", "requirements.txt"]:
        existe(ROOT / "api" / nombre, f"api/{nombre}")
    for nombre in ["main.py", "config.py", "db.py", "errors.py"]:
        existe(ROOT / "api" / "app" / nombre, f"api/app/{nombre}")
    existe(ROOT / "api" / "app" / "dal" / "__init__.py", "api/app/dal/__init__.py")
    existe(ROOT / "api" / "app" / "routers" / "__init__.py", "api/app/routers/__init__.py")
    existe(ROOT / "api" / "tests" / "test_salud.py", "api/tests/test_salud.py")

    # front
    for nombre in ["index.html"]:
        existe(ROOT / "front" / nombre, f"front/{nombre}")
    existe(ROOT / "front" / "css" / "estilos.css", "front/css/estilos.css")
    existe(ROOT / "front" / "js" / "config.js", "front/js/config.js")
    existe(ROOT / "front" / "js" / "api.js", "front/js/api.js")

    # docs
    for nombre in ["README.md", "esquema_relacional.md", "diccionario_datos.md", "normalizacion.md", "decisiones_diseno.md", "trazabilidad.md"]:
        existe(ROOT / "docs" / nombre, f"docs/{nombre}")
    existe(ROOT / "docs" / "der" / ".gitkeep", "docs/der/.gitkeep")
    existe(ROOT / "docs" / "informes" / "informe_final.md", "docs/informes/informe_final.md")

    if ERRORES:
        print("ERRORES ENCONTRADOS:")
        for e in ERRORES:
            print(f"  - {e}")
        return 1

    print("Estructura completa: OK")
    if AVISOS:
        print("Avisos:")
        for a in AVISOS:
            print(f"  - {a}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
