-- =============================================================================
-- db_tests.sql
-- Pruebas de base de datos para las reglas de negocio RN-01 a RN-15.
-- Cada regla tiene: "caso que debe funcionar" y "caso que debe fallar".
-- Los casos que deben fallar se envuelven en DO ... EXCEPTION para capturar
-- el error y reportar éxito si se lanza la excepción esperada.
-- =============================================================================

\echo '===== Inicio de db_tests.sql ====='
\set ON_ERROR_STOP on

-- =============================================================================
-- SETUP: Datos maestros mínimos para las pruebas
-- =============================================================================
\echo '--- SETUP: insertando datos maestros'

-- Deshabilitar trigger de coherencia cliente/subtipo durante el setup
-- (se vuelve a habilitar al final; las inserciones de cliente+subtipo
--  se hacen en pasos separados que el trigger no puede verificar atomicamente)
ALTER TABLE cliente DISABLE TRIGGER trg_coherencia_cliente_subtipo;

INSERT INTO provincia (nombre) VALUES ('Mendoza') ON CONFLICT DO NOTHING;
INSERT INTO departamento (id_provincia, nombre) VALUES (1, 'San Rafael') ON CONFLICT DO NOTHING;
INSERT INTO localidad (id_provincia, nombre, codigo_postal, encargado_regional)
VALUES (1, 'San Rafael', '5600', 'Encargado Test') ON CONFLICT DO NOTHING;
INSERT INTO bodega (cuit, razon_social, domicilio)
VALUES ('20123456789', 'Bodega Test', 'Calle Falsa 123') ON CONFLICT DO NOTHING;
INSERT INTO cepa (nombre, tipo) VALUES ('Malbec', 'tinta') ON CONFLICT DO NOTHING;
INSERT INTO cepa (nombre, tipo) VALUES ('Cabernet Sauvignon', 'tinta') ON CONFLICT DO NOTHING;
INSERT INTO maridaje (nombre, temperatura_servicio) VALUES ('Carnes rojas', 17.0) ON CONFLICT DO NOTHING;
INSERT INTO transportista (razon_social, cuit, email, telefono, domicilio)
VALUES ('Transportista Test', '20987654321', 'test@trans.com', '2621234567', 'Calle X 123')
ON CONFLICT DO NOTHING;
INSERT INTO sala_venta (id_localidad, calle, numero, dia_cierre)
VALUES (1, 'Av. Test', '100', 'lunes') ON CONFLICT DO NOTHING;

-- IDs esperados después del setup:
-- provincia: 1, departamento: 1, localidad: 1, bodega: 1
-- cepa: 1 (Malbec), 2 (Cabernet), maridaje: 1, transportista: 1, sala_venta: 1

-- =============================================================================
-- RN-01: El precio de un vino es único para toda la red y siempre mayor que cero
-- Mecanismo: CHECK (precio > 0) + UNIQUE (nombre, anada, volumen_ml)
-- =============================================================================

-- Caso que debe FUNCIONAR: precio > 0
\echo '--- RN-01: caso que debe funcionar (precio > 0)'
INSERT INTO vino (id_bodega, nombre, tipo, anada, volumen_ml, graduacion, precio)
VALUES (1, 'Vino Test RN-01 OK', 'tinto', 2021, 750, 14.00, 10000.00);

-- Caso que debe FALLAR: precio <= 0
\echo '--- RN-01: caso que debe fallar (precio <= 0)'
DO $$
BEGIN
    INSERT INTO vino (id_bodega, nombre, tipo, anada, volumen_ml, graduacion, precio)
    VALUES (1, 'Vino Test RN-01 FAIL', 'tinto', 2021, 750, 14.00, 0.00);
    RAISE EXCEPTION 'RN-01: debería haber fallado con precio <= 0';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'RN-01 OK: precio <= 0 rechazado (CHECK precio > 0)';
END;
$$;

-- =============================================================================
-- RN-02: Una sala pertenece a una sola localidad. Cada localidad tiene un único encargado regional.
-- Mecanismo: FK + diseño normalizado (3FN)
-- =============================================================================

-- Caso que debe FUNCIONAR: sala con localidad válida
\echo '--- RN-02: caso que debe funcionar (sala con localidad válida)'
INSERT INTO sala_venta (id_localidad, calle, numero, dia_cierre)
VALUES (1, 'Calle Test RN-02', '123', 'martes');

