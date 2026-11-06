# Informe Etapa 2 — Integridad y lógica en la base de datos

**Proyecto:** Bodegas del Atuel — TP Integrador de Bases de Datos (UTN FRSR)  
**Etapa:** 2 — Integridad y lógica en la base  
**Pasos completados:** 002_constraints, 003_funciones, 004_procedimientos, 005_triggers, 006_vistas, 007_roles, tests/db_tests.sql, demostración de concurrencia.  
**Estado:** Etapa 2 completa.

---

## Paso 1 — `002_constraints.sql` — Restricciones de integridad

### 1. UNIQUE adicionales (más allá de PK)

| Tabla | Restricción UNIQUE | Columnas |
|-------|-------------------|----------|
| provincia | uq_provincia_nombre | nombre |
| departamento | uq_departamento_provincia_nombre | id_provincia, nombre |
| localidad | uq_localidad_provincia_nombre_cp | id_provincia, nombre, codigo_postal |
| bodega | uq_bodega_cuit | cuit |
| transportista | uq_transportista_cuit | cuit |
| empleado | uq_empleado_cuit | cuit |
| cepa | uq_cepa_nombre | nombre |
| maridaje | uq_maridaje_nombre | nombre |
| lote_uva | uq_lote_uva_parcela_campania | id_finca, nro_parcela, campania |
| vino | uq_vino_nombre_anada_volumen | nombre, anada, volumen_ml |
| cliente | uq_cliente_tipo_doc_nro_doc | tipo_doc, nro_doc |
| permiso_exportacion | uq_permiso_exportacion_codigo | codigo |

**Total:** 12 UNIQUE adicionales.

### 2. CHECK (20+ restricciones, incluyendo uno entre columnas)

| Regla | Restricción | Tabla | Condición |
|-------|-------------|-------|-----------|
| RN-01 | chk_vino_precio_positivo | vino | precio > 0 |
| RN-15 | chk_vino_graduacion_rango | vino | graduacion BETWEEN 5 AND 20 |
| RN-15 | chk_vino_volumen_valido | vino | volumen_ml IN (187, 375, 750, 1000, 1500, 3000) |
| | chk_finca_superficie_positiva | finca | superficie_ha > 0 |
| | chk_parcela_superficie_positiva | parcela | superficie_ha > 0 |
| RN-15 | chk_lote_kilos_positivos | lote_uva | kilos_cosechados > 0 |
| | chk_stock_sala_cantidad_no_negativa | stock_sala | cantidad >= 0 |
| | chk_stock_deposito_cantidad_no_negativa | stock_deposito | cantidad >= 0 |
| | chk_renglon_ingreso_cantidad_positiva | renglon_ingreso | cantidad > 0 |
| | chk_renglon_transferencia_cantidad_positiva | renglon_transferencia | cantidad > 0 |
| | chk_renglon_comprobante_cantidad_positiva | renglon_comprobante | cantidad > 0 |
| RN-05 | chk_vino_cepa_porcentaje_rango | vino_cepa | porcentaje BETWEEN 0 AND 100 |
| RN-06 | chk_cliente_descuento_rango | cliente | descuento BETWEEN 0 AND 100 |
| | chk_renglon_comprobante_descuento_rango | renglon_comprobante | descuento_aplicado BETWEEN 0 AND 100 |
| RN-07 | chk_permiso_vencimiento_posterior | permiso_exportacion | fecha_vencimiento > fecha_emision |
| | chk_analisis_brix_positivo | analisis_calidad | brix > 0 |
| | chk_analisis_ph_positivo | analisis_calidad | ph > 0 |
| | chk_analisis_acidez_positiva | analisis_calidad | acidez_total > 0 |
| | chk_empleado_salario_positivo | empleado | salario > 0 |

**Total:** 20+ CHECK, incluyendo uno entre columnas (`fecha_vencimiento > fecha_emision` en `permiso_exportacion`).

### 3. DEFAULT (al menos 3)

