# Informe Final — Bodegas del Atuel (TPI Base de Datos)

**Proyecto:** Bodegas del Atuel — TP Integrador de Bases de Datos (UTN FRSR)  
**Estado:** Todas las etapas del 1 al 7 completadas. Etapa 8 omitida por indicación del docente.  
**Integrantes:** Puita Axel, Cerda Santiago, Serpa Juan Cruz

---

## 1. Introducción y objetivo del proyecto

Sistema de gestión y distribución de una empresa vitivinícola llamado «Bodegas del Atuel». El proyecto modela la producción de uva, elaboración de vinos, stock en depósito central y salas de venta, clientes (socios, distribuidores, exportadores), ingresos, transferencias y comprobantes de venta.

Toda la lógica de negocio (reglas RN-01 a RN-15) está implementada dentro de PostgreSQL mediante constraints, funciones, procedimientos almacenados y triggers. La base de datos es el corazón del sistema; la API y el frontend solo consumen y presentan datos sin recalcular nada.

El sistema se ejecuta exclusivamente en entorno local mediante Docker Compose (base de datos PostgreSQL 16, API REST en Node.js/Express y frontend estático con nginx).

---

## 2. Etapa 1: Modelado (Diseño del esquema relacional)

[Contenido basado en `docs/informes/informe_etapa1_modelado.md`]

### Paso 1 — Análisis del DER y reglas de negocio

El modelo parte de un DER con 25 tablas y 6 tipos enumerados. Se aplicaron las reglas de mapeo del DER al esquema relacional:

| Regla de mapeo | Aplicación en el esquema |
|----------------|--------------------------|
| Entidad fuerte → tabla con PK | `provincia`, `departamento`, `localidad`, `bodega`, `finca`, `cepa`, `vino`, `maridaje`, `sala_venta`, `empleado`, `cliente`, `transportista`, `ingreso`, `transferencia`, `comprobante`, `stock_deposito` |
| Relación 1:N → FK en el lado N | `empleado.id_sala`, `vino.id_bodega`, `parcela.id_departamento`, `lote_uva.id_bodega`, etc. |
| Relación N:M → tabla intermedia con PK compuesta | `vino_cepa`, `vino_maridaje`, `stock_sala`, `transportista_localidad`, `renglon_ingreso`, `renglon_transferencia`, `renglon_comprobante` |
| Entidad débil → PK hereda de la fuerte | `parcela (id_finca, nro_parcela)`, `permiso_exportacion (id_cliente, codigo)` |
| Jerarquía de clientes | Supertipo `cliente` + subtipos `socio`, `distribuidor`, `exportador` (PK compartida + discriminador `tipo_cliente`) |

### Paso 2 — Tipos enumerados y dominios

Se definieron 6 tipos enumerados y 7 dominios reutilizables para garantizar integridad de dominio y evitar texto libre en clasificaciones.

### Paso 3 — Diccionario de datos

El diccionario de datos (`docs/diccionario_datos.md`) documenta cada tabla, columna, tipo, nulabilidad, PK/FK y descripción. Cubre 25 tablas organizadas en 10 grupos: geografía, salas y empleados, bodegas y producción de uva, vinos, stock, transportistas, ingresos, transferencias, clientes (jerarquía) y comprobantes de venta.

### Paso 4 — Normalización (1FN, 2FN, 3FN)

El esquema alcanza 3FN con una excepción controlada: atributos derivados en `comprobante` (subtotal, total, descuento) que se almacenan por ser un documento histórico y evitar recálculos masivos.

### Paso 5 — Decisiones de diseño

- Jerarquía de clientes: supertipo `cliente` + subtipos.
- Claves subrogadas para la mayoría de entidades; claves compuestas para entidades débiles y relaciones N:M.
- Tipos de datos: `NUMERIC` para dinero, `DATE` para fechas de negocio, tipos enumerados para estados/clasificaciones.
- Acciones referenciales: `ON DELETE RESTRICT` para catálogos y entidades con movimientos; `ON DELETE CASCADE` para renglones sin cabecera y subtipos.

**Archivo relacionado:** `db/migrations/001_esquema.sql`

---

## 3. Etapa 2: Integridad y lógica en la base de datos

[Contenido basado en `docs/informes/informe_etapa2_integridad.md`]

### Paso 1 — `002_constraints.sql` — Restricciones de integridad

- **12 UNIQUE adicionales** (más allá de PK): provincia, departamento, localidad, bodega (CUIT), transportista (CUIT), empleado (CUIT), cepa, maridaje, lote_uva, vino (nombre+añada+volumen), cliente (tipo_doc+nro_doc), permiso_exportacion.
- **20+ CHECK**: precio > 0, graduación 5-20, volumen válido, superficies positivas, kilos positivos, stocks >= 0, cantidades > 0, descuento entre 0 y 100, fecha_vencimiento > fecha_emision, salario > 0, etc.
- **6 DEFAULT**: estado 'en_confeccion' en ingreso/transferencia, fecha_alta CURRENT_DATE, cantidad 0 en stocks.
- **Acciones referenciales**: RESTRICT en mayoría de FK; CASCADE en renglones, subtipos, composición, stock, análisis, cobertura.

