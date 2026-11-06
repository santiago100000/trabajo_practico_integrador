-- =============================================================================
-- insert.sql
-- Consignas I1-I6 del enunciado PDF (sección 8.2 - Inserción de datos).
-- Para cada una: código, enunciado, estrategia y consulta SQL.
-- Las que modifican datos están envueltas en BEGIN; ... ROLLBACK; (plantilla
-- comentada) para no dejar cambios a medias. Valores concretos obtenidos del
-- dataset cargado (subconsultas en lugar de IDs fijos).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- I1: Insertar en transportista-localidad una nueva cobertura que vincule la
-- localidad de General Alvear con el transportista que menos envíos (ingresos
-- trasladados) haya realizado en el último trimestre.
-- -----------------------------------------------------------------------------
-- Estrategia:
--   1. Obtener id_localidad de General Alvear.
--   2. Contar ingresos por transportista en los últimos 3 meses (medido desde
--      la fecha máxima de ingreso).
--   3. Elegir el transportista con menos envíos (COUNT, LIMIT 1).
--   4. Insertar la relación en transportista_localidad.
-- Plantilla (comentada, para no dejar cambios a medias):
-- BEGIN;
--   -- control previo: verificar que no exista ya la relación
--   -- sentencia INSERT
--   -- control posterior: SELECT para verificar la inserción
-- ROLLBACK;
INSERT INTO transportista_localidad (cod_transportista, id_localidad)
VALUES (
    (
        SELECT cod_transportista
        FROM (
            SELECT t.cod_transportista, COUNT(i.cod_ingreso) AS n_envios
            FROM transportista t
            LEFT JOIN ingreso i
              ON i.cod_transportista = t.cod_transportista
             AND i.fecha >= (
                 SELECT max(fecha) FROM ingreso
             ) - INTERVAL '3 months'
            GROUP BY t.cod_transportista
            ORDER BY n_envios ASC, t.cod_transportista ASC
            LIMIT 1
        ) sub
    ),
    (
        SELECT id_localidad FROM localidad WHERE nombre = 'General Alvear' LIMIT 1
    )
)
ON CONFLICT (cod_transportista, id_localidad) DO NOTHING;

-- -----------------------------------------------------------------------------
-- I2: Si existe algún vino tinto con graduación de 14° o más, crear el maridaje
-- «cordero al disco» y asociarlo a todos los vinos que cumplan esa condición.
-- -----------------------------------------------------------------------------
-- Estrategia:
--   1. Verificar que exista al menos un vino tinto con graduación >= 14.
--   2. Insertar el maridaje 'cordero al disco' con temperatura 18 °C (carne).
--   3. Asociar ese maridaje a todos los vinos tintos con graduación >= 14 que
--      aún no tengan esa asociación (NOT EXISTS para evitar duplicados).
-- Plantilla (comentada):
-- BEGIN;
--   -- control previo: contar vinos tintos con graduación >= 14
--   -- sentencia INSERT (maridaje + wine_maridaje)
--   -- control posterior: verificar asociación
-- ROLLBACK;
-- Insertar maridaje (id_maridaje es identity, no se especifica)
INSERT INTO maridaje (nombre, temperatura_servicio)
VALUES ('cordero al disco', 18)
ON CONFLICT (nombre) DO NOTHING;

-- Asociar a vinos tintos con graduación >= 14 que no tengan ya el maridaje
INSERT INTO vino_maridaje (cod_vino, id_maridaje)
SELECT v.cod_vino, m.id_maridaje
FROM vino v
CROSS JOIN maridaje m
WHERE v.tipo = 'tinto'
  AND v.graduacion >= 14
  AND m.nombre = 'cordero al disco'
  AND NOT EXISTS (
      SELECT 1 FROM vino_maridaje vm
      WHERE vm.cod_vino = v.cod_vino AND vm.id_maridaje = m.id_maridaje
  );

