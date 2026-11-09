# Bodegas del Atuel - TP Integrador de Bases de Datos (UTN FRSR)

Gestión y distribución de una empresa vitivinícola.

## Integrantes

| Integrantes | GitHub |
|------------|--------|
| Puita Axel | https://github.com/AXELL991 |
| Cerda Santiago | https://github.com/santiago100000 |
| Serpa Juan Cruz | https://github.com/Serpagero |

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

## 🚀 Cómo lanzar la aplicación (Terminal 1)

### 1. Configurar variables de entorno

```bash
cp .env.example .env
```

Editar el archivo `.env` con valores reales (contraseñas, puertos, etc.). **Nunca subir `.env` al repositorio**; está en `.gitignore`.

### 2. Levantar los servicios

```bash
docker compose up --build
```

Esto levanta cuatro servicios:

| Servicio | Puerto | Descripción |
|----------|--------|-------------|
| `db` | 127.0.0.1:5433 | PostgreSQL 16 (base de datos) |
| `migrate` | — | Aplica migraciones SQL (001 a 008) y termina |
| `api` | http://localhost:8001 | API REST de Node.js/Express |
| `front` | http://localhost:8081 | Frontend estático con nginx |

### 3. Verificar que la API está funcionando

Desde una terminal:

```powershell
Invoke-WebRequest -Uri "http://localhost:8001/salud" -UseBasicParsing
```

O desde el navegador: `http://localhost:8001/salud`

Respuesta esperada:
```json
{"status":"ok","db":{"resultado":1}}
```

### 4. Abrir el frontend

El frontend está disponible en:

```
http://localhost:8081
```

---

## 📦 Cómo cargar datos de prueba (Terminal 2)

Mientras los servicios están corriendo en la Terminal 1, abre una **segunda terminal** y ejecuta:

```powershell
docker compose --profile seed run --rm seed python seed.py --masivo
```

Esto ejecuta `db/seed/seed.py` con semilla fija (42), carga catálogos desde CSV, genera datos masivos con Faker, deshabilita/rehabilita triggers durante la carga, recalcula totales y stock, y genera un volcado `dump_completo.sql.gz`.

**Volúmenes cargados:**
- 20.000 clientes (socios, distribuidores, exportadores)
- 150.000 comprobantes
- 375.024 renglones de comprobante
- 60 vinos, 10 salas, 8 bodegas, 6 transportistas
- Stock inicial en depósito y salas

---

## 🖥️ Cómo usar la página (Frontend)

Abre tu navegador en: **http://localhost:8081**

### Pantallas disponibles

| Pantalla | URL | Descripción |
|----------|-----|-------------|
| Dashboard | `http://localhost:8081` | Top vinos, ventas por sala (gráfico), vinos sin stock por sala |
| Catálogo de Vinos | `http://localhost:8081/vinos.html` | Listado paginado con filtros (nombre, tipo, bodega, cepa, añada) |
| Alta de Vino | `http://localhost:8081/alta-vino.html` | Crear vino con composición de cepas (suma debe ser 100% - RN-05) |
| Nueva Venta | `http://localhost:8081/ventas.html` | Elegir cliente y sala, agregar vinos, generar comprobante |
| Clientes | `http://localhost:8081/clientes.html` | Listado, crear (socio/distribuidor/exportador), eliminar |
| Transferencias | `http://localhost:8081/transferencias.html` | Crear, cargar renglones, terminar, procesar |
| Reportes | `http://localhost:8081/reportes.html` | Top vinos, ventas por sala, vinos sin stock, trazabilidad |

---

## 📋 Reglas de negocio (RN-01 a RN-15)

Todas las reglas viven en PostgreSQL. Cuando se viola una, el frontend muestra el error con el código de la regla entre paréntesis:

| RN | Regla | Ejemplo de error en pantalla |
|----|-------|------------------------------|
| RN-01 | Precio de vino > 0 y único | `El precio debe ser mayor que cero (RN-01)` |
| RN-04 | Una cosecha por parcela y campaña | `Ya existe una cosecha para esa parcela y campaña (RN-04)` |
| RN-05 | Porcentajes de corte suman 100 | `La suma de porcentajes... Debe ser exactamente 100 (RN-05)` |
| RN-06 | Descuento socio 10%, dist. 20%, exp. 30% | `El descuento debe estar entre 0 y 100 (RN-06)` |
| RN-07 | Vencimiento de permiso > emisión | `La fecha de vencimiento debe ser posterior... (RN-07)` |
| RN-09 | No vender más stock del que hay | `Stock insuficiente en la sala X para el vino Y... (RN-09)` |
| RN-10/RN-11 | Estados de documento sin retrocesos | `No está en estado terminado... (RN-10 / RN-11)` |
| RN-12 | Sin confección no se modifican renglones | `No se pueden modificar renglones... (RN-12)` |
| RN-13 | Cambio de precio auditado | Auditoría automática en tabla `auditoria_precio` |
| RN-14 | No borrar entidad con movimientos | `Key (id_cliente)=X is still referenced... (RN-14)` |
| RN-15 | Cantidades, superficies, kilos, precios > 0; graduación 5-20 | Mensaje específico del campo violado |

### Ejemplo práctico: Crear un cliente

1. Ve a `http://localhost:8081/clientes.html`
2. Completa el formulario: tipo, nombre, documento, dirección, ID de localidad
3. Si eliges **distribuidor**: llena zona de cobertura y nro. de habilitación (obligatorios)
4. Si eliges **exportador**: llena país de destino (obligatorio)
5. Haz clic en "Crear Cliente"
6. Si hay error (ej. CUIT duplicado, localidad inexistente), se mostrará el mensaje de la base de datos con la regla correspondiente

