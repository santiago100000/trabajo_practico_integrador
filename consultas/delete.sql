-- ============================================================================
-- consultas/delete.sql — Etapa 5, Paso 1 y Paso 2: Consultas SQL (DELETE)
-- Sección 8.3 del enunciado TPI Bodegas del Atuel
-- Cada consigna incluye: código, enunciado, consulta SQL y estrategia.
-- Valores concretos tomados del dataset cargado (Etapa 3, semilla 42).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- D1: Borrar los comprobantes con más de 5 años de antigüedad asociados a
--     clientes socios del club.
-- Estrategia: DELETE con JOIN a cliente y filtro por tipo_cliente='socio' y
-- fecha > 5 años. Los renglones de comprobante se borran en cascada por
-- ON DELETE CASCADE (fk_renglon_comp_comprobante).
-- ---------------------------------------------------------------------------
BEGIN;
-- Consulta de control previa: comprobantes que serían borrados
SELECT c.nro_comprobante, c.fecha, c.id_cliente, cl.nombre_razon_social, cl.tipo_cliente
FROM comprobante c
JOIN cliente cl ON cl.id_cliente = c.id_cliente
WHERE cl.tipo_cliente = 'socio'
  AND c.fecha <= CURRENT_DATE - INTERVAL '5 years'
ORDER BY c.nro_comprobante;

DELETE FROM comprobante c
USING cliente cl
WHERE c.id_cliente = cl.id_cliente
  AND cl.tipo_cliente = 'socio'
  AND c.fecha <= CURRENT_DATE - INTERVAL '5 years';

-- Consulta de control posterior: verificar que no queden comprobantes socios > 5 años
SELECT count(*) AS comprobantes_socios_mas_5_anos
FROM comprobante c
JOIN cliente cl ON cl.id_cliente = c.id_cliente
WHERE cl.tipo_cliente = 'socio'
  AND c.fecha <= CURRENT_DATE - INTERVAL '5 years';
ROLLBACK;

-- ---------------------------------------------------------------------------
-- D2: Eliminar las cepas que no componen ningún vino ni están plantadas en
--     ninguna parcela.
-- Estrategia: DELETE con NOT EXISTS verificando que no haya filas en
-- vino_cepa ni en parcela que referencien a la cepa.
-- ---------------------------------------------------------------------------
BEGIN;
-- Consulta de control previa: cepas que serían eliminadas
SELECT c.id_cepa, c.nombre, c.tipo
FROM cepa c
WHERE NOT EXISTS (
    SELECT 1 FROM vino_cepa vc WHERE vc.id_cepa = c.id_cepa
)
  AND NOT EXISTS (
    SELECT 1 FROM parcela p WHERE p.id_cepa = c.id_cepa
);

DELETE FROM cepa c
WHERE NOT EXISTS (
    SELECT 1 FROM vino_cepa vc WHERE vc.id_cepa = c.id_cepa
)
  AND NOT EXISTS (
    SELECT 1 FROM parcela p WHERE p.id_cepa = c.id_cepa
);

-- Consulta de control posterior: verificar que no queden cepas huérfanas
SELECT count(*) AS cepas_huerfanas
FROM cepa c
WHERE NOT EXISTS (
    SELECT 1 FROM vino_cepa vc WHERE vc.id_cepa = c.id_cepa
)
  AND NOT EXISTS (
    SELECT 1 FROM parcela p WHERE p.id_cepa = c.id_cepa
);
ROLLBACK;

-- ---------------------------------------------------------------------------
-- D3: La sala de una localidad determinada fue dada de baja: eliminar los
--     empleados de esa sala que trabajaron menos de dos años.
-- Parámetro: localidad ID 4 (donde está la sala 1).
-- Estrategia: DELETE desde empleado usando JOIN con sala_venta y localidad,
-- filtrando por localidad y fecha_ingreso < 2 años.
-- ---------------------------------------------------------------------------
BEGIN;
-- Consulta de control previa: empleados de salas en localidad 4 con < 2 años
SELECT e.id_empleado, e.nombre, e.apellido, e.fecha_ingreso, s.id_sala, l.nombre AS localidad
FROM empleado e
JOIN sala_venta s ON s.id_sala = e.id_sala
JOIN localidad l ON l.id_localidad = s.id_localidad
WHERE l.id_localidad = 4
  AND e.fecha_ingreso > CURRENT_DATE - INTERVAL '2 years'
ORDER BY e.id_empleado;

DELETE FROM empleado e
USING sala_venta s, localidad l
WHERE e.id_sala = s.id_sala
  AND s.id_localidad = l.id_localidad
  AND l.id_localidad = 4
  AND e.fecha_ingreso > CURRENT_DATE - INTERVAL '2 years';

