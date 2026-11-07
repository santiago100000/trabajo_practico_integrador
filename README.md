# Bodegas del Atuel - TP Integrador de Bases de Datos (UTN FRSR)

Gestión y distribución de una empresa vitivinícola.

## Integrantes

| Integrante | GitHub |
|------------|--------|
| Puita Axel | |
| Cerda Santiago | |
| Serpa Juan Cruz | |

**Nota:** Los roles son rotativos, por lo que no se asignan responsabilidades fijas por integrante. Todos los integrantes participan en todas las etapas del proyecto.

---

## Descripción del proyecto

Sistema de gestión y distribución de una empresa vitivinícola llamado «Bodegas del Atuel». El proyecto modela la producción de uva, elaboración de vinos, stock en depósito central y salas de venta, clientes (socios, distribuidores, exportadores), ingresos, transferencias y comprobantes de venta.

Toda la lógica de negocio (reglas RN-01 a RN-15) está implementada dentro de PostgreSQL mediante constraints, funciones, procedimientos almacenados y triggers. La base de datos es el corazón del sistema; la API y el frontend solo consumen y presentan datos sin recalcular nada.

---

## Requisitos

- Docker y Docker Compose
- (Opcional) Python 3.12 local para ejecutar el script de carga masiva (`seed.py`) sin contenedor

---

## Cómo lanzar la aplicación

### 1. Configurar variables de entorno

```bash
cp .env.example .env
```

Editar el archivo `.env` con valores reales (contraseñas, puertos, etc.). **Nunca subir `.env` al repositorio**; está en `.gitignore`.

### 2. Levantar los servicios

```bash
docker compose up --build
```

Esto levanta tres servicios:

| Servicio | Descripción | Puerto local |
|----------|-------------|--------------|
| `db` | PostgreSQL 16 (base de datos) | `127.0.0.1:5433` |
| `migrate` | Aplica las migraciones SQL en orden (`db/migrations/001` a `008`) y termina | — |
| `api` | API REST de Node.js/Express | `http://localhost:8001` |
| `front` | Frontend estático con nginx | `http://localhost:8081` |

### 3. Verificar que la API está funcionando

```bash
curl http://localhost:8001/salud
```

Respuesta esperada:
```json
{"status":"ok","db":{"resultado":1}}
```

### 4. Abrir el frontend

El frontend está disponible en:

```
http://localhost:8081
```

### 5. Cargar datos de prueba (opcional pero recomendado)

Para probar con datos masivos (20.000 clientes, 150.000 comprobantes, 500.000+ renglones):

```bash
docker compose --profile seed run --rm seed
```

Esto ejecuta `db/seed/seed.py` con semilla fija (reproducible) y genera un volcado `dump_completo.sql.gz`.

---

## Cómo usar la API

La API expone los siguientes endpoints REST (puerto 8001):

### Salud
- `GET /salud` — Verifica conectividad con la base de datos.

### Vinos
- `GET /vinos` — Listado paginado de vinos. Query params opcionales: `page`, `limit`, `tipo`, `cepa`, `bodega`, `anada`.
- `GET /vinos/:cod` — Detalle completo de un vino (composición de cepas, maridajes y stock).
- `POST /vinos` — Crear un vino con su composición de cepas (transacción).
- `PUT /vinos/:cod` — Actualizar precio de un vino (dispara auditoría de precios, RN-13).
- `DELETE /vinos/:cod` — Eliminar un vino (si no tiene movimientos asociados, RN-14).

### Clientes
- `GET /clientes` — Listado de clientes con sus subtipos (socio, distribuidor, exportador).
- `GET /clientes/:id` — Detalle de un cliente.
- `POST /clientes` — Crear cliente con subtipo.
- `PUT /clientes/:id` — Actualizar cliente y subtipo.
- `DELETE /clientes/:id` — Eliminar cliente (en cascada borra subtipo).

### Comprobantes de venta
- `GET /comprobantes/:nro` — Detalle de un comprobante con sus renglones.
- `POST /comprobantes` — Crear comprobante con renglones (transacción; triggers calculan totales y descuentan stock, RN-08 y RN-09).

### Ingresos (depósito central)
- `POST /ingresos` — Crear ingreso en estado `en_confeccion`.
- `POST /ingresos/:cod/renglones` — Agregar renglones a un ingreso en confección (RN-12).
- `POST /ingresos/:cod/procesar` — Procesar ingreso (solo si estado es `terminado`; impacto en stock del depósito, RN-10).

### Transferencias (depósito → sala)
- `POST /transferencias` — Crear transferencia en estado `en_confeccion`.
- `POST /transferencias/:nro/renglones` — Agregar renglones a una transferencia en confección (RN-12).
- `POST /transferencias/:nro/terminar` — Cambiar estado a `terminado`.
- `POST /transferencias/:nro/procesar` — Procesar transferencia (valida stock en depósito, RN-11).

