# Explicación del Proyecto — Bodegas del Atuel (TPI Bases de Datos)

**Propósito:** Este documento explica cómo funciona el proyecto, etapa por etapa, con énfasis en todo lo relacionado con la base de datos, para la exposición/defensa oral. Cada integrante debe poder explicar y modificar cualquier parte del proyecto.

**Ubicación:** `CARPETA TEMPORAL/explicacion.md` (solo referencia interna, no se sube al repositorio).

---

## 1. Visión General del Proyecto

**Sistema:** Gestión y distribución de una empresa vitivinícola llamada «Bodegas del Atuel».

**Motor de base de datos:** PostgreSQL 16 (en contenedor Docker).

**Principio fundamental (Regla de Oro):** La base de datos es el corazón del sistema. Toda la lógica de negocio (reglas RN-01 a RN-15) vive dentro de PostgreSQL mediante constraints, funciones, procedimientos y triggers. La API y el front NO recalculan totales, descuentos ni stock; solo llaman a lo que la base ya garantiza.

**Arquitectura:**
- `db/`: Esquema físico, migraciones (001-008), seed, pruebas SQL.
- `api/`: API REST en Node.js con Express y driver nativo `pg` (sin ORM), capa de acceso a datos propia (DAL), pool de conexiones, traducción de errores SQLSTATE a HTTP.
- `front/`: HTML/JS/CSS con nginx, consume solo la API.
- `docker-compose.yml`: Levanta db, migrate, api y front con un solo comando.

---

## 2. Arquitectura y Tecnologías

### 2.1 Servicios Docker

| Servicio | Puerto | Tecnología | Descripción |
|----------|--------|------------|-------------|
| `db` | 127.0.0.1:5433 | PostgreSQL 16 | Base de datos principal |
| `migrate` | — | PostgreSQL 16 | Aplica migraciones 001-008 en orden |
| `api` | 127.0.0.1:8001 | Node.js + Express | API REST con driver nativo `pg` |
| `front` | 127.0.0.1:8081 | nginx:alpine | Frontend estático HTML/JS/CSS |
| `seed` | — | Python 3.12 | Carga masiva de datos (profile `seed`) |

### 2.2 Capas del Sistema

```
┌─────────────────────────────────────────┐
│           FRONTEND (nginx:8081)         │
│  HTML/JS/CSS - Consume solo la API      │
└─────────────────────────────────────────┘
                        ↓ HTTP/JSON
┌─────────────────────────────────────────┐
│             API REST (8001)             │
│  Node.js + Express + driver pg nativo   │
│  Sin ORM - Consultas parametrizadas     │
└─────────────────────────────────────────┘
                        ↓ SQL
┌─────────────────────────────────────────┐
│        BASE DE DATOS PostgreSQL 16      │
│  Reglas RN-01 a RN-15 en constraints,   │
│  funciones, procedimientos y triggers   │
└─────────────────────────────────────────┘
```

---

## 3. Etapa 1: Modelado (Diseño del Esquema)

### 3.1 ¿Qué se hizo?
Se pasó del escenario escrito (enunciado del TPI) a un esquema físico en PostgreSQL, pasando por:
1. DER (Diagrama Entidad-Relación)
2. Esquema relacional normalizado (3FN)
3. Diccionario de datos
4. Decisiones de diseño
5. Esquema físico SQL (`db/migrations/001_esquema.sql`)

### 3.2 Tipos Enumerados (6 tipos)
Ningún estado o clasificación se modela como texto libre:

| Tipo | Valores | Usado en |
|------|---------|----------|
| `estado_documento` | en_confeccion, terminado, procesado | `ingreso.estado`, `transferencia.estado` |
| `tipo_vino` | tinto, blanco, rosado, espumante | `vino.tipo` |
| `tipo_cepa` | tinta, blanca | `cepa.tipo` |
| `tipo_cliente` | socio, distribuidor, exportador | `cliente.tipo_cliente` (discriminador) |
| `tipo_documento` | DNI, CUIT, CUIL, PASAPORTE | `cliente.tipo_doc` |
| `dia_semana` | lunes, martes, miercoles, jueves, viernes, sabado, domingo | `sala_venta.dia_cierre` |

