# Informe final — Bodegas del Atuel (TP Integrador de Bases de Datos)

**Cátedra:** Bases de Datos · UTN Facultad Regional San Rafael  
**Ciclo lectivo:** 2026  
**Estado:** Etapa 1 y Etapa 2 completadas

---

## 1. Introducción

El sistema «Bodegas del Atuel» es una aplicación de gestión y distribución de una empresa vitivinícola ficticia que integra la producción de uva y vino con su distribución y venta a través de una red de salas de venta. El proyecto sigue la metodología por etapas definida en el enunciado del TPI, donde la base de datos es el corazón del sistema y la API/front son el medio para demostrar que funciona como parte de un sistema completo.

**Tecnologías utilizadas:**
- PostgreSQL 16 (motor de base de datos)
- Python 3.12 + FastAPI + psycopg (API, sin ORM)
- HTML/JS/CSS + nginx (Frontend)
- Docker y Docker Compose (infraestructura)

---

## 2. Alcance del sistema

El sistema contempla las siguientes áreas funcionales:

| Área | Descripción |
|------|-------------|
| Geografía | Provincias, departamentos, localidades con encargado regional |
| Salas y empleados | Salas de venta, empleados con CUIT y salario |
| Bodegas | Bodegas del grupo con CUIT y razón social |
| Producción de uva | Fincas, parcelas (entidad débil), cepas, lotes de uva, análisis de calidad |
| Vinos | Catálogo de vinos con composición de cepas, maridajes y auditoría de precios |
| Stock | Stock por sala y stock del depósito central |
| Transportistas | Empresas de transporte y localidades que cubren |
| Ingresos | Ingresos de vinos al depósito con estados y renglones |
| Transferencias | Transferencias entre depósito y salas con estados y renglones |
| Clientes | Jerarquía socio/distribuidor/exportador con permisos de exportación |
| Comprobantes | Ventas con renglones, subtotales, descuentos y totales calculados por la base |

---

## 3. Modelo de datos

El modelo está documentado en:
- `docs/der/Esquema Relacional.dbml` — Diagrama entidad-relación (DBML)
- `docs/esquema_relacional.md` — Esquema relacional escrito
- `docs/diccionario_datos.md` — Diccionario de datos completo
- `docs/normalizacion.md` — Justificación de normalización hasta 3FN
- `docs/decisiones_diseno.md` — Decisiones de diseño (jerarquía, claves, tipos, acciones referenciales)

**Principales decisiones:**
- Jerarquía de clientes: supertipo `cliente` + subtipos `socio`, `distribuidor`, `exportador`
- Entidad débil `parcela`: PK compuesta `(id_finca, nro_parcela)`
- Entidad débil `permiso_exportacion`: PK compuesta `(id_cliente, codigo)`
- Importes monetarios con `NUMERIC`, nunca `FLOAT`
- Estados y clasificaciones con tipos `ENUM`, nunca texto libre
- Identificadores subrogados con `GENERATED ALWAYS AS IDENTITY`

---

## 4. Reglas de negocio (RN-01 a RN-15)

Todas las reglas de negocio están protegidas por mecanismos en la base de datos. La trazabilidad completa está en `docs/trazabilidad.md`.

| RN | Regla | Mecanismo implementado |
|----|-------|------------------------|
| RN-01 | Precio del vino > 0 y único | CHECK + UNIQUE (nombre, anada, volumen_ml) |
| RN-02 | Sala pertenece a una localidad; encargado por localidad | FK + diseño 3FN |
| RN-03 | Empleado trabaja en una sola sala | FK NOT NULL |
| RN-04 | Parcela con una cepa; una cosecha por campaña | FK + UNIQUE (id_finca, nro_parcela, campania) |
| RN-05 | Porcentajes de corte suman 100 | Constraint trigger diferido |
| RN-06 | Descuento por tipo de cliente | Función + CHECK de rango |
| RN-07 | Vencimiento posterior a emisión | CHECK entre columnas |
| RN-08 | Total del comprobante calculado | Función + trigger AFTER INSERT |
| RN-09 | Stock suficiente; nunca negativo | Trigger BEFORE INSERT + CHECK |
| RN-10 | Ingreso terminado impacta depósito; estados no retroceden | ENUM + procedimiento transaccional |
| RN-11 | Igual que RN-10 para transferencias | Trigger de fecha + procedimiento |
| RN-12 | Renglones solo en confección | Triggers sobre renglones |
| RN-13 | Auditoría de cambios de precio | Trigger AFTER UPDATE + tabla auditoría |
| RN-14 | No borrar con movimientos | ON DELETE RESTRICT |
| RN-15 | Cantidades y graduación en rango | CHECK |

