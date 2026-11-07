# Informe Etapa 6 — API REST (Bodegas del Atuel)

**Proyecto:** Bodegas del Atuel — TP Integrador de Bases de Datos (UTN FRSR)  
**Etapa:** 6 — API REST  
**Estado:** Completa y operativa  
**Archivo relacionado:** `api/` (código fuente), `docker-compose.yml` (servicio `api`), `docs/openapi.json` (documentación OpenAPI/Swagger)

---

## 1. Descripción general

La Etapa 6 implementa una API REST en Node.js con Express que conecta a la base de datos PostgreSQL desarrollada en las etapas 1 a 5. La API expone endpoints para gestionar vinos, clientes, comprobantes de venta, ingresos, transferencias y reportes, respetando la regla de oro del proyecto: **la base de datos es el corazón del sistema**, por lo que toda la lógica de negocio (RN-01 a RN-15) vive en PostgreSQL y la API solo consume y presenta datos sin recalcular nada.

La API se despliega localmente con Docker Compose y se comunica con la base de datos usando el rol `app_rw` (privilegios mínimos: lectura/escritura en tablas de negocio), nunca como superusuario.

---

## 2. Arquitectura y estructura de archivos

```
api/
├── Dockerfile                    # Imagen Node.js 20-alpine, expone puerto 8001
├── package.json                  # Dependencias: express, pg, dotenv, jest, supertest
├── docs/openapi.json             # Documentación OpenAPI/Swagger de la API
├── src/
│   ├── app.js                    # Configuración de Express, middlewares, rutas
│   ├── index.js                  # Punto de entrada, escucha en PORT (default 8001)
│   ├── config/
│   │   └── db.js                 # Pool de conexiones pg (parámetros desde .env)
│   ├── db/                       # Capa de acceso a datos (7 módulos)
│   │   ├── index.js              # Exporta el pool
│   │   ├── salud.js              # Consulta de salud (SELECT 1)
│   │   ├── vinos.js              # CRUD vinos, composición, maridajes, stock
│   │   ├── clientes.js           # CRUD clientes con subtipos (socio/distribuidor/exportador)
│   │   ├── comprobantes.js       # Crear comprobante con renglones (transacción)
│   │   ├── ingresos.js           # Crear ingreso, agregar renglones, procesar (sp_procesar_ingreso)
│   │   ├── transferencias.js     # Crear transferencia, agregar renglones, terminar, procesar (sp_procesar_transferencia)
│   │   └── reportes.js           # Top vinos, ventas por sala, vinos sin stock, transportista activo, trazabilidad
│   ├── controllers/              # Controladores (7)
│   │   ├── saludController.js
│   │   ├── vinosController.js
│   │   ├── clientesController.js
│   │   ├── comprobantesController.js
│   │   ├── ingresosController.js
│   │   ├── transferenciasController.js
│   │   └── reportesController.js
│   ├── routes/                   # Rutas REST (7)
│   │   ├── saludRoutes.js
│   │   ├── vinosRoutes.js
│   │   ├── clientesRoutes.js
│   │   ├── comprobantesRoutes.js
│   │   ├── ingresosRoutes.js
│   │   ├── transferenciasRoutes.js
│   │   └── reportesRoutes.js
│   └── middlewares/
│       └── errorHandler.js       # Mapeo SQLSTATE → códigos HTTP
└── tests/                        # Tests unitarios con mocks
    ├── api.test.js               # 12 pruebas de endpoints
    ├── setup.js                  # Configuración de mocks de pg
    └── helpers/
        └── mockPool.js           # Simulación de pool de pg para tests
```

---

## 3. Endpoints implementados

