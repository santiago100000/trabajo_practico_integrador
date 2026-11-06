# Informe EXPLAIN (ANALYZE, BUFFERS) — Etapa 5: Consultas SQL Avanzadas

Este documento registra los planes de ejecución medidos con `EXPLAIN (ANALYZE, BUFFERS)` para las consultas avanzadas de la Etapa 5 (S9 a S12). Las consultas S1, S4 y S8 pertenecen a la Etapa 4 (Índices y rendimiento) y ya están documentadas en `docs/informes/informe_etapa4_indices.md`.

Base de datos: PostgreSQL 16 (Docker), datos cargados Etapa 3 (semilla 42).

**Nota sobre S12a:** La consulta original usaba `NOT EXISTS` correlionado doble (división relacional), lo que generaba un plan de costo extremadamente alto y un timeout (>120 segundos) al ejecutar `EXPLAIN ANALYZE`. La consulta fue reescrita en `consultas/select.sql` usando `GROUP BY` + `HAVING COUNT(DISTINCT ...)` para evitar el problema. No se incluye un plan `EXPLAIN ANALYZE` de la versión optimizada porque no se pudo medir contra la base cargada en este entorno.

---

## S1: Ranking de los 10 vinos con mayor cantidad de botellas vendidas

**Consulta:** `renglon_comprobante → comprobante → vino`, GROUP BY, SUM, ORDER BY DESC, LIMIT 10.

**Resultado:**

```
                                                                                       QUERY PLAN                                                                                         
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=11949.78..11949.80 rows=10 width=28) (actual time=427.712..434.645 rows=10 loops=1)
   Buffers: shared hit=5776
   ->  Sort  (cost=11949.78..11949.93 rows=60 width=28) (actual time=427.710..434.639 rows=10 loops=1)
         Sort Key: (sum((rc.cantidad)::integer)) DESC
         Sort Method: top-N heapsort  Memory: 26kB
         Buffers: shared hit=5776
         ->  Finalize GroupAggregate  (cost=11933.28..11948.48 rows=60 width=28) (actual time=427.535..434.580 rows=60 loops=1)
               Group Key: v.cod_vino
               Buffers: shared hit=5773
               ->  Gather Merge  (cost=11933.28..11947.28 rows=120 width=28) (actual time=427.524..434.509 rows=180 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=5773
                     ->  Sort  (cost=10933.26..10933.41 rows=60 width=28) (actual time=417.569..417.580 rows=60 loops=3)
                           Sort Method: quicksort  Memory: 28kB
                           Buffers: shared hit=5773
                           Worker 0:  Sort Method: quicksort  Memory: 28kB
                           Worker 1:  Sort Method: quicksort  Memory: 28kB
                           ->  Partial HashAggregate  (cost=10930.89..10931.49 rows=60 width=28) (actual time=417.482..417.502 rows=60 loops=3)
                                 Group Key: v.cod_vino
                                 Batches: 1  Memory Usage: 24kB
                                 Buffers: shared hit=5759
                                 ->  Hash Join  (cost=4636.64..10149.59 rows=156260 width=24) (actual time=78.617..339.464 rows=125008 loops=3)
                                       Hash Cond: (rc.cod_vino = v.cod_vino)
                                       ->  Parallel Hash Join  (cost=4634.29..9708.08 rows=156260 width=8) (actual time=78.511..252.733 rows=125008 loops=3)
                                             ->  Parallel Seq Scan on renglon_comprobante rc  (actual time=0.032..34.836 rows=125008 loops=3)
                                                   Buffers: shared hit=3101
                                             ->  Parallel Hash  (actual time=77.231..77.232 rows=50000 loops=3)
                                                   ->  Parallel Seq Scan on comprobante c  (actual time=0.643..15.584 rows=50000 loops=3)
                                                         Buffers: shared hit=2649
                                       ->  Hash  (actual time=0.070..0.070 rows=60 loops=3)
                                             ->  Seq Scan on vino v  (actual time=0.033..0.045 rows=60 loops=3)
                                                   Buffers: shared hit=3
 Planning Time: 3.296 ms
 Execution Time: 435.127 ms
```

