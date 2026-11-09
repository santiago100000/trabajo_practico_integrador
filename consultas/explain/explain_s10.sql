-- ============================================================================
-- consultas/explain/explain_s10.sql — Etapa 5, Paso 6: EXPLAIN de S10
-- Consulta: Rendimiento kg/ha por parcela y campaña vs promedio de finca
-- ============================================================================

EXPLAIN (ANALYZE, BUFFERS)
WITH rendimiento_parcela AS (
    SELECT l.id_finca, l.nro_parcela, l.campania,
           l.kilos_cosechados / p.superficie_ha AS kg_por_ha
    FROM lote_uva l
    JOIN parcela p ON p.id_finca = l.id_finca AND p.nro_parcela = l.nro_parcela
)
SELECT
    rp.id_finca,
    rp.nro_parcela,
    rp.campania,
    rp.kg_por_ha,
    (SELECT AVG(rp2.kg_por_ha)
     FROM rendimiento_parcela rp2
     WHERE rp2.id_finca = rp.id_finca) AS promedio_finca,
    CASE
        WHEN rp.kg_por_ha < (SELECT AVG(rp3.kg_por_ha)
                             FROM rendimiento_parcela rp3
                             WHERE rp3.id_finca = rp.id_finca)
        THEN 'Rinde menos que el promedio de su finca'
        ELSE 'Rinde igual o más que el promedio'
    END AS observacion
FROM rendimiento_parcela rp
ORDER BY rp.id_finca, rp.nro_parcela;
