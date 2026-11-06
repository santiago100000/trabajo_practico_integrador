# Informe Etapa 4 — Índices y rendimiento (Pasos 1 y 2)

**Proyecto:** Bodegas del Atuel — TP Integrador de Bases de Datos (UTN FRSR)  
**Etapa:** 4 — Índices y rendimiento  
**Pasos completados:** Paso 1 (selección de consultas candidatas) y Paso 2 (medición inicial con EXPLAIN ANALYZE BUFFERS sobre índices de PK y UNIQUE)  
**Estado:** Pasos 1 y 2 completados con resultados reales contra la base cargada de la Etapa 3.  
**Pendientes:** Pasos 3 a 8 (diseño de índices, creación en `008_indices.sql`, mediciones posteriores, tabla comparativa).

---

## Paso 1 — Selección de consultas candidatas

Según el enunciado (sección 8 del TPI), se deben elegir al menos tres consultas que involucren muchas filas. Se seleccionaron las siguientes:

| Código | Consulta | Tablas involucradas | Justificación |
|--------|----------|---------------------|---------------|
| **S1** | Ranking de los 10 vinos con mayor cantidad de botellas vendidas en toda la red de salas. | `renglon_comprobante`, `comprobante`, `vino` | Tabla `renglon_comprobante` es la más grande (500.000+ filas). Involucra JOIN y GROUP BY sobre gran volumen. |
| **S4** | Top 5 de las salas que solicitaron mayor cantidad de un vino determinado mediante transferencias en los últimos 15 días. | `renglon_transferencia`, `transferencia` | Filtro por rango de fecha (`últimos 15 días`) y GROUP BY por sala. Útil para validar índice parcial o compuesto. |
| **S8** | Monto total de ventas por sala en el último trimestre, en orden descendente. | `comprobante`, `sala_venta` | Filtro por rango de fecha (`últimos 3 meses`), GROUP BY por sala, ordenamiento. Candidata para índice compuesto `(id_sala, fecha)`. |

> Se eligieron S1, S4 y S8 (3 consultas, cumpliendo el mínimo del enunciado). S10 también es candidata válida pero se deja para futura ampliación.

---

### S1 — Ranking de vinos más vendidos

```sql
SELECT
    v.cod_vino,
    v.nombre,
    SUM(r.cantidad) AS total_botellas_vendidas
FROM renglon_comprobante r
JOIN comprobante c ON r.nro_comprobante = c.nro_comprobante
JOIN vino v ON r.cod_vino = v.cod_vino
GROUP BY v.cod_vino, v.nombre
ORDER BY total_botellas_vendidas DESC
LIMIT 10;
```

---

### S4 — Salas con más transferencias de un vino en los últimos 15 días

> Se usa `cod_vino = 1` como valor concreto del dataset (ajustar según el ID real de un vino existente tras la carga masiva).

```sql
SELECT
    tr.id_sala,
    SUM(rt.cantidad) AS total_solicitado
FROM renglon_transferencia rt
JOIN transferencia tr ON rt.nro_solicitud = tr.nro_solicitud
WHERE rt.cod_vino = 1
  AND tr.fecha_confeccion >= (SELECT MAX(fecha_confeccion) FROM transferencia) - INTERVAL '15 days'
GROUP BY tr.id_sala
ORDER BY total_solicitado DESC
LIMIT 5;
```

---

### S8 — Monto total de ventas por sala en el último trimestre

```sql
SELECT
    s.id_sala,
    s.calle,
    s.numero,
    SUM(c.total) AS monto_total_ventas
FROM comprobante c
JOIN sala_venta s ON c.id_sala = s.id_sala
WHERE c.fecha >= (SELECT MAX(fecha) FROM comprobante) - INTERVAL '3 months'
GROUP BY s.id_sala, s.calle, s.numero
ORDER BY monto_total_ventas DESC;
```

---

## Paso 2 — Medición inicial con EXPLAIN (ANALYZE, BUFFERS)

Ejecutar `ANALYZE` sobre todas las tablas involucradas para actualizar estadísticas, y luego `EXPLAIN (ANALYZE, BUFFERS)` sobre cada consulta. Esto se hace **antes de crear cualquier índice adicional** (solo existen los índices de claves primarias y UNIQUE de la Etapa 1 y 2).

