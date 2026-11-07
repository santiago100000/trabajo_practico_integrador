const vinosService = require('../db/vinos');

async function listarVinos(req, res) {
  const { page, limit, tipo, cepa, bodega, anada } = req.query;
  const vinos = await vinosService.listarVinos({
    page: parseInt(page, 10) || 1,
    limit: parseInt(limit, 10) || 10,
    tipo,
    cepa,
    bodega,
    anada: anada ? parseInt(anada, 10) : undefined,
  });
  res.json(vinos);
}

async function obtenerVino(req, res) {
  const cod = parseInt(req.params.cod, 10);
  const vino = await vinosService.obtenerVino(cod);
  if (!vino) {
    return res.status(404).json({ error: 'Vino no encontrado' });
  }
  res.json(vino);
}

async function crearVino(req, res) {
  const codVino = await vinosService.crearVino(req.body);
  res.status(201).json({ cod_vino: codVino, mensaje: 'Vino creado correctamente' });
}

async function actualizarVino(req, res) {
  const cod = parseInt(req.params.cod, 10);
  const resultado = await vinosService.actualizarVino(cod, req.body);
  if (!resultado) {
    return res.status(404).json({ error: 'Vino no encontrado' });
  }
  res.json({ mensaje: 'Precio actualizado. Auditoria de precio registrada en DB (RN-13)' });
}

async function eliminarVino(req, res) {
  const cod = parseInt(req.params.cod, 10);
  const resultado = await vinosService.eliminarVino(cod);
  if (!resultado) {
    return res.status(404).json({ error: 'Vino no encontrado' });
  }
  res.json({ mensaje: 'Vino eliminado' });
}

module.exports = {
  listarVinos,
  obtenerVino,
  crearVino,
  actualizarVino,
  eliminarVino,
};
