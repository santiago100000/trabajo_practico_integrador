# Configuración de Docker — Variables, Puertos y Red

> **NOTA:** Este archivo es solo de referencia (proyecto externo: `pdf_extractor_microservicios`). No pertenece al TPI Bodegas del Atuel. Se usa únicamente como guía para evitar conflictos de puertos y variables de entorno entre ambos proyectos (ver `CARPETA TEMPORAL/progreso.md`).

> Archivo de referencia para iniciar un nuevo proyecto con Docker.
> Objetivo: evitar conflictos de puertos y asegurar que las variables de entorno coincidan entre servicios.

SOLO PARA TENER DE REFERENCIA   
---
## 1. Arquitectura del stack (dos grupos de servicios)

| Grupo | Archivo docker-compose | Servicios |
|-------|------------------------|-----------|
| Infraestructura | `docker-compose.infra.yml` | MongoDB, Redis, Traefik |
| Negocio (microservicios) | `docker-compose.yml` | `document-crud-service`, `pdf-extractor-service`, `export-viewer-service` |

**Orden de levantamiento obligatorio:**
1. Primero infraestructura: `docker compose -f docker-compose.infra.yml up --build -d`
2. Después negocio: `docker compose up --build -d`
3. O ambos juntos: `docker compose -f docker-compose.infra.yml -f docker-compose.yml up --build -d`

---

## 2. Red Docker

| Nombre | Driver | Notas |
|--------|--------|-------|
| `universidad-net` | bridge | Red compartida entre infraestructura y microservicios |

- Es creada por `docker-compose.infra.yml`.
- En `docker-compose.yml` (negocio) se declara como `external: true`.
- Todos los servicios de negocio deben estar en esta red para comunicarse entre sí por nombre de servicio.

---

## 3. Puertos publicados en el host (riesgo de conflicto)

| Puerto | Servicio | Protocolo | Público en host | Comentario |
|--------|----------|-----------|-----------------|------------|
| 8000 | `export-viewer-service` | HTTP | **Sí** (`8000:8000`) | Orquestador público, punto de entrada único |
| 80 | Traefik | HTTP | **Sí** (`80:80`) | Proxy inverso |
| 8080 | Traefik | HTTP | **Sí** (`8080:8080`) | Dashboard de Traefik |
| 27017 | MongoDB | TCP | **Sí** (`27017:27017`) | Base de datos (acceso desde host/MongoDB Compass) |

---

## 4. Puertos internos (red Docker, NO publicar en el host)

| Puerto | Servicio | Público en host | Nota |
|--------|----------|-----------------|------|
| 8000 | `pdf-extractor-service` | **No** | 5 réplicas. Publicar `8000:8000` con replicas>1 causa conflicto de bind. Se accede vía orquestador o red interna. |
| 8000 | `document-crud-service` | **No** | Acceso solo vía red interna. |
| 6379 | Redis | **No** | Rate limiting compartido, solo entre contenedores. |
| 27017 | MongoDB | **Sí** (opcional) | Interno entre contenedores; publicado en host solo para herramientas externas. |

### Regla clave para evitar conflictos de puertos
- **Solo `export-viewer-service` publica el puerto 8000 en el host.**
- `pdf-extractor-service` (5 réplicas) y `document-crud-service` **no deben tener `ports:` publicado en el host**; se accede a ellos por nombre de servicio dentro de `universidad-net`.
- Si no usas Traefik, libera los puertos 80 y 8080 para evitar conflictos con otros proyectos.

---

## 5. Variables de entorno (archivo `.env` raíz)

### Red Docker
| Variable | Valor ejemplo | Descripción |
|----------|---------------|-------------|
| `COMPOSE_PROJECT_NAME` | `pdf_extractor_microservicios` | Nombre del proyecto Docker Compose |
| `NETWORK_NAME` | `universidad-net` | Nombre de la red compartida |

### MongoDB (infraestructura)
| Variable | Valor ejemplo | Descripción |
|----------|---------------|-------------|
| `MONGO_ROOT_USERNAME` | `pdf_admin` | Usuario root de MongoDB |
| `MONGO_ROOT_PASSWORD` | `cambia_esta_contraseña_en_produccion` | Contraseña root de MongoDB |
| `MONGO_URI` | `mongodb://${MONGO_ROOT_USERNAME}:${MONGO_ROOT_PASSWORD}@mongo:27017/pdf_extractor_db?authSource=admin` | URI de conexión |
| `MONGO_DB_NAME` | `pdf_extractor_db` | Nombre de la base de datos |
| `MONGO_TIMEOUT_MS` | `5000` | Timeout de conexión en ms |

### Redis (rate limiting compartido)
| Variable | Valor ejemplo | Descripción |
|----------|---------------|-------------|
| `REDIS_PASSWORD` | `cambia_esta_contraseña_en_produccion` | Contraseña de Redis |
| `REDIS_URL` | `redis://:${REDIS_PASSWORD}@redis:6379/0` | URL de conexión a Redis |