### Reportes
- `GET /reportes/top-vinos` — Top 10 vinos más vendidos.
- `GET /reportes/ventas-por-sala` — Ventas totales por sala en el último trimestre.
- `GET /reportes/vinos-sin-stock?id_sala=X` — Vinos sin stock en la sala X pero con stock en depósito.
- `GET /reportes/transportista-activo` — Transporte con más ingresos en el último mes.
- `GET /reportes/trazabilidad/:cod` — Ficha completa de un vino (cepas, maridajes, stock total).

---

## Consultas SQL (Etapa 5)

En la carpeta `consultas/` se encuentran los archivos SQL con consultas comentadas, estratégias y consultas de control previa/posterior:

| Archivo | Contenido |
|---------|-----------|
| `consultas/select.sql` | 12 consultas SELECT (S1 a S12): ranking, división relacional, filtros por fecha, CTE, funciones de ventana, anti-join, etc. |
| `consultas/insert.sql` | 6 sentencias INSERT (I1 a I6): cobertura transportista-localidad, maridajes condicionales, comprobantes con renglones, bodegas, salas, ingresos. |
| `consultas/update.sql` | 6 sentencias UPDATE (U1 a U6): recálculo de totales, aumento salarial, ajuste de precios, intercambio de días de cierre, descuentos a menos vendidos, descuentos a exportadores. |
| `consultas/delete.sql` | 6 sentencias DELETE (D1 a D6): borrado de comprobantes antiguos, cepas huérfanas, empleados con poca antigüedad, socios sin compras, ingresos procesados antiguos. |

Todas las sentencias están envueltas en transacciones (`BEGIN`/`ROLLBACK`) para pruebas seguras, y incluyen consultas de control previa y posterior.

---

## Pruebas

### Tests de base de datos (reglas de negocio RN-01 a RN-15)

```bash
docker compose exec db psql -U bodegas_owner -d bodegas -f /tests/db_tests.sql
```

Cada regla tiene un caso que debe funcionar y un caso que debe fallar, reportando `NOTICE "OK"` al pasar.

### Tests de la API (unitarios, con mocks)

```bash
cd api
npm install
npm test
```

---

## Estructura del repositorio

```
.
├── .env                          # Variables de entorno (no se sube al repo)
├── .env.example                  # Plantilla de variables de entorno
├── .gitignore                    # Archivos ignorados por git
├── README.md                     # Este archivo
├── docker-compose.yml            # Orquestación de servicios (db, migrate, api, seed)
├── verificar_estructura.py       # Script de verificación de estructura del proyecto
├── dump_completo.sql.gz          # Volcado completo de la base (generado, no se sube al repo)
├── CARPETA TEMPORAL/             # Documentos de referencia y progreso del proyecto
│   ├── progreso.md
│   ├── reglas_del_proyecto_bodegas_del_atuel.txt
│   ├── TPI_Bodegas_del_Atuel.md
│   ├── DOCKER_VARIABLES_PUERTOS_REDES.md
│   └── explicacion.md
├── db/
│   ├── migrations/               # Migraciones SQL (001 a 008)
│   │   ├── 001_esquema.sql       # Tipos, dominios, tablas, PK y FK
│   │   ├── 002_constraints.sql   # UNIQUE, CHECK, DEFAULT, acciones referenciales
│   │   ├── 003_funciones.sql     # 4 funciones de base de datos
│   │   ├── 004_procedimientos.sql # 2 procedimientos transaccionales
│   │   ├── 005_triggers.sql      # 8 triggers (BEFORE, AFTER, constraint diferido)
│   │   ├── 006_vistas.sql        # 3 vistas (1 materializada)
│   │   ├── 007_roles.sql         # 3 roles con privilegios mínimos
│   │   └── 008_indices.sql       # 6 índices para rendimiento
│   ├── migrate_entrypoint.sh     # Script de aplicación de migraciones
│   ├── seed/                     # Carga masiva de datos (Etapa 3)
│   │   ├── seed.py               # Script Python con Faker y semilla fija
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   ├── README.md
│   │   └── catalogos/            # CSV de catálogos (cepas, localidades, etc.)
│   └── tests/
│       ├── db_tests.sql          # Pruebas de reglas de negocio
│       └── prueba_etapa4_mediciones.sql  # Mediciones de índices
├── api/                          # API REST (Etapa 6)
│   ├── Dockerfile
│   ├── package.json
│   ├── docs/openapi.json
│   ├── src/
│   │   ├── app.js
│   │   ├── index.js
│   │   ├── config/db.js          # Pool de conexiones pg
│   │   ├── db/                   # Capa de acceso a datos (7 módulos)
│   │   ├── controllers/          # Controladores (7)
│   │   ├── routes/               # Rutas REST (7)
│   │   └── middlewares/
│   │       └── errorHandler.js   # Mapeo SQLSTATE → códigos HTTP
│   └── tests/                    # Tests de la API (mocks)
├── consultas/                    # Consultas SQL etapa 5 (select, insert, update, delete)
└── docs/                         # Documentación técnica
    ├── informe_etapa1_modelado.md
    ├── informe_etapa2_integridad.md
    ├── informe_etapa3_carga_masiva.md
    ├── informe_etapa4_indices.md
    ├── informe_etapa5_explain.md
    ├── esquema_relacional.md
    ├── diccionario_datos.md
    ├── normalizacion.md
    ├── decisiones_diseno.md
    ├── trazabilidad.md           # Trazabilidad RN-01 a RN-15
    └── der/                      # Diagrama entidad-relación
```

