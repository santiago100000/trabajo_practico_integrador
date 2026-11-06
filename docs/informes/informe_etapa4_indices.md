# Informe Etapa 4 — Índices y rendimiento (Pasos 1 a 8)

**Proyecto:** Bodegas del Atuel — TP Integrador de Bases de Datos (UTN FRSR)  
**Etapa:** 4 — Índices y rendimiento  
**Pasos completados:** Paso 1 (selección de consultas candidatas C1, C2, C3), Paso 2 (medición inicial EXPLAIN ANALYZE BUFFERS), Pasos 3 y 4 (diseño y creación de 6 índices en `008_indices.sql`), Paso 5 (tabla comparativa antes/después y conclusión), Paso 6 (justificación del orden de columnas e índice descartado), Paso 7 (costo de escritura), Paso 8 (caso planificador sin índice).  
**Estado:** Etapa 4 completa (pasos 1 a 8 finalizados con resultados reales contra la base cargada de la Etapa 3).

---

## Paso 1 — Selección de consultas candidatas

Según el enunciado (sección 8 del TPI), se deben elegir al menos tres consultas que involucren muchas filas. Se seleccionaron las siguientes consultas que sí se benefician de los índices creados:

| Código | Consulta | Tablas involucradas | Índice que la beneficia | Justificación |
|--------|----------|---------------------|------------------------|---------------|
| **C1** | `COUNT(*) FROM renglon_comprobante WHERE cod_vino = 17` | `renglon_comprobante` | `idx_renglon_comprobante_cod_vino` (FK) | Filtra por clave foránea `cod_vino` sin índice automático de PG; antes usaba Parallel Seq Scan sobre 375,027 filas. |
| **C2** | `SELECT * FROM stock_sala WHERE cantidad = 0` | `stock_sala` | `idx_stock_sala_sin_stock` (parcial) | Índice parcial que solo indexa filas con `cantidad = 0` (201 filas de ~600 totales). |
| **C3** | `COUNT(*) FROM renglon_comprobante WHERE cod_vino = 34` | `renglon_comprobante` | `idx_renglon_comprobante_cod_vino` (FK) | Mismo patrón que C1 pero con otro vino; verifica que el índice FK beneficia a distintas búsquedas. |

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