-- -----------------------------------------------------------------------------
-- I3: Crear un nuevo comprobante con tres renglones para un cliente dado, en la
-- sala con ID 1, dentro de una transacción y usando las funciones de cálculo.
-- -----------------------------------------------------------------------------
-- Estrategia:
--   1. Elegir un cliente existente (id_cliente = 1, exportador).
--   2. Insertar comprobante con subtotal=descuento=total=0 (el trigger los
--      recalcula vía fn_total_comprobante).
--   3. Insertar 3 renglones con vinos diferentes de la sala 1.
--   4. El trigger trg_descontar_stock_y_calcular_totales descuenta stock y
--      recalcula totales (RN-08, RN-09).
--   5. Verificar que el total del comprobante coincida con la suma de renglones.
-- Plantilla (comentada):
-- BEGIN;
--   -- control previo: verificar stock disponible en sala 1 para los 3 vinos
--   INSERT INTO comprobante (...) VALUES (...);
--   INSERT INTO renglon_comprobante (...) VALUES (...);  -- x3
--   -- control posterior: SELECT subtotal, total FROM comprobante
-- ROLLBACK;
INSERT INTO comprobante (fecha, id_cliente, id_sala, subtotal, descuento, total)
VALUES (CURRENT_DATE, 1, 1, 0, 0, 0);

INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
SELECT currval(pg_get_serial_sequence('comprobante', 'nro_comprobante')), cod_vino, 2, precio, 30, 0
FROM vino
WHERE cod_vino IN (
    SELECT cod_vino FROM vino ORDER BY cod_vino LIMIT 3 OFFSET 0
);

-- -----------------------------------------------------------------------------
-- I4: Insertar una nueva bodega.
-- -----------------------------------------------------------------------------
-- Estrategia: INSERT simple con CUIT válido (11 dígitos) y razón social única.
-- Plantilla (comentada):
-- BEGIN;
--   INSERT INTO bodega (cuit, razon_social, domicilio) VALUES (...);
--   control posterior: SELECT * FROM bodega WHERE cuit = ...;
-- ROLLBACK;
INSERT INTO bodega (cuit, razon_social, domicilio)
VALUES ('20123456789', 'Bodega Nueva del Atuel S.A.', 'Ruta Nacional 143, km 12, San Rafael');

-- -----------------------------------------------------------------------------
-- I5: Insertar una nueva sala de venta.
-- -----------------------------------------------------------------------------
-- Estrategia: INSERT simple con id_localidad existente y dia_cierre válido (ENUM).
-- Plantilla (comentada):
-- BEGIN;
--   INSERT INTO sala_venta (id_localidad, calle, numero, dia_cierre) VALUES (...);
--   control posterior: SELECT * FROM sala_venta WHERE id_sala = ...;
-- ROLLBACK;
INSERT INTO sala_venta (id_localidad, calle, numero, dia_cierre)
VALUES ((SELECT id_localidad FROM localidad WHERE nombre = 'Mendoza' LIMIT 1),
        'Calle Falsa 123', '456', 'viernes');

-- -----------------------------------------------------------------------------
-- I6: Crear un ingreso en confección de 120 botellas de un vino determinado
-- («Malbec Reserva» de 750 ml), elaborado por una bodega dada y transportista
-- dado.
-- -----------------------------------------------------------------------------
-- Estrategia:
--   1. Obtener cod_vino del vino 'Malbec Reserva' 750 ml (subconsulta).
--   2. Obtener id_bodega de una bodega dada (subconsulta).
--   3. Obtener cod_transportista de un transportista dado (subconsulta).
--   4. Insertar ingreso en estado 'en_confeccion' (default).
--   5. Insertar renglón de ingreso con cantidad 120.
-- Plantilla (comentada):
-- BEGIN;
--   -- control previo: verificar que el vino exista y tenga stock suficiente
--   INSERT INTO ingreso (...) VALUES (...);
--   INSERT INTO renglon_ingreso (...) VALUES (...);
--   control posterior: verificar estado = 'en_confeccion'
-- ROLLBACK;
INSERT INTO ingreso (fecha, estado, cod_transportista, id_bodega)
VALUES (
    CURRENT_DATE,
    'en_confeccion',
    (SELECT cod_transportista FROM transportista LIMIT 1),
    (SELECT id_bodega FROM bodega LIMIT 1)
);

INSERT INTO renglon_ingreso (cod_ingreso, cod_vino, cantidad)
VALUES (
    currval(pg_get_serial_sequence('ingreso', 'cod_ingreso')),
    (
        SELECT cod_vino FROM vino
        WHERE nombre ILIKE '%Malbec Reserva%' AND volumen_ml = 750
        LIMIT 1
    ),
    120
);

-- =============================================================================
-- Fin de insert.sql
-- =============================================================================
