const clientesService = require('../db/clientes');

async function listarClientes(req, res) {
  const clientes = await clientesService.listarClientes();
  res.json(clientes);
}

async function obtenerCliente(req, res) {
  const id = parseInt(req.params.id, 10);
  const cliente = await clientesService.obtenerCliente(id);
  if (!cliente) {
    return res.status(404).json({ error: 'Cliente no encontrado' });
  }
  res.json(cliente);
}

async function crearCliente(req, res) {
  const idCliente = await clientesService.crearCliente(req.body);
  res.status(201).json({ id_cliente: idCliente, mensaje: 'Cliente creado correctamente' });
}

async function actualizarCliente(req, res) {
  const id = parseInt(req.params.id, 10);
  const resultado = await clientesService.actualizarCliente(id, req.body);
  if (!resultado) {
    return res.status(404).json({ error: 'Cliente no encontrado' });
  }
  res.json({ mensaje: 'Cliente actualizado correctamente' });
}

async function eliminarCliente(req, res) {
  const id = parseInt(req.params.id, 10);
  const resultado = await clientesService.eliminarCliente(id);
  if (!resultado) {
    return res.status(404).json({ error: 'Cliente no encontrado' });
  }
  res.json({ mensaje: 'Cliente eliminado correctamente' });
}

module.exports = {
  listarClientes,
  obtenerCliente,
  crearCliente,
  actualizarCliente,
  eliminarCliente,
};
