-- ============================================================================
-- consultas/insert.sql — Etapa 5: Consultas SQL (INSERT)
-- Sección 8.2 del enunciado TPI Bodegas del Atuel
-- Valores concretos tomados del dataset cargado (Etapa 3, semilla 42).
-- Cada modificación se ejecuta dentro de BEGIN ... ROLLBACK para no persistir cambios.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- I1: Insertar en transportista_localidad una nueva cobertura que vincule
--     la localidad de General Alvear con el transportista que menos envíos
--     (ingresos trasladados) haya realizado en el último trimestre.
-- Estrategia: Subconsulta para hallar el transportista con menos ingresos
--     en los últimos 3 meses; si no hay ingresos (dataset vacío), usar el
--     transportista de menor id por defecto (COALESCE).
--     id_localidad General Alvear = 12 (verificado en dataset).
-- ---------------------------------------------------------------------------
BEGIN;
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
SELECT 'I1: cobertura insertada (o ya existía)' AS resultado;
ROLLBACK;

-- ---------------------------------------------------------------------------
-- I2: Si existe algún vino tinto con graduación de 14° o más, crear el maridaje
--     «cordero al disco» y asociarlo a todos los vinos que cumplan esa condición.
-- Estrategia: DO bloque para condicional; INSERT maridaje con ON CONFLICT DO NOTHING;
--     luego INSERT vino_maridaje asociando todos los vinos tinto >= 14°.
-- Vinos que cumplen (verificados): cod_vino 5, 8, 13, 14, 20.
-- ---------------------------------------------------------------------------
BEGIN;
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
SELECT 'I2: maridaje cordero al disco asociado a vinos tintos >= 14°' AS resultado;
ROLLBACK;

-- ---------------------------------------------------------------------------
-- I3: Crear un nuevo comprobante con tres renglones para un cliente dado,
--     en la sala con ID 1, dentro de una transacción y usando las funciones
--     de cálculo.
-- Estrategia: cliente 1 (exportador, descuento 30%), sala 1, tres vinos con
--     stock suficiente en sala 1. Se inserta comprobante con subtotal=0,
--     descuento=0, total=0 (los triggers recalculan). Luego se insertan los
--     renglones; el trigger AFTER INSERT recalcula totales y descuenta stock.
--     Se consulta fn_total_comprobante para verificar el total final.
-- Vinos y precios: 23 (Malbec Reserva 2018, 23820.22), 41 (Chenin Blanc 2020, 6978.56),
--     6 (Cabernet Sauvignon 2018, 8135.64). Cantidad 2 cada uno.
-- ---------------------------------------------------------------------------
BEGIN;
INSERT INTO comprobante (fecha, id_cliente, id_sala, subtotal, descuento, total)
VALUES (CURRENT_DATE, 1, 1, 0, 0, 0)
RETURNING nro_comprobante;

-- Capturar el nro_comprobante generado (en un script real se usaría RETURNING en la app)
-- Aquí lo consultamos directamente:
INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
SELECT nro_comprobante, 23, 2, 23820.22, 30, ROUND(2 * 23820.22 * (1 - 30/100), 2)
FROM comprobante WHERE nro_comprobante = (SELECT MAX(nro_comprobante) FROM comprobante);

INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
SELECT nro_comprobante, 41, 2, 6978.56, 30, ROUND(2 * 6978.56 * (1 - 30/100), 2)
FROM comprobante WHERE nro_comprobante = (SELECT MAX(nro_comprobante) FROM comprobante);

INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
SELECT nro_comprobante, 6, 2, 8135.64, 30, ROUND(2 * 8135.64 * (1 - 30/100), 2)
FROM comprobante WHERE nro_comprobante = (SELECT MAX(nro_comprobante) FROM comprobante);

SELECT c.nro_comprobante, c.subtotal, c.descuento, c.total,
       fn_total_comprobante(c.nro_comprobante) AS total_verificado
FROM comprobante c
WHERE c.nro_comprobante = (SELECT MAX(nro_comprobante) FROM comprobante);
ROLLBACK;

-- ---------------------------------------------------------------------------
-- I4: Insertar una nueva bodega.
-- Estrategia: INSERT con CUIT único que no exista en la tabla (verificado
--     que no hay bodega con cuit 30123456789).
-- ---------------------------------------------------------------------------
BEGIN;
INSERT INTO bodega (cuit, razon_social, domicilio)
VALUES ('30123456789', 'Bodega Ejemplo S.A.', 'Ruta Nacional 40, km 1200, Luján de Cuyo, Mendoza');
SELECT * FROM bodega WHERE cuit = '30123456789';
ROLLBACK;

-- ---------------------------------------------------------------------------
-- I5: Insertar una nueva sala de venta.
-- Estrategia: nueva sala en localidad 12 (General Alvear), día de cierre lunes.
-- ---------------------------------------------------------------------------
BEGIN;
INSERT INTO sala_venta (id_localidad, calle, numero, dia_cierre)
VALUES (12, 'Calle Falsa 123', '456', 'lunes')
RETURNING id_sala, calle, numero, dia_cierre, id_localidad;
ROLLBACK;

-- ---------------------------------------------------------------------------
-- I6: Crear un ingreso en confección de 120 botellas de un vino determinado
--     (por ejemplo «Tempranillo 2018» cod_vino=1), elaborado por una bodega
--     dada (id_bodega=1) y trasladado por un transportista dado
--     (cod_transportista=1).
-- Estrategia: INSERT ingreso en estado 'en_confeccion' (default), luego
--     INSERT renglon_ingreso con 120 botellas.
-- ---------------------------------------------------------------------------
BEGIN;
INSERT INTO ingreso (fecha, estado, cod_transportista, id_bodega)
VALUES (CURRENT_DATE, 'en_confeccion', 1, 1)
RETURNING cod_ingreso;

INSERT INTO renglon_ingreso (cod_ingreso, cod_vino, cantidad)
SELECT cod_ingreso, 1, 120
FROM ingreso WHERE cod_ingreso = (SELECT MAX(cod_ingreso) FROM ingreso);

SELECT i.cod_ingreso, i.estado, i.cod_transportista, i.id_bodega,
       ri.cod_vino, ri.cantidad
FROM ingreso i
JOIN renglon_ingreso ri ON ri.cod_ingreso = i.cod_ingreso
WHERE i.cod_ingreso = (SELECT MAX(cod_ingreso) FROM ingreso);
ROLLBACK;