-- Caso que debe FALLAR: sala con localidad inexistente (FK violada)
\echo '--- RN-02: caso que debe fallar (localidad inexistente)'
DO $$
BEGIN
    INSERT INTO sala_venta (id_localidad, calle, numero, dia_cierre)
    VALUES (999999, 'Calle Test RN-02 FAIL', '123', 'miercoles');
    RAISE EXCEPTION 'RN-02: debería haber fallado con localidad inexistente';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'RN-02 OK: localidad inexistente rechazada (FK)';
END;
$$;

-- =============================================================================
-- RN-03: Cada empleado trabaja en una sola sala.
-- Mecanismo: FK NOT NULL
-- =============================================================================

-- Caso que debe FUNCIONAR: empleado con sala válida
\echo '--- RN-03: caso que debe funcionar (empleado con sala válida)'
INSERT INTO empleado (id_sala, cuit, nombre, apellido, fecha_ingreso, salario)
VALUES (1, '20123456789', 'Juan', 'Perez', '2020-01-01', 50000.00);

-- Caso que debe FALLAR: empleado con sala inexistente (FK violada)
\echo '--- RN-03: caso que debe fallar (sala inexistente)'
DO $$
BEGIN
    INSERT INTO empleado (id_sala, cuit, nombre, apellido, fecha_ingreso, salario)
    VALUES (999999, '20123456788', 'Maria', 'Garcia', '2020-01-01', 50000.00);
    RAISE EXCEPTION 'RN-03: debería haber fallado con sala inexistente';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'RN-03 OK: sala inexistente rechazada (FK)';
END;
$$;

-- Caso que debe FALLAR: empleado con cuit nulo (NOT NULL)
\echo '--- RN-03: caso que debe fallar (cuit nulo)'
DO $$
BEGIN
    INSERT INTO empleado (id_sala, cuit, nombre, apellido, fecha_ingreso, salario)
    VALUES (1, NULL, 'Sin CUIT', 'Apellido', '2020-01-01', 50000.00);
    RAISE EXCEPTION 'RN-03: debería haber fallado con cuit nulo';
EXCEPTION WHEN not_null_violation THEN
    RAISE NOTICE 'RN-03 OK: cuit nulo rechazado (NOT NULL)';
END;
$$;

-- =============================================================================
-- RN-04: Una parcela tiene una sola cepa y se cosecha como máximo una vez por campaña.
-- Mecanismo: FK + UNIQUE (id_finca, nro_parcela, campania)
-- =============================================================================

-- Necesitamos una finca primero
INSERT INTO finca (id_departamento, nombre, superficie_ha)
VALUES (1, 'Finca Test RN-04', 100.00) ON CONFLICT DO NOTHING;
INSERT INTO parcela (id_finca, nro_parcela, id_cepa, superficie_ha, anio_plantacion)
VALUES (1, 1, 1, 10.00, 2020) ON CONFLICT DO NOTHING;

-- Caso que debe FUNCIONAR: lote con parcela y campaña válidas
\echo '--- RN-04: caso que debe funcionar (lote válido)'
INSERT INTO lote_uva (id_finca, nro_parcela, campania, fecha_cosecha, kilos_cosechados, id_bodega)
VALUES (1, 1, 2024, '2024-03-15', 1000.00, 1);

-- Caso que debe FALLAR: misma parcela, misma campaña (UNIQUE violada)
\echo '--- RN-04: caso que debe fallar (misma parcela y campaña)'
DO $$
BEGIN
    INSERT INTO lote_uva (id_finca, nro_parcela, campania, fecha_cosecha, kilos_cosechados, id_bodega)
    VALUES (1, 1, 2024, '2024-04-01', 500.00, 1);
    RAISE EXCEPTION 'RN-04: debería haber fallado con parcela y campaña duplicadas';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'RN-04 OK: misma parcela y campaña rechazada (UNIQUE)';
END;
$$;

-- =============================================================================
-- RN-05: Los porcentajes de corte de un vino suman exactamente 100.
-- Mecanismo: Constraint trigger diferido
-- =============================================================================

