const cepasService = require('../db/cepas');

async function listarCepas(req, res) {
  const cepas = await cepasService.listarCepas();
  res.json(cepas);
}

module.exports = { listarCepas };
