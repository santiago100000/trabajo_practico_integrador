# Justificación de normalización y decisiones de diseño

**TPI Bases de Datos · Bodegas del Atuel · Etapa 1 (Modelado)**

## 1. Del DER al esquema relacional: reglas aplicadas

- **Entidad fuerte:** una tabla con su identificador como clave primaria.
- **Atributo compuesto:** se descompone en atributos simples (la dirección de la sala pasa a `calle` y `numero`).
- **Relación 1:N:** la clave foránea va del lado N (por ejemplo `empleado.id_sala`, `vino.id_bodega`, `parcela.id_cepa`).
- **Relación N:M:** tabla intermedia con clave primaria compuesta y los atributos de la relación (`vino_cepa`, `vino_maridaje`, `stock_sala`, `transportista_localidad` y los renglones).
- **Entidad débil:** la clave hereda la de la entidad fuerte. `parcela` tiene clave (`id_finca`, `nro_parcela`) y `permiso_exportacion` tiene clave (`id_cliente`, `codigo`).
- **Jerarquía de clientes:** supertipo `cliente` y un subtipo por tabla (`socio`, `distribuidor`, `exportador`), cuya clave primaria es a la vez clave foránea al supertipo.

## 2. Dependencias funcionales relevantes

| Tabla | Dependencias funcionales |
| --- | --- |
| localidad | `id_localidad → id_provincia, nombre, codigo_postal, encargado_regional` |
| departamento | `id_departamento → id_provincia, nombre` |
| sala\_venta | `id_sala → id_localidad, calle, numero, dia_cierre` |
| empleado | `id_empleado → id_sala, cuit, nombre, apellido, fecha_ingreso, salario` |
| finca | `id_finca → id_departamento, nombre, superficie_ha` |
| parcela | `(id_finca, nro_parcela) → id_cepa, superficie_ha, anio_plantacion` |
| lote\_uva | `nro_lote → id_finca, nro_parcela, campania, fecha_cosecha, kilos_cosechados, id_bodega`; clave candidata `(id_finca, nro_parcela, campania)` |
| analisis\_calidad | `id_analisis → nro_lote, fecha_analisis, brix, ph, acidez_total` |
| vino | `cod_vino → id_bodega, nombre, tipo, anada, volumen_ml, graduacion, precio`; clave candidata `(nombre, anada, volumen_ml)` |
| vino\_cepa | `(cod_vino, id_cepa) → porcentaje` |
| maridaje | `id_maridaje → nombre, temperatura_servicio` |
| stock\_sala | `(id_sala, cod_vino) → cantidad` |
| stock\_deposito | `cod_vino → cantidad` |
| ingreso / transferencia | `cod_ingreso → fecha, estado, cod_transportista, id_bodega` y `nro_solicitud → id_sala, fecha_confeccion, estado` |
| cliente | `id_cliente → tipo_cliente, nombre_razon_social, tipo_doc, nro_doc, direccion, id_localidad, fecha_alta, descuento` |
| comprobante | `nro_comprobante → fecha, id_cliente, id_sala, subtotal, descuento, total` |
| renglon\_comprobante | `(nro_comprobante, cod_vino) → cantidad, precio_unitario, descuento_aplicado, subtotal` |

## 3. Verificación de la normalización

### Primera forma normal (1FN)

Todos los atributos son atómicos y no hay grupos repetidos. La dirección compuesta se descompuso en `calle` y `numero`. Las relaciones N:M (cepas de un vino, maridajes de un vino, localidades que cubre un transportista, renglones) se resolvieron con tablas intermedias, de modo que ninguna celda guarda listas.

### Segunda forma normal (2FN)

Solo las tablas con clave compuesta pueden tener dependencias parciales, y en ninguna un atributo depende de una parte de la clave:

- `parcela`: `superficie_ha`, `anio_plantacion` e `id_cepa` dependen de la clave completa (`id_finca`, `nro_parcela`). No se guarda el nombre de la finca en la parcela porque dependería solo de `id_finca` (dependencia parcial) y se obtiene por la clave foránea.
- `vino_cepa`: `porcentaje` depende del par vino-cepa.
- `stock_sala`: `cantidad` depende del par sala-vino.
- Renglones: `cantidad`, `precio_unitario` y descuentos dependen del par cabecera-vino.

### Tercera forma normal (3FN)

No quedan dependencias transitivas entre atributos no clave:

