-- =============================================================================
-- 002_constraints.sql
-- Etapa: 2 - Integridad y lógica en la base de datos
-- Propósito: Agregar restricciones UNIQUE, CHECK, DEFAULT y acciones referenciales
--            sobre el esquema físico de la Etapa 1 (001_esquema.sql).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. UNIQUE adicionales (más allá de las claves primarias)
-- ---------------------------------------------------------------------------

ALTER TABLE provincia
    ADD CONSTRAINT uq_provincia_nombre UNIQUE (nombre);

ALTER TABLE departamento
    ADD CONSTRAINT uq_departamento_provincia_nombre UNIQUE (id_provincia, nombre);

ALTER TABLE localidad
    ADD CONSTRAINT uq_localidad_provincia_nombre_cp UNIQUE (id_provincia, nombre, codigo_postal);

ALTER TABLE bodega
    ADD CONSTRAINT uq_bodega_cuit UNIQUE (cuit);

ALTER TABLE transportista
    ADD CONSTRAINT uq_transportista_cuit UNIQUE (cuit);

ALTER TABLE empleado
    ADD CONSTRAINT uq_empleado_cuit UNIQUE (cuit);

ALTER TABLE cepa
    ADD CONSTRAINT uq_cepa_nombre UNIQUE (nombre);

ALTER TABLE maridaje
    ADD CONSTRAINT uq_maridaje_nombre UNIQUE (nombre);

ALTER TABLE lote_uva
    ADD CONSTRAINT uq_lote_uva_parcela_campania UNIQUE (id_finca, nro_parcela, campania);

ALTER TABLE vino
    ADD CONSTRAINT uq_vino_nombre_anada_volumen UNIQUE (nombre, anada, volumen_ml);

ALTER TABLE cliente
    ADD CONSTRAINT uq_cliente_tipo_doc_nro_doc UNIQUE (tipo_doc, nro_doc);

ALTER TABLE permiso_exportacion
    ADD CONSTRAINT uq_permiso_exportacion_codigo UNIQUE (codigo);

-- ---------------------------------------------------------------------------
-- 2. CHECK (al menos 8, incluyendo uno entre columnas)
-- ---------------------------------------------------------------------------

-- RN-01: precio del vino mayor que cero
ALTER TABLE vino
    ADD CONSTRAINT chk_vino_precio_positivo CHECK (precio > 0);

-- RN-15: graduación alcohólica entre 5 y 20
ALTER TABLE vino
    ADD CONSTRAINT chk_vino_graduacion_rango CHECK (graduacion BETWEEN 5 AND 20);

-- RN-15: volumen de presentación válido
ALTER TABLE vino
    ADD CONSTRAINT chk_vino_volumen_valido CHECK (volumen_ml IN (187, 375, 750, 1000, 1500, 3000));

-- RN-15: superficies positivas
ALTER TABLE finca
    ADD CONSTRAINT chk_finca_superficie_positiva CHECK (superficie_ha > 0);

ALTER TABLE parcela
    ADD CONSTRAINT chk_parcela_superficie_positiva CHECK (superficie_ha > 0);

-- RN-15: kilos cosechados positivos
ALTER TABLE lote_uva
    ADD CONSTRAINT chk_lote_kilos_positivos CHECK (kilos_cosechados > 0);

-- Cantidades positivas en stocks y renglones
ALTER TABLE stock_sala
    ADD CONSTRAINT chk_stock_sala_cantidad_no_negativa CHECK (cantidad >= 0);

ALTER TABLE stock_deposito
    ADD CONSTRAINT chk_stock_deposito_cantidad_no_negativa CHECK (cantidad >= 0);

ALTER TABLE renglon_ingreso
    ADD CONSTRAINT chk_renglon_ingreso_cantidad_positiva CHECK (cantidad > 0);

ALTER TABLE renglon_transferencia
    ADD CONSTRAINT chk_renglon_transferencia_cantidad_positiva CHECK (cantidad > 0);

ALTER TABLE renglon_comprobante
    ADD CONSTRAINT chk_renglon_comprobante_cantidad_positiva CHECK (cantidad > 0);

-- RN-05: porcentaje de corte entre 0 y 100
ALTER TABLE vino_cepa
    ADD CONSTRAINT chk_vino_cepa_porcentaje_rango CHECK (porcentaje BETWEEN 0 AND 100);

-- RN-06: descuento entre 0 y 100
ALTER TABLE cliente
    ADD CONSTRAINT chk_cliente_descuento_rango CHECK (descuento BETWEEN 0 AND 100);

ALTER TABLE renglon_comprobante
    ADD CONSTRAINT chk_renglon_comprobante_descuento_rango CHECK (descuento_aplicado BETWEEN 0 AND 100);