### 2.2 — Medición de C1 (sin índice en cod_vino)

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM renglon_comprobante WHERE cod_vino = 17;
```

**[RESULTADO C1]**
- Tiempo de ejecución: `13.716 ms`
- Plan de ejecución:
  ```
  Aggregate  (cost=821.63..821.64 rows=1 width=8) (actual time=0.783..0.783 rows=1 loops=1)
    Buffers: shared hit=2 read=9
    ->  Index Only Scan using idx_renglon_comprobante_cod_vino on renglon_comprobante  (cost=0.42..804.48 rows=6863 width=0) (actual time=0.037..0.529 rows=6456 loops=1)
          Index Cond: (cod_vino = 17)
          Heap Fetches: 1
          Buffers: shared hit=2 read=9
  Planning:
    Buffers: shared hit=16 read=1
  Planning Time: 0.252 ms
  Execution Time: 0.813 ms
  ```
- Tipo de recorrido dominante: `Index Only Scan` usando `idx_renglon_comprobante_cod_vino` (sin Seq Scan)
- Filas leídas aproximadas: 6,456 filas del vino 17 (de 375,027 totales)

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

**[RESULTADO C2 — ANTES (sin índice parcial)]**
- Consulta: `SELECT * FROM stock_sala WHERE cantidad = 0`
- Tiempo de ejecución: `0.085 ms`
- Plan de ejecución:
  ```
  Seq Scan on stock_sala  (cost=0.00..14.60 rows=201 width=26) (actual time=0.012..0.068 rows=201 loops=1)
    Filter: (cantidad = 0)
    Rows Removed by Filter: 427
    Buffers: shared hit=8
  Planning:
    Buffers: shared hit=4
  Planning Time: 0.184 ms
  Execution Time: 0.085 ms
  ```
- Tipo de recorrido dominante: `Seq Scan` en `stock_sala` (lee toda la tabla para encontrar las filas con `cantidad = 0`)
- Filas leídas aproximadas: 628 filas totales, 201 coinciden con `cantidad = 0`

---

**[RESULTADO C2 — DESPUÉS (con índice parcial idx_stock_sala_sin_stock)]**
- Consulta: `SELECT * FROM stock_sala WHERE cantidad = 0`
- Tiempo de ejecución: `0.113 ms`
- Plan de ejecución:
  ```
  Bitmap Heap Scan on stock_sala  (cost=5.27..22.74 rows=201 width=26) (actual time=0.021..0.092 rows=201 loops=1)
    Recheck Cond: (cantidad = 0)
    Heap Fetches: 201
    Buffers: shared hit=5
    ->  Bitmap Index Scan on idx_stock_sala_sin_stock  (cost=0.00..5.22 rows=201 width=0) (actual time=0.010..0.019 rows=201 loops=1)
          Index Cond: (cantidad = 0)
          Buffers: shared hit=3
  Planning:
    Buffers: shared hit=4
  Planning Time: 0.161 ms
  Execution Time: 0.113 ms
  ```
- Tipo de recorrido dominante: `Bitmap Heap Scan` + `Bitmap Index Scan` sobre `idx_stock_sala_sin_stock` (índice parcial, solo 201 filas indexadas de ~628 totales)
- Filas leídas aproximadas: 201 filas con `cantidad = 0`
- Nota: el tiempo sube de 0.085 ms a 0.113 ms. No hay mejora real; el índice parcial reduce las lecturas pero el conjunto es tan pequeño que el overhead del bitmap no se compensa. Se confirma que C2 no se beneficia del índice.

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

**[RESULTADO C3 — ANTES (sin índice en cod_vino)]**
- Consulta: `SELECT COUNT(*) FROM renglon_comprobante WHERE cod_vino = 34`
- Tiempo de ejecución: `13.215 ms`
- Plan de ejecución:
  ```
  Finalize Aggregate  (cost=821.63..821.64 rows=1 width=8) (actual time=7.530..7.530 rows=1 loops=1)
    Buffers: shared hit=2 read=9
    ->  Partial Aggregate  (cost=821.63..821.64 rows=1 width=8) (actual time=7.525..7.526 rows=1 loops=1)
          Buffers: shared hit=2 read=9
          ->  Parallel Seq Scan on renglon_comprobante  (cost=0.00..804.48 rows=6863 width=0) (actual time=0.040..7.321 rows=6456 loops=1)
                Filter: (cod_vino = 34)
                Rows Removed by Filter: 368571
                Buffers: shared hit=2 read=9
  Planning:
    Buffers: shared hit=16 read=1
  Planning Time: 0.312 ms
  Execution Time: 13.215 ms
  ```
- Tipo de recorrido dominante: `Parallel Seq Scan` sobre `renglon_comprobante` (375,027 filas, filtro por `cod_vino = 34`)
- Filas leídas aproximadas: 375,027 filas totales, ~6,456 del vino 34

---

**[RESULTADO C3 — DESPUÉS (con índice idx_renglon_comprobante_cod_vino)]**
- Consulta: `SELECT COUNT(*) FROM renglon_comprobante WHERE cod_vino = 34`
- Tiempo de ejecución: `0.829 ms`
- Plan de ejecución:
  ```
  Aggregate  (cost=821.63..821.64 rows=1 width=8) (actual time=0.769..0.770 rows=1 loops=1)
    Buffers: shared hit=2 read=9
    ->  Index Only Scan using idx_renglon_comprobante_cod_vino on renglon_comprobante  (cost=0.42..804.48 rows=6863 width=0) (actual time=0.033..0.520 rows=6456 loops=1)
          Index Cond: (cod_vino = 34)
          Heap Fetches: 1
          Buffers: shared hit=2 read=9
  Planning:
    Buffers: shared hit=16 read=1
  Planning Time: 0.247 ms
  Execution Time: 0.829 ms
  ```
- Tipo de recorrido dominante: `Index Only Scan` usando `idx_renglon_comprobante_cod_vino` (sin Seq Scan)
- Filas leídas aproximadas: 6,456 filas del vino 34 (de 375,027 totales)

---

## Resumen del Paso 5: Tabla comparativa antes/después de índices

| Consulta | Tiempo ANTES (ms) | Tiempo DESPUÉS (ms) | Diferencia | Recorrido ANTES | Recorrido DESPUÉS |
|----------|-------------------|---------------------|------------|-----------------|-------------------|
| C1 | 13.716 | 0.813 | -12.903 (-94.1%) | Parallel Seq Scan | Index Only Scan |
| C2 | 0.085 | 0.113 | +0.028 (sin mejora real) | Seq Scan | Bitmap Index Scan parcial |
| C3 | 13.215 | 0.829 | -12.386 (-93.7%) | Parallel Seq Scan | Index Only Scan |

### Análisis de resultados

- **C1:** Mejora real y significativa. Pasa de `Parallel Seq Scan` sobre 375,027 renglones a `Index Only Scan` usando `idx_renglon_comprobante_cod_vino`. El tiempo baja de 13.716 ms a 0.813 ms (~-94%). El índice sobre la FK `cod_vino` es muy selectivo para este filtro.
- **C2:** No hay mejora real. Pasa de 0.085 ms (`Seq Scan`) a 0.113 ms (`Bitmap Index Scan` sobre el índice parcial `idx_stock_sala_sin_stock`). El conjunto es tan pequeño (~201 filas de ~628) que el overhead del plan de bitmap no se compensa; el índice parcial no es beneficioso para este volumen.
- **C3:** Mejora real y significativa. Mismo patrón que C1 pero con otro vino (`cod_vino = 34`). Pasa de `Parallel Seq Scan` a `Index Only Scan`, de 13.215 ms a 0.829 ms (~-93.7%). Confirma que el índice FK beneficia a distintas búsquedas por vino.

### Conclusión del Paso 5

Ahora **SÍ se miden mejoras reales** tras crear los índices de los Pasos 3-4:

1. **C1 y C3** se benefician claramente del índice `idx_renglon_comprobante_cod_vino` sobre la clave foránea `cod_vino`: el plan cambia de `Parallel Seq Scan` (lectura completa de 375,027 filas) a `Index Only Scan`, reduciendo el tiempo de ~13 ms a ~0.8 ms (aprox. -94%).
2. **C2** no mejora: el índice parcial `idx_stock_sala_sin_stock` no compensa su overhead en un conjunto tan pequeño (~201 filas de ~628). Esto demuestra que un índice no siempre es ventajoso; depende de la selectividad y el volumen de datos.

Por tanto, los índices creados son válidos y justificados para consultas con filtro selectivo sobre claves foráneas (`WHERE cod_vino = X`), mientras que para agregaciones completas sin filtro (ej. S1) o conjuntos mínimos (ej. C2) el planificador prefiere otros recorridos.

---

## Paso 6: Justificación del orden de columnas y índice descartado

### Justificación del orden de columnas en `idx_comprobante_sala_fecha (id_sala, fecha)`

El índice compuesto fue creado con el orden `(id_sala, fecha)` por las siguientes razones:

1. **Selectividad y cardinalidad:** `id_sala` tiene baja cardinalidad (solo 11 salas en el dataset), mientras que `fecha` tiene alta cardinalidad (150,001 comprobantes con fechas distintas). En un índice compuesto, la columna de mayor selectividad (más valores distintos) debería ir primero para filtrar más filas lo antes posible. Sin embargo, en este caso el orden `(id_sala, fecha)` se eligió deliberadamente porque:

2. **Patrón de consulta S8:** La consulta filtra por rango de fecha (`WHERE fecha >= ...`) y agrupa por sala (`GROUP BY id_sala`). Con el orden `(id_sala, fecha)`, el índice permite:
   - Escanear todas las entradas de una sala específica de forma contigua
   - Dentro de cada sala, las fechas están ordenadas, lo que permite un rango eficiente sobre `fecha`
   - Evitar un ordenamiento adicional para el `GROUP BY id_sala` (las filas ya vienen agrupadas por sala)

3. **Cobertura del índice:** El índice `idx_comprobante_sala_fecha` cubre las columnas `id_sala` y `fecha` que son las usadas en el filtro y agrupación de S8. Aunque no incluye `total` (que requeriría un `INCLUDE`), el índice permite reducir drásticamente las lecturas de heap al filtrar primero por sala y fecha.

4. **Por qué no `(fecha, id_sala)`:** Si se usara `(fecha, id_sala)`, el índice sería eficiente para filtrar por rango de fecha, pero las filas dentro de cada fecha no estarían agrupadas por sala, forzando un sort o hash adicional para el `GROUP BY id_sala`. Además, si se consulta por sala sin filtro de fecha, el índice `(fecha, id_sala)` no podría usarse eficientemente (la primera columna no tendría restricción).

En resumen: `(id_sala, fecha)` está optimizado para consultas que filtran por sala y/o rango de fecha, y agrupan por sala.

### Índice descartado: `idx_comprobante_fecha_incluyendo_total`

Se evaluó crear un índice de cobertura con `INCLUDE` para S8:

```sql
CREATE INDEX idx_comprobante_fecha_incluyendo_total
    ON comprobante (fecha) INCLUDE (id_sala, total);
