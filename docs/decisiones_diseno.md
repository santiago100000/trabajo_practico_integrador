# Decisiones de diseño

**TPI Bases de Datos · Bodegas del Atuel · Etapa 1 (Modelado)**

A continuación se justifican las decisiones de diseño tomadas para el modelo de datos, tal como se pide en la sección 5 del enunciado del TPI.

## 1. Jerarquía de clientes

| Estrategia | Ventajas | Desventajas |
|------------|----------|-------------|
| Tabla única con columna de tipo | Consultas simples, sin joins | Muchos NULL (zona y habilitación solo existen en distribuidores, país solo en exportadores); los `NOT NULL` por subtipo no se pueden declarar |
| Una tabla por subtipo (sin supertipo) | Sin NULL | Las FK de `comprobante` no pueden apuntar a un único cliente; consultas sobre todos los clientes requieren `UNION` |
| **Supertipo + subtipos (elegida)** | Las FK a `cliente` son únicas; atributos propios con `NOT NULL`; sin NULL innecesarios | Requiere joins para datos del subtipo; hay que asegurar que el discriminador coincida con la tabla de subtipo |

Se eligió **supertipo `cliente` + subtipos `socio`, `distribuidor`, `exportador`** porque `comprobante` referencia a cualquier cliente y cada subtipo tiene atributos obligatorios propios (zona y habilitación en distribuidor, país en exportador). La columna `tipo_cliente` (enumerado) actúa como discriminador. La tabla `socio` no tiene atributos propios, pero se mantiene para representar el subtipo y permitir agregar datos del club sin rediseñar. La coherencia entre `tipo_cliente` y la tabla de subtipo se verificará en la etapa 2 con un trigger.

## 2. Claves naturales vs subrogadas

| Entidad | Clave elegida | Justificación |
|---------|---------------|---------------|
| localidad | `id_localidad` (subrogada) | El código postal no identifica una localidad: puede repetirse entre localidades y el nombre puede repetirse entre provincias. |
| bodega, transportista, empleado | Subrogada + `cuit` único | El CUIT es un identificador válido pero largo, se replica en muchas FK y podría corregirse; la subrogada es estable y liviana. |
| vino | `cod_vino` (subrogada) + `UNIQUE (nombre, anada, volumen_ml)` | El enunciado habla de «un código»; la clave natural compuesta se protege con `UNIQUE`. |
| parcela | Compuesta (`id_finca`, `nro_parcela`) | Entidad débil: el número solo identifica dentro de la finca. |
| lote, comprobante, ingreso, transferencia | Número generado | El enunciado los define como número o código de documento; los genera la base y no se cargan a mano. |
| renglones, vino_cepa, stock | Compuesta | Identifican de forma natural cada par cabecera-vino o sala-vino. |
| permiso_exportacion | Compuesta (`id_cliente`, `codigo`) | Entidad débil del exportador. |

## 3. Tipos de datos

- **Dinero:** `NUMERIC(12,2)` (dominio `dom_dinero`), nunca `FLOAT`. Los porcentajes usan `NUMERIC(5,2)`.
- **Fechas:** `DATE` para fechas de negocio; `TIMESTAMP` solo en la auditoría de precios, donde importa la hora.
- **Estados y clasificaciones:** tipos enumerados (`estado_documento`, `tipo_vino`, `tipo_cepa`, `tipo_cliente`, `tipo_documento`, `dia_semana`) en lugar de texto libre.
- **CUIT:** dominio `dom_cuit` = `CHAR(11)` con `CHECK` de 11 dígitos, reutilizado en bodega, transportista y empleado.
- **Identificadores:** `GENERATED ALWAYS AS IDENTITY`, para que nadie pueda forzar un valor a mano.

## 4. Atributos derivados

| Atributo | Decisión | Cómo se garantiza la consistencia |
|----------|----------|-----------------------------------|
| `renglon_comprobante.subtotal` | Se almacena | Lo calcula un trigger a partir de cantidad, precio y descuento |
| `comprobante.subtotal`, `descuento`, `total` | Se almacenan | `fn_total_comprobante` + trigger AFTER INSERT en el renglón (RN-08) y consulta de control |
| `cliente.descuento` | Se almacena | Valor por defecto con `fn_descuento_cliente` y `CHECK` de rango (RN-06) |
| Stock total de un vino (depósito + salas) | Se calcula | Vista, para no duplicar los stocks |
| Antigüedad de un empleado | Se calcula | `fn_antiguedad_anios` a partir de `fecha_ingreso` |
| Rendimiento kg/ha de una parcela | Se calcula | Consulta S10 |

## 5. Acciones referenciales

Las claves primarias son subrogadas y nunca se modifican, por lo que `ON UPDATE` queda en `NO ACTION` en todas las FK. Para `ON DELETE`:

| Clave foránea | ON DELETE | Motivo |
|---------------|-----------|--------|
| `vino → bodega`, `ingreso → bodega`, `lote_uva → bodega` | RESTRICT | RN-14: no se borra una bodega con movimientos |
| `ingreso → transportista` | RESTRICT | RN-14 |
| `renglon_* → vino`, `stock_* → vino`, `auditoria_precio → vino` | RESTRICT | RN-14: no se borra un vino con movimientos ni se pierde su historia de precios |
| `renglon_ingreso → ingreso`, `renglon_transferencia → transferencia`, `renglon_comprobante → comprobante` | CASCADE | Un renglón no existe sin su cabecera |
| `analisis_calidad → lote_uva` | CASCADE | El análisis no existe sin su lote |
| `socio`, `distribuidor`, `exportador → cliente`; `permiso_exportacion → exportador` | CASCADE | El subtipo y los permisos no existen sin su cliente |
| `vino_cepa → vino`, `vino_maridaje → vino` | CASCADE | La composición y los maridajes pertenecen al vino |
| `vino_cepa → cepa`, `vino_maridaje → maridaje`, `parcela → cepa` | RESTRICT | No se borra una cepa o maridaje en uso |
| `transportista_localidad → transportista` | CASCADE | La cobertura pertenece al transportista |
| `transportista_localidad → localidad`, `sala_venta → localidad`, `cliente → localidad` | RESTRICT | Hay datos que dependen de la localidad |
| `parcela → finca`, `lote_uva → parcela` | RESTRICT | Se conserva el historial de cosechas |
| `empleado → sala_venta`, `transferencia → sala_venta`, `comprobante → sala_venta`, `comprobante → cliente` | RESTRICT | Documentos y personal no se pierden por borrar su sala o cliente |
| `stock_sala → sala_venta` | CASCADE | El stock no existe sin la sala |
| `finca → departamento`, `departamento → provincia`, `localidad → provincia` | RESTRICT | Tablas de catálogo |

## 6. Supuestos tomados del enunciado

- Existe un único depósito central, por eso no hay tabla de depósito y `stock_deposito` se identifica solo por vino.
- `comprobante.descuento` es un **importe**, y el porcentaje aplicado vive en cada renglón.
- Los datos extra que no pide el enunciado (`empleado.apellido`, `cliente.email` y `telefono`, `observaciones` en ingresos y transferencias) son opcionales y no afectan las reglas.
- Las restricciones `UNIQUE`, `CHECK`, `DEFAULT` y las acciones referenciales se declaran en `002_constraints.sql`; el `001_esquema.sql` contiene tipos, dominios, tablas, PK y FK.
