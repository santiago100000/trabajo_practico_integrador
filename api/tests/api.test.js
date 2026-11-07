const request = require('supertest');

let mockPool;

jest.mock('../src/config/db', () => {
  const { MockPool } = require('./helpers/mockPool');
  const { crearErrorSqlstate } = require('./helpers/mockPool');
  mockPool = new MockPool();
  return { default: mockPool, __esModule: true };
});

const app = require('../src/app');

beforeEach(() => {
  mockPool.reset();
});

describe('ETAPA 6 - API REST Bodegas del Atuel', () => {
  // 1. Salud
  test('GET /salud responde 200 y conectividad OK', async () => {
    mockPool.responses = [
      { rows: [{ resultado: 1 }] },
    ];
    const res = await request(app).get('/salud');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  // 2. Listado de vinos con paginación
  test('GET /vinos responde 200 con listado paginado', async () => {
    mockPool.responses = [
      {
        rows: [
          {
            cod_vino: 1,
            nombre: 'Tempranillo Reserva',
            tipo: 'tinto',
            anada: 2018,
            volumen_ml: 750,
            graduacion: 14.5,
            precio: 2500.00,
            bodega: 'Bodega del Atuel',
          },
        ],
      },
    ];
    const res = await request(app).get('/vinos?page=1&limit=10');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body[0].cod_vino).toBe(1);
  });

  // 3. Detalle de vino por código
  test('GET /vinos/:cod responde 200 con detalle completo', async () => {
    mockPool.responses = [
      { rows: [{ cod_vino: 1, nombre: 'Malbec', tipo: 'tinto', anada: 2019, volumen_ml: 750, graduacion: 14.0, precio: 3000.00, bodega: 'Bodega X' }] },
      { rows: [{ id_cepa: 1, cepa: 'Malbec', tipo_cepa: 'tinta', porcentaje: 100 }] },
      { rows: [{ id_maridaje: 1, nombre: 'Carnes rojas', temperatura_servicio: 18.0 }] },
      { rows: [{ stock_deposito: 50, stock_salas: 30, stock_total: 80 }] },
    ];
    const res = await request(app).get('/vinos/1');
    expect(res.status).toBe(200);
    expect(res.body.cod_vino).toBe(1);
    expect(res.body.composicion).toBeDefined();
    expect(res.body.maridajes).toBeDefined();
    expect(res.body.stock).toBeDefined();
  });

  // 4. Vino no encontrado -> 404
  test('GET /vinos/:cod inexistente responde 404', async () => {
    mockPool.responses = [
      { rows: [] },
    ];
    const res = await request(app).get('/vinos/99999');
    expect(res.status).toBe(404);
    expect(res.body.error).toBe('Vino no encontrado');
  });

  // 5. Crear vino exitoso -> 201 (transacción)
  test('POST /vinos crea vino y composicion en transaccion -> 201', async () => {
    mockPool.responses = [
      { rows: [{ cod_vino: 10 }] }, // INSERT vino RETURNING
    ];
    const res = await request(app).post('/vinos').send({
      id_bodega: 1,
      nombre: 'Vino Test',
      tipo: 'tinto',
      anada: 2020,
      volumen_ml: 750,
      graduacion: 13.5,
      precio: 2000.00,
      composicion: [{ id_cepa: 1, porcentaje: 100 }],
    });
    expect(res.status).toBe(201);
    expect(res.body.cod_vino).toBe(10);
  });

  // 6. Precio negativo -> 422 (CHECK violado en DB)
  test('POST /vinos con precio negativo -> 422 CHECK violado', async () => {
    const errorCheck = {
      code: '23514',
      message: 'nueva fila para relacion "vino" viola la restriccion de check "chk_vino_precio_positivo"',
      detail: 'Falla en la restriccion de check.',
    };
    mockPool.responses = [
      { error: Object.assign(new Error(errorCheck.message), { code: errorCheck.code, detail: errorCheck.detail }) },
    ];
    const res = await request(app).post('/vinos').send({
      id_bodega: 1,
      nombre: 'Vino Invalido',
      tipo: 'tinto',
      anada: 2020,
      volumen_ml: 750,
      graduacion: 13.5,
      precio: -100,
    });
    expect(res.status).toBe(422);
    expect(res.body.codigo).toBe('CHECK_VIOLATED');
  });

  // 7. Venta con stock insuficiente -> 409 (trigger RN-09, P0001)
  test('POST /comprobantes con stock insuficiente -> 409 regla de negocio', async () => {
    const errorStock = {
      code: 'P0001',
      message: 'Stock insuficiente en la sala 1 para el vino 5 (solicitado: 100, disponible: 5). No se puede vender mas de lo que hay en stock (RN-09).',
    };
    mockPool.responses = [
      { rows: [{ nro_comprobante: 50 }] }, // INSERT comprobante OK
      { error: Object.assign(new Error(errorStock.message), { code: errorStock.code, detail: errorStock.message }) }, // INSERT renglon falla
    ];
    const res = await request(app).post('/comprobantes').send({
      id_cliente: 1,
      id_sala: 1,
      renglones: [{ cod_vino: 5, cantidad: 100, precio_unitario: 1000, descuento_aplicado: 0 }],
    });
    expect(res.status).toBe(409);
    expect(res.body.codigo).toBe('PLPGSQL_RAISE');
    expect(res.body.mensaje).toContain('Stock insuficiente');
  });

  // 8. Transferencia terminar cuando no esta en confeccion -> 409
  test('POST /transferencias/:nro/terminar cuando no esta en confeccion -> 409', async () => {
    mockPool.responses = [
      { rows: [], rowCount: 0 }, // UPDATE no afecta filas (estado no es en_confeccion)
    ];
    const res = await request(app).post('/transferencias/5/terminar');
    expect(res.status).toBe(409);
    expect(res.body.error).toBe('conflicto');
  });

  // 9. Crear cliente exitoso -> 201
  test('POST /clientes crea cliente con subtipo -> 201', async () => {
    mockPool.responses = [
      { rows: [{ id_cliente: 100 }] }, // INSERT cliente
    ];
    const res = await request(app).post('/clientes').send({
      tipo_cliente: 'socio',
      nombre_razon_social: 'Juan Perez',
      tipo_doc: 'DNI',
      nro_doc: '12345678',
      direccion: 'Calle Falsa 123',
      id_localidad: 1,
      fecha_alta: '2024-01-01',
      email: 'juan@test.com',
      telefono: '2664123456',
      subtipo: 'socio',
    });
    expect(res.status).toBe(201);
    expect(res.body.id_cliente).toBe(100);
  });

  // 10. Reporte top vinos -> 200
  test('GET /reportes/top-vinos responde 200 con ranking', async () => {
    mockPool.responses = [
      {
        rows: [
          { cod_vino: 1, nombre: 'Malbec', tipo: 'tinto', anada: 2019, botellas_vendidas: 1500 },
          { cod_vino: 2, nombre: 'Cabernet', tipo: 'tinto', anada: 2018, botellas_vendidas: 1200 },
        ],
      },
    ];
    const res = await request(app).get('/reportes/top-vinos');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBe(2);
    expect(res.body[0].botellas_vendidas).toBe(1500);
  });

  // 11. Trazabilidad de vino -> 200
  test('GET /reportes/trazabilidad/:cod responde 200 con ficha completa', async () => {
    mockPool.responses = [
      {
        rows: [{
          cod_vino: 1,
          nombre: 'Malbec 2019',
          bodega: 'Bodega del Atuel',
          cepas: 'Malbec (100%)',
          maridajes: 'Carnes rojas',
          stock_total: 100,
        }],
      },
    ];
    const res = await request(app).get('/reportes/trazabilidad/1');
    expect(res.status).toBe(200);
    expect(res.body.cod_vino).toBe(1);
    expect(res.body.cepas).toBeDefined();
  });

  // 12. Vinos sin stock -> 200
  test('GET /reportes/vinos-sin-stock responde 200', async () => {
    mockPool.responses = [
      {
        rows: [
          { cod_vino: 3, nombre: 'Chardonnay', tipo: 'blanco', anada: 2020 },
        ],
      },
    ];
    const res = await request(app).get('/reportes/vinos-sin-stock?id_sala=1');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });
});
