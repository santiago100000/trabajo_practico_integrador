-- =============================================================================
-- 008_indices.sql
-- Etapa: 4 - Índices y rendimiento
-- Pasos 1 y 2 (documentados a continuación): selección de consultas candidatas
-- y medición inicial con EXPLAIN (ANALYZE, BUFFERS) sobre índices de PK/UNIQUE.
-- Pasos 3 a 8: diseño, creación y comparación de índices (pendiente de completar
-- tras ejecutar los EXPLAIN del paso 2 contra la base cargada de la Etapa 3).
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
-- PASO 2: Medición inicial (ejecutar en este orden, antes de crear índices)
-- ---------------------------------------------------------------------------
-- 1. Actualizar estadísticas:
--    ANALYZE renglon_comprobante;
--    ANALYZE comprobante;
--    ANALYZE vino;
--    ANALYZE renglon_transferencia;
--    ANALYZE transferencia;
--    ANALYZE sala_venta;
--
-- 2. Ejecutar EXPLAIN (ANALYZE, BUFFERS) para S1, S4 y S8.
--    Pegar los resultados en docs/informes/informe_etapa4_indices.md
--    (secciones [RESULTADO S1], [RESULTADO S4], [RESULTADO S8]).
--
-- Ejemplo de comando para S1:
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT v.cod_vino, v.nombre, SUM(r.cantidad)
-- FROM renglon_comprobante r
-- JOIN comprobante c ON r.nro_comprobante = c.nro_comprobante
-- JOIN vino v ON r.cod_vino = v.cod_vino
-- GROUP BY v.cod_vino, v.nombre
-- ORDER BY SUM(r.cantidad) DESC
-- LIMIT 10;

-- ---------------------------------------------------------------------------
-- PASO 3 y 4: Diseño y creación de índices (pendiente de completar)
-- ---------------------------------------------------------------------------
-- Después de analizar los planes del paso 2, descomentar y ajustar los
-- índices que correspondan. Requisitos mínimos del enunciado:
--   • Al menos 5 índices
--   • Uno compuesto
--   • Uno parcial (con WHERE)
--   • Uno sobre una clave foránea
--   • Uno de otro tipo/variante (expresión, BRIN, INCLUDE, etc.)
--   • Cada uno justificado

-- Ejemplo de estructura (descomentar tras validar con EXPLAIN):

-- -- Índice compuesto (id_sala, fecha) para S8
-- CREATE INDEX idx_comprobante_sala_fecha
--     ON comprobante (id_sala, fecha);

-- -- Índice parcial sobre stock_sala (cantidad = 0) para S6
-- CREATE INDEX idx_stock_sala_sin_stock
--     ON stock_sala (id_sala, cod_vino)
--     WHERE cantidad = 0;

-- -- Índice sobre clave foránea cod_vino en renglon_comprobante para S1
-- CREATE INDEX idx_renglon_comprobante_cod_vino
--     ON renglon_comprobante (cod_vino);

-- -- Índice de expresión UPPER(nombre) en vino
-- CREATE INDEX idx_vino_nombre_upper
--     ON vino (UPPER(nombre));

-- -- Índice con INCLUDE en comprobante (fecha) INCLUDE (id_sala, total) para S8
-- CREATE INDEX idx_comprobante_fecha_cubriendo
--     ON comprobante (fecha)
--     INCLUDE (id_sala, total);

-- -- Índice BRIN en renglon_comprobante (nro_comprobante)
-- CREATE INDEX idx_renglon_comprobante_nro_brin
--     ON renglon_comprobante USING BRIN (nro_comprobante);

-- ---------------------------------------------------------------------------
-- FIN de 008_indices.sql
-- =============================================================================