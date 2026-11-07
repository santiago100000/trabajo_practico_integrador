const { pool } = require('./index');

async function listarVinos({ page = 1, limit = 10, tipo, cepa, bodega, anada, nombre }) {
  const offset = (page - 1) * limit;
  const params = [];
  let condiciones = [];

  if (tipo) {
    params.push(tipo);
    condiciones.push(`v.tipo = $${params.length}`);
  }
  if (cepa) {
    params.push(cepa);
    condiciones.push(`EXISTS (SELECT 1 FROM vino_cepa vc JOIN cepa c ON c.id_cepa = vc.id_cepa WHERE vc.cod_vino = v.cod_vino AND c.nombre ILIKE $${params.length})`);
  }
  if (bodega) {
    params.push(`%${bodega}%`);
    condiciones.push(`EXISTS (SELECT 1 FROM bodega b WHERE b.id_bodega = v.id_bodega AND b.razon_social ILIKE $${params.length})`);
  }
  if (nombre) {
    params.push(`%${nombre}%`);
    condiciones.push(`v.nombre ILIKE $${params.length}`);
  }
  if (anada) {
    params.push(anada);
    condiciones.push(`v.anada = $${params.length}`);
  }

  const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : '';
  params.push(limit, offset);

  const query = `
    SELECT v.cod_vino, v.nombre, v.tipo, v.anada, v.volumen_ml, v.graduacion, v.precio,
           b.razon_social AS bodega,
           COALESCE(sd.cantidad, 0) + COALESCE(ss.stock_salas, 0) AS stock_total
    FROM vino v
    JOIN bodega b ON b.id_bodega = v.id_bodega
    LEFT JOIN stock_deposito sd ON sd.cod_vino = v.cod_vino
    LEFT JOIN (
        SELECT cod_vino, SUM(cantidad) AS stock_salas
        FROM stock_sala
        GROUP BY cod_vino
    ) ss ON ss.cod_vino = v.cod_vino
    ${where}
    ORDER BY v.cod_vino
    LIMIT $${params.length - 1} OFFSET $${params.length}
  `;

  const { rows } = await pool.query(query, params);
  return rows;
}

async function obtenerVino(codVino) {
  const vinoQuery = `
    SELECT v.cod_vino, v.nombre, v.tipo, v.anada, v.volumen_ml, v.graduacion, v.precio,
           b.razon_social AS bodega
    FROM vino v
    JOIN bodega b ON b.id_bodega = v.id_bodega
    WHERE v.cod_vino = $1
  `;
  const vinoResult = await pool.query(vinoQuery, [codVino]);
  if (vinoResult.rows.length === 0) return null;

  const composicionQuery = `
    SELECT c.id_cepa, c.nombre AS cepa, c.tipo AS tipo_cepa, vc.porcentaje
    FROM vino_cepa vc
    JOIN cepa c ON c.id_cepa = vc.id_cepa
    WHERE vc.cod_vino = $1
    ORDER BY c.nombre
  `;
  const composicionResult = await pool.query(composicionQuery, [codVino]);

  const maridajesQuery = `
    SELECT m.id_maridaje, m.nombre, m.temperatura_servicio
    FROM vino_maridaje vm
    JOIN maridaje m ON m.id_maridaje = vm.id_maridaje
    WHERE vm.cod_vino = $1
    ORDER BY m.nombre
  `;
  const maridajesResult = await pool.query(maridajesQuery, [codVino]);

  const stockQuery = `
    SELECT COALESCE(sd.cantidad, 0) AS stock_deposito,
           COALESCE(ss.stock_salas, 0) AS stock_salas,
           (COALESCE(sd.cantidad, 0) + COALESCE(ss.stock_salas, 0)) AS stock_total
    FROM vino v
    LEFT JOIN stock_deposito sd ON sd.cod_vino = v.cod_vino
    LEFT JOIN (
      SELECT cod_vino, SUM(cantidad) AS stock_salas
      FROM stock_sala
      GROUP BY cod_vino
    ) ss ON ss.cod_vino = v.cod_vino
    WHERE v.cod_vino = $1
  `;
  const stockResult = await pool.query(stockQuery, [codVino]);

  return {
    ...vinoResult.rows[0],
    composicion: composicionResult.rows,
    maridajes: maridajesResult.rows,
    stock: stockResult.rows[0],
  };
}

async function crearVino({ id_bodega, nombre, tipo, anada, volumen_ml, graduacion, precio, composicion }) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const vinoQuery = `
      INSERT INTO vino (id_bodega, nombre, tipo, anada, volumen_ml, graduacion, precio)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING cod_vino
    `;
    const vinoValues = [id_bodega, nombre, tipo, anada, volumen_ml, graduacion, precio];
    const vinoResult = await client.query(vinoQuery, vinoValues);
    const codVino = vinoResult.rows[0].cod_vino;

    if (composicion && composicion.length > 0) {
      const cepaQuery = `
        INSERT INTO vino_cepa (cod_vino, id_cepa, porcentaje)
        VALUES ($1, $2, $3)
      `;
      for (const c of composicion) {
        await client.query(cepaQuery, [codVino, c.id_cepa, c.porcentaje]);
      }
    }

    await client.query('COMMIT');
    return codVino;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function actualizarVino(codVino, { precio }) {
  const query = `UPDATE vino SET precio = $1 WHERE cod_vino = $2 RETURNING cod_vino`;
  const { rows } = await pool.query(query, [precio, codVino]);
  return rows[0];
}

async function eliminarVino(codVino) {
  const query = `DELETE FROM vino WHERE cod_vino = $1 RETURNING cod_vino`;
  const { rows } = await pool.query(query, [codVino]);
  return rows[0];
}

module.exports = {
  listarVinos,
  obtenerVino,
  crearVino,
  actualizarVino,
  eliminarVino,
};
