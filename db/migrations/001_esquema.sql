-- =====================================================
-- Etapa 1: tipos enumerados, dominios, tablas, PK y FK.
-- Etapa 2 (002_constraints.sql): UNIQUE, CHECK, DEFAULT, ON DELETE/UPDATE.
-- =====================================================

-- ---------- TIPOS ENUMERADOS ----------
CREATE TYPE estado_documento AS ENUM ('en_confeccion', 'terminado', 'procesado');
CREATE TYPE tipo_vino        AS ENUM ('tinto', 'blanco', 'rosado', 'espumante');
CREATE TYPE tipo_cepa        AS ENUM ('tinta', 'blanca');
CREATE TYPE tipo_cliente     AS ENUM ('socio', 'distribuidor', 'exportador');
CREATE TYPE tipo_documento   AS ENUM ('DNI', 'CUIT', 'CUIL', 'PASAPORTE');
CREATE TYPE dia_semana       AS ENUM ('lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo');

-- ---------- DOMINIOS ----------
CREATE DOMAIN dom_cuit       AS char(11) CHECK (VALUE ~ '^[0-9]{11}$');
CREATE DOMAIN dom_email      AS varchar(120);
CREATE DOMAIN dom_telefono   AS varchar(30);
CREATE DOMAIN dom_dinero     AS numeric(12,2);
CREATE DOMAIN dom_porcentaje AS numeric(5,2);
CREATE DOMAIN dom_superficie AS numeric(10,2);
CREATE DOMAIN dom_cantidad   AS integer;
CREATE DOMAIN dom_anio       AS smallint;

-- ---------- GEOGRAFIA ----------
CREATE TABLE provincia (
    id_provincia integer GENERATED ALWAYS AS IDENTITY,
    nombre       varchar(80) NOT NULL,
    CONSTRAINT pk_provincia PRIMARY KEY (id_provincia)
);

CREATE TABLE departamento (
    id_departamento integer GENERATED ALWAYS AS IDENTITY,
    id_provincia    integer NOT NULL,
    nombre          varchar(80) NOT NULL,
    CONSTRAINT pk_departamento PRIMARY KEY (id_departamento),
    CONSTRAINT fk_departamento_provincia FOREIGN KEY (id_provincia) REFERENCES provincia (id_provincia)
);

CREATE TABLE localidad (
    id_localidad       integer GENERATED ALWAYS AS IDENTITY,
    id_provincia       integer NOT NULL,
    nombre             varchar(100) NOT NULL,
    codigo_postal      varchar(10) NOT NULL,
    encargado_regional varchar(100) NOT NULL,   -- FD: id_localidad -> encargado_regional
    CONSTRAINT pk_localidad PRIMARY KEY (id_localidad),
    CONSTRAINT fk_localidad_provincia FOREIGN KEY (id_provincia) REFERENCES provincia (id_provincia)
);

-- ---------- SALAS Y EMPLEADOS ----------
CREATE TABLE sala_venta (
    id_sala      integer GENERATED ALWAYS AS IDENTITY,
    id_localidad integer NOT NULL,
    calle        varchar(120) NOT NULL,
    numero       varchar(10) NOT NULL,
    dia_cierre   dia_semana NOT NULL,
    CONSTRAINT pk_sala_venta PRIMARY KEY (id_sala),
    CONSTRAINT fk_sala_localidad FOREIGN KEY (id_localidad) REFERENCES localidad (id_localidad)
);

CREATE TABLE empleado (
    id_empleado   integer GENERATED ALWAYS AS IDENTITY,
    id_sala       integer NOT NULL,              -- RN-03
    cuit          dom_cuit NOT NULL,
    nombre        varchar(80) NOT NULL,
    apellido      varchar(80) NOT NULL,
    fecha_ingreso date NOT NULL,
    salario       dom_dinero NOT NULL,
    CONSTRAINT pk_empleado PRIMARY KEY (id_empleado),
    CONSTRAINT fk_empleado_sala FOREIGN KEY (id_sala) REFERENCES sala_venta (id_sala)
);

