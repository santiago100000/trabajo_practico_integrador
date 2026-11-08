const express = require('express');
const router = express.Router();
const { listarCepas } = require('../controllers/cepasController');

router.get('/cepa', listarCepas);

module.exports = router;
