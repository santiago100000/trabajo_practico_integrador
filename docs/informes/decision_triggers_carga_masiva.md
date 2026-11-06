# Decisión de diseño: Manejo de triggers durante la carga masiva (Etapa 3)

**Proyecto:** Bodegas del Atuel — TP Integrador de Bases de Datos (UTN FRSR)  
**Etapa:** 3 — Carga masiva de datos  
**Archivo relacionado:** `db/seed/seed.py` (funciones `deshabilitar_triggers()` y `habilitar_triggers()`)  
**Fecha:** 05/11/2026

---

## 1. Decisión tomada

Durante la carga masiva histórica de datos (clientes, comprobantes, renglones de comprobante, stock inicial) se **deshabilitan temporalmente los triggers** que chocan con inserciones masivas, y se **rehabilitan al finalizar**, tras recalcular los totales y el stock de sala manualmente.

### Triggers deshabilitados (7 en total)

| Trigger | Tabla | Tipo | Regla de negocio | Motivo de deshabilitación |
|---------|-------|------|------------------|---------------------------|
| `trg_coherencia_cliente_subtipo` | `cliente` | AFTER INSERT/UPDATE | Jerarquía cliente (discriminador vs subtipo) | Al insertar un cliente, exige que ya exista la fila en la tabla de subtipo (`socio`, `distribuidor` o `exportador`). En carga masiva se insertan cliente y subtipo en lotes separados; el trigger dispararía antes de que exista la fila del subtipo. |
| `trg_validar_stock_venta` | `renglon_comprobante` | BEFORE INSERT | RN-09 (stock suficiente en sala) | Al insertar renglones de comprobante masivamente, el stock de sala aún no se ha ajustado; el trigger rechazaría la venta por stock insuficiente aunque el depósito central tenga stock. |
| `trg_descontar_stock_y_calcular_totales` | `renglon_comprobante` | AFTER INSERT | RN-08, RN-09 (descuento stock y totales) | Dispara una actualización del stock de sala y recálculo de totales del comprobante **por cada renglón insertado**. Con ~375.000 renglones, esto encarece enormemente la carga y puede generar bloqueos. |
| `trg_bloquear_renglones_ingreso` | `renglon_ingreso` | BEFORE INSERT/UPDATE/DELETE | RN-12 (solo cambios en confección) | Durante la carga histórica los ingresos ya están en estado definitivo; no es necesario validar el estado de confección. |
| `trg_bloquear_renglones_transferencia` | `renglon_transferencia` | BEFORE INSERT/UPDATE/DELETE | RN-12 (solo cambios en confección) | Igual que el anterior, para transferencias. |
| `trg_fecha_confeccion_transferencia` | `transferencia` | BEFORE INSERT/UPDATE | RN-11 (fecha de confección = actual) | Fuerza `fecha_confeccion = CURRENT_DATE`. En carga histórica las transferencias pueden tener fechas pasadas; el trigger las sobrescribiría con la fecha actual. |
| `trg_auditoria_precio_vino` | `vino` | AFTER UPDATE | RN-13 (auditoría de cambios de precio) | Durante la carga masiva no se modifican precios de vinos existentes; el trigger solo generaría filas de auditoría innecesarias. |

### Cómo se ejecuta

1. `deshabilitar_triggers()` — ejecuta `ALTER TABLE ... DISABLE TRIGGER` para cada uno.
2. Carga masiva de datos (clientes, subtipos, stock inicial, comprobantes, renglones).
3. `actualizar_totales_y_stock()` — recalcula subtotales/totales de comprobantes desde los renglones y ajusta el stock de sala descontando lo vendido (usando `GREATEST` para no violar `CHECK cantidad >= 0`).
4. `habilitar_triggers()` — ejecuta `ALTER TABLE ... ENABLE TRIGGER` para restaurar la protección.
5. Consultas de control finales (conteo por tabla).

---

## 2. Riesgos identificados

### Riesgo 1: Inconsistencia si el proceso falla a mitad
Si el script se interrumpe entre `deshabilitar_triggers()` y `habilitar_triggers()` (por error, caída de conexión, OOM, etc.), los triggers quedan deshabilitados y la base queda en un estado donde las reglas de negocio (RN-05, RN-08, RN-09, RN-11, RN-12, RN-13) **no están protegidas** para los datos cargados hasta ese momento.

**Mitigación:** El script se ejecuta en lotes con `COMMIT` por lote. Si falla, se puede reejecutar (es idempotente gracias a `ON CONFLICT DO NOTHING` en las tablas maestras y a la recarga completa de comprobantes/renglones). Además, se genera `dump_completo.sql.gz` al finalizar para poder restaurar desde un estado conocido.

