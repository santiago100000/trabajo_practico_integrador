const express = require('express');
const router = express.Router();
const {
  listarClientes,
  obtenerCliente,
  crearCliente,
  actualizarCliente,
  eliminarCliente,
} = require('../controllers/clientesController');

router.get('/clientes', listarClientes);
router.get('/clientes/:id', obtenerCliente);
router.post('/clientes', crearCliente);
router.put('/clientes/:id', actualizarCliente);
router.delete('/clientes/:id', eliminarCliente);

module.exports = router;
