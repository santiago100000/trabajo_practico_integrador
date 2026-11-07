const transferenciasService = require('../db/transferencias');

async function crearTransferencia(req, res) {
  const nroSolicitud = await transferenciasService.crearTransferencia(req.body);
  res.status(201).json({
    nro_solicitud: nroSolicitud,
    estado: 'en_confeccion',
    mensaje: 'Transferencia creada en estado en_confeccion (RN-11)',
  });
}

async function agregarRenglonTransferencia(req, res) {
  const nro = parseInt(req.params.nro, 10);
  const renglon = await transferenciasService.agregarRenglonTransferencia(nro, req.body);
  res.status(201).json(renglon);
}

async function terminarTransferencia(req, res) {
  const nro = parseInt(req.params.nro, 10);
  const resultado = await transferenciasService.terminarTransferencia(nro);
  if (!resultado) {
    return res.status(409).json({ error: 'La transferencia no esta en estado en_confeccion o no existe' });
  }
  res.json({ mensaje: 'Transferencia terminada', nro_solicitud: nro, estado: 'terminado' });
}

async function procesarTransferencia(req, res) {
  const nro = parseInt(req.params.nro, 10);
  const resultado = await transferenciasService.procesarTransferencia(nro);
  res.json({ mensaje: 'Transferencia procesada (stock movido a sala)', ...resultado });
}

module.exports = {
  crearTransferencia,
  agregarRenglonTransferencia,
  terminarTransferencia,
  procesarTransferencia,
};