-- ---------- BODEGAS ----------
CREATE TABLE bodega (
    id_bodega    integer GENERATED ALWAYS AS IDENTITY,
    cuit         dom_cuit NOT NULL,
    razon_social varchar(150) NOT NULL,
    domicilio    varchar(200) NOT NULL,
    CONSTRAINT pk_bodega PRIMARY KEY (id_bodega)
);

-- ---------- PRODUCCION DE UVA ----------
CREATE TABLE finca (
    id_finca        integer GENERATED ALWAYS AS IDENTITY,
    id_departamento integer NOT NULL,
    nombre          varchar(100) NOT NULL,
    superficie_ha   dom_superficie NOT NULL,
    CONSTRAINT pk_finca PRIMARY KEY (id_finca),
    CONSTRAINT fk_finca_departamento FOREIGN KEY (id_departamento) REFERENCES departamento (id_departamento)
);

CREATE TABLE cepa (
    id_cepa integer GENERATED ALWAYS AS IDENTITY,
    nombre  varchar(80) NOT NULL,
    tipo    tipo_cepa NOT NULL,
    CONSTRAINT pk_cepa PRIMARY KEY (id_cepa)
);

-- Entidad debil de finca. Una sola cepa por parcela (RN-04)
CREATE TABLE parcela (
    id_finca        integer NOT NULL,
    nro_parcela     integer NOT NULL,
    id_cepa         integer NOT NULL,
    superficie_ha   dom_superficie NOT NULL,
    anio_plantacion dom_anio NOT NULL,
    CONSTRAINT pk_parcela PRIMARY KEY (id_finca, nro_parcela),
    CONSTRAINT fk_parcela_finca FOREIGN KEY (id_finca) REFERENCES finca (id_finca),
    CONSTRAINT fk_parcela_cepa FOREIGN KEY (id_cepa) REFERENCES cepa (id_cepa)
);

CREATE TABLE lote_uva (
    nro_lote         integer GENERATED ALWAYS AS IDENTITY,
    id_finca         integer NOT NULL,
    nro_parcela      integer NOT NULL,
    campania         dom_anio NOT NULL,
    fecha_cosecha    date NOT NULL,
    kilos_cosechados numeric(12,2) NOT NULL,
    id_bodega        integer NOT NULL,           -- bodega a la que fue entregado
    CONSTRAINT pk_lote_uva PRIMARY KEY (nro_lote),
    CONSTRAINT fk_lote_parcela FOREIGN KEY (id_finca, nro_parcela) REFERENCES parcela (id_finca, nro_parcela),
    CONSTRAINT fk_lote_bodega FOREIGN KEY (id_bodega) REFERENCES bodega (id_bodega)
);

CREATE TABLE analisis_calidad (
    id_analisis    integer GENERATED ALWAYS AS IDENTITY,
    nro_lote       integer NOT NULL,
    fecha_analisis date NOT NULL,
    brix           numeric(5,2) NOT NULL,
    ph             numeric(4,2) NOT NULL,
    acidez_total   numeric(5,2) NOT NULL,        -- g/L
    CONSTRAINT pk_analisis_calidad PRIMARY KEY (id_analisis),
    CONSTRAINT fk_analisis_lote FOREIGN KEY (nro_lote) REFERENCES lote_uva (nro_lote)
);

-- ---------- VINOS ----------
CREATE TABLE vino (
    cod_vino   integer GENERATED ALWAYS AS IDENTITY,
    id_bodega  integer NOT NULL,
    nombre     varchar(80) NOT NULL,
    tipo       tipo_vino NOT NULL,
    anada      dom_anio NOT NULL,
    volumen_ml integer NOT NULL,
    graduacion numeric(4,2) NOT NULL,
    precio     dom_dinero NOT NULL,              -- RN-01
    CONSTRAINT pk_vino PRIMARY KEY (cod_vino),
    CONSTRAINT fk_vino_bodega FOREIGN KEY (id_bodega) REFERENCES bodega (id_bodega)
);

