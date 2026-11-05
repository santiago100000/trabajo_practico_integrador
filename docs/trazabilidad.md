# Trazabilidad de reglas de negocio

**TPI Bases de Datos · Bodegas del Atuel · Etapa 2**

Tabla de trazabilidad que vincula cada regla de negocio (RN-01 a RN-15) con su mecanismo de implementación en la base de datos y su caso de prueba en `db/tests/db_tests.sql`.

| RN | Mecanismo esperado (del PDF) | Mecanismo implementado | Caso de prueba |
|----|------------------------------|------------------------|----------------|
| RN-01 | Atributo en vino + CHECK | `CHECK (precio > 0)` en `vino.precio` + `UNIQUE (nombre, anada, volumen_ml)` | `db_tests.sql`: caso que funciona (precio 10000.00) y caso que falla (precio 0.00 → `check_violation`) |
| RN-02 | FK + diseño normalizado (3FN) | `FK sala_venta.id_localidad → localidad.id_localidad` + `localidad.encargado_regional` depende de la clave (3FN) | `db_tests.sql`: sala con localidad válida (OK) y localidad inexistente 999999 (falla → `foreign_key_violation`) |
| RN-03 | FK NOT NULL | `FK empleado.id_sala → sala_venta.id_sala` con `NOT NULL` | `db_tests.sql`: empleado con sala válida (OK), sala inexistente (falla → `foreign_key_violation`), cuit nulo (falla → `not_null_violation`) |
| RN-04 | FK + UNIQUE (parcela, campaña) | `FK lote_uva.(id_finca, nro_parcela) → parcela.(id_finca, nro_parcela)` + `UNIQUE (id_finca, nro_parcela, campania)` | `db_tests.sql`: lote válido (OK) y misma parcela+campaña duplicada (falla → `unique_violation`) |
| RN-05 | Constraint trigger diferido | `CONSTRAINT TRIGGER trg_chk_porcentajes_vino_cepa` DEFERRABLE INITIALLY DEFERRED sobre `vino_cepa` | `db_tests.sql`: porcentajes 85+15=100 (OK) y 50+30≠100 (falla al COMMIT → excepción P0001) |
| RN-06 | Función de descuento + CHECK de rango | `fn_descuento_cliente()` (IMMUTABLE: socio 10%, distribuidor 20%, exportador 30%) + `CHECK (descuento BETWEEN 0 AND 100)` | `db_tests.sql`: descuento 10.00 para socio (OK) y descuento 150.00 (falla → `check_violation`) |
| RN-07 | Tabla de permisos + CHECK entre columnas | Tabla `permiso_exportacion` + `CHECK (fecha_vencimiento > fecha_emision)` | `db_tests.sql`: vencimiento 2025 > emisión 2024 (OK) y vencimiento 2024 < emisión 2025 (falla → `check_violation`) |
| RN-08 | Función de cálculo + trigger | `fn_total_comprobante()` + trigger AFTER INSERT `trg_descontar_stock_y_calcular_totales` sobre `renglon_comprobante` | `db_tests.sql`: comprobante con 2 renglones, total calculado automáticamente = 9000.00 (OK) |
| RN-09 | Trigger BEFORE INSERT + CHECK | `BEFORE INSERT trg_validar_stock_venta` sobre `renglon_comprobante` + `CHECK (cantidad >= 0)` en stocks | `db_tests.sql`: venta con stock suficiente (OK, quedan 98), venta de 999999 (falla → excepción P0001), stock negativo (falla → `check_violation`) |
| RN-10 | Tipo ENUM + trigger de estados + procedimiento | `ENUM estado_documento` + `sp_procesar_ingreso()` (valida estado='terminado', FOR UPDATE, todo o nada) | `db_tests.sql`: ingreso terminado procesado (OK) e ingreso en_confeccion rechazado (falla → excepción P0001) |
| RN-11 | Trigger de estados y de fecha + procedimiento | `BEFORE trg_fecha_confeccion_transferencia` + `sp_procesar_transferencia()` (valida stock en depósito, descuenta y suma a sala) | `db_tests.sql`: transferencia terminada procesada (OK), transferencia en_confeccion rechazada (falla → P0001), modificar fecha de confección rechazada (falla) |
| RN-12 | Trigger sobre los renglones | `BEFORE trg_bloquear_renglones_ingreso` y `trg_bloquear_renglones_transferencia` sobre renglones | `db_tests.sql`: renglón en ingreso en_confección (OK) y renglón en ingreso terminado rechazado (falla → excepción P0001) |
| RN-13 | Trigger AFTER UPDATE + tabla de auditoría | `AFTER UPDATE trg_auditoria_precio_vino` sobre `vino` + tabla `auditoria_precio` | `db_tests.sql`: cambiar precio 10000→12000, verificar registro en `auditoria_precio` con precio_anterior y precio_nuevo (OK) |
| RN-14 | FK con ON DELETE RESTRICT | `ON DELETE RESTRICT` en FK de `bodega`, `vino`, `transportista` hacia tablas con movimientos | `db_tests.sql`: borrar bodega sin movimientos (OK) y borrar bodega id=1 con movimientos (falla → `foreign_key_violation`) |
| RN-15 | CHECK | `CHECK` en múltiples columnas: precio>0, graduación 5-20, superficies>0, kilos>0, cantidades>0, salario>0 | `db_tests.sql`: graduación 25.00 (falla → `check_violation`) y cantidad -5 en renglón (falla → `check_violation`) |

---

## Resumen de mecanismos por tipo

| Tipo de mecanismo | Cantidad | Reglas cubiertas |
|-------------------|----------|------------------|
| CHECK | 20+ | RN-01, RN-03, RN-06, RN-07, RN-09, RN-15 |
| UNIQUE | 12 | RN-01, RN-04 |
| FOREIGN KEY | Todas las tablas | RN-02, RN-03, RN-04, RN-14 |
| NOT NULL | Todos los obligatorios | RN-03 |
| DEFAULT | 7 | (apoyo a reglas de estados y fechas) |
| Función | 4 | RN-06, RN-08 |
| Procedimiento transaccional | 2 | RN-10, RN-11 |
| Trigger BEFORE | 5 | RN-09, RN-11, RN-12 |
| Trigger AFTER | 2 | RN-08, RN-13 |
| Constraint Trigger DEFERRABLE | 1 | RN-05 |
| Vistas | 3 | (soporte a reportes) |
| Roles y privilegios | 3 | (seguridad de acceso) |

---

## Archivos de referencia

- Esquema físico: `db/migrations/001_esquema.sql`
- Constraints: `db/migrations/002_constraints.sql`
- Funciones: `db/migrations/003_funciones.sql`
- Procedimientos: `db/migrations/004_procedimientos.sql`
- Triggers: `db/migrations/005_triggers.sql`
- Vistas: `db/migrations/006_vistas.sql`
- Roles: `db/migrations/007_roles.sql`
- Pruebas SQL: `db/tests/db_tests.sql`
