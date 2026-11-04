# Diccionario de datos

**Proyecto:** Bodegas del Atuel — TP Integrador de Bases de Datos
**Etapa:** 1 (Modelado)
**Origen:** esquema físico `db/migrations/001_esquema.sql`
**Estado:** coincide con el esquema físico de la Etapa 1 (solo PK y FK; CHECK/UNIQUE/DEFAULT se completan en `002_constraints.sql`).

---

## Convenciones

- **PK:** clave primaria de la tabla.
- **FK:** clave foránea que referencia a otra tabla.
- **NN:** columna `NOT NULL` (no admite nulos).
- **N:** columna que admite nulos.
- **Tipo enumerado:** definido con `CREATE TYPE ... AS ENUM`.
- **Dominio:** definido con `CREATE DOMAIN ...`.

---

## 1. Tipos enumerados

| Tipo | Valores permitidos | Usado en |
|------|-------------------|----------|
| `estado_documento` | `en_confeccion`, `terminado`, `procesado` | `ingreso.estado`, `transferencia.estado` |
| `tipo_vino` | `tinto`, `blanco`, `rosado`, `espumante` | `vino.tipo` |
| `tipo_cepa` | `tinta`, `blanca` | `cepa.tipo` |
| `tipo_cliente` | `socio`, `distribuidor`, `exportador` | `cliente.tipo_cliente` (discriminador de la jerarquía) |
| `tipo_documento` | `DNI`, `CUIT`, `CUIL`, `PASAPORTE` | `cliente.tipo_doc` |
| `dia_semana` | `lunes`, `martes`, `miercoles`, `jueves`, `viernes`, `sabado`, `domingo` | `sala_venta.dia_cierre` |

> Ningún estado ni clasificación se modela como texto libre: todos usan tipos enumerados.

---

## 2. Dominios

| Dominio | Definición | Descripción | Usado en |
|---------|-----------|-------------|----------|
| `dom_cuit` | `char(11) CHECK (VALUE ~ '^[0-9]{11}$')` | CUIT de 11 dígitos numéricos | `empleado.cuit`, `bodega.cuit`, `transportista.cuit` |
| `dom_email` | `varchar(120)` | Correo electrónico | `cliente.email`, `transportista.email` |
| `dom_telefono` | `varchar(30)` | Teléfono | `cliente.telefono`, `transportista.telefono` |
| `dom_dinero` | `numeric(12,2)` | Importe monetario | precios, salario, subtotales, totales, auditoría |
| `dom_porcentaje` | `numeric(5,2)` | Porcentaje (0‑100) | `vino_cepa.porcentaje`, `cliente.descuento`, `renglon_comprobante.descuento_aplicado` |
| `dom_superficie` | `numeric(10,2)` | Superficie en hectáreas | `finca.superficie_ha`, `parcela.superficie_ha` |
| `dom_cantidad` | `integer` | Cantidad entera de unidades | stocks, renglones de ingreso/transferencia/comprobante |
| `dom_anio` | `smallint` | Año / campaña | `parcela.anio_plantacion`, `lote_uva.campania`, `vino.anada` |

> Los importes usan `NUMERIC`, nunca `FLOAT`, para evitar errores de punto flotante en cálculos de dinero.

---

## 3. Tablas

### 3.1 Geografía

#### provincia

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_provincia` | `integer` | NN | PK (identity) | Identificador de provincia |
| `nombre` | `varchar(80)` | NN | — | Nombre de la provincia |

#### departamento

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_departamento` | `integer` | NN | PK (identity) | Identificador de departamento |
| `id_provincia` | `integer` | NN | FK → `provincia` | Provincia a la que pertenece |
| `nombre` | `varchar(80)` | NN | — | Nombre del departamento |

#### localidad

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_localidad` | `integer` | NN | PK (identity) | Identificador de localidad |
| `id_provincia` | `integer` | NN | FK → `provincia` | Provincia de la localidad |
| `nombre` | `varchar(100)` | NN | — | Nombre de la localidad |
| `codigo_postal` | `varchar(10)` | NN | — | Código postal |
| `encargado_regional` | `varchar(100)` | NN | — | Encargado regional de la localidad (FD: `id_localidad → encargado_regional`) |

---

### 3.2 Salas y empleados

#### sala_venta

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_sala` | `integer` | NN | PK (identity) | Identificador de sala de venta |
| `id_localidad` | `integer` | NN | FK → `localidad` | Localidad donde está la sala |
| `calle` | `varchar(120)` | NN | — | Calle del domicilio |
| `numero` | `varchar(10)` | NN | — | Número del domicilio |
| `dia_cierre` | `dia_semana` | NN | — | Día de cierre de la sala |

