const ingresosService = require('../db/ingresos');

async function crearIngreso(req, res) {
  const codIngreso = await ingresosService.crearIngreso(req.body);
  res.status(201).json({
    cod_ingreso: codIngreso,
    estado: 'en_confeccion',
    mensaje: 'Ingreso creado en estado en_confeccion',
  });
}

async function agregarRenglonIngreso(req, res) {
  const cod = parseInt(req.params.cod, 10);
  const renglon = await ingresosService.agregarRenglonIngreso(cod, req.body);
  res.status(201).json(renglon);
}

async function procesarIngreso(req, res) {
  const cod = parseInt(req.params.cod, 10);
  const resultado = await ingresosService.procesarIngreso(cod);
  res.json({ mensaje: 'Ingreso procesado (stock actualizado en deposito)', ...resultado });
}

module.exports = {
  crearIngreso,
  agregarRenglonIngreso,
  procesarIngreso,
};
