-- =============================================================================
-- 006_vistas.sql
-- Etapa: 2 - Integridad y lógica en la base de datos
-- Propósito: Crear 3 vistas (una puede ser materializada).
-- Vista 1: Stock total por vino (depósito + salas) — materializada
-- Vista 2: Ventas mensuales por sala
-- Vista 3: Documentos pendientes (ingresos y transferencias en confección o terminado)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Vista 1 (MATERIALIZADA): Stock total por vino (depósito central + salas)
-- ---------------------------------------------------------------------------
CREATE MATERIALIZED VIEW mv_stock_total_por_vino AS
SELECT
    v.cod_vino,
    v.nombre,
    v.tipo,
    v.anada,
    v.volumen_ml,
    COALESCE(sd.cantidad, 0) AS stock_deposito,
    COALESCE(ss.stock_salas, 0) AS stock_salas,
    (COALESCE(sd.cantidad, 0) + COALESCE(ss.stock_salas, 0)) AS stock_total
FROM vino v
LEFT JOIN stock_deposito sd ON v.cod_vino = sd.cod_vino
LEFT JOIN (
    SELECT cod_vino, SUM(cantidad) AS stock_salas
    FROM stock_sala
    GROUP BY cod_vino
) ss ON v.cod_vino = ss.cod_vino
WITH DATA;

CREATE UNIQUE INDEX idx_mv_stock_total_cod_vino ON mv_stock_total_por_vino (cod_vino);

-- ---------------------------------------------------------------------------
-- Vista 2: Ventas mensuales por sala (últimos 12 meses)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_ventas_mensuales_por_sala AS
SELECT
    s.id_sala,
    s.calle,
    s.numero,
    l.nombre AS localidad,
    DATE_TRUNC('month', c.fecha) AS mes,
    COUNT(DISTINCT c.nro_comprobante) AS cant_comprobantes,
    SUM(r.cantidad) AS cant_botellas_vendidas,
    SUM(c.total) AS monto_total_ventas
FROM comprobante c
JOIN sala_venta s ON c.id_sala = s.id_sala
JOIN localidad l ON s.id_localidad = l.id_localidad
JOIN renglon_comprobante r ON c.nro_comprobante = r.nro_comprobante
WHERE c.fecha >= (SELECT MAX(fecha) FROM comprobante) - INTERVAL '12 months'
GROUP BY s.id_sala, s.calle, s.numero, l.nombre, DATE_TRUNC('month', c.fecha)
ORDER BY s.id_sala, mes DESC;

-- ---------------------------------------------------------------------------
-- Vista 3: Documentos pendientes (ingresos y transferencias no procesados)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_documentos_pendientes AS
SELECT
    'ingreso' AS tipo_documento,
    cod_ingreso AS id_documento,
    fecha,
    estado,
    b.razon_social AS bodega_origen,
    t.razon_social AS transportista
FROM ingreso i
JOIN bodega b ON i.id_bodega = b.id_bodega
JOIN transportista t ON i.cod_transportista = t.cod_transportista
WHERE i.estado IN ('en_confeccion', 'terminado')

UNION ALL

SELECT
    'transferencia' AS tipo_documento,
    nro_solicitud AS id_documento,
    fecha_confeccion AS fecha,
    estado,
    NULL AS bodega_origen,
    NULL AS transportista
FROM transferencia tr
WHERE tr.estado IN ('en_confeccion', 'terminado')
ORDER BY tipo_documento, fecha DESC;

-- =============================================================================
-- Resumen de vistas implementadas:
--   1. mv_stock_total_por_vino   → MATERIALIZED VIEW  → stock depósito + salas
--   2. vw_ventas_mensuales_por_sala → VIEW            → ventas últimos 12 meses
--   3. vw_documentos_pendientes   → VIEW              → ingresos y transferencias pendientes
-- =============================================================================