### Ejemplo práctico: Crear una venta

1. Ve a `http://localhost:8081/ventas.html`
2. Selecciona un cliente y una sala
3. Agrega vinos con cantidades (selecciona el vino del desplegable)
4. Haz clic en "Generar Comprobante"
5. Si no hay stock suficiente: `Stock insuficiente en la sala X para el vino Y (solicitado: 100, disponible: 5). (RN-09)`
6. Si todo está bien: se crea el comprobante y se redirige al dashboard

---

## 🛑 Cómo detener el sistema

### Detener y conservar datos:

```powershell
docker compose down
```

### Detener y borrar TODO (incluyendo datos de la base):

```powershell
docker compose down -v
```

---

## Comandos resumen

| Acción | Comando |
|--------|---------|
| Levantar todo | `docker compose up --build` |
| Detener (conservar datos) | `docker compose down` |
| Detener y borrar datos | `docker compose down -v` |
| Cargar datos masivos | `docker compose --profile seed run --rm seed python seed.py --masivo` |
| Ver contenedores | `docker compose ps` |
| Ver logs de la API | `docker logs bodegas_api` |

---

## Estructura del repositorio

```
.
├── .env                          # Variables de entorno (no se sube al repo)
├── .env.example                  # Plantilla de variables de entorno
├── .gitignore                    # Archivos ignorados por git
├── README.md                     # Este archivo
├── docker-compose.yml            # Orquestación de servicios
├── verificar_estructura.py       # Script de verificación de estructura
├── CARPETA TEMPORAL/             # Documentos de referencia y progreso del proyecto
├── db/
│   ├── migrations/               # Migraciones SQL (001 a 008)
│   ├── seed/                     # Script de carga masiva y catálogos CSV
│   └── tests/                    # Pruebas SQL (db_tests.sql)
├── api/
│   ├── src/
│   │   ├── app.js                # Configuración Express, middlewares, rutas
│   │   ├── index.js              # Punto de entrada, puerto 8001
│   │   ├── config/db.js          # Pool de conexiones pg
│   │   ├── db/                   # Capa de acceso a datos (9 módulos)
│   │   ├── controllers/          # Controladores (9)
│   │   ├── routes/               # Rutas REST (9)
│   │   └── middlewares/errorHandler.js
│   ├── tests/                    # Tests unitarios (Jest + Supertest)
│   └── docs/openapi.json         # Documentación OpenAPI/Swagger
├── front/
│   ├── index.html                # Dashboard
│   ├── vinos.html                # Catálogo de vinos
│   ├── alta-vino.html            # Alta de vino con composición de cepas
│   ├── ventas.html               # Nueva venta / comprobantes
│   ├── clientes.html             # Gestión de clientes
│   ├── transferencias.html       # Transferencias depósito → sala
│   ├── reportes.html             # Reportes
│   ├── js/config.js              # URL base de la API
│   ├── js/api.js                 # Capa de servicios (todas las llamadas API)
│   └── css/style.css             # Estilos (diseño minimalista, tonos de vino)
├── consultas/                    # Consultas SQL etapa 5 (30 consultas comentadas)
└── docs/                         # Documentación técnica (DER, esquema, informes)
```

---

## Decisiones de diseño clave

- **Base de datos como corazón del sistema:** Toda la lógica de negocio (RN-01 a RN-15) vive en PostgreSQL. La API y el front solo consumen y presentan datos sin recalcular nada.
- **SQL directo:** No se usa ORM ni query builders. Todas las consultas se escriben a mano con driver nativo (`pg` para Node.js).
- **Parametrización:** Todas las consultas SQL usan parámetros para prevenir inyección SQL.
- **Errores SQLSTATE → HTTP:** La API traduce códigos de error de PostgreSQL a códigos HTTP claros y el frontend los muestra con la regla de negocio asociada (RN-XX).
- **Rol de privilegios mínimos:** La API se conecta con el rol `app_rw` (lectura/escritura en tablas de negocio), nunca como superusuario/propietario.
- **Puerto de Postgres solo en localhost:** La base de datos se publica solo en `127.0.0.1` para no exponerla fuera de la máquina local.
- **Sin despliegue en la nube:** El sistema está diseñado para funcionar únicamente en entorno local.

---

## Notas importantes

- **No subir `.env` al repositorio:** Contiene contraseñas y está en `.gitignore`.
- **`dump_completo.sql.gz` no se sube:** Está en `.gitignore`. Se genera localmente con `pg_dump`.
- **La API escucha en `http://localhost:8001`** (configurable vía `API_PORT` en `.env`).
- **La base de datos está en `127.0.0.1:5433`** (configurable vía `DB_PORT` en `.env`).
- **El frontend está en `http://localhost:8081`**.
- Los archivos de la `CARPETA TEMPORAL/` son de referencia local del proyecto.

---

## Nota sobre el despliegue (Etapa 8)

Por indicación del profesor, la **Etapa 8 (despliegue en la nube)** era opcional y se omite en esta entrega. El sistema está configurado para ejecutarse **exclusivamente en entorno local** mediante Docker Compose. No hay URL pública, ni servidor externo, ni conexión cifrada a proveedor de nube. Todos los servicios (base de datos, API y frontend) se levantan en la máquina local con `docker compose up --build`.