### Paso 2 — `003_funciones.sql` — 4 funciones

| Función | Propósito |
|---------|-----------|
| `fn_total_comprobante` | Calcula total de un comprobante (RN-08) |
| `fn_stock_sala` | Devuelve stock de vino en sala (RN-09) |
| `fn_descuento_cliente` | Descuento por tipo: socio 10%, distribuidor 20%, exportador 30% (RN-06) |
| `fn_antiguedad_anios` | Años de antigüedad de empleado (consulta U2) |

### Paso 3 — `004_procedimientos.sql` — 2 procedimientos transaccionales

| Procedimiento | Propósito |
|---------------|-----------|
| `sp_procesar_ingreso` | Procesa ingreso al depósito central (RN-10) |
| `sp_procesar_transferencia` | Procesa transferencia depósito → sala (RN-11) |

Ambos usan `FOR UPDATE` y garantizan todo o nada con ROLLBACK automático.

### Paso 4 — `005_triggers.sql` — 8 triggers

| # | Trigger | Regla |
|---|---------|-------|
| 1 | `trg_chk_porcentajes_vino_cepa` | RN-05 (suma porcentajes = 100, constraint diferido) |
| 2 | `trg_validar_stock_venta` | RN-09 (validar stock antes de vender) |
| 3 | `trg_descontar_stock_y_calcular_totales` | RN-08/RN-09 (descuento stock y totales) |
| 4 | `trg_bloquear_renglones_ingreso` | RN-12 (bloquear cambios si no está en confección) |
| 5 | `trg_bloquear_renglones_transferencia` | RN-12 (idéntico para transferencias) |
| 6 | `trg_fecha_confeccion_transferencia` | RN-11 (forzar fecha actual) |
| 7 | `trg_auditoria_precio_vino` | RN-13 (auditoría de cambios de precio) |
| 8 | `trg_coherencia_cliente_subtipo` | Jerarquía cliente |

### Paso 5 — `006_vistas.sql` — 3 vistas

| Vista | Tipo | Propósito |
|-------|------|-----------|
| `mv_stock_total_por_vino` | MATERIALIZED VIEW | Stock total por vino (depósito + salas) |
| `vw_ventas_mensuales_por_sala` | VIEW | Ventas mensuales por sala (últimos 12 meses) |
| `vw_documentos_pendientes` | VIEW | Ingresos y transferencias pendientes |

### Paso 6 — `007_roles.sql` — 3 roles y privilegios mínimos

| Rol | Privilegios |
|-----|-------------|
| `bodegas_owner` | ALL sobre esquema, tablas, secuencias, funciones, procedimientos |
| `app_rw` | SELECT/INSERT/UPDATE/DELETE en tablas de negocio (usa la API) |
| `reporte_ro` | SELECT en tablas y vistas (solo lectura) |

### Paso 7 — `tests/db_tests.sql` — Pruebas RN-01 a RN-15

Cada regla tiene un mecanismo y un caso de prueba; los casos que deben fallar fallan con error claro.

**Archivos relacionados:** `db/migrations/002_...sql` a `007_roles.sql`, `db/tests/db_tests.sql`

---

## 4. Etapa 3: Carga masiva de datos

[Contenido basado en `docs/informes/informe_etapa3_carga_masiva.md`]

### Paso 1 — Catálogos desde CSV

6 archivos CSV: cepas (10), localidades (16), departamentos_mendoza (10), tipos_vino, presentaciones_ml, maridajes (10).

### Paso 2 — Orden de carga por dependencias FK

7 niveles de carga respetando dependencias de claves foráneas, desde geografía hasta renglones de comprobante.

### Paso 3 — Carga masiva con Faker

| Tabla | Volumen |
|-------|---------|
| clientes | 20.000 |
| comprobantes | 150.000 |
| renglones de comprobante | 500.000+ |

Semilla fija (42) para reproducibilidad. Se genera `dump_completo.sql.gz` para restaurar la base.

### Paso 4 — Manejo de triggers durante la carga masiva

7 triggers deshabilitados temporalmente durante la carga y rehabilitados al finalizar, tras recalcular totales y stock.

### Paso 5 — Consultas de control

Conteo final por tabla, verificación de stock negativo (0) y totales consistentes (0 inconsistencias).

**Archivos relacionados:** `db/seed/seed.py`, `db/seed/catalogos/*.csv`, `docs/informes/decision_triggers_carga_masiva.md`