CREATE TABLE vino_cepa (
    cod_vino   integer NOT NULL,
    id_cepa    integer NOT NULL,
    porcentaje dom_porcentaje NOT NULL,          -- RN-05
    CONSTRAINT pk_vino_cepa PRIMARY KEY (cod_vino, id_cepa),
    CONSTRAINT fk_vino_cepa_vino FOREIGN KEY (cod_vino) REFERENCES vino (cod_vino),
    CONSTRAINT fk_vino_cepa_cepa FOREIGN KEY (id_cepa) REFERENCES cepa (id_cepa)
);

CREATE TABLE maridaje (
    id_maridaje          integer GENERATED ALWAYS AS IDENTITY,
    nombre               varchar(80) NOT NULL,
    temperatura_servicio numeric(4,1) NOT NULL,  -- grados C
    CONSTRAINT pk_maridaje PRIMARY KEY (id_maridaje)
);

CREATE TABLE vino_maridaje (
    cod_vino    integer NOT NULL,
    id_maridaje integer NOT NULL,
    CONSTRAINT pk_vino_maridaje PRIMARY KEY (cod_vino, id_maridaje),
    CONSTRAINT fk_vino_maridaje_vino FOREIGN KEY (cod_vino) REFERENCES vino (cod_vino),
    CONSTRAINT fk_vino_maridaje_maridaje FOREIGN KEY (id_maridaje) REFERENCES maridaje (id_maridaje)
);

-- La completa un trigger AFTER UPDATE (RN-13)
CREATE TABLE auditoria_precio (
    id_auditoria    integer GENERATED ALWAYS AS IDENTITY,
    cod_vino        integer NOT NULL,
    precio_anterior dom_dinero NOT NULL,
    precio_nuevo    dom_dinero NOT NULL,
    fecha_hora      timestamp NOT NULL,
    usuario         varchar(63) NOT NULL,
    CONSTRAINT pk_auditoria_precio PRIMARY KEY (id_auditoria),
    CONSTRAINT fk_auditoria_vino FOREIGN KEY (cod_vino) REFERENCES vino (cod_vino)
);

-- ---------- STOCK ----------
CREATE TABLE stock_sala (
    id_sala  integer NOT NULL,
    cod_vino integer NOT NULL,
    cantidad dom_cantidad NOT NULL,
    CONSTRAINT pk_stock_sala PRIMARY KEY (id_sala, cod_vino),
    CONSTRAINT fk_stock_sala_sala FOREIGN KEY (id_sala) REFERENCES sala_venta (id_sala),
    CONSTRAINT fk_stock_sala_vino FOREIGN KEY (cod_vino) REFERENCES vino (cod_vino)
);

-- Un solo deposito central: el stock se identifica solo por vino
CREATE TABLE stock_deposito (
    cod_vino integer NOT NULL,
    cantidad dom_cantidad NOT NULL,
    CONSTRAINT pk_stock_deposito PRIMARY KEY (cod_vino),
    CONSTRAINT fk_stock_deposito_vino FOREIGN KEY (cod_vino) REFERENCES vino (cod_vino)
);

-- ---------- TRANSPORTISTAS ----------
CREATE TABLE transportista (
    cod_transportista integer GENERATED ALWAYS AS IDENTITY,
    razon_social      varchar(150) NOT NULL,
    cuit              dom_cuit NOT NULL,
    email             dom_email NOT NULL,
    telefono          dom_telefono NOT NULL,
    domicilio         varchar(200) NOT NULL,
    CONSTRAINT pk_transportista PRIMARY KEY (cod_transportista)
);

CREATE TABLE transportista_localidad (
    cod_transportista integer NOT NULL,
    id_localidad      integer NOT NULL,
    CONSTRAINT pk_transportista_localidad PRIMARY KEY (cod_transportista, id_localidad),
    CONSTRAINT fk_tl_transportista FOREIGN KEY (cod_transportista) REFERENCES transportista (cod_transportista),
    CONSTRAINT fk_tl_localidad FOREIGN KEY (id_localidad) REFERENCES localidad (id_localidad)
);

