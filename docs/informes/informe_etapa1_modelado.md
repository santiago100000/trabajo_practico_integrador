# Informe Etapa 1 — Modelado (Diseño del esquema relacional)

**Proyecto:** Bodegas del Atuel — TP Integrador de Bases de Datos (UTN FRSR)  
**Etapa:** 1 — Modelado  
**Pasos completados:** Diseño del esquema relacional, normalización, diccionario de datos, decisiones de diseño.  
**Estado:** Etapa 1 completa.  
**Archivo relacionado:** `db/migrations/001_esquema.sql` (tipos, dominios, tablas, PK y FK).

---

## Paso 1 — Análisis del DER y reglas de negocio

El modelo parte de un DER con 25 tablas y 6 tipos enumerados. Se aplicaron las reglas de mapeo del DER al esquema relacional:

| Regla de mapeo | Aplicación en el esquema |
|----------------|--------------------------|
| Entidad fuerte → tabla con PK | `provincia`, `departamento`, `localidad`, `bodega`, `finca`, `cepa`, `vino`, `maridaje`, `sala_venta`, `empleado`, `cliente`, `transportista`, `ingreso`, `transferencia`, `comprobante`, `stock_deposito` |
| Relación 1:N → FK en el lado N | `empleado.id_sala`, `vino.id_bodega`, `parcela.id_departamento`, `lote_uva.id_bodega`, etc. |
| Relación N:M → tabla intermedia con PK compuesta | `vino_cepa`, `vino_maridaje`, `stock_sala`, `transportista_localidad`, `renglon_ingreso`, `renglon_transferencia`, `renglon_comprobante` |
| Entidad débil → PK hereda de la fuerte | `parcela (id_finca, nro_parcela)`, `permiso_exportacion (id_cliente, codigo)` |
| Jerarquía de clientes | Supertipo `cliente` + subtipos `socio`, `distribuidor`, `exportador` (PK compartida + discriminador `tipo_cliente`) |

---

## Paso 2 — Tipos enumerados y dominios

Se definieron 6 tipos enumerados (ningún estado o clasificación se modela como texto libre):

| Tipo enumerado | Valores | Usado en |
|----------------|---------|----------|
| `estado_documento` | en_confeccion, terminado, procesado | `ingreso.estado`, `transferencia.estado` |
| `tipo_vino` | tinto, blanco, rosado, espumante | `vino.tipo` |
| `tipo_cepa` | tinta, blanca | `cepa.tipo` |
| `tipo_cliente` | socio, distribuidor, exportador | `cliente.tipo_cliente` (discriminador) |
| `tipo_documento` | DNI, CUIT, CUIL, PASAPORTE | `cliente.tipo_doc` |
| `dia_semana` | lunes, martes, miercoles, jueves, viernes, sabado, domingo | `sala_venta.dia_cierre` |

Se definieron 7 dominios reutilizables:

| Dominio | Definición | Usado en |
|---------|-----------|----------|
| `dom_cuit` | `char(11) CHECK (VALUE ~ '^[0-9]{11}$')` | `empleado.cuit`, `bodega.cuit`, `transportista.cuit` |
| `dom_email` | `varchar(120)` | `cliente.email`, `transportista.email` |
| `dom_telefono` | `varchar(30)` | `cliente.telefono`, `transportista.telefono` |
| `dom_dinero` | `numeric(12,2)` | precios, salario, subtotales, totales, auditoría |
| `dom_porcentaje` | `numeric(5,2)` | `vino_cepa.porcentaje`, `cliente.descuento`, `renglon_comprobante.descuento_aplicado` |
| `dom_superficie` | `numeric(10,2)` | `finca.superficie_ha`, `parcela.superficie_ha` |
| `dom_cantidad` | `integer` | stocks, renglones de ingreso/transferencia/comprobante |

Los importes usan `NUMERIC`, nunca `FLOAT`, para evitar errores de punto flotante en cálculos de dinero.