**Resumen:**
- **Execution Time:** 435.127 ms
- **Recorrido:** Parallel Seq Scan sobre `renglon_comprobante` (125,008 filas), Parallel Seq Scan sobre `comprobante` (50,000 filas), Seq Scan sobre `vino` (60 filas).
- **Buffers:** shared hit=5776
- **Observación:** El planificador usa Hash Join y Parallel Hash Aggregate. No hay índice sobre la FK `cod_vino` en `renglon_comprobante` que ayude al JOIN con `vino`, por lo que se hace Seq Scan paralelo sobre la tabla grande.

---

## S4: Top 5 salas que solicitaron mayor cantidad de un vino mediante transferencias (últimos 15 días)

**Consulta:** `renglon_transferencia → transferencia → sala_venta`, filtro por vino y fecha.

**Resultado:**

```
                                                                         QUERY PLAN                                                                          
-------------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=45.58..45.59 rows=3 width=308) (actual time=0.073..0.075 rows=0 loops=1)
   Buffers: shared hit=9
   ->  Sort  (cost=45.58..45.59 rows=3 width=308) (actual time=0.071..0.074 rows=0 loops=1)
         Sort Method: quicksort  Memory: 25kB
         Buffers: shared hit=9
         ->  GroupAggregate  (cost=45.49..45.56 rows=3 width=308) (actual time=0.041..0.043 rows=0 loops=1)
               Group Key: t.id_sala, s.calle, s.numero
               Buffers: shared hit=6
               ->  Sort  (cost=45.49..45.50 rows=3 width=304) (actual time=0.041..0.042 rows=0 loops=1)
                     Sort Method: quicksort  Memory: 25kB
                     Buffers: shared hit=6
                     ->  Nested Loop  (cost=15.06..45.46 rows=3 width=304) (actual time=0.005..0.007 rows=0 loops=1)
                           ->  Hash Join  (cost=14.91..44.57 rows=3 width=8) (actual time=0.005..0.006 rows=0 loops=1)
                                 Hash Cond: (t.nro_solicitud = rt.nro_solicitud)
                                 ->  Seq Scan on transferencia t  (actual time=0.004..0.004 rows=0 loops=1)
                                       Filter: (fecha_confeccion >= (CURRENT_DATE - '15 days'::interval))
                                 ->  Hash  (cost=14.79..14.79 rows=10 width=8) (never executed)
                                       ->  Bitmap Heap Scan on renglon_transferencia rt  (never executed)
                                             Recheck Cond: (cod_vino = 33)
                                             ->  Bitmap Index Scan on idx_renglon_transferencia_cod_vino  (never executed)
                                                   Index Cond: (cod_vino = 33)
                           ->  Index Scan using pk_sala_venta on sala_venta s  (never executed)
                                 Index Cond: (id_sala = t.id_sala)
 Planning Time: 1.463 ms
 Execution Time: 0.235 ms
```

**Resumen:**
- **Execution Time:** 0.235 ms
- **Filas devueltas:** 0 (no hay transferencias cargadas en la base de la Etapa 3).
- **Índice usado:** `idx_renglon_transferencia_cod_vino` (Bitmap Index Scan), creado en la Etapa 4.
- **Observación:** Como no hay filas en `transferencia`, el Bitmap Heap Scan nunca se ejecuta. El índice sobre la FK `cod_vino` existe y está listo para cuando haya datos.

---

## S8: Monto total de ventas por sala en el último trimestre

**Consulta:** `comprobante → sala_venta`, filtro por fecha, GROUP BY, SUM, ORDER BY DESC.

**Resultado:**

