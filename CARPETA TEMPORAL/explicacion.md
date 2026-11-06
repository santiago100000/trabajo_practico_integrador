# Explicación del Proyecto — Bodegas del Atuel (TPI Bases de Datos)

**Propósito:** Este documento explica cómo funciona el proyecto, etapa por etapa, con énfasis en todo lo relacionado con la base de datos, para la exposición/defensa oral.

**Ubicación:** `CARPETA TEMPORAL/explicacion.md` (solo referencia interna, no se sube al repositorio).

---

## 1. Visión General del Proyecto

**Sistema:** Gestión y distribución de una empresa vitivinícola llamada «Bodegas del Atuel».

**Motor de base de datos:** PostgreSQL 16 (en contenedor Docker).

**Principio fundamental (Regla de Oro):** La base de datos es el corazón del sistema. Toda la lógica de negocio (reglas RN-01 a RN-15) vive dentro de PostgreSQL mediante constraints, funciones, procedimientos y triggers. La API y el front NO recalculan totales, descuentos ni stock; solo llaman a lo que la base ya garantiza.

**Arquitectura:**
- `db/`: Esquema físico, migraciones (001-008), seed, pruebas SQL.
- `api/`: FastAPI con driver nativo psycopg (sin ORM), capa de acceso a datos propia (DAL), pool de conexiones, traducción de errores SQLSTATE a HTTP.
- `front/`: HTML/JS/CSS con nginx, consume solo la API.
- `docker-compose.yml`: Levanta db, migrate, api y front con un solo comando.

---

## 2. Etapa 1 — Modelado (Completada)

### Objetivo
Pasar del escenario escrito a un esquema físico en PostgreSQL, pasando por el DER, el esquema relacional y la normalización.

### Qué se entregó

| Entregable | Archivo | Estado |
|------------|---------|--------|
| DER (diagrama entidad-relación) | `docs/der/Esquema Relacional.dbml` | ✅ |
| Esquema relacional escrito | `docs/esquema_relacional.md` | ✅ |
| Diccionario de datos | `docs/diccionario_datos.md` | ✅ |
| Normalización 3FN + justificación | `docs/normalizacion.md` | ✅ |
| Decisiones de diseño | `docs/decisiones_diseno.md` | ✅ |
| Esquema físico SQL | `db/migrations/001_esquema.sql` | ✅ |

### Detalle de la base de datos en Etapa 1

**Tipos enumerados (6 ENUM):**
- `estado_documento`: en_confeccion, terminado, procesado
- `tipo_vino`: tinto, blanco, rosado, espumante
- `tipo_cepa`: tinta, blanca
- `tipo_cliente`: socio, distribuidor, exportador
- `tipo_documento`: DNI, CUIT, CUIL, PASAPORTE
- `dia_semana`: lunes a domingo

**Dominios (reutilizables):**
- `dom_cuit`: CHAR(11) con CHECK de 11 dígitos (usado en empleado, bodega, transportista)
- `dom_dinero`: NUMERIC(12,2) para importes monetarios (nunca FLOAT)
- `dom_porcentaje`: NUMERIC(5,2) para porcentajes
- `dom_superficie`: NUMERIC(10,2) para hectáreas
- `dom_cantidad`: INTEGER para cantidades
- `dom_anio`: SMALLINT para años/campañas

**Tablas creadas (25 tablas):**
- Geografía: provincia, departamento, localidad
- Salas y empleados: sala_venta, empleado
- Bodegas: bodega
- Producción de uva: finca, cepa, parcela (entidad débil), lote_uva, analisis_calidad
- Vinos: vino, vino_cepa (N:M con atributo porcentaje), maridaje, vino_maridaje (N:M), auditoria_precio
- Stock: stock_sala, stock_deposito
- Transportistas: transportista, transportista_localidad (N:M)
- Ingresos: ingreso, renglon_ingreso
- Transferencias: transferencia, renglon_transferencia
- Clientes (jerarquía supertipo/subtipos): cliente, socio, distribuidor, exportador, permiso_exportacion (entidad débil)
- Comprobantes: comprobante, renglon_comprobante

**Decisiones clave de modelado:**
- **Jerarquía de clientes:** Supertipo `cliente` + subtipos `socio`, `distribuidor`, `exportador` con PK compartida (`id_cliente`) y discriminador `tipo_cliente`. Ventaja: las FK de comprobante apuntan a una sola tabla; cada subtipo tiene atributos NOT NULL propios.
- **Entidad débil parcela:** PK compuesta `(id_finca, nro_parcela)` con FK a `finca`.
- **Entidad débil permiso_exportacion:** PK compuesta `(id_cliente, codigo)` con FK a `exportador`.
- **Claves subrogadas:** `GENERATED ALWAYS AS IDENTITY` en casi todas las tablas; CUIT como identificador natural único pero no como PK.
- **Sin FLOAT:** Todos los importes usan `NUMERIC` para evitar errores de punto flotante en dinero.
- **Estados no son texto libre:** Todos usan tipos ENUM.

