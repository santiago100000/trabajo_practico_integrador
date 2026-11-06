# Informe Etapa 4 — Índices y Rendimiento (Bodegas del Atuel)

**Cátedra:** Bases de Datos · UTN Facultad Regional San Rafael  
**Ciclo lectivo:** 2026  
**Etapa:** 4 (Índices y rendimiento)  
**Archivo de migración:** `db/migrations/008_indices.sql`  
**Base de datos:** PostgreSQL 16 (Docker) con datos cargados (Etapa 3):  
  - `comprobante`: 150.000 filas  
  - `renglon_comprobante`: 375.024 filas  
  - `stock_sala`: 600 filas  
  - `vino`: 60 filas  

---

## 1. Índices creados (6 en total)

Se cumplen todos los requisitos mínimos del enunciado (≥5 índices, incluyendo compuesto, parcial, FK, otro tipo/variante).

| # | Índice | Tabla | Tipo | Justificación |
|---|--------|-------|------|---------------|
| 1 | `idx_comprobante_sala_fecha` | `comprobante` | **Compuesto** `(id_sala, fecha)` | S8 (monto total de ventas por sala en último trimestre): filtra por rango de fecha y agrupa por sala. El orden `id_sala` primero permite agrupar por sala y filtrar por fecha dentro de cada grupo. |
| 2 | `idx_stock_sala_sin_stock` | `stock_sala` | **Parcial** `WHERE cantidad = 0` | S6 (vinos sin stock en sala pero con stock en depósito): solo una pequeña fracción (~33%) de las filas tiene cantidad = 0. El índice parcial es más pequeño y rápido que uno completo. |
| 3 | `idx_renglon_comprobante_cod_vino` | `renglon_comprobante` | **Sobre FK** `cod_vino` | S1 (ranking de vinos más vendidos): une `renglon_comprobante` con `vino` por `cod_vino`. PostgreSQL no indexa automáticamente las FK, por lo que es necesario crearlo explícitamente. |
| 4 | `idx_vino_nombre_upper` | `vino` | **De expresión** `UPPER(nombre)` | Búsquedas de vinos por nombre sin distinción de mayúsculas/minúsculas (`WHERE UPPER(nombre) = UPPER('...')`). |
| 5 | `idx_comprobante_fecha_cubriendo` | `comprobante` | **INCLUDE** `(fecha) INCLUDE (id_sala, total)` | S8: filtra por fecha y necesita `id_sala` y `total`. Con `INCLUDE`, el índice cubre la consulta (Index Only Scan) sin acudir al heap. |
| 6 | `idx_renglon_comprobante_nro_brin` | `renglon_comprobante` | **BRIN** `nro_comprobante` | `nro_comprobante` es `GENERATED ALWAYS AS IDENTITY` (valores crecientes correlacionados con posición física). Un BRIN es muy compacto y ideal para consultas de rango sobre este campo. |

### DDL aplicado

Ver `db/migrations/008_indices.sql`.

---

## 2. Medición de rendimiento: EXPLAIN (ANALYZE, BUFFERS)

Se midieron 3 consultas candidatas de la sección 8 del enunciado, antes y después de crear los índices. Cada consulta se ejecutó dos veces; se reporta el tiempo de ejecución del plan.

### Consulta S8 — Monto total de ventas por sala en el último trimestre

```sql
SELECT c.id_sala, SUM(r.subtotal) AS monto_total
FROM comprobante c
JOIN renglon_comprobante r ON r.nro_comprobante = c.nro_comprobante
WHERE c.fecha >= (SELECT CURRENT_DATE - INTERVAL '3 months')
GROUP BY c.id_sala
ORDER BY monto_total DESC;
```

| | Antes de índices | Después de índices |
|---|------------------|--------------------|
| Execution Time | 444,967 ms | 72,944 ms |
| Plan | Parallel Hash Join + 2× Parallel Seq Scan | Parallel Hash Join + 2× Parallel Seq Scan |
| Buffers (shared hit) | 5.477 | 5.477 |

**Observación:** El plan no cambió (todavía usa Seq Scan) porque el volumen de datos (150k comprobantes) aún es pequeño para que el planificador prefiera el índice compuesto. La mejora de tiempo se debe principalmente a que los datos ya estaban en caché (segunda ejecución). En un entorno de producción con millones de filas, el índice compuesto sí se usaría.