#### empleado

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_empleado` | `integer` | NN | PK (identity) | Identificador de empleado |
| `id_sala` | `integer` | NN | FK → `sala_venta` | Sala donde trabaja (RN-03) |
| `cuit` | `dom_cuit` | NN | — | CUIT del empleado |
| `nombre` | `varchar(80)` | NN | — | Nombre |
| `apellido` | `varchar(80)` | NN | — | Apellido |
| `fecha_ingreso` | `date` | NN | — | Fecha de ingreso |
| `salario` | `dom_dinero` | NN | — | Salario |

---

### 3.3 Bodegas y producción de uva

#### bodega

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_bodega` | `integer` | NN | PK (identity) | Identificador de bodega |
| `cuit` | `dom_cuit` | NN | — | CUIT de la bodega |
| `razon_social` | `varchar(150)` | NN | — | Razón social |
| `domicilio` | `varchar(200)` | NN | — | Domicilio |

#### finca

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_finca` | `integer` | NN | PK (identity) | Identificador de finca |
| `id_departamento` | `integer` | NN | FK → `departamento` | Departamento donde está la finca |
| `nombre` | `varchar(100)` | NN | — | Nombre de la finca |
| `superficie_ha` | `dom_superficie` | NN | — | Superficie en hectáreas |

#### cepa

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_cepa` | `integer` | NN | PK (identity) | Identificador de cepa |
| `nombre` | `varchar(80)` | NN | — | Nombre de la cepa |
| `tipo` | `tipo_cepa` | NN | — | `tinta` o `blanca` |

#### parcela (entidad débil de finca)

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_finca` | `integer` | NN | PK, FK → `finca` | Finca a la que pertenece (parte de la PK compuesta) |
| `nro_parcela` | `integer` | NN | PK | Número de parcela dentro de la finca |
| `id_cepa` | `integer` | NN | FK → `cepa` | Cepa plantada (una sola cepa por parcela, RN-04) |
| `superficie_ha` | `dom_superficie` | NN | — | Superficie de la parcela |
| `anio_plantacion` | `dom_anio` | NN | — | Año de plantación |

#### lote_uva

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `nro_lote` | `integer` | NN | PK (identity) | Número de lote de uva |
| `id_finca` | `integer` | NN | FK (parte compuesta) → `parcela` | Finca del lote |
| `nro_parcela` | `integer` | NN | FK (parte compuesta) → `parcela` | Parcela del lote |
| `campania` | `dom_anio` | NN | — | Campaña de cosecha |
| `fecha_cosecha` | `date` | NN | — | Fecha de cosecha |
| `kilos_cosechados` | `numeric(12,2)` | NN | — | Kilos cosechados |
| `id_bodega` | `integer` | NN | FK → `bodega` | Bodega a la que fue entregado |

#### analisis_calidad

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_analisis` | `integer` | NN | PK (identity) | Identificador de análisis |
| `nro_lote` | `integer` | NN | FK → `lote_uva` | Lote analizado |
| `fecha_analisis` | `date` | NN | — | Fecha del análisis |
| `brix` | `numeric(5,2)` | NN | — | Grados Brix |
| `ph` | `numeric(4,2)` | NN | — | pH |
| `acidez_total` | `numeric(5,2)` | NN | — | Acidez total (g/L) |

---

### 3.4 Vinos

#### vino

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `cod_vino` | `integer` | NN | PK (identity) | Código de vino |
| `id_bodega` | `integer` | NN | FK → `bodega` | Bodega que lo elabora |
| `nombre` | `varchar(80)` | NN | — | Nombre del vino |
| `tipo` | `tipo_vino` | NN | — | `tinto`, `blanco`, `rosado` o `espumante` |
| `anada` | `dom_anio` | NN | — | Añada |
| `volumen_ml` | `integer` | NN | — | Volumen en ml |
| `graduacion` | `numeric(4,2)` | NN | — | Graduación alcohólica |
| `precio` | `dom_dinero` | NN | — | Precio (RN-01) |

#### vino_cepa (N:M con atributo entre vino y cepa)

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `cod_vino` | `integer` | NN | PK, FK → `vino` | Vino (parte de la PK compuesta) |
| `id_cepa` | `integer` | NN | PK, FK → `cepa` | Cepa (parte de la PK compuesta) |
| `porcentaje` | `dom_porcentaje` | NN | — | Porcentaje de la cepa en el corte (RN-05) |