-- ---------- INGRESOS ----------
CREATE TABLE ingreso (
    cod_ingreso       integer GENERATED ALWAYS AS IDENTITY,
    fecha             date NOT NULL,
    estado            estado_documento NOT NULL,
    cod_transportista integer NOT NULL,
    id_bodega         integer NOT NULL,          -- bodega de origen
    observaciones     text,
    CONSTRAINT pk_ingreso PRIMARY KEY (cod_ingreso),
    CONSTRAINT fk_ingreso_transportista FOREIGN KEY (cod_transportista) REFERENCES transportista (cod_transportista),
    CONSTRAINT fk_ingreso_bodega FOREIGN KEY (id_bodega) REFERENCES bodega (id_bodega)
);

CREATE TABLE renglon_ingreso (
    cod_ingreso integer NOT NULL,
    cod_vino    integer NOT NULL,
    cantidad    dom_cantidad NOT NULL,
    CONSTRAINT pk_renglon_ingreso PRIMARY KEY (cod_ingreso, cod_vino),
    CONSTRAINT fk_renglon_ingreso_ingreso FOREIGN KEY (cod_ingreso) REFERENCES ingreso (cod_ingreso),
    CONSTRAINT fk_renglon_ingreso_vino FOREIGN KEY (cod_vino) REFERENCES vino (cod_vino)
);

-- ---------- TRANSFERENCIAS ----------
CREATE TABLE transferencia (
    nro_solicitud    integer GENERATED ALWAYS AS IDENTITY,
    id_sala          integer NOT NULL,           -- sala solicitante
    fecha_confeccion date NOT NULL,              -- RN-11: la fija un trigger
    estado           estado_documento NOT NULL,
    observaciones    text,
    CONSTRAINT pk_transferencia PRIMARY KEY (nro_solicitud),
    CONSTRAINT fk_transferencia_sala FOREIGN KEY (id_sala) REFERENCES sala_venta (id_sala)
);

CREATE TABLE renglon_transferencia (
    nro_solicitud integer NOT NULL,
    cod_vino      integer NOT NULL,
    cantidad      dom_cantidad NOT NULL,
    CONSTRAINT pk_renglon_transferencia PRIMARY KEY (nro_solicitud, cod_vino),
    CONSTRAINT fk_renglon_transf_transferencia FOREIGN KEY (nro_solicitud) REFERENCES transferencia (nro_solicitud),
    CONSTRAINT fk_renglon_transf_vino FOREIGN KEY (cod_vino) REFERENCES vino (cod_vino)
);

-- ---------- CLIENTES (supertipo + subtipos) ----------
CREATE TABLE cliente (
    id_cliente         integer GENERATED ALWAYS AS IDENTITY,
    tipo_cliente       tipo_cliente NOT NULL,    -- discriminador
    nombre_razon_social varchar(150) NOT NULL,
    tipo_doc           tipo_documento NOT NULL,
    nro_doc            varchar(20) NOT NULL,
    direccion          varchar(200) NOT NULL,
    id_localidad       integer NOT NULL,
    fecha_alta         date NOT NULL,
    descuento          dom_porcentaje NOT NULL,  -- RN-06: lo fija fn_descuento_cliente
    email              dom_email,
    telefono           dom_telefono,
    CONSTRAINT pk_cliente PRIMARY KEY (id_cliente),
    CONSTRAINT fk_cliente_localidad FOREIGN KEY (id_localidad) REFERENCES localidad (id_localidad)
);

-- Socio no tiene atributos propios: la tabla existe para representar el subtipo
CREATE TABLE socio (
    id_cliente integer NOT NULL,
    CONSTRAINT pk_socio PRIMARY KEY (id_cliente),
    CONSTRAINT fk_socio_cliente FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
);

CREATE TABLE distribuidor (
    id_cliente      integer NOT NULL,
    zona_cobertura  varchar(120) NOT NULL,
    nro_habilitacion varchar(30) NOT NULL,
    CONSTRAINT pk_distribuidor PRIMARY KEY (id_cliente),
    CONSTRAINT fk_distribuidor_cliente FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
);

