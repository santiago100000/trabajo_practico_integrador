EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id_cliente, c.nombre_razon_social
FROM cliente c
WHERE c.id_cliente IN (
    SELECT cp.id_cliente
    FROM comprobante cp
    JOIN renglon_comprobante rc ON rc.nro_comprobante = cp.nro_comprobante
    JOIN vino v ON v.cod_vino = rc.cod_vino
    WHERE v.id_bodega = 1
    GROUP BY cp.id_cliente
    HAVING COUNT(DISTINCT v.cod_vino) = (
        SELECT COUNT(*) FROM vino v2 WHERE v2.id_bodega = 1
    )
);
