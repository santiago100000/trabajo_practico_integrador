const { Pool } = require('pg');
require('dotenv').config({ path: require('path').resolve(__dirname, '../../../.env') });

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT, 10) || 5432,
  user: process.env.DB_USER || 'app_rw',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'bodegas',
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on('connect', () => {
  // No-op: rol app_rw con privilegios limitados, todo se resuelve en SQL
});

pool.on('error', (err) => {
  console.error('Error inesperado en el pool de pg:', err);
});

module.exports = pool;
