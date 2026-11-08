# Progreso del TPI - Bodegas del Atuel

## Estado general del repositorio

**Rama:** `main`  
**Último commit:** `85e74a8` (fix(front): corregir conectividad con API en todas las pantallas)  
**Push a `origin/main`:** ✅ Sincronizado  
**Última actualización:** 08/11/2026  

**Etapas completadas:** 1, 2, 3, 4, 5, 6, 7  
**Etapa en curso:** ninguna  
**Etapas pendientes:** 9 (etapa 8 de despliegue en la nube descartada)  

---

## Etapa 1: Modelado — COMPLETADA ✅

**Fecha:** 05/11/2026  

**Qué se hizo:**
1. Revisión completa del proyecto (enunciado, README, migraciones, diccionario, normalización, DER, docker-compose, verificar_estructura.py).
2. Restauración de `docs/der/Esquema Relacional.dbml` (estaba borrado en git) con el esquema relacional completo (25 tablas, 6 enums).
3. `docs/esquema_relacional.md` escrito con el DBML completo.
4. `docs/decisiones_diseno.md` completado (jerarquía de clientes, claves, tipos de datos, atributos derivados, acciones referenciales, supuestos).
5. `verificar_estructura.py` ajustado: DDL real en etapa 1 es aviso, no error.
6. Puertos publicados fijos en `docker-compose.yml` (DB: 5433, API: 8001, Front: 8081) para evitar conflictos con otro proyecto.
7. Verificación: `001_esquema.sql` aplicado sin errores sobre base vacía (Docker).

**Commits y push:**
- `1d5e2d3`: Etapa 1 completa
- `63c2637`: Cambia puertos por defecto
- `77a3744`: Puertos publicados fijos en docker-compose
- Push a `origin/main` ✅

**Criterios de aceptación Etapa 1:** Todos ✅

**Notas:**
- Puertos fijos en docker-compose, no hace falta setear $env de PowerShell.
- `.env` está en .gitignore, no se sube.
- `CARPETA TEMPORAL/` no se sube al repositorio (solo `progreso.md` y `PROGRESO_ETAPA3.md` están trackeados).

---

## Etapa 2: Integridad y lógica en la base — COMPLETADA ✅

**Fecha:** 05/11/2026  

### Paso 1: `002_constraints.sql` — COMPLETADO ✅
- 12 UNIQUE adicionales, 20+ CHECK, 7 DEFAULT, todas las FK con ON DELETE/ON UPDATE justificados.
- Commit `1b60887` pusheado ✅

### Paso 2: `003_funciones.sql` — COMPLETADO ✅
- 4 funciones: fn_total_comprobante, fn_stock_sala, fn_descuento_cliente, fn_antiguedad_anios.
- Commit `63ff478` pusheado ✅

### Paso 3: `004_procedimientos.sql` — COMPLETADO ✅
- 2 procedimientos transaccionales: sp_procesar_ingreso, sp_procesar_transferencia (FOR UPDATE, todo o nada).
- Commit `63ff478` pusheado ✅

### Paso 4: `005_triggers.sql` — COMPLETADO ✅
- 8 triggers: 1 constraint diferido (RN-05), 5 BEFORE, 2 AFTER.
- Commit `2a3079b` pusheado ✅

### Paso 5: `006_vistas.sql` — COMPLETADO ✅
- 3 vistas: mv_stock_total_por_vino (materializada), vw_ventas_mensuales_por_sala, vw_documentos_pendientes.
- Commit `2a3079b` pusheado ✅

### Paso 6: `007_roles.sql` — COMPLETADO ✅
- 3 roles: bodegas_owner, app_rw, reporte_ro. REVOKE de PUBLIC. Contraseñas inyectadas via sed.
- Commit `3884958` pusheado ✅

### Paso 7: `tests/db_tests.sql` — COMPLETADO ✅
- Pruebas SQL para RN-01 a RN-15. Todas las NOTICE "OK" verificadas con Docker.
- Commit `f1e05d2` pusheado ✅

### Paso 8: Demostración de concurrencia — COMPLETADA ✅
- Informe escrito en `docs/informes/informe_final.md` (sección 8 y capítulo de capturas). **Nota: este archivo fue eliminado al reducir el proyecto a etapas 1-3; las capturas están en `docs/informes/Paso 8 Capturas/`.**
- 4 capturas: stock inicial, terminal 1 sin FOR UPDATE, terminal 2 sin FOR UPDATE, terminal 2 con FOR UPDATE.

