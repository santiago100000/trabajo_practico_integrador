-- ============================================================================
-- consultas/insert.sql — Etapa 5, Paso 1 y Paso 2: Consultas SQL (INSERT)
-- Sección 8.2 del enunciado TPI Bodegas del Atuel
-- Cada consigna incluye: código, enunciado, consulta SQL y estrategia.
-- Valores concretos tomados del dataset cargado (Etapa 3, semilla 42).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- I1: Insertar en la relación transportista-localidad una nueva cobertura que
--     vincule la localidad de General Alvear con el transportista que menos
--     envíos (ingresos trasladados) haya realizado en el último trimestre.
-- Parámetro: localidad General Alvear (id_localidad = 12).
-- Estrategia: Subconsulta para hallar el transportista con menos ingresos en
-- los últimos 3 meses; si no hay ingresos, usar el transportista de menor id
-- por defecto (COALESCE). ON CONFLICT DO NOTHING para evitar duplicados.
-- ---------------------------------------------------------------------------
BEGIN;
-- Consulta de control previa: transportistas y sus ingresos en último trimestre
SELECT tr.cod_transportista, tr.razon_social, COUNT(i.cod_ingreso) AS ingresos_trimestre
FROM transportista tr
LEFT JOIN ingreso i ON i.cod_transportista = tr.cod_transportista
    AND i.fecha >= CURRENT_DATE - INTERVAL '3 months'
GROUP BY tr.cod_transportista, tr.razon_social
ORDER BY ingresos_trimestre ASC, tr.cod_transportista;

-- Inserción de cobertura
INSERT INTO transportista_localidad (cod_transportista, id_localidad)
VALUES (
    COALESCE((
        SELECT i.cod_transportista
        FROM ingreso i
        WHERE i.fecha >= CURRENT_DATE - INTERVAL '3 months'
        GROUP BY i.cod_transportista
        ORDER BY COUNT(*) ASC, i.cod_transportista ASC
        LIMIT 1
    ), 1),
    12
) ON CONFLICT (cod_transportista, id_localidad) DO NOTHING;

-- Consulta de control posterior
SELECT * FROM transportista_localidad
WHERE id_localidad = 12 AND cod_transportista = (
    COALESCE((
        SELECT i.cod_transportista
        FROM ingreso i
        WHERE i.fecha >= CURRENT_DATE - INTERVAL '3 months'
        GROUP BY i.cod_transportista
        ORDER BY COUNT(*) ASC, i.cod_transportista ASC
        LIMIT 1
    ), 1)
);
ROLLBACK;

-- ---------------------------------------------------------------------------
-- I2: Si existe algún vino tinto con graduación de 14° o más, crear el maridaje
--     «cordero al disco» y asociarlo a todos los vinos que cumplan esa condición.
-- Estrategia: Bloque DO para condicional; INSERT maridaje con ON CONFLICT DO
-- NOTHING; luego INSERT vino_maridaje asociando todos los vinos tinto >= 14°.
-- ---------------------------------------------------------------------------
BEGIN;
-- Consulta de control previa: vinos tintos con graduación >= 14
SELECT cod_vino, nombre, graduacion
FROM vino
WHERE tipo = 'tinto' AND graduacion >= 14
ORDER BY cod_vino;

DO $$
DECLARE
    v_existe boolean;
    m_id integer;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM vino WHERE tipo = 'tinto' AND graduacion >= 14
    ) INTO v_existe;

    IF v_existe THEN
        INSERT INTO maridaje (nombre, temperatura_servicio)
        VALUES ('cordero al disco', 18.0)
        ON CONFLICT (nombre) DO NOTHING
        RETURNING id_maridaje INTO m_id;

        IF m_id IS NULL THEN
            SELECT id_maridaje INTO m_id FROM maridaje WHERE nombre = 'cordero al disco';
        END IF;

        INSERT INTO vino_maridaje (cod_vino, id_maridaje)
        SELECT v.cod_vino, m_id
        FROM vino v
        WHERE v.tipo = 'tinto' AND v.graduacion >= 14
        ON CONFLICT (cod_vino, id_maridaje) DO NOTHING;
    END IF;
END $$;

-- Consulta de control posterior
SELECT v.cod_vino, v.nombre, m.nombre AS maridaje
FROM vino v
JOIN vino_maridaje vm ON vm.cod_vino = v.cod_vino
JOIN maridaje m ON m.id_maridaje = vm.id_maridaje
WHERE v.tipo = 'tinto' AND v.graduacion >= 14 AND m.nombre = 'cordero al disco'
ORDER BY v.cod_vino;
ROLLBACK;

-- ---------------------------------------------------------------------------
-- I3: Crear un nuevo comprobante con tres renglones para un cliente dado,
--     en la sala con ID 1, dentro de una transacción y usando las funciones
--     de cálculo.
-- Parámetros: cliente ID 1 (exportador, descuento 30%), sala ID 1.
-- Vinos: cod_vino 23 (Malbec Reserva 2018, 23820.22), cod_vino 41 (Chenin
-- Blanc 2020, 6978.56), cod_vino 6 (Cabernet Sauvignon 2018, 8135.64).
-- Cantidad 2 cada uno.
-- Estrategia: INSERT comprobante con subtotal=0, descuento=0, total=0 (los
-- triggers recalculan). Luego INSERT de renglones; el trigger AFTER INSERT
-- recalcula totales y descuenta stock. Se consulta fn_total_comprobante para
-- verificar el total final.
-- ---------------------------------------------------------------------------
BEGIN;
-- Consulta de control previa: stock disponible en sala 1 para los vinos
SELECT ss.cod_vino, v.nombre, ss.cantidad AS stock_disponible
FROM stock_sala ss
JOIN vino v ON v.cod_vino = ss.cod_vino
WHERE ss.id_sala = 1 AND ss.cod_vino IN (23, 41, 6);

