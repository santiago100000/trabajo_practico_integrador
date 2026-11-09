-- ============================================================================
-- consultas/explain/explain_s1.sql — Etapa 5, Paso 6: EXPLAIN de S1
-- Consulta: Ranking de los 10 vinos con mayor cantidad de botellas vendidas
-- ============================================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT v.cod_vino, v.nombre, SUM(rc.cantidad) AS botellas_vendidas
FROM renglon_comprobante rc
JOIN comprobante c ON c.nro_comprobante = rc.nro_comprobante
JOIN vino v ON v.cod_vino = rc.cod_vino
GROUP BY v.cod_vino, v.nombre
ORDER BY botellas_vendidas DESC
LIMIT 10;