### 3.3 Dominios (7 tipos reutilizables)

| Dominio | Definición | Descripción |
|---------|-----------|-------------|
| `dom_cuit` | `char(11) CHECK (VALUE ~ '^[0-9]{11}$')` | CUIT de 11 dígitos |
| `dom_email` | `varchar(120)` | Correo electrónico |
| `dom_telefono` | `varchar(30)` | Teléfono |
| `dom_dinero` | `numeric(12,2)` | Importe monetario (nunca FLOAT) |
| `dom_porcentaje` | `numeric(5,2)` | Porcentaje (0-100) |
| `dom_superficie` | `numeric(10,2)` | Superficie en hectáreas |
| `dom_cantidad` | `integer` | Cantidad de unidades |
| `dom_anio` | `smallint` | Año / campaña |

### 3.4 Tablas (25 tablas)

**Geografía:** provincia, departamento, localidad  
**Salas y empleados:** sala_venta, empleado  
**Bodegas y producción:** bodega, finca, cepa, parcela, lote_uva, analisis_calidad  
**Vinos:** vino, vino_cepa, maridaje, vino_maridaje, auditoria_precio  
**Stock:** stock_sala, stock_deposito  
**Transportistas:** transportista, transportista_localidad  
**Ingresos:** ingreso, renglon_ingreso  
**Transferencias:** transferencia, renglon_transferencia  
**Clientes (jerarquía):** cliente, socio, distribuidor, exportador, permiso_exportacion  
**Comprobantes:** comprobante, renglon_comprobante

### 3.5 Decisiones de diseño clave

**Jerarquía de clientes:** Supertipo `cliente` + subtipos `socio`, `distribuidor`, `exportador` con PK compartida (`id_cliente`) y discriminador `tipo_cliente`. Ventaja: las FK de comprobante apuntan a una sola tabla; cada subtipo tiene atributos NOT NULL propios.

**Claves subrogadas:** `GENERATED ALWAYS AS IDENTITY` en casi todas las tablas. Las claves naturales como CUIT se mantienen como UNIQUE pero no como PK.

**Sin FLOAT:** Todos los importes usan `NUMERIC` para evitar errores de punto flotante en dinero.

**Entidades débiles:** `parcela` (PK `id_finca, nro_parcela`) y `permiso_exportacion` (PK `id_cliente, codigo`).

---

## 4. Etapa 2: Integridad y Lógica en la Base de Datos

Esta es la etapa de mayor peso. Todas las reglas de negocio (RN-01 a RN-15) se implementan dentro de PostgreSQL.

### 4.1 Constraints (`002_constraints.sql`)

**UNIQUE adicionales (12):**
- provincia(nombre), departamento(id_provincia, nombre), localidad(id_provincia, nombre, codigo_postal)
- bodega(cuit), transportista(cuit), empleado(cuit), cepa(nombre), maridaje(nombre)
- lote_uva(id_finca, nro_parcela, campania)
- vino(nombre, anada, volumen_ml)
- cliente(tipo_doc, nro_doc)
- permiso_exportacion(codigo)

**CHECK (20+ restricciones, incluyendo uno entre columnas):**
- vino.precio > 0 (RN-01)
- vino.graduacion BETWEEN 5 AND 20 (RN-15)
- vino.volumen_ml IN (187, 375, 750, 1000, 1500, 3000) (RN-15)
- finca.superficie_ha > 0, parcela.superficie_ha > 0 (RN-15)
- lote_uva.kilos_cosechados > 0 (RN-15)
- stock_sala.cantidad >= 0, stock_deposito.cantidad >= 0 (RN-09, RN-15)
- renglon_*.cantidad > 0 (RN-15)
- vino_cepa.porcentaje BETWEEN 0 AND 100 (RN-05)
- cliente.descuento BETWEEN 0 AND 100, renglon_comprobante.descuento_aplicado BETWEEN 0 AND 100 (RN-06)
- permiso_exportacion.fecha_vencimiento > fecha_emision (RN-07, CHECK entre columnas)
- analisis_calidad.brix > 0, ph > 0, acidez_total > 0 (RN-15)
- empleado.salario > 0 (RN-15)