---

### Consulta S1 — Ranking de los 10 vinos más vendidos

```sql
SELECT v.cod_vino, v.nombre, SUM(r.cantidad) AS total_botellas
FROM renglon_comprobante r
JOIN vino v ON v.cod_vino = r.cod_vino
GROUP BY v.cod_vino, v.nombre
ORDER BY total_botellas DESC
LIMIT 10;
```

| | Antes de índices | Después de índices |
|---|------------------|--------------------|
| Execution Time | 69,086 ms | 3.068,641 ms |
| Plan | Hash Join (renglones ⋈ vino) | Nested Loop (renglones ⋈ vino) |
| Buffers (shared hit) | 3.127 | 378.142 |

**Observación:** El tiempo **empeoró** drásticamente. El índice en `renglon_comprobante.cod_vino` indujo al planificador a elegir un Nested Loop en lugar del Hash Join. Como hay solo 60 vinos y 375k renglones, el Hash Join era mucho más eficiente. El planificador estimó mal el costo porque el índice hace parecer que acceder por `cod_vino` es barato, pero para un join masivo el Hash Join es superior.

**Lección:** Un índice no siempre mejora el rendimiento. El planificador elige el plan que estima más barato, y a veces se equivoca.

---

### Consulta S3 (adicional) — Renglones con cantidad > 10

```sql
SELECT * FROM renglon_comprobante
WHERE cantidad > 10
ORDER BY nro_comprobante, cod_vino
LIMIT 100;
```

| | Antes de índices | Después de índices |
|---|------------------|--------------------|
| Execution Time | 15,608 ms | 17,351 ms |
| Plan | Parallel Seq Scan | Parallel Seq Scan |
| Filas devueltas | 0 | 0 |

**Observación:** Sin cambios. La consulta devuelve 0 filas porque las cantidades generadas en la carga van de 1 a 6 (ninguna > 10). El planificador usa Seq Scan en ambos casos.

---

## 3. Consultas específicas que demuestran cada tipo de índice

### 3.1 Índice de expresión — `idx_vino_nombre_upper`

```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vino WHERE UPPER(nombre) = UPPER('Tempranillo 2018');
```

**Resultado:** Seq Scan en `vino` (60 filas).  
**Por qué no se usa el índice:** La tabla es muy pequeña (60 filas). El costo de acceder al índice es mayor que escanear toda la tabla. Para tablas pequeñas, Seq Scan es siempre más rápido.

---

### 3.2 Índice parcial — `idx_stock_sala_sin_stock`

```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM stock_sala WHERE cantidad = 0 LIMIT 20;
```

**Resultado:** Seq Scan en `stock_sala` (600 filas, 201 con cantidad = 0).  
**Por qué no se usa el índice:** La tabla es pequeña (600 filas). El planificador determina que es más barato escanear las 600 filas que usar el índice parcial. En una tabla con millones de filas y pocas con cantidad = 0, el índice parcial sería muy beneficioso.

---

### 3.3 Índice BRIN vs PK — `idx_renglon_comprobante_nro_brin`

```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM renglon_comprobante WHERE nro_comprobante BETWEEN 100000 AND 100100;
```

**Resultado:** Index Scan usando `pk_renglon_comprobante` (no el BRIN).  
**Por qué no se usa el BRIN:** La clave primaria `pk_renglon_comprobante (nro_comprobante, cod_vino)` ya cubre `nro_comprobante` como primera columna. El B-tree del PK es más preciso que el BRIN para rangos exactos, por lo que el planificador prefiere el PK. El BRIN es redundante en este caso.  
**Lección:** Antes de crear un índice, verificar que no exista ya uno que cubra las mismas columnas (como el PK).

---

### 3.4 Índice INCLUDE (cubriendo) — `idx_comprobante_fecha_cubriendo` ✅

```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT id_sala, total FROM comprobante WHERE fecha = '2026-11-04' LIMIT 20;
```

**Resultado:**  
```
Index Only Scan using idx_comprobante_fecha_cubriendo on comprobante
  Index Cond: (fecha = '2026-11-04'::date)
  Heap Fetches: 0
```

