# db/seed

Este directorio contiene el cargador de catálogos semilla para el TP "Bodegas del Atuel".
Implementa el **Paso 1 de la Etapa 3** del enunciado: cargar catálogos reales desde CSV.

## Estructura

- `catalogos/*.csv` — datos de catálogo del Anexo B:
  - `cepas.csv` — cepas con tipo (tinta/blanca)
  - `maridajes.csv` — maridajes con temperatura de servicio
  - `departamentos_mendoza.csv` — departamentos de Mendoza
  - `localidades.csv` — localidades de Mendoza con códigos postales reales
  - `tipos_vino.csv` — referencia (tipo_vino es ENUM en el esquema, no tabla)
  - `presentaciones_ml.csv` — referencia (volumen_ml es campo en vino, no tabla)
- `seed.py` — script de carga con psycopg, `execute_values` (carga por lotes),
  semilla fija (`--seed` / env `SEED`), medición de tiempos por tabla y consultas de control.
- `requirements.txt` — `psycopg[binary]`, `psycopg_pool`, `Faker`.
- `Dockerfile` — imagen para ejecutar el seed.

## Cómo ejecutar

```bash
docker compose --profile seed run --rm seed
```

El seed se conecta como `bodegas_owner` y hace lo siguiente:

1. Asegura que exista la provincia **Mendoza** (dependencia de `departamento` y `localidad`).
2. Carga cada catálogo desde su CSV usando `execute_values` (inserción por lotes) con
   `ON CONFLICT DO NOTHING` para ser idempotente.
3. Respeta el orden de dependencias de claves foráneas:
   `cepas` → `maridajes` → `departamentos_mendoza` → `localidades`.
4. Imprime el tiempo de carga de cada tabla y un conteo de control final.

## Semilla

Puedes fijar una semilla para reproducibilidad:

```bash
docker compose --profile seed run --rm -e SEED=123 seed
```

o editar el `.env` (`SEED=42` por defecto).

## Estado

✅ Implementado: carga de cepas, maridajes, departamentos y localidades desde CSV (Paso 1).
✅ Implementado: carga masiva con Faker (Paso 3+): clientes (20.000), comprobantes (150.000),
  renglones de comprobante (500.000+), stock inicial, actualización de totales y stock,
  deshabilitación/rehabilitación de triggers y consultas de control.

## Carga masiva (modo `--masivo`)

El modo masivo genera datos coherentes con semilla fija para reproducibilidad:

```bash
# Volúmenes por defecto: 20.000 clientes, 150.000 comprobantes, ~500.000 renglones
docker compose --profile seed run --rm seed --masivo

# Volúmenes personalizados
docker compose --profile seed run --rm seed --masivo --clientes 30000 --comprobantes 200000

# Con semilla distinta (reproducible con esa semilla)
docker compose --profile seed run --rm -e SEED=7 seed --masivo
```

### Qué hace el modo masivo

1. Carga datos maestros (bodegas, fincas, parcelas, vinos, salas, empleados, transportistas)
   solo si las tablas están vacías.
2. **Deshabilita triggers** que chocan con inserciones masivas:
   `trg_coherencia_cliente_subtipo`, `trg_validar_stock_venta`,
   `trg_descontar_stock_y_calcular_totales`, `trg_bloquear_renglones_*`,
   `trg_fecha_confeccion_transferencia`, `trg_auditoria_precio_vino`.
3. Inserta 20.000 clientes + filas de subtipo (socio/distribuidor/exportador) por lotes.
4. Carga stock inicial en depósito y salas.
5. Inserta comprobantes y renglones de comprobante por lotes.
6. **Recalcula totales** de comprobantes y **ajusta stock de sala** (descuenta lo vendido).
7. **Rehabilita triggers** y ejecuta consultas de control (conteo por tabla).
8. Genera `dump_completo.sql.gz` con `pg_dump` (volcado completo de la base cargada).

### Volcado de respaldo (`dump_completo.sql.gz`)

El archivo `dump_completo.sql.gz` se genera en la raíz del repositorio tras la carga masiva.
Permite restaurar la base en otra instancia:

```bash
# Descomprimir y restaurar en una base vacía
gunzip -k dump_completo.sql.gz
psql -U bodegas_owner -d bodegas -f dump_completo.sql
```

o directamente desde el gz:

```bash
zcat dump_completo.sql.gz | psql -U bodegas_owner -d bodegas
```

> El archivo `*.sql.gz` está en `.gitignore` (no se sube al repositorio).
