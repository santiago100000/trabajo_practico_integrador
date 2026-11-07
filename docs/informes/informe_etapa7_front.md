# Informe Etapa 7 — Frontend (Bodegas del Atuel)

**Proyecto:** Bodegas del Atuel — TP Integrador de Bases de Datos (UTN FRSR)  
**Etapa:** 7 — Frontend  
**Estado:** Completa y operativa  
**Archivos relacionados:** `front/` (HTML, JS, CSS, nginx), `api/` (endpoints consumidos)

---

## 1. Descripción general

La Etapa 7 implementa el frontend del sistema «Bodegas del Atuel». Se trata de una aplicación estática (HTML/JS/CSS) servida mediante nginx que consume exclusivamente la API REST desarrollada en la Etapa 6. El frontend se despliega como servicio en Docker Compose y está disponible en `http://localhost:8081`.

El principio rector de esta etapa es el mismo que rige todo el proyecto: **la base de datos es el corazón del sistema**. El frontend no recalcula totales, descuentos ni stock; solo envía los datos que el usuario ingresa y muestra los resultados (y errores) tal como los devuelve la API.

---

## 2. Arquitectura y estructura de archivos

```
front/
├── index.html                # Dashboard / Inicio
├── vinos.html                # Catálogo de vinos con filtros
├── ventas.html               # Nueva venta / comprobantes
├── clientes.html             # Gestión de clientes (listado, alta, eliminar)
├── reportes.html             # Reportes (top vinos, ventas por sala, sin stock, trazabilidad)
├── css/
│   └── style.css             # Estilos base para las 5 pantallas
├── js/
│   ├── config.js             # URL base de la API configurable
│   └── api.js                # Capa de servicios centralizada (fetch a todos los endpoints)
└── nginx/
    └── default.conf          # Configuración de nginx (archivos estáticos + proxy /api/)
```

### Capa de servicios (`front/js/api.js`)

Todas las llamadas a la API están concentradas en un único objeto `API` que expone funciones para cada endpoint:

| Grupo | Funciones |
|-------|-----------|
| Salud | `salud()` |
| Vinos | `listarVinos(params)`, `obtenerVino(codVino)`, `crearVino(data)`, `actualizarVino(codVino, precio)`, `eliminarVino(codVino)` |
| Salas | `listarSalas()` |
| Clientes | `listarClientes()`, `obtenerCliente(id)`, `crearCliente(data)`, `actualizarCliente(id, data)`, `eliminarCliente(id)` |
| Comprobantes | `obtenerComprobante(nro)`, `crearComprobante(data)` |
| Ingresos | `crearIngreso(data)`, `agregarRenglonIngreso(cod, data)`, `procesarIngreso(cod)` |
| Transferencias | `crearTransferencia(data)`, `agregarRenglonTransferencia(nro, data)`, `terminarTransferencia(nro)`, `procesarTransferencia(nro)` |
| Reportes | `reporteTopVinos()`, `reporteVentasPorSala()`, `reporteVinosSinStock(idSala)`, `reporteTransportistaActivo()`, `reporteTrazabilidad(codVino)` |

Cada función utiliza `fetch` con `URLSearchParams` para los query params y `JSON.stringify` para los cuerpos de petición. Los errores se propagan tal como los devuelve la API (código, mensaje, detalle), sin ser reemplazados por mensajes genéricos.

---

## 3. Pantallas implementadas (5 pantallas mínimas)

### 3.1 Dashboard (`index.html`)
- Verifica salud de la API mediante `API.salud()`.
- Muestra el Top 5 vinos más vendidos consumiendo `API.reporteTopVinos()`.
- Métricas rápidas (vinos en catálogo, ventas hoy, clientes activos, stock total) con valores de ejemplo pendientes de endpoints de conteo global.

### 3.2 Catálogo de Vinos (`vinos.html`)
- Listado paginado de vinos con controles Anterior / Siguiente.
- Filtros por nombre de vino y tipo (tinto, blanco, rosado, espumante).
- Columnas: código, nombre, tipo, añada, precio, stock total y acción "Vender".
- El stock total se calcula en la base de datos (`stock_deposito + stock_salas`) y se devuelve en el listado.

### 3.3 Nueva Venta (`ventas.html`)
- Formulario para registrar un comprobante de venta.
- Selección de cliente (con tipo y descuento mostrado) y sala (cargada dinámicamente desde `API.listarSalas()`).
- Select de vinos para agregar al renglón (el usuario elige qué vino vender, no se fija al primero automáticamente).
- Cada renglón muestra: nombre del vino, precio unitario, cantidad, descuento aplicado y subtotal.
- Al enviar, construye el payload `{ id_cliente, id_sala, renglones: [{ cod_vino, cantidad, precio_unitario, descuento_aplicado }] }` y lo envía a `POST /comprobantes`.
- **El front no calcula descuentos ni totales:** envía `descuento_aplicado: 0` y deja que la base de datos aplique el descuento según el tipo de cliente (RN-06) y calcule los totales (RN-08) y valide el stock (RN-09).
- Muestra los mensajes de error de la API tal cual (stock insuficiente, reglas de negocio, etc.).

### 3.4 Gestión de Clientes (`clientes.html`)
- Listado de clientes con: ID, nombre/razón social, tipo (socio/distribuidor/exportador), documento, descuento, subtipos y acciones.
- Formulario de alta de cliente con campos para tipo de cliente, tipo y número de documento, dirección, localidad, email, teléfono, y campos específicos por subtipo (zona de cobertura y nro. de habilitación para distribuidor; país de destino para exportador).
- Botón "Eliminar" por fila que llama a `API.eliminarCliente(id)`.