---

## Paso 3 — Diccionario de datos

El diccionario de datos (`docs/diccionario_datos.md`) documenta cada tabla, columna, tipo, nulabilidad, PK/FK y descripción. Cubre 25 tablas organizadas en 10 grupos:

1. **Geografía:** `provincia`, `departamento`, `localidad`
2. **Salas y empleados:** `sala_venta`, `empleado`
3. **Bodegas y producción de uva:** `bodega`, `finca`, `cepa`, `parcela`, `lote_uva`, `analisis_calidad`
4. **Vinos:** `vino`, `vino_cepa`, `maridaje`, `vino_maridaje`, `auditoria_precio`
5. **Stock:** `stock_sala`, `stock_deposito`
6. **Transportistas:** `transportista`, `transportista_localidad`
7. **Ingresos:** `ingreso`, `renglon_ingreso`
8. **Transferencias:** `transferencia`, `renglon_transferencia`
9. **Clientes (jerarquía):** `cliente`, `socio`, `distribuidor`, `exportador`, `permiso_exportacion`
10. **Comprobantes de venta:** `comprobante`, `renglon_comprobante`

---

## Paso 4 — Normalización (1FN, 2FN, 3FN)

### Primera forma normal (1FN)
Todos los atributos son atómicos y no hay grupos repetidos. La dirección compuesta se descompuso en `calle` y `numero`. Las relaciones N:M se resolvieron con tablas intermedias, de modo que ninguna celda guarda listas.

### Segunda forma normal (2FN)
Solo las tablas con clave compuesta pueden tener dependencias parciales, y en ninguna un atributo no clave depende de una parte de la clave:
- `parcela`: `superficie_ha`, `anio_plantacion` e `id_cepa` dependen de la clave completa `(id_finca, nro_parcela)`.
- `vino_cepa`, `stock_sala`, renglones: los atributos dependen del par completo de la PK compuesta.

### Tercera forma normal (3FN)
No quedan dependencias transitivas entre atributos no clave:
- `finca → departamento → provincia`: se extrajeron `provincia` y `departamento` a tablas propias.
- `cliente.descuento`: `tipo_cliente` da el valor por defecto (vía `fn_descuento_cliente`), pero no determina el descuento individual del cliente.
- Maridaje: `temperatura_servicio` depende de `id_maridaje`, no del par vino-maridaje.

### Excepción controlada: atributos derivados
`comprobante.subtotal`, `comprobante.total`, `comprobante.descuento` y `renglon_comprobante.subtotal` se almacenan (salen estrictamente de 3FN) por tres razones: el enunciado los incluye, el comprobante es un documento histórico que no debe cambiar, y evita recalcular sobre cientos de miles de renglones. La consistencia se garantiza con `fn_total_comprobante` + trigger AFTER INSERT (RN-08).

---

## Paso 5 — Decisiones de diseño (sección 5 del enunciado)

### 5.1 Jerarquía de clientes
Se eligió **supertipo `cliente` + subtipos** porque `comprobante` referencia a cualquier cliente y cada subtipo tiene atributos obligatorios propios (zona/habilitación en distribuidor, país en exportador). La tabla `socio` no tiene atributos propios pero se mantiene para representar el subtipo.

### 5.2 Claves naturales vs subrogadas
| Entidad | Clave elegida | Justificación |
|---------|---------------|---------------|
| localidad | `id_localidad` (subrogada) | El código postal no identifica una localidad. |
| bodega, transportista, empleado | Subrogada + `cuit` único | El CUIT es largo y se replica en muchas FK. |
| vino | `cod_vino` (subrogada) + `UNIQUE (nombre, anada, volumen_ml)` | Clave natural compuesta protegida con UNIQUE. |
| parcela | Compuesta (`id_finca`, `nro_parcela`) | Entidad débil. |
| lote, comprobante, ingreso, transferencia | Número generado (IDENTITY) | La base genera el número, no se carga a mano. |
| renglones, vino_cepa, stock | Compuesta | Identifican naturalmente cada par. |
| permiso_exportacion | Compuesta (`id_cliente`, `codigo`) | Entidad débil del exportador. |

