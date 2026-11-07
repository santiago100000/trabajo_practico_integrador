const { pool } = require('./index');

async function crearComprobante({ id_cliente, id_sala, renglones }) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const cabeceraQuery = `
      INSERT INTO comprobante (fecha, id_cliente, id_sala, subtotal, descuento, total)
      VALUES (CURRENT_DATE, $1, $2, 0, 0, 0)
      RETURNING nro_comprobante
    `;
    const cabeceraResult = await client.query(cabeceraQuery, [id_cliente, id_sala]);
    const nroComprobante = cabeceraResult.rows[0].nro_comprobante;

    const renglonQuery = `
      INSERT INTO renglon_comprobante (nro_comprobante, cod_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
      VALUES ($1, $2, $3, $4, $5, $6)
    `;
    for (const r of renglones) {
      await client.query(renglonQuery, [
        nroComprobante,
        r.cod_vino,
        r.cantidad,
        r.precio_unitario,
        r.descuento_aplicado,
        r.subtotal || 0,
      ]);
    }

    await client.query('COMMIT');
    return nroComprobante;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function obtenerComprobante(nroComprobante) {
  const cabeceraQuery = `
    SELECT c.nro_comprobante, c.fecha, c.id_cliente, c.id_sala,
           cl.nombre_razon_social AS cliente, cl.tipo_cliente,
           s.id_sala, s.calle, s.numero AS sala_numero,
           c.subtotal, c.descuento, c.total
    FROM comprobante c
    JOIN cliente cl ON cl.id_cliente = c.id_cliente
    JOIN sala_venta s ON s.id_sala = c.id_sala
    WHERE c.nro_comprobante = $1
  `;
  const cabeceraResult = await pool.query(cabeceraQuery, [nroComprobante]);
  if (cabeceraResult.rows.length === 0) return null;

  const renglonesQuery = `
    SELECT r.cod_vino, v.nombre AS vino, r.cantidad, r.precio_unitario,
           r.descuento_aplicado, r.subtotal
    FROM renglon_comprobante r
    JOIN vino v ON v.cod_vino = r.cod_vino
    WHERE r.nro_comprobante = $1
    ORDER BY r.cod_vino
  `;
  const renglonesResult = await pool.query(renglonesQuery, [nroComprobante]);

  return {
    ...cabeceraResult.rows[0],
    renglones: renglonesResult.rows,
  };
}

module.exports = {
  crearComprobante,
  obtenerComprobante,
};
