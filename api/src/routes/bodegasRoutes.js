const express = require('express');
const router = express.Router();
const { listarBodegas } = require('../controllers/bodegasController');

router.get('/bodegas', listarBodegas);

module.exports = router;