| Tabla | Columna | Valor por defecto |
|-------|---------|-------------------|
| ingreso | estado | 'en_confeccion' |
| transferencia | estado | 'en_confeccion' |
| cliente | fecha_alta | CURRENT_DATE |
| transferencia | fecha_confeccion | CURRENT_DATE |
| stock_sala | cantidad | 0 |
| stock_deposito | cantidad | 0 |

**Total:** 6 DEFAULT (superan el mínimo de 3).

### 4. Acciones referenciales ON DELETE / ON UPDATE

Todas las FK usan `ON UPDATE NO ACTION`. Se droparon y re-crearon las FK para definir `ON DELETE`:

- **RESTRICT (mayoría):** catálogos, bodega con movimientos (RN-14), vino con movimientos (RN-14), localidad con dependientes, historial de cosechas, documentos y personal no se pierden.
- **CASCADE:** renglones sin cabecera, subtipos sin cliente, composición sin vino, stock sin sala, análisis sin lote, cobertura sin transportista.

---

## Paso 2 — `003_funciones.sql` — 4 funciones de base de datos

| Función | Parámetros | Retorna | Volatilidad | Propósito |
|---------|-----------|---------|-------------|-----------|
| `fn_total_comprobante` | `p_nro_comprobante integer` | `numeric(12,2)` | STABLE | Calcula el total de un comprobante sumando subtotales de renglones (RN-08) |
| `fn_stock_sala` | `p_id_sala integer, p_cod_vino integer` | `integer` | STABLE | Devuelve stock de un vino en una sala (RN-09: validar stock antes de vender) |
| `fn_descuento_cliente` | `p_tipo_cliente tipo_cliente` | `numeric(5,2)` | IMMUTABLE | Devuelve descuento por tipo: socio 10%, distribuidor 20%, exportador 30% (RN-06) |
| `fn_antiguedad_anios` | `p_fecha_ingreso date` | `integer` | STABLE | Calcula años completos de antigüedad de un empleado (consulta U2) |

---

## Paso 3 — `004_procedimientos.sql` — 2 procedimientos transaccionales

| Procedimiento | Parámetro | Propósito |
|---------------|-----------|-----------|
| `sp_procesar_ingreso` | `p_cod_ingreso integer` | Procesa un ingreso al depósito central. Valida estado 'terminado', bloquea renglones con FOR UPDATE, suma al stock_deposito, cambia estado a 'procesado' (RN-10). Todo o nada con ROLLBACK automático. |
| `sp_procesar_transferencia` | `p_nro_solicitud integer` | Procesa una transferencia del depósito a una sala. Valida estado 'terminado', verifica stock suficiente (RN-11), descuenta del depósito y suma a la sala, cambia estado a 'procesado'. Todo o nada con ROLLBACK automático. |

Ambos usan `FOR UPDATE` para bloquear filas y garantizan consistencia (todo o nada).

---

## Paso 4 — `005_triggers.sql` — 8 triggers

| # | Trigger | Tabla | Tipo | Regla de negocio |
|---|---------|-------|------|------------------|
| 1 | `trg_chk_porcentajes_vino_cepa` | `vino_cepa` | CONSTRAINT DEFERRABLE | RN-05: suma de porcentajes de corte = 100 |
| 2 | `trg_validar_stock_venta` | `renglon_comprobante` | BEFORE INSERT | RN-09: validar stock suficiente en sala antes de vender |
| 3 | `trg_descontar_stock_y_calcular_totales` | `renglon_comprobante` | AFTER INSERT | RN-08/RN-09: descuento de stock y cálculo de totales del comprobante |
| 4 | `trg_bloquear_renglones_ingreso` | `renglon_ingreso` | BEFORE I/U/D | RN-12: bloquear cambios si el ingreso no está en confección |
| 5 | `trg_bloquear_renglones_transferencia` | `renglon_transferencia` | BEFORE I/U/D | RN-12: bloquear cambios si la transferencia no está en confección |
| 6 | `trg_fecha_confeccion_transferencia` | `transferencia` | BEFORE I/U | RN-11: forzar fecha de confección = actual, prohibir modificarla |
| 7 | `trg_auditoria_precio_vino` | `vino` | AFTER UPDATE | RN-13: registrar auditoría de cambios de precio |
| 8 | `trg_coherencia_cliente_subtipo` | `cliente` | AFTER I/U | Jerarquía cliente: discriminador debe coincidir con tabla de subtipo |