-- Consulta de control posterior: verificar que no queden empleados < 2 años en localidad 4
SELECT count(*) AS empleados_menos_2_anos_localidad_4
FROM empleado e
JOIN sala_venta s ON s.id_sala = e.id_sala
JOIN localidad l ON l.id_localidad = s.id_localidad
WHERE l.id_localidad = 4
  AND e.fecha_ingreso > CURRENT_DATE - INTERVAL '2 years';
ROLLBACK;

-- ---------------------------------------------------------------------------
-- D4: Borrar los clientes socios que nunca compraron y se dieron de alta hace
--     más de 5 años.
-- Estrategia: DELETE desde cliente y socio con NOT EXISTS verificando que no
-- haya compras y fecha_alta > 5 años. ON DELETE CASCADE borra la fila de socio.
-- ---------------------------------------------------------------------------
BEGIN;
-- Consulta de control previa: clientes socios sin compras y > 5 años de alta
SELECT c.id_cliente, c.nombre_razon_social, c.fecha_alta
FROM cliente c
JOIN socio s ON s.id_cliente = c.id_cliente
WHERE c.tipo_cliente = 'socio'
  AND c.fecha_alta <= CURRENT_DATE - INTERVAL '5 years'
  AND NOT EXISTS (
    SELECT 1 FROM comprobante cp WHERE cp.id_cliente = c.id_cliente
  )
ORDER BY c.id_cliente;

DELETE FROM cliente c
USING socio s
WHERE c.id_cliente = s.id_cliente
  AND c.tipo_cliente = 'socio'
  AND c.fecha_alta <= CURRENT_DATE - INTERVAL '5 years'
  AND NOT EXISTS (
    SELECT 1 FROM comprobante cp WHERE cp.id_cliente = c.id_cliente
  );

-- Consulta de control posterior
SELECT count(*) AS socios_sin_compras_mas_5_anos
FROM cliente c
JOIN socio s ON s.id_cliente = c.id_cliente
WHERE c.tipo_cliente = 'socio'
  AND c.fecha_alta <= CURRENT_DATE - INTERVAL '5 years'
  AND NOT EXISTS (
    SELECT 1 FROM comprobante cp WHERE cp.id_cliente = c.id_cliente
  );
ROLLBACK;

-- ---------------------------------------------------------------------------
-- D5: Eliminar los ingresos en estado procesado de hace más de 365 días.
-- Estrategia: DELETE con filtro por estado='procesado' y fecha > 365 días.
-- Los renglones de ingreso se borran en cascada por ON DELETE CASCADE.
-- ---------------------------------------------------------------------------
BEGIN;
-- Consulta de control previa: ingresos procesados > 365 días
SELECT i.cod_ingreso, i.fecha, i.estado
FROM ingreso i
WHERE i.estado = 'procesado'
  AND i.fecha <= CURRENT_DATE - INTERVAL '365 days'
ORDER BY i.cod_ingreso;

DELETE FROM ingreso i
WHERE i.estado = 'procesado'
  AND i.fecha <= CURRENT_DATE - INTERVAL '365 days';

-- Consulta de control posterior
SELECT count(*) AS ingresos_procesados_mas_365_dias
FROM ingreso i
WHERE i.estado = 'procesado'
  AND i.fecha <= CURRENT_DATE - INTERVAL '365 days';
ROLLBACK;

-- ---------------------------------------------------------------------------
-- D6: Borrar los clientes socios sin compras que viven en una localidad
--     específica.
-- Parámetro: localidad ID 12 (General Alvear).
-- Estrategia: DELETE desde cliente y socio con NOT EXISTS para compras y
-- filtro por localidad. ON DELETE CASCADE borra la fila de socio.
-- ---------------------------------------------------------------------------
BEGIN;
-- Consulta de control previa: clientes socios sin compras en localidad 12
SELECT c.id_cliente, c.nombre_razon_social, c.direccion, l.nombre AS localidad
FROM cliente c
JOIN socio s ON s.id_cliente = c.id_cliente
JOIN localidad l ON l.id_localidad = c.id_localidad
WHERE l.id_localidad = 12
  AND NOT EXISTS (
    SELECT 1 FROM comprobante cp WHERE cp.id_cliente = c.id_cliente
  )
ORDER BY c.id_cliente;

DELETE FROM cliente c
USING socio s
WHERE c.id_cliente = s.id_cliente
  AND c.tipo_cliente = 'socio'
  AND c.id_localidad = 12
  AND NOT EXISTS (
    SELECT 1 FROM comprobante cp WHERE cp.id_cliente = c.id_cliente
  );

-- Consulta de control posterior
SELECT count(*) AS socios_sin_compras_localidad_12
FROM cliente c
JOIN socio s ON s.id_cliente = c.id_cliente
JOIN localidad l ON l.id_localidad = c.id_localidad
WHERE l.id_localidad = 12
  AND NOT EXISTS (
    SELECT 1 FROM comprobante cp WHERE cp.id_cliente = c.id_cliente
  );
ROLLBACK;