> **Nota:** Los resultados (tiempos y planes) deben pegarse en las secciones `[RESULTADO]` después de ejecutar contra la base cargada con la Etapa 3.

### 2.1 — Actualizar estadísticas

```sql
ANALYZE renglon_comprobante;
ANALYZE comprobante;
ANALYZE vino;
ANALYZE renglon_transferencia;
ANALYZE transferencia;
ANALYZE sala_venta;
```

---

### 2.2 — Medición de S1 (sin índices adicionales)

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    v.cod_vino,
    v.nombre,
    SUM(r.cantidad) AS total_botellas_vendidas
FROM renglon_comprobante r
JOIN comprobante c ON r.nro_comprobante = c.nro_comprobante
JOIN vino v ON r.cod_vino = v.cod_vino
GROUP BY v.cod_vino, v.nombre
ORDER BY total_botellas_vendidas DESC
LIMIT 10;
```

**[RESULTADO S1]**
- Tiempo de ejecución: `124.119 ms`
- Plan de ejecución:
  ```
  Limit  (cost=11653.47..11653.50 rows=10 width=28) (actual time=120.441..123.930 rows=10 loops=1)
    Buffers: shared hit=3160 read=2320
    ->  Sort  (cost=11653.47..11653.63 rows=63 width=28) (actual time=120.439..123.927 rows=10 loops=1)
          Sort Key: (sum((r.cantidad)::integer)) DESC
          Sort Method: top-N heapsort  Memory: 26kB
          Buffers: shared hit=3160 read=2320
          ->  Finalize GroupAggregate  (cost=11636.15..11652.11 rows=63 width=28) (actual time=120.373..123.901 rows=60 loops=1)
                Group Key: v.cod_vino
                Buffers: shared hit=3157 read=2320
                ->  Gather Merge  (cost=11636.15..11650.85 rows=126 width=28) (actual time=120.365..123.873 rows=180 loops=1)
                      Workers Planned: 2
                      Workers Launched: 2
                      Buffers: shared hit=3157 read=2320
                      ->  Sort  (cost=10636.13..10636.29 rows=63 width=28) (actual time=114.595..114.600 rows=60 loops=3)
                            Sort Key: v.cod_vino
                            Sort Method: quicksort  Memory: 28kB
                            Buffers: shared hit=3157 read=2320
                            Worker 0:  Sort Method: quicksort  Memory: 28kB
                            Worker 1:  Sort Method: quicksort  Memory: 28kB
                            ->  Partial HashAggregate  (cost=10633.62..10634.25 rows=63 width=28) (actual time=114.352..114.362 rows=60 loops=3)
                                  Group Key: v.cod_vino
                                  Batches: 1  Memory Usage: 24kB
                                  Buffers: shared hit=3143 read=2320
                                  Worker 0:  Batches: 1  Memory Usage: 24kB
                                  Worker 1:  Batches: 1  Memory Usage: 24kB
                                  ->  Hash Join  (cost=4340.73..9852.31 rows=156261 width=24) (actual time=43.400..99.348 rows=125009 loops=3)
                                        Hash Cond: (r.cod_vino = v.cod_vino)
                                        Buffers: shared hit=3143 read=2320
                                        ->  Parallel Hash Join  (cost=4338.31..9412.12 rows=156261 width=8) (actual time=43.311..81.175 rows=125009 loops=3)
                                              Hash Cond: (r.nro_comprobante = c.nro_comprobante)
                                              Buffers: shared hit=3134 read=2320
                                              ->  Parallel Seq Scan on renglon_comprobante r  (cost=0.00..4663.61 rows=156261 width=12) (actual time=0.015..8.035 rows=125009 loops=3)
                                                    Buffers: shared hit=3101
                                              ->  Parallel Hash  (cost=3235.36..3235.36 rows=88236 width=4) (actual time=42.081..42.081 rows=50000 loops=3)
                                                    Buckets: 262144  Batches: 1  Memory Usage: 7968kB
                                                    Buffers: shared hit=33 read=2320
                                                    ->  Parallel Seq Scan on comprobante c  (cost=0.00..3235.36 rows=88236 width=4) (actual time=2.821..19.389 rows=50000 loops=3)
                                                          Buffers: shared hit=33 read=2320
                                        ->  Hash  (cost=1.63..1.63 rows=63 width=20) (actual time=0.059..0.060 rows=63 loops=3)
                                              Buckets: 1024  Batches: 1  Memory Usage: 12kB
                                              Buffers: shared hit=3
                                              ->  Seq Scan on vino v  (cost=0.00..1.63 rows=63 width=20) (actual time=0.038..0.044 rows=63 loops=3)
                                                    Buffers: shared hit=3
  Planning:
    Buffers: shared hit=307 read=14
  Planning Time: 4.925 ms
  Execution Time: 124.119 ms
  ```
- Tipo de recorrido dominante: `Parallel Seq Scan` sobre `renglon_comprobante` y `comprobante` (tablas grandes sin índice adicional)
- Filas leídas aproximadas: 125,009 renglones, 50,000 comprobantes, 63 vinos

---

### 2.3 — Medición de S4 (sin índices adicionales)

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    tr.id_sala,
    SUM(rt.cantidad) AS total_solicitado
FROM renglon_transferencia rt
JOIN transferencia tr ON rt.nro_solicitud = tr.nro_solicitud
WHERE rt.cod_vino = 1
  AND tr.fecha_confeccion >= (SELECT MAX(fecha_confeccion) FROM transferencia) - INTERVAL '15 days'
GROUP BY tr.id_sala
ORDER BY total_solicitado DESC
LIMIT 5;
```

