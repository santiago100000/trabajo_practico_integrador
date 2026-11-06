-- =============================================================================
-- select.sql
-- Consignas S1-S12 del enunciado PDF (sección 8.4 y 8.5 - Consultas SELECT).
-- Cada una: código, enunciado, estrategia y consulta SQL. Los valores
-- concretos se obtienen del dataset mediante subconsultas (no IDs fijos).
-- =============================================================================

-- =============================================================================
-- S1: Ranking de los 10 vinos con mayor cantidad de botellas vendidas en toda
-- la red de salas.
-- =============================================================================
-- Estrategia: sumar cantidad por vino desde renglon_comprobante, ordenar
-- descendente, limitar a 10.
SELECT v.cod_vino, v.nombre, v.tipo, v.anada,
       SUM(r.cantidad) AS total_botellas_vendidas
FROM vino v
JOIN renglon_comprobante r ON r.cod_vino = v.cod_vino
GROUP BY v.cod_vino, v.nombre, v.tipo, v.anada
ORDER BY total_botellas_vendidas DESC
LIMIT 10;

-- =============================================================================
-- S2: Listar códigos y nombres de los vinos que se vendieron en todas las salas
-- (división relacional).
-- =============================================================================
-- Estrategia: NOT EXISTS sobre salas donde no haya una venta del vino.
-- Para cada vino, verificar que no exista una sala sin una venta de ese vino.
SELECT v.cod_vino, v.nombre
FROM vino v
WHERE NOT EXISTS (
    SELECT 1 FROM sala_venta s
    WHERE NOT EXISTS (
        SELECT 1 FROM comprobante c
        JOIN renglon_comprobante r ON r.nro_comprobante = c.nro_comprobante
        WHERE c.id_sala = s.id_sala AND r.cod_vino = v.cod_vino
    )
);

-- =============================================================================
-- S3: Cantidad de clientes de cada tipo que compraron en una sala determinada
-- en la última semana.
-- =============================================================================
-- Estrategia: sala 1, última semana medida desde la fecha máxima de comprobante.
-- Contar clientes distintos por tipo_cliente.
SELECT cl.tipo_cliente, COUNT(DISTINCT c.id_cliente) AS cantidad_clientes
FROM comprobante c
JOIN cliente cl ON cl.id_cliente = c.id_cliente
WHERE c.id_sala = 1
  AND c.fecha >= (
      SELECT max(fecha) FROM comprobante
  ) - INTERVAL '1 week'
GROUP BY cl.tipo_cliente
ORDER BY cl.tipo_cliente;

-- =============================================================================
-- S4: Top 5 de las salas que solicitaron mayor cantidad de un vino determinado
-- mediante transferencias en los últimos 15 días.
-- =============================================================================
-- Estrategia: elegir un vino concreto (cod_vino = 1), filtrar transferencias
-- en los últimos 15 días (desde fecha max de transferencia), agrupar por sala.
SELECT t.id_sala, SUM(rt.cantidad) AS total_cantidad_solicitada
FROM transferencia t
JOIN renglon_transferencia rt ON rt.nro_solicitud = t.nro_solicitud
WHERE rt.cod_vino = 1
  AND t.fecha_confeccion >= (
      SELECT max(fecha_confeccion) FROM transferencia
  ) - INTERVAL '15 days'
GROUP BY t.id_sala
ORDER BY total_cantidad_solicitada DESC
LIMIT 5;

-- =============================================================================
-- S5: Listado de las salas con menor cantidad de transferencias pendientes (no
-- procesadas).
-- =============================================================================
-- Estrategia: contar transferencias con estado <> 'procesado' por sala,
-- ordenar ascendente (menor cantidad primero).
SELECT s.id_sala, s.calle, s.numero,
       COUNT(t.nro_solicitud) AS transferencias_pendientes
FROM sala_venta s
LEFT JOIN transferencia t ON t.id_sala = s.id_sala
    AND t.estado <> 'procesado'
GROUP BY s.id_sala, s.calle, s.numero
ORDER BY transferencias_pendientes ASC, s.id_sala ASC;

-- =============================================================================
-- S6: Para una sala determinada, los vinos sin stock en la sala pero con stock
-- en el depósito central.
-- =============================================================================
-- Estrategia: sala 1, vinos que tienen stock_deposito.cantidad > 0 pero no
-- tienen fila en stock_sala o tienen cantidad = 0.
SELECT v.cod_vino, v.nombre,
       sd.cantidad AS stock_deposito,
       COALESCE(ss.cantidad, 0) AS stock_sala