### Auth interna (misma valor en los 3 servicios)
| Variable | Valor ejemplo | Descripción |
|----------|---------------|-------------|
| `INTERNAL_API_TOKEN` | `c2db8b6b0449ceb6cfb3252e060999e5d220e239eadebdde70af7e3885c13e08` | Token para comunicación interna entre servicios. Generar con: `openssl rand -hex 32` |

### pdf-extractor-service
| Variable | Valor ejemplo | Descripción |
|----------|---------------|-------------|
| `EXTRACTOR_MAX_FILE_SIZE_MB` | `15` | Tamaño máximo de archivo PDF en MB |
| `EXTRACTOR_MAX_PAGES` | `500` | Máximo número de páginas |
| `EXTRACTOR_TIMEOUT_SECONDS` | `25` | Timeout de extracción en segundos |
| `EXTRACTOR_WORKER_POOL_SIZE` | `8` | Tamaño del pool de workers |
| `EXTRACTOR_QUEUE_MAXSIZE` | `100` | Tamaño máximo de la cola |
| `EXTRACTOR_LOGLEVEL` | `info` | Nivel de logs |

### document-crud-service
| Variable | Valor ejemplo | Descripción |
|----------|---------------|-------------|
| `CRUD_MAX_TEXT_BYTES` | `15728640` | Bytes máximo de texto (15 MB) |
| `CRUD_PAGE_SIZE_MAX` | `100` | Tamaño máximo de página paginada |
| `CRUD_LOGLEVEL` | `info` | Nivel de logs |

### export-viewer-service (orquestador)
| Variable | Valor ejemplo | Descripción |
|----------|---------------|-------------|
| `VIEWER_EXTRACTOR_URL` | `http://pdf-extractor-service:8000` | URL interna del extractor |
| `VIEWER_CRUD_URL` | `http://document-crud-service:8000` | URL interna del CRUD |
| `VIEWER_CONNECT_TIMEOUT` | `5` | Timeout de conexión en segundos |
| `VIEWER_EXTRACTOR_READ_TIMEOUT` | `60` | Timeout de lectura del extractor |
| `VIEWER_CRUD_READ_TIMEOUT` | `5` | Timeout de lectura del CRUD |
| `VIEWER_RETRY_ATTEMPTS` | `3` | Número de reintentos |
| `VIEWER_RETRY_BACKOFF_BASE` | `0.5` | Base de backoff exponencial |
| `VIEWER_MAX_FILE_SIZE_MB` | `10` | Tamaño máximo de archivo en MB |
| `VIEWER_LOGLEVEL` | `info` | Nivel de logs |
| `VIEWER_PUBLIC_PORT` | `8000` | Puerto público del orquestador |
| `VIEWER_RATE_LIMIT_MAX` | `60` | Máximo peticiones por ventana |
| `VIEWER_RATE_LIMIT_WINDOW` | `60` | Ventana de rate limit en segundos |
| `VIEWER_TRUSTED_PROXY` | `false` | Confiar en proxy inverso |

### Traefik
| Variable | Valor ejemplo | Descripción |
|----------|---------------|-------------|
| `TRAEFIK_DASHBOARD_PORT` | `8080` | Puerto del dashboard |
| `TRAEFIK_HTTP_PORT` | `80` | Puerto HTTP |

---

## 6. Variables de entorno por servicio (archivos `.env` individuales)

Cada servicio tiene su propio `.env` (no versionado). Copiar `.env.example` como `.env`:

```bash
cp .env.example .env
```

### document-crud-service/.env
- `MONGO_ROOT_USERNAME`, `MONGO_ROOT_PASSWORD`, `MONGO_URI`, `MONGO_DB_NAME`, `MONGO_TIMEOUT_MS`
- `LOGLEVEL`
- `INTERNAL_API_TOKEN`
- `MAX_TEXT_BYTES`, `PAGE_SIZE_MAX`

### pdf-extractor-service/.env
- `LOGLEVEL`
- `INTERNAL_API_TOKEN`
- `MAX_FILE_SIZE_MB`, `MAX_PAGES`, `EXTRACT_TIMEOUT_SECONDS`
- `WORKER_POOL_SIZE`, `QUEUE_MAXSIZE`

### export-viewer-service/.env
- `EXTRACTOR_URL`, `CRUD_URL` (usar nombres de servicio Docker, no `localhost`)
- `CONNECT_TIMEOUT`, `EXTRACTOR_READ_TIMEOUT`, `CRUD_READ_TIMEOUT`
- `RETRY_ATTEMPTS`, `RETRY_BACKOFF_BASE`
- `MAX_FILE_SIZE_MB`
- `LOGLEVEL`
- `INTERNAL_API_TOKEN`
- `PUBLIC_PORT`
- `MONGO_ROOT_USERNAME`, `MONGO_ROOT_PASSWORD`
- `REDIS_PASSWORD`