#### maridaje

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_maridaje` | `integer` | NN | PK (identity) | Identificador de maridaje |
| `nombre` | `varchar(80)` | NN | — | Nombre del maridaje |
| `temperatura_servicio` | `numeric(4,1)` | NN | — | Temperatura de servicio (°C) |

#### vino_maridaje (N:M sin atributos entre vino y maridaje)

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `cod_vino` | `integer` | NN | PK, FK → `vino` | Vino (parte de la PK compuesta) |
| `id_maridaje` | `integer` | NN | PK, FK → `maridaje` | Maridaje (parte de la PK compuesta) |

#### auditoria_precio

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_auditoria` | `integer` | NN | PK (identity) | Identificador de auditoría |
| `cod_vino` | `integer` | NN | FK → `vino` | Vino cuyo precio cambió |
| `precio_anterior` | `dom_dinero` | NN | — | Precio antes del cambio |
| `precio_nuevo` | `dom_dinero` | NN | — | Precio después del cambio |
| `fecha_hora` | `timestamp` | NN | — | Fecha y hora del cambio |
| `usuario` | `varchar(63)` | NN | — | Usuario que realizó el cambio |

---

### 3.5 Stock

#### stock_sala

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_sala` | `integer` | NN | PK, FK → `sala_venta` | Sala de venta (parte de la PK compuesta) |
| `cod_vino` | `integer` | NN | PK, FK → `vino` | Vino (parte de la PK compuesta) |
| `cantidad` | `dom_cantidad` | NN | — | Cantidad en stock en la sala |

#### stock_deposito (depósito central, stock solo por vino)

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `cod_vino` | `integer` | NN | PK, FK → `vino` | Vino (PK simple) |
| `cantidad` | `dom_cantidad` | NN | — | Cantidad en stock del depósito central |

---

### 3.6 Transportistas

#### transportista

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `cod_transportista` | `integer` | NN | PK (identity) | Código de transportista |
| `razon_social` | `varchar(150)` | NN | — | Razón social |
| `cuit` | `dom_cuit` | NN | — | CUIT |
| `email` | `dom_email` | NN | — | Correo electrónico |
| `telefono` | `dom_telefono` | NN | — | Teléfono |
| `domicilio` | `varchar(200)` | NN | — | Domicilio |

#### transportista_localidad (N:M entre transportista y localidad)

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `cod_transportista` | `integer` | NN | PK, FK → `transportista` | Transportista (parte de la PK compuesta) |
| `id_localidad` | `integer` | NN | PK, FK → `localidad` | Localidad de cobertura (parte de la PK compuesta) |

---

### 3.7 Ingresos

#### ingreso

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `cod_ingreso` | `integer` | NN | PK (identity) | Código de ingreso |
| `fecha` | `date` | NN | — | Fecha de ingreso |
| `estado` | `estado_documento` | NN | — | `en_confeccion`, `terminado` o `procesado` |
| `cod_transportista` | `integer` | NN | FK → `transportista` | Transportista que realizó el ingreso |
| `id_bodega` | `integer` | NN | FK → `bodega` | Bodega de origen |
| `observaciones` | `text` | N | — | Observaciones |

#### renglon_ingreso (renglón de comprobante de ingreso)

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `cod_ingreso` | `integer` | NN | PK, FK → `ingreso` | Ingreso (parte de la PK compuesta) |
| `cod_vino` | `integer` | NN | PK, FK → `vino` | Vino (parte de la PK compuesta) |
| `cantidad` | `dom_cantidad` | NN | — | Cantidad ingresada |

---

### 3.8 Transferencias

#### transferencia

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `nro_solicitud` | `integer` | NN | PK (identity) | Número de solicitud de transferencia |
| `id_sala` | `integer` | NN | FK → `sala_venta` | Sala solicitante |
| `fecha_confeccion` | `date` | NN | — | Fecha de confección (RN-11: la fija un trigger) |
| `estado` | `estado_documento` | NN | — | `en_confeccion`, `terminado` o `procesado` |
| `observaciones` | `text` | N | — | Observaciones |

#### renglon_transferencia (renglón de comprobante de transferencia)

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `nro_solicitud` | `integer` | NN | PK, FK → `transferencia` | Transferencia (parte de la PK compuesta) |
| `cod_vino` | `integer` | NN | PK, FK → `vino` | Vino (parte de la PK compuesta) |
| `cantidad` | `dom_cantidad` | NN | — | Cantidad transferida |

---

### 3.9 Clientes (jerarquía supertipo / subtipos)

#### cliente (supertipo)

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_cliente` | `integer` | NN | PK (identity) | Identificador de cliente |
| `tipo_cliente` | `tipo_cliente` | NN | — | Discriminador: `socio`, `distribuidor` o `exportador` |
| `nombre_razon_social` | `varchar(150)` | NN | — | Nombre o razón social |
| `tipo_doc` | `tipo_documento` | NN | — | Tipo de documento (`DNI`, `CUIT`, `CUIL`, `PASAPORTE`) |
| `nro_doc` | `varchar(20)` | NN | — | Número de documento |
| `direccion` | `varchar(200)` | NN | — | Dirección |
| `id_localidad` | `integer` | NN | FK → `localidad` | Localidad del cliente |
| `fecha_alta` | `date` | NN | — | Fecha de alta |
| `descuento` | `dom_porcentaje` | NN | — | Descuento por defecto (RN-06: lo fija `fn_descuento_cliente`) |
| `email` | `dom_email` | N | — | Correo electrónico |
| `telefono` | `dom_telefono` | N | — | Teléfono |

