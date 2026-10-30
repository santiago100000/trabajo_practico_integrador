# db/seed

Este directorio contiene el esqueleto del cargador de semillas (catálogos) para el TP "Bodegas del Atuel".

## Estructura

- `catalogos/*.csv` — datos de catálogo del Anexo B (cepas, maridajes, departamentos de Mendoza, tipos de vino, presentaciones en ml). `localidades.csv` solo tiene encabezado; el grupo debe cargar códigos postales reales (no inventar).
- `seed.py` — esqueleto con argparse (`--seed`, default env `SEED`), `random.seed` y `Faker.seed` fijos, conexión como owner desde variables de entorno, helper para medir tiempos y una función vacía por tabla en orden de dependencias.
- `requirements.txt` — `psycopg[binary]`, `Faker`.
- `Dockerfile` — imagen para ejecutar el seed.

## Cómo ejecutar

```bash
docker compose --profile seed run --rm seed
```

El seed se conecta como `bodegas_owner` y necesita `DISABLE TRIGGER` en las tablas destino (el grupo lo implementa en `seed.py`).

## Estado

Sin datos insertados todavía: cada función de carga lanza `NotImplementedError` hasta que el grupo implemente la inserción real.