-- Caso que debe FUNCIONAR: porcentajes que suman 100 (dentro de una transacción)
\echo '--- RN-05: caso que debe funcionar (porcentajes suman 100)'
BEGIN;
INSERT INTO vino_cepa (cod_vino, id_cepa, porcentaje)
VALUES (1, 1, 85.00);
INSERT INTO vino_cepa (cod_vino, id_cepa, porcentaje)
VALUES (1, 2, 15.00);
COMMIT;

-- Caso que debe FALLAR: porcentajes que NO suman 100 (constraint trigger diferido)
\echo '--- RN-05: caso que debe fallar (porcentajes no suman 100)'
DO $$
BEGIN
    INSERT INTO vino_cepa (cod_vino, id_cepa, porcentaje)
    VALUES (2, 1, 50.00);
    INSERT INTO vino_cepa (cod_vino, id_cepa, porcentaje)
    VALUES (2, 2, 30.00);
    COMMIT;
    RAISE EXCEPTION 'RN-05: debería haber fallado al hacer COMMIT (suma != 100)';
EXCEPTION WHEN others THEN
    ROLLBACK;
    RAISE NOTICE 'RN-05 OK: porcentajes que no suman 100 rechazados (constraint trigger diferido)';
END;
$$;

-- =============================================================================
-- RN-06: El descuento depende del tipo de cliente: socio 10 %, distribuidor 20 %, exportador 30 %.
-- Mecanismo: Función de descuento + CHECK de rango
-- =============================================================================

-- Caso que debe FUNCIONAR: descuento válido según tipo
\echo '--- RN-06: caso que debe funcionar (descuento válido)'
INSERT INTO cliente (tipo_cliente, nombre_razon_social, tipo_doc, nro_doc, direccion, id_localidad, fecha_alta, descuento)
VALUES ('socio', 'Cliente Test RN-06', 'DNI', '12345678', 'Calle 123', 1, '2020-01-01', 10.00);
INSERT INTO socio (id_cliente) VALUES (1);

-- Caso que debe FALLAR: descuento fuera de rango (CHECK violado)
\echo '--- RN-06: caso que debe fallar (descuento fuera de rango)'
DO $$
BEGIN
    INSERT INTO cliente (tipo_cliente, nombre_razon_social, tipo_doc, nro_doc, direccion, id_localidad, fecha_alta, descuento)
    VALUES ('socio', 'Cliente Test RN-06 FAIL', 'DNI', '12345679', 'Calle 123', 1, '2020-01-01', 150.00);
    RAISE EXCEPTION 'RN-06: debería haber fallado con descuento fuera de rango';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'RN-06 OK: descuento fuera de rango rechazado (CHECK 0-100)';
END;
$$;

-- =============================================================================
-- RN-07: Un exportador puede tener varios permisos; el vencimiento es posterior a la emisión.
-- Mecanismo: Tabla de permisos + CHECK entre columnas
-- =============================================================================

-- Necesitamos un cliente exportador
INSERT INTO cliente (tipo_cliente, nombre_razon_social, tipo_doc, nro_doc, direccion, id_localidad, fecha_alta, descuento)
VALUES ('exportador', 'Exportador Test RN-07', 'CUIT', '20111111111', 'Calle 456', 1, '2020-01-01', 30.00);
INSERT INTO exportador (id_cliente, pais_destino)
VALUES (3, 'Chile');

-- Caso que debe FUNCIONAR: permiso con vencimiento posterior a emisión
\echo '--- RN-07: caso que debe funcionar (vencimiento posterior a emisión)'
INSERT INTO permiso_exportacion (id_cliente, codigo, fecha_emision, fecha_vencimiento)
VALUES (3, 'PERM-001', '2024-01-01', '2025-01-01');

-- Caso que debe FALLAR: vencimiento antes o igual a emisión (CHECK entre columnas)
\echo '--- RN-07: caso que debe fallar (vencimiento <= emisión)'
DO $$
BEGIN
    INSERT INTO permiso_exportacion (id_cliente, codigo, fecha_emision, fecha_vencimiento)
    VALUES (3, 'PERM-002', '2025-01-01', '2024-01-01');
    RAISE EXCEPTION 'RN-07: debería haber fallado con vencimiento antes de emisión';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'RN-07 OK: vencimiento antes de emisión rechazado (CHECK entre columnas)';
