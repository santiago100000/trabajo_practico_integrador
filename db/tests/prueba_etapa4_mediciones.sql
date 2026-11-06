\timing on

-- ============================================================
-- PRUEBA ETAPA 4: Medición de consultas que SÍ se benefician
-- de los índices creados (Paso 5 - Tabla comparativa)
--
-- Reproduce exactamente C1, C2 y C3 del informe
-- informe_etapa4_indices.md
-- ============================================================

-- ---------------------------------------------------------------------------
-- CONSULTA 1 (C1): COUNT de renglones por vino específico (cod_vino = 17)
-- Índice: idx_renglon_comprobante_cod_vino (sobre FK)
-- ---------------------------------------------------------------------------
\echo '=== CONSULTA 1 ANTES: COUNT WHERE cod_vino = 17 (sin índice FK) ==='
DROP INDEX IF EXISTS idx_renglon_comprobante_cod_vino;
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM renglon_comprobante WHERE cod_vino = 17;

\echo '=== CONSULTA 1 DESPUÉS: COUNT WHERE cod_vino = 17 (con índice FK) ==='
CREATE INDEX idx_renglon_comprobante_cod_vino ON renglon_comprobante (cod_vino);
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM renglon_comprobante WHERE cod_vino = 17;

-- ---------------------------------------------------------------------------
-- CONSULTA 2 (C2): Todas las filas sin stock (cantidad = 0)
-- Índice: idx_stock_sala_sin_stock (parcial WHERE cantidad = 0)
-- ---------------------------------------------------------------------------
\echo '=== CONSULTA 2 ANTES: SELECT * WHERE cantidad = 0 (sin índice parcial) ==='
DROP INDEX IF EXISTS idx_stock_sala_sin_stock;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM stock_sala WHERE cantidad = 0;

\echo '=== CONSULTA 2 DESPUÉS: SELECT * WHERE cantidad = 0 (con índice parcial) ==='
CREATE INDEX idx_stock_sala_sin_stock ON stock_sala (id_sala, cod_vino) WHERE cantidad = 0;
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM stock_sala WHERE cantidad = 0;

-- ---------------------------------------------------------------------------
-- CONSULTA 3 (C3): COUNT de renglones por otro vino (cod_vino = 34)
-- Índice: idx_renglon_comprobante_cod_vino (misma función, diferente dato)
-- ---------------------------------------------------------------------------
\echo '=== CONSULTA 3 ANTES: COUNT WHERE cod_vino = 34 (sin índice FK) ==='
DROP INDEX IF EXISTS idx_renglon_comprobante_cod_vino;
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM renglon_comprobante WHERE cod_vino = 34;

\echo '=== CONSULTA 3 DESPUÉS: COUNT WHERE cod_vino = 34 (con índice FK) ==='
CREATE INDEX idx_renglon_comprobante_cod_vino ON renglon_comprobante (cod_vino);
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM renglon_comprobante WHERE cod_vino = 34;

-- ---------------------------------------------------------------------------
-- VERIFICACIÓN FINAL: Índices activos en la base
-- ---------------------------------------------------------------------------
\echo '=== ÍNDICES ACTIVOS EN LA BASE ==='
SELECT indexname FROM pg_indexes WHERE schemaname = 'public' AND indexname LIKE 'idx_%' ORDER BY indexname;

\echo '=== FIN DE PRUEBA ==='