**Mínimos cumplidos:** ≥6 triggers (hay 8), ≥1 BEFORE (hay 5), ≥1 AFTER (hay 3), ≥1 constraint trigger diferido (hay 1: trg_chk_porcentajes_vino_cepa).

---

## Paso 5 — `006_vistas.sql` — 3 vistas

| Vista | Tipo | Propósito |
|-------|------|-----------|
| `mv_stock_total_por_vino` | MATERIALIZED VIEW | Stock total por vino = depósito central + salas. Tiene índice único en `cod_vino`. |
| `vw_ventas_mensuales_por_sala` | VIEW | Ventas mensuales por sala (últimos 12 meses): cant. comprobantes, botellas vendidas, monto total. |
| `vw_documentos_pendientes` | VIEW | Ingresos y transferencias en estados 'en_confeccion' o 'terminado', con bodega_origen y transportista. |

---

## Paso 6 — `007_roles.sql` — 3 roles y privilegios mínimos

| Rol | Privilegios |
|-----|-------------|
| `bodegas_owner` | ALL sobre esquema, tablas, secuencias, funciones, procedimientos (propietario) |
| `app_rw` | SELECT/INSERT/UPDATE/DELETE en tablas de negocio, USAGE en secuencias, EXECUTE en funciones/procedimientos (usa la API) |
| `reporte_ro` | SELECT en tablas y vistas (solo lectura para reportes) |

Se aplicó `REVOKE ALL ON SCHEMA public FROM PUBLIC` y todos los privilegios de tablas/secuencias/funciones/procedimientos de PUBLIC. Las contraseñas se inyectan vía variables de entorno (`@OWNER_PASSWORD@`, `@APP_PASSWORD@`, `@RO_PASSWORD@`), nunca escritas en el archivo.

---

## Paso 7 — `tests/db_tests.sql` — Pruebas de reglas de negocio

Pruebas SQL para RN-01 a RN-15. Todas las NOTICE "OK" verificadas con Docker. Cada regla tiene un mecanismo y un caso de prueba; los casos que deben fallar fallan con error claro, y los que deben funcionar, funcionan.

---

## Paso 8 — Demostración de concurrencia

Informe en `docs/informes/informe_final.md` (sección 8 y capítulo de capturas). 4 capturas: stock inicial, terminal 1 sin FOR UPDATE, terminal 2 sin FOR UPDATE, terminal 2 con FOR UPDATE. Demuestra que sin FOR UPDATE se pierden actualizaciones y con FOR UPDATE se mantiene la consistencia (todo o nada).

---

## Conclusión de la Etapa 2

La Etapa 2 implementó integridad y lógica en la base: 12 UNIQUE, 20+ CHECK (incluyendo uno entre columnas), 6 DEFAULT, acciones referenciales en todas las FK, 4 funciones, 2 procedimientos transaccionales con FOR UPDATE, 8 triggers (incluyendo 1 constraint diferido), 3 vistas (1 materializada), 3 roles con privilegios mínimos y revocación de PUBLIC, pruebas para RN-01 a RN-15, y demostración de concurrencia. Todos los mínimos de la tabla de requisitos del enunciado se cumplen.

---

## Archivos relacionados
- `db/migrations/002_constraints.sql` — UNIQUE, CHECK, DEFAULT, acciones referenciales.
- `db/migrations/003_funciones.sql` — 4 funciones.
- `db/migrations/004_procedimientos.sql` — 2 procedimientos transaccionales.
- `db/migrations/005_triggers.sql` — 8 triggers.
- `db/migrations/006_vistas.sql` — 3 vistas.
- `db/migrations/007_roles.sql` — 3 roles y privilegios.
- `db/tests/db_tests.sql` — Pruebas RN-01 a RN-15.
- `docs/informes/Paso 8 Capturas/` — Capturas de la demostración de concurrencia.