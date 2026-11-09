-- ============================================================================
-- consultas/explain/explain_s8.sql — Etapa 5, Paso 6: EXPLAIN de S8
-- Consulta: Monto total de ventas por sala en el último trimestre
-- ============================================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT s.id_sala, s.calle, s.numero, SUM(cp.total) AS ventas_totales
FROM comprobante cp
JOIN sala_venta s ON s.id_sala = cp.id_sala
WHERE cp.fecha >= CURRENT_DATE - INTERVAL '3 months'
GROUP BY s.id_sala, s.calle, s.numero
ORDER BY ventas_totales DESC;