#### socio (subtipo, sin atributos propios)

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_cliente` | `integer` | NN | PK, FK → `cliente` | Cliente que es socio |

#### distribuidor (subtipo)

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_cliente` | `integer` | NN | PK, FK → `cliente` | Cliente que es distribuidor |
| `zona_cobertura` | `varchar(120)` | NN | — | Zona de cobertura |
| `nro_habilitacion` | `varchar(30)` | NN | — | Número de habilitación |

#### exportador (subtipo)

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_cliente` | `integer` | NN | PK, FK → `cliente` | Cliente que es exportador |
| `pais_destino` | `varchar(80)` | NN | — | País de destino principal |

#### permiso_exportacion (entidad débil de exportador, RN-07)

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `id_cliente` | `integer` | NN | PK, FK → `exportador` | Exportador (parte de la PK compuesta) |
| `codigo` | `varchar(30)` | NN | PK | Código del permiso (parte de la PK compuesta) |
| `fecha_emision` | `date` | NN | — | Fecha de emisión |
| `fecha_vencimiento` | `date` | NN | — | Fecha de vencimiento |

---

### 3.10 Comprobantes de venta

#### comprobante

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `nro_comprobante` | `integer` | NN | PK (identity) | Número de comprobante |
| `fecha` | `date` | NN | — | Fecha del comprobante |
| `id_cliente` | `integer` | NN | FK → `cliente` | Cliente comprador |
| `id_sala` | `integer` | NN | FK → `sala_venta` | Sala donde se vendió |
| `subtotal` | `dom_dinero` | NN | — | Subtotal (mantenido por trigger/función, RN-08) |
| `descuento` | `dom_dinero` | NN | — | Descuento importe (mantenido por trigger/función, RN-08) |
| `total` | `dom_dinero` | NN | — | Total (mantenido por trigger/función, RN-08) |

#### renglon_comprobante (renglón de comprobante de venta)

| Columna | Tipo | Nulo? | PK/FK | Descripción |
|---------|------|-------|-------|-------------|
| `nro_comprobante` | `integer` | NN | PK, FK → `comprobante` | Comprobante (parte de la PK compuesta) |
| `cod_vino` | `integer` | NN | PK, FK → `vino` | Vino (parte de la PK compuesta) |
| `cantidad` | `dom_cantidad` | NN | — | Cantidad vendida |
| `precio_unitario` | `dom_dinero` | NN | — | Precio unitario al momento de la venta |
| `descuento_aplicado` | `dom_porcentaje` | NN | — | % de descuento aplicado según tipo de cliente |
| `subtotal` | `dom_dinero` | NN | — | `cantidad * precio * (1 - desc/100)` |

---

## 4. Resumen de decisiones de mapeo reflejadas en el diccionario

| Decisión | Cómo se materializa en el esquema |
|----------|-----------------------------------|
| Jerarquía de clientes | Supertipo `cliente` + subtipos `socio`, `distribuidor`, `exportador` con PK compartida (`id_cliente`) y discriminador `tipo_cliente`. `socio` no agrega atributos propios. |
| Entidad débil `parcela` | PK compuesta `(id_finca, nro_parcela)` con FK a `finca`. |
| Entidad débil `permiso_exportacion` | PK compuesta `(id_cliente, codigo)` con FK a `exportador`. |
| Relaciones N:M con atributos | `vino_cepa` (atributo `porcentaje`), `renglon_ingreso`, `renglon_transferencia`, `renglon_comprobante` (renglones con atributos de cantidad/precio/subtotal). |
| Relaciones N:M sin atributos | `vino_maridaje`, `transportista_localidad`. |
| Importes monetarios | `NUMERIC` (dominios `dom_dinero`), nunca `FLOAT`. |
| Estados y clasificaciones | Tipos enumerados (`estado_documento`, `tipo_vino`, `tipo_cepa`, `tipo_cliente`, `tipo_documento`, `dia_semana`), nunca texto libre. |
