const express = require('express');
const router = express.Router();
const { crearComprobante, obtenerComprobante } = require('../controllers/comprobantesController');

router.post('/comprobantes', crearComprobante);
router.get('/comprobantes/:nro', obtenerComprobante);

module.exports = router;
