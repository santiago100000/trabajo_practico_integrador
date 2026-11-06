# Bodegas del Atuel - TP Integrador de Bases de Datos (UTN FRSR)

Gestión y distribución de una empresa vitivinícola.

## Integrantes y roles (placeholders)

| Integrante | Rol | GitHub |
|------------|-----|--------|
| Nombre 1 | Modelo de datos y migraciones | @usuario1 |
| Nombre 2 | API y capa de acceso a datos | @usuario2 |
| Nombre 3 | Frontend y pruebas | @usuario3 |
| Nombre 4 | Consultas SQL y pruebas de base | @usuario4 |

## Requisitos

- Docker y Docker Compose
- (Opcional) Python 3.12 local para correr la API sin contenedor

## Cómo levantar

```bash
cp .env.example .env
# Editar .env con valores reales (nunca subir .env al repo)

docker compose up --build
```

Servicios:
- `db`: PostgreSQL 16 en `127.0.0.1:${DB_PORT}` (default 5432)
- `migrate`: aplica migraciones de `db/migrations/` en orden y termina
- `seed` (profile `seed`): carga masiva de datos con `db/seed/seed.py` y catálogos CSV

## Cómo correr el seed (opcional)

```bash
docker compose --profile seed run --rm seed
```

## Cómo correr los tests SQL (base)

```bash
docker compose exec db psql -U bodegas_owner -d bodegas -f /tests/db_tests.sql
```

## URLs locales

- Base de datos: http://localhost:${DB_PORT} (default 5433)

## Tabla de hitos

- [x] H1: Scaffolding inicial (este repositorio)
- [x] H2: Esquema, restricciones, funciones, procedimientos, triggers, vistas y roles (001 a 007)
- [x] H3: Carga masiva de datos (db/seed/ con catálogos CSV y seed.py con Faker)
- [x] H4: Índices y rendimiento (db/migrations/008_indices.sql, informe con planes EXPLAIN antes/después)
- [x] H5: Consultas SQL (consultas/select.sql, insert.sql, update.sql, delete.sql con S1-S12, I1-I6, U1-U6, D1-D6)

## Decisiones

- **DDL real en migraciones:** todos los archivos `db/migrations/001_esquema.sql` a `007_roles.sql` contienen DDL completo y aplicable (no son stubs).
- **Todas las columnas de auditoría** usan `timestamp` con `DEFAULT CURRENT_TIMESTAMP` (trigger `trg_auditoria_precio_vino`).
- **Regla de oro:** la base de datos es el corazón del sistema. Toda la lógica de negocio (RN-01 a RN-15) vive dentro de PostgreSQL mediante constraints, funciones, procedimientos y triggers.
- Puerto de Postgres publicado solo en `127.0.0.1` para no exponerlo fuera de localhost.

## Despliegue en la nube

No aplica. El sistema está diseñado para funcionar únicamente en entorno local con Docker y Docker Compose. No hay etapa 8 de despliegue en la nube.
