-- =============================================================================
-- 008_indices.sql
-- Etapa: 4 - Índices y rendimiento
-- Propósito: Crear ≥5 índices justificados con evidencia EXPLAIN (ANALYZE, BUFFERS).
-- Requisitos mínimos del enunciado:
--   • Índice compuesto
--   • Índice parcial (con WHERE)
--   • Índice sobre una clave foránea
--   • Índice de otro tipo/variante (expresión, BRIN, INCLUDE, etc.)
--   • Cada uno justificado
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Índice compuesto (id_sala, fecha)
-- Justificación: S8 (monto total de ventas por sala en último trimestre) filtra
--   por fecha y agrupa por id_sala. Un índice compuesto (id_sala, fecha) permite
--   al planificador filtrar por rango de fecha y agrupar por sala sin Seq Scan.
--   El orden de columnas es id_sala primero porque la agrupación es por sala
--   y dentro de cada sala se filtra por fecha.
-- ---------------------------------------------------------------------------
CREATE INDEX idx_comprobante_sala_fecha
    ON comprobante (id_sala, fecha);

-- ---------------------------------------------------------------------------
-- 2. Índice parcial (solo stock_sala con cantidad = 0)
-- Justificación: S6 (vinos sin stock en sala pero con stock en depósito) necesita
--   encontrar rápidamente las filas de stock_sala agotadas. Como solo una pequeña
--   fracción de las filas tiene cantidad = 0, un índice parcial es mucho más
--   pequeño y rápido que uno completo.
-- ---------------------------------------------------------------------------
CREATE INDEX idx_stock_sala_sin_stock
    ON stock_sala (id_sala, cod_vino)
    WHERE cantidad = 0;

-- ---------------------------------------------------------------------------
-- 3. Índice sobre clave foránea (cod_vino en renglon_comprobante)
-- Justificación: PostgreSQL no indexa automáticamente las FK. S1 (ranking de vinos
--   más vendidos) une renglon_comprobante con vino por cod_vino. Un índice sobre
--   la FK acelera el join y el GROUP BY por cod_vino.
-- ---------------------------------------------------------------------------
CREATE INDEX idx_renglon_comprobante_cod_vino
    ON renglon_comprobante (cod_vino);

-- ---------------------------------------------------------------------------
-- 4. Índice de expresión (UPPER(nombre) en vino)
-- Justificación: Las búsquedas de vinos por nombre suelen hacerse sin distinguir
--   mayúsculas/minúsculas (ILIKE o UPPER). Un índice sobre la expresión UPPER(nombre)
--   permite usar el índice en consultas como WHERE UPPER(nombre) = UPPER('malbec').
-- ---------------------------------------------------------------------------
CREATE INDEX idx_vino_nombre_upper
    ON vino (UPPER(nombre));

-- ---------------------------------------------------------------------------
-- 5. Índice con INCLUDE (cubriendo) en comprobante (fecha) INCLUDE (id_sala, total)
-- Justificación: S8 filtra por fecha y necesita id_sala y total. Con INCLUDE,
--   el índice cubre la consulta sin acudir al heap (Index Only Scan), reduciendo
--   lecturas de disco. La columna indexada es fecha (filtro de rango) y se
--   incluyen id_sala y total para evitar acceso a tabla.
-- ---------------------------------------------------------------------------
CREATE INDEX idx_comprobante_fecha_cubriendo
    ON comprobante (fecha)
    INCLUDE (id_sala, total);

-- ---------------------------------------------------------------------------
-- 6. Índice BRIN en renglon_comprobante (nro_comprobante)
-- Justificación: nro_comprobante es GENERATED ALWAYS AS IDENTITY, por lo que los
--   valores se insertan en orden creciente y están correlacionados con la posición
--   física en la tabla. Un BRIN es mucho más compacto que un B-tree y es ideal
--   para consultas de rango sobre nro_comprobante (ej. últimos comprobantes).
-- ---------------------------------------------------------------------------
CREATE INDEX idx_renglon_comprobante_nro_brin
    ON renglon_comprobante USING BRIN (nro_comprobante);

-- =============================================================================
-- Fin de 008_indices.sql
-- =============================================================================