---

## 5. Etapa 4: Índices y rendimiento

[Contenido basado en `docs/informes/informe_etapa4_indices.md`]

### Consultas candidatas

- **C1/C3:** `COUNT(*) FROM renglon_comprobante WHERE cod_vino = X` → se beneficia de `idx_renglon_comprobante_cod_vino`
- **C2:** `SELECT * FROM stock_sala WHERE cantidad = 0` → índice parcial (sin mejora real en volumen pequeño)
- **S1, S4, S8:** consultas avanzadas de referencia

### 6 índices creados

| Índice | Tipo | Propósito |
|--------|------|-----------|
| `idx_comprobante_sala_fecha` | Compuesto | Filtrar y agrupar por sala y fecha (S8) |
| `idx_stock_sala_sin_stock` | Parcial | Filtrar stock = 0 (C2) |
| `idx_renglon_comprobante_cod_vino` | FK | Filtrar renglones por vino (C1, C3) |
| `idx_vino_nombre_upper` | Expresión | Búsqueda insensible a mayúsculas |
| `idx_renglon_comprobante_nro_brin` | BRIN | Consultas de rango en nro_comprobante |
| `idx_renglon_transferencia_cod_vino` | FK | Filtrar transferencias por vino (S4) |

### Resultado comparativo

- **C1:** 13.716 ms → 0.813 ms (-94.1%), de Parallel Seq Scan a Index Only Scan
- **C3:** 13.215 ms → 0.829 ms (-93.7%), mismo patrón
- **C2:** 0.085 ms → 0.113 ms (sin mejora real, conjunto demasiado pequeño)

### Costo de escritura

12% de sobrecarga en INSERT masivo (10,000 filas con 6 índices vs sin índices).

**Archivo relacionado:** `db/migrations/008_indices.sql`

---

## 6. Etapa 5: Consultas SQL

[Contenido basado en `docs/informes/informe_etapa5_explain.md`]

### 12 consultas SELECT (S1 a S12)

| Código | Consulta | Técnica |
|--------|----------|---------|
| S1 | Ranking 10 vinos más vendidos | JOIN, GROUP BY, SUM, LIMIT |
| S2 | Vinos vendidos en todas las salas | División relacional (NOT EXISTS doble) |
| S3 | Clientes por tipo en última semana | JOIN, filtro fecha, COUNT DISTINCT |
| S4 | Top 5 salas por transferencias de un vino | JOIN, filtro vino+fecha, GROUP BY, LIMIT |
| S5 | Salas con menos transferencias pendientes | LEFT JOIN, ORDER BY ASC |
| S6 | Vinos sin stock en sala pero con stock en depósito | INNER JOIN + LEFT JOIN |
| S7 | Transporte con más ingresos en último mes | JOIN, filtro fecha, ORDER BY DESC |
| S8 | Monto total ventas por sala (último trimestre) | JOIN, filtro fecha, GROUP BY, SUM |
| S9 | Ficha completa de un vino | Múltiples JOINs, string_agg, stock total |
| S10 | Rendimiento kg/ha por parcela y campaña | CTE, subconsulta correlacionada |
| S11 | Ranking vinos por sala con ventas acumuladas | CTE, RANK() OVER, suma ventana |
| S12a | Clientes que compraron todos vinos de una bodega | División relacional (GROUP BY + HAVING) |
| S12b | Clientes que nunca compraron vino tinto | Anti-join (NOT EXISTS) |

### 6 consultas INSERT (I1 a I6), 6 UPDATE (U1 a U6), 6 DELETE (D1 a D6)

Todas envueltas en transacciones con consultas de control previa y posterior.

### Medición EXPLAIN (ANALYZE, BUFFERS)

Consultas más costosas: S1 (435 ms) y S11 (568 ms), ambas con Parallel Seq Scan sobre tablas grandes. S12a reescrita para evitar timeout (>120s con NOT EXISTS correlionado) y ahora ejecuta en 232 ms.

**Archivos relacionados:** `consultas/select.sql`, `consultas/insert.sql`, `consultas/update.sql`, `consultas/delete.sql`

---

## 7. Etapa 6: API REST

[Contenido basado en `docs/informes/informe_etapa6_api.md`]

### Arquitectura

Node.js + Express + driver nativo `pg` (sin ORM). Consultas parametrizadas para prevenir inyección SQL. La API se conecta con el rol `app_rw` (privilegios mínimos), nunca como superusuario.

### 22 endpoints en 7 grupos

