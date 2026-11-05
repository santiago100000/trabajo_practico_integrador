-- =============================================================================
-- 005_triggers.sql
-- Etapa: 2 - Integridad y lógica en la base de datos
-- Propósito: Crear triggers (BEFORE, AFTER, constraint diferido) que protejan las reglas RN.
-- Mínimos exigidos: ≥6 triggers, ≥1 BEFORE, ≥1 AFTER, ≥1 constraint trigger diferido.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Función auxiliar para el constraint trigger de suma de porcentajes (RN-05)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_porcentajes_vino_cepa()
RETURNS trigger AS $$
DECLARE
    v_suma numeric(5,2);
BEGIN
    SELECT COALESCE(SUM(porcentaje), 0)
    INTO v_suma
    FROM vino_cepa
    WHERE cod_vino = NEW.cod_vino;

    IF v_suma <> 100 THEN
        RAISE EXCEPTION 'La suma de porcentajes de corte del vino % es %. Debe ser exactamente 100 (RN-05).',
            NEW.cod_vino, v_suma
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- Trigger 1 (CONSTRAINT, DEFERRABLE): Suma de porcentajes de corte = 100 (RN-05)
-- Se ejecuta al finalizar la transacción para permitir inserciones parciales.
-- ---------------------------------------------------------------------------
CREATE CONSTRAINT TRIGGER trg_chk_porcentajes_vino_cepa
    AFTER INSERT OR UPDATE OR DELETE ON vino_cepa
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION fn_check_porcentajes_vino_cepa();

-- ---------------------------------------------------------------------------
-- Trigger 2 (BEFORE INSERT): Validación de stock en venta (RN-09)
-- Rechaza la venta si no hay stock suficiente en la sala.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_validar_stock_venta()
RETURNS trigger AS $$
DECLARE
    v_stock integer;
    v_id_sala integer;
BEGIN
    -- Obtener el id_sala del comprobante padre
    SELECT id_sala INTO v_id_sala
    FROM comprobante
    WHERE nro_comprobante = NEW.nro_comprobante;

    -- Obtener stock actual del vino en esa sala
    SELECT cantidad INTO v_stock
    FROM stock_sala
    WHERE id_sala = v_id_sala
      AND cod_vino = NEW.cod_vino;

    IF COALESCE(v_stock, 0) < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente en la sala % para el vino % (solicitado: %, disponible: %). No se puede vender más de lo que hay en stock (RN-09).',
            v_id_sala, NEW.cod_vino, NEW.cantidad, COALESCE(v_stock, 0)
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_stock_venta
    BEFORE INSERT ON renglon_comprobante
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_validar_stock_venta();

-- ---------------------------------------------------------------------------
-- Trigger 3 (AFTER INSERT): Descuento de stock y cálculo de totales (RN-08, RN-09)
-- Actualiza el stock de la sala y los importes del comprobante.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_descontar_stock_y_calcular_totales()
RETURNS trigger AS $$
DECLARE
    v_id_sala integer;
    v_subtotal_renglon numeric(12,2);
    v_descuento_importe numeric(12,2);
BEGIN
    -- Obtener id_sala del comprobante
    SELECT id_sala INTO v_id_sala
    FROM comprobante
    WHERE nro_comprobante = NEW.nro_comprobante;

    -- Descontar stock de la sala
    UPDATE stock_sala
    SET cantidad = cantidad - NEW.cantidad
    WHERE id_sala = v_id_sala
      AND cod_vino = NEW.cod_vino;

    -- Calcular subtotal del renglón: cantidad * precio_unitario * (1 - descuento/100)
    v_subtotal_renglon := NEW.cantidad * NEW.precio_unitario * (1 - NEW.descuento_aplicado / 100);

    -- Actualizar el subtotal del renglón si es diferente
    IF v_subtotal_renglon <> NEW.subtotal THEN
        UPDATE renglon_comprobante
        SET subtotal = v_subtotal_renglon
        WHERE nro_comprobante = NEW.nro_comprobante
          AND cod_vino = NEW.cod_vino;
    END IF;

    -- Recalcular totales del comprobante (fn_total_comprobante)
    UPDATE comprobante
    SET subtotal = fn_total_comprobante(nro_comprobante),
        total = fn_total_comprobante(nro_comprobante)
    WHERE nro_comprobante = NEW.nro_comprobante;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_descontar_stock_y_calcular_totales
    AFTER INSERT ON renglon_comprobante
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_descontar_stock_y_calcular_totales();

-- ---------------------------------------------------------------------------
-- Trigger 4 (BEFORE INSERT/UPDATE/DELETE): Bloqueo de renglones de ingreso y transferencia (RN-12)
-- No admite cambios si el documento no está en confección.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_bloquear_renglones_ingreso()
RETURNS trigger AS $$
DECLARE
    v_estado text;
BEGIN
    SELECT estado INTO v_estado
    FROM ingreso
    WHERE cod_ingreso = NEW.cod_ingreso;

    IF v_estado <> 'en_confeccion' THEN
        RAISE EXCEPTION 'No se pueden modificar renglones de un ingreso que no está en confección (estado actual: %) (RN-12).', v_estado
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bloquear_renglones_ingreso
    BEFORE INSERT OR UPDATE OR DELETE ON renglon_ingreso
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_bloquear_renglones_ingreso();