**DEFAULT (6):**
- ingreso.estado = 'en_confeccion'
- transferencia.estado = 'en_confeccion'
- cliente.fecha_alta = CURRENT_DATE
- transferencia.fecha_confeccion = CURRENT_DATE
- stock_sala.cantidad = 0
- stock_deposito.cantidad = 0

**Acciones referenciales:** Todas las FK tienen ON DELETE/ON UPDATE justificados. RESTRICT en bodega, transportista, vino (RN-14). CASCADE en renglones y subtipos de cliente.

### 4.2 Funciones (4 funciones en `003_funciones.sql`)

| Función | Parámetros | Retorna | Volatilidad | Propósito |
|---------|-----------|---------|-------------|-----------|
| `fn_total_comprobante` | `p_nro_comprobante integer` | `numeric(12,2)` | STABLE | Suma subtotales de renglones (RN-08) |
| `fn_stock_sala` | `p_id_sala integer, p_cod_vino integer` | `integer` | STABLE | Stock de un vino en una sala (RN-09) |
| `fn_descuento_cliente` | `p_tipo_cliente tipo_cliente` | `numeric(5,2)` | IMMUTABLE | Socio 10%, distribuidor 20%, exportador 30% (RN-06) |
| `fn_antiguedad_anios` | `p_fecha_ingreso date` | `integer` | STABLE | Años de antigüedad de un empleado |

### 4.3 Procedimientos transaccionales (2 procedimientos en `004_procedimientos.sql`)

| Procedimiento | Parámetro | Propósito |
|---------------|-----------|-----------|
| `sp_procesar_ingreso` | `p_cod_ingreso integer` | Valida estado 'terminado', bloquea renglones con FOR UPDATE, suma al stock_deposito, cambia estado a 'procesado' (RN-10). Todo o nada con ROLLBACK automático. |
| `sp_procesar_transferencia` | `p_nro_solicitud integer` | Valida estado 'terminado', verifica stock suficiente (RN-11), descuenta del depósito y suma a la sala, cambia estado a 'procesado'. Todo o nada con ROLLBACK automático. |

### 4.4 Triggers (8 triggers en `005_triggers.sql`)

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

### 4.5 Vistas (3 vistas en `006_vistas.sql`)

| Vista | Tipo | Propósito |
|-------|------|-----------|
| `mv_stock_total_por_vino` | MATERIALIZED VIEW | Stock total por vino = depósito central + salas. Tiene índice único en `cod_vino`. |
| `vw_ventas_mensuales_por_sala` | VIEW | Ventas mensuales por sala (últimos 12 meses) |
| `vw_documentos_pendientes` | VIEW | Ingresos y transferencias no procesados (en_confeccion o terminado) |

### 4.6 Roles (3 roles en `007_roles.sql`)

| Rol | Privilegios | Uso |
|-----|-------------|-----|
| `bodegas_owner` | ALL sobre esquema, tablas, secuencias, funciones, procedimientos | Administrador de la base |
| `app_rw` | SELECT/INSERT/UPDATE/DELETE en tablas, USAGE secuencias, EXECUTE funciones/procedimientos | La API se conecta con este rol (nunca owner) |
| `reporte_ro` | SELECT en tablas y vistas | Solo lectura para reportes |

**Seguridad:** `REVOKE ALL FROM PUBLIC` en esquema, tablas, secuencias, funciones, procedimientos. Las contraseñas se inyectan vía variables de entorno, nunca escritas en el archivo SQL.

---

## 5. Tabla de trazabilidad: Reglas de negocio (RN-01 a RN-15)