| Grupo | Endpoints principales |
|-------|----------------------|
| Salud | `GET /salud` |
| Vinos | `GET /vinos`, `GET /vinos/:cod`, `POST /vinos`, `PUT /vinos/:cod`, `DELETE /vinos/:cod` |
| Clientes | `GET /clientes`, `GET /clientes/:id`, `POST /clientes`, `PUT /clientes/:id`, `DELETE /clientes/:id` |
| Comprobantes | `GET /comprobantes/:nro`, `POST /comprobantes` |
| Ingresos | `POST /ingresos`, `POST /ingresos/:cod/renglones`, `POST /ingresos/:cod/procesar` |
| Transferencias | `POST /transferencias`, `POST /transferencias/:nro/renglones`, `POST /transferencias/:nro/terminar`, `POST /transferencias/:nro/procesar` |
| Reportes | `GET /reportes/top-vinos`, `GET /reportes/ventas-por-sala`, `GET /reportes/vinos-sin-stock`, `GET /reportes/transportista-activo`, `GET /reportes/trazabilidad/:cod` |

### Manejo de errores

Mapeo SQLSTATE → HTTP: 23505→409, 23503→409, 23514→422, 23502→422, P0001→409, 22P02→400, 40001/40P01→503.

### Tests

12 pruebas unitarias con Jest y Supertest. Pruebas de base de datos con `db/tests/db_tests.sql`.

**Archivo relacionado:** `api/`, `docs/openapi.json`

---

## 8. Etapa 7: Frontend

[Contenido basado en `docs/informes/informe_etapa7_front.md`]

### Arquitectura

Aplicación estática (HTML/JS/CSS) servida con nginx en puerto 8081. Consume exclusivamente la API REST de la Etapa 6.

### 5 pantallas implementadas

| Pantalla | Descripción |
|----------|-------------|
| Dashboard (`index.html`) | Top vinos, métricas rápidas, verifica salud de API |
| Catálogo de Vinos (`vinos.html`) | Listado paginado, filtros por nombre y tipo, stock total |
| Nueva Venta (`ventas.html`) | Crear comprobante con cliente, sala y vinos |
| Clientes (`clientes.html`) | Listado, alta y eliminación de clientes |
| Reportes (`reportes.html`) | Top vinos, ventas por sala, vinos sin stock, trazabilidad |

### Principio rector

El frontend no recalcula totales, descuentos ni stock. Envía `descuento_aplicado: 0` y deja que la base de datos aplique RN-06, RN-08 y RN-09.

**Archivo relacionado:** `front/`, `api/src/db/salas.js`, `api/src/routes/salasRoutes.js`

---

## 9. Etapa 8: Despliegue en la nube — NO APLICABLE

Por indicación del docente, la **Etapa 8 (despliegue en la nube) se omite en esta entrega**. El sistema está configurado para ejecutarse **exclusivamente en entorno local** mediante Docker Compose. No hay URL pública, ni servidor externo, ni conexión cifrada a proveedor de nube. Todos los servicios (base de datos, API y frontend) se levantan en la máquina local con `docker compose up --build`.

---

## 10. Conclusiones y aprendizajes

El proyecto cumple con los requisitos de las etapas 1 a 7 del enunciado TPI Bodegas del Atuel. La base de datos opera como corazón del sistema con todas las reglas de negocio implementadas internamente (RN-01 a RN-15). La API REST expone los datos sin duplicar lógica, y el frontend presenta la información sin recalcular nada.

Decisiones clave que se mantendrían:
- SQL directo sin ORM, consultas parametrizadas.
- Base de datos como única fuente de verdad para reglas de negocio.
- Docker Compose para levantar todo el entorno con un solo comando.
- Semilla fija para carga masiva reproducible.

---

## 11. Archivos relacionados y estructura del repositorio

```
.
├── .env                          # Variables de entorno (no se sube al repo)
├── .env.example                  # Plantilla de variables de entorno
├── .gitignore                    # Archivos ignorados por git
├── README.md                     # Instrucciones de uso y lanzamiento
├── docker-compose.yml            # Orquestación de servicios (db, migrate, api, front, seed)
├── verificar_estructura.py       # Script de verificación de estructura
├── CARPETA TEMPORAL/             # Documentos de referencia y progreso del proyecto
├── db/
│   ├── migrations/               # Migraciones SQL (001 a 008)
│   ├── seed/                     # Script de carga masiva y catálogos CSV
│   └── tests/                    # Pruebas SQL (db_tests.sql)
├── api/
│   ├── src/                      # Código fuente Node.js/Express
│   ├── tests/                    # Tests unitarios (Jest + Supertest)
│   └── docs/openapi.json         # Documentación OpenAPI/Swagger
├── front/
│   ├── *.html                    # 5 pantallas del frontend
│   ├── js/                       # Capa de servicios (config.js, api.js)
│   ├── css/style.css             # Estilos
│   └── nginx/default.conf        # Configuración de nginx
├── consultas/                    # Consultas SQL etapa 5 (30 consultas comentadas)
└── docs/                         # Documentación técnica (DER, esquema, informes)
```
