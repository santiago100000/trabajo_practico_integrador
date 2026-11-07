const { pool } = require('./index');

async function listarSalas() {
  const query = `
    SELECT s.id_sala, s.calle, s.numero, l.nombre AS localidad
    FROM sala_venta s
    JOIN localidad l ON l.id_localidad = s.id_localidad
    ORDER BY s.id_sala
  `;
  const { rows } = await pool.query(query);
  return rows;
}

module.exports = { listarSalas };