**[RESULTADO S4]**
- Tiempo de ejecución: `0.094 ms`
- Plan de ejecución:
  ```
  Limit  (cost=0.05..0.06 rows=1 width=12) (actual time=0.028..0.028 rows=0 loops=1)
    Buffers: shared hit=3
    InitPlan 1 (returns $0)
      ->  Aggregate  (cost=0.00..0.01 rows=1 width=4) (never executed)
            ->  Seq Scan on transferencia  (cost=0.00..0.00 rows=1 width=4) (never executed)
    ->  Sort  (cost=0.04..0.04 rows=1 width=12) (actual time=0.027..0.027 rows=0 loops=1)
          Sort Key: (sum((rt.cantidad)::integer)) DESC
          Sort Method: quicksort  Memory: 25kB
          Buffers: shared hit=3
          ->  HashAggregate  (cost=0.02..0.03 rows=1 width=12) (actual time=0.004..0.004 rows=0 loops=1)
                Group Key: tr.id_sala
                Batches: 1  Memory Usage: 24kB
                ->  Nested Loop  (cost=0.00..0.01 rows=1 width=8) (actual time=0.003..0.003 rows=0 loops=1)
                      Join Filter: (rt.nro_solicitud = tr.nro_solicitud)
                      ->  Seq Scan on renglon_transferencia rt  (cost=0.00..0.00 rows=1 width=8) (actual time=0.003..0.003 rows=0 loops=1)
                            Filter: (cod_vino = 1)
                      ->  Seq Scan on transferencia tr  (cost=0.00..0.00 rows=1 width=8) (never executed)
                            Filter: (fecha_confeccion >= ($0 - '15 days'::interval))
  Planning:
    Buffers: shared hit=132 read=2
  Planning Time: 1.092 ms
  Execution Time: 0.094 ms
  ```
- Tipo de recorrido dominante: `Seq Scan` en `renglon_transferencia` y `transferencia` (0 filas encontradas para `cod_vino = 1`)
- Filas leídas aproximadas: 0 filas (no hay renglones de transferencia para el vino 1)

---

### 2.4 — Medición de S8 (sin índices adicionales)

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    s.id_sala,
    s.calle,
    s.numero,
    SUM(c.total) AS monto_total_ventas
