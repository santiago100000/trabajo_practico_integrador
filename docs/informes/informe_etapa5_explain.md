# Informe Etapa 5 — Consultas SQL Avanzadas (EXPLAIN ANALYZE BUFFERS)

**Proyecto:** Bodegas del Atuel — TP Integrador de Bases de Datos (UTN FRSR)  
**Etapa:** 5 — Consultas SQL  
**Pasos completados:** Paso 1 (consultas SELECT S1 a S12), Paso 2 (consultas INSERT I1 a I6), Paso 3 (consultas UPDATE U1 a U6), Paso 4 (consultas DELETE D1 a D6), Paso 5 (medición EXPLAIN ANALYZE BUFFERS de consultas avanzadas S9 a S12 y S1, S4, S8 de referencia).  
**Estado:** Etapa 5 completa.  
**Base de datos:** PostgreSQL 16 (Docker), datos cargados Etapa 3 (semilla 42).  
**Archivos relacionados:** `consultas/select.sql`, `consultas/insert.sql`, `consultas/update.sql`, `consultas/delete.sql`.

---

## Paso 1 — Consultas SELECT avanzadas (S1 a S12)

Se implementaron 12 consultas SELECT en `consultas/select.sql`, cubriendo las consultas requeridas en la sección 8 del enunciado:

| Código | Consulta | Técnica SQL |
|--------|----------|-------------|
| S1 | Ranking de los 10 vinos más vendidos | JOIN múltiple, GROUP BY, SUM, ORDER BY DESC, LIMIT |
| S2 | Vinos vendidos en todas las salas | División relacional con NOT EXISTS doble |
| S3 | Clientes por tipo en última semana | JOIN, filtro por fecha, GROUP BY, COUNT DISTINCT |
| S4 | Top 5 salas por transferencias de un vino | JOIN, filtro por vino y fecha, GROUP BY, LIMIT |
| S5 | Salas con menos transferencias pendientes | LEFT JOIN, filtro por estado, GROUP BY, ORDER BY ASC |
| S6 | Vinos sin stock en sala pero con stock en depósito | INNER JOIN + LEFT JOIN, WHERE IS NULL o = 0 |
| S7 | Transporte con más ingresos en último mes | JOIN, filtro por fecha, GROUP BY, ORDER BY DESC, LIMIT |
| S8 | Monto total de ventas por sala (último trimestre) | JOIN, filtro por fecha, GROUP BY, SUM, ORDER BY DESC |
| S9 | Ficha completa de un vino | Múltiples JOINs, string_agg, stock total = depósito + salas |
| S10 | Rendimiento kg/ha por parcela y campaña | CTE, subconsulta correlacionada para promedio de finca |
| S11 | Ranking de vinos por sala con ventas acumuladas | CTE, RANK() OVER, suma acumulada con ventana |
| S12a | Clientes que compraron todos los vinos de una bodega | División relacional (reescrita con GROUP BY + HAVING COUNT DISTINCT) |
| S12b | Clientes que nunca compraron vino tinto | Anti-join con NOT EXISTS |

---

## Paso 2 — Consultas INSERT (I1 a I6)

Se implementaron 6 consultas INSERT en `consultas/insert.sql`:

| Código | Consulta | Característica |
|--------|----------|----------------|
| I1 | Cobertura transportista-localidad | Subconsulta para transportista con menos ingresos, ON CONFLICT DO NOTHING |
| I2 | Maridaje «cordero al disco» para vinos tintos ≥ 14° | Bloque DO condicional, INSERT con ON CONFLICT DO NOTHING |
| I3 | Comprobante con 3 renglones | Transacción, triggers recalculan totales y descuentan stock |
| I4 | Nueva bodega | INSERT con CUIT único |
| I5 | Nueva sala de venta | INSERT en localidad específica |
| I6 | Ingreso en confección con 120 botellas | INSERT en estado 'en_confeccion' + renglón de ingreso |

Todas envueltas en transacciones `BEGIN`/`ROLLBACK` para pruebas seguras, con consultas de control previa y posterior.

---

## Paso 3 — Consultas UPDATE (U1 a U6)

Se implementaron 6 consultas UPDATE en `consultas/update.sql`:

| Código | Consulta | Característica |
|--------|----------|----------------|
| U1 | Recalcular totales de comprobantes | UPDATE con subconsulta de suma de renglones |
| U2 | Aumentar salario 20% a empleados > 5 años | UPDATE con filtro por fecha de ingreso |
| U3 | Incrementar precio 13% a vinos de una bodega | UPDATE que dispara trigger de auditoría (RN-13) |
| U4 | Intercambiar días de cierre lunes↔miércoles | UPDATE con CASE WHEN en una sola sentencia |
| U5 | Descuento 15% a los 10 vinos menos vendidos | UPDATE con subconsulta de menos vendidos |
| U6 | Subir descuento al 35% a exportadores con > 3 permisos | UPDATE con subconsulta HAVING COUNT > 3 |

Todas envueltas en transacciones con consultas de control previa y posterior.

---

## Paso 4 — Consultas DELETE (D1 a D6)

Se implementaron 6 consultas DELETE en `consultas/delete.sql`:

| Código | Consulta | Característica |
|--------|----------|----------------|
| D1 | Borrar comprobantes > 5 años de clientes socios | DELETE con JOIN, ON DELETE CASCADE borra renglones |
| D2 | Eliminar cepas huérfanas | DELETE con NOT EXISTS doble |
| D3 | Eliminar empleados < 2 años en localidad específica | DELETE con JOIN múltiplo, filtro por fecha |
| D4 | Borrar clientes socios sin compras > 5 años | DELETE con NOT EXISTS, CASCADE borra subtipo |
| D5 | Eliminar ingresos procesados > 365 días | DELETE con filtro por estado y fecha, CASCADE |
| D6 | Borrar clientes socios sin compras en localidad | DELETE con JOIN, NOT EXISTS, filtro por localidad |

Todas envueltas en transacciones con consultas de control previa y posterior.

---

## Paso 5 — Medición EXPLAIN (ANALYZE, BUFFERS) de consultas avanzadas

Se ejecutaron planes de ejecución con `EXPLAIN (ANALYZE, BUFFERS)` para las consultas avanzadas de la etapa 5 (S9 a S12) y consultas de referencia de la etapa 4 (S1, S4, S8).

### S1: Ranking de los 10 vinos con mayor cantidad de botellas vendidas

**Tiempo de ejecución:** 435.127 ms

**Resumen:**
- **Recorrido:** Parallel Seq Scan sobre `renglon_comprobante`, Parallel Seq Scan sobre `comprobante`, Seq Scan sobre `vino`.
- **Buffers:** shared hit=5776
- **Observación:** El planificador usa Hash Join y Parallel Hash Aggregate. No hay índice sobre la FK `cod_vino` en `renglon_comprobante` que ayude al JOIN con `vino` para este tipo de agregación completa, por lo que se hace Seq Scan paralelo sobre la tabla grande.

### S4: Top 5 salas que solicitaron mayor cantidad de un vino mediante transferencias (últimos 15 días)

**Tiempo de ejecución:** 0.235 ms

**Resumen:**
- **Filas devueltas:** 0 (no hay transferencias cargadas en la base de la Etapa 3).
- **Índice usado:** `idx_renglon_transferencia_cod_vino` (Bitmap Index Scan), creado en la Etapa 4.
- **Observación:** Como no hay filas en `transferencia`, el Bitmap Heap Scan nunca se ejecuta. El índice sobre la FK `cod_vino` existe y está listo para cuando haya datos.

### S8: Monto total de ventas por sala en el último trimestre

**Tiempo de ejecución:** 57.891 ms

**Resumen:**
- **Recorrido:** Parallel Seq Scan sobre `comprobante`, Seq Scan sobre `sala_venta`.
- **Buffers:** shared hit=2664
- **Observación:** El filtro por fecha descarta 56,242 filas. El índice compuesto `idx_comprobante_sala_fecha` (creado en Etapa 4) no se usa porque el planificador estima que Seq Scan es más barato para este volumen de datos filtrado.

### S9: Ficha de un vino (cepas, bodega, maridajes, stock total)

**Tiempo de ejecución:** 0.721 ms

**Resumen:**
- **Índices usados:** `pk_bodega` (Index Scan), `pk_vino_cepa` (Bitmap Index Scan), `pk_vino_maridaje` (Bitmap Index Scan).
- **Buffers:** shared hit=23
- **Observación:** Muy rápido porque filtra por PK de `vino` y usa los índices de PK de las tablas relacionadas.

### S10: Rendimiento en kg por hectárea por parcela y campaña

**Tiempo de ejecución:** 0.187 ms

