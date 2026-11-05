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
  # Inyectar contraseñas desde variables de entorno (nunca escritas en los .sql)
  sed -e "s/@OWNER_PASSWORD@/$OWNER_PASSWORD/g" \
      -e "s/@APP_PASSWORD@/$APP_PASSWORD/g" \
      -e "s/@RO_PASSWORD@/$RO_PASSWORD/g" \
      "$f" | psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
    -v ON_ERROR_STOP=1 -f -
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 \
    -c "INSERT INTO ops.schema_migrations (nombre_archivo) VALUES ('$nombre');"
done

echo "Migraciones completadas."
