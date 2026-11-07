const express = require('express');
const errorHandler = require('./middlewares/errorHandler');

const saludRoutes = require('./routes/saludRoutes');
const vinosRoutes = require('./routes/vinosRoutes');
const clientesRoutes = require('./routes/clientesRoutes');
const comprobantesRoutes = require('./routes/comprobantesRoutes');
const transferenciasRoutes = require('./routes/transferenciasRoutes');
const ingresosRoutes = require('./routes/ingresosRoutes');
const reportesRoutes = require('./routes/reportesRoutes');

const app = express();

app.use(express.json());

app.use(saludRoutes);
app.use(vinosRoutes);
app.use(clientesRoutes);
app.use(comprobantesRoutes);
app.use(transferenciasRoutes);
app.use(ingresosRoutes);
app.use(reportesRoutes);

app.use(errorHandler);

module.exports = app;