| RN | Descripción | Mecanismo implementado | Caso de prueba |
|----|-------------|------------------------|----------------|
| RN-01 | Precio de vino > 0 y único para toda la red | `CHECK (precio > 0)` + `UNIQUE (nombre, anada, volumen_ml)` | Insertar precio 0 → `check_violation` |
| RN-02 | Sala → localidad única. Cada localidad tiene un único encargado regional | `FK sala_venta.id_localidad → localidad.id_localidad` + 3FN | Sala con localidad inexistente → `foreign_key_violation` |
| RN-03 | Cada empleado trabaja en una sola sala | `FK empleado.id_sala → sala_venta.id_sala` con `NOT NULL` | Sala inexistente o cuit nulo → error FK o NOT NULL |
| RN-04 | Una parcela tiene una sola cepa y se cosecha una vez por campaña | `FK lote_uva.(id_finca, nro_parcela) → parcela.(id_finca, nro_parcela)` + `UNIQUE (id_finca, nro_parcela, campania)` | Misma parcela y campaña duplicada → `unique_violation` |
| RN-05 | Los porcentajes de corte de un vino suman exactamente 100 | `CONSTRAINT TRIGGER trg_chk_porcentajes_vino_cepa` DEFERRABLE INITIALLY DEFERRED | 50+30≠100 → excepción P0001 al COMMIT |
| RN-06 | El descuento depende del tipo de cliente: socio 10%, distribuidor 20%, exportador 30% | `fn_descuento_cliente()` (IMMUTABLE) + `CHECK (descuento BETWEEN 0 AND 100)` | Descuento 150 → `check_violation` |
| RN-07 | El vencimiento de permiso > emisión | `CHECK (fecha_vencimiento > fecha_emision)` | Vencimiento antes de emisión → `check_violation` |
| RN-08 | El total del comprobante es la suma de sus renglones con el descuento aplicado | `fn_total_comprobante()` + trigger AFTER INSERT `trg_descontar_stock_y_calcular_totales` | Comprobante con renglones → total calculado automáticamente |
| RN-09 | No se puede vender más de lo que hay en stock de la sala. Stock nunca negativo | `BEFORE INSERT trg_validar_stock_venta` + `CHECK (cantidad >= 0)` en stocks | Venta de 999999 unidades → excepción P0001 |
| RN-10 | Solo un ingreso terminado impacta en el depósito y pasa a procesado | `ENUM estado_documento` + `sp_procesar_ingreso()` (FOR UPDATE, todo o nada) | Ingreso en_confeccion no puede procesarse → P0001 |
| RN-11 | Igual que RN-10 para transferencias. Fecha de confección es la actual y no se puede modificar | `BEFORE trg_fecha_confeccion_transferencia` + `sp_procesar_transferencia()` | Transferencia en_confeccion rechazada → P0001 |
| RN-12 | Un ingreso o transferencia que no está en confección no admite agregar/modificar/quitar renglones | `BEFORE trg_bloquear_renglones_*` sobre renglones | Renglón en ingreso terminado rechazado → P0001 |
| RN-13 | Todo cambio de precio de un vino queda auditado | `AFTER UPDATE trg_auditoria_precio_vino` + tabla `auditoria_precio` | Cambio de precio → registro en auditoría con precio_anterior y precio_nuevo |
| RN-14 | No se puede borrar un transportista, una bodega ni un vino que tengan movimientos asociados | `FK con ON DELETE RESTRICT` en bodega, vino, transportista | Borrar bodega con movimientos → `foreign_key_violation` |
| RN-15 | Cantidades, superficies, kilos y precios son siempre positivos. La graduación está entre 5 y 20 | `CHECK` en múltiples columnas | Graduación 25 → `check_violation` |

---

## 6. Etapa 3: Carga masiva de datos

### 6.1 ¿Qué se hace?
El script `db/seed/seed.py` carga datos masivos usando Python, Faker y semilla fija para reproducibilidad.

### 6.2 Volúmenes cargados

| Tabla | Volumen |
|-------|---------|
| clientes | 20.000 |
| comprobantes | 150.000 |
| renglones de comprobante | 375.024 |
| stock inicial | 60 vinos × 10 salas |
| Catálogos (cepas, maridajes, departamentos, localidades) | Datos reales de Mendoza |