**Verificación:** `001_esquema.sql` se aplica sobre una base vacía sin errores.

---

## 3. Etapa 2 — Integridad y Lógica en la Base de Datos (Completada)

Esta es la etapa de mayor peso. Todas las reglas de negocio (RN-01 a RN-15) se implementan dentro de PostgreSQL.

### Paso 1 — `002_constraints.sql` (Restricciones)

**UNIQUE adicionales (12):**
- `provincia(nombre)`, `departamento(id_provincia, nombre)`, `localidad(id_provincia, nombre, codigo_postal)`
- `bodega(cuit)`, `transportista(cuit)`, `empleado(cuit)`, `cepa(nombre)`, `maridaje(nombre)`
- `lote_uva(id_finca, nro_parcela, campania)` — una cosecha por parcela y campaña (RN-04)
- `vino(nombre, anada, volumen_ml)`, `cliente(tipo_doc, nro_doc)`, `permiso_exportacion(codigo)`

**CHECK (20+):**
- `vino.precio > 0` (RN-01)
- `vino.graduacion BETWEEN 5 AND 20` (RN-15)
- `vino.volumen_ml IN (187, 375, 750, 1000, 1500, 3000)` (RN-15)
- `finca.superficie_ha > 0`, `parcela.superficie_ha > 0` (RN-15)
- `lote_uva.kilos_cosechados > 0` (RN-15)
- `stock_sala.cantidad >= 0`, `stock_deposito.cantidad >= 0` (RN-09, RN-15)
- `renglon_ingreso.cantidad > 0`, `renglon_transferencia.cantidad > 0`, `renglon_comprobante.cantidad > 0` (RN-15)
- `vino_cepa.porcentaje BETWEEN 0 AND 100` (RN-05)
- `cliente.descuento BETWEEN 0 AND 100`, `renglon_comprobante.descuento_aplicado BETWEEN 0 AND 100` (RN-06)
- `permiso_exportacion.fecha_vencimiento > fecha_emision` (RN-07, CHECK entre columnas)
- `analisis_calidad.brix > 0`, `ph > 0`, `acidez_total > 0` (RN-15)
- `empleado.salario > 0` (RN-15)

**DEFAULT (7):**
- `ingreso.estado = 'en_confeccion'`, `transferencia.estado = 'en_confeccion'`
- `cliente.fecha_alta = CURRENT_DATE`, `transferencia.fecha_confeccion = CURRENT_DATE`
- `stock_sala.cantidad = 0`, `stock_deposito.cantidad = 0`

**Acciones referenciales ON DELETE / ON UPDATE:**
- `RESTRICT` en bodega, transportista, vino (RN-14: no se borra con movimientos)
- `CASCADE` en renglones (no existen sin cabecera), subtipos de cliente, análisis de calidad
- `NO ACTION` en ON UPDATE (las PK subrogadas nunca cambian)

### Paso 2 — `003_funciones.sql` (4 funciones)

| Función | Parámetros | Retorna | Volatilidad | Propósito |
|---------|-----------|---------|-------------|-----------|
| `fn_total_comprobante` | `p_nro_comprobante integer` | `numeric(12,2)` | STABLE | Suma subtotales de renglones (RN-08) |
| `fn_stock_sala` | `p_id_sala integer, p_cod_vino integer` | `integer` | STABLE | Stock de un vino en una sala (RN-09) |
| `fn_descuento_cliente` | `p_tipo_cliente tipo_cliente` | `numeric(5,2)` | IMMUTABLE | Socio 10%, distribuidor 20%, exportador 30% (RN-06) |
| `fn_antiguedad_anios` | `p_fecha_ingreso date` | `integer` | STABLE | Años de antigüedad de un empleado |

### Paso 3 — `004_procedimientos.sql` (2 procedimientos transaccionales)

**`sp_procesar_ingreso(p_cod_ingreso)`:**
1. Valida que el ingreso exista y esté en estado `terminado` (FOR UPDATE para bloquear la fila)
2. Bloquea los renglones con `FOR UPDATE`
3. Suma las cantidades al `stock_deposito` (INSERT ... ON CONFLICT)
4. Cambia el estado a `procesado` (transición final, no retrocede)
5. Todo en una transacción: si algo falla, ROLLBACK completo

