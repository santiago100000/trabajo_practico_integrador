const comprobantesService = require('../db/comprobantes');

async function crearComprobante(req, res) {
  const nroComprobante = await comprobantesService.crearComprobante(req.body);
  res.status(201).json({
    nro_comprobante: nroComprobante,
    mensaje: 'Comprobante creado. Totales y stock calculados por triggers en DB (RN-08, RN-09)',
  });
}

async function obtenerComprobante(req, res) {
  const nro = parseInt(req.params.nro, 10);
  const comprobante = await comprobantesService.obtenerComprobante(nro);
  if (!comprobante) {
    return res.status(404).json({ error: 'Comprobante no encontrado' });
  }
  res.json(comprobante);
}

module.exports = {
  crearComprobante,
  obtenerComprobante,
};
