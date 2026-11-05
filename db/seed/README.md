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

✅ Implementado: carga de cepas, maridajes, departamentos y localidades desde CSV.
