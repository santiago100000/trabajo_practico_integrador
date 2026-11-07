const express = require('express');
const router = express.Router();
const { getSalud } = require('../controllers/saludController');

router.get('/salud', getSalud);

module.exports = router;
