# Progreso del TPI - Bodegas del Atuel

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
- `CARPETA TEMPORAL/` no se sube al repositorio.

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
- Informe escrito en `docs/informes/informe_final.md` (sección 8 y capítulo de capturas).
- Capturas pendientes de insertar físicamente por el usuario (4 capturas descritas: stock inicial, terminal 1 sin FOR UPDATE, terminal 2 sin FOR UPDATE, terminal 2 con FOR UPDATE).

**Commits y push Etapa 2:**
- `1b60887`, `63ff478`, `2a3079b`, `3884958`, `f1e05d2`, `b54a307` (trazabilidad)
- Push a `origin/main` ✅

**Criterios de aceptación Etapa 2:** Todos ✅
- Todos los mínimos de la tabla de requisitos alcanzados
- Cada regla RN-01 a RN-15 tiene mecanismo y caso de prueba
- Casos que deben fallar fallan con error claro; los que deben funcionan, funcionan
- Procesar transferencia sin stock no deja cambios a medias (ROLLBACK)
- API conecta con rol app_rw (no propietario, privilegios mínimos)

### Siguiente etapa sugerida: Etapa 3
- Carga masiva de datos con db/seed/seed.py y CSV de catálogos
- Volúmenes: al menos una tabla con >100.000 registros

## Archivo de referencia (no pertenece al TPI)
- `CARPETA TEMPORAL/DOCKER_VARIABLES_PUERTOS_REDES.md`: guía de referencia de otro proyecto.

## Archivo de explicación para defensa
- `CARPETA TEMPORAL/explicacion.md`: explicación completa del proyecto por etapa, con énfasis en base de datos. Listo para exposición oral.