**Commits y push Etapa 2:**
- `1b60887`, `63ff478`, `2a3079b`, `3884958`, `f1e05d2`, `b54a307` (trazabilidad)
- Push a `origin/main` ✅

**Criterios de aceptación Etapa 2:** Todos ✅
- Todos los mínimos de la tabla de requisitos alcanzados
- Cada regla RN-01 a RN-15 tiene mecanismo y caso de prueba
- Casos que deben fallar fallan con error claro; los que deben funcionan, funcionan
- Procesar transferencia sin stock no deja cambios a medias (ROLLBACK)
- API conecta con rol app_rw (no propietario, privilegios mínimos)

---

## Etapa 3: Carga masiva de datos — COMPLETADA ✅

**Fecha:** 05/11/2026  

### Paso 1: Catálogos desde CSV (anexo B) — COMPLETADO ✅
- Commit `5a49f44` — Push: OK
- `db/seed/seed.py` implementado con carga por lotes (`executemany`), semilla fija, orden de dependencias FK, `ON CONFLICT DO NOTHING`, consultas de control
- `db/seed/requirements.txt` — agregado `psycopg_pool`
- `db/seed/README.md` documentado
- CSV completados y limpios: `cepas.csv`, `localidades.csv`, `departamentos_mendoza.csv`, `tipos_vino.csv`, `presentaciones_ml.csv`, `maridajes.csv`
- Probado contra Docker: carga exitosa (10 cepas, 10 maridajes, 10 departamentos, 16 localidades)

### Paso 2: Orden de carga por dependencias FK — COMPLETADO ✅
- Commit `0d812a4` — Push: OK
- Diagrama en `docs/informes/diagrama Orden de carga (hecho en mermaid.ai).png`
- 7 niveles de carga respetando dependencias FK

### Paso 3 en adelante: Carga masiva con Faker — COMPLETADO ✅
- Commit `e942bb3`: Etapa 3 completa (carga masiva con Faker y dump_completo.sql.gz)
- Commit `00b115a`: Documenta decisión y riesgos de deshabilitar triggers en carga masiva
- `db/seed/seed.py` modo `--masivo` implementado: clientes (20.000), comprobantes (150.000), renglones de comprobante (500.000+), stock inicial, actualización de totales y stock, deshabilitación/rehabilitación de triggers, consultas de control
- `dump_completo.sql.gz` generado con `pg_dump` (no se sube al repo por `.gitignore`)
- `docs/informes/decision_triggers_carga_masiva.md`: decisión y riesgos documentados

**Estado del repositorio Etapa 3:**
- Rama: `main`
- Último commit push: `00b115a` (Etapa 3 completa)
- Todo sincronizado con `origin/main`

**Criterios de aceptación Etapa 3:**
- Se cumplen los mínimos de volumen (cliente 20.000, comprobante 150.000, renglón 500.000+)
- Dos ejecuciones con la misma semilla producen los mismos datos (semilla fija implementada)
- Consultas de control no encuentran inconsistencias (implementadas en seed.py)
- Documentado cómo se manejaron los triggers durante la carga (`decision_triggers_carga_masiva.md`)

---

## Etapa 4: Índices y rendimiento — COMPLETADA ✅

**Pasos completados:**

### Paso 1: Selección de consultas candidatas — COMPLETADO ✅
- Se seleccionaron 3 consultas de la sección 8 del enunciado:
  - **S1:** Ranking de los 10 vinos con mayor cantidad de botellas vendidas (`renglon_comprobante`, `comprobante`, `vino`)
  - **S4:** Top 5 salas que solicitaron mayor cantidad de un vino determinado mediante transferencias en los últimos 15 días (`renglon_transferencia`, `transferencia`)
  - **S8:** Monto total de ventas por sala en el último trimestre (`comprobante`, `sala_venta`)
- Documentado en `docs/informes/informe_etapa4_indices.md` y `db/migrations/008_indices.sql`

### Paso 2: Medición inicial con EXPLAIN (ANALYZE, BUFFERS) — COMPLETADO ✅ (datos reales)
- Comandos `ANALYZE` ejecutados en las 6 tablas involucradas
- Comandos `EXPLAIN (ANALYZE, BUFFERS)` ejecutados para S1, S4 y S8 contra la base cargada de la Etapa 3
- Resultados reales registrados en `docs/informes/informe_etapa4_indices.md`:
  - S1: 124.119 ms, Parallel Seq Scan sobre renglon_comprobante y comprobante
  - S4: 0.094 ms, Seq Scan, 0 filas (cod_vino=1 sin transferencias)
  - S8: 25.802 ms, Index Only Scan usando idx_comprobante_fecha_cubriendo