```
                                                                            QUERY PLAN                                                                            
------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=5432.03..5432.63 rows=240 width=332) (actual time=53.009..57.675 rows=10 loops=1)
   Sort Key: (sum((cp.total)::numeric)) DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=2664
   ->  Finalize GroupAggregate  (cost=5390.14..5422.54 rows=240 width=332) (actual time=52.823..57.537 rows=10 loops=1)
         Group Key: s.id_sala
         Buffers: shared hit=2661
         ->  Gather Merge  (cost=5390.14..5417.74 rows=240 width=332) (actual time=52.799..57.469 rows=20 loops=1)
               Workers Planned: 1
               Workers Launched: 1
               Buffers: shared hit=2661
               ->  Sort  (cost=4390.13..4390.73 rows=240 width=332) (actual time=48.896..48.901 rows=10 loops=2)
                     Sort Method: quicksort  Memory: 26kB
                     Buffers: shared hit=2661
                     ->  Partial HashAggregate  (cost=4377.64..4380.64 rows=240 width=332) (actual time=48.839..48.853 rows=10 loops=2)
                           Group Key: s.id_sala
                           Batches: 1  Memory Usage: 37kB
                           Buffers: shared hit=2654
                           ->  Hash Join  (cost=15.40..4267.41 rows=22046 width=308) (actual time=1.236..39.625 rows=18758 loops=2)
                                 Hash Cond: (cp.id_sala = s.id_sala)
                                 ->  Parallel Seq Scan on comprobante cp  (actual time=1.138..29.432 rows=18758 loops=2)
                                       Filter: (fecha >= (CURRENT_DATE - '3 mons'::interval))
                                       Rows Removed by Filter: 56242
                                       Buffers: shared hit=2649
                                 ->  Hash  (actual time=0.048..0.049 rows=10 loops=2)
                                       ->  Seq Scan on sala_venta s  (actual time=0.035..0.038 rows=10 loops=2)
                                             Buffers: shared hit=2
 Planning Time: 1.455 ms
 Execution Time: 57.891 ms
```

**Resumen:**
- **Execution Time:** 57.891 ms
- **Recorrido:** Parallel Seq Scan sobre `comprobante` (22,046 filas filtradas de 75,000), Seq Scan sobre `sala_venta` (10 filas).
- **Buffers:** shared hit=2664
- **Observación:** El filtro por fecha descarta 56,242 filas. El índice `idx_comprobante_sala_fecha` (compuesto, creado en Etapa 4) no se usa porque el planificador estima que Seq Scan es más barato para este volumen de datos filtrado.

---

## S9: Ficha de un vino (cepas, bodega, maridajes, stock total)

**Consulta:** `vino → bodega`, LEFT JOIN `vino_cepa`, `cepa`, `vino_maridaje`, `maridaje`, `stock_deposito`, subquery `stock_sala`. Filtro `cod_vino = 1`.

**Resultado:**

```
                                                                             QUERY PLAN                                                                              
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
 GroupAggregate  (cost=87.45..90.42 rows=66 width=422) (actual time=0.368..0.374 rows=1 loops=1)
   Buffers: shared hit=23
   ->  Sort  (cost=87.45..87.61 rows=66 width=738) (actual time=0.343..0.348 rows=1 loops=1)
         Sort Method: quicksort  Memory: 25kB
         Buffers: shared hit=23
         ->  Nested Loop Left Join  (cost=28.93..85.45 rows=66 width=738) (actual time=0.269..0.282 rows=1 loops=1)
               ->  Nested Loop Left Join  (cost=13.88..54.99 rows=6 width=560) (actual time=0.224..0.235 rows=1 loops=1)
                     ->  Nested Loop Left Join  (cost=0.14..26.38 rows=1 width=350) (actual time=0.189..0.198 rows=1 loops=1)
                           ->  Nested Loop Left Join  (cost=0.14..11.83 rows=1 width=342) (actual time=0.071..0.079 rows=1 loops=1)
                                 ->  Nested Loop  (cost=0.14..10.07 rows=1 width=338) (actual time=0.054..0.061 rows=1 loops=1)
                                       ->  Seq Scan on vino v  (actual time=0.031..0.038 rows=1 loops=1)
                                             Filter: (cod_vino = 1)
                                             Rows Removed by Filter: 59
                                       ->  Index Scan using pk_bodega on bodega b  (actual time=0.019..0.019 rows=1 loops=1)
                                             Index Cond: (id_bodega = v.id_bodega)
                                 ->  Seq Scan on stock_deposito sd  (actual time=0.016..0.016 rows=1 loops=1)
                                       Filter: (cod_vino = 1)
                           ->  GroupAggregate  (actual time=0.116..0.116 rows=1 loops=1)
                                 ->  Seq Scan on stock_sala  (actual time=0.031..0.110 rows=10 loops=1)
                                       Filter: (cod_vino = 1)
                                       Rows Removed by Filter: 590
                     ->  Hash Right Join  (actual time=0.034..0.036 rows=0 loops=1)
                           Hash Cond: (c.id_cepa = vc.id_cepa)
                           ->  Bitmap Heap Scan on vino_cepa vc  (actual time=0.008..0.009 rows=0 loops=1)
                                 Recheck Cond: (cod_vino = 1)
                                 ->  Bitmap Index Scan on pk_vino_cepa  (actual time=0.007..0.007 rows=0 loops=1)
                                       Index Cond: (cod_vino = 1)
               ->  Materialize  (actual time=0.043..0.044 rows=0 loops=1)
                     ->  Hash Right Join  (actual time=0.033..0.034 rows=0 loops=1)
                           ->  Bitmap Heap Scan on vino_maridaje vm  (actual time=0.014..0.014 rows=0 loops=1)
                                 Recheck Cond: (cod_vino = 1)
                                 ->  Bitmap Index Scan on pk_vino_maridaje  (actual time=0.011..0.011 rows=0 loops=1)
                                       Index Cond: (cod_vino = 1)
 Planning Time: 5.912 ms
 Execution Time: 0.721 ms
```

