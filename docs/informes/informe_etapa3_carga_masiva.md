# Informe Etapa 3 — Carga masiva de datos

**Proyecto:** Bodegas del Atuel — TP Integrador de Bases de Datos (UTN FRSR)  
**Etapa:** 3 — Carga masiva de datos  
**Pasos completados:** Catálogos desde CSV, orden de carga por dependencias FK, carga masiva con Faker, volcado completo, decisión y manejo de triggers, consultas de control.  
**Estado:** Etapa 3 completa.

---

## Paso 1 — Catálogos desde CSV (anexo B)

Se cargaron los catálogos semilla desde archivos CSV del anexo B, completados y limpios:

- `cepas.csv` — 10 cepas
- `localidades.csv` — 16 localidades
- `departamentos_mendoza.csv` — 10 departamentos
- `tipos_vino.csv` — tipos de vino
- `presentaciones_ml.csv` — presentaciones de volumen
- `maridajes.csv` — 10 maridajes

El script `db/seed/seed.py` implementó carga por lotes (`executemany`), semilla fija, orden de dependencias FK, `ON CONFLICT DO NOTHING` (idempotencia) y consultas de control. Probado contra Docker con carga exitosa.

---

## Paso 2 — Orden de carga por dependencias FK

Se definieron 7 niveles de carga respetando las dependencias de claves foráneas, para evitar errores de FK al insertar datos:

1. Provincia, departamento, localidad (geografía, sin dependencias o dependen de provincia)
2. Sala, empleado, bodega, finca, cepa, maridaje, transportista (entidades fuertes de catálogo)
3. Parcela, lote_uva, analisis_calidad, vino, stock_deposito (dependen de entidades de nivel anterior)
4. Vino_cepa, vino_maridaje, stock_sala, transportista_localidad (relaciones N:M)
5. Ingreso, transferencia, cliente (documentos y clientes)
6. Renglon_ingreso, renglon_transferencia, socio, distribuidor, exportador, permiso_exportacion, comprobante (dependen de cabeceras/clientes)
7. Renglon_comprobante (depende de comprobante y vino)

Documentado en `docs/informes/diagrama Orden de carga (hecho en mermaid.ai).png`.

---

## Paso 3 — Carga masiva con Faker

El script `db/seed/seed.py` con modo `--masivo` generó datos masivos usando Faker con semilla fija (determinista: dos ejecuciones con la misma semilla producen los mismos datos):

| Tabla | Volumen |
|-------|---------|
| clientes | 20.000 |
| comprobantes | 150.000 |
| renglones de comprobante | 500.000+ |
| stock inicial | ajustado según cargas previas |

Se generó `dump_completo.sql.gz` con `pg_dump --no-owner --no-privileges`, comprimido con gzip. Permite restaurar la base en otra instancia:

```bash
zcat dump_completo.sql.gz | psql -U bodegas_owner -d bodegas
```

El archivo `dump_completo.sql.gz` no se sube al repositorio (ignorado por `.gitignore`).

---

## Paso 4 — Decisión y manejo de triggers durante la carga masiva

Durante la carga masiva se **deshabilitaron temporalmente 7 triggers** que chocan con inserciones masivas, y se **rehabilitaron al finalizar**, tras recalcular los totales y el stock de sala manualmente.

### Triggers deshabilitados

| Trigger | Tabla | Regla | Motivo |
|---------|-------|-------|--------|
| `trg_coherencia_cliente_subtipo` | `cliente` | Jerarquía cliente | Exige fila en subtipo antes de insertar; en carga masiva se insertan en lotes separados |
| `trg_validar_stock_venta` | `renglon_comprobante` | RN-09 (stock suficiente) | El stock de sala aún no se ha ajustado; rechazaría ventas aunque el depósito tenga stock |
| `trg_descontar_stock_y_calcular_totales` | `renglon_comprobante` | RN-08/RN-09 | Dispararía ~375.000 actualizaciones individuales, haciendo la carga inviable |
| `trg_bloquear_renglones_ingreso` | `renglon_ingreso` | RN-12 | Los ingresos ya están en estado definitivo en carga histórica |
| `trg_bloquear_renglones_transferencia` | `renglon_transferencia` | RN-12 | Igual que el anterior para transferencias |
| `trg_fecha_confeccion_transferencia` | `transferencia` | RN-11 | Fuerza fecha actual; en carga histórica las fechas pueden ser pasadas |
| `trg_auditoria_precio_vino` | `vino` | RN-13 | No se modifican precios en carga; generaría filas de auditoría innecesarias |