---

## Etapas completadas

| Hito | Etapa | Estado |
|------|-------|--------|
| H1 | Scaffolding inicial | ✅ Completa |
| H2 | Esquema, restricciones, funciones, procedimientos, triggers, vistas y roles (001 a 007) | ✅ Completa |
| H3 | Carga masiva de datos (db/seed/ con catálogos CSV y seed.py con Faker) | ✅ Completa |
| H4 | Índices y rendimiento (db/migrations/008_indices.sql, informe EXPLAIN antes/después) | ✅ Completa |
| H5 | Consultas SQL (archivos INSERT, UPDATE, DELETE, SELECT comentados) | ✅ Completa |
| H6 | API REST funcionando en local con Docker Compose | ✅ Completa |

---

## Decisiones de diseño clave

- **Base de datos como corazón del sistema:** Toda la lógica de negocio (RN-01 a RN-15) vive en PostgreSQL mediante constraints, funciones, procedimientos y triggers. La API no recalcula totales, descuentos ni stock.
- **SQL directo:** No se usa ORM ni query builders. Todas las consultas se escriben a mano con driver nativo (`pg` para Node.js, `psycopg` para Python).
- **Parametrización:** Todas las consultas SQL usan parámetros (`$1`, `$2`) para prevenir inyección SQL.
- **Errores SQLSTATE → HTTP:** La API traduce códigos de error de PostgreSQL a códigos HTTP claros (409 conflicto, 422 validación, 400 solicitud malformada, 503 concurrencia, etc.).
- **Rol de privilegios mínimos:** La API se conecta con el rol `app_rw` (lectura/escritura en tablas de negocio), nunca como superusuario/propietario.
- **Puerto de Postgres solo en localhost:** La base de datos se publica solo en `127.0.0.1` para no exponerla fuera de la máquina local.
- **Sin despliegue en la nube:** El sistema está diseñado para funcionar únicamente en entorno local. No hay etapa 8 de despliegue en la nube.

---

## Reglas de negocio implementadas (RN-01 a RN-15)

Cada regla está protegida por al menos un mecanismo en la base de datos:

| Regla | Descripción | Mecanismo |
|-------|-------------|-----------|
| RN-01 | Precio de vino > 0 y único por red | CHECK + UNIQUE |
| RN-02 | Sala → localidad única, encargado regional por localidad | FK + 3FN |
| RN-03 | Empleado → una sola sala | FK NOT NULL |
| RN-04 | Parcela → una cepa, cosecha una vez por campaña | FK + UNIQUE (parcela, campaña) |
| RN-05 | Porcentajes de corte suman 100 | Constraint trigger diferido |
| RN-06 | Descuento por tipo de cliente (10/20/30 %) | Función + CHECK rango |
| RN-07 | Vencimiento de permiso > emisión | CHECK entre columnas |
| RN-08 | Total de comprobante = suma de renglones | Función + trigger AFTER INSERT |
| RN-09 | No vender más stock del que hay | Trigger BEFORE INSERT + CHECK |
| RN-10 | Ingreso terminado → depósito → procesado | ENUM + procedimiento transaccional |
| RN-11 | Transferencia terminada → depósito → sala | Trigger de fecha + procedimiento |
| RN-12 | Sin confección no se modifican renglones | Trigger BEFORE sobre renglones |
| RN-13 | Cambio de precio auditado | Trigger AFTER UPDATE + tabla auditoría |
| RN-14 | No borrar entidad con movimientos | ON DELETE RESTRICT |
| RN-15 | Cantidades, superficies, kilos, precios > 0; graduación 5-20 | CHECK |

---

## Notas importantes

- **No subir `.env` al repositorio:** Contiene contraseñas y está en `.gitignore`.
- **`dump_completo.sql.gz` no se sube:** Está en `.gitignore`. Se genera localmente con `pg_dump`.
- **La API escucha en `http://localhost:8001`** (configurable vía `API_PORT` en `.env`).
- **La base de datos está en `127.0.0.1:5433`** (configurable vía `DB_PORT` en `.env`).
- Los archivos de la `CARPETA TEMPORAL/` son de referencia local del proyecto y contienen el enunciado original, reglas del proyecto y seguimiento de progreso.