**`sp_procesar_transferencia(p_nro_solicitud)`:**
1. Valida que la transferencia esté en estado `terminado` (FOR UPDATE)
2. Bloquea los renglones con `FOR UPDATE`
3. Verifica stock suficiente en `stock_deposito` para cada vino (RN-11)
4. Descuenta del depósito central y suma al stock de la sala
5. Cambia el estado a `procesado`
6. Todo o nada: si hay stock insuficiente, se revierte todo

### Paso 4 — `005_triggers.sql` (8 triggers)

| # | Trigger | Tipo | Regla RN |
|---|---------|------|----------|
| 1 | `trg_chk_porcentajes_vino_cepa` | CONSTRAINT DEFERRABLE INITIALLY DEFERRED | RN-05 (suma porcentajes = 100) |
| 2 | `trg_validar_stock_venta` | BEFORE INSERT | RN-09 (stock suficiente para vender) |
| 3 | `trg_descontar_stock_y_calcular_totales` | AFTER INSERT | RN-08, RN-09 (descuento stock + totales) |
| 4 | `trg_bloquear_renglones_ingreso` | BEFORE I/U/D | RN-12 (solo si está en confección) |
| 5 | `trg_bloquear_renglones_transferencia` | BEFORE I/U/D | RN-12 (solo si está en confección) |
| 6 | `trg_fecha_confeccion_transferencia` | BEFORE I/U | RN-11 (fecha actual, no modificable) |
| 7 | `trg_auditoria_precio_vino` | AFTER UPDATE | RN-13 (auditoría de cambios de precio) |
| 8 | `trg_coherencia_cliente_subtipo` | AFTER I/U | Jerarquía cliente (tipo vs subtipo) |

Tipos cubiertos: 1 constraint diferido, 5 BEFORE, 2 AFTER.

### Paso 5 — `006_vistas.sql` (3 vistas)

| Vista | Tipo | Propósito |
|-------|------|-----------|
| `mv_stock_total_por_vino` | MATERIALIZED VIEW | Stock depósito + salas por vino (con índice único) |
| `vw_ventas_mensuales_por_sala` | VIEW | Ventas de los últimos 12 meses por sala |
| `vw_documentos_pendientes` | VIEW | Ingresos y transferencias no procesados (en_confeccion o terminado) |

### Paso 6 — `007_roles.sql` (3 roles)

| Rol | Privilegios | Uso |
|-----|-------------|-----|
| `bodegas_owner` | ALL en esquema, tablas, secuencias, funciones, procedimientos | Administrador de la base |
| `app_rw` | SELECT/INSERT/UPDATE/DELETE en tablas, USAGE secuencias, EXECUTE funciones/procedimientos | La API se conecta con este rol (nunca owner) |
| `reporte_ro` | SELECT en tablas y vistas | Solo lectura para reportes |

**Seguridad:**
- `REVOKE ALL FROM PUBLIC` en esquema, tablas, secuencias, funciones, procedimientos
- Contraseñas inyectadas vía variables de entorno (`@OWNER_PASSWORD@`, `@APP_PASSWORD@`, `@RO_PASSWORD@`), nunca escritas en el archivo SQL
- La API nunca usa el rol propietario

### Paso 7 — `tests/db_tests.sql` (Pruebas SQL)

Cada regla RN-01 a RN-15 tiene:
- **Caso que debe funcionar:** sentencia que se ejecuta sin error
- **Caso que debe fallar:** sentencia envuelta en `DO ... EXCEPTION` que verifica que se lance la excepción esperada (SQLSTATE: `check_violation`, `foreign_key_violation`, `unique_violation`, `not_null_violation`)

Se verificó ejecución exitosa contra una base vacía con Docker Compose.

---

## 4. Enfoque para la Exposición/Defensa (Base de Datos)

### ¿Qué explicar del modelo?

1. **DER → Esquema relacional:** Entidades, relaciones, cardinalidades, entidad débil (parcela), jerarquía de clientes (supertipo/subtipos), relaciones N:M con atributos (vino_cepa, renglones).

2. **Normalización 3FN:**
   - 1FN: Atributos atómicos, no hay grupos repetidos, N:M resueltas con tablas intermedias.
   - 2FN: No hay dependencias parciales en claves compuestas (parcela no guarda nombre de finca, vino_cepa no guarda nombre de vino).
   - 3FN: No hay dependencias transitivas (finca → departamento → provincia se separó en tablas propias; localidad → encargado_regional está bien porque el encargado depende solo de la localidad).
   - Excepción controlada: comprobante.subtotal/total se almacenan (atributos derivados) por ser documento histórico y evitar recalcular en reportes masivos.

3. **Tipos de datos:**
   - `NUMERIC` para dinero, nunca `FLOAT`.
   - `ENUM` para estados y clasificaciones, nunca texto libre.
   - `CHAR(11)` con CHECK para CUIT.
   - `DATE` para fechas de negocio, `TIMESTAMP` solo en auditoría de precios.