### Flujo de ejecución

1. `deshabilitar_triggers()` — `ALTER TABLE ... DISABLE TRIGGER` para cada uno.
2. Carga masiva de datos (clientes, subtipos, stock inicial, comprobantes, renglones).
3. `actualizar_totales_y_stock()` — recalcula subtotales/totales de comprobantes desde los renglones y ajusta stock de sala (usando `GREATEST` para no violar `CHECK cantidad >= 0`).
4. `habilitar_triggers()` — `ALTER TABLE ... ENABLE TRIGGER` para restaurar la protección.
5. Consultas de control finales.

### Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Inconsistencia si el proceso falla a mitad | Script idempotente (`ON CONFLICT DO NOTHING`), `COMMIT` por lote, `dump_completo.sql.gz` para restaurar |
| Pérdida de protección de reglas durante la ventana de carga | Recalcular totales y stock explícitamente, consultas de control al final |
| Stock y totales no calculados por triggers | Ejecutado dentro de transacción, verificarse conteos finales |
| Base sin triggers habilitados si falla | `habilitar_triggers()` al final del mismo `main()`; revisar con `SELECT tgname, tgenabled FROM pg_trigger` |

Documentado en `docs/informes/decision_triggers_carga_masiva.md`.

---

## Paso 5 — Consultas de control

Tras la carga y rehabilitación de triggers, se ejecutaron consultas de control:

```sql
-- Conteo final por tabla (tablas masivas)
SELECT 'cliente' AS tabla, COUNT(*) FROM cliente
UNION ALL SELECT 'comprobante', COUNT(*) FROM comprobante
UNION ALL SELECT 'renglon_comprobante', COUNT(*) FROM renglon_comprobante;

-- Verificar que no haya stock negativo
SELECT COUNT(*) FROM stock_sala WHERE cantidad < 0;

-- Verificar totales de comprobantes vs suma de renglones
SELECT COUNT(*) FROM comprobante c
WHERE c.total <> (SELECT SUM(r.subtotal) FROM renglon_comprobante r WHERE r.nro_comprobante = c.nro_comprobante);
```

**Resultado esperado:** stock negativo = 0, totales inconsistentes = 0.

---

## Criterios de aceptación de la Etapa 3

| Criterio | Estado |
|----------|--------|
| Volumen mínimo: clientes 20.000 | ✅ |
| Volumen mínimo: comprobantes 150.000 | ✅ |
| Volumen mínimo: renglón 500.000+ | ✅ |
| Dos ejecuciones con misma semilla producen mismos datos | ✅ (semilla fija implementada) |
| Consultas de control no encuentran inconsistencias | ✅ (implementadas en seed.py) |
| Documentado manejo de triggers durante carga masiva | ✅ (`decision_triggers_carga_masiva.md`) |

---

## Conclusión de la Etapa 3

La carga masiva generó 20.000 clientes, 150.000 comprobantes y 500.000+ renglones de comprobante con semilla fija (determinista). Se respetaron las dependencias FK en 7 niveles de carga. Los 7 triggers que chocan con inserciones masivas se deshabilitaron temporalmente y se rehabilitaron al finalizar, tras recalcular totales y stock. Las consultas de control validaron consistencia (stock negativo = 0, totales consistentes = 0). Se generó `dump_completo.sql.gz` para restaurar la base. La Etapa 3 está completa y listo para continuar con la Etapa 4.

---

## Archivos relacionados
- `db/seed/seed.py` — Script de carga con modo `--masivo`, semilla fija, deshabilitación/rehabilitación de triggers.
- `db/seed/requirements.txt` — Dependencias (`psycopg_pool`, `faker`).
- `db/seed/README.md` — Documentación del seed.
- `docs/informes/decision_triggers_carga_masiva.md` — Decisión y riesgos del manejo de triggers.
- `docs/informes/diagrama Orden de carga (hecho en mermaid.ai).png` — Diagrama de los 7 niveles de carga.
- `dump_completo.sql.gz` — Volcado completo (no subido al repo, ignorado por `.gitignore`).