# Progreso del TPI - Bodegas del Atuel

## Estado general del repositorio

**Rama:** `main`  
**Último commit:** `89da240` (feat(front): completar Etapa 7 - alta de vinos, transferencias, filtros y tablero completo)  
**Push a `origin/main`:** ✅ Sincronizado  
**Última actualización:** 08/11/2026  

**Etapas completadas:** 1, 2, 3, 4, 5, 6, 7  
**Etapa en curso:** ninguna  
**Etapas pendientes:** 9 (etapa 8 de despliegue en la nube descartada)

---

## Etapas completadas

Todas las etapas del TPI están implementadas y funcionales:

### Etapa 1: Modelado — COMPLETADA ✅
- Esquema relacional con 25 tablas, 6 ENUMs, 7 dominios
- DER, esquema relacional DBML, diccionario de datos, normalización 3FN
- Decisiones de diseño: jerarquía de clientes (supertipo/subtipos), claves subrogadas vs naturales

### Etapa 2: Integridad y lógica en la base — COMPLETADA ✅
- 12 UNIQUE adicionales, 20+ CHECK (incluyendo uno entre columnas), 6 DEFAULT
- 4 funciones: fn_total_comprobante, fn_stock_sala, fn_descuento_cliente, fn_antiguedad_anios
- 2 procedimientos transaccionales: sp_procesar_ingreso, sp_procesar_transferencia (FOR UPDATE, todo o nada)
- 8 triggers (1 constraint diferido, 5 BEFORE, 2 AFTER) cubriendo RN-01 a RN-15
- 3 vistas (1 materializada: mv_stock_total_por_vino)
- 3 roles: bodegas_owner, app_rw, reporte_ro (privilegios mínimos, REVOKE de PUBLIC)
- Pruebas SQL para RN-01 a RN-15 en db/tests/db_tests.sql

### Etapa 3: Carga masiva de datos — COMPLETADA ✅
- Catálogos desde CSV (cepas, maridajes, departamentos, localidades)
- Carga masiva con Faker: 20.000 clientes, 150.000 comprobantes, 375.024 renglones
- Semilla fija (42) para reproducibilidad
- Deshabilitación/rehabilitación de triggers durante carga masiva
- dump_completo.sql.gz generado

### Etapa 4: Índices y rendimiento — COMPLETADA ✅
- 6 índices: compuesto, parcial, FK, expresión, BRIN, FK
- Mediciones EXPLAIN (ANALYZE, BUFFERS) antes y después
- Costo de escritura medido

### Etapa 5: Consultas SQL — COMPLETADA ✅
- 30 consultas comentadas (12 SELECT, 6 INSERT, 6 UPDATE, 6 DELETE)
- S12a reescrita para evitar timeout (>120s → 232ms)
- Todas envueltas en transacciones con control previa/posterior

### Etapa 6: API REST — COMPLETADA ✅
- Node.js + Express + driver pg nativo (sin ORM)
- 22 endpoints REST en 7 grupos: salud, vinos, salas, clientes, comprobantes, ingresos, transferencias, reportes
- Consultas parametrizadas, transacciones para operaciones multi-tabla
- Mapeo SQLSTATE → HTTP (409, 422, 400, 503, 500)
- 12 pruebas unitarias con Jest y Supertest
- Documentación OpenAPI/Swagger en api/docs/openapi.json

### Etapa 7: Frontend — COMPLETADA ✅
- 7 pantallas totales: dashboard, vinos, alta de vino, nueva venta, clientes, transferencias, reportes
- Rediseño minimalista, serio, tecnológico (paleta de vinos, sin emojis)
- Consultas parametrizadas, sin lógica de cálculo en el front
- Errores de reglas de negocio mostrados con código RN-XX entre paréntesis
- Reconnect con backoff exponencial ante errores de red

---

## Cómo lanzar el sistema (Terminal 1)

Desde la carpeta raíz del proyecto:

```powershell
# 1. Detener y limpiar todo (incluyendo volúmenes de datos)
docker compose down -v

# 2. Levantar todos los servicios desde cero
docker compose up --build
```

Servicios levantados:

| Servicio | Puerto | Descripción |
|----------|--------|-------------|
| bodegas_db | 127.0.0.1:5433 | PostgreSQL 16 (base de datos) |
| bodegas_api | http://localhost:8001 | API REST (Node.js/Express) |
| bodegas_front | http://localhost:8081 | Frontend estático (nginx) |
| bodegas_migrate | — | Aplica migraciones 001-008 y termina |

Verificar que la API responde:
```powershell
Invoke-WebRequest -Uri "http://localhost:8001/salud" -UseBasicParsing
# Respuesta esperada: {"status":"ok","db":{"resultado":1}}
```

### Para detener el sistema (sin borrar datos):
```powershell
docker compose down
```

### Para detener y borrar TODO (incluyendo datos de la base):
```powershell
docker compose down -v
```

---

## Cómo cargar datos de prueba (Terminal 2)

Mientras los servicios están corriendo en la Terminal 1, abre una **segunda terminal** y ejecuta:

```powershell
# Cargar datos masivos con semilla fija (42)
docker compose --profile seed run --rm seed python seed.py --masivo
```

Esto cargará:
- 20.000 clientes (socios, distribuidores, exportadores)
- 150.000 comprobantes
- 375.024 renglones de comprobante
- 60 vinos, 10 salas, 8 bodegas, 6 transportistas
- Stock inicial en depósito y salas

El proceso tarda aproximadamente 2-3 minutos. Cuando termine, ya puedes usar el front con datos reales.

---

## Cómo usar la página (Frontend)