**Resumen:**
- **Execution Time:** 0.721 ms
- **Índices usados:** `pk_bodega` (Index Scan), `pk_vino_cepa` (Bitmap Index Scan), `pk_vino_maridaje` (Bitmap Index Scan).
- **Buffers:** shared hit=23
- **Observación:** Muy rápido porque filtra por PK de `vino` y usa los índices de PK de las tablas relacionadas.

---

## S10: Rendimiento en kg por hectárea por parcela y campaña

**Consulta:** CTE `rendimiento_parcela` con JOIN `lote_uva → parcela`, subconsulta correlacionada para promedio de finca.

**Resultado:**

```
                                                          QUERY PLAN                                                          
------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=34231.13..34234.21 rows=1230 width=74) (actual time=0.058..0.060 rows=0 loops=1)
   CTE rendimiento_parcela
     ->  Hash Join  (cost=37.50..69.33 rows=1230 width=42) (actual time=0.006..0.007 rows=0 loops=1)
           Hash Cond: ((l.id_finca = p.id_finca) AND (l.nro_parcela = p.nro_parcela))
           ->  Seq Scan on lote_uva l  (actual time=0.005..0.005 rows=0 loops=1)
           ->  Hash  (never executed)
                 ->  Seq Scan on parcela p  (never executed)
   ->  CTE Scan on rendimiento_parcela rp  (actual time=0.007..0.008 rows=0 loops=1)
         SubPlan 2
           ->  Aggregate  (never executed)
                 ->  CTE Scan on rendimiento_parcela rp2  (never executed)
 Planning Time: 1.116 ms
 Execution Time: 0.187 ms
```

**Resumen:**
- **Execution Time:** 0.187 ms
- **Filas devueltas:** 0 (no hay lotes de uva cargados en la base de la Etapa 3).
- **Observación:** El CTE se materializa pero no hay filas. El Hash Join entre `lote_uva` y `parcela` nunca se ejecuta porque `lote_uva` está vacío.

---

## S11: Ranking de vinos dentro de cada sala por botellas vendidas

**Consulta:** CTE con GROUP BY, RANK() OVER (PARTITION BY), suma acumulada con ventana.

**Resultado:**