### Riesgo 2: Pérdida de protección de reglas durante la ventana de carga
Mientras los triggers están deshabilitados, se podrían insertar datos que violen:
- RN-05: porcentajes de corte que no sumen 100 (no aplicable en carga masiva, no se cargan vinos_cepa masivamente).
- RN-08/RN-09: totales incorrectos o ventas sin stock (mitigado recalculando totales y stock manualmente en `actualizar_totales_y_stock()`).
- RN-11: fechas de confección modificables (mitigado porque no se cargan transferencias masivamente en este paso).
- RN-12: cambios en documentos no en confección (no aplicable).
- RN-13: auditoría de precios no registrada (no aplicable, no se cambian precios en carga).

**Mitigación:** Se recalculan totales y stock explícitamente después de la carga, y se validan con consultas de control al final.

### Riesgo 3: Stock y totales no calculados por triggers
Al deshabilitar `trg_descontar_stock_y_calcular_totales`, el stock de sala y los totales de comprobante no se actualizan automáticamente por fila. El paso `actualizar_totales_y_stock()` lo hace de forma masiva (una sentencia `UPDATE` con `JOIN` en lugar de fila por fila), pero si ese paso falla o tiene un error lógico, los datos quedarían incoherentes.

**Mitigación:** El paso de actualización se ejecuta dentro de una transacción y se verifican los conteos finales por tabla.

### Riesgo 4: Dejar la base sin triggers habilitados
Si el script falla antes de llegar a `habilitar_triggers()`, la base queda con los 7 triggers deshabilitados permanentemente hasta que alguien los vuelva a habilitar manualmente.

**Mitigación:** El flujo está diseñado para que `habilitar_triggers()` se ejecute al final del mismo `main()` que `deshabilitar_triggers()`. En caso de falla intermedia, un operador debe revisar el estado de los triggers con:
```sql
SELECT tgname, tgenabled FROM pg_trigger WHERE tgname LIKE 'trg_%';
```
y volver a habilitar con `ALTER TABLE ... ENABLE TRIGGER`.

### Riesgo 5: Datos cargados no validados por reglas de negocio
Como los triggers están deshabilitados durante la inserción, los datos cargados no pasan por las validaciones de RN-01 a RN-15. Esto es aceptable para carga histórica controlada, pero no para carga de datos de usuario en producción.

**Mitigación:** Esta estrategia solo se usa en la carga masiva inicial (Etapa 3). En producción, la API y el front llaman a funciones/procedimientos con triggers activos.

---

## 3. Alternativas evaluadas y descartadas

| Alternativa | Por qué se descartó |
|-------------|---------------------|
| Cargar con triggers habilitados | `trg_validar_stock_venta` rechazaría inserciones por stock insuficiente en sala (el stock se ajusta después). `trg_descontar_stock_y_calcular_totales` dispararía ~375.000 actualizaciones individuales, haciendo la carga extremadamente lenta. |
| Cargar renglones con `descuento_aplicado = 0` y actualizar después | Violaría RN-06 (descuento según tipo de cliente) y requeriría pasos adicionales de limpieza. |
| Usar `COPY` en lugar de `INSERT` | `COPY` no dispara triggers, pero no permite el control por lotes ni el manejo de `ON CONFLICT` de forma tan flexible. Además, `COPY` requiere acceso a archivos del servidor. |
| No deshabilitar ningún trigger y aceptar la lentitud | Con ~375.000 renglones, el trigger AFTER INSERT por fila haría la carga inviable en tiempo razonable. |

---

## 4. Validación post-carga

Tras rehabilitar los triggers, se ejecutan consultas de control:

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

Resultado esperado: stock negativo = 0, totales inconsistentes = 0.

---

## 5. Archivos generados

- `dump_completo.sql.gz` — Volcado completo de la base cargada con `pg_dump --no-owner --no-privileges`, comprimido con gzip. Permite restaurar la base en otra instancia:
  ```bash
  zcat dump_completo.sql.gz | psql -U bodegas_owner -d bodegas
  ```

---

## 6. Conclusión

La decisión de deshabilitar triggers durante la carga masiva está justificada por la incompatibilidad de ciertos triggers con inserciones históricas en volumen y por el impacto de rendimiento. Los riesgos se mitigan con recálculo explícito de totales y stock, consultas de control finales, idempotencia del script y generación de volcado de respaldo. Los triggers se rehabilitan al finalizar, restaurando la protección de todas las reglas de negocio (RN-01 a RN-15) para operaciones posteriores.