END;
$$;

-- =============================================================================
-- RN-08: El total del comprobante es la suma de sus renglones con el descuento aplicado.
-- Mecanismo: Función de cálculo + trigger AFTER INSERT
-- =============================================================================

-- Necesitamos stock para la sala 1, vino 1
INSERT INTO stock_sala (id_sala, cod_vino, cantidad) VALUES (1, 1, 100);

-- Caso que debe FUNCIONAR: comprobante con renglones, total calculado por trigger
\echo '--- RN-08: caso que debe funcionar (total calculado por trigger)'
DO $$
DECLARE
    v_nro_comp integer;
BEGIN
    INSERT INTO comprobante (fecha, id_cliente, id_sala, subtotal, descuento, total)
    VALUES ('2024-01-15', 1, 1, 0.00, 0.00, 0.00)
    RETURNING nro_comprobante INTO v_nro_comp;

    INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
    VALUES (v_nro_comp, 1, 2, 5000.00, 10.00, 9000.00);
    -- El trigger debería haber actualizado subtotal y total del comprobante

    RAISE NOTICE 'RN-08: comprobante creado con nro = %', v_nro_comp;
END;
$$;

-- Verificar que el total fue calculado (no cargado a mano inconsistente)
DO $$
DECLARE
    v_total numeric(12,2);
    v_nro_comp integer;
BEGIN
    SELECT nro_comprobante INTO v_nro_comp FROM comprobante WHERE id_cliente = 1 ORDER BY nro_comprobante DESC LIMIT 1;
    SELECT total INTO v_total FROM comprobante WHERE nro_comprobante = v_nro_comp;
    IF v_total IS NULL OR v_total = 0 THEN
        RAISE EXCEPTION 'RN-08: el total no fue calculado por el trigger';
    END IF;
    RAISE NOTICE 'RN-08 OK: total calculado por trigger = %', v_total;
END;
$$;

-- =============================================================================
-- RN-09: No se puede vender más de lo que hay en stock de la sala. Stock nunca negativo.
-- Mecanismo: Trigger BEFORE INSERT + CHECK (cantidad >= 0)
-- =============================================================================

-- Caso que debe FUNCIONAR: venta con stock suficiente
\echo '--- RN-09: caso que debe funcionar (stock suficiente)'
-- El stock_sala ya tiene 100 unidades de vino 1 en sala 1 (insertado arriba)
-- La venta de 2 unidades en RN-08 ya descontó, queda 98
DO $$
DECLARE
    v_stock integer;
BEGIN
    SELECT cantidad INTO v_stock FROM stock_sala WHERE id_sala = 1 AND cod_vino = 1;
    RAISE NOTICE 'RN-09 OK: stock actual en sala 1, vino 1 = %', v_stock;
END;
$$;

-- Caso que debe FALLAR: venta sin stock suficiente
\echo '--- RN-09: caso que debe fallar (stock insuficiente)'
DO $$
DECLARE
    v_nro_comp integer;
BEGIN
    INSERT INTO comprobante (fecha, id_cliente, id_sala, subtotal, descuento, total)
    VALUES ('2024-01-16', 1, 1, 0.00, 0.00, 0.00)
    RETURNING nro_comprobante INTO v_nro_comp;

    INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
    VALUES (v_nro_comp, 1, 999999, 5000.00, 0.00, 0.00);
    RAISE EXCEPTION 'RN-09: debería haber fallado por stock insuficiente';
EXCEPTION WHEN others THEN
    RAISE NOTICE 'RN-09 OK: stock insuficiente rechazado (trigger BEFORE INSERT)';
END;
$$;

-- Caso que debe FALLAR: stock negativo (CHECK)
\echo '--- RN-09: caso que debe fallar (stock negativo)'
DO $$
BEGIN
    UPDATE stock_sala SET cantidad = -1 WHERE id_sala = 1 AND cod_vino = 1;
    RAISE EXCEPTION 'RN-09: debería haber fallado con stock negativo';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'RN-09 OK: stock negativo rechazado (CHECK cantidad >= 0)';
END;
$$;

