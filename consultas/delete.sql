-- =============================================================================
-- delete.sql
-- Consignas D1-D6 del enunciado PDF (sección 8.3 - Borrado de datos).
-- Cada sentencia se prueba dentro de BEGIN; ... ROLLBACK; para mostrar
-- estado antes y después sin dejar cambios a medias. Las FK con ON DELETE
-- CASCADE arrastran los renglones asociados automáticamente.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- D1: Borrar los comprobantes con más de 5 años de antigüedad asociados a
-- clientes socios del club.
-- -----------------------------------------------------------------------------
-- Estrategia: borrar de comprobante donde el cliente es socio (tipo_cliente =
-- 'socio') y la fecha es anterior a hace 5 años (medido desde CURRENT_DATE).
-- Los renglones se borran por ON DELETE CASCADE (fk_renglon_comp_comprobante).
BEGIN;
  -- Control previo
  SELECT c.nro_comprobante, c.fecha, cl.nombre_razon_social, cl.tipo_cliente
  FROM comprobante c
  JOIN cliente cl ON cl.id_cliente = c.id_cliente
  WHERE cl.tipo_cliente = 'socio'
    AND c.fecha < CURRENT_DATE - INTERVAL '5 years'
  ORDER BY c.nro_comprobante;

  DELETE FROM comprobante
  WHERE id_cliente IN (
      SELECT id_cliente FROM cliente WHERE tipo_cliente = 'socio'
    )
    AND fecha < CURRENT_DATE - INTERVAL '5 years';

  -- Control posterior: debe devolver 0 filas
  SELECT COUNT(*) AS comprobantes_socio_mas_de_5_anos
  FROM comprobante c
  JOIN cliente cl ON cl.id_cliente = c.id_cliente
  WHERE cl.tipo_cliente = 'socio'
    AND c.fecha < CURRENT_DATE - INTERVAL '5 years';

ROLLBACK;

-- -----------------------------------------------------------------------------
-- D2: Eliminar las cepas que no componen ningún vino ni están plantadas en
-- ninguna parcela.
-- -----------------------------------------------------------------------------
-- Estrategia: borrar de cepa donde no exista fila en vino_cepa (N:M con vino)
-- ni en parcela (entidad débil). FK con ON DELETE RESTRICT en esas tablas, por
-- lo que solo se podrán borrar si no hay dependencias.
BEGIN;
  -- Control previo: cepas sin uso
  SELECT c.id_cepa, c.nombre, c.tipo
  FROM cepa c
  WHERE NOT EXISTS (SELECT 1 FROM vino_cepa vc WHERE vc.id_cepa = c.id_cepa)
    AND NOT EXISTS (SELECT 1 FROM parcela p WHERE p.id_cepa = c.id_cepa);

  DELETE FROM cepa
  WHERE NOT EXISTS (SELECT 1 FROM vino_cepa vc WHERE vc.id_cepa = cepa.id_cepa)
    AND NOT EXISTS (SELECT 1 FROM parcela p WHERE p.id_cepa = cepa.id_cepa);

  -- Control posterior: debe devolver 0 cepas sin uso (todas las cepas están en
  -- uso o ya se borraron las que no lo estaban)
  SELECT COUNT(*) AS cepas_sin_uso
  FROM cepa c
  WHERE NOT EXISTS (SELECT 1 FROM vino_cepa vc WHERE vc.id_cepa = c.id_cepa)
    AND NOT EXISTS (SELECT 1 FROM parcela p WHERE p.id_cepa = c.id_cepa);

ROLLBACK;

-- -----------------------------------------------------------------------------
-- D3: La sala de una localidad determinada fue dada de baja: eliminar los
-- empleados de esa sala que trabajaron menos de dos años.
-- -----------------------------------------------------------------------------
-- Estrategia: elegir una localidad (ej. 'Mendoza'), obtener sus salas, y borrar
-- empleados de esas salas con antigüedad < 2 años (fn_antiguedad_anios).
BEGIN;
  -- Control previo: empleados a borrar
  SELECT e.id_empleado, e.nombre, e.apellido, s.id_sala, l.nombre AS localidad,
         e.fecha_ingreso, fn_antiguedad_anios(e.fecha_ingreso) AS anos_antiguedad
  FROM empleado e
  JOIN sala_venta s ON s.id_sala = e.id_sala
  JOIN localidad l ON l.id_localidad = s.id_localidad
  WHERE l.nombre = 'Mendoza'
    AND fn_antiguedad_anios(e.fecha_ingreso) < 2
  ORDER BY e.id_empleado;

  DELETE FROM empleado
  WHERE id_sala IN (
      SELECT s.id_sala
      FROM sala_venta s
      JOIN localidad l ON l.id_localidad = s.id_localidad
      WHERE l.nombre = 'Mendoza'
    )
    AND fn_antiguedad_anios(fecha_ingreso) < 2;

  -- Control posterior: debe devolver 0 empleados de Mendoza con < 2 años
  SELECT COUNT(*) AS empleados_mendoza_menos_de_2_anos
  FROM empleado e
  JOIN sala_venta s ON s.id_sala = e.id_sala
  JOIN localidad l ON l.id_localidad = s.id_localidad
  WHERE l.nombre = 'Mendoza'
    AND fn_antiguedad_anios(e.fecha_ingreso) < 2;

