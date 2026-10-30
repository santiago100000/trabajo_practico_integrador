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
- `api`: FastAPI en `http://localhost:${API_PORT}` (default 8000), docs en `/docs`
- `front`: nginx en `http://localhost:${FRONT_PORT}` (default 8080)

## Cómo correr el seed (opcional)

```bash
docker compose --profile seed run --rm seed
```

## Cómo correr los tests SQL (base)

```bash
docker compose exec db psql -U bodegas_owner -d bodegas -f /tests/db_tests.sql
```

## Cómo correr los tests de la API

```bash
docker compose exec api pytest -q
```

## URLs locales

- API: http://localhost:8000
- Documentación API (Swagger): http://localhost:8000/docs
- Front: http://localhost:8080

## Tabla de hitos

- [ ] H1: Scaffolding inicial (este repositorio)
- [ ] H2: Esquema y restricciones (001, 002)
- [ ] H3: Funciones (003)
- [ ] H4: Procedimientos transaccionales (004)
- [ ] H5: Triggers (005)
- [ ] H6: Vistas (006)
- [ ] H7: Roles y privilegios (007)
- [ ] H8: Índices (008)
- [ ] H9: API, front, seed, consultas y pruebas completas

## Decisiones

- **Ambiguedad resuelta por simplicidad:** todas las columnas de auditoría usan `timestamptz` con `DEFAULT now()`.
- Los `.sql` de migración son stubs con solo comentarios; el grupo escribe el DDL real a mano.
- La API y el front no calculan totales, descuentos ni stock: eso vive en la base de datos (funciones, triggers y vistas).
- Puerto de Postgres publicado solo en `127.0.0.1` para no exponerlo fuera de localhost.

## Despliegue en la nube

TODO