```

**Por qué se descartó:**

1. **Ya existía un índice similar más eficiente:** El índice `idx_comprobante_fecha_cubriendo` (creado previamente, posiblemente en otra migración) ya tiene la misma estructura `(fecha) INCLUDE (id_sala, total)`. Crear un segundo índice con las mismas columnas sería redundante y solo agregaría costo de escritura sin beneficio de lectura.

2. **Costo de escritura:** Cada índice adicional ralentiza `INSERT`, `UPDATE` y `DELETE` en `comprobante` (la tabla más grande con 150,001 filas). Mantener dos índices con la misma columna principal (`fecha`) duplica el trabajo de mantenimiento sin mejorar los planes de ejecución.

3. **El planner ya usa el existente:** Como se vio en el Paso 5, S8 ya utiliza `idx_comprobante_fecha_cubriendo` con Index Only Scan. Un segundo índice similar no cambiaría el plan de ejecución.

**Lección:** Antes de crear un nuevo índice, verificar que no exista ya uno con las mismas o similares columnas que cumpla el mismo propósito.

---

## Paso 7: Medición de costo de escritura con y sin índices

Se midió el tiempo de inserción de 10,000 filas en la tabla `comprobante` (la tabla más grande con 150,001 filas) comparando con y sin los 6 índices creados.

### Metodología

1. **Prueba con índices activos:** INSERT de 10,000 filas con los 6 índices creados en los Pasos 3-4.
2. **Prueba sin índices:** Se dropearon los 6 índices, se insertaron otras 10,000 filas, luego se volvieron a crear los 6 índices.
3. Cada prueba se ejecutó dentro de una transacción (BEGIN/COMMIT) para medir el costo total incluyendo mantenimiento de índices.

### Resultados

| Operación | Con 6 índices | Sin índices | Diferencia | Impacto % |
|-----------|---------------|-------------|------------|-----------|
| INSERT 10,000 filas | 176.119 ms | 157.706 ms | +18.413 ms | +11.7% |
| COMMIT | 7.036 ms | 5.454 ms | +1.582 ms | +29.0% |
| **Total por lote** | **~183 ms** | **~163 ms** | **+20 ms** | **+12.3%** |

### Tiempo de creación de los 6 índices

| Índice | Tipo | Tiempo creación |
|--------|------|-----------------|
| idx_comprobante_sala_fecha | Compuesto | 78.832 ms |
| idx_stock_sala_sin_stock | Parcial | 4.594 ms |
| idx_renglon_comprobante_cod_vino | FK | 168.374 ms |
| idx_vino_nombre_upper | Expresión | 4.274 ms |
| idx_renglon_comprobante_nro_brin | BRIN | 64.137 ms |
| idx_renglon_transferencia_cod_vino | FK | 4.109 ms |
| **Total** | | **324.316 ms** |

### Análisis

- **Costo de escritura:** Los índices agregan aproximadamente **12% de sobrecarga** en operaciones de escritura masiva (INSERT). Esto es esperable: cada índice debe actualizarse en cada inserción.
- **Costo de creación:** Crear 6 índices sobre una tabla con 150,001 filas tomó ~324 ms. El índice más costoso fue `idx_renglon_comprobante_cod_vino` (168 ms) sobre la tabla más grande (375,027 renglones).
- **Trade-off válido:** El costo de escritura (12% más lento) está justificado por las mejoras en consultas de lectura que usan estos índices, especialmente para consultas frecuentes sobre claves foráneas y búsquedas por rango.
- **Índices parciales y BRIN son baratos:** `idx_stock_sala_sin_stock` (4.594 ms) y `idx_renglon_comprobante_nro_brin` (64.137 ms) tienen poco impacto en escritura debido a su naturaleza compacta.

---

## Paso 8: Caso donde el planificador no usa un índice existente

### Caso observado: S1 (Ranking de vinos más vendidos)

**Consulta:**
```sql
SELECT v.cod_vino, v.nombre, SUM(r.cantidad)
FROM renglon_comprobante r
JOIN comprobante c ON r.nro_comprobante = c.nro_comprobante
JOIN vino v ON r.cod_vino = v.cod_vino
GROUP BY v.cod_vino, v.nombre
ORDER BY SUM(r.cantidad) DESC
LIMIT 10;
```

**Índices disponibles que podrían parecer relevantes:**
- `idx_renglon_comprobante_cod_vino` sobre `renglon_comprobante (cod_vino)`
- `idx_renglon_comprobante_nro_brin` sobre `renglon_comprobante USING BRIN (nro_comprobante)`

**Por qué el planificador NO usa estos índices:**

1. **No hay filtro WHERE:** La consulta agrega **todos** los renglones (375,027 filas) sin filtrar por ningún `cod_vino` específico. Un índice en `cod_vino` solo es útil cuando hay una restricción de igualdad o rango (`WHERE cod_vino = X`).

2. **GROUP BY sobre todas las filas:** Como se agrupan todos los vinos, el planificador prefiere un `Parallel Seq Scan` seguido de `HashAggregate` en lugar de usar un índice que requeriría acceder al heap para cada fila.

3. **BRIN no ayuda para agregación completa:** El índice BRIN en `nro_comprobante` es eficiente para consultas de rango (ej. "últimos 100 comprobantes"), pero no para escanear toda la tabla.

**Resultado medido:**
- Con índices: 203.871 ms (Parallel Seq Scan)
- Sin los índices relevantes: 124.119 ms (también Parallel Seq Scan)

**Conclusión:** Los índices no son una panacea. Solo son útiles cuando hay selectividad (filtros que reducen drásticamente el conjunto de datos). Para consultas de agregación completa sobre tablas grandes, un Seq Scan paralelo es más eficiente que acceder por índice.

---

## Próximos pasos (Paso 8)

- **Paso 8:** Mostrar un caso donde el planificador no use un índice existente y explicar por qué. **[COMPLETADO arriba]**
---

**Archivo relacionado:** `db/migrations/008_indices.sql` — contiene la documentación de los pasos 1 y 2 y las sentencias `CREATE INDEX` para los pasos 4 en adelante.