- Tabla resumen antes/después completada con tiempos base

### Paso 3: Diseño de índices — COMPLETADO ✅
- Se diseñaron 6 índices basados en los planes de ejecución observados:
  1. Compuesto (id_sala, fecha) en comprobante → S8
  2. Parcial WHERE cantidad = 0 en stock_sala → stock agotado
  3. Sobre FK cod_vino en renglon_comprobante → S1 (evita Parallel Seq Scan)
  4. De expresión UPPER(nombre) en vino → búsqueda case-insensitive
  5. BRIN en renglon_comprobante (nro_comprobante) → consultas de rango
  6. Sobre FK cod_vino en renglon_transferencia → S4
- Todos los requisitos mínimos cumplidos (≥5, compuesto, parcial, FK, expresión/BRIN)

### Paso 4: Creación de índices en 008_indices.sql — COMPLETADO ✅
- 6 índices creados en `db/migrations/008_indices.sql`, cada uno con justificación
- Commit `e62e644` pusheado a `origin/main` ✅

**Etapa 4 COMPLETA ✅** (todos los pasos 1 a 8 finalizados)

- Paso 5: Tabla comparativa antes/después con C1, C2, C3 — COMPLETADO ✅
  - C1: 13.716 ms (Parallel Seq Scan) → 0.813 ms (Index Only Scan), -94.1%
  - C2: 0.085 ms (Seq Scan) → 0.113 ms (Bitmap Index Scan parcial), sin mejora real
  - C3: 13.215 ms (Parallel Seq Scan) → 0.829 ms (Index Only Scan), -93.7%
  - Conclusión actualizada: ahora SÍ hay mejoras medidas en C1 y C3.
- Paso 7: Medir costo de escritura (carga masiva con y sin índices) — COMPLETADO ✅
  - INSERT 10,000 filas: 176.119 ms con índices vs 157.706 ms sin índices (+12%)
  - Creación de 6 índices: 324.316 ms total
- Paso 8: Mostrar caso donde el planificador no use un índice existente y explicar por qué — COMPLETADO ✅
  - Caso S1: consulta sin WHERE no usa índice en cod_vino (Parallel Seq Scan es más eficiente)

**Archivos creados:**
- `db/migrations/008_indices.sql` (6 índices creados con justificación)
- `docs/informes/informe_etapa4_indices.md` (pasos 1 a 8 completos con resultados reales)

**Commit y push:** `66ff4f2` (etapa 4) y `22e3e48` (etapa 5) — Push a `origin/main` ✅

---

## Etapa 5: Consultas SQL — COMPLETADA ✅

**Fecha:** 06/11/2026

### Consultas implementadas

| Archivo | Consultas | Cantidad |
|---------|-----------|----------|
| `consultas/select.sql` | S1 a S12 | 12 SELECT |
| `consultas/insert.sql` | I1 a I6 | 6 INSERT |
| `consultas/update.sql` | U1 a U6 | 6 UPDATE |
| `consultas/delete.sql` | D1 a D6 | 6 DELETE |

**Total:** 30 consultas SQL comentadas con enunciado, estrategia y consultas de control previa/posterior.

**Optimización aplicada:**
- S12a (clientes que compraron todos los vinos de una bodega) fue reescrita de `NOT EXISTS` correlionado doble (que generaba timeout >120s en EXPLAIN ANALYZE) a `GROUP BY` + `HAVING COUNT(DISTINCT ...)` para evitar planes de costo excesivo.

**Informe EXPLAIN:**
- `docs/informes/informe_etapa5_explain.md` documenta los planes de ejecución para S1, S4, S8, S9, S10, S11, S12a y S12b.

**Commit y push:** `22e3e48` — Push a `origin/main` ✅

**Criterios de aceptación Etapa 5:**
- Archivos INSERT, UPDATE, DELETE y SELECT comentados ✅
- Consultas avanzadas (división relacional, funciones de ventana, CTE, anti-join) implementadas ✅
- S12a optimizada para evitar timeout ✅

---

## Etapa 6: API REST — COMPLETADA ✅

**Fecha:** 07/11/2026