-- RN-07: vencimiento posterior a emisión (CHECK entre columnas)
ALTER TABLE permiso_exportacion
    ADD CONSTRAINT chk_permiso_vencimiento_posterior CHECK (fecha_vencimiento > fecha_emision);

-- Valores positivos en análisis de calidad
ALTER TABLE analisis_calidad
    ADD CONSTRAINT chk_analisis_brix_positivo CHECK (brix > 0);

ALTER TABLE analisis_calidad
    ADD CONSTRAINT chk_analisis_ph_positivo CHECK (ph > 0);

ALTER TABLE analisis_calidad
    ADD CONSTRAINT chk_analisis_acidez_positiva CHECK (acidez_total > 0);

-- Salario positivo
ALTER TABLE empleado
    ADD CONSTRAINT chk_empleado_salario_positivo CHECK (salario > 0);

-- ---------------------------------------------------------------------------
-- 3. DEFAULT (al menos 3)
-- ---------------------------------------------------------------------------

ALTER TABLE ingreso
    ALTER COLUMN estado SET DEFAULT 'en_confeccion';

ALTER TABLE transferencia
    ALTER COLUMN estado SET DEFAULT 'en_confeccion';

ALTER TABLE cliente
    ALTER COLUMN fecha_alta SET DEFAULT CURRENT_DATE;

ALTER TABLE transferencia
    ALTER COLUMN fecha_confeccion SET DEFAULT CURRENT_DATE;

ALTER TABLE stock_sala
    ALTER COLUMN cantidad SET DEFAULT 0;

ALTER TABLE stock_deposito
    ALTER COLUMN cantidad SET DEFAULT 0;

-- ---------------------------------------------------------------------------
-- 4. Acciones referenciales ON DELETE / ON UPDATE en cada FK
-- ---------------------------------------------------------------------------
-- Nota: en PostgreSQL no se puede alterar una FK existente para cambiar
-- ON DELETE/ON UPDATE. Se debe dropar y volver a crear.

-- Tabla: departamento -> provincia (RESTRICT, catálogo)
ALTER TABLE departamento
    DROP CONSTRAINT fk_departamento_provincia,
    ADD CONSTRAINT fk_departamento_provincia
        FOREIGN KEY (id_provincia) REFERENCES provincia (id_provincia)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: localidad -> provincia (RESTRICT, hay datos que dependen)
ALTER TABLE localidad
    DROP CONSTRAINT fk_localidad_provincia,
    ADD CONSTRAINT fk_localidad_provincia
        FOREIGN KEY (id_provincia) REFERENCES provincia (id_provincia)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: sala_venta -> localidad (RESTRICT)
ALTER TABLE sala_venta
    DROP CONSTRAINT fk_sala_localidad,
    ADD CONSTRAINT fk_sala_localidad
        FOREIGN KEY (id_localidad) REFERENCES localidad (id_localidad)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: empleado -> sala_venta (RESTRICT, D3 borra empleados primero)
ALTER TABLE empleado
    DROP CONSTRAINT fk_empleado_sala,
    ADD CONSTRAINT fk_empleado_sala
        FOREIGN KEY (id_sala) REFERENCES sala_venta (id_sala)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: finca -> departamento (RESTRICT, catálogo)
ALTER TABLE finca
    DROP CONSTRAINT fk_finca_departamento,
    ADD CONSTRAINT fk_finca_departamento
        FOREIGN KEY (id_departamento) REFERENCES departamento (id_departamento)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: parcela -> finca (RESTRICT, se conserva historial)
ALTER TABLE parcela
    DROP CONSTRAINT fk_parcela_finca,
    ADD CONSTRAINT fk_parcela_finca
        FOREIGN KEY (id_finca) REFERENCES finca (id_finca)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: parcela -> cepa (RESTRICT, no se borra cepa en uso)
ALTER TABLE parcela
    DROP CONSTRAINT fk_parcela_cepa,
    ADD CONSTRAINT fk_parcela_cepa
        FOREIGN KEY (id_cepa) REFERENCES cepa (id_cepa)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: lote_uva -> parcela (RESTRICT, se conserva historial de cosechas)
ALTER TABLE lote_uva
    DROP CONSTRAINT fk_lote_parcela,
    ADD CONSTRAINT fk_lote_parcela
        FOREIGN KEY (id_finca, nro_parcela) REFERENCES parcela (id_finca, nro_parcela)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: lote_uva -> bodega (RESTRICT, RN-14)
ALTER TABLE lote_uva
    DROP CONSTRAINT fk_lote_bodega,
    ADD CONSTRAINT fk_lote_bodega
        FOREIGN KEY (id_bodega) REFERENCES bodega (id_bodega)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: analisis_calidad -> lote_uva (CASCADE, análisis no existe sin lote)
