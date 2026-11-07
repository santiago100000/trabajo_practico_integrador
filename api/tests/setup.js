const pg = require('pg');

// Almacenar el Pool original
const OriginalPool = pg.Pool;

// Mock del cliente de pg (simula una conexión y consulta)
class MockClient {
  constructor() {
    this.connected = false;
    this.queryResults = [];
    this.queryIndex = 0;
  }

  async connect() {
    this.connected = true;
  }

  async query(text, params) {
    // Simular transacciones simples
    if (text === 'BEGIN') return { rows: [], rowCount: 0 };
    if (text === 'COMMIT') return { rows: [], rowCount: 0 };
    if (text === 'ROLLBACK') return { rows: [], rowCount: 0 };

    // Buscar un resultado predefinido para esta consulta
    const result = this.queryResults[this.queryIndex];
    this.queryIndex++;

    if (!result) {
      // Por defecto, retornar filas vacías
      return { rows: [], rowCount: 0 };
    }

    if (result.error) {
      throw result.error;
    }

    return result;
  }

  async release() {
    this.connected = false;
  }
}

// Mock del Pool de pg
class MockPool {
  constructor(config) {
    this.config = config;
    this.client = new MockClient();
    this.queryIndex = 0;
    this.queryResults = [];
  }

  async connect() {
    return this.client;
  }

  async query(text, params) {
    if (text === 'BEGIN') return { rows: [], rowCount: 0 };
    if (text === 'COMMIT') return { rows: [], rowCount: 0 };
    if (text === 'ROLLBACK') return { rows: [], rowCount: 0 };

    const result = this.queryResults[this.queryIndex];
    this.queryIndex++;

    if (!result) {
      return { rows: [], rowCount: 0 };
    }

    if (result.error) {
      throw result.error;
    }

    return result;
  }

  async end() {
    // No-op para tests
  }
}

// Reemplazar pg.Pool con el mock
pg.Pool = MockPool;

// Helper para configurar resultados de consultas mock
global.__setQueryResults = (results) => {
  // Se usa desde los tests para inyectar respuestas
};

module.exports = { MockPool, MockClient, OriginalPool };