CREATE TABLE exportador (
    id_cliente   integer NOT NULL,
    pais_destino varchar(80) NOT NULL,           -- pais de destino principal
    CONSTRAINT pk_exportador PRIMARY KEY (id_cliente),
    CONSTRAINT fk_exportador_cliente FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
);

-- Entidad debil de exportador (RN-07)
CREATE TABLE permiso_exportacion (
    id_cliente        integer NOT NULL,
    codigo            varchar(30) NOT NULL,
    fecha_emision     date NOT NULL,
    fecha_vencimiento date NOT NULL,
    CONSTRAINT pk_permiso_exportacion PRIMARY KEY (id_cliente, codigo),
    CONSTRAINT fk_permiso_exportador FOREIGN KEY (id_cliente) REFERENCES exportador (id_cliente)
);

-- ---------- COMPROBANTES ----------
-- subtotal, descuento (importe) y total se almacenan pero los mantiene un
-- trigger/funcion (RN-08): nunca se cargan a mano.
CREATE TABLE comprobante (
    nro_comprobante integer GENERATED ALWAYS AS IDENTITY,
    fecha           date NOT NULL,
    id_cliente      integer NOT NULL,
    id_sala         integer NOT NULL,
    subtotal        dom_dinero NOT NULL,
    descuento       dom_dinero NOT NULL,
    total           dom_dinero NOT NULL,
    CONSTRAINT pk_comprobante PRIMARY KEY (nro_comprobante),
    CONSTRAINT fk_comprobante_cliente FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente),
    CONSTRAINT fk_comprobante_sala FOREIGN KEY (id_sala) REFERENCES sala_venta (id_sala)
);

CREATE TABLE renglon_comprobante (
    nro_comprobante    integer NOT NULL,
    cod_vino           integer NOT NULL,
    cantidad           dom_cantidad NOT NULL,
    precio_unitario    dom_dinero NOT NULL,      -- precio al momento de la venta
    descuento_aplicado dom_porcentaje NOT NULL,  -- % segun tipo de cliente
    subtotal           dom_dinero NOT NULL,      -- cantidad * precio * (1 - desc/100)
    CONSTRAINT pk_renglon_comprobante PRIMARY KEY (nro_comprobante, cod_vino),
    CONSTRAINT fk_renglon_comp_comprobante FOREIGN KEY (nro_comprobante) REFERENCES comprobante (nro_comprobante),
    CONSTRAINT fk_renglon_comp_vino FOREIGN KEY (cod_vino) REFERENCES vino (cod_vino)
);

-- =====================================================
-- PENDIENTE PARA 002_constraints.sql
--  UNIQUE: provincia(nombre); departamento(id_provincia,nombre);
--   localidad(id_provincia,nombre,codigo_postal); bodega(cuit); empleado(cuit);
--   cepa(nombre); maridaje(nombre); transportista(cuit);
--   lote_uva(id_finca,nro_parcela,campania)  -- RN-04
--   vino(nombre,anada,volumen_ml); cliente(tipo_doc,nro_doc);
--   permiso_exportacion(codigo)
--  CHECK: precio>0; cantidades>0 / stock>=0; superficies,kilos>0;
--   graduacion BETWEEN 5 AND 20; volumen_ml IN (187,375,750,1500,3000);
--   porcentaje BETWEEN 0 AND 100; descuento_aplicado BETWEEN 0 AND 100;
--   fecha_vencimiento > fecha_emision; ph/brix/acidez > 0
--  DEFAULT: estado='en_confeccion'; fecha_alta/fecha_confeccion=CURRENT_DATE;
--   stock_*.cantidad=0; comprobante.subtotal/descuento/total=0
--  ON DELETE: RESTRICT en vino, bodega, transportista y movimientos;
--   CASCADE en renglon_* (y analisis_calidad si se decide)
--  Triggers: RN-05, 08, 09, 10, 11, 12, 13 y coherencia cliente.tipo_cliente
--   vs. tabla de subtipo
-- =====================================================