### 5.3 Tipos de datos
- **Dinero:** `NUMERIC(12,2)` (dominio `dom_dinero`), nunca `FLOAT`.
- **Fechas:** `DATE` para fechas de negocio; `TIMESTAMP` solo en auditoría de precios.
- **Estados/clasificaciones:** tipos enumerados, nunca texto libre.
- **CUIT:** dominio `dom_cuit` = `CHAR(11)` con CHECK de 11 dígitos.
- **Identificadores:** `GENERATED ALWAYS AS IDENTITY`.

### 5.4 Acciones referenciales (ON DELETE)
Todas las FK usan `ON UPDATE NO ACTION`. Para `ON DELETE`:
- **RESTRICT:** catálogos, bodega con movimientos, vino con movimientos, localidad con datos dependientes, historial de cosechas, documentos/personal no se pierden.
- **CASCADE:** renglones sin cabecera, subtipos sin cliente, composición sin vino, stock sin sala, análisis sin lote, cobertura sin transportista.

### 5.5 Supuestos tomados
- Un único depósito central: `stock_deposito` se identifica solo por vino.
- `comprobante.descuento` es un importe; el porcentaje vive en cada renglón.
- Datos extra (`empleado.apellido`, `cliente.email`/`telefono`, `observaciones`) son opcionales.
- Las restricciones UNIQUE/CHECK/DEFAULT y acciones referenciales se declaran en `002_constraints.sql`; `001_esquema.sql` contiene tipos, dominios, tablas, PK y FK.

---

## Conclusión de la Etapa 1

El esquema relacional modela 25 tablas con 6 tipos enumerados y 7 dominios, alcanzando 3FN con una excepción controlada (atributos derivados de comprobante). Se documentaron decisiones de diseño sobre jerarquía de clientes, claves, tipos de datos, acciones referenciales y supuestos. El esquema físico está en `db/migrations/001_esquema.sql` y listo para aplicar.

---

## Archivos relacionados
- `docs/esquema_relacional.md` — Esquema relacional completo en DBML.
- `docs/diccionario_datos.md` — Diccionario de datos detallado por tabla.
- `docs/normalizacion.md` — Justificación de normalización y decisiones de diseño.
- `docs/decisiones_diseno.md` — Decisiones de diseño (sección 5 del enunciado).
- `db/migrations/001_esquema.sql` — Esquema físico (tipos, dominios, tablas, PK, FK).

El modelo parte de un DER con 25 tablas y 6 tipos enumerados. Se aplicaron las reglas de mapeo del DER al esquema relacional:

| Regla de mapeo | Aplicación en el esquema |
|----------------|--------------------------|
| Entidad fuerte → tabla con PK | `provincia`, `departamento`, `localidad`, `bodega`, `finca`, `cepa`, `vino`, `maridaje`, `sala_venta`, `empleado`, `cliente`, `transportista`, `ingreso`, `transferencia`, `comprobante`, `stock_deposito` |
| Relación 1:N → FK en el lado N | `empleado.id_sala`, `vino.id_bodega`, `parcela.id_departamento`, `lote_uva.id_bodega`, etc. |
| Relación N:M → tabla intermedia con PK compuesta | `vino_cepa`, `vino_maridaje`, `stock_sala`, `transportista_localidad`, `renglon_ingreso`, `renglon_transferencia`, `renglon_comprobante` |
| Entidad débil → PK hereda de la fuerte | `parcela (id_finca, nro_parcela)`, `permiso_exportacion (id_cliente, codigo)` |
| Jerarquía de clientes | Supertipo `cliente` + subtipos `socio`, `distribuidor`, `exportador` (PK compartida + discriminador `tipo_cliente`) |

---