### Implementado
- Servidor Express en `api/src/app.js` y `api/src/index.js` escuchando en puerto 8001
- Capa de acceso a datos con `pg` (consultas parametrizadas, sin ORM) en `api/src/db/`
- 7 controladores en `api/src/controllers/`
- 7 rutas REST en `api/src/routes/`
- Middleware de manejo de errores SQLSTATE → códigos HTTP en `api/src/middlewares/errorHandler.js`
- Dockerfile en `api/Dockerfile` (Node.js 20-alpine, EXPOSE 8001)
- Documentación OpenAPI/Swagger en `api/docs/openapi.json`
- 12 pruebas unitarias con Jest y Supertest en `api/tests/`
- Servicio `api` en `docker-compose.yml` con healthcheck en puerto 8001

### Endpoints implementados
- `GET /salud` — Health check con consulta a BD
- `GET/POST/PUT/DELETE /vinos` — CRUD de vinos con composición y stock
- `GET/POST/PUT/DELETE /clientes` — CRUD de clientes con subtipos
- `GET/POST /comprobantes` — Comprobantes con renglones (triggers RN-08/RN-09)
- `POST/POST/POST /ingresos` — Crear, agregar renglones, procesar (sp_procesar_ingreso)
- `POST/POST/POST/POST /transferencias` — Crear, agregar renglones, terminar, procesar (sp_procesar_transferencia)
- `GET /reportes/*` — Top vinos, ventas por sala, vinos sin stock, transportista activo, trazabilidad

### Evidencia de funcionamiento
- `curl http://localhost:8001/salud` responde `{"status":"ok","db":{"resultado":1}}`
- Migraciones 001-008 aplicadas sin errores
- Rol `app_rw` conecta correctamente con privilegios mínimos
- CORS habilitado en la API (`cors` middleware) para permitir peticiones del frontend desde `http://localhost:8081`

**Commit y push:** `ee1272e` (README), `cf49de2` (informe etapa 6), `08e277e` (fix puertos 8001), `74d217f` (front con 5 pantallas y capa API), `b6d60ef` (front: criterios 4, 5, 6) — Push a `origin/main` ✅

**Criterios de aceptación Etapa 6:**
- API REST funcionando en local con Docker Compose ✅
- Retorna JSON ✅
- Traduce errores SQL a códigos HTTP claros ✅
- Conecta con rol de privilegios mínimos (app_rw) ✅
- Consultas SQL parametrizadas (sin inyección SQL) ✅

---

## Etapa 7: Frontend — COMPLETADA ✅

**Fecha:** 07/11/2026

### Implementado
- 5 pantallas en `front/`:
  - `index.html` — Dashboard / Inicio
  - `vinos.html` — Catálogo de vinos con filtros y paginación
  - `ventas.html` — Nueva venta / comprobantes (select de vinos, salas desde API)
  - `clientes.html` — Listado de clientes + formulario de alta + eliminar
  - `reportes.html` — Reportes (top vinos, ventas por sala, sin stock, trazabilidad)
- Capa de servicios centralizada:
  - `front/js/config.js` — URL base de la API configurable (`API_BASE_URL`)
  - `front/js/api.js` — Todas las llamadas a la API REST (`fetch`, parámetros)
- Estilos: `front/css/style.css`
- Servicio `front` en `docker-compose.yml` (nginx, puerto 8081)

### Correcciones realizadas en Etapa 7
| # | Problema | Solución |
|---|----------|----------|
| 1 | `ventas.html` siempre agregaba el primer vino | Select de vinos para elegir cuál vender |
| 2 | El front calculaba descuentos (violaba regla de oro) | Se envía `descuento_aplicado: 0`, la BD aplica RN-06 |
| 3 | `vinos.html` filtro "por nombre" buscaba por bodega | Parámetro `nombre` en API y front |
| 4 | Columna "Stock Total" siempre mostraba 0 | API calcula `stock_total` en `listarVinos()` |
| 5 | Salas hardcodeadas en `ventas.html` y `reportes.html` | Endpoint `GET /salas` en API, cargado dinámicamente |
| 6 | `clientes.html` solo listaba, sin CRUD | Formulario de alta + botón eliminar por fila |
| 7 | `vinos.html` sin paginación | Controles Anterior / Siguiente |
| 8 | No se podían crear clientes (3 errores) | `fecha_alta` por defecto, `descuento` calculado en API, trigger coherencia deferrable |

