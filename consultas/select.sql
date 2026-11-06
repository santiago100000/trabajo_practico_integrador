-- ============================================================================
-- consultas/select.sql — Etapa 5, Paso 1 y Paso 2: Consultas SQL (SELECT)
-- Sección 8.4 y 8.5 del enunciado TPI Bodegas del Atuel
-- Cada consigna incluye: código, enunciado, consulta SQL y estrategia.
-- Valores concretos tomados del dataset cargado (Etapa 3, semilla 42).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- S1: Ranking de los 10 vinos con mayor cantidad de botellas vendidas en toda
--     la red de salas.
-- Estrategia: JOIN entre renglon_comprobante, comprobante y vino; GROUP BY
-- vino; SUM(cantidad); ORDER BY DESC; LIMIT 10.
-- ---------------------------------------------------------------------------
SELECT v.cod_vino, v.nombre, SUM(rc.cantidad) AS botellas_vendidas
FROM renglon_comprobante rc
JOIN comprobante c ON c.nro_comprobante = rc.nro_comprobante
JOIN vino v ON v.cod_vino = rc.cod_vino
GROUP BY v.cod_vino, v.nombre
ORDER BY botellas_vendidas DESC
LIMIT 10;


-- ---------------------------------------------------------------------------
-- S2: Listar códigos y nombres de los vinos que se vendieron en todas las salas
--     (división relacional).
-- Estrategia: NOT EXISTS doble: para cada vino, verificar que no exista una
-- sala donde el vino NO tenga ventas registradas.
-- ---------------------------------------------------------------------------
SELECT v.cod_vino, v.nombre
FROM vino v
WHERE NOT EXISTS (
    SELECT 1 FROM sala_venta s
    WHERE NOT EXISTS (
        SELECT 1 FROM renglon_comprobante rc
        JOIN comprobante c ON c.nro_comprobante = rc.nro_comprobante
        WHERE rc.cod_vino = v.cod_vino
          AND c.id_sala = s.id_sala
    )
);


-- ---------------------------------------------------------------------------
-- S3: Cantidad de clientes de cada tipo que compraron en una sala determinada
--     en la última semana.
-- Parámetro: sala ID 1.
-- Estrategia: JOIN comprobante → cliente; filtrar por sala y fecha (últimos
-- 7 días); GROUP BY tipo_cliente; COUNT DISTINCT clientes.
-- ---------------------------------------------------------------------------
SELECT c.tipo_cliente, COUNT(DISTINCT cp.id_cliente) AS cantidad_clientes
FROM comprobante cp
JOIN cliente c ON c.id_cliente = cp.id_cliente
WHERE cp.id_sala = 1
  AND cp.fecha >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY c.tipo_cliente
ORDER BY cantidad_clientes DESC;


-- ---------------------------------------------------------------------------
-- S4: Top 5 de las salas que solicitaron mayor cantidad de un vino determinado
--     mediante transferencias en los últimos 15 días.
-- Parámetro: vino cod_vino = 33 (Bonarda 2019, 750 ml, tinto).
-- Estrategia: JOIN renglon_transferencia → transferencia → sala_venta;
-- filtrar por vino y fecha; GROUP BY sala; LIMIT 5.
-- ---------------------------------------------------------------------------
SELECT t.id_sala, s.calle, s.numero, SUM(rt.cantidad) AS botellas_solicitadas
FROM renglon_transferencia rt
JOIN transferencia t ON t.nro_solicitud = rt.nro_solicitud
JOIN sala_venta s ON s.id_sala = t.id_sala
WHERE rt.cod_vino = 33
  AND t.fecha_confeccion >= CURRENT_DATE - INTERVAL '15 days'
GROUP BY t.id_sala, s.calle, s.numero
ORDER BY botellas_solicitadas DESC
LIMIT 5;


-- ---------------------------------------------------------------------------
-- S5: Listado de las salas con menor cantidad de transferencias pendientes
--     (no procesadas: en_confeccion o terminado).
-- Estrategia: LEFT JOIN transferencia filtrando estados <> 'procesado';
-- GROUP BY sala; ORDER BY ASC.
-- ---------------------------------------------------------------------------
SELECT s.id_sala, s.calle, s.numero, COUNT(t.nro_solicitud) AS transferencias_pendientes
FROM sala_venta s
LEFT JOIN transferencia t ON t.id_sala = s.id_sala
    AND t.estado <> 'procesado'
GROUP BY s.id_sala, s.calle, s.numero
ORDER BY transferencias_pendientes ASC, s.id_sala;


