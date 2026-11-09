-- ============================================================================
-- consultas/explain/explain_s4.sql — Etapa 5, Paso 6: EXPLAIN de S4
-- Consulta: Top 5 salas con más transferencias de un vino (últimos 15 días)
-- Parámetro: cod_vino = 33
-- ============================================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT t.id_sala, s.calle, s.numero, SUM(rt.cantidad) AS botellas_solicitadas
FROM renglon_transferencia rt
JOIN transferencia t ON t.nro_solicitud = rt.nro_solicitud
JOIN sala_venta s ON s.id_sala = t.id_sala
WHERE rt.cod_vino = 33
  AND t.fecha_confeccion >= CURRENT_DATE - INTERVAL '15 days'
GROUP BY t.id_sala, s.calle, s.numero
ORDER BY botellas_solicitadas DESC
LIMIT 5;