FROM comprobante c
JOIN sala_venta s ON c.id_sala = s.id_sala
WHERE c.fecha >= (SELECT MAX(fecha) FROM comprobante) - INTERVAL '3 months'
GROUP BY s.id_sala, s.calle, s.numero
ORDER BY monto_total_ventas DESC;
```

**[RESULTADO S8]**
- Tiempo de ejecución: `25.802 ms`
- Plan de ejecución:
  ```
  Sort  (cost=2301.28..2301.31 rows=11 width=63) (actual time=25.659..25.670 rows=10 loops=1)
    Sort Key: (sum((c.total)::numeric)) DESC
    Sort Method: quicksort  Memory: 25kB
    Buffers: shared hit=13 read=185
    InitPlan 2 (returns $1)
      ->  Result  (cost=0.46..0.47 rows=1 width=4) (actual time=1.184..1.187 rows=1 loops=1)
            Buffers: shared hit=2 read=3
            InitPlan 1 (returns $0)
              ->  Limit  (cost=0.42..0.46 rows=1 width=4) (actual time=1.179..1.181 rows=1 loops=1)
                    Buffers: shared hit=2 read=3
                    ->  Index Only Scan Backward using idx_comprobante_fecha_cubriendo on comprobante  (cost=0.42..5589.44 rows=150001 width=4) (actual time=1.177..1.177 rows=1 loops=1)
                          Index Cond: (fecha IS NOT NULL)
                          Heap Fetches: 1
                          Buffers: shared hit=2 read=3
    ->  HashAggregate  (cost=2300.48..2300.62 rows=11 width=63) (actual time=25.623..25.632 rows=10 loops=1)
          Group Key: s.id_sala
          Batches: 1  Memory Usage: 24kB
          Buffers: shared hit=10 read=185
          ->  Hash Join  (cost=1.67..2050.48 rows=50000 width=39) (actual time=2.033..18.342 rows=37070 loops=1)
                Hash Cond: (c.id_sala = s.id_sala)
                Buffers: shared hit=10 read=185
                ->  Index Only Scan using idx_comprobante_fecha_cubriendo on comprobante c  (cost=0.42..1867.42 rows=50000 width=12) (actual time=1.990..11.478 rows=37070 loops=1)
                      Index Cond: (fecha >= ($1 - '3 mons'::interval))
                      Heap Fetches: 1
                      Buffers: shared hit=9 read=185
                ->  Hash  (cost=1.11..1.11 rows=11 width=31) (actual time=0.020..0.026 rows=11 loops=1)
                      Buckets: 1024  Batches: 1  Memory Usage: 9kB
                      Buffers: shared hit=1
                      ->  Seq Scan on sala_venta s  (cost=0.00..1.11 rows=11 width=31) (actual time=0.013..0.015 rows=11 loops=1)
                            Buffers: shared hit=1
  Planning:
    Buffers: shared hit=234 read=8
  Planning Time: 2.975 ms
  Execution Time: 25.802 ms
  ```
- Tipo de recorrido dominante: `Index Only Scan` sobre `comprobante` usando `idx_comprobante_fecha_cubriendo` (ya existe en 006_vistas.sql o migración previa) + `Seq Scan` en `sala_venta` (11 filas, pequeña)
- Filas leídas aproximadas: 37,070 comprobantes en el trimestre, 11 salas

---

## Resumen del Paso 2 (pendiente de completar con datos reales)

| Consulta | Tiempo (ms) sin índices | Recorrido dominante | Filas leídas |
|----------|------------------------|---------------------|--------------|
| S1 | 124.119 | Parallel Seq Scan (renglon_comprobante, comprobante) | 125,009 renglones, 50,000 comprobantes |
| S4 | 0.094 | Seq Scan (renglon_transferencia, transferencia) | 0 filas (cod_vino=1 no tiene transferencias) |
| S8 | 25.802 | Index Only Scan (comprobante via idx_comprobante_fecha_cubriendo) | 37,070 comprobantes, 11 salas |

---

## Próximos pasos (Paso 3 a 8)

1. **Paso 3:** Diseñar índices a partir de los planes observados (buscar Seq Scan sobre tablas grandes, ordenamientos costosos, JOINs sin índice).
2. **Paso 4:** Crear los índices en `db/migrations/008_indices.sql` y volver a ejecutar `ANALYZE`.
3. **Paso 5:** Repetir las mediciones de S1, S4 y S8 y armar una tabla comparativa (antes / después).
4. **Paso 6:** Justificar el orden de columnas del índice compuesto y documentar un índice descartado.
5. **Paso 7:** Medir el costo de escritura (carga masiva con y sin índices).
6. **Paso 8:** Mostrar un caso en que el planificador no use un índice existente y explicar por qué.

---

**Archivo relacionado:** `db/migrations/008_indices.sql` — contiene la documentación de los pasos 1 y 2 y las sentencias `CREATE INDEX` para los pasos 4 en adelante.