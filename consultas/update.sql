-- =============================================================================
-- update.sql
-- Consignas U1-U6 del enunciado PDF (sección 8.1 - Modificación de datos).
-- Cada sentencia se prueba dentro de BEGIN; ... ROLLBACK; para mostrar
-- estado antes y después sin dejar cambios a medias.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- U1: Recalcular el total de todos los comprobantes aplicando el descuento que
-- corresponde al tipo de cliente.
-- -----------------------------------------------------------------------------
-- Estrategia: actualizar la columna descuento de comprobante con el importe del
-- descuento según tipo_cliente del cliente (socio 10 %, distribuidor 20 %,
-- exportador 30 %). Usar fn_descuento_cliente para obtener el % y calcular el
-- importe sobre el subtotal de los renglones.
-- Nota: el subtotal de cada comprobante se recalcula desde sus renglones;
-- el importe de descuento = subtotal * descuento_pct / 100.
BEGIN;
  -- Control previo: muestra algunos comprobantes antes del cambio
  SELECT nro_comprobante, id_cliente, subtotal, descuento, total
  FROM comprobante ORDER BY nro_comprobante LIMIT 5;

  UPDATE comprobante c
  SET descuento = sub.subtotal * fn_descuento_cliente(cl.tipo_cliente) / 100
  FROM (
      SELECT nro_comprobante, SUM(r.subtotal) AS subtotal
      FROM renglon_comprobante r
      GROUP BY nro_comprobante
  ) sub
  JOIN cliente cl ON cl.id_cliente = c.id_cliente
  WHERE c.nro_comprobante = sub.nro_comprobante;

  -- Control posterior: verificar que los descuentos se aplicaron correctamente
  SELECT nro_comprobante, id_cliente, subtotal, descuento,
         subtotal * fn_descuento_cliente(cl.tipo_cliente) / 100 AS descuento_esperado
  FROM comprobante c
  JOIN cliente cl ON cl.id_cliente = c.id_cliente
  ORDER BY nro_comprobante LIMIT 5;

ROLLBACK;

-- -----------------------------------------------------------------------------
-- U2: Aumentar un 20 % el salario de los empleados con más de 5 años de
-- antigüedad.
-- -----------------------------------------------------------------------------
-- Estrategia: usar fn_antiguedad_anios(fecha_ingreso) para calcular años de
-- antigüedad y aumentar salario un 20 % donde sea > 5.
BEGIN;
  -- Control previo
  SELECT id_empleado, nombre, apellido, fecha_ingreso, salario,
         fn_antiguedad_anios(fecha_ingreso) AS anos_antiguedad
  FROM empleado ORDER BY id_empleado LIMIT 5;

  UPDATE empleado
  SET salario = salario * 1.20
  WHERE fn_antiguedad_anios(fecha_ingreso) > 5;

  -- Control posterior
  SELECT id_empleado, nombre, apellido, salario,
         fn_antiguedad_anios(fecha_ingreso) AS anos_antiguedad
  FROM empleado
  WHERE fn_antiguedad_anios(fecha_ingreso) > 5
  ORDER BY id_empleado LIMIT 5;

ROLLBACK;

-- -----------------------------------------------------------------------------
-- U3: Incrementar un 13 % el precio de los vinos elaborados por una bodega
-- determinada.
-- -----------------------------------------------------------------------------
-- Estrategia: seleccionar una bodega concreta (por razon_social) y aumentar
-- precio un 13 %. El trigger trg_auditoria_precio_vino registrará el cambio
-- (RN-13).
BEGIN;
  -- Control previo: vinos de la bodega antes del cambio
  SELECT v.cod_vino, v.nombre, v.precio, b.razon_social
  FROM vino v JOIN bodega b ON b.id_bodega = v.id_bodega
  WHERE b.razon_social = 'Gomez, Villalba and Martinez'
  ORDER BY v.cod_vino LIMIT 5;

  UPDATE vino
  SET precio = precio * 1.13
  WHERE id_bodega = (
      SELECT id_bodega FROM bodega
      WHERE razon_social = 'Gomez, Villalba and Martinez'
      LIMIT 1
  );

  -- Control posterior
  SELECT v.cod_vino, v.nombre, v.precio
  FROM vino v
  WHERE v.id_bodega = (
      SELECT id_bodega FROM bodega
      WHERE razon_social = 'Gomez, Villalba and Martinez'
      LIMIT 1
  )
  ORDER BY v.cod_vino LIMIT 5;

ROLLBACK;