```
                                                                                             QUERY PLAN                                                                                             
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Incremental Sort  (cost=21178.84..23257.89 rows=24600 width=72) (actual time=561.920..566.249 rows=600 loops=1)
   Sort Method: quicksort  Average Memory: 29kB  Peak Memory: 29kB
   Buffers: shared hit=5765
   ->  WindowAgg  (cost=21169.96..22092.46 rows=24600 width=72) (actual time=561.582..565.762 rows=600 loops=1)
         Buffers: shared hit=5759
         ->  WindowAgg  (cost=21169.96..21661.96 rows=24600 width=72) (actual time=561.563..564.659 rows=600 loops=1)
               Buffers: shared hit=5759
               ->  Sort  (cost=21169.96..21231.46 rows=24600 width=64) (actual time=561.550..563.959 rows=600 loops=1)
                     Sort Method: quicksort  Memory: 67kB
                     Buffers: shared hit=5759
                     ->  Subquery Scan on ventas_por_sala_vino  (actual time=560.289..563.397 rows=600 loops=1)
                           ->  Finalize HashAggregate  (actual time=560.287..563.268 rows=600 loops=1)
                                 Group Key: c.id_sala, rc.cod_vino, v.nombre
                                 Batches: 1  Memory Usage: 1297kB
                                 Buffers: shared hit=5759
                                 ->  Gather  (actual time=555.470..559.674 rows=1800 loops=1)
                                       Workers Planned: 2
                                       Workers Launched: 2
                                       Buffers: shared hit=5759
                                       ->  Partial HashAggregate  (actual time=548.337..549.037 rows=600 loops=3)
                                             Group Key: c.id_sala, rc.cod_vino, v.nombre
                                             Batches: 1  Memory Usage: 1041kB
                                             Buffers: shared hit=5759
                                             ->  Hash Join  (actual time=91.773..360.368 rows=125008 loops=3)
                                                   Hash Cond: (rc.cod_vino = v.cod_vino)
                                                   ->  Parallel Hash Join  (actual time=91.623..282.085 rows=125008 loops=3)
                                                         ->  Parallel Seq Scan on renglon_comprobante rc  (actual time=0.031..44.977 rows=125008 loops=3)
                                                               Buffers: shared hit=3101
                                                         ->  Parallel Hash  (actual time=90.243..90.245 rows=50000 loops=3)
                                                               ->  Parallel Seq Scan on comprobante c  (actual time=1.027..27.677 rows=50000 loops=3)
                                                                     Buffers: shared hit=2649
                                                   ->  Hash  (actual time=0.087..0.088 rows=60 loops=3)
                                                         ->  Seq Scan on vino v  (actual time=0.040..0.052 rows=60 loops=3)
                                                               Buffers: shared hit=3
 Planning Time: 2.641 ms
 Execution Time: 568.254 ms
```

**Resumen:**
- **Execution Time:** 568.254 ms
- **Recorrido:** Parallel Seq Scan sobre `renglon_comprobante`, Parallel Hash Join, Partial HashAggregate, WindowAgg (RANK + SUM con ventana), Incremental Sort.
- **Buffers:** shared hit=5765
- **Observación:** Similar a S1, con Parallel Seq Scan sobre la tabla grande. Las funciones de ventana (RANK y SUM acumulada) se aplican después del agregado.

---

## S12a: Clientes que compraron todos los vinos de una bodega (división relacional)

**Consulta:** NOT EXISTS doble correlacionada sobre `vino` y `renglon_comprobante`.

**Resultado:** Timeout al ejecutar con ANALYZE (>120 segundos). Plan sin ANALYZE:

```
                                                       QUERY PLAN                                                       
-------------------------------------------------------------------------------------------------------------------------
 Nested Loop Anti Join  (cost=0.00..398961468.06 rows=10000 width=28)
   Join Filter: (NOT (SubPlan 1))
   ->  Seq Scan on cliente c  (cost=0.00..510.00 rows=20000 width=28)
   ->  Materialize  (cost=0.00..1.78 rows=7 width=4)
         ->  Seq Scan on vino v  (cost=0.00..1.75 rows=7 width=4)
               Filter: (id_bodega = 1)
   SubPlan 1
     ->  Nested Loop  (cost=0.42..4559.54 rows=1 width=0)
           ->  Seq Scan on comprobante cp  (cost=0.00..4524.00 rows=8 width=4)
                 Filter: (id_cliente = c.id_cliente)
           ->  Index Only Scan using pk_renglon_comprobante on renglon_comprobante rc  (cost=0.42..4.44 rows=1 width=4)
                 Index Cond: ((nro_comprobante = cp.nro_comprobante) AND (cod_vino = v.cod_vino))
```

**Resumen:**
- **Plan original:** Nested Loop Anti Join con SubPlan correlacionado.
- **Costo estimado:** 398,961,468 (muy alto).
- **Observación:** La consulta original es inviable en este dataset (timeout >120s). Fue reescrita en `consultas/select.sql` usando `GROUP BY` + `HAVING COUNT(DISTINCT ...)` para evitar la correlación doble.

---

## S12b: Clientes que nunca compraron ningún vino tinto (anti-join con NOT EXISTS)

**Consulta:** NOT EXISTS sobre `renglon_comprobante → comprobante → vino` con filtro `tipo = 'tinto'`.

**Resultado:**