### 6.3 Orden de carga (respetando FK)
1. Provincia, departamento, localidad (geografía)
2. Bodega, finca, cepa, maridaje, transportista, sala, empleado
3. Vino, stock_deposito, vino_cepa, vino_maridaje, stock_sala, transportista_localidad
4. Cliente, socio, distribuidor, exportador, permiso_exportacion
5. Ingreso, transferencia, comprobante
6. Renglon_ingreso, renglon_transferencia, renglon_comprobante

### 6.4 Manejo de triggers durante carga masiva
7 triggers se deshabilitan temporalmente durante la carga masiva para evitar conflictos, y se rehabilitan al finalizar:

| Trigger | Tabla | Motivo |
|---------|-------|--------|
| `trg_coherencia_cliente_subtipo` | cliente | Exige fila en subtipo antes de insertar |
| `trg_validar_stock_venta` | renglon_comprobante | Stock de sala aún no ajustado |
| `trg_descontar_stock_y_calcular_totales` | renglon_comprobante | Dispararía actualizaciones individuales por cada renglón |
| `trg_bloquear_renglones_ingreso` | renglon_ingreso | Ingresos ya están en estado definitivo |
| `trg_bloquear_renglones_transferencia` | renglon_transferencia | Igual que el anterior |
| `trg_fecha_confeccion_transferencia` | transferencia | Fuerza fecha actual; en carga histórica fechas pueden ser pasadas |
| `trg_auditoria_precio_vino` | vino | No se modifican precios en carga masiva |

Después de la carga, se recalculan totales y stock manualmente, y se vuelven a habilitar los triggers.

### 6.5 Cómo ejecutar
```powershell
docker compose --profile seed run --rm seed python seed.py --masivo
```

---

## 7. Etapa 4: Índices y rendimiento

Se crearon 6 índices basados en mediciones EXPLAIN (ANALYZE, BUFFERS) reales:

| Índice | Tipo | Consulta beneficiada | Mejora |
|--------|------|---------------------|--------|
| `idx_comprobante_sala_fecha` | Compuesto (id_sala, fecha) | S8: ventas por sala trimestre | Reduce lecturas |
| `idx_stock_sala_sin_stock` | Parcial (WHERE cantidad = 0) | Vinos sin stock en sala | Índice más pequeño |
| `idx_renglon_comprobante_cod_vino` | Sobre FK (cod_vino) | S1: ranking de vinos más vendidos | De Parallel Seq Scan a Index Only Scan (~94% mejora) |
| `idx_vino_nombre_upper` | Expresión (UPPER(nombre)) | Búsqueda de vino por nombre case-insensitive | Evita Seq Scan |
| `idx_renglon_comprobante_nro_brin` | BRIN (nro_comprobante) | Consultas de rango por nro_comprobante | Índice compacto |
| `idx_renglon_transferencia_cod_vino` | Sobre FK (cod_vino) | S4: salas con más transferencias de un vino | Acelera filtrado por vino |

**Costo de escritura:** Los índices agregan aproximadamente 12% de sobrecarga en operaciones INSERT masivas, justificado por las mejoras en lecturas.

---

## 8. Etapa 5: Consultas SQL

Se implementaron 30 consultas comentadas (12 SELECT, 6 INSERT, 6 UPDATE, 6 DELETE), todas envueltas en transacciones con consultas de control previa y posterior.