-- -----------------------------------------------------------------------------
-- U4: En las salas cuyo día de cierre es lunes cambiarlo a miércoles y
-- viceversa, en una sola sentencia.
-- -----------------------------------------------------------------------------
-- Estrategia: usar CASE para intercambiar 'lunes' <-> 'miercoles' en una
-- sola sentencia UPDATE.
BEGIN;
  -- Control previo
  SELECT id_sala, calle, dia_cierre FROM sala_venta
  WHERE dia_cierre IN ('lunes', 'miercoles')
  ORDER BY id_sala;

  UPDATE sala_venta
  SET dia_cierre = CASE dia_cierre
      WHEN 'lunes' THEN 'miercoles'
      WHEN 'miercoles' THEN 'lunes'
      ELSE dia_cierre
  END
  WHERE dia_cierre IN ('lunes', 'miercoles');

  -- Control posterior
  SELECT id_sala, calle, dia_cierre FROM sala_venta
  WHERE dia_cierre IN ('lunes', 'miercoles')
  ORDER BY id_sala;

ROLLBACK;

-- -----------------------------------------------------------------------------
-- U5: Aplicar un 15 % de descuento de precio a los 10 vinos menos vendidos de
-- toda la red.
-- -----------------------------------------------------------------------------
-- Estrategia: contar botellas vendidas por vino (suma de cantidad en
-- renglon_comprobante), tomar los 10 con menos ventas (incluyendo vinos sin
-- ventas con LEFT JOIN) y reducir su precio un 15 %.
BEGIN;
  -- Control previo: los 10 vinos menos vendidos
  SELECT v.cod_vino, v.nombre, v.precio, COALESCE(vendidos.total, 0) AS botellas_vendidas
  FROM vino v
  LEFT JOIN (
      SELECT cod_vino, SUM(cantidad) AS total
      FROM renglon_comprobante
      GROUP BY cod_vino
  ) vendidos ON vendidos.cod_vino = v.cod_vino
  ORDER BY botellas_vendidas ASC, v.cod_vino ASC
  LIMIT 10;

  UPDATE vino
  SET precio = precio * 0.85
  WHERE cod_vino IN (
      SELECT cod_vino FROM (
          SELECT v.cod_vino, COALESCE(SUM(r.cantidad), 0) AS botellas_vendidas
          FROM vino v
          LEFT JOIN renglon_comprobante r ON r.cod_vino = v.cod_vino
          GROUP BY v.cod_vino
          ORDER BY botellas_vendidas ASC, v.cod_vino ASC
          LIMIT 10
      ) sub
  );

  -- Control posterior
  SELECT v.cod_vino, v.nombre, v.precio, COALESCE(vendidos.total, 0) AS botellas_vendidas
  FROM vino v
  LEFT JOIN (
      SELECT cod_vino, SUM(cantidad) AS total
      FROM renglon_comprobante
      GROUP BY cod_vino
  ) vendidos ON vendidos.cod_vino = v.cod_vino
  WHERE v.cod_vino IN (
      SELECT cod_vino FROM (
          SELECT v.cod_vino, COALESCE(SUM(r.cantidad), 0) AS botellas_vendidas
          FROM vino v
          LEFT JOIN renglon_comprobante r ON r.cod_vino = v.cod_vino
          GROUP BY v.cod_vino
          ORDER BY botellas_vendidas ASC, v.cod_vino ASC
          LIMIT 10
      ) sub
  )
  ORDER BY botellas_vendidas ASC, v.cod_vino ASC;

ROLLBACK;

-- -----------------------------------------------------------------------------
-- U6: A los exportadores con más de 3 permisos de exportación, subirles el
-- descuento al 35 %.
-- -----------------------------------------------------------------------------
-- Estrategia: identificar exportadores con COUNT(permiso_exportacion) > 3 y
-- actualizar descuento a 35 en la tabla cliente (tipo_cliente = 'exportador').
BEGIN;
  -- Control previo
  SELECT c.id_cliente, c.nombre_razon_social, c.descuento,
         COUNT(p.codigo) AS n_permisos
  FROM cliente c
  JOIN exportador e ON e.id_cliente = c.id_cliente
  LEFT JOIN permiso_exportacion p ON p.id_cliente = e.id_cliente
  WHERE c.tipo_cliente = 'exportador'
  GROUP BY c.id_cliente, c.nombre_razon_social, c.descuento
  ORDER BY c.id_cliente;

  UPDATE cliente
  SET descuento = 35
  WHERE tipo_cliente = 'exportador'
    AND id_cliente IN (
        SELECT e.id_cliente
        FROM exportador e
        JOIN permiso_exportacion p ON p.id_cliente = e.id_cliente
        GROUP BY e.id_cliente
        HAVING COUNT(p.codigo) > 3
    );

  -- Control posterior
  SELECT c.id_cliente, c.nombre_razon_social, c.descuento,
         COUNT(p.codigo) AS n_permisos
  FROM cliente c
  JOIN exportador e ON e.id_cliente = c.id_cliente
  LEFT JOIN permiso_exportacion p ON p.id_cliente = e.id_cliente
  WHERE c.tipo_cliente = 'exportador'
  GROUP BY c.id_cliente, c.nombre_razon_social, c.descuento
  ORDER BY c.id_cliente;

ROLLBACK;

-- =============================================================================
-- Fin de update.sql
-- =============================================================================
