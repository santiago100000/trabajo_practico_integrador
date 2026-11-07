const { pool } = require('./index');

async function crearTransferencia({ id_sala, observaciones }) {
  const query = `
    INSERT INTO transferencia (id_sala, fecha_confeccion, estado, observaciones)
    VALUES ($1, CURRENT_DATE, 'en_confeccion', $2)
    RETURNING nro_solicitud
  `;
  const { rows } = await pool.query(query, [id_sala, observaciones || null]);
  return rows[0].nro_solicitud;
}

async function agregarRenglonTransferencia(nroSolicitud, { cod_vino, cantidad }) {
  const query = `
    INSERT INTO renglon_transferencia (nro_solicitud, cod_vino, cantidad)
    VALUES ($1, $2, $3)
    RETURNING nro_solicitud, cod_vino, cantidad
  `;
  const { rows } = await pool.query(query, [nroSolicitud, cod_vino, cantidad]);
  return rows[0];
}

async function terminarTransferencia(nroSolicitud) {
  const query = `
    UPDATE transferencia
    SET estado = 'terminado'
    WHERE nro_solicitud = $1 AND estado = 'en_confeccion'
    RETURNING nro_solicitud, estado
  `;
  const { rows } = await pool.query(query, [nroSolicitud]);
  return rows[0];
}

async function procesarTransferencia(nroSolicitud) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('CALL sp_procesar_transferencia($1)', [nroSolicitud]);
    await client.query('COMMIT');
    return { nro_solicitud: nroSolicitud, estado: 'procesado' };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = {
  crearTransferencia,
  agregarRenglonTransferencia,
  terminarTransferencia,
  procesarTransferencia,
};
