const express = require('express');
const router = express.Router();
const {
  getTopVinos,
  getVentasPorSala,
  getVinosSinStock,
  getTransportistaActivo,
  getTrazabilidad,
} = require('../controllers/reportesController');

router.get('/reportes/top-vinos', getTopVinos);
router.get('/reportes/ventas-por-sala', getVentasPorSala);
router.get('/reportes/vinos-sin-stock', getVinosSinStock);
router.get('/reportes/transportista-activo', getTransportistaActivo);
router.get('/reportes/trazabilidad/:cod', getTrazabilidad);

module.exports = router;
