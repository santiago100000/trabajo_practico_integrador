# Progreso del TPI - Bodegas del Atuel

## Estado general del repositorio

**Rama:** `main`  
**Último commit:** `1c48984` (Etapa 4: pasos 1 y 2 - selección de consultas y medición inicial EXPLAIN)  
**Push a `origin/main`:** ✅ Sincronizado  
**Última actualización:** 06/11/2026  

**Etapas completadas:** 1, 2, 3  
**Etapa en curso:** 4 (pasos 1 y 2 hechos; pasos 3 a 8 pendientes)  
**Etapas pendientes:** 5, 6, 7, 8, 9  

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

## Etapa 4: Índices y rendimiento — EN CURSO

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

**Pasos pendientes (6 a 8):**
- Paso 6: Justificar orden de columnas del índice compuesto y documentar un índice descartado
- Paso 7: Medir costo de escritura (carga masiva con y sin índices)
- Paso 8: Mostrar caso donde el planificador no use un índice existente y explicar por qué

**Archivos creados:**
- `db/migrations/008_indices.sql` (6 índices creados con justificación)
- `docs/informes/informe_etapa4_indices.md` (pasos 1 a 5 completos con resultados reales antes/después)

**Commit y push:** `96d31c1` — Push a `origin/main` ✅

---

## Cambios estructurales realizados (reducción a etapas 1-3)

- Eliminadas etapas 4 a 9 del repositorio (`api/`, `front/`, `consultas/`, `db/migrations/008_indices.sql` original, `docs/informes/informe_final.md`, `docs/informes/informe_etapa4_indices.md` original)
- `docker-compose.yml`: solo servicios `db`, `migrate` y `seed` (profile `seed`)
- `README.md`: hitos solo hasta H3, decisiones corregidas (migraciones con DDL real, no stubs), despliegue en nube marcado como pendiente
- `CARPETA TEMPORAL/`: solo `progreso.md` y `PROGRESO_ETAPA3.md` trackeados en el repo; el resto es referencia local
- `.gitignore`: ignora `/CARPETA TEMPORAL/` excepto `progreso.md` y `PROGRESO_ETAPA3.md`

---

## Próximos pasos sugeridos (cuando se decida continuar)

1. Completar Etapa 4 pasos 3 a 8 (requiere ejecutar EXPLAIN contra base cargada)
2. Etapa 5: Consultas SQL (INSERT, UPDATE, DELETE, SELECT)
3. Etapa 6: API REST con FastAPI
4. Etapa 7: Frontend con nginx
5. Etapa 8: Despliegue en la nube
6. Etapa 9: Documentación y defensa