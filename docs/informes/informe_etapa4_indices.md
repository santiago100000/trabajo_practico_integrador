# Informe Etapa 4 — Índices y rendimiento (Pasos 1 y 2)

**Proyecto:** Bodegas del Atuel — TP Integrador de Bases de Datos (UTN FRSR)  
**Etapa:** 4 — Índices y rendimiento  
**Pasos completados:** Paso 1 (selección de consultas candidatas) y Paso 2 (medición inicial con EXPLAIN ANALYZE BUFFERS sobre índices de PK y UNIQUE)  
**Estado:** Pasos 1 y 2 listos para ejecutar contra la base cargada (Etapa 3).  
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
- Tiempo de ejecución: `________ ms`
- Plan de ejecución:  
  ```
  (pegar aquí el resultado de EXPLAIN ANALYZE BUFFERS)
  ```
- Tipo de recorrido dominante: `________` (ej. Seq Scan, Hash Join, etc.)
- Filas leídas aproximadas: `________`

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
- Tiempo de ejecución: `________ ms`
- Plan de ejecución:  
  ```
  (pegar aquí el resultado de EXPLAIN ANALYZE BUFFERS)
  ```
- Tipo de recorrido dominante: `________`
- Filas leídas aproximadas: `________`

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
- Tiempo de ejecución: `________ ms`
- Plan de ejecución:  
  ```
  (pegar aquí el resultado de EXPLAIN ANALYZE BUFFERS)
  ```
- Tipo de recorrido dominante: `________`
- Filas leídas aproximadas: `________`

---

## Resumen del Paso 2 (pendiente de completar con datos reales)

| Consulta | Tiempo (ms) sin índices | Recorrido dominante | Filas leídas |
|----------|------------------------|---------------------|--------------|
| S1 | `________` | `________` | `________` |
| S4 | `________` | `________` | `________` |
| S8 | `________` | `________` | `________` |

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