### Consultas SELECT avanzadas:
- **S1:** Ranking de los 10 vinos más vendidos (JOIN múltiple, GROUP BY, SUM, LIMIT)
- **S2:** Vinos vendidos en todas las salas (división relacional con NOT EXISTS doble)
- **S3:** Clientes por tipo en última semana (JOIN, filtro por fecha, GROUP BY)
- **S4:** Top 5 salas por transferencias de un vino (JOIN, filtro por vino y fecha)
- **S5:** Salas con menos transferencias pendientes (LEFT JOIN, filtro por estado)
- **S6:** Vinos sin stock en sala pero con stock en depósito (INNER JOIN + LEFT JOIN)
- **S7:** Transporte con más ingresos en último mes (JOIN, GROUP BY, LIMIT)
- **S8:** Monto total de ventas por sala en último trimestre (JOIN, GROUP BY, SUM)
- **S9:** Ficha completa de un vino (múltiples JOINs, string_agg)
- **S10:** Rendimiento kg/ha por parcela y campaña (CTE, subconsulta correlacionada)
- **S11:** Ranking de vinos por sala con ventas acumuladas (CTE, RANK() OVER, suma acumulada con ventana)
- **S12a:** Clientes que compraron todos los vinos de una bodega (división relacional reescrita con GROUP BY + HAVING COUNT DISTINCT)
- **S12b:** Clientes que nunca compraron vino tinto (anti-join con NOT EXISTS)

**Nota:** S12a fue reescrita de NOT EXISTS correlionado doble (timeout >120s) a GROUP BY + HAVING COUNT DISTINCT (232ms).

---

## 9. Etapa 6: API REST

### 9.1 Arquitectura
Node.js + Express + driver nativo `pg` (sin ORM). Consultas parametrizadas para prevenir inyección SQL.

### 9.2 Endpoints (22 endpoints)

| Grupo | Endpoint | Método | Descripción |
|-------|----------|--------|-------------|
| Salud | `/salud` | GET | Verifica conectividad con BD |
| Vinos | `/vinos` | GET/POST | Listado paginado con filtros / crear vino con composición |
| Vinos | `/vinos/{cod}` | GET/PUT/DELETE | Detalle completo / actualizar precio (audita RN-13) / eliminar |
| Clientes | `/clientes` | GET/POST | Listado con subtipos / crear con subtipo |
| Clientes | `/clientes/{id}` | GET/PUT/DELETE | Detalle / actualizar / eliminar (CASCADE en subtipos) |
| Comprobantes | `/comprobantes` | POST | Crear venta con renglones (triggers RN-08/RN-09) |
| Comprobantes | `/comprobantes/{nro}` | GET | Detalle con renglones |
| Ingresos | `/ingresos` | POST | Crear ingreso en estado en_confeccion |
| Ingresos | `/ingresos/{cod}/renglones` | POST | Agregar renglones a ingreso en confección |
| Ingresos | `/ingresos/{cod}/procesar` | POST | Procesar ingreso (llama sp_procesar_ingreso) |
| Transferencias | `/transferencias` | POST | Crear transferencia en estado en_confeccion |
| Transferencias | `/transferencias/{nro}/renglones` | POST | Agregar renglones a transferencia en confección |
| Transferencias | `/transferencias/{nro}/terminar` | POST | Cambiar estado a terminado |
| Transferencias | `/transferencias/{nro}/procesar` | POST | Procesar transferencia (llama sp_procesar_transferencia) |
| Reportes | `/reportes/top-vinos` | GET | Top 10 vinos más vendidos |
| Reportes | `/reportes/ventas-por-sala` | GET | Ventas totales por sala en último trimestre |
| Reportes | `/reportes/vinos-sin-stock?id_sala=X` | GET | Vinos sin stock en sala X pero con stock en depósito |
| Reportes | `/reportes/transportista-activo` | GET | Transporte con más ingresos en último mes |
| Reportes | `/reportes/trazabilidad/{cod}` | GET | Ficha completa de un vino (cepas, maridajes, stock total) |

### 9.3 Traducción de errores SQLSTATE → HTTP

| SQLSTATE | Código HTTP | Significado |
|----------|-------------|-------------|
| 23505 | 409 | UNIQUE violado |
| 23503 | 409 | FOREIGN KEY violada |
| 23514 | 422 | CHECK violado (regla de negocio) |
| 23502 | 422 | NOT NULL violado |
| P0001 | 409 | Excepción PL/pgSQL (regla de negocio) |
| 22P02 | 400 | Formato/tipo inválido |
| 40001 / 40P01 | 503 | Serialización/deadlock |
| default | 500 | Error interno |