**Resumen:**
- **Filas devueltas:** 0 (no hay lotes de uva cargados en la base de la Etapa 3).
- **Observación:** El CTE se materializa pero no hay filas. El Hash Join entre `lote_uva` y `parcela` nunca se ejecuta porque `lote_uva` está vacío.

### S11: Ranking de vinos dentro de cada sala por botellas vendidas

**Tiempo de ejecución:** 568.254 ms

**Resumen:**
- **Recorrido:** Parallel Seq Scan sobre `renglon_comprobante`, Parallel Hash Join, Partial HashAggregate, WindowAgg (RANK + SUM con ventana), Incremental Sort.
- **Buffers:** shared hit=5765
- **Observación:** Similar a S1, con Parallel Seq Scan sobre la tabla grande. Las funciones de ventana (RANK y SUM acumulada) se aplican después del agregado.

### S12a: Clientes que compraron todos los vinos de una bodega (división relacional)

**Tiempo de ejecución:** 232.222 ms

**Resumen:**
- **Plan principal:** Hash Join + GroupAggregate con `HAVING COUNT(DISTINCT v.cod_vino)`.
- **Índices usados:** Ninguno (Parallel Seq Scan sobre tablas grandes).
- **Buffers:** shared hit=6131
- **Observación:** La versión original usaba `NOT EXISTS` correlionado doble, lo que generaba un plan de costo extremadamente alto y un timeout (>120 segundos). La consulta fue reescrita en `consultas/select.sql` usando `GROUP BY` + `HAVING COUNT(DISTINCT ...)` comparado con el total de vinos de la bodega. El planificador ahora usa Hash Join en lugar de Nested Loop Anti Join, y la subconsulta de conteo de vinos de la bodega se resuelve eficientemente.

### S12b: Clientes que nunca compraron ningún vino tinto (anti-join con NOT EXISTS)

**Tiempo de ejecución:** 402.125 ms

**Resumen:**
- **Plan:** Hash Right Anti Join.
- **Buffers:** shared hit=6061
- **Observación:** El planificador convierte el NOT EXISTS en un Anti Join con Hash, que es eficiente para este volumen de datos.

---

## Tabla comparativa resumen

| Consulta | Tiempo de ejecución | Plan principal | Índices usados |
|----------|-------------------|----------------|----------------|
| S1 | 435.127 ms | Parallel Hash Join + GroupAggregate | Ninguno (Seq Scan paralelo) |
| S4 | 0.235 ms | Hash Join + Limit | `idx_renglon_transferencia_cod_vino` (no ejecutado, 0 filas) |
| S8 | 57.891 ms | Parallel Hash Join + GroupAggregate | Ninguno (Seq Scan paralelo) |
| S9 | 0.721 ms | Nested Loop Left Join | `pk_bodega`, `pk_vino_cepa`, `pk_vino_maridaje` |
| S10 | 0.187 ms | Hash Join (CTE vacío) | Ninguno (0 filas) |
| S11 | 568.254 ms | Parallel Hash Join + WindowAgg | Ninguno (Seq Scan paralelo) |
| S12a | 232.222 ms | Hash Join + GroupAggregate | Ninguno (Parallel Seq Scan) |
| S12b | 402.125 ms | Hash Right Anti Join | Ninguno (Hash Join) |

---

## Conclusión

Las consultas más costosas son S1 y S11, ambas con recorridos secuenciales paralelos sobre tablas grandes (`renglon_comprobante` con ~375,024 filas). S12a fue reescrita para evitar el timeout de la versión original (NOT EXISTS correlionado doble que tardaba >120s) y ahora ejecuta en 232.222 ms usando `GROUP BY` + `HAVING COUNT DISTINCT`. Los índices creados en la Etapa 4 no se usan en S1 y S11 porque el planificador estima que Seq Scan es más barato para agregaciones completas sobre tablas grandes.

Todos los archivos de consultas de la etapa 5 están implementados y documentados en `consultas/select.sql`, `consultas/insert.sql`, `consultas/update.sql` y `consultas/delete.sql`.

---

## Archivos relacionados

- `consultas/select.sql` — 12 consultas SELECT (S1 a S12)
- `consultas/insert.sql` — 6 consultas INSERT (I1 a I6)
- `consultas/update.sql` — 6 consultas UPDATE (U1 a U6)
- `consultas/delete.sql` — 6 consultas DELETE (D1 a D6)