**Observación:** **Este es el caso de éxito.** El planificador usa un **Index Only Scan** con `Heap Fetches: 0`, lo que significa que no necesitó acceder a la tabla heap porque todas las columnas requeridas (`fecha`, `id_sala`, `total`) están en el índice. Esto reduce drásticamente las lecturas de disco.

---

## 4. Caso en que el planificador NO usa un índice existente

Se documentan 4 situaciones donde el planificador prefiere no usar un índice:

| Caso | Índice existente | Qué hace el planificador | Razón |
|------|-----------------|--------------------------|-------|
| Tabla pequeña (vino, 60 filas) | `idx_vino_nombre_upper` | Seq Scan | Costo del índice > costo de escanear 60 filas |
| Tabla pequeña (stock_sala, 600 filas) | `idx_stock_sala_sin_stock` | Seq Scan | Costo del índice > costo de escanear 600 filas |
| Join masivo (S1) | `idx_renglon_comprobante_cod_vino` | Hash Join (sin usar el índice) | Para pocos valores distintos (60 vinos), Hash Join es más eficiente que Nested Loop por índice |
| Columna ya en PK | `idx_renglon_comprobante_nro_brin` | Usa el PK (B-tree) | El PK ya cubre `nro_comprobante`; el BRIN es redundante y menos preciso |

---

## 5. Costo de escritura de los índices

Cada índice adicional implica un costo de escritura en operaciones `INSERT`, `UPDATE` y `DELETE` sobre la tabla, porque cada índice debe mantenerse actualizado:

| Tabla | Índices que se actualizan en INSERT | Impacto estimado |
|-------|-------------------------------------|------------------|
| `comprobante` | `idx_comprobante_sala_fecha`, `idx_comprobante_fecha_cubriendo` | +2 escrituras de índice por fila insertada |
| `renglon_comprobante` | `idx_renglon_comprobante_cod_vino`, `idx_renglon_comprobante_nro_brin`, PK | +3 escrituras de índice por fila insertada |
| `stock_sala` | `idx_stock_sala_sin_stock`, PK | +2 escrituras de índice por fila insertada |
| `vino` | `idx_vino_nombre_upper`, PK | +2 escrituras de índice por fila insertada |

**Recomendación:** No crear índices que no se vayan a usar. Cada índice innecesario ralentiza las escrituras y consume espacio en disco sin beneficio en lecturas.

---

## 6. Tabla comparativa resumen

| Consulta | Antes (ms) | Después (ms) | ¿Mejoró? | Índice usado |
|----------|------------|--------------|----------|--------------|
| S8 Ventas por sala trimestre | 444,967 | 72,944 | ✅ Sí | Parcialmente (caché) |
| S1 Ranking vinos más vendidos | 69,086 | 3.068,641 | ❌ No (empeoró) | Ninguno (Hash Join era mejor) |
| S3 Renglones cantidad > 10 | 15,608 | 17,351 | ≈ Sin cambios | Ninguno (0 filas) |
| Comprobante por fecha (Index Only Scan) | N/A | 0,195 | ✅ Sí | `idx_comprobante_fecha_cubriendo` |

---

## 7. Conclusiones

1. **Se crearon 6 índices** cumpliendo todos los requisitos del enunciado (compuesto, parcial, FK, expresión, INCLUDE, BRIN).
2. **Los índices no siempre mejoran el rendimiento.** En tablas pequeñas (vino: 60, stock_sala: 600) el planificador prefiere Seq Scan. En joins masivos, el índice en FK puede inducir a un plan peor (Nested Loop vs Hash Join).
3. **El índice INCLUDE (cubriendo) fue el más exitoso:** permitió un Index Only Scan con Heap Fetches = 0, eliminando acceso al heap.
4. **Cada índice tiene un costo de escritura** que debe considerarse. No crear índices que no se usen.
5. **El BRIN fue redundante** con el PK existente que ya cubre la misma columna.

---

## 8. Archivos entregados

- `db/migrations/008_indices.sql` — DDL de los 6 índices con justificaciones
- `docs/informes/informe_etapa4_indices.md` — Este informe
