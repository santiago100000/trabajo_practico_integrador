const { pool } = require('./index');

async function crearIngreso({ fecha, cod_transportista, id_bodega, observaciones }) {
  const query = `
    INSERT INTO ingreso (fecha, estado, cod_transportista, id_bodega, observaciones)
    VALUES ($1, 'en_confeccion', $2, $3, $4)
    RETURNING cod_ingreso
  `;
  const { rows } = await pool.query(query, [fecha, cod_transportista, id_bodega, observaciones || null]);
  return rows[0].cod_ingreso;
}

async function agregarRenglonIngreso(codIngreso, { cod_vino, cantidad }) {
  const query = `
    INSERT INTO renglon_ingreso (cod_ingreso, cod_vino, cantidad)
    VALUES ($1, $2, $3)
    RETURNING cod_ingreso, cod_vino, cantidad
  `;
  const { rows } = await pool.query(query, [codIngreso, cod_vino, cantidad]);
  return rows[0];
}

async function procesarIngreso(codIngreso) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('CALL sp_procesar_ingreso($1)', [codIngreso]);
    await client.query('COMMIT');
    return { cod_ingreso: codIngreso, estado: 'procesado' };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = {
  crearIngreso,
  agregarRenglonIngreso,
  procesarIngreso,
};
