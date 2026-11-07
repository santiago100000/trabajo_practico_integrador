const express = require('express');
const router = express.Router();
const { crearIngreso, agregarRenglonIngreso, procesarIngreso } = require('../controllers/ingresosController');

router.post('/ingresos', crearIngreso);
router.post('/ingresos/:cod/renglones', agregarRenglonIngreso);
router.post('/ingresos/:cod/procesar', procesarIngreso);

module.exports = router;
