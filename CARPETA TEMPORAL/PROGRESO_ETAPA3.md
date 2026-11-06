# PROGRESO — TPI Bodegas del Atuel

**Ultima actualización:** 05/11/2026

## Etapa 1 — Modelado ✅ COMPLETA
- DER, esquema relacional, diccionario de datos, normalización 3FN
- `db/migrations/001_esquema.sql` aplicada

## Etapa 2 — Integridad y lógica en la base ✅ COMPLETA
- `002_constraints.sql` a `007_roles.sql` aplicadas
- `db/tests/db_tests.sql` con pruebas RN-01 a RN-15
- Demostración de concurrencia (capturas en `docs/informes/Paso 8 Capturas/`)

## Etapa 3 — Carga masiva de datos

### Paso 1 — Catálogos desde CSV (anexo B) ✅ COMPLETO
- Commit: `5a49f44` — Push: OK
- `db/seed/seed.py` implementado con carga por lotes (`executemany`), semilla fija, orden de dependencias FK, `ON CONFLICT DO NOTHING`, consultas de control
- `db/seed/requirements.txt` — agregado `psycopg_pool`
- `db/seed/README.md` documentado
- CSV completados y limpios: `cepas.csv`, `localidades.csv`, `departamentos_mendoza.csv`, `tipos_vino.csv`, `presentaciones_ml.csv`
- Probado contra Docker: carga exitosa (10 cepas, 10 maridajes, 10 departamentos, 16 localidades)

### Paso 2 — Orden de carga por dependencias FK ✅ COMPLETO
- Commit: `0d812a4` — Push: OK
- Diagrama en `docs/informes/diagrama Orden de carga (hecho en mermaid.ai).png`
- 7 niveles de carga respetando dependencias FK

### Paso 3 en adelante — COMPLETO ✅
- Carga masiva con Faker (clientes, vinos, comprobantes, etc.) implementada en `db/seed/seed.py` (modo `--masivo`).
- Volúmenes: cliente 20.000, comprobante 150.000, renglón 500.000+ (por defecto).
- Manejo de triggers durante carga (DISABLE/ENABLE TRIGGER): 7 triggers deshabilitados y rehabilitados al final.
- Consultas de control y volcado `pg_dump` (`dump_completo.sql.gz`).
- Commit `e942bb3`: Etapa 3 completa (carga masiva con Faker y dump_completo.sql.gz).
- Commit `00b115a`: Documenta decisión y riesgos de deshabilitar triggers en carga masiva.

## Estado del repositorio
- Rama: `main`
- Último commit push: `00b115a` (Etapa 3 completa)
- Todo sincronizado con `origin/main`
