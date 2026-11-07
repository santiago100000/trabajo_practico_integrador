const express = require('express');
const router = express.Router();
const {
  crearTransferencia,
  agregarRenglonTransferencia,
  terminarTransferencia,
  procesarTransferencia,
} = require('../controllers/transferenciasController');

router.post('/transferencias', crearTransferencia);
router.post('/transferencias/:nro/renglones', agregarRenglonTransferencia);
router.post('/transferencias/:nro/terminar', terminarTransferencia);
router.post('/transferencias/:nro/procesar', procesarTransferencia);

module.exports = router;