4. **Reglas de negocio implementadas en la base (RN-01 a RN-15):** Cada regla tiene al menos un mecanismo (constraint, función, procedimiento, trigger) y un caso de prueba.

### ¿Qué demostrar en vivo?

1. **Aplicar migraciones desde cero:** `docker compose down -v && docker compose up -d db migrate` → todas las migraciones (001-008) aplicadas sin errores.

2. **Probar una regla que falla:** Ejemplo, intentar insertar un vino con precio 0 o negativo → debe rechazar con `CHECK precio > 0`.

3. **Probar un trigger:** Insertar un renglón de comprobante con cantidad mayor al stock disponible → debe rechazar con mensaje de stock insuficiente (RN-09).

4. **Probar un procedimiento transaccional:** Llamar `sp_procesar_transferencia` con stock insuficiente en depósito → debe hacer ROLLBACK completo (todo o nada).

5. **Mostrar las vistas:** Consultar `mv_stock_total_por_vino` para ver stock depósito + salas.

6. **Mostrar los roles:** Conectarse con `app_rw` y verificar que no puede hacer `DROP TABLE` (solo SELECT/INSERT/UPDATE/DELETE).

7. **Mostrar la auditoría:** Cambiar el precio de un vino y consultar `auditoria_precio` para ver el registro (RN-13).

### Preguntas típicas de defensa y respuestas

**P: ¿Por qué no usan ORM?**
R: El enunciado lo prohíbe. Usamos psycopg (driver nativo de PostgreSQL) con consultas parametrizadas para evitar inyección SQL y para que el SQL quede visible y controlado.

**P: ¿Dónde vive la lógica de negocio?**
R: En la base de datos (constraints, funciones, procedimientos, triggers). La API solo llama a lo que la base ya garantiza. Así las reglas valen aunque alguien acceda a la base directamente.

**P: ¿Cómo garantizan que los porcentajes de corte sumen 100?**
R: Con un constraint trigger diferido (`DEFERRABLE INITIALLY DEFERRED`) que se ejecuta al hacer COMMIT y verifica que la suma de `vino_cepa.porcentaje` por vino sea exactamente 100.

**P: ¿Qué pasa si dos usuarios intentan vender la última botella al mismo tiempo?**
R: Usamos `SELECT ... FOR UPDATE` en los procedimientos transaccionales para bloquear la fila. La segunda sesión espera hasta que la primera haga COMMIT o ROLLBACK. Sin este bloqueo, se podría perder la actualización (pérdida de actualización clásica).

**P: ¿Por qué usan claves subrogadas en lugar de naturales?**
R: Las claves subrogadas (IDENTITY) son estables, livianas y nunca cambian. Las claves naturales como CUIT o código postal pueden corregirse o repetirse. Se mantienen como UNIQUE donde aplica.

**P: ¿Qué hace el trigger de auditoría de precios?**
R: `trg_auditoria_precio_vino` se dispara AFTER UPDATE en `vino` y, si el precio cambió, inserta en `auditoria_precio` el precio anterior, nuevo, fecha/hora y usuario (RN-13).

---

## 5. Flujo de una Venta (Ejemplo End-to-End en la Base)

1. El cliente elige vinos en el front → la API recibe la solicitud.
2. La API inserta un `comprobante` con subtotal=0, descuento=0, total=0.
3. Para cada renglón, la API inserta en `renglon_comprobante`.
4. El trigger `trg_validar_stock_venta` (BEFORE INSERT) verifica que haya stock suficiente en la sala (RN-09).
5. El trigger `trg_descontar_stock_y_calcular_totales` (AFTER INSERT) descuenta el stock de la sala y recalcula subtotal/total del comprobante usando `fn_total_comprobante` (RN-08).
6. Si en cualquier punto falla (stock insuficiente), toda la transacción se revierte.

---

## 6. Cómo Levantar y Probar

```bash
# 1. Copiar variables de entorno
cp .env.example .env

# 2. Levantar todo (base, migraciones, API, front)
docker compose up --build

# 3. Verificar que la base esté sana
docker compose exec db pg_isready -U bodegas_owner -d bodegas

# 4. Ejecutar pruebas SQL
docker compose exec db psql -U bodegas_owner -d bodegas -f /tests/db_tests.sql

# 5. Ver URLs
# API: http://localhost:8001
# Front: http://localhost:8081
# Swagger: http://localhost:8001/docs
```

---

**Nota:** Este archivo es solo para preparación de la exposición. No pertenece al repositorio del proyecto (está en `CARPETA TEMPORAL/`).