ROLLBACK;

-- -----------------------------------------------------------------------------
-- D4: Borrar los clientes socios que nunca compraron y se dieron de alta hace
-- más de 5 años.
-- -----------------------------------------------------------------------------
-- Estrategia: borrar de cliente donde tipo_cliente = 'socio', no exista
-- comprobante asociado, y fecha_alta < hace 5 años. La tabla socio se borra
-- por ON DELETE CASCADE (fk_socio_cliente).
BEGIN;
  -- Control previo: socios a borrar
  SELECT c.id_cliente, c.nombre_razon_social, c.fecha_alta
  FROM cliente c
  WHERE c.tipo_cliente = 'socio'
    AND NOT EXISTS (SELECT 1 FROM comprobante cp WHERE cp.id_cliente = c.id_cliente)
    AND c.fecha_alta < CURRENT_DATE - INTERVAL '5 years';

  DELETE FROM cliente
  WHERE tipo_cliente = 'socio'
    AND NOT EXISTS (SELECT 1 FROM comprobante cp WHERE cp.id_cliente = cliente.id_cliente)
    AND fecha_alta < CURRENT_DATE - INTERVAL '5 years';

  -- Control posterior: debe devolver 0
  SELECT COUNT(*) AS socios_sin_compras_mas_de_5_anos
  FROM cliente c
  WHERE c.tipo_cliente = 'socio'
    AND NOT EXISTS (SELECT 1 FROM comprobante cp WHERE cp.id_cliente = c.id_cliente)
    AND c.fecha_alta < CURRENT_DATE - INTERVAL '5 years';

ROLLBACK;

-- -----------------------------------------------------------------------------
-- D5: Eliminar los ingresos en estado procesado de hace más de 365 días.
-- -----------------------------------------------------------------------------
-- Estrategia: borrar de ingreso donde estado = 'procesado' y fecha anterior a
-- hace 365 días. Los renglones se borran por ON DELETE CASCADE
-- (fk_renglon_ingreso_ingreso).
BEGIN;
  -- Control previo
  SELECT cod_ingreso, fecha, estado
  FROM ingreso
  WHERE estado = 'procesado'
    AND fecha < CURRENT_DATE - INTERVAL '365 days'
  ORDER BY cod_ingreso;

  DELETE FROM ingreso
  WHERE estado = 'procesado'
    AND fecha < CURRENT_DATE - INTERVAL '365 days';

  -- Control posterior: debe devolver 0
  SELECT COUNT(*) AS ingresos_procesados_mas_de_365_dias
  FROM ingreso
  WHERE estado = 'procesado'
    AND fecha < CURRENT_DATE - INTERVAL '365 days';

ROLLBACK;

-- -----------------------------------------------------------------------------
-- D6: Borrar los clientes socios sin compras que viven en una localidad
-- específica.
-- -----------------------------------------------------------------------------
-- Estrategia: elegir una localidad concreta (ej. 'Godoy Cruz'), borrar clientes
-- tipo_cliente = 'socio' de esa localidad que nunca compraron. La tabla socio
-- se borra por CASCADE.
BEGIN;
  -- Control previo: socios de Godoy Cruz sin compras
  SELECT c.id_cliente, c.nombre_razon_social, l.nombre AS localidad
  FROM cliente c
  JOIN localidad l ON l.id_localidad = c.id_localidad
  WHERE c.tipo_cliente = 'socio'
    AND l.nombre = 'Godoy Cruz'
    AND NOT EXISTS (SELECT 1 FROM comprobante cp WHERE cp.id_cliente = c.id_cliente);

  DELETE FROM cliente
  WHERE tipo_cliente = 'socio'
    AND id_localidad = (SELECT id_localidad FROM localidad WHERE nombre = 'Godoy Cruz' LIMIT 1)
    AND NOT EXISTS (SELECT 1 FROM comprobante cp WHERE cp.id_cliente = cliente.id_cliente);

  -- Control posterior: debe devolver 0
  SELECT COUNT(*) AS socios_godoy_cruz_sin_compras
  FROM cliente c
  JOIN localidad l ON l.id_localidad = c.id_localidad
  WHERE c.tipo_cliente = 'socio'
    AND l.nombre = 'Godoy Cruz'
    AND NOT EXISTS (SELECT 1 FROM comprobante cp WHERE cp.id_cliente = c.id_cliente);

ROLLBACK;

-- =============================================================================
-- Fin de delete.sql
-- =============================================================================
