const bodegasService = require('../db/bodegas');

async function listarBodegas(req, res) {
  const bodegas = await bodegasService.listarBodegas();
  res.json(bodegas);
}

module.exports = { listarBodegas };
