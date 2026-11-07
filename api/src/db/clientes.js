const { pool } = require('./index');

async function listarClientes() {
  const query = `
    SELECT c.id_cliente, c.tipo_cliente, c.nombre_razon_social, c.tipo_doc, c.nro_doc,
           c.direccion, c.id_localidad, c.fecha_alta, c.descuento, c.email, c.telefono,
           s.id_cliente AS es_socio,
           d.id_cliente AS es_distribuidor, d.zona_cobertura, d.nro_habilitacion,
           e.id_cliente AS es_exportador, e.pais_destino
    FROM cliente c
    LEFT JOIN socio s ON s.id_cliente = c.id_cliente
    LEFT JOIN distribuidor d ON d.id_cliente = c.id_cliente
    LEFT JOIN exportador e ON e.id_cliente = c.id_cliente
    ORDER BY c.id_cliente
  `;
  const { rows } = await pool.query(query);
  return rows;
}

async function obtenerCliente(idCliente) {
  const query = `
    SELECT c.id_cliente, c.tipo_cliente, c.nombre_razon_social, c.tipo_doc, c.nro_doc,
           c.direccion, c.id_localidad, c.fecha_alta, c.descuento, c.email, c.telefono,
           s.id_cliente AS es_socio,
           d.id_cliente AS es_distribuidor, d.zona_cobertura, d.nro_habilitacion,
           e.id_cliente AS es_exportador, e.pais_destino
    FROM cliente c
    LEFT JOIN socio s ON s.id_cliente = c.id_cliente
    LEFT JOIN distribuidor d ON d.id_cliente = c.id_cliente
    LEFT JOIN exportador e ON e.id_cliente = c.id_cliente
    WHERE c.id_cliente = $1
  `;
  const { rows } = await pool.query(query, [idCliente]);
  return rows[0] || null;
}

async function crearCliente({ tipo_cliente, nombre_razon_social, tipo_doc, nro_doc,
                              direccion, id_localidad, fecha_alta, email, telefono,
                              subtipo, zona_cobertura, nro_habilitacion, pais_destino }) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const clienteQuery = `
      INSERT INTO cliente (tipo_cliente, nombre_razon_social, tipo_doc, nro_doc, direccion,
                           id_localidad, fecha_alta, email, telefono)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING id_cliente
    `;
    const clienteValues = [tipo_cliente, nombre_razon_social, tipo_doc, nro_doc,
                           direccion, id_localidad, fecha_alta, email, telefono];
    const clienteResult = await client.query(clienteQuery, clienteValues);
    const idCliente = clienteResult.rows[0].id_cliente;

    if (subtipo === 'socio') {
      await client.query('INSERT INTO socio (id_cliente) VALUES ($1)', [idCliente]);
    } else if (subtipo === 'distribuidor') {
      await client.query(
        'INSERT INTO distribuidor (id_cliente, zona_cobertura, nro_habilitacion) VALUES ($1, $2, $3)',
        [idCliente, zona_cobertura, nro_habilitacion]
      );
    } else if (subtipo === 'exportador') {
      await client.query(
        'INSERT INTO exportador (id_cliente, pais_destino) VALUES ($1, $2)',
        [idCliente, pais_destino]
      );
    }

    await client.query('COMMIT');
    return idCliente;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function actualizarCliente(idCliente, { nombre_razon_social, tipo_doc, nro_doc,
                                              direccion, id_localidad, email, telefono,
                                              subtipo, zona_cobertura, nro_habilitacion, pais_destino }) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query(
      `UPDATE cliente SET nombre_razon_social = $1, tipo_doc = $2, nro_doc = $3,
                           direccion = $4, id_localidad = $5, email = $6, telefono = $7
       WHERE id_cliente = $8`,
      [nombre_razon_social, tipo_doc, nro_doc, direccion, id_localidad, email, telefono, idCliente]
    );

    // Eliminar subtipo existente y recrear según el nuevo
    await client.query('DELETE FROM socio WHERE id_cliente = $1', [idCliente]);
    await client.query('DELETE FROM distribuidor WHERE id_cliente = $1', [idCliente]);
    await client.query('DELETE FROM exportador WHERE id_cliente = $1', [idCliente]);

    if (subtipo === 'socio') {
      await client.query('INSERT INTO socio (id_cliente) VALUES ($1)', [idCliente]);
    } else if (subtipo === 'distribuidor') {
      await client.query(
        'INSERT INTO distribuidor (id_cliente, zona_cobertura, nro_habilitacion) VALUES ($1, $2, $3)',
        [idCliente, zona_cobertura, nro_habilitacion]
      );
    } else if (subtipo === 'exportador') {
      await client.query(
        'INSERT INTO exportador (id_cliente, pais_destino) VALUES ($1, $2)',
        [idCliente, pais_destino]
      );
    }

    await client.query('COMMIT');
    return idCliente;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function eliminarCliente(idCliente) {
  const query = `DELETE FROM cliente WHERE id_cliente = $1 RETURNING id_cliente`;
  const { rows } = await pool.query(query, [idCliente]);
  return rows[0];
}

module.exports = {
  listarClientes,
  obtenerCliente,
  crearCliente,
  actualizarCliente,
  eliminarCliente,
};