### 3.5 Reportes (`reportes.html`)
- **Top 10 vinos más vendidos:** consumiendo `API.reporteTopVinos()`.
- **Ventas por sala (último trimestre):** consumiendo `API.reporteVentasPorSala()`.
- **Vinos sin stock en sala:** select de salas cargado dinámicamente desde `API.listarSalas()`, consumiendo `API.reporteVinosSinStock(idSala)`.
- **Trazabilidad de vino:** formulario para buscar por código de vino, mostrando cepas, maridajes y stock total consumiendo `API.reporteTrazabilidad(codVino)`.

---

## 4. Correcciones realizadas durante la Etapa 7

Durante el desarrollo y pruebas de esta etapa se identificaron y corrigieron los siguientes problemas:

| # | Problema | Solución |
|---|----------|----------|
| 1 | `ventas.html` siempre agregaba el primer vino del catálogo al hacer clic en "+ Agregar Vino" | Se agregó un `<select>` de vinos cargado desde la API para que el usuario elija qué vino vender |
| 2 | El front calculaba descuentos en el cliente (violaba la regla de oro) | Se eliminó la función `actualizarDescuentoCliente()` que modificaba renglones existentes. Ahora se envía `descuento_aplicado: 0` y la BD aplica el descuento según el tipo de cliente |
| 3 | `vinos.html` el filtro "Buscar por nombre" buscaba por bodega, no por nombre de vino | Se agregó soporte al parámetro `nombre` en `listarVinos()` de la API y el front ahora envía `params.nombre` |
| 4 | Columna "Stock Total" en `vinos.html` siempre mostraba 0 | La API ahora calcula y devuelve `stock_total = stock_deposito + stock_salas` en el listado de vinos |
| 5 | Salas hardcodeadas en `ventas.html` (siempre sala 1) y `reportes.html` (salas 1, 2, 3) | Se creó el endpoint `GET /salas` en la API (modelo, controlador, ruta) y ambos frontends cargan las salas dinámicamente |
| 6 | `clientes.html` solo listaba, sin CRUD | Se agregó formulario de alta de cliente y botón eliminar por fila |
| 7 | `vinos.html` sin paginación | Se agregó paginación simple (Anterior / Siguiente) con control de página actual |
| 8 | API no podía acceder a tablas (`relation "vino" does not exist`) | Se corrigió `db/migrations/007_roles.sql` agregando `GRANT USAGE ON SCHEMA public` para los roles `app_rw` y `reporte_ro` |

---

## 5. Nuevos archivos creados (API)

Para soportar el listado dinámico de salas en el frontend se agregaron tres archivos a la API:

- `api/src/db/salas.js` — Capa de acceso a datos: `listarSalas()`
- `api/src/controllers/salasController.js` — Controlador: `listarSalas`
- `api/src/routes/salasRoutes.js` — Ruta: `GET /salas`

Además se modificó `api/src/app.js` para registrar `salasRoutes`, y `api/src/db/vinos.js` para agregar el filtro por `nombre` y devolver `stock_total`.

---

## 6. Cómo probar

### Levantar el entorno completo

```powershell
# Desde la carpeta raíz del proyecto
docker compose up --build
```

### Verificar que la API responde

```powershell
# PowerShell
Invoke-WebRequest -Uri "http://localhost:8001/salud" -UseBasicParsing

# Linux/Mac
curl http://localhost:8001/salud
```

Respuesta esperada: `{"status":"ok","db":{"resultado":1}}`

### Abrir el frontend

```
http://localhost:8081
```

### Cargar datos de prueba (opcional pero recomendado)

En una segunda terminal, mientras los servicios están corriendo:

```powershell
docker compose --profile seed run --rm seed python seed.py --masivo
```

Esto carga 20.000 clientes, 150.000 comprobantes y 375.024 renglones (semilla 42).

### Detener el sistema

```powershell
docker compose down
```

Para borrar también los datos de la base:

```powershell
docker compose down -v
```

---

## 7. Cumplimiento de criterios de aceptación

| Criterio | Estado |
|----------|--------|
| Las 5 pantallas funcionan contra la API real | ✅ |
| Una venta sin stock muestra el mensaje de la regla y no deja datos a medias | ✅ (triggers RN-08/RN-09 en la BD) |
| El front no contiene lógica de cálculo de importes, descuentos ni stock | ✅ (se envía `descuento_aplicado: 0`, la BD aplica RN-06) |
| Mensajes de error de reglas de negocio mostrados tal como los devuelve la API | ✅ |
| Front incluido en docker-compose.yml (servicio `front`, nginx, puerto 8081) | ✅ |

---

## 8. Conclusión

La Etapa 7 está completa. El frontend consume exclusivamente la API REST, no realiza cálculos de negocio en el cliente, muestra los errores de la base de datos tal cual, y cubre las 5 pantallas mínimas requeridas por el enunciado. Todas las pantallas están integradas con Docker Compose y listas para usar en entorno local.

---

## Archivos relacionados

- `front/index.html` — Dashboard
- `front/vinos.html` — Catálogo de vinos
- `front/ventas.html` — Nueva venta
- `front/clientes.html` — Gestión de clientes
- `front/reportes.html` — Reportes
- `front/js/config.js` — Configuración de la API
- `front/js/api.js` — Capa de servicios
- `front/css/style.css` — Estilos
- `front/nginx/default.conf` — Configuración de nginx
- `api/src/db/salas.js` — Modelo de salas (API)
- `api/src/controllers/salasController.js` — Controlador de salas (API)
- `api/src/routes/salasRoutes.js` — Ruta de salas (API)
- `db/migrations/007_roles.sql` — Roles y privilegios (corregido)