FROM vino v
JOIN stock_deposito sd ON sd.cod_vino = v.cod_vino
LEFT JOIN stock_sala ss ON ss.id_sala = 1 AND ss.cod_vino = v.cod_vino
WHERE sd.cantidad > 0
  AND COALESCE(ss.cantidad, 0) = 0
ORDER BY v.cod_vino;

-- =============================================================================
-- S7: ¿Cuál es la empresa de transporte con mayor actividad en el último mes?
-- =============================================================================
-- Estrategia: contar ingresos por transportista en el último mes (desde fecha
-- máxima de ingreso), ordenar descendente, tomar el primero.
SELECT t.cod_transportista, t.razon_social, COUNT(i.cod_ingreso) AS n_ingresos
FROM transportista t
JOIN ingreso i ON i.cod_transportista = t.cod_transportista
WHERE i.fecha >= (
    SELECT max(fecha) FROM ingreso
) - INTERVAL '1 month'
GROUP BY t.cod_transportista, t.razon_social
ORDER BY n_ingresos DESC
LIMIT 1;

-- =============================================================================
-- S8: Monto total de ventas por sala en el último trimestre, en orden
-- descendente.
-- =============================================================================
-- Estrategia: sumar total de comprobantes en los últimos 3 meses (desde fecha
-- máxima), agrupar por sala.
SELECT c.id_sala, s.calle, s.numero,
       SUM(c.total) AS monto_total_ventas_trimestre
FROM comprobante c
JOIN sala_venta s ON s.id_sala = c.id_sala
WHERE c.fecha >= (
    SELECT max(fecha) FROM comprobante
) - INTERVAL '3 months'
GROUP BY c.id_sala, s.calle, s.numero
ORDER BY monto_total_ventas_trimestre DESC;

-- =============================================================================
-- S9: Ficha de un vino: cepas con sus porcentajes, bodega elaboradora,
-- maridajes y stock total (depósito más salas).
-- Herramienta esperada: Joins, agregación y vista.
-- =============================================================================
-- Estrategia:
--   1. Elegir un vino concreto (cod_vino = 1).
--   2. Obtener composición de cepas (vino_cepa) con nombre y porcentaje.
--   3. Obtener bodega elaboradora.
--   4. Obtener maridajes asociados.
--   5. Calcular stock total = stock_deposito + suma stock_sala.
--   6. Usar la vista mv_stock_total_por_vino si existe para el stock total.
SELECT v.cod_vino, v.nombre AS vino, v.tipo, v.anada, v.volumen_ml, v.precio,
       b.razon_social AS bodega_elaboradora,
       -- Cepas con porcentajes (agrupadas como texto)
       STRING_AGG(c.nombre || ' (' || vc.porcentaje || '%)', ', '
                  ORDER BY vc.porcentaje DESC) AS composicion_cepas,
       -- Maridajes (agrupados como texto)
       STRING_AGG(m.nombre, ', ' ORDER BY m.nombre) AS maridajes,
       -- Stock total: depósito + salas
       COALESCE(sd.cantidad, 0) + COALESCE(ss.stock_salas, 0) AS stock_total
FROM vino v
JOIN bodega b ON b.id_bodega = v.id_bodega
JOIN vino_cepa vc ON vc.cod_vino = v.cod_vino
JOIN cepa c ON c.id_cepa = vc.id_cepa
LEFT JOIN vino_maridaje vm ON vm.cod_vino = v.cod_vino
LEFT JOIN maridaje m ON m.id_maridaje = vm.id_maridaje
LEFT JOIN stock_deposito sd ON sd.cod_vino = v.cod_vino
LEFT JOIN (
    SELECT cod_vino, SUM(cantidad) AS stock_salas
    FROM stock_sala
    GROUP BY cod_vino
) ss ON ss.cod_vino = v.cod_vino
WHERE v.cod_vino = 1
GROUP BY v.cod_vino, v.nombre, v.tipo, v.anada, v.volumen_ml, v.precio,
         b.razon_social, sd.cantidad, ss.stock_salas;