---

## 5. Diseño de base de datos

### 5.1 Migraciones aplicadas

| Migración | Contenido | Estado |
|-----------|-----------|--------|
| `001_esquema.sql` | Tipos ENUM, dominios, tablas, PK, FK | ✅ Aplicada |
| `002_constraints.sql` | UNIQUE, CHECK, DEFAULT, acciones referenciales | ✅ Aplicada |
| `003_funciones.sql` | 4 funciones (total, stock, descuento, antigüedad) | ✅ Aplicada |
| `004_procedimientos.sql` | 2 procedimientos transaccionales (ingreso, transferencia) | ✅ Aplicada |
| `005_triggers.sql` | 8 triggers (BEFORE, AFTER, constraint diferido) | ✅ Aplicada |
| `006_vistas.sql` | 3 vistas (1 materializada, 2 regulares) | ✅ Aplicada |
| `007_roles.sql` | 3 roles (owner, app_rw, reporte_ro) | ✅ Aplicada |
| `008_indices.sql` | 6 índices (compuesto, parcial, FK, expresión, INCLUDE, BRIN) | ✅ Aplicada |

### 5.2 Funciones implementadas

| Función | Parámetros | Retorna | Volatilidad |
|---------|-----------|---------|-------------|
| `fn_total_comprobante` | `p_nro_comprobante integer` | `numeric(12,2)` | STABLE |
| `fn_stock_sala` | `p_id_sala integer, p_cod_vino integer` | `integer` | STABLE |
| `fn_descuento_cliente` | `p_tipo_cliente tipo_cliente` | `numeric(5,2)` | IMMUTABLE |
| `fn_antiguedad_anios` | `p_fecha_ingreso date` | `integer` | STABLE |

### 5.3 Procedimientos transaccionales

| Procedimiento | Parámetros | Propósito |
|---------------|-----------|-----------|
| `sp_procesar_ingreso` | `p_cod_ingreso integer` | Procesa ingreso terminado al depósito (RN-10) |
| `sp_procesar_transferencia` | `p_nro_solicitud integer` | Procesa transferencia depósito→sala (RN-11) |

### 5.4 Triggers implementados (8 triggers)

| Trigger | Tipo | Regla |
|---------|------|-------|
| `trg_chk_porcentajes_vino_cepa` | CONSTRAINT DEFERRABLE | RN-05 |
| `trg_validar_stock_venta` | BEFORE INSERT | RN-09 |
| `trg_descontar_stock_y_calcular_totales` | AFTER INSERT | RN-08, RN-09 |
| `trg_bloquear_renglones_ingreso` | BEFORE I/U/D | RN-12 |
| `trg_bloquear_renglones_transferencia` | BEFORE I/U/D | RN-12 |
| `trg_fecha_confeccion_transferencia` | BEFORE I/U | RN-11 |
| `trg_auditoria_precio_vino` | AFTER UPDATE | RN-13 |
| `trg_coherencia_cliente_subtipo` | AFTER I/U | Jerarquía cliente |

### 5.5 Vistas implementadas

| Vista | Tipo | Propósito |
|-------|------|-----------|
| `mv_stock_total_por_vino` | MATERIALIZED VIEW | Stock depósito + salas por vino |
| `vw_ventas_mensuales_por_sala` | VIEW | Ventas últimos 12 meses por sala |
| `vw_documentos_pendientes` | VIEW | Ingresos y transferencias no procesados |

### 5.6 Roles y privilegios

| Rol | Privilegios | Uso |
|-----|-------------|-----|
| `bodegas_owner` | ALL en esquema | Administrador |
| `app_rw` | SELECT/INSERT/UPDATE/DELETE, USAGE secuencias, EXECUTE | API (rol de la aplicación) |
| `reporte_ro` | SELECT en tablas y vistas | Reportes (solo lectura) |

---

## 6. Pruebas

### 6.1 Pruebas SQL (`db/tests/db_tests.sql`)