### 3.1 Salud
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/salud` | Verifica conectividad con la base de datos (`SELECT 1`). Responde `{"status":"ok","db":{"resultado":1}}` |

### 3.2 Vinos
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/vinos` | Listado paginado de vinos. Query params: `page`, `limit`, `tipo`, `cepa`, `bodega`, `anada` |
| GET | `/vinos/:cod` | Detalle completo de un vino (composición de cepas, maridajes, stock en depósito y salas) |
| POST | `/vinos` | Crear un vino con su composición de cepas (transacción) |
| PUT | `/vinos/:cod` | Actualizar precio de un vino (dispara trigger `trg_auditoria_precio_vino`, RN-13) |
| DELETE | `/vinos/:cod` | Eliminar un vino (si no tiene movimientos asociados, RN-14) |

### 3.3 Clientes
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/clientes` | Listado de clientes con sus subtipos (socio, distribuidor, exportador) |
| GET | `/clientes/:id` | Detalle de un cliente |
| POST | `/clientes` | Crear cliente con subtipo (transacción) |
| PUT | `/clientes/:id` | Actualizar cliente y subtipo (transacción) |
| DELETE | `/clientes/:id` | Eliminar cliente (en cascada borra la fila del subtipo) |

### 3.4 Comprobantes de venta
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/comprobantes/:nro` | Detalle de un comprobante con sus renglones |
| POST | `/comprobantes` | Crear comprobante con renglones (transacción; triggers calculan totales RN-08 y descuentan stock RN-09) |

### 3.5 Ingresos (depósito central)
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | `/ingresos` | Crear ingreso en estado `en_confeccion` |
| POST | `/ingresos/:cod/renglones` | Agregar renglones a un ingreso en confección (RN-12: solo si estado es `en_confeccion`) |
| POST | `/ingresos/:cod/procesar` | Procesar ingreso (solo si estado es `terminado`; impacto en stock del depósito, RN-10; usa `sp_procesar_ingreso`) |

### 3.6 Transferencias (depósito → sala)
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | `/transferencias` | Crear transferencia en estado `en_confeccion` (fecha de confección = actual, RN-11) |
| POST | `/transferencias/:nro/renglones` | Agregar renglones a una transferencia en confección (RN-12) |
| POST | `/transferencias/:nro/terminar` | Cambiar estado a `terminado` |
| POST | `/transferencias/:nro/procesar` | Procesar transferencia (valida stock en depósito, descuenta y suma a sala, RN-11; usa `sp_procesar_transferencia`) |

