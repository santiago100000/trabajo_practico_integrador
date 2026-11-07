function mapearErrorSQLSTATE(err) {
  const codigo = err.code;
  const mensaje = err.message || 'Error interno del servidor';
  const detalle = err.detail || err.hint || undefined;

  switch (codigo) {
    case '23505': // UNIQUE violado
      return {
        status: 409,
        body: {
          error: 'conflicto',
          codigo: 'UNIQUE_VIOLATED',
          mensaje: 'Ya existe un registro con ese valor único',
          detalle,
        },
      };
    case '23503': // FOREIGN KEY violada
      return {
        status: 409,
        body: {
          error: 'conflicto',
          codigo: 'FOREIGN_KEY_VIOLATED',
          mensaje: 'Referencia inválida: el registro relacionado no existe o tiene restricciones',
          detalle,
        },
      };
    case '23514': // CHECK violado
      return {
        status: 422,
        body: {
          error: 'validacion',
          codigo: 'CHECK_VIOLATED',
          mensaje: 'Regla de negocio violada (RN-XX): ' + mensaje,
          detalle,
        },
      };
    case '23502': // NOT NULL violado
      return {
        status: 422,
        body: {
          error: 'validacion',
          codigo: 'NOT_NULL_VIOLATED',
          mensaje: 'Campo requerido faltante',
          detalle,
        },
      };
    case 'P0001': // RAISE EXCEPTION desde trigger o procedimiento
      return {
        status: 409,
        body: {
          error: 'regla_negocio',
          codigo: 'PLPGSQL_RAISE',
          mensaje: mensaje,
          detalle,
        },
      };
    case '22P02': // Formato/tipo inválido
      return {
        status: 400,
        body: {
          error: 'solicitud_malformada',
          codigo: 'INVALID_TEXT_REPRESENTATION',
          mensaje: 'Formato o tipo de dato inválido',
          detalle,
        },
      };
    case '40001': // Serialization failure
    case '40P01': // Deadlock detected
      return {
        status: 503,
        body: {
          error: 'servicio_no_disponible',
          codigo: codigo,
          mensaje: 'Conflicto de concurrencia o interbloqueo. Reintentar la operación',
        },
        headers: { 'Retry-After': '2' },
      };
    default:
      return {
        status: 500,
        body: {
          error: 'error_interno',
          codigo: codigo || 'UNKNOWN',
          mensaje: 'Error interno del servidor',
          detalle: process.env.NODE_ENV === 'development' ? detalle : undefined,
        },
      };
  }
}

function errorHandler(err, req, res, next) {
  const mapeo = mapearErrorSQLSTATE(err);

  if (mapeo.headers) {
    res.set(mapeo.headers);
  }

  res.status(mapeo.status).json(mapeo.body);
}

module.exports = errorHandler;
