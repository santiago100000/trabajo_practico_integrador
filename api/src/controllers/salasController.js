const salasService = require('../db/salas');

async function listarSalas(req, res) {
  const salas = await salasService.listarSalas();
  res.json(salas);
}

module.exports = { listarSalas };
