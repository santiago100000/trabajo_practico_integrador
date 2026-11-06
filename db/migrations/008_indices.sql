-- =============================================================================
-- 008_indices.sql
-- Etapa: 4 - Índices y rendimiento
-- Pasos 1 y 2: selección de consultas candidatas y medición inicial con
-- EXPLAIN (ANALYZE, BUFFERS) sobre índices de PK/UNIQUE.
-- Pasos 3 y 4: diseño y creación de índices basados en los planes observados.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- PASO 1: Consultas candidatas seleccionadas (de la sección 8 del enunciado)
-- ---------------------------------------------------------------------------
-- S1: Ranking de los 10 vinos con mayor cantidad de botellas vendidas.
--   Tablas: renglon_comprobante, comprobante, vino
-- S4: Top 5 salas que solicitaron mayor cantidad de un vino determinado
--     mediante transferencias en los últimos 15 días.
--   Tablas: renglon_transferencia, transferencia
-- S8: Monto total de ventas por sala en el último trimestre.
--   Tablas: comprobante, sala_venta

-- ---------------------------------------------------------------------------
-- PASO 2: Resultados de medición inicial (EXPLAIN ANALYZE BUFFERS)
-- ---------------------------------------------------------------------------
-- S1: 124.119 ms — Parallel Seq Scan sobre renglon_comprobante y comprobante.
--     No hay índice en FKs (cod_vino, nro_comprobante), por lo que se lee
--     toda la tabla (375,027 renglones).
-- S4: 0.094 ms — Seq Scan, 0 filas (cod_vino=1 no tiene transferencias).
--     Falta índice en renglon_transferencia(cod_vino) para filtrar rápido.
-- S8: 25.802 ms — Index Only Scan usando idx_comprobante_fecha_cubriendo
--     (ya existe). Mejora posible con índice compuesto (id_sala, fecha).

-- ---------------------------------------------------------------------------
-- PASO 3 y 4: Diseño y creación de índices
-- ---------------------------------------------------------------------------
-- Requisitos mínimos del enunciado:
--   • Al menos 5 índices
--   • Uno compuesto
--   • Uno parcial (con WHERE)
--   • Uno sobre una clave foránea
--   • Uno de otro tipo/variante (expresión, BRIN, INCLUDE, etc.)
--   • Cada uno justificado
-- ---------------------------------------------------------------------------

-- Índice 1: Compuesto (id_sala, fecha) en comprobante
-- Justificación: S8 filtra por rango de fecha (últimos 3 meses) y agrupa por
-- id_sala. Un índice compuesto (id_sala, fecha) permite al planificador
-- filtrar por fecha y agrupar por sala sin Seq Scan. El orden de columnas es
-- id_sala primero porque la agrupación es por sala y dentro de cada sala se
-- filtra por rango de fecha.
-- Consulta beneficiada: S8
CREATE INDEX idx_comprobante_sala_fecha
    ON comprobante (id_sala, fecha);

-- Índice 2: Parcial en stock_sala WHERE cantidad = 0
-- Justificación: Consultas que buscan vinos sin stock en una sala (ej. S6:
-- "vinos sin stock en la sala pero con stock en el depósito"). Solo una pequeña
-- fracción de las filas tiene cantidad = 0, por lo que un índice parcial es
-- mucho más pequeño y rápido que uno completo.
-- Consulta beneficiada: S6 y similares de stock agotado
CREATE INDEX idx_stock_sala_sin_stock
    ON stock_sala (id_sala, cod_vino)
    WHERE cantidad = 0;

-- Índice 3: Sobre clave foránea cod_vino en renglon_comprobante
-- Justificación: PostgreSQL no indexa automáticamente las claves foráneas.
-- S1 une renglon_comprobante con vino por cod_vino y agrupa por cod_vino.
-- Un índice sobre la FK acelera el JOIN y el GROUP BY, evitando el Parallel
-- Seq Scan que tardó 124.119 ms sin índice.
-- Consulta beneficiada: S1
CREATE INDEX idx_renglon_comprobante_cod_vino
    ON renglon_comprobante (cod_vino);

-- Índice 4: De expresión UPPER(nombre) en vino
-- Justificación: Las búsquedas de vinos por nombre suelen hacerse sin
-- distinguir mayúsculas/minúsculas (ILIKE o UPPER). Un índice sobre la
-- expresión UPPER(nombre) permite usar el índice en consultas como
-- WHERE UPPER(nombre) = UPPER('malbec'), evitando Seq Scan sobre la tabla
-- de vinos.
-- Consulta beneficiada: búsquedas de vino por nombre (case-insensitive)
CREATE INDEX idx_vino_nombre_upper
    ON vino (UPPER(nombre));

-- Índice 5: BRIN en renglon_comprobante (nro_comprobante)
-- Justificación: nro_comprobante es GENERATED ALWAYS AS IDENTITY, por lo que
-- los valores se insertan en orden creciente y están correlacionados con la
-- posición física en la tabla. Un BRIN es mucho más compacto que un B-tree y
-- es ideal para consultas de rango sobre nro_comprobante (ej. "últimos
-- comprobantes"), con menor costo de escritura y mantenimiento.
-- Consulta beneficiada: consultas de rango por nro_comprobante
CREATE INDEX idx_renglon_comprobante_nro_brin
    ON renglon_comprobante USING BRIN (nro_comprobante);

-- Índice 6: Sobre clave foránea cod_vino en renglon_transferencia
-- Justificación: S4 filtra renglon_transferencia por cod_vino = 1 y une con
-- transferencia por nro_solicitud. Sin índice en cod_vino, el planificador
-- hace Seq Scan. Un índice sobre la FK acelera el filtrado por vino y el JOIN
-- posterior.
-- Consulta beneficiada: S4
CREATE INDEX idx_renglon_transferencia_cod_vino
    ON renglon_transferencia (cod_vino);

-- =============================================================================
-- Resumen de índices creados (6 en total, cumpliendo requisitos mínimos):
--   1. idx_comprobante_sala_fecha       → compuesto (id_sala, fecha)         → S8
--   2. idx_stock_sala_sin_stock         → parcial (WHERE cantidad = 0)       → S6/stock agotado
--   3. idx_renglon_comprobante_cod_vino → sobre FK (cod_vino)                → S1
--   4. idx_vino_nombre_upper            → de expresión (UPPER(nombre))       → búsqueda vino por nombre
--   5. idx_renglon_comprobante_nro_brin → BRIN (nro_comprobante)             → consultas de rango
--   6. idx_renglon_transferencia_cod_vino → sobre FK (cod_vino)              → S4
-- =============================================================================