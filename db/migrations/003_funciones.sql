-- =============================================================================
-- 003_funciones.sql
-- Etapa: 2 - Integridad y lógica en la base de datos
-- Propósito: Crear funciones de base de datos con propósito, parámetros y volatilidad.
-- Cada función incluye comentario con propósito, parámetros y volatilidad (STABLE/IMMUTABLE).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- fn_total_comprobante
-- Propósito: Calcula el total de un comprobante sumando los subtotales de sus
--            renglones. Se usa para mantener la consistencia del comprobante
--            (RN-08: el total no se carga a mano).
-- Parámetros: p_nro_comprobante (integer) - número de comprobante
-- Retorna: numeric(12,2) - total del comprobante
-- Volatilidad: STABLE (solo lee tablas, resultado determinista para datos fijos)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_total_comprobante(p_nro_comprobante integer)
RETURNS numeric(12,2) AS $$
DECLARE
    v_total numeric(12,2);
BEGIN
    SELECT COALESCE(SUM(subtotal), 0)
    INTO v_total
    FROM renglon_comprobante
    WHERE nro_comprobante = p_nro_comprobante;

    RETURN v_total;
END;
$$ LANGUAGE plpgsql STABLE;

-- ---------------------------------------------------------------------------
-- fn_stock_sala
-- Propósito: Devuelve la cantidad en stock de un vino determinado en una sala
--            de venta determinada. Se usa para validar stock antes de vender
--            (RN-09: no se puede vender más de lo que hay).
-- Parámetros: p_id_sala (integer) - identificador de sala
--             p_cod_vino (integer) - código de vino
-- Retorna: integer - cantidad en stock (0 si no hay registro)
-- Volatilidad: STABLE (solo lee tablas)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_stock_sala(p_id_sala integer, p_cod_vino integer)
RETURNS integer AS $$
DECLARE
    v_cantidad integer;
BEGIN
    SELECT COALESCE(cantidad, 0)
    INTO v_cantidad
    FROM stock_sala
    WHERE id_sala = p_id_sala
      AND cod_vino = p_cod_vino;

    RETURN v_cantidad;
END;
$$ LANGUAGE plpgsql STABLE;

-- ---------------------------------------------------------------------------
-- fn_descuento_cliente
-- Propósito: Devuelve el porcentaje de descuento que corresponde a un tipo de
--            cliente según la regla de negocio RN-06:
--              socio   -> 10%
--              distribuidor -> 20%
--              exportador -> 30%
-- Parámetros: p_tipo_cliente (tipo_cliente) - tipo de cliente (enumerado)
-- Retorna: numeric(5,2) - porcentaje de descuento
-- Volatilidad: IMMUTABLE (siempre el mismo resultado para el mismo tipo,
--              no depende de datos de tabla ni de fecha/hora)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_descuento_cliente(p_tipo_cliente tipo_cliente)
RETURNS numeric(5,2) AS $$
BEGIN
    CASE p_tipo_cliente
        WHEN 'socio' THEN
            RETURN 10.00;
        WHEN 'distribuidor' THEN
            RETURN 20.00;
        WHEN 'exportador' THEN
            RETURN 30.00;
        ELSE
            RETURN 0.00;
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ---------------------------------------------------------------------------
-- fn_antiguedad_anios
-- Propósito: Calcula los años completos de antigüedad de un empleado a partir
--            de su fecha de ingreso laboral. Se usa en consultas como U2
--            (aumentar salario a empleados con más de 5 años).
-- Parámetros: p_fecha_ingreso (date) - fecha de ingreso del empleado
-- Retorna: integer - años de antigüedad
-- Volatilidad: STABLE (usa CURRENT_DATE, determinista dentro de una transacción)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_antiguedad_anios(p_fecha_ingreso date)
RETURNS integer AS $$
BEGIN
    RETURN EXTRACT(YEAR FROM AGE(CURRENT_DATE, p_fecha_ingreso))::integer;
END;
$$ LANGUAGE plpgsql STABLE;

-- =============================================================================
-- Fin de 003_funciones.sql
-- =============================================================================
