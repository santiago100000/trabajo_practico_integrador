#!/bin/sh
set -e

echo "Esperando a que db esté disponible..."
until psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c '\q' >/dev/null 2>&1; do
  echo "  db no lista, reintentando en 2s..."
  sleep 2
done

echo "Creando esquema ops y tabla de registro de migraciones..."
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 <<'SQL'
CREATE SCHEMA IF NOT EXISTS ops;

CREATE TABLE IF NOT EXISTS ops.schema_migrations (
    nombre_archivo text PRIMARY KEY,
    aplicado_en timestamptz NOT NULL DEFAULT now()
);
SQL

echo "Aplicando migraciones en orden alfabético..."
for f in /migrations/0*.sql; do
  nombre=$(basename "$f")
  ya_aplicado=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
    -t -A -c "SELECT 1 FROM ops.schema_migrations WHERE nombre_archivo = '$nombre';")
  if [ -n "$ya_aplicado" ]; then
    echo "  Saltando (ya aplicado): $nombre"
    continue
  fi
  echo "  Aplicando: $nombre"
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
    -v app_password="$APP_PASSWORD" -v ro_password="$RO_PASSWORD" \
    -v ON_ERROR_STOP=1 -f "$f"
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 \
    -c "INSERT INTO ops.schema_migrations (nombre_archivo) VALUES ('$nombre');"
done

echo "Migraciones completadas."
