-- =============================================================================
-- 004_procedimientos.sql
-- Etapa: 2 - Integridad y lógica en la base de datos
-- Propósito: Crear procedimientos transaccionales con FOR UPDATE y todo o nada.
-- Cada procedimiento valida estado, bloquea filas necesarias, modifica stocks
-- y cambia estados. Si algo falla, todo se revierte (ROLLBACK automático del CALL).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- sp_procesar_ingreso
-- Propósito: Procesa un ingreso de vinos al depósito central.
--            Flujo: el ingreso debe estar en estado 'terminado'. Al procesar:
--              1. Valida que el estado sea 'terminado' (RN-10)
--              2. Bloquea los renglones con FOR UPDATE
--              3. Suma las cantidades al stock_deposito
--              4. Cambia el estado a 'procesado' (RN-10)
--            Todo en una transacción: si algo falla, se revierte todo.
-- Parámetros: p_cod_ingreso (integer) - código de ingreso
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_procesar_ingreso(p_cod_ingreso integer)
LANGUAGE plpgsql AS $$
DECLARE
    v_estado text;
    v_cod_vino integer;
    v_cantidad integer;
BEGIN
    -- 1. Validar que el ingreso exista y esté en estado 'terminado'
    SELECT estado INTO v_estado
    FROM ingreso
    WHERE cod_ingreso = p_cod_ingreso
    FOR UPDATE;

    IF v_estado IS NULL THEN
        RAISE EXCEPTION 'El ingreso % no existe', p_cod_ingreso
            USING ERRCODE = 'P0001';
    END IF;

    IF v_estado <> 'terminado' THEN
        RAISE EXCEPTION 'El ingreso % no está en estado terminado (estado actual: %). Solo un ingreso terminado puede impactar en el stock del depósito (RN-10).', p_cod_ingreso, v_estado
            USING ERRCODE = 'P0001';
    END IF;

    -- 2. Bloquear y procesar cada renglón: sumar al stock_deposito
    FOR v_cod_vino, v_cantidad IN
        SELECT cod_vino, cantidad
        FROM renglon_ingreso
        WHERE cod_ingreso = p_cod_ingreso
        FOR UPDATE
    LOOP
        -- Insertar o actualizar stock_deposito
        INSERT INTO stock_deposito (cod_vino, cantidad)
        VALUES (v_cod_vino, v_cantidad)
        ON CONFLICT (cod_vino)
        DO UPDATE SET cantidad = stock_deposito.cantidad + EXCLUDED.cantidad;
    END LOOP;

    -- 3. Cambiar estado a 'procesado' (transición final, no retrocede)
    UPDATE ingreso
    SET estado = 'procesado'
    WHERE cod_ingreso = p_cod_ingreso;
END;
$$;

-- ---------------------------------------------------------------------------
-- sp_procesar_transferencia
-- Propósito: Procesa una transferencia de vinos del depósito central a una sala.
--            Flujo: la transferencia debe estar en estado 'terminado'. Al procesar:
--              1. Valida que el estado sea 'terminado' (RN-11)
--              2. Bloquea los renglones con FOR UPDATE
--              3. Verifica stock suficiente en depósito para cada vino
--              4. Descuenta del depósito y suma al stock de la sala
--              5. Cambia el estado a 'procesado' (RN-11)
--            Todo en una transacción: si algo falla, se revierte todo.
-- Parámetros: p_nro_solicitud (integer) - número de solicitud de transferencia
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_procesar_transferencia(p_nro_solicitud integer)
LANGUAGE plpgsql AS $$
DECLARE
    v_estado text;
    v_id_sala integer;
    v_stock_deposito integer;
    v_cod_vino integer;
    v_cantidad integer;
BEGIN
    -- 1. Validar que la transferencia exista y esté en estado 'terminado'
    SELECT estado, id_sala INTO v_estado, v_id_sala
    FROM transferencia
    WHERE nro_solicitud = p_nro_solicitud
    FOR UPDATE;

    IF v_estado IS NULL THEN
        RAISE EXCEPTION 'La transferencia % no existe', p_nro_solicitud
            USING ERRCODE = 'P0001';
    END IF;

    IF v_estado <> 'terminado' THEN
        RAISE EXCEPTION 'La transferencia % no está en estado terminado (estado actual: %). Solo una transferencia terminada puede impactar en el stock (RN-11).', p_nro_solicitud, v_estado
            USING ERRCODE = 'P0001';
    END IF;

    -- 2. Bloquear y procesar cada renglón: verificar stock y mover
    FOR v_cod_vino, v_cantidad IN
        SELECT cod_vino, cantidad
        FROM renglon_transferencia
        WHERE nro_solicitud = p_nro_solicitud
        FOR UPDATE
    LOOP
        -- Verificar stock suficiente en depósito (RN-11)
        SELECT cantidad INTO v_stock_deposito
        FROM stock_deposito
        WHERE cod_vino = v_cod_vino
        FOR UPDATE;

        IF v_stock_deposito IS NULL OR v_stock_deposito < v_cantidad THEN
            RAISE EXCEPTION 'Stock insuficiente en depósito para el vino % (solicitado: %, disponible: %). No puede procesarse la transferencia (RN-11).', v_cod_vino, v_cantidad, COALESCE(v_stock_deposito, 0)
                USING ERRCODE = 'P0001';
        END IF;

        -- Descontar del depósito central
        UPDATE stock_deposito
        SET cantidad = cantidad - v_cantidad
        WHERE cod_vino = v_cod_vino;

        -- Sumar al stock de la sala (insertar o actualizar)
        INSERT INTO stock_sala (id_sala, cod_vino, cantidad)
        VALUES (v_id_sala, v_cod_vino, v_cantidad)
        ON CONFLICT (id_sala, cod_vino)
        DO UPDATE SET cantidad = stock_sala.cantidad + EXCLUDED.cantidad;
    END LOOP;

    -- 3. Cambiar estado a 'procesado' (transición final, no retrocede)
    UPDATE transferencia
    SET estado = 'procesado'
    WHERE nro_solicitud = p_nro_solicitud;
END;
$$;

-- =============================================================================
-- Fin de 004_procedimientos.sql
-- =============================================================================