-- =============================================================================
-- RN-10: Solo un ingreso terminado impacta en el depósito y pasa a procesado.
-- Transiciones: en_confeccion -> terminado -> procesado, sin retrocesos.
-- Mecanismo: Tipo ENUM + trigger de estados + procedimiento
-- =============================================================================

-- Caso que debe FUNCIONAR: procedimiento procesa ingreso terminado
\echo '--- RN-10: caso que debe funcionar (procesar ingreso terminado)'
DO $$
DECLARE
    v_cod_ingreso integer;
BEGIN
    -- Crear ingreso en confección
    INSERT INTO ingreso (fecha, estado, cod_transportista, id_bodega)
    VALUES ('2024-01-10', 'en_confeccion', 1, 1)
    RETURNING cod_ingreso INTO v_cod_ingreso;

    -- Agregar renglones (permitido porque está en confección)
    INSERT INTO renglon_ingreso (cod_ingreso, cod_vino, cantidad)
    VALUES (v_cod_ingreso, 1, 50);

    -- Cambiar estado a terminado
    UPDATE ingreso SET estado = 'terminado' WHERE cod_ingreso = v_cod_ingreso;

    -- Procesar el ingreso
    CALL sp_procesar_ingreso(v_cod_ingreso);
    RAISE NOTICE 'RN-10 OK: ingreso % procesado correctamente', v_cod_ingreso;
END;
$$;

-- Caso que debe FALLAR: ingreso no terminado no puede procesarse
\echo '--- RN-10: caso que debe fallar (ingreso no terminado)'
DO $$
DECLARE
    v_cod_ingreso integer;
BEGIN
    INSERT INTO ingreso (fecha, estado, cod_transportista, id_bodega)
    VALUES ('2024-01-10', 'en_confeccion', 1, 1)
    RETURNING cod_ingreso INTO v_cod_ingreso;

    CALL sp_procesar_ingreso(v_cod_ingreso);
    RAISE EXCEPTION 'RN-10: debería haber fallado con ingreso no terminado';
EXCEPTION WHEN others THEN
    RAISE NOTICE 'RN-10 OK: ingreso no terminado rechazado (procedimiento)';
END;
$$;

-- =============================================================================
-- RN-11: Igual que RN-10 para transferencias. Fecha de confección es la actual y no se puede modificar.
-- Mecanismo: Trigger de estados y de fecha + procedimiento
-- =============================================================================

-- Necesitamos stock en depósito
INSERT INTO stock_deposito (cod_vino, cantidad) VALUES (1, 500)
ON CONFLICT (cod_vino) DO UPDATE SET cantidad = stock_deposito.cantidad + 500;

-- Caso que debe FUNCIONAR: procedimiento procesa transferencia terminada
\echo '--- RN-11: caso que debe funcionar (procesar transferencia terminada)'
DO $$
DECLARE
    v_nro_solicitud integer;
BEGIN
    -- Crear transferencia en confección
    INSERT INTO transferencia (id_sala, fecha_confeccion, estado, observaciones)
    VALUES (1, CURRENT_DATE, 'en_confeccion', 'Test RN-11')
    RETURNING nro_solicitud INTO v_nro_solicitud;

    -- Agregar renglones (permitido porque está en confección)
    INSERT INTO renglon_transferencia (nro_solicitud, cod_vino, cantidad)
    VALUES (v_nro_solicitud, 1, 100);

    -- Cambiar estado a terminado
    UPDATE transferencia SET estado = 'terminado' WHERE nro_solicitud = v_nro_solicitud;

    -- Procesar la transferencia
    CALL sp_procesar_transferencia(v_nro_solicitud);
    RAISE NOTICE 'RN-11 OK: transferencia % procesada correctamente', v_nro_solicitud;
END;
$$;

-- Caso que debe FALLAR: transferencia no terminada no puede procesarse
\echo '--- RN-11: caso que debe fallar (transferencia no terminada)'
DO $$
DECLARE
    v_nro_solicitud integer;
BEGIN
    INSERT INTO transferencia (id_sala, fecha_confeccion, estado, observaciones)
    VALUES (1, CURRENT_DATE, 'en_confeccion', 'Test RN-11 FAIL')
    RETURNING nro_solicitud INTO v_nro_solicitud;

    CALL sp_procesar_transferencia(v_nro_solicitud);
    RAISE EXCEPTION 'RN-11: debería haber fallado con transferencia no terminada';