CREATE OR REPLACE FUNCTION fn_trg_bloquear_renglones_transferencia()
RETURNS trigger AS $$
DECLARE
    v_estado text;
BEGIN
    SELECT estado INTO v_estado
    FROM transferencia
    WHERE nro_solicitud = NEW.nro_solicitud;

    IF v_estado <> 'en_confeccion' THEN
        RAISE EXCEPTION 'No se pueden modificar renglones de una transferencia que no está en confección (estado actual: %) (RN-12).', v_estado
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bloquear_renglones_transferencia
    BEFORE INSERT OR UPDATE OR DELETE ON renglon_transferencia
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_bloquear_renglones_transferencia();

-- ---------------------------------------------------------------------------
-- Trigger 5 (BEFORE INSERT/UPDATE): Fecha de confección de transferencia (RN-11)
-- Fuerza la fecha actual al insertar y prohíbe modificarla.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_fecha_confeccion_transferencia()
RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.fecha_confeccion := CURRENT_DATE;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.fecha_confeccion <> OLD.fecha_confeccion THEN
            RAISE EXCEPTION 'La fecha de confección de una transferencia no se puede modificar (RN-11).'
                USING ERRCODE = 'P0001';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_fecha_confeccion_transferencia
    BEFORE INSERT OR UPDATE ON transferencia
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_fecha_confeccion_transferencia();

-- ---------------------------------------------------------------------------
-- Trigger 6 (AFTER UPDATE): Auditoría de precio de vino (RN-13)
-- Registra precio anterior, precio nuevo, fecha y hora, usuario.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_auditoria_precio_vino()
RETURNS trigger AS $$
BEGIN
    IF OLD.precio <> NEW.precio THEN
        INSERT INTO auditoria_precio (cod_vino, precio_anterior, precio_nuevo, fecha_hora, usuario)
        VALUES (OLD.cod_vino, OLD.precio, NEW.precio, CURRENT_TIMESTAMP, CURRENT_USER);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditoria_precio_vino
    AFTER UPDATE ON vino
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_auditoria_precio_vino();

-- ---------------------------------------------------------------------------
-- Trigger 7 (AFTER INSERT/UPDATE): Coherencia cliente.tipo_cliente vs tabla de subtipo
-- Asegura que el discriminador coincida con la existencia en la tabla de subtipo.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_coherencia_cliente_subtipo()
RETURNS trigger AS $$
DECLARE
    v_tipo text;
BEGIN
    SELECT tipo_cliente INTO v_tipo
    FROM cliente
    WHERE id_cliente = NEW.id_cliente;

    CASE v_tipo
        WHEN 'socio' THEN
            IF NOT EXISTS (SELECT 1 FROM socio WHERE id_cliente = NEW.id_cliente) THEN
                RAISE EXCEPTION 'El cliente % es tipo socio pero no existe en la tabla socio.', NEW.id_cliente
                    USING ERRCODE = 'P0001';
            END IF;
        WHEN 'distribuidor' THEN
            IF NOT EXISTS (SELECT 1 FROM distribuidor WHERE id_cliente = NEW.id_cliente) THEN
                RAISE EXCEPTION 'El cliente % es tipo distribuidor pero no existe en la tabla distribuidor.', NEW.id_cliente
                    USING ERRCODE = 'P0001';
            END IF;
        WHEN 'exportador' THEN
            IF NOT EXISTS (SELECT 1 FROM exportador WHERE id_cliente = NEW.id_cliente) THEN
                RAISE EXCEPTION 'El cliente % es tipo exportador pero no existe en la tabla exportador.', NEW.id_cliente
                    USING ERRCODE = 'P0001';
            END IF;
        ELSE
            RAISE EXCEPTION 'Tipo de cliente desconocido: %', v_tipo
                USING ERRCODE = 'P0001';
    END CASE;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_coherencia_cliente_subtipo
    AFTER INSERT OR UPDATE ON cliente
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_coherencia_cliente_subtipo();

-- =============================================================================
-- Resumen de triggers implementados:
--   1. trg_chk_porcentajes_vino_cepa      → CONSTRAINT DEFERRABLE  → RN-05
--   2. trg_validar_stock_venta            → BEFORE INSERT          → RN-09
--   3. trg_descontar_stock_y_calcular_totales → AFTER INSERT       → RN-08, RN-09
--   4. trg_bloquear_renglones_ingreso     → BEFORE (I/U/D)         → RN-12
--   5. trg_bloquear_renglones_transferencia → BEFORE (I/U/D)      → RN-12
--   6. trg_fecha_confeccion_transferencia → BEFORE (I/U)           → RN-11
--   7. trg_auditoria_precio_vino          → AFTER UPDATE           → RN-13
--   8. trg_coherencia_cliente_subtipo     → AFTER (I/U)            → Jerarquía cliente
-- =============================================================================