-- ---------------------------------------------------------------------------
-- S6: Para una sala determinada, los vinos sin stock en la sala pero con stock
--     en el depósito central.
-- Parámetro: sala ID 1.
-- Estrategia: INNER JOIN stock_deposito (cantidad > 0) y LEFT JOIN stock_sala
-- (sala 1) WHERE stock_sala es NULL o cantidad = 0.
-- ---------------------------------------------------------------------------
SELECT v.cod_vino, v.nombre
FROM vino v
JOIN stock_deposito sd ON sd.cod_vino = v.cod_vino AND sd.cantidad > 0
LEFT JOIN stock_sala ss ON ss.cod_vino = v.cod_vino AND ss.id_sala = 1
WHERE ss.cod_vino IS NULL OR ss.cantidad = 0;


-- ---------------------------------------------------------------------------
-- S7: ¿Cuál es la empresa de transporte con mayor actividad en el último mes?
--     Actividad medida por cantidad de ingresos.
-- Estrategia: JOIN ingreso → transportista; filtrar por fecha del último mes;
-- GROUP BY transportista; ORDER BY DESC; LIMIT 1.
-- ---------------------------------------------------------------------------
SELECT tr.cod_transportista, tr.razon_social, COUNT(i.cod_ingreso) AS ingresos_ultimo_mes
FROM ingreso i
JOIN transportista tr ON tr.cod_transportista = i.cod_transportista
WHERE i.fecha >= CURRENT_DATE - INTERVAL '1 month'
GROUP BY tr.cod_transportista, tr.razon_social
ORDER BY ingresos_ultimo_mes DESC
LIMIT 1;


-- ---------------------------------------------------------------------------
-- S8: Monto total de ventas por sala en el último trimestre, en orden
--     descendente.
-- Estrategia: JOIN comprobante → sala_venta; filtrar por fecha del último
-- trimestre; GROUP BY sala; SUM(total); ORDER BY DESC.
-- ---------------------------------------------------------------------------
SELECT s.id_sala, s.calle, s.numero, SUM(cp.total) AS ventas_totales
FROM comprobante cp
JOIN sala_venta s ON s.id_sala = cp.id_sala
WHERE cp.fecha >= CURRENT_DATE - INTERVAL '3 months'
GROUP BY s.id_sala, s.calle, s.numero
ORDER BY ventas_totales DESC;


-- ---------------------------------------------------------------------------
-- S9: Ficha de un vino: cepas con sus porcentajes, bodega elaboradora,
--     maridajes y stock total (depósito más salas).
-- Parámetro: vino cod_vino = 1 (Tempranillo 2018).
-- Estrategia: múltiples JOINs; string_agg para cepas y maridajes; stock_total
-- = stock_deposito + SUM(stock_sala).
-- ---------------------------------------------------------------------------
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


-- ---------------------------------------------------------------------------
-- S10: Rendimiento en kg por hectárea de cada parcela y campaña, e identificar
--      las parcelas que rinden menos que el promedio de su finca.
-- Estrategia: CTE con rendimiento por parcela; subconsulta correlacionada
-- para promedio de finca.
-- ---------------------------------------------------------------------------
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


-- ---------------------------------------------------------------------------
-- S11: Ranking de vinos dentro de cada sala por botellas vendidas y
--      ventas acumuladas mensuales por sala.
-- Estrategia: RANK() OVER (PARTITION BY id_sala) y suma acumulada con ventana
-- ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW.
-- ---------------------------------------------------------------------------
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


-- ---------------------------------------------------------------------------
-- S12: Clientes que compraron todos los vinos de una bodega determinada,
--      y clientes que nunca compraron ningún vino tinto.
-- Parámetro: bodega id_bodega = 1.
-- Estrategia S12a: NOT EXISTS (división relacional).
-- Estrategia S12b: NOT EXISTS (anti-join).
-- ---------------------------------------------------------------------------

-- S12a: Clientes que compraron todos los vinos de la bodega id_bodega = 1
-- Estrategia: contar vinos distintos de la bodega comprados por cada cliente
-- y comparar con el total de vinos de esa bodega. Usa GROUP BY + HAVING COUNT
-- DISTINCT en lugar de NOT EXISTS correlionado doble, que generaba un plan
-- de costo muy elevado (timeout en EXPLAIN con la version original).
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

-- S12b: Clientes que nunca compraron ningún vino tinto
SELECT c.id_cliente, c.nombre_razon_social
FROM cliente c
WHERE NOT EXISTS (
    SELECT 1 FROM renglon_comprobante rc
    JOIN comprobante cp ON cp.nro_comprobante = rc.nro_comprobante
    JOIN vino v ON v.cod_vino = rc.cod_vino
    WHERE v.tipo = 'tinto'
      AND cp.id_cliente = c.id_cliente
);