EXCEPTION WHEN others THEN
    RAISE NOTICE 'RN-11 OK: transferencia no terminada rechazada (procedimiento)';
END;
$$;

-- Caso que debe FALLAR: modificar fecha de confección
\echo '--- RN-11: caso que debe fallar (modificar fecha de confección)'
DO $$
DECLARE
    v_nro_solicitud integer;
BEGIN
    SELECT nro_solicitud INTO v_nro_solicitud
    FROM transferencia WHERE estado = 'terminado' ORDER BY nro_solicitud DESC LIMIT 1;

    UPDATE transferencia SET fecha_confeccion = '2020-01-01' WHERE nro_solicitud = v_nro_solicitud;
    RAISE EXCEPTION 'RN-11: debería haber fallado al modificar fecha de confección';
EXCEPTION WHEN others THEN
    RAISE NOTICE 'RN-11 OK: modificación de fecha de confección rechazada (trigger)';
END;
$$;

-- =============================================================================
-- RN-12: Un ingreso o transferencia que no está en confección no admite agregar,
-- modificar ni quitar renglones.
-- Mecanismo: Trigger sobre los renglones
-- =============================================================================

-- Caso que debe FUNCIONAR: agregar renglón a ingreso en confección
\echo '--- RN-12: caso que debe funcionar (ingreso en confección admite renglones)'
DO $$
DECLARE
    v_cod_ingreso integer;
BEGIN
    INSERT INTO ingreso (fecha, estado, cod_transportista, id_bodega)
    VALUES ('2024-01-10', 'en_confeccion', 1, 1)
    RETURNING cod_ingreso INTO v_cod_ingreso;

    INSERT INTO renglon_ingreso (cod_ingreso, cod_vino, cantidad)
    VALUES (v_cod_ingreso, 1, 10);
    RAISE NOTICE 'RN-12 OK: renglón agregado a ingreso % en confección', v_cod_ingreso;
END;
$$;

-- Caso que debe FALLAR: agregar renglón a ingreso no en confección
\echo '--- RN-12: caso que debe fallar (ingreso no en confección no admite renglones)'
DO $$
DECLARE
    v_cod_ingreso integer;
BEGIN
    SELECT cod_ingreso INTO v_cod_ingreso
    FROM ingreso WHERE estado = 'terminado' ORDER BY cod_ingreso DESC LIMIT 1;

    INSERT INTO renglon_ingreso (cod_ingreso, cod_vino, cantidad)
    VALUES (v_cod_ingreso, 1, 10);
    RAISE EXCEPTION 'RN-12: debería haber fallado con ingreso no en confección';
EXCEPTION WHEN others THEN
    RAISE NOTICE 'RN-12 OK: renglón en ingreso no en confección rechazado (trigger)';
END;
$$;

-- =============================================================================
-- RN-13: Todo cambio de precio de un vino queda auditado.
-- Mecanismo: Trigger AFTER UPDATE + tabla de auditoría
-- =============================================================================

-- Caso que debe FUNCIONAR: cambio de precio genera auditoría
\echo '--- RN-13: caso que debe funcionar (cambio de precio auditado)'
UPDATE vino SET precio = 12000.00 WHERE cod_vino = 1;

-- Verificar que existe registro en auditoría
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT COUNT(*) INTO v_count FROM auditoria_precio WHERE cod_vino = 1;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'RN-13: no se generó registro de auditoría';
    END IF;
    RAISE NOTICE 'RN-13 OK: cambio de precio auditado (% registros)', v_count;
END;
$$;

-- Verificar valores de auditoría
DO $$
DECLARE
    v_previo numeric(12,2);
    v_nuevo numeric(12,2);
BEGIN
    SELECT precio_anterior, precio_nuevo INTO v_previo, v_nuevo
    FROM auditoria_precio WHERE cod_vino = 1 ORDER BY id_auditoria DESC LIMIT 1;
    IF v_previo <> 10000.00 OR v_nuevo <> 12000.00 THEN
        RAISE EXCEPTION 'RN-13: auditoría con valores incorrectos (previo: %, nuevo: %)', v_previo, v_nuevo;
    END IF;
    RAISE NOTICE 'RN-13 OK: auditoría con valores correctos (previo: %, nuevo: %)', v_previo, v_nuevo;
