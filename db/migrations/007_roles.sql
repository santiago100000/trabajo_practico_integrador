-- =============================================================================
-- 007_roles.sql
-- Etapa: 2 - Integridad y lógica en la base de datos
-- Propósito: Crear 3 roles, revocar privilegios públicos y grants mínimos.
-- Las contraseñas se inyectan vía sed en migrate_entrypoint.sh desde variables
-- de entorno (OWNER_DB_PASSWORD, APP_DB_PASSWORD, RO_DB_PASSWORD), nunca escritas
-- en este archivo.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Crear roles (contraseñas inyectadas via @OWNER_PASSWORD@, @APP_PASSWORD@,
--    @RO_PASSWORD@; nunca escritas en este archivo)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bodegas_owner') THEN
        CREATE ROLE bodegas_owner LOGIN PASSWORD '@OWNER_PASSWORD@';
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_rw') THEN
        CREATE ROLE app_rw LOGIN PASSWORD '@APP_PASSWORD@';
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'reporte_ro') THEN
        CREATE ROLE reporte_ro LOGIN PASSWORD '@RO_PASSWORD@';
    END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- 2. Otorgar privilegios sobre el esquema public al owner (administrador)
-- ---------------------------------------------------------------------------
GRANT ALL ON SCHEMA public TO bodegas_owner;

-- ---------------------------------------------------------------------------
-- 3. REVOKE de privilegios públicos (nunca dejar acceso por defecto a PUBLIC)
-- ---------------------------------------------------------------------------
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL PROCEDURES IN SCHEMA public FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 4. GRANT mínimos para bodegas_owner (propietario: todo en el esquema)
-- ---------------------------------------------------------------------------
GRANT ALL ON ALL TABLES IN SCHEMA public TO bodegas_owner;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO bodegas_owner;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO bodegas_owner;
GRANT ALL ON ALL PROCEDURES IN SCHEMA public TO bodegas_owner;

-- ---------------------------------------------------------------------------
-- 5. GRANT mínimos para app_rw (API: lectura/escritura en tablas de negocio,
--    uso de secuencias, ejecución de funciones y procedimientos)
-- ---------------------------------------------------------------------------

-- Tablas de catálogo y negocio: SELECT, INSERT, UPDATE, DELETE
GRANT SELECT, INSERT, UPDATE, DELETE ON
    provincia, departamento, localidad,
    sala_venta, empleado,
    bodega,
    finca, cepa, parcela, lote_uva, analisis_calidad,
    vino, vino_cepa, maridaje, vino_maridaje, auditoria_precio,
    stock_sala, stock_deposito,
    transportista, transportista_localidad,
    ingreso, renglon_ingreso,
    transferencia, renglon_transferencia,
    cliente, socio, distribuidor, exportador, permiso_exportacion,
    comprobante, renglon_comprobante
TO app_rw;

-- Secuencias (para INSERT con identity/serial)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_rw;

-- Funciones y procedimientos: EXECUTE
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO app_rw;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA public TO app_rw;

-- ---------------------------------------------------------------------------
-- 6. GRANT mínimos para reporte_ro (solo lectura para reportes)
-- ---------------------------------------------------------------------------

-- Tablas: solo SELECT
GRANT SELECT ON
    provincia, departamento, localidad,
    sala_venta, empleado,
    bodega,
    finca, cepa, parcela, lote_uva, analisis_calidad,
    vino, vino_cepa, maridaje, vino_maridaje, auditoria_precio,
    stock_sala, stock_deposito,
    transportista, transportista_localidad,
    ingreso, renglon_ingreso,
    transferencia, renglon_transferencia,
    cliente, socio, distribuidor, exportador, permiso_exportacion,
    comprobante, renglon_comprobante
TO reporte_ro;

-- Vistas: solo SELECT
GRANT SELECT ON mv_stock_total_por_vino TO reporte_ro;
GRANT SELECT ON vw_ventas_mensuales_por_sala TO reporte_ro;
GRANT SELECT ON vw_documentos_pendientes TO reporte_ro;

-- No otorgar USAGE en secuencias a reporte_ro (solo lectura)
-- No otorgar EXECUTE en funciones/procedimientos a reporte_ro

-- ---------------------------------------------------------------------------
-- 7. Default privileges para futuras tablas (buena práctica)
-- ---------------------------------------------------------------------------
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_rw;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO reporte_ro;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT EXECUTE ON FUNCTIONS TO app_rw;

-- =============================================================================
-- Resumen de roles implementados:
--   1. bodegas_owner  → ALL en esquema, tablas, secuencias, funciones, procedimientos
--   2. app_rw         → SELECT/INSERT/UPDATE/DELETE en tablas, USAGE secuencias,
--                       EXECUTE funciones/procedimientos (API usa este rol)
--   3. reporte_ro     → SELECT en tablas y vistas (solo lectura para reportes)
-- Contraseñas: inyectadas via @OWNER_PASSWORD@, @APP_PASSWORD@, @RO_PASSWORD@
-- Nunca escritas en este archivo. ✅
-- =============================================================================
