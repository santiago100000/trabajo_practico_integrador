-- ============================================================================
-- consultas/update.sql — Etapa 5: Consultas SQL (UPDATE)
-- Sección 8.1 del enunciado TPI Bodegas del Atuel
-- Valores concretos tomados del dataset cargado (Etapa 3, semilla 42).
-- Cada modificación se ejecuta dentro de BEGIN ... ROLLBACK para no persistir cambios.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- U1: Recalcular el total de todos los comprobantes aplicando el descuento
--     que corresponde al tipo de cliente.
-- Estrategia: actualizar subtotal, descuento y total de cada comprobante a
--     partir de sus renglones. El descuento por cliente ya está reflejado en
--     cada renglón (descuento_aplicado), por lo que el total del comprobante
--     es la suma de subtotales de renglones, y el monto de descuento es la
--     diferencia entre el bruto (precio * cantidad) y lo neto.
-- ---------------------------------------------------------------------------
BEGIN;
-- Control antes: mostrar algunos comprobantes con sus valores actuales
SELECT c.nro_comprobante, c.subtotal, c.descuento, c.total
FROM comprobante c
ORDER BY c.nro_comprobante
LIMIT 3;

UPDATE comprobante c
SET subtotal = sub.suma_neta,
    descuento = sub.suma_bruta - sub.suma_neta,
    total = sub.suma_neta
FROM (
    SELECT rc.nro_comprobante,
           SUM(rc.precio_unitario * rc.cantidad) AS suma_bruta,
           SUM(rc.subtotal) AS suma_neta
    FROM renglon_comprobante rc
    GROUP BY rc.nro_comprobante
) sub
WHERE c.nro_comprobante = sub.nro_comprobante;

-- Control después: verificar que los valores se actualizaron
SELECT c.nro_comprobante, c.subtotal, c.descuento, c.total,
       fn_total_comprobante(c.nro_comprobante) AS total_verificado
FROM comprobante c
ORDER BY c.nro_comprobante
LIMIT 3;
ROLLBACK;

-- ---------------------------------------------------------------------------
-- U2: Aumentar un 20 % el salario de los empleados con más de 5 años
--     de antigüedad.
-- Estrategia: fecha_ingreso <= hace 5 años. Aplicar salario * 1.20.
-- ---------------------------------------------------------------------------
BEGIN;
-- Control antes: empleados con más de 5 años y sus salarios actuales
SELECT id_empleado, nombre, apellido, fecha_ingreso, salario
FROM empleado
WHERE fecha_ingreso <= CURRENT_DATE - INTERVAL '5 years'
ORDER BY id_empleado;

UPDATE empleado
SET salario = ROUND(salario * 1.20, 2)
WHERE fecha_ingreso <= CURRENT_DATE - INTERVAL '5 years';

-- Control después: verificar los nuevos salarios
SELECT id_empleado, nombre, apellido, fecha_ingreso, salario
FROM empleado
WHERE fecha_ingreso <= CURRENT_DATE - INTERVAL '5 years'
ORDER BY id_empleado;
ROLLBACK;

-- ---------------------------------------------------------------------------
-- U3: Incrementar un 13 % el precio de los vinos elaborados por una bodega
--     determinada. Usamos id_bodega = 1 (Gomez, Villalba and Martinez).
-- Estrategia: precio * 1.13. Dispara trigger trg_auditoria_precio_vino (RN-13).
-- ---------------------------------------------------------------------------
BEGIN;
-- Control antes: vinos de la bodega 1 con precios actuales
SELECT cod_vino, nombre, precio
FROM vino
WHERE id_bodega = 1
ORDER BY cod_vino;

UPDATE vino
SET precio = ROUND(precio * 1.13, 2)
WHERE id_bodega = 1;

-- Control después: verificar nuevos precios y auditoría
SELECT cod_vino, nombre, precio
FROM vino
WHERE id_bodega = 1
ORDER BY cod_vino;

SELECT * FROM auditoria_precio
WHERE cod_vino IN (SELECT cod_vino FROM vino WHERE id_bodega = 1)
ORDER BY id_auditoria DESC
LIMIT 10;
ROLLBACK;

-- ---------------------------------------------------------------------------
-- U4: En las salas cuyo día de cierre es lunes cambiarlo a miércoles y
--     viceversa, en una sola sentencia.
-- Estrategia: CASE WHEN para intercambiar los dos valores.
-- ---------------------------------------------------------------------------
BEGIN;
-- Control antes: salas con lunes o miércoles
SELECT id_sala, calle, numero, dia_cierre
FROM sala_venta
WHERE dia_cierre IN ('lunes', 'miercoles')
ORDER BY id_sala;