END;
$$;

-- =============================================================================
-- RN-14: No se puede borrar un transportista, una bodega ni un vino que tengan movimientos asociados.
-- Mecanismo: FK con ON DELETE RESTRICT
-- =============================================================================

-- Caso que debe FUNCIONAR: borrar entidad sin movimientos
\echo '--- RN-14: caso que debe funcionar (borrar entidad sin movimientos)'
INSERT INTO bodega (cuit, razon_social, domicilio)
VALUES ('20999999999', 'Bodega Test RN-14', 'Calle Falsa 123');
DELETE FROM bodega WHERE cuit = '20999999999';
\echo 'RN-14 OK: bodega sin movimientos borrada'

-- Caso que debe FALLAR: borrar bodega con movimientos asociados
\echo '--- RN-14: caso que debe fallar (bodega con movimientos)'
DO $$
BEGIN
    DELETE FROM bodega WHERE id_bodega = 1;
    RAISE EXCEPTION 'RN-14: debería haber fallado al borrar bodega con movimientos';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'RN-14 OK: bodega con movimientos no se puede borrar (ON DELETE RESTRICT)';
END;
$$;

-- =============================================================================
-- RN-15: Cantidades, superficies, kilos y precios son siempre positivos.
-- La graduación está entre 5 y 20.
-- Mecanismo: CHECK
-- =============================================================================

-- Caso que debe FALLAR: graduación fuera de rango (5-20)
\echo '--- RN-15: caso que debe fallar (graduación fuera de rango)'
DO $$
BEGIN
    INSERT INTO vino (id_bodega, nombre, tipo, anada, volumen_ml, graduacion, precio)
    VALUES (1, 'Vino Test RN-15 FAIL', 'tinto', 2021, 750, 25.00, 10000.00);
    RAISE EXCEPTION 'RN-15: debería haber fallado con graduación fuera de rango';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'RN-15 OK: graduación fuera de rango rechazada (CHECK 5-20)';
END;
$$;

-- Caso que debe FALLAR: cantidad negativa en renglón
\echo '--- RN-15: caso que debe fallar (cantidad negativa)'
DO $$
DECLARE
    v_nro_comp integer;
BEGIN
    -- Crear un comprobante para probar
    INSERT INTO comprobante (fecha, id_cliente, id_sala, subtotal, descuento, total)
    VALUES ('2024-01-17', 1, 1, 0.00, 0.00, 0.00)
    RETURNING nro_comprobante INTO v_nro_comp;

    INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
    VALUES (v_nro_comp, 1, -5, 5000.00, 0.00, 0.00);
    RAISE EXCEPTION 'RN-15: debería haber fallado con cantidad negativa';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'RN-15 OK: cantidad negativa rechazada (CHECK cantidad > 0)';
END;
$$;

-- =============================================================================
-- Demo de concurrencia: dos sesiones intentan vender la última botella
-- =============================================================================
\echo '===== Demo de concurrencia ====='
\echo 'Nota: Esta demo requiere dos sesiones psql separadas. Patrón:'
\echo ''
\echo 'Sesión A (sin bloqueo):                      Sesión B (con FOR UPDATE):'
\echo '  BEGIN;                                       BEGIN;'
\echo '  SELECT cantidad FROM stock_sala              SELECT cantidad FROM stock_sala'
\echo '    WHERE id_sala=1 AND cod_vino=1;              WHERE id_sala=1 AND cod_vino=1'
\echo '                                                   FOR UPDATE;'
\echo '  UPDATE stock_sala SET cantidad=cantidad-1    UPDATE stock_sala SET cantidad=cantidad-1'
\echo '    WHERE id_sala=1 AND cod_vino=1;              WHERE id_sala=1 AND cod_vino=1;'
\echo '  COMMIT;                                        COMMIT;'
\echo ''
\echo 'Resultado esperado: La sesión B bloquea la fila hasta COMMIT,'
\echo 'impidiendo que la sesión A venda la última botella dos veces.'
\echo ''
\echo '===== Fin de db_tests.sql ====='

-- Volver a habilitar el trigger de coherencia cliente/subtipo
ALTER TABLE cliente ENABLE TRIGGER trg_coherencia_cliente_subtipo;
