const express = require('express');
const cors = require('cors');
const errorHandler = require('./middlewares/errorHandler');

const saludRoutes = require('./routes/saludRoutes');
const vinosRoutes = require('./routes/vinosRoutes');
const salasRoutes = require('./routes/salasRoutes');
const clientesRoutes = require('./routes/clientesRoutes');
const comprobantesRoutes = require('./routes/comprobantesRoutes');
const transferenciasRoutes = require('./routes/transferenciasRoutes');
const ingresosRoutes = require('./routes/ingresosRoutes');
const reportesRoutes = require('./routes/reportesRoutes');

const app = express();

app.use(cors());
app.use(express.json());

app.use(saludRoutes);
app.use(vinosRoutes);
app.use(salasRoutes);
app.use(clientesRoutes);
app.use(comprobantesRoutes);
app.use(transferenciasRoutes);
app.use(ingresosRoutes);
app.use(reportesRoutes);

app.use(errorHandler);

module.exports = app;