Abre tu navegador en: **http://localhost:8081**

### 1. Dashboard (`index.html`)
- Muestra top 10 vinos más vendidos
- Ventas por sala en el último trimestre (con gráfico de barras)
- Vinos sin stock en una sala seleccionable
- Accesos rápidos a todas las pantallas

### 2. Catálogo de Vinos (`vinos.html`)
- Listado paginado (10 por página) con navegación Anterior/Siguiente
- Filtros: nombre, tipo (tinto/blanco/rosado/espumante), bodega, cepa, añada
- Cada fila muestra: código, nombre, tipo, añada, precio, stock total
- Botón "Editar" para modificar un vino existente

### 3. Alta de Vino (`alta-vino.html`)
- Formulario completo: bodega, nombre, tipo, añada, volumen, graduación, precio
- Composición de cepas: agregar múltiples cepas con porcentajes
- **Regla RN-05:** La suma de porcentajes debe ser exactamente 100. Si no, no permite guardar
- Muestra error de la base de datos si se viola alguna restricción

### 4. Nueva Venta (`ventas.html`)
- Selecciona cliente y sala de venta
- Agrega vinos con cantidades al renglón
- **Regla de oro:** El front NO calcula descuentos ni totales. La BD lo hace (triggers RN-08/RN-09)
- Si intentas vender más stock del disponible: `Stock insuficiente... (RN-09)`
- Al guardar: se crea el comprobante y se redirige al dashboard

### 5. Clientes (`clientes.html`)
- Listado de todos los clientes con su tipo, documento, descuento, subtipos
- Formulario de alta: socio, distribuidor o exportador
- Para distribuidor: zona de cobertura y nro. de habilitación (campos obligatorios)
- Para exportador: país de destino (campo obligatorio)
- Botón eliminar por fila
- **Regla RN-14:** No se puede eliminar un cliente que tenga compras asociadas. Si intentas, muestra: `...still referenced from table "comprobante". (RN-14)`

### 6. Transferencias (`transferencias.html`)
- Crear transferencia: selecciona sala solicitante y agrega vinos con cantidades
- Estados: en_confección → terminado → procesado
- Botón "Terminar": solo disponible si está en_confección
- Botón "Procesar": solo disponible si está terminado. Descuenta del depósito y suma a la sala
- **Regla RN-11:** Si no hay stock suficiente en depósito, se revierte todo (ROLLBACK)

### 7. Reportes (`reportes.html`)
- Top 10 vinos más vendidos
- Ventas por sala en el último trimestre
- Vinos sin stock en una sala seleccionada (con stock en depósito)
- Trazabilidad de vino: cepas, maridajes, stock total

---

## Reglas de negocio implementadas (RN-01 a RN-15)

Todas las reglas viven en PostgreSQL. Cuando se viola una, el frontend muestra el error con el código de la regla entre paréntesis:

| RN | Regla | Mensaje de error típico |
|----|-------|------------------------|
| RN-01 | Precio de vino > 0 y único | "El precio debe ser mayor que cero (RN-01)" / "Ya existe un vino... (RN-01)" |
| RN-04 | Una cosecha por parcela y campaña | "Ya existe una cosecha para esa parcela y campaña (RN-04)" |
| RN-05 | Porcentajes de corte suman 100 | "La suma de porcentajes... Debe ser exactamente 100 (RN-05)" |
| RN-06 | Descuento socio 10%, dist. 20%, exp. 30% | "El descuento debe estar entre 0 y 100 (RN-06)" |
| RN-07 | Vencimiento > emisión en permisos | "La fecha de vencimiento debe ser posterior... (RN-07)" |
| RN-09 | No vender más stock del que hay | "Stock insuficiente en la sala X... (RN-09)" |
| RN-10/RN-11 | Estados de documento sin retrocesos | "No está en estado terminado... (RN-10 / RN-11)" |
| RN-12 | Sin confección no se modifican renglones | "No se pueden modificar renglones... (RN-12)" |
| RN-13 | Cambio de precio auditado | Auditoría automática en tabla auditoria_precio |
| RN-14 | No borrar entidad con movimientos | "Key (id_cliente)=X is still referenced... (RN-14)" |
| RN-15 | Cantidades, superficies, kilos, precios > 0; graduación 5-20 | Mensaje específico del campo violado |

---

## Solución de problemas comunes

| Problema | Causa probable | Solución |
|----------|---------------|----------|
| "No se puede conectar con la API" | La API no está corriendo o hay problema de red | Ejecutar `docker compose up --build` y esperar a que `bodegas_api` esté `healthy` |
| Error al eliminar cliente | El cliente tiene compras asociadas (RN-14) | No se puede eliminar. Primero borra sus comprobantes o usa otro cliente |
| Error al crear distribuidor/exportador | Falta llenar zona de cobertura o país de destino | Llenar todos los campos obligatorios del subtipo seleccionado |
| Error al crear vino | Porcentajes de cepas no suman 100 | Ajustar los porcentajes hasta que sumen exactamente 100 |
| Error al procesar transferencia | No hay stock suficiente en depósito | Primero procesa un ingreso para agregar stock al depósito |

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

## Notas importantes

- **Puerto frontend:** `http://localhost:8081`
- **Puerto API:** `http://localhost:8001` (solo API, no tiene página web)
- **Puerto DB:** `127.0.0.1:5433` (solo localhost)
- **Contraseñas:** Configuradas en `.env` (no se sube al repo). Usar `bodegas777` si se crea uno nuevo.
- **El front NO calcula totales ni descuentos:** Todo lo hace PostgreSQL mediante triggers y funciones (regla de oro del proyecto)