-- =============================================================================
-- S10: Rendimiento en kg por hectárea de cada parcela y campaña, e identificar
-- las parcelas que rinden menos que el promedio de su finca.
-- Herramienta esperada: CTE y subconsulta correlacionada.
-- =============================================================================
-- Estrategia:
--   1. CTE: calcular kg_por_hectarea = kilos_cosechados / superficie_ha por
--      parcela y campaña (join lote_uva con parcela).
--   2. Subconsulta correlacionada: promedio de rendimiento de la finca de cada
--      parcela (otras parcelas de la misma finca).
--   3. Marcar si rinde menos que el promedio de su finca.
WITH rendimiento_parcela AS (
    SELECT l.id_finca, l.nro_parcela, l.campania,
           l.kilos_cosechados,
           p.superficie_ha,
           l.kilos_cosechados / NULLIF(p.superficie_ha, 0) AS kg_por_hectarea
    FROM lote_uva l
    JOIN parcela p ON p.id_finca = l.id_finca AND p.nro_parcela = l.nro_parcela
)
SELECT rp.id_finca, rp.nro_parcela, rp.campania,
       rp.kilos_cosechados, rp.superficie_ha, rp.kg_por_hectarea,
       -- Promedio de rendimiento de la finca (subconsulta correlacionada)
       (
           SELECT AVG(rp2.kg_por_hectarea)
           FROM rendimiento_parcela rp2
           WHERE rp2.id_finca = rp.id_finca
       ) AS promedio_finca_kg_ha,
       CASE
           WHEN rp.kg_por_hectarea < (
               SELECT AVG(rp2.kg_por_hectarea)
               FROM rendimiento_parcela rp2
               WHERE rp2.id_finca = rp.id_finca
           ) THEN 'rinde_menos_que_promedio_finca'
           ELSE 'rinde_promedio_o_mas'
       END AS observacion
FROM rendimiento_parcela rp
ORDER BY rp.id_finca, rp.nro_parcela, rp.campania;

-- =============================================================================
-- S11: Ranking de vinos dentro de cada sala por botellas vendidas y ventas
-- acumuladas mensuales por sala.
-- Herramienta esperada: RANK() OVER (PARTITION BY ...) y suma acumulada con
-- ventana.
-- =============================================================================
-- Estrategia:
--   1. Parte A: ranking de vinos por sala (botellas vendidas) con RANK().
--   2. Parte B: ventas acumuladas mensuales por sala con SUM() OVER (ORDER BY
--      mes).
SELECT 'ranking_vinos_por_sala' AS parte, id_sala, cod_vino,
       total_botellas,
       RANK() OVER (PARTITION BY id_sala ORDER BY total_botellas DESC) AS ranking_por_sala
FROM (
    SELECT c.id_sala, r.cod_vino, SUM(r.cantidad) AS total_botellas
    FROM comprobante c
    JOIN renglon_comprobante r ON r.nro_comprobante = c.nro_comprobante
    GROUP BY c.id_sala, r.cod_vino
) sub
ORDER BY id_sala, ranking_por_sala;

SELECT 'ventas_acumuladas_mensuales_por_sala' AS parte,
       id_sala, mes, ventas_mes,
       SUM(ventas_mes) OVER (PARTITION BY id_sala ORDER BY mes
                             ROWS UNBOUNDED PRECEDING) AS ventas_acumuladas
FROM (
    SELECT c.id_sala,
           date_trunc('month', c.fecha)::date AS mes,
           SUM(c.total) AS ventas_mes
    FROM comprobante c
    GROUP BY c.id_sala, date_trunc('month', c.fecha)
) sub
ORDER BY id_sala, mes;

-- =============================================================================
-- S12: Clientes que compraron todos los vinos de una bodega determinada, y
-- clientes que nunca compraron ningún vino tinto.
-- Herramienta esperada: NOT EXISTS (división) y anti-join.
-- =============================================================================
-- Estrategia:
--   1. Parte A: clientes que compraron TODOS los vinos de una bodega
--      (bodega id = 1). División relacional con NOT EXISTS: no existe un vino
--      de esa bodega que el cliente NO haya comprado.
--   2. Parte B: clientes que NUNCA compraron vino tinto (anti-join con NOT
--      EXISTS sobre compras de vinos tipo 'tinto').
-- Parte A: clientes que compraron todos los vinos de la bodega 1
SELECT c.id_cliente, c.nombre_razon_social, c.tipo_cliente
FROM cliente c
WHERE NOT EXISTS (
    SELECT 1 FROM vino v
    WHERE v.id_bodega = 1
      AND NOT EXISTS (
          SELECT 1 FROM comprobante cp
          JOIN renglon_comprobante rc ON rc.nro_comprobante = cp.nro_comprobante
          WHERE cp.id_cliente = c.id_cliente
            AND rc.cod_vino = v.cod_vino
      )
);

-- Parte B: clientes que nunca compraron ningún vino tinto (anti-join)
SELECT c.id_cliente, c.nombre_razon_social, c.tipo_cliente
FROM cliente c
WHERE NOT EXISTS (
    SELECT 1 FROM comprobante cp
    JOIN renglon_comprobante rc ON rc.nro_comprobante = cp.nro_comprobante
    JOIN vino v ON v.cod_vino = rc.cod_vino
    WHERE cp.id_cliente = c.id_cliente
      AND v.tipo = 'tinto'
);

-- =============================================================================
-- Fin de select.sql (parte 2: S9-S12)
-- =============================================================================