- **`finca → departamento → provincia`:** si `finca` guardara el nombre del departamento y la provincia, la provincia dependería del departamento y no de la finca. Se extrajeron `provincia` y `departamento` a tablas propias. Cada nombre se guarda una sola vez y se evitan anomalías de actualización.
- **`localidad → encargado_regional`:** el enunciado fija un único encargado por localidad, es decir, el encargado depende de la clave de `localidad`. Como ningún otro atributo de `localidad` lo determina, queda dentro de la tabla sin violar 3FN. Si el encargado pasara a ser una persona con datos propios, se separaría en una entidad.
- **`cliente.descuento`:** a primera vista `tipo_cliente → descuento` (socio 10 %, distribuidor 20 %, exportador 30 %) sería una dependencia transitiva. Pero el descuento es un valor individual que puede apartarse del de su tipo (la consigna U6 sube a 35 % el descuento de ciertos exportadores). Por lo tanto `tipo_cliente` no determina `descuento`: el tipo solo da el valor por defecto, que calcula `fn_descuento_cliente`, y el valor guardado depende del cliente.
- **Maridaje:** la temperatura de servicio depende del maridaje (`id_maridaje → temperatura_servicio`), no del par vino-maridaje, por eso está en `maridaje` y no en `vino_maridaje`.
- **`parcela`:** la cepa es un atributo de la parcela (una sola cepa por parcela), por lo que `id_cepa` es una clave foránea y no hace falta una tabla N:M.

### Excepción controlada: atributos derivados

`comprobante.subtotal`, `comprobante.total`, `comprobante.descuento` y `renglon_comprobante.subtotal` se calculan a partir de otros datos, por lo que estrictamente se salen de 3FN. Se almacenan por tres razones: el enunciado los incluye como atributos y exige la regla RN-08, el comprobante es un documento histórico que no debe cambiar si cambian el precio del vino o el descuento del cliente, y evita recalcular sobre cientos de miles de renglones en los reportes. La consistencia no queda en manos de la API: la función `fn_total_comprobante` y un trigger AFTER INSERT en el renglón los mantienen, y la consulta de control de la etapa 3 verifica que el total coincida con la suma de los renglones.

## 4. Decisiones de diseño (sección 5 del enunciado)

### 4.1 Jerarquía de clientes

| Estrategia | Ventajas | Desventajas |
| --- | --- | --- |
| Tabla única con columna de tipo | Consultas simples, sin joins | Muchos NULL (zona y habilitación solo existen en distribuidores, país solo en exportadores); los `NOT NULL` por subtipo no se pueden declarar |
| Una tabla por subtipo (sin supertipo) | Sin NULL | Las FK de `comprobante` no pueden apuntar a un único cliente; consultas sobre todos los clientes requieren `UNION` |
| **Supertipo + subtipos (elegida)** | Las FK a `cliente` son únicas; atributos propios con `NOT NULL`; sin NULL innecesarios | Requiere joins para datos del subtipo; hay que asegurar que el discriminador coincida con la tabla de subtipo |

Se eligió supertipo más subtipos porque `comprobante` referencia a cualquier cliente y cada subtipo tiene atributos obligatorios propios. La columna `tipo_cliente` (enumerado) actúa como discriminador, y la función de descuento se apoya en ella. La tabla `socio` no tiene atributos propios, pero se mantiene para representar el subtipo y permitir agregar datos del club sin rediseñar. La coherencia entre `tipo_cliente` y la tabla de subtipo se verificará en la etapa 2 con un trigger.

### 4.2 Claves naturales o subrogadas

| Entidad | Clave elegida | Justificación |
| --- | --- | --- |
| localidad | `id_localidad` (subrogada) | El código postal no identifica una localidad: puede repetirse entre localidades y el nombre puede repetirse entre provincias. |
| bodega, transportista, empleado | Subrogada + `cuit` único | El CUIT es un identificador válido pero largo, se replica en muchas FK y podría corregirse; la subrogada es estable y liviana. |
| vino | `cod_vino` (subrogada) + `UNIQUE (nombre, anada, volumen_ml)` | El enunciado habla de «un código»; la clave natural compuesta se protege con `UNIQUE`. |
| parcela | Compuesta (`id_finca`, `nro_parcela`) | Entidad débil: el número solo identifica dentro de la finca. |
| lote, comprobante, ingreso, transferencia | Número generado (`nro_lote`, `nro_comprobante`, `cod_ingreso`, `nro_solicitud`) | El enunciado los define como número o código de documento; los genera la base y no se cargan a mano. |
| renglones, vino\_cepa, stock | Compuesta | Identifican de forma natural cada par cabecera-vino o sala-vino. |
| permiso\_exportacion | Compuesta (`id_cliente`, `codigo`) | Entidad débil del exportador. |

### 4.3 Tipos de datos