UPDATE sala_venta
SET dia_cierre = CASE
    WHEN dia_cierre = 'lunes' THEN 'miercoles'
    WHEN dia_cierre = 'miercoles' THEN 'lunes'
    ELSE dia_cierre
END
WHERE dia_cierre IN ('lunes', 'miercoles');

-- Control después: verificar el intercambio
SELECT id_sala, calle, numero, dia_cierre
FROM sala_venta
WHERE dia_cierre IN ('lunes', 'miercoles')
ORDER BY id_sala;
ROLLBACK;

-- ---------------------------------------------------------------------------
-- U5: Aplicar un 15 % de descuento de precio a los 10 vinos menos vendidos
--     de toda la red.
-- Estrategia: identificar los 10 vinos con menor suma de cantidades vendidas
--     en renglon_comprobante, y aplicar precio * 0.85. Dispara trigger de
--     auditoría de precios (RN-13).
-- ---------------------------------------------------------------------------
BEGIN;
-- Control antes: los 10 vinos menos vendidos con sus precios actuales
WITH ventas_por_vino AS (
    SELECT rc.cod_vino, SUM(rc.cantidad) AS total_vendido
    FROM renglon_comprobante rc
    GROUP BY rc.cod_vino
)
SELECT v.cod_vino, v.nombre, v.precio, COALESCE(vv.total_vendido, 0) AS total_vendido
FROM vino v
LEFT JOIN ventas_por_vino vv ON vv.cod_vino = v.cod_vino
ORDER BY total_vendido ASC, v.cod_vino
LIMIT 10;

UPDATE vino
SET precio = ROUND(precio * 0.85, 2)
WHERE cod_vino IN (
    SELECT cod_vino FROM (
        SELECT rc.cod_vino, SUM(rc.cantidad) AS total_vendido
        FROM renglon_comprobante rc
        GROUP BY rc.cod_vino
        ORDER BY total_vendido ASC
        LIMIT 10
    ) sub
);

-- Control después: verificar los nuevos precios y auditoría
WITH ventas_por_vino AS (
    SELECT rc.cod_vino, SUM(rc.cantidad) AS total_vendido
    FROM renglon_comprobante rc
    GROUP BY rc.cod_vino
)
SELECT v.cod_vino, v.nombre, v.precio, COALESCE(vv.total_vendido, 0) AS total_vendido
FROM vino v
LEFT JOIN ventas_por_vino vv ON vv.cod_vino = v.cod_vino
ORDER BY total_vendido ASC, v.cod_vino
LIMIT 10;

SELECT * FROM auditoria_precio
WHERE cod_vino IN (
    SELECT cod_vino FROM (
        SELECT rc.cod_vino, SUM(rc.cantidad) AS total_vendido
        FROM renglon_comprobante rc
        GROUP BY rc.cod_vino
        ORDER BY total_vendido ASC
        LIMIT 10
    ) sub
)
ORDER BY id_auditoria DESC
LIMIT 10;
ROLLBACK;

-- ---------------------------------------------------------------------------
-- U6: A los exportadores con más de 3 permisos de exportación, subirles el
--     descuento al 35 %.
-- Estrategia: subconsulta sobre permiso_exportacion con HAVING count(*) > 3.
-- En el dataset actual no hay exportadores con más de 3 permisos, por lo que
-- no se afectarán filas, pero la sentencia es válida.
-- ---------------------------------------------------------------------------
BEGIN;
-- Control antes: exportadores y su cantidad de permisos
SELECT c.id_cliente, c.nombre_razon_social, c.descuento,
       COUNT(p.codigo) AS cant_permisos
FROM cliente c
JOIN exportador e ON e.id_cliente = c.id_cliente
LEFT JOIN permiso_exportacion p ON p.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre_razon_social, c.descuento
ORDER BY cant_permisos DESC, c.id_cliente;

UPDATE cliente c
SET descuento = 35
WHERE c.tipo_cliente = 'exportador'
  AND c.id_cliente IN (
      SELECT id_cliente
      FROM permiso_exportacion
      GROUP BY id_cliente
      HAVING COUNT(*) > 3
  );

-- Control después: verificar descuentos de exportadores
SELECT c.id_cliente, c.nombre_razon_social, c.descuento,
       COUNT(p.codigo) AS cant_permisos
FROM cliente c
JOIN exportador e ON e.id_cliente = c.id_cliente
LEFT JOIN permiso_exportacion p ON p.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.nombre_razon_social, c.descuento
ORDER BY cant_permisos DESC, c.id_cliente;
ROLLBACK;
