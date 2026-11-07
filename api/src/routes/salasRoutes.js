const express = require('express');
const router = express.Router();
const { listarSalas } = require('../controllers/salasController');

router.get('/salas', listarSalas);

module.exports = router;
