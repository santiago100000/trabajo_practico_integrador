const { pool } = require('./index');

async function listarCepas() {
  const query = `SELECT id_cepa, nombre, tipo FROM cepa ORDER BY nombre`;
  const { rows } = await pool.query(query);
  return rows;
}

module.exports = { listarCepas };