ALTER TABLE analisis_calidad
    DROP CONSTRAINT fk_analisis_lote,
    ADD CONSTRAINT fk_analisis_lote
        FOREIGN KEY (nro_lote) REFERENCES lote_uva (nro_lote)
        ON DELETE CASCADE ON UPDATE NO ACTION;

-- Tabla: vino -> bodega (RESTRICT, RN-14)
ALTER TABLE vino
    DROP CONSTRAINT fk_vino_bodega,
    ADD CONSTRAINT fk_vino_bodega
        FOREIGN KEY (id_bodega) REFERENCES bodega (id_bodega)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: vino_cepa -> vino (CASCADE, composición pertenece al vino)
ALTER TABLE vino_cepa
    DROP CONSTRAINT fk_vino_cepa_vino,
    ADD CONSTRAINT fk_vino_cepa_vino
        FOREIGN KEY (cod_vino) REFERENCES vino (cod_vino)
        ON DELETE CASCADE ON UPDATE NO ACTION;

-- Tabla: vino_cepa -> cepa (RESTRICT, no se borra cepa en uso, D2)
ALTER TABLE vino_cepa
    DROP CONSTRAINT fk_vino_cepa_cepa,
    ADD CONSTRAINT fk_vino_cepa_cepa
        FOREIGN KEY (id_cepa) REFERENCES cepa (id_cepa)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: vino_maridaje -> vino (CASCADE)
ALTER TABLE vino_maridaje
    DROP CONSTRAINT fk_vino_maridaje_vino,
    ADD CONSTRAINT fk_vino_maridaje_vino
        FOREIGN KEY (cod_vino) REFERENCES vino (cod_vino)
        ON DELETE CASCADE ON UPDATE NO ACTION;

-- Tabla: vino_maridaje -> maridaje (RESTRICT, no se borra maridaje en uso)
ALTER TABLE vino_maridaje
    DROP CONSTRAINT fk_vino_maridaje_maridaje,
    ADD CONSTRAINT fk_vino_maridaje_maridaje
        FOREIGN KEY (id_maridaje) REFERENCES maridaje (id_maridaje)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: auditoria_precio -> vino (RESTRICT, RN-14, no se pierde historia)
ALTER TABLE auditoria_precio
    DROP CONSTRAINT fk_auditoria_vino,
    ADD CONSTRAINT fk_auditoria_vino
        FOREIGN KEY (cod_vino) REFERENCES vino (cod_vino)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: stock_sala -> sala_venta (CASCADE, stock no existe sin sala)
ALTER TABLE stock_sala
    DROP CONSTRAINT fk_stock_sala_sala,
    ADD CONSTRAINT fk_stock_sala_sala
        FOREIGN KEY (id_sala) REFERENCES sala_venta (id_sala)
        ON DELETE CASCADE ON UPDATE NO ACTION;

-- Tabla: stock_sala -> vino (RESTRICT, RN-14)
ALTER TABLE stock_sala
    DROP CONSTRAINT fk_stock_sala_vino,
    ADD CONSTRAINT fk_stock_sala_vino
        FOREIGN KEY (cod_vino) REFERENCES vino (cod_vino)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: stock_deposito -> vino (RESTRICT, RN-14)
ALTER TABLE stock_deposito
    DROP CONSTRAINT fk_stock_deposito_vino,
    ADD CONSTRAINT fk_stock_deposito_vino
        FOREIGN KEY (cod_vino) REFERENCES vino (cod_vino)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: transportista_localidad -> transportista (CASCADE)
ALTER TABLE transportista_localidad
    DROP CONSTRAINT fk_tl_transportista,
    ADD CONSTRAINT fk_tl_transportista
        FOREIGN KEY (cod_transportista) REFERENCES transportista (cod_transportista)
        ON DELETE CASCADE ON UPDATE NO ACTION;

-- Tabla: transportista_localidad -> localidad (RESTRICT)
ALTER TABLE transportista_localidad
    DROP CONSTRAINT fk_tl_localidad,
    ADD CONSTRAINT fk_tl_localidad
        FOREIGN KEY (id_localidad) REFERENCES localidad (id_localidad)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: ingreso -> transportista (RESTRICT, RN-14)
ALTER TABLE ingreso
    DROP CONSTRAINT fk_ingreso_transportista,
    ADD CONSTRAINT fk_ingreso_transportista
        FOREIGN KEY (cod_transportista) REFERENCES transportista (cod_transportista)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: ingreso -> bodega (RESTRICT, RN-14)
ALTER TABLE ingreso
    DROP CONSTRAINT fk_ingreso_bodega,
    ADD CONSTRAINT fk_ingreso_bodega
        FOREIGN KEY (id_bodega) REFERENCES bodega (id_bodega)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: renglon_ingreso -> ingreso (CASCADE)