- **Dinero:** `NUMERIC(12,2)` (dominio `dom_dinero`), nunca `FLOAT`. Los porcentajes usan `NUMERIC(5,2)`.
- **Fechas:** `DATE` para fechas de negocio; `TIMESTAMP` solo en la auditoría de precios, donde importa la hora.
- **Estados y clasificaciones:** tipos enumerados (`estado_documento`, `tipo_vino`, `tipo_cepa`, `tipo_cliente`, `tipo_documento`, `dia_semana`) en lugar de texto libre.
- **CUIT:** dominio `dom_cuit` = `CHAR(11)` con `CHECK` de 11 dígitos, reutilizado en bodega, transportista y empleado.
- **Identificadores:** `GENERATED ALWAYS AS IDENTITY`, para que nadie pueda forzar un valor a mano.

### 4.4 Atributos derivados

| Atributo | Decisión | Cómo se garantiza la consistencia |
| --- | --- | --- |
| `renglon_comprobante.subtotal` | Se almacena | Lo calcula un trigger a partir de cantidad, precio y descuento |
| `comprobante.subtotal`, `descuento`, `total` | Se almacenan | `fn_total_comprobante` + trigger AFTER INSERT en el renglón (RN-08) y consulta de control |
| `cliente.descuento` | Se almacena | Valor por defecto con `fn_descuento_cliente` y `CHECK` de rango (RN-06) |
| Stock total de un vino (depósito + salas) | Se calcula | Vista, para no duplicar los stocks |
| Antigüedad de un empleado | Se calcula | `fn_antiguedad_anios` a partir de `fecha_ingreso` |
| Rendimiento kg/ha de una parcela | Se calcula | Consulta S10 |

### 4.5 Acciones referenciales

Las claves primarias son subrogadas y nunca se modifican, por lo que `ON UPDATE` queda en `NO ACTION` en todas las FK. Para `ON DELETE`:

| Clave foránea | ON DELETE | Motivo |
| --- | --- | --- |
| `vino → bodega`, `ingreso → bodega`, `lote_uva → bodega` | RESTRICT | RN-14: no se borra una bodega con movimientos |
| `ingreso → transportista` | RESTRICT | RN-14 |
| `renglon_* → vino`, `stock_* → vino`, `auditoria_precio → vino` | RESTRICT | RN-14: no se borra un vino con movimientos ni se pierde su historia de precios |
| `renglon_ingreso → ingreso`, `renglon_transferencia → transferencia`, `renglon_comprobante → comprobante` | CASCADE | Un renglón no existe sin su cabecera (D1 arrastra los renglones) |
| `analisis_calidad → lote_uva` | CASCADE | El análisis no existe sin su lote |
| `socio`, `distribuidor`, `exportador → cliente`; `permiso_exportacion → exportador` | CASCADE | El subtipo y los permisos no existen sin su cliente (D4, D6) |
| `vino_cepa → vino`, `vino_maridaje → vino` | CASCADE | La composición y los maridajes pertenecen al vino |
| `vino_cepa → cepa`, `vino_maridaje → maridaje`, `parcela → cepa` | RESTRICT | No se borra una cepa o maridaje en uso (D2) |
| `transportista_localidad → transportista` | CASCADE | La cobertura pertenece al transportista |
| `transportista_localidad → localidad`, `sala_venta → localidad`, `cliente → localidad` | RESTRICT | Hay datos que dependen de la localidad |
| `parcela → finca`, `lote_uva → parcela` | RESTRICT | Se conserva el historial de cosechas |
| `empleado → sala_venta`, `transferencia → sala_venta`, `comprobante → sala_venta`, `comprobante → cliente` | RESTRICT | Documentos y personal no se pierden por borrar su sala o cliente; D3 borra primero a los empleados |
| `stock_sala → sala_venta` | CASCADE | El stock no existe sin la sala |
| `finca → departamento`, `departamento → provincia`, `localidad → provincia` | RESTRICT | Tablas de catálogo |

## 5. Supuestos tomados del enunciado

- Existe un único depósito central, por eso no hay tabla de depósito y `stock_deposito` se identifica solo por vino.
- `comprobante.descuento` es un **importe**, y el porcentaje aplicado vive en cada renglón.
- Los datos extra que no pide el enunciado (`empleado.apellido`, `cliente.email` y `telefono`, `observaciones` en ingresos y transferencias) son opcionales y no afectan las reglas.
- Las restricciones `UNIQUE`, `CHECK`, `DEFAULT` y las acciones referenciales se declaran en `002_constraints.sql`; el `001_esquema.sql` contiene tipos, dominios, tablas, PK y FK.
