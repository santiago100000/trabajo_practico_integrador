const { pool } = require('./index');

async function topVinos() {
  const query = `
    SELECT v.cod_vino, v.nombre, v.tipo, v.anada,
           SUM(rc.cantidad) AS botellas_vendidas
    FROM renglon_comprobante rc
    JOIN comprobante c ON c.nro_comprobante = rc.nro_comprobante
    JOIN vino v ON v.cod_vino = rc.cod_vino
    GROUP BY v.cod_vino, v.nombre, v.tipo, v.anada
    ORDER BY botellas_vendidas DESC
    LIMIT 10
  `;
  const { rows } = await pool.query(query);
  return rows;
}

async function ventasPorSala() {
  const query = `
    SELECT s.id_sala, s.calle, s.numero,
           SUM(cp.total) AS ventas_totales
    FROM comprobante cp
    JOIN sala_venta s ON s.id_sala = cp.id_sala
    WHERE cp.fecha >= CURRENT_DATE - INTERVAL '3 months'
    GROUP BY s.id_sala, s.calle, s.numero
    ORDER BY ventas_totales DESC
  `;
  const { rows } = await pool.query(query);
  return rows;
}

async function vinosSinStock({ id_sala }) {
  const query = `
    SELECT v.cod_vino, v.nombre, v.tipo, v.anada
    FROM vino v
    JOIN stock_deposito sd ON sd.cod_vino = v.cod_vino AND sd.cantidad > 0
    LEFT JOIN stock_sala ss ON ss.cod_vino = v.cod_vino AND ss.id_sala = $1
    WHERE ss.cod_vino IS NULL OR ss.cantidad = 0
    ORDER BY v.cod_vino
  `;
  const { rows } = await pool.query(query, [id_sala]);
  return rows;
}

async function transportistaActivo() {
  const query = `
    SELECT tr.cod_transportista, tr.razon_social,
           COUNT(i.cod_ingreso) AS ingresos_ultimo_mes
    FROM ingreso i
    JOIN transportista tr ON tr.cod_transportista = i.cod_transportista
    WHERE i.fecha >= CURRENT_DATE - INTERVAL '1 month'
    GROUP BY tr.cod_transportista, tr.razon_social
    ORDER BY ingresos_ultimo_mes DESC
    LIMIT 1
  `;
  const { rows } = await pool.query(query);
  return rows;
}

async function trazabilidad(codVino) {
  const query = `
    SELECT
      v.cod_vino,
      v.nombre,
      b.razon_social AS bodega,
      string_agg(DISTINCT c.nombre || ' (' || vc.porcentaje || '%)', ', ') AS cepas,
      string_agg(DISTINCT m.nombre, ', ') AS maridajes,
      COALESCE(sd.cantidad, 0) + COALESCE(ss.stock_salas, 0) AS stock_total
    FROM vino v
    JOIN bodega b ON b.id_bodega = v.id_bodega
    LEFT JOIN vino_cepa vc ON vc.cod_vino = v.cod_vino
    LEFT JOIN cepa c ON c.id_cepa = vc.id_cepa
    LEFT JOIN vino_maridaje vm ON vm.cod_vino = v.cod_vino
    LEFT JOIN maridaje m ON m.id_maridaje = vm.id_maridaje
    LEFT JOIN stock_deposito sd ON sd.cod_vino = v.cod_vino
    LEFT JOIN (
      SELECT cod_vino, SUM(cantidad) AS stock_salas
      FROM stock_sala
      GROUP BY cod_vino
    ) ss ON ss.cod_vino = v.cod_vino
    WHERE v.cod_vino = $1
    GROUP BY v.cod_vino, v.nombre, b.razon_social, sd.cantidad, ss.stock_salas
  `;
  const { rows } = await pool.query(query, [codVino]);
  return rows[0] || null;
}

module.exports = {
  topVinos,
  ventasPorSala,
  vinosSinStock,
  transportistaActivo,
  trazabilidad,
};
