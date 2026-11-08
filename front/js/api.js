// ============================================================================
// Capa de servicios — Bodegas del Atuel Frontend
// Concentra TODAS las llamadas a la API REST (Etapa 6)
// URL base configurable en js/config.js
// ============================================================================

const API = (() => {
  /**
   * Realiza una petición fetch a la API.
   * @param {string} path - Ruta del endpoint (ej. '/vinos')
   * @param {object} options - Opciones de fetch (method, body, headers)
   * @returns {Promise<any>} Datos de la respuesta o lanza error con info de la API
   */
  async function request(path, options = {}) {
    const url = `${CONFIG.API_BASE_URL}${path}`;
    const headers = {
      'Content-Type': 'application/json',
      ...options.headers,
    };

    const config = {
      ...options,
      headers,
    };

    // Intentar hasta 3 veces con backoff exponencial ante errores de red
    let ultimoError;
    for (let intento = 1; intento <= 3; intento++) {
      try {
        const response = await fetch(url, config);

        // Intentar leer el cuerpo como JSON (la API devuelve JSON en errores también)
        let data;
        const contentType = response.headers.get('content-type');
        if (contentType && contentType.includes('application/json')) {
          data = await response.json();
        } else {
          data = await response.text();
        }

        if (!response.ok) {
          // La API ya devuelve { error, codigo, mensaje, detalle } con el status correcto
          const err = new Error(data.mensaje || data || 'Error en la petición');
          err.status = response.status;
          err.codigo = data.codigo;
          err.detalle = data.detalle;
          err.body = data;
          throw err;
        }

        return data;
      } catch (err) {
        ultimoError = err;

        // Si es un error de HTTP (4xx, 5xx) de la API, no reintentar
        if (err.status) {
          throw err;
        }

        // Error de red: reintentar salvo que sea el último intento
        const esErrorRed = err.type === 'system'
          || err.code === 'ECONNREFUSED'
          || err.code === 'ENOTFOUND'
          || err.code === 'EHOSTUNREACH'
          || err.message === 'Failed to fetch'
          || err.message.includes('network')
          || err.message.includes('conexión');

        if (!esErrorRed || intento === 3) {
          const netErr = new Error('No se puede conectar con la API. Verificá que el servidor esté corriendo en http://localhost:8001');
          netErr.status = 0;
          netErr.codigo = 'CONNECTION_ERROR';
          throw netErr;
        }

        // Esperar antes del siguiente intento (backoff: 500ms, 1000ms)
        await new Promise(r => setTimeout(r, intento * 500));
      }
    }

    throw ultimoError;
  }

  // ============================================================================
  // FORMATEO DE ERRORES DE REGLAS DE NEGOCIO
  // ============================================================================
  /**
   * Dado un error de la API, devuelve un mensaje amigable para el usuario
   * con la regla de negocio asociada entre paréntesis (RN-XX).
   * @param {Error} err - Error lanzado por request()
   * @returns {string} Mensaje listo para mostrar en pantalla
   */
  function formatearErrorParaUsuario(err) {
    // Si el mensaje ya trae "(RN-XX)" de los triggers de la BD, usarlo tal cual
    const matchRN = err.mensaje && err.mensaje.match(/\(RN-\d+\)/);
    if (matchRN) {
      return err.mensaje;
    }

    // Mapeo por código SQLSTATE y contexto
    const codigo = err.codigo;
    const mensaje = err.mensaje || err.message || '';
    const detalle = err.detalle || '';

    // P0001: excepción PL/pgSQL desde trigger o procedimiento (ya trae RN en el mensaje)
    if (codigo === 'P0001') {
      // Buscar si el mensaje ya menciona una regla
      if (mensaje.match(/RN-\d+/)) {
        return mensaje;
      }
      // Si no, intentar inferir por palabras clave
      const m = mensaje.toLowerCase();
      if (m.includes('stock insuficiente') || m.includes('no se puede vender')) {
        return mensaje + ' (RN-09)';
      }
      if (m.includes('no está en estado terminado') || m.includes('no está en confección')) {
        return mensaje + ' (RN-10 / RN-11)';
      }
      if (m.includes('no se pueden modificar renglones')) {
        return mensaje + ' (RN-12)';
      }
      if (m.includes('fecha de confección')) {
        return mensaje + ' (RN-11)';
      }
      if (m.includes('porcentajes')) {
        return mensaje + ' (RN-05)';
      }
      return mensaje;
    }

    // 23503: FOREIGN KEY violada
    if (codigo === '23503') {
      const m = (mensaje + ' ' + detalle).toLowerCase();
      if (m.includes('comprobante') || m.includes('cliente')) {
        return 'No se puede eliminar porque tiene compras asociadas (RN-14)';
      }
      if (m.includes('bodega') || m.includes('vino') || m.includes('transportista')) {
        return 'No se puede eliminar porque tiene movimientos asociados (RN-14)';
      }
      return 'Referencia inválida: el registro relacionado no existe o tiene restricciones';
    }

    // 23514: CHECK violado
    if (codigo === '23514') {
      const m = (mensaje + ' ' + detalle).toLowerCase();
      if (m.includes('precio') && m.includes('mayor que cero')) {
        return 'El precio debe ser mayor que cero (RN-01)';
      }
      if (m.includes('graduación') || m.includes('graduacion')) {
        return 'La graduación alcohólica debe estar entre 5 y 20 (RN-15)';
      }
      if (m.includes('cantidad') && m.includes('negativa')) {
        return 'La cantidad debe ser positiva (RN-15)';
      }
      if (m.includes('descuento') && m.includes('rango')) {
        return 'El descuento debe estar entre 0 y 100 (RN-06)';
      }
      if (m.includes('fecha_vencimiento') || m.includes('vencimiento') && m.includes('emisión')) {
        return 'La fecha de vencimiento debe ser posterior a la de emisión (RN-07)';
      }
      if (m.includes('superficie')) {
        return 'La superficie debe ser positiva (RN-15)';
      }
      if (m.includes('kilos')) {
        return 'Los kilos cosechados deben ser positivos (RN-15)';
      }
      if (m.includes('salario')) {
        return 'El salario debe ser positivo (RN-15)';
      }
      return 'Regla de negocio violada (consultar detalles)';
    }

    // 23505: UNIQUE violado
    if (codigo === '23505') {
      const m = (mensaje + ' ' + detalle).toLowerCase();
      if (m.includes('vino') && (m.includes('nombre') || m.includes('anada') || m.includes('volumen'))) {
        return 'Ya existe un vino con ese nombre, añada y volumen (RN-01)';
      }
      if (m.includes('lote') || m.includes('parcela') || m.includes('campaña')) {
        return 'Ya existe una cosecha para esa parcela y campaña (RN-04)';
      }
      if (m.includes('cliente') || m.includes('tipo_doc') || m.includes('nro_doc')) {
        return 'Ya existe un cliente con ese tipo y número de documento';
      }
      if (m.includes('cuit')) {
        return 'Ya existe una entidad con ese CUIT';
      }
      if (m.includes('maridaje')) {
        return 'Ya existe un maridaje con ese nombre';
      }
      return 'Ya existe un registro con ese valor único';
    }

    // 23502: NOT NULL violado
    if (codigo === '23502') {
      return 'Campo requerido faltante';
    }

    // 22P02: formato inválido
    if (codigo === '22P02') {
      return 'Formato o tipo de dato inválido';
    }

    // 40001 / 40P01: deadlock o serialización
    if (codigo === '40001' || codigo === '40P01') {
      return 'Conflicto de concurrencia. Reintentar la operación';
    }

    // Si no se pudo clasificar, devolver el mensaje original
    return err.mensaje || err.message || 'Error en la petición';
  }

  // ============================================================================
  // SALUD
  // ============================================================================
  async function salud() {
    try {
      return await request(CONFIG.ENDPOINTS.SALUD);
    } catch (err) {
      throw new Error('No se puede conectar con la API. Asegúrate de que el servidor esté corriendo en http://localhost:8001');
    }
  }

  // Verifica si la API está disponible antes de hacer operaciones
  async function verificarConectividad() {
    try {
      await salud();
      return true;
    } catch (err) {
      return false;
    }
  }

  // ============================================================================
  // SALAS DE VENTA
  // ============================================================================
  async function listarSalas() {
    return request(CONFIG.ENDPOINTS.SALAS);
  }

  // ============================================================================
  // VINOS
  // ============================================================================
  async function listarVinos(params = {}) {
    const qs = new URLSearchParams();
    if (params.page) qs.set('page', params.page);
    if (params.limit) qs.set('limit', params.limit);
    if (params.tipo) qs.set('tipo', params.tipo);
    if (params.cepa) qs.set('cepa', params.cepa);
    if (params.bodega) qs.set('bodega', params.bodega);
    if (params.nombre) qs.set('nombre', params.nombre);
    if (params.anada) qs.set('anada', params.anada);
    const path = qs.toString()
      ? `${CONFIG.ENDPOINTS.VINOS}?${qs.toString()}`
      : CONFIG.ENDPOINTS.VINOS;
    return request(path);
  }

  async function obtenerVino(codVino) {
    return request(`${CONFIG.ENDPOINTS.VINOS}/${codVino}`);
  }

  async function crearVino(vinoData) {
    return request(CONFIG.ENDPOINTS.VINOS, {
      method: 'POST',
      body: JSON.stringify(vinoData),
    });
  }

  async function actualizarVino(codVino, precio) {
    return request(`${CONFIG.ENDPOINTS.VINOS}/${codVino}`, {
      method: 'PUT',
      body: JSON.stringify({ precio }),
    });
  }

  async function eliminarVino(codVino) {
    return request(`${CONFIG.ENDPOINTS.VINOS}/${codVino}`, {
      method: 'DELETE',
    });
  }

  // ============================================================================
  // CLIENTES
  // ============================================================================
  async function listarClientes() {
    return request(CONFIG.ENDPOINTS.CLIENTES);
  }

  async function obtenerCliente(idCliente) {
    return request(`${CONFIG.ENDPOINTS.CLIENTES}/${idCliente}`);
  }

  async function crearCliente(clienteData) {
    return request(CONFIG.ENDPOINTS.CLIENTES, {
      method: 'POST',
      body: JSON.stringify(clienteData),
    });
  }

  async function actualizarCliente(idCliente, clienteData) {
    return request(`${CONFIG.ENDPOINTS.CLIENTES}/${idCliente}`, {
      method: 'PUT',
      body: JSON.stringify(clienteData),
    });
  }

  async function eliminarCliente(idCliente) {
    return request(`${CONFIG.ENDPOINTS.CLIENTES}/${idCliente}`, {
      method: 'DELETE',
    });
  }

  // ============================================================================
  // COMPROBANTES (VENTAS)
  // ============================================================================
  async function obtenerComprobante(nroComprobante) {
    return request(`${CONFIG.ENDPOINTS.COMPROBANTES}/${nroComprobante}`);
  }

  /**
   * Crear un comprobante de venta.
   * IMPORTANTE: El front NO calcula totales ni stock.
   * Solo envía lo que el usuario ingresó; la BD calcula subtotal, descuento, total
   * y valida stock mediante triggers (RN-08, RN-09).
   * @param {object} data { id_cliente, id_sala, renglones: [{cod_vino, cantidad, precio_unitario, descuento_aplicado}] }
   */
  async function crearComprobante(data) {
    return request(CONFIG.ENDPOINTS.COMPROBANTES, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  // ============================================================================
  // INGRESOS (DEPÓSITO CENTRAL)
  // ============================================================================
  async function crearIngreso(ingresoData) {
    return request(CONFIG.ENDPOINTS.INGRESOS, {
      method: 'POST',
      body: JSON.stringify(ingresoData),
    });
  }

  async function agregarRenglonIngreso(codIngreso, renglonData) {
    return request(`${CONFIG.ENDPOINTS.INGRESOS}/${codIngreso}/renglones`, {
      method: 'POST',
      body: JSON.stringify(renglonData),
    });
  }

  async function procesarIngreso(codIngreso) {
    return request(`${CONFIG.ENDPOINTS.INGRESOS}/${codIngreso}/procesar`, {
      method: 'POST',
    });
  }

  // ============================================================================
  // TRANSFERENCIAS (DEPÓSITO → SALA)
  // ============================================================================
  async function crearTransferencia(transferenciaData) {
    return request(CONFIG.ENDPOINTS.TRANSFERENCIAS, {
      method: 'POST',
      body: JSON.stringify(transferenciaData),
    });
  }

  async function agregarRenglonTransferencia(nroSolicitud, renglonData) {
    return request(`${CONFIG.ENDPOINTS.TRANSFERENCIAS}/${nroSolicitud}/renglones`, {
      method: 'POST',
      body: JSON.stringify(renglonData),
    });
  }

  async function terminarTransferencia(nroSolicitud) {
    return request(`${CONFIG.ENDPOINTS.TRANSFERENCIAS}/${nroSolicitud}/terminar`, {
      method: 'POST',
    });
  }

  async function procesarTransferencia(nroSolicitud) {
    return request(`${CONFIG.ENDPOINTS.TRANSFERENCIAS}/${nroSolicitud}/procesar`, {
      method: 'POST',
    });
  }

  // ============================================================================
  // REPORTES
  // ============================================================================
  async function reporteTopVinos() {
    return request(`${CONFIG.ENDPOINTS.REPORTES}/top-vinos`);
  }

  async function reporteVentasPorSala() {
    return request(`${CONFIG.ENDPOINTS.REPORTES}/ventas-por-sala`);
  }

  async function reporteVinosSinStock(idSala) {
    return request(`${CONFIG.ENDPOINTS.REPORTES}/vinos-sin-stock?id_sala=${idSala}`);
  }

  async function reporteTransportistaActivo() {
    return request(`${CONFIG.ENDPOINTS.REPORTES}/transportista-activo`);
  }

  async function reporteTrazabilidad(codVino) {
    return request(`${CONFIG.ENDPOINTS.REPORTES}/trazabilidad/${codVino}`);
  }

  return {
    salud,
    verificarConectividad,
    formatearErrorParaUsuario,
    listarSalas,
    listarVinos,
    obtenerVino,
    crearVino,
    actualizarVino,
    eliminarVino,
    listarClientes,
    obtenerCliente,
    crearCliente,
    actualizarCliente,
    eliminarCliente,
    obtenerComprobante,
    crearComprobante,
    crearIngreso,
    agregarRenglonIngreso,
    procesarIngreso,
    crearTransferencia,
    agregarRenglonTransferencia,
    terminarTransferencia,
    procesarTransferencia,
    reporteTopVinos,
    reporteVentasPorSala,
    reporteVinosSinStock,
    reporteTransportistaActivo,
    reporteTrazabilidad,
  };
})();

// Export para módulos si es necesario
if (typeof exports !== 'undefined') {
  exports.API = API;
}