---

## 7. Endpoints principales

| Servicio | Endpoint | URL (desde host) | Header requerido |
|----------|----------|------------------|------------------|
| export-viewer-service | Página principal | `http://localhost:8000/` | No |
| export-viewer-service | Swagger | `http://localhost:8000/docs` | No |
| export-viewer-service | Upload PDF | `POST http://localhost:8000/v1/documents/upload` | `X-Internal-Token` |
| export-viewer-service | Listar documentos | `GET http://localhost:8000/v1/documents` | `X-Internal-Token` |
| export-viewer-service | Obtener documento | `GET http://localhost:8000/v1/documents/{id}` | `X-Internal-Token` |
| export-viewer-service | Exportar | `GET http://localhost:8000/v1/documents/{id}/export?format=txt\|json` | `X-Internal-Token` |
| export-viewer-service | Health | `GET http://localhost:8000/health/live` | No |
| Traefik dashboard | Panel | `http://localhost:8080/dashboard/` | No |
| MongoDB Compass | Conexión | `localhost:27017` | Usuario/contraseña de `.env` |

> Nota: `http://pdf-extractor-service:8000` y `http://document-crud-service:8000` **no funcionan desde el navegador del host**. Son nombres internos de Docker válidos solo dentro de la red `universidad-net`. Desde el host siempre usa `http://localhost:8000`.

---

## 8. Comandos de verificación

### Estado de contenedores
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Redes Docker
```bash
docker network ls
docker network inspect universidad-net
```

### Puerto publicado de un servicio
```bash
docker compose port export-viewer-service 8000
```

### Logs de un servicio
```bash
docker compose logs -f export-viewer-service
docker compose logs -f pdf-extractor-service
docker compose logs -f document-crud-service
```

### Salud de los servicios
```bash
curl http://localhost:8000/health/live
```

### Detener y limpiar
```bash
docker compose down                 # detiene y elimina contenedores de negocio
docker compose -f docker-compose.infra.yml down  # detiene infraestructura
docker compose down -v              # elimina volúmenes (incluido MongoDB) — ⚠️ borra datos
```

---

## 9. Checklist antes de levantar el nuevo proyecto

- [ ] Elegir puertos únicos para el nuevo proyecto (evitar 8000, 80, 8080, 27017 si ya están en uso).
- [ ] Si se reusarán los mismos puertos, detener primero cualquier proyecto anterior que los use.
- [ ] Crear `.env` a partir de `.env.example` en la raíz y en cada servicio.
- [ ] Asegurar que `INTERNAL_API_TOKEN` sea **idéntico** en los 3 servicios (document-crud, pdf-extractor, export-viewer).
- [ ] Verificar que las URLs internas usen nombres de servicio Docker (`pdf-extractor-service`, `document-crud-service`, `redis`, `mongo`), no `localhost`.
- [ ] Confirmar que `pdf-extractor-service` **no tiene `ports:` publicado** si tiene más de 1 réplica.
- [ ] Confirmar que solo `export-viewer-service` publica `8000:8000`.
- [ ] Levantar infraestructura primero, luego los microservicios.
- [ ] Verificar con `docker ps` que todos los contenedores estén `Up` y saludables.
- [ ] Probar el endpoint `http://localhost:8000/health/live` desde el navegador.
- [ ] Nunca subir el archivo `.env` real al repositorio (agregarlo a `.gitignore`).

---

## 10. Notas importantes

1. **`MONGO_ROOT_PASSWORD` solo se aplica la primera vez** que MongoDB inicia (volumen vacío). Para cambiarla después, hay que borrar el volumen y recrear la base de datos.
2. **Traefik usa proveedor de archivos**, no necesita montar el socket de Docker (`docker.sock`).
3. **Réplicas del extractor**: 5 réplicas con límite de 1 CPU y 1 GB cada una. Ajustar `deploy.resources.limits` según el hardware disponible.
4. **Archivos `.env` individuales**: cada servicio lee su propio `.env` más el `.env` raíz vía `env_file` en el `docker-compose.yml`.

---

## 11. Estructura recomendada de carpetas para el nuevo proyecto

```
nuevo-proyecto/
├── .env
├── .env.example
├── .gitignore
├── docker-compose.infra.yml
├── docker-compose.yml
├── document-crud-service/
│   ├── .env
│   ├── .env.example
│   ├── docker-compose.yml
│   └── Dockerfile
├── pdf-extractor-service/
│   ├── .env
│   ├── .env.example
│   ├── docker-compose.yml
│   └── Dockerfile
├── export-viewer-service/
│   ├── .env
│   ├── .env.example
│   ├── docker-compose.yml
│   └── Dockerfile
├── traefik-proxy/
│   ├── config/
│   │   ├── traefik.yml
│   │   └── config.yml
│   └── docker-compose.yml
└── README.md
```

---

**Generado a partir del proyecto de referencia:** `pdf_extractor_microservicios`
