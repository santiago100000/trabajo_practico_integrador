const { pool } = require('./index');

async function listarBodegas() {
  const query = `SELECT id_bodega, cuit, razon_social, domicilio FROM bodega ORDER BY razon_social`;
  const { rows } = await pool.query(query);
  return rows;
}

module.exports = { listarBodegas };
