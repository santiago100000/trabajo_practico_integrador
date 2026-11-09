-- ============================================================================
-- consultas/explain/explain_s9.sql — Etapa 5, Paso 6: EXPLAIN de S9
-- Consulta: Ficha completa de un vino (cepas, bodega, maridajes, stock total)
-- Parámetro: cod_vino = 1
-- ============================================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    v.cod_vino,
    v.nombre,
    b.razon_social AS bodega,
    string_agg(DISTINCT c.nombre || ' (' || vc.porcentaje || '%)', ', ') AS cepas,
    string_agg(DISTINCT m.nombre, ', ') AS maridajes,
    COALESCE(sd.cantidad, 0) + COALESCE(ss.stock_salas, 0) AS stock_total
FROM vino v
JOIN bodega b ON b.id_bodega = v.id_bodega
LEFT JOIN vino_cepa vc ON vc.cod_vino = v.cod_vino
LEFT JOIN cepa c ON c.id_cepa = vc.id_cepa
LEFT JOIN vino_maridaje vm ON vm.cod_vino = v.cod_vino
LEFT JOIN maridaje m ON m.id_maridaje = vm.id_maridaje
LEFT JOIN stock_deposito sd ON sd.cod_vino = v.cod_vino
LEFT JOIN (
    SELECT cod_vino, SUM(cantidad) AS stock_salas
    FROM stock_sala
    GROUP BY cod_vino
) ss ON ss.cod_vino = v.cod_vino
WHERE v.cod_vino = 1
GROUP BY v.cod_vino, v.nombre, b.razon_social, sd.cantidad, ss.stock_salas;