---

## 9. Etapa 7: Frontend

### 9.1 Pantallas (7 pantallas)

| Pantalla | Archivo | Descripción |
|----------|---------|-------------|
| Dashboard | `front/index.html` | Top vinos más vendidos, ventas por sala (gráfico), vinos sin stock por sala |
| Catálogo de Vinos | `front/vinos.html` | Listado paginado con filtros (nombre, tipo, bodega, cepa, añada) |
| Alta de Vino | `front/alta-vino.html` | Crear vino con composición de cepas (validación suma 100% RN-05) |
| Nueva Venta | `front/ventas.html` | Elegir cliente y sala, agregar vinos, generar comprobante |
| Clientes | `front/clientes.html` | Listado, crear (socio/distribuidor/exportador), eliminar |
| Transferencias | `front/transferencias.html` | Crear, cargar renglones, terminar, procesar |
| Reportes | `front/reportes.html` | Top vinos, ventas por sala, vinos sin stock, trazabilidad |

### 9.2 Reglas de oro del frontend (respetadas)
- **El front NO calcula totales, descuentos ni stock.** Solo envía datos y muestra resultados de la API.
- **El front NO contiene lógica de cálculo de importes.** El `descuento_aplicado` se envía como 0 y la BD aplica el descuento según tipo de cliente (RN-06).
- **Mensajes de error de la API se muestran tal cual**, sin ocultar ni reemplazar por genéricos.
- **Errores de reglas de negocio muestran el código RN-XX** entre paréntesis.

### 9.3 Capa de servicios
Todas las llamadas a la API están centralizadas en `front/js/api.js` con manejo de errores, reintentos con backoff exponencial y verificación de conectividad antes de cargar datos.

---

## 10. Cómo levantar y usar el sistema (guía rápida)

### Terminal 1 - Levantar servicios:
```powershell
docker compose down -v
docker compose up --build
```

### Terminal 2 - Cargar datos masivos:
```powershell
docker compose --profile seed run --rm seed python seed.py --masivo
```

### Navegador:
```
http://localhost:8081
```

### Verificar API:
```powershell
curl http://localhost:8001/salud
# Respuesta: {"status":"ok","db":{"resultado":1}}
```

---

## 11. Detalles técnicos importantes para la defensa

### ¿Por qué no ORM?
El enunciado lo prohíbe estrictamente. Se usa `pg` (Node.js) y `psycopg` (Python) como drivers nativos. Todas las consultas son SQL escrito a mano y parametrizado.

### ¿Por qué la BD es el corazón?
Porque las reglas de negocio están protegidas dentro de PostgreSQL. Si alguien accede directamente a la base de datos (por ejemplo con psql o DBeaver), las reglas siguen aplicándose gracias a constraints, triggers y procedimientos almacenados.

### ¿Qué pasa si se intenta eliminar un cliente con compras?
La FK `fk_comprobante_cliente` tiene `ON DELETE RESTRICT` (RN-14). PostgreSQL rechaza la eliminación con error `foreign_key_violation` y el frontend muestra el mensaje: `Key (id_cliente)=X is still referenced from table "comprobante". (RN-14)`

### ¿Qué pasa si dos usuarios venden la última botella al mismo tiempo?
El trigger `trg_validar_stock_venta` (BEFORE INSERT) y el trigger `trg_descontar_stock_y_calcular_totales` (AFTER INSERT) se ejecutan dentro de la transacción. Con `SELECT ... FOR UPDATE` en los procedimientos, la segunda sesión espera hasta que la primera termine, evitando pérdida de actualización.

### ¿Cómo se manejan los porcentajes de corte?
Con un constraint trigger diferido (`DEFERRABLE INITIALLY DEFERRED`) que se ejecuta al COMMIT. Esto permite insertar cepas por separado dentro de una transacción y verificar al final que sumen exactamente 100.

---

**Fin de la explicación.** Cada integrante debe poder explicar cualquier parte de este documento durante la defensa oral.