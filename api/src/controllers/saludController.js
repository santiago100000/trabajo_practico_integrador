const saludService = require('../db/salud');

async function getSalud(req, res) {
  const resultado = await saludService.checkSalud();
  res.json({ status: 'ok', db: resultado });
}

module.exports = { getSalud };