```
                                                                      QUERY PLAN                                                                      
------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=6785.98..6872.38 rows=10 width=28) (actual time=401.609..401.645 rows=10 loops=1)
   Buffers: shared hit=6061
   ->  Hash Right Anti Join  (cost=6785.98..16463.41 rows=1120 width=28) (actual time=401.607..401.640 rows=10 loops=1)
         Hash Cond: (cp.id_cliente = c.id_cliente)
         Buffers: shared hit=6061
         ->  Hash Join  (cost=6025.98..14226.53 rows=112507 width=4) (actual time=101.329..331.354 rows=112565 loops=1)
               Hash Cond: (rc.nro_comprobante = cp.nro_comprobante)
               ->  Hash Join  (cost=1.98..7907.18 rows=112507 width=4) (actual time=0.087..155.347 rows=112565 loops=1)
                     Hash Cond: (rc.cod_vino = v.cod_vino)
                     ->  Seq Scan on renglon_comprobante rc  (actual time=0.012..57.593 rows=375024 loops=1)
                           Buffers: shared hit=3101
                     ->  Hash  (actual time=0.041..0.043 rows=18 loops=1)
                           ->  Seq Scan on vino v  (actual time=0.013..0.023 rows=18 loops=1)
                                 Filter: (tipo = 'tinto'::tipo_vino)
                                 Rows Removed by Filter: 42
               ->  Hash  (actual time=99.854..99.855 rows=150000 loops=1)
                     Buckets: 262144  Batches: 1  Memory Usage: 7908kB
                     Buffers: shared hit=2649
                     ->  Seq Scan on comprobante cp  (actual time=1.831..35.948 rows=150000 loops=1)
                           Buffers: shared hit=2649
         ->  Hash  (actual time=15.607..15.607 rows=20000 loops=1)
               Buckets: 32768  Batches: 1  Memory Usage: 1434kB
               Buffers: shared hit=310
               ->  Seq Scan on cliente c  (actual time=0.016..7.431 rows=20000 loops=1)
                     Buffers: shared hit=310
 Planning Time: 2.995 ms
 Execution Time: 402.125 ms
```

**Resumen:**
- **Execution Time:** 402.125 ms
- **Plan:** Hash Right Anti Join, mucho más eficiente que S12a porque usa Hash en lugar de NOT EXISTS correlacionado.
- **Buffers:** shared hit=6061
- **Observación:** El planificador convierte el NOT EXISTS en un Anti Join con Hash, que es eficiente para este volumen de datos.

---

## Tabla comparativa resumen

| Consulta | Execution Time | Plan principal | Índices usados |
|----------|---------------|----------------|----------------|
| S1 | 435.127 ms | Parallel Hash Join + GroupAggregate | Ninguno (Seq Scan paralelo) |
| S4 | 0.235 ms | Hash Join + Limit | `idx_renglon_transferencia_cod_vino` (no ejecutado, 0 filas) |
| S8 | 57.891 ms | Parallel Hash Join + GroupAggregate | Ninguno (Seq Scan paralelo) |
| S9 | 0.721 ms | Nested Loop Left Join | `pk_bodega`, `pk_vino_cepa`, `pk_vino_maridaje` |
| S10 | 0.187 ms | Hash Join (CTE vacío) | Ninguno (0 filas) |
| S11 | 568.254 ms | Parallel Hash Join + WindowAgg | Ninguno (Seq Scan paralelo) |
| S12a | Optimizada (sin medir) | GROUP BY + HAVING COUNT DISTINCT | Ninguno (Hash Join esperado) |
| S12b | 402.125 ms | Hash Right Anti Join | Ninguno (Hash Join) |

**Conclusión:** Las consultas más costosas son S1 y S11, ambas con recorridos secuenciales paralelos sobre tablas grandes (`renglon_comprobante` con 375,024 filas). S12a fue reescrita para evitar el timeout de la versión original (NOT EXISTS correlionado doble) y ahora usa `GROUP BY` + `HAVING COUNT DISTINCT`, que permite al planificador usar `Hash Join` en lugar de `Nested Loop Anti Join`. Los índices creados en la Etapa 4 no se usan en S1 y S11 porque el planificador estima que Seq Scan es más barato para agregaciones completas sobre tablas grandes.