ALTER TABLE renglon_ingreso
    DROP CONSTRAINT fk_renglon_ingreso_ingreso,
    ADD CONSTRAINT fk_renglon_ingreso_ingreso
        FOREIGN KEY (cod_ingreso) REFERENCES ingreso (cod_ingreso)
        ON DELETE CASCADE ON UPDATE NO ACTION;

-- Tabla: renglon_ingreso -> vino (RESTRICT)
ALTER TABLE renglon_ingreso
    DROP CONSTRAINT fk_renglon_ingreso_vino,
    ADD CONSTRAINT fk_renglon_ingreso_vino
        FOREIGN KEY (cod_vino) REFERENCES vino (cod_vino)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: transferencia -> sala_venta (RESTRICT)
ALTER TABLE transferencia
    DROP CONSTRAINT fk_transferencia_sala,
    ADD CONSTRAINT fk_transferencia_sala
        FOREIGN KEY (id_sala) REFERENCES sala_venta (id_sala)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: renglon_transferencia -> transferencia (CASCADE)
ALTER TABLE renglon_transferencia
    DROP CONSTRAINT fk_renglon_transf_transferencia,
    ADD CONSTRAINT fk_renglon_transf_transferencia
        FOREIGN KEY (nro_solicitud) REFERENCES transferencia (nro_solicitud)
        ON DELETE CASCADE ON UPDATE NO ACTION;

-- Tabla: renglon_transferencia -> vino (RESTRICT)
ALTER TABLE renglon_transferencia
    DROP CONSTRAINT fk_renglon_transf_vino,
    ADD CONSTRAINT fk_renglon_transf_vino
        FOREIGN KEY (cod_vino) REFERENCES vino (cod_vino)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: cliente -> localidad (RESTRICT)
ALTER TABLE cliente
    DROP CONSTRAINT fk_cliente_localidad,
    ADD CONSTRAINT fk_cliente_localidad
        FOREIGN KEY (id_localidad) REFERENCES localidad (id_localidad)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: socio -> cliente (CASCADE)
ALTER TABLE socio
    DROP CONSTRAINT fk_socio_cliente,
    ADD CONSTRAINT fk_socio_cliente
        FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
        ON DELETE CASCADE ON UPDATE NO ACTION;

-- Tabla: distribuidor -> cliente (CASCADE)
ALTER TABLE distribuidor
    DROP CONSTRAINT fk_distribuidor_cliente,
    ADD CONSTRAINT fk_distribuidor_cliente
        FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
        ON DELETE CASCADE ON UPDATE NO ACTION;

-- Tabla: exportador -> cliente (CASCADE)
ALTER TABLE exportador
    DROP CONSTRAINT fk_exportador_cliente,
    ADD CONSTRAINT fk_exportador_cliente
        FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
        ON DELETE CASCADE ON UPDATE NO ACTION;

-- Tabla: permiso_exportacion -> exportador (CASCADE)
ALTER TABLE permiso_exportacion
    DROP CONSTRAINT fk_permiso_exportador,
    ADD CONSTRAINT fk_permiso_exportador
        FOREIGN KEY (id_cliente) REFERENCES exportador (id_cliente)
        ON DELETE CASCADE ON UPDATE NO ACTION;

-- Tabla: comprobante -> cliente (RESTRICT, documentos no se pierden)
ALTER TABLE comprobante
    DROP CONSTRAINT fk_comprobante_cliente,
    ADD CONSTRAINT fk_comprobante_cliente
        FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: comprobante -> sala_venta (RESTRICT)
ALTER TABLE comprobante
    DROP CONSTRAINT fk_comprobante_sala,
    ADD CONSTRAINT fk_comprobante_sala
        FOREIGN KEY (id_sala) REFERENCES sala_venta (id_sala)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- Tabla: renglon_comprobante -> comprobante (CASCADE)
ALTER TABLE renglon_comprobante
    DROP CONSTRAINT fk_renglon_comp_comprobante,
    ADD CONSTRAINT fk_renglon_comp_comprobante
        FOREIGN KEY (nro_comprobante) REFERENCES comprobante (nro_comprobante)
        ON DELETE CASCADE ON UPDATE NO ACTION;

-- Tabla: renglon_comprobante -> vino (RESTRICT, RN-14)
ALTER TABLE renglon_comprobante
    DROP CONSTRAINT fk_renglon_comp_vino,
    ADD CONSTRAINT fk_renglon_comp_vino
        FOREIGN KEY (cod_vino) REFERENCES vino (cod_vino)
        ON DELETE RESTRICT ON UPDATE NO ACTION;

-- =============================================================================
-- Fin de 002_constraints.sql
-- =============================================================================