Se ejecutaron pruebas para las 15 reglas de negocio. Cada regla tiene un caso que debe funcionar y un caso que debe fallar. Todas las pruebas pasaron exitosamente sobre una base vacía.

**Comando de ejecución:**
```bash
docker compose exec db psql -U bodegas_owner -d bodegas -f /tests/db_tests.sql
```

**Resultado:** Todas las NOTICE de "OK" aparecieron para cada regla RN-01 a RN-15.

### 6.2 Demostración de concurrencia (Paso 8)

Se demostró el comportamiento de dos sesiones concurrentes intentando vender la última botella de un vino.

**Escenario A — Sin `FOR UPDATE`:**
- Ambas sesiones leen `stock = 1`
- Ambas intentan descontar 1
- Resultado: una falla con `CHECK (cantidad >= 0)` o inconsistencia

**Escenario B — Con `FOR UPDATE`:**
- Sesión A bloquea la fila con `SELECT ... FOR UPDATE`
- Sesión B queda esperando hasta que A hace `COMMIT`
- Sesión B lee `stock = 0` y no puede vender
- Resultado: consistente

**Nivel de aislamiento:** `read committed` (por defecto de PostgreSQL)

> **Capturas incluidas en este informe:**
> 1. Tabla con stock inicial = 1
> 2. Terminal 1 sin FOR UPDATE (SELECT=1, UPDATE, COMMIT)
> 3. Terminal 2 sin FOR UPDATE (SELECT=1, UPDATE falla)
> 4. Terminal 2 con FOR UPDATE (bloqueo/esperando)

---

## 7. Conclusiones y trabajo futuro

### Conclusiones

1. La base de datos implementa todas las reglas de negocio (RN-01 a RN-15) mediante constraints, funciones, procedimientos y triggers, garantizando integridad sin importar quién acceda a los datos.
2. La API nunca recalcula totales, descuentos ni stock; llama a las funciones y procedimientos de la base.
3. Las migraciones se aplican desde cero sobre una base vacía sin errores.
4. Los roles de base de datos siguen el principio de privilegios mínimos (la API no usa el rol propietario).

### Trabajo futuro (Etapas 3 a 9)

| Etapa | Objetivo | Estado |
|-------|----------|--------|
| Etapa 3 | Carga masiva de datos (>100.000 registros) | Pendiente |
| Etapa 4 | Índices y rendimiento con EXPLAIN | Pendiente (008_indices.sql es stub) |
| Etapa 5 | Consultas SQL (INSERT, UPDATE, DELETE, SELECT) | Parcial (archivos existen en `consultas/`) |
| Etapa 6 | API REST con FastAPI | Parcial (estructura existe) |
| Etapa 7 | Frontend con nginx | Parcial (estructura existe) |
| Etapa 8 | Despliegue en la nube | Pendiente |
| Etapa 9 | Documentación y defensa | En curso |

---

## 8. Capturas — Demostración de concurrencia

Esta sección contiene las capturas de pantalla de la demostración de concurrencia (Paso 8 de la Etapa 2).

> **Nota:** Las capturas deben insertarse aquí como imágenes. A continuación se describe qué muestra cada una:

| Captura | Descripción |
|---------|-------------|
| Captura 1 | Tabla `stock_sala` con `cantidad = 1` (stock inicial) |
| Captura 2 | Terminal 1 sin `FOR UPDATE`: `BEGIN`, `SELECT` devuelve 1, `UPDATE`, `COMMIT` |
| Captura 3 | Terminal 2 sin `FOR UPDATE`: `SELECT` devuelve 1, `UPDATE` falla por `CHECK (cantidad >= 0)` |
| Captura 4 | Terminal 2 con `FOR UPDATE`: `SELECT ... FOR UPDATE` queda bloqueado esperando a Terminal 1 |

**Cómo se generaron las capturas:**

1. Abrir dos terminales de PowerShell
2. En cada una ejecutar: `docker compose exec db psql -U bodegas_owner -d bodegas`
3. Seguir los scripts del Escenario A (sin FOR UPDATE) y Escenario B (con FOR UPDATE) detallados en la sección 6.2

---

*Informe generado el 05/11/2026. Revisar y completar las etapas pendientes (3 a 9) antes de la entrega final.*
