const { pool } = require('./index');

async function checkSalud() {
  const { rows } = await pool.query('SELECT 1 AS resultado');
  return rows[0];
}

module.exports = { checkSalud };