### 3.7 Reportes
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/reportes/top-vinos` | Top 10 vinos más vendidos (ranking por botellas) |
| GET | `/reportes/ventas-por-sala` | Ventas totales por sala en el último trimestre |
| GET | `/reportes/vinos-sin-stock?id_sala=X` | Vinos sin stock en la sala X pero con stock en depósito central |
| GET | `/reportes/transportista-activo` | Transporte con más ingresos en el último mes |
| GET | `/reportes/trazabilidad/:cod` | Ficha completa de un vino (cepas, maridajes, stock total) |

---

## 4. Capa de acceso a datos

La capa de acceso a datos (`api/src/db/`) utiliza el driver nativo `pg` de PostgreSQL con consultas parametrizadas (`$1`, `$2`, etc.) para prevenir inyección SQL. Cada módulo exporta funciones asíncronas que utilizan el pool de conexiones configurado en `api/src/config/db.js`.

**Características clave:**
- **Consultas parametrizadas:** Todas las sentencias SQL usan placeholders (`$1`, `$2`) para prevenir inyección SQL.
- **Transacciones:** Las operaciones de escritura que afectan múltiples tablas (crear vino con composición, crear comprobante con renglones, crear cliente con subtipo, etc.) usan `BEGIN`/`COMMIT`/`ROLLBACK` para garantizar atomicidad.
- **Uso de procedimientos almacenados:** `procesarIngreso()` llama a `sp_procesar_ingreso()` y `procesarTransferencia()` llama a `sp_procesar_transferencia()`, delegando la lógica de negocio a la base de datos.
- **Pool de conexiones:** Configurado con `max: 10`, `idleTimeoutMillis: 30000`, `connectionTimeoutMillis: 5000`.

---

## 5. Manejo de errores

El middleware `api/src/middlewares/errorHandler.js` mapea códigos SQLSTATE de PostgreSQL a códigos HTTP claros:

| SQLSTATE | Código HTTP | Significado |
|----------|-------------|-------------|
| `23505` | 409 | UNIQUE violado (conflicto) |
| `23503` | 409 | FOREIGN KEY violada (referencia inválida) |
| `23514` | 422 | CHECK violado (regla de negocio RN-XX) |
| `23502` | 422 | NOT NULL violado (campo requerido) |
| `P0001` | 409 | Excepción PL/pgSQL desde trigger o procedimiento (regla de negocio) |
| `22P02` | 400 | Formato/tipo inválido |
| `40001` / `40P01` | 503 | Fallo de serialización o deadlock (concurrencia) |
| default | 500 | Error interno del servidor |

Esto permite que la API traduzca errores de base de datos en respuestas HTTP claras sin exponer detalles internos en producción.

---

## 6. Docker y despliegue local

La API se despliega como servicio en `docker-compose.yml`:

```yaml
api:
  build: ./api
  container_name: bodegas_api
  ports:
    - "127.0.0.1:8001:8001"
  environment:
    DB_HOST: db
    DB_PORT: 5432
    DB_USER: app_rw
    DB_PASSWORD: ${APP_DB_PASSWORD}
    DB_NAME: ${POSTGRES_DB}
    PORT: 8001
  depends_on:
    db:
      condition: service_healthy
    migrate:
      condition: service_completed_successfully
  healthcheck:
    test: ["CMD-SHELL", "node -e \"require('http').get({host:'127.0.0.1',port:8001,path:'/salud',timeout:2000},r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))\""]
    interval: 10s
    timeout: 5s
    retries: 10
    start_period: 15s
  restart: unless-stopped
