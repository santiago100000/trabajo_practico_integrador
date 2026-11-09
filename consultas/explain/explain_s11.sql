-- ============================================================================
-- consultas/explain/explain_s11.sql — Etapa 5, Paso 6: EXPLAIN de S11
-- Consulta: Ranking de vinos por sala con ventas acumuladas mensuales
-- ============================================================================

EXPLAIN (ANALYZE, BUFFERS)
WITH ventas_por_sala_vino AS (
    SELECT c.id_sala, rc.cod_vino, v.nombre,
           SUM(rc.cantidad) AS botellas_vendidas,
           SUM(rc.subtotal) AS monto_vendido
    FROM renglon_comprobante rc
    JOIN comprobante c ON c.nro_comprobante = rc.nro_comprobante
    JOIN vino v ON v.cod_vino = rc.cod_vino
    GROUP BY c.id_sala, rc.cod_vino, v.nombre
)
SELECT
    id_sala,
    cod_vino,
    nombre,
    botellas_vendidas,
    RANK() OVER (PARTITION BY id_sala ORDER BY botellas_vendidas DESC) AS ranking_vinos_por_sala,
    SUM(monto_vendido) OVER (
        PARTITION BY id_sala
        ORDER BY botellas_vendidas DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS ventas_acumuladas
FROM ventas_por_sala_vino
ORDER BY id_sala, ranking_vinos_por_sala;
