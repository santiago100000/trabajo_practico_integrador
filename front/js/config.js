// ============================================================================
// Configuración centralizada del Frontend — Bodegas del Atuel
// ============================================================================
// La URL base de la API se puede configurar de dos formas:
// 1. Definiendo window.__API_BASE_URL__ antes de cargar este script
// 2. Editando el valor por defecto a continuación
// ============================================================================

const CONFIG = {
  // URL base de la API REST (Etapa 6)
  // La API corre en http://localhost:8001 y tiene CORS habilitado para el front en 8081.
  API_BASE_URL:
    typeof window !== 'undefined' && window.__API_BASE_URL__
      ? window.__API_BASE_URL__
      : 'http://localhost:8001',

  // Tiempo de espera para peticiones (ms)
  REQUEST_TIMEOUT: 10000,

  // Endpoints de la API
  ENDPOINTS: {
    SALUD: '/salud',

    // Vinos
    VINOS: '/vinos',

    // Clientes
    CLIENTES: '/clientes',

    // Comprobantes de venta
    COMPROBANTES: '/comprobantes',

    // Ingresos al depósito
    INGRESOS: '/ingresos',

    // Transferencias depósito → sala
    TRANSFERENCIAS: '/transferencias',

    // Reportes
    REPORTES: '/reportes',
  },
};

// Export para entornos que soporten módulos
if (typeof exports !== 'undefined') {
  exports.CONFIG = CONFIG;
}
