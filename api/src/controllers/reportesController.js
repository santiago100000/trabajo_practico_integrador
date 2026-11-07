const reportesService = require('../db/reportes');

async function getTopVinos(req, res) {
  const data = await reportesService.topVinos();
  res.json(data);
}

async function getVentasPorSala(req, res) {
  const data = await reportesService.ventasPorSala();
  res.json(data);
}

async function getVinosSinStock(req, res) {
  const id_sala = parseInt(req.query.id_sala, 10);
  if (!id_sala) {
    return res.status(400).json({ error: 'id_sala es requerido' });
  }
  const data = await reportesService.vinosSinStock({ id_sala });
  res.json(data);
}

async function getTransportistaActivo(req, res) {
  const data = await reportesService.transportistaActivo();
  res.json(data);
}

async function getTrazabilidad(req, res) {
  const cod = parseInt(req.params.cod, 10);
  const data = await reportesService.trazabilidad(cod);
  if (!data) {
    return res.status(404).json({ error: 'Vino no encontrado' });
  }
  res.json(data);
}

module.exports = {
  getTopVinos,
  getVentasPorSala,
  getVinosSinStock,
  getTransportistaActivo,
  getTrazabilidad,
};
