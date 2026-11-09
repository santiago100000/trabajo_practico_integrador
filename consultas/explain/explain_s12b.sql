-- ============================================================================
-- consultas/explain/explain_s12b.sql — Etapa 5, Paso 6: EXPLAIN de S12b
-- Consulta: Clientes que nunca compraron ningún vino tinto
-- ============================================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id_cliente, c.nombre_razon_social
FROM cliente c
WHERE NOT EXISTS (
    SELECT 1 FROM renglon_comprobante rc
    JOIN comprobante cp ON cp.nro_comprobante = rc.nro_comprobante
    JOIN vino v ON v.cod_vino = rc.cod_vino
    WHERE v.tipo = 'tinto'
      AND cp.id_cliente = c.id_cliente
);