-- Insertar comprobante
INSERT INTO comprobante (fecha, id_cliente, id_sala, subtotal, descuento, total)
VALUES (CURRENT_DATE, 1, 1, 0, 0, 0)
RETURNING nro_comprobante;

-- Insertar renglones (el trigger recalcula totales y descuenta stock)
INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
SELECT nro_comprobante, 23, 2, 23820.22, 30, ROUND(2 * 23820.22 * (1 - 30/100), 2)
FROM comprobante WHERE nro_comprobante = (SELECT MAX(nro_comprobante) FROM comprobante);

INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
SELECT nro_comprobante, 41, 2, 6978.56, 30, ROUND(2 * 6978.56 * (1 - 30/100), 2)
FROM comprobante WHERE nro_comprobante = (SELECT MAX(nro_comprobante) FROM comprobante);

INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
SELECT nro_comprobante, 6, 2, 8135.64, 30, ROUND(2 * 8135.64 * (1 - 30/100), 2)
FROM comprobante WHERE nro_comprobante = (SELECT MAX(nro_comprobante) FROM comprobante);

-- Consulta de control posterior: verificar totales
SELECT c.nro_comprobante, c.subtotal, c.descuento, c.total,
       fn_total_comprobante(c.nro_comprobante) AS total_verificado
FROM comprobante c
WHERE c.nro_comprobante = (SELECT MAX(nro_comprobante) FROM comprobante);

-- Verificar stock descontado
SELECT ss.cod_vino, v.nombre, ss.cantidad AS stock_despues
FROM stock_sala ss
JOIN vino v ON v.cod_vino = ss.cod_vino
WHERE ss.id_sala = 1 AND ss.cod_vino IN (23, 41, 6);
ROLLBACK;

-- ---------------------------------------------------------------------------
-- I4: Insertar una nueva bodega.
-- Estrategia: INSERT con CUIT único que no exista en la tabla.
-- ---------------------------------------------------------------------------
BEGIN;
-- Consulta de control previa: verificar que el CUIT no exista
SELECT * FROM bodega WHERE cuit = '30123456789';

INSERT INTO bodega (cuit, razon_social, domicilio)
VALUES ('30123456789', 'Bodega Ejemplo S.A.', 'Ruta Nacional 40, km 1200, Luján de Cuyo, Mendoza');

-- Consulta de control posterior
SELECT * FROM bodega WHERE cuit = '30123456789';
ROLLBACK;

-- ---------------------------------------------------------------------------
-- I5: Insertar una nueva sala de venta.
-- Estrategia: nueva sala en localidad 12 (General Alvear), día de cierre lunes.
-- ---------------------------------------------------------------------------
BEGIN;
-- Consulta de control previa: salas existentes en localidad 12
SELECT id_sala, calle, numero, dia_cierre
FROM sala_venta
WHERE id_localidad = 12;

INSERT INTO sala_venta (id_localidad, calle, numero, dia_cierre)
VALUES (12, 'Calle Falsa 123', '456', 'lunes')
RETURNING id_sala, calle, numero, dia_cierre, id_localidad;

-- Consulta de control posterior
SELECT id_sala, calle, numero, dia_cierre, id_localidad
FROM sala_venta
WHERE calle = 'Calle Falsa 123';
ROLLBACK;

-- ---------------------------------------------------------------------------
-- I6: Crear un ingreso en confección de 120 botellas de un vino determinado
--     (por ejemplo «Tempranillo 2018» cod_vino=1), elaborado por una bodega
--     dada (id_bodega=1) y trasladado por un transportista dado
--     (cod_transportista=1).
-- Estrategia: INSERT ingreso en estado 'en_confeccion' (default), luego
-- INSERT renglon_ingreso con 120 botellas.
-- ---------------------------------------------------------------------------
BEGIN;
-- Consulta de control previa: verificar existencia de vino, bodega y transportista
SELECT v.cod_vino, v.nombre FROM vino v WHERE v.cod_vino = 1;
SELECT b.id_bodega, b.razon_social FROM bodega b WHERE b.id_bodega = 1;
SELECT tr.cod_transportista, tr.razon_social FROM transportista tr WHERE tr.cod_transportista = 1;

INSERT INTO ingreso (fecha, estado, cod_transportista, id_bodega)
VALUES (CURRENT_DATE, 'en_confeccion', 1, 1)
RETURNING cod_ingreso;

INSERT INTO renglon_ingreso (cod_ingreso, cod_vino, cantidad)
SELECT cod_ingreso, 1, 120
FROM ingreso WHERE cod_ingreso = (SELECT MAX(cod_ingreso) FROM ingreso);

-- Consulta de control posterior
SELECT i.cod_ingreso, i.estado, i.cod_transportista, i.id_bodega,
       ri.cod_vino, ri.cantidad
FROM ingreso i
JOIN renglon_ingreso ri ON ri.cod_ingreso = i.cod_ingreso
WHERE i.cod_ingreso = (SELECT MAX(cod_ingreso) FROM ingreso);
ROLLBACK;
