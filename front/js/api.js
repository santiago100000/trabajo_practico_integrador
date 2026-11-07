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
      signal: options.signal || AbortSignal.timeout(CONFIG.REQUEST_TIMEOUT),
    };

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
      if (err.name === 'AbortError') {
        const timeoutErr = new Error('Tiempo de espera agotado al conectar con la API');
        timeoutErr.status = 0;
        timeoutErr.codigo = 'TIMEOUT';
        throw timeoutErr;
      }
      throw err;
    }
  }

  // ============================================================================
  // SALUD
  // ============================================================================
  async function salud() {
    return request(CONFIG.ENDPOINTS.SALUD);
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
