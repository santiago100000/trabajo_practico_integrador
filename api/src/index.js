const app = require('./app');

const PORT = parseInt(process.env.PORT, 10) || 8001;

const server = app.listen(PORT, () => {
  console.log(`API Bodegas del Atuel escuchando en puerto ${PORT}`);
});

process.on('SIGTERM', () => {
  console.log('SIGTERM recibido, cerrando servidor...');
  server.close(() => {
    console.log('Servidor cerrado');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT recibido, cerrando servidor...');
  server.close(() => {
    console.log('Servidor cerrado');
    process.exit(0);
  });
});