```

**Puerto estandarizado a 8001** en todos los archivos:
- `.env`: `API_PORT=8001`
- `api/Dockerfile`: `EXPOSE 8001`
- `docker-compose.yml`: `127.0.0.1:8001:8001`, `PORT: 8001`, healthcheck `port:8001`
- `api/src/index.js`: `const PORT = parseInt(process.env.PORT || process.env.API_PORT, 10) || 8001;`

---

## 7. Tests

### Tests unitarios de la API (`api/tests/api.test.js`)

Se implementaron **12 pruebas unitarias** utilizando Jest y Supertest, con un mock del pool de pg (`mockPool.js`) que simula respuestas de base de datos sin requerir una instancia real:

| # | Prueba | Endpoint | Resultado esperado |
|---|--------|----------|-------------------|
| 1 | Salud responde 200 | `GET /salud` | 200, `status: 'ok'` |
| 2 | Listado paginado de vinos | `GET /vinos` | 200, array de vinos |
| 3 | Detalle completo de vino | `GET /vinos/:cod` | 200, con composición, maridajes, stock |
| 4 | Vino no encontrado | `GET /vinos/:cod` inexistente | 404 |
| 5 | Crear vino en transacción | `POST /vinos` | 201, `cod_vino` devuelto |
| 6 | Precio negativo rechazado | `POST /vinos` precio < 0 | 422, `CHECK_VIOLATED` |
| 7 | Stock insuficiente | `POST /comprobantes` stock < cantidad | 409, `PLPGSQL_RAISE` (RN-09) |
| 8 | Transferencia no en confección | `POST /transferencias/:nro/terminar` | 409 (conflicto) |
| 9 | Crear cliente con subtipo | `POST /clientes` | 201, `id_cliente` devuelto |
| 10 | Top vinos report | `GET /reportes/top-vinos` | 200, array de vinos |
| 11 | Trazabilidad de vino | `GET /reportes/trazabilidad/:cod` | 200, ficha completa |
| 12 | Vinos sin stock | `GET /reportes/vinos-sin-stock` | 200, array de vinos |

### Tests de base de datos

Las reglas de negocio RN-01 a RN-15 se prueban con `db/tests/db_tests.sql`, ejecutable contra la base de datos real:

```bash
docker compose exec db psql -U bodegas_owner -d bodegas -f /tests/db_tests.sql
```

---

## 8. Evidencia de funcionamiento

La API ha sido levantada exitosamente con `docker compose up --build` y el endpoint de salud responde correctamente:

```bash
$ curl http://localhost:8001/salud
{"status":"ok","db":{"resultado":1}}
```

Esto confirma que:
- El contenedor de la API se construye y arranca correctamente
- La API se conecta a la base de datos PostgreSQL 16
- Las migraciones (001 a 008) se aplican sin errores
- El rol `app_rw` puede consultar la base de datos
- El healthcheck de Docker Compose pasa correctamente

---

## 9. Decisiones de diseño

| Decisión | Justificación |
|----------|---------------|
| **Node.js + Express** | Framework ligero y ampliamente conocido, fácil de integrar con PostgreSQL |
| **Driver nativo `pg`** | Cumple la regla de oro del proyecto: SQL directo, sin ORM ni query builders que oculten el SQL |
| **Consultas parametrizadas** | Previene inyección SQL, requisito del enunciado |
| **Transacciones en operaciones de escritura** | Garantiza atomicidad (todo o nada) en operaciones multi-tabla |
| **Uso de procedimientos almacenados** | La lógica de negocio (procesar ingreso/transferencia) vive en la BD, la API solo llama a los procedures |
| **Rol `app_rw` con privilegios mínimos** | La API no se conecta como superusuario, cumple requisito de seguridad del enunciado |
| **Mapeo SQLSTATE → HTTP** | Traduce errores de PostgreSQL a códigos HTTP claros para el cliente |
| **Puerto 8001** | Evita conflictos con otros proyectos locales, estandarizado en todos los archivos de configuración |

---

## 10. Cómo ejecutar y probar

### Levantar el entorno completo

```bash
# 1. Configurar variables de entorno
cp .env.example .env
# Editar .env con valores reales de contraseñas

# 2. Levantar servicios
docker compose up --build

# 3. Verificar salud de la API
curl http://localhost:8001/salud
# Respuesta esperada: {"status":"ok","db":{"resultado":1}}
```

### Cargar datos de prueba (opcional)

```bash
docker compose --profile seed run --rm seed
```

### Ejecutar tests unitarios de la API

```bash
cd api
npm install
npm test
```

### Ejecutar pruebas de base de datos

```bash
docker compose exec db psql -U bodegas_owner -d bodegas -f /tests/db_tests.sql
```

---

## 11. Conclusión

La Etapa 6 está **completa y operativa**. La API REST:

- ✅ Se conecta a PostgreSQL 16 con el rol `app_rw` (privilegios mínimos)
- ✅ Expone 22 endpoints REST organizados en 7 grupos (salud, vinos, clientes, comprobantes, ingresos, transferencias, reportes)
- ✅ Usa consultas SQL parametrizadas (sin ORM, sin inyección SQL)
- ✅ Implementa transacciones para operaciones de escritura multi-tabla
- ✅ Llama a procedimientos almacenados de la BD para lógica de negocio (procesar ingreso/transferencia)
- ✅ Traduce errores SQLSTATE a códigos HTTP claros (409, 422, 400, 503)
- ✅ Incluye 12 pruebas unitarias con Jest y Supertest
- ✅ Se despliega localmente con Docker Compose en puerto 8001
- ✅ El endpoint de salud responde correctamente: `{"status":"ok","db":{"resultado":1}}`

La API cumple con los requisitos del enunciado para la Etapa 6: API REST funcionando en local con Docker Compose, retornando JSON, traduciendo errores SQL a códigos HTTP claros, conectándose con rol de privilegios mínimos y usando consultas SQL parametrizadas.