### Archivos nuevos (API)
- `api/src/db/salas.js` — Modelo `listarSalas()`
- `api/src/controllers/salasController.js` — Controlador de salas
- `api/src/routes/salasRoutes.js` — Ruta `GET /salas`
- `db/migrations/005_triggers.sql` — Trigger coherencia → DEFERRABLE

### Rediseño visual (Etapa 7)
Se rediseñó el frontend con un estilo minimalista, serio y tecnológico:
- Paleta basada en tonos de vino (burdeos #722F37, oro #B8860B, neutros cálidos)
- Eliminados emojis innecesarios para aspecto más profesional
- Tarjetas con bordes sutiles y sombras suaves
- Botones con tonos de vino y estados hover definidos
- Paginación en vinos con controles Anterior/Siguiente

### Criterios de aceptación cumplidos
| Criterio | Estado |
|----------|--------|
| Las 5 pantallas funcionan contra la API real (localhost:8001) | ✅ |
| Venta sin stock muestra mensaje de la regla y no deja datos a medias | ✅ |
| El front NO contiene lógica de cálculo de importes, descuentos ni stock | ✅ |
| Mensajes de error de reglas de negocio mostrados tal cual | ✅ |
| Front incluido en docker-compose.yml | ✅ |
| Creación de clientes funciona (socio, distribuidor, exportador) | ✅ |

**Commits y push Etapa 7:**
- `ee1272e` (README), `cf49de2` (informe etapa 6), `08e277e` (fix puertos 8001)
- `74d217f` (front con 5 pantallas y capa API)
- `b6d60ef` (front: criterios 4, 5, 6)
- `d9c2b54` (fix(api): USAGE schema public a app_rw y reporte_ro)
- `d48798b` (fix(seed): esperar a migrate, OWNER_DB_PASSWORD)
- `5316f14` (docs(readme): sección de uso diario)
- `b6b626a` (docs: informe Etapa 7 Frontend)
- `04f4791` (fix(etapa7): corregir creación de clientes desde el front)
- `82d6e3b` (design(front): rediseño minimalista, serio y tecnológico)
- Push a `origin/main` ✅

### Informes creados (etapas 1-7)
- `docs/informes/informe_etapa1_modelado.md`
- `docs/informes/informe_etapa2_integridad.md`
- `docs/informes/informe_etapa3_carga_masiva.md`
- `docs/informes/informe_etapa4_indices.md`
- `docs/informes/informe_etapa5_explain.md`
- `docs/informes/informe_etapa6_api.md`
- `docs/informes/informe_etapa7_front.md`

---

## Cambios estructurales realizados

- `docker-compose.yml`: servicios `db`, `migrate` y `seed` (profile `seed`)
- `README.md`: hitos actualizados hasta H6, integrantes reales (Puita Axel, Cerda Santiago, Serpa Juan Cruz), roles rotativos, instrucciones de lanzamiento y uso de la API, decisiones corregidas (migraciones con DDL real, no stubs), despliegue en nube descartado
- `CARPETA TEMPORAL/`: `progreso.md` y documentos de referencia trackeados en el repo
- `.gitignore`: ignora `/CARPETA TEMPORAL/` excepto `progreso.md`, `DOCKER_VARIABLES_PUERTOS_REDES.md`, `explicacion.md`, `reglas_del_proyecto_bodegas_del_atuel.txt`, `TPI_Bodegas_del_Atuel.md`

---

**Informes creados (etapas 1-6):**
- `docs/informes/informe_etapa1_modelado.md` — Modelo, normalización, diccionario, decisiones de diseño.
- `docs/informes/informe_etapa2_integridad.md` — Constraints, funciones, procedimientos, triggers, vistas, roles, pruebas.
- `docs/informes/informe_etapa3_carga_masiva.md` — Catálogos CSV, orden de carga FK, carga masiva Faker, triggers, consultas de control.
- `docs/informes/informe_etapa4_indices.md` — Índices y rendimiento (pasos 1 a 8 con resultados reales EXPLAIN).
- `docs/informes/informe_etapa5_explain.md` — Planes EXPLAIN para consultas S1 a S12 (reescrito en español con formato consistente a los demás informes).
- `docs/informes/informe_etapa6_api.md` — API REST: arquitectura, endpoints, tests, despliegue Docker.

## Próximos pasos sugeridos (cuando se decida continuar)

1. Etapa 9: Documentación y defensa (etapa 8 de despliegue en la nube descartada)