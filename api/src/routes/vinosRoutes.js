const express = require('express');
const router = express.Router();
const {
  listarVinos,
  obtenerVino,
  crearVino,
  actualizarVino,
  eliminarVino,
} = require('../controllers/vinosController');

router.get('/vinos', listarVinos);
router.get('/vinos/:cod', obtenerVino);
router.post('/vinos', crearVino);
router.put('/vinos/:cod', actualizarVino);
router.delete('/vinos/:cod', eliminarVino);

module.exports = router;
