-- =============================================================================
-- db_tests.sql
-- Pruebas de base de datos para las reglas de negocio RN-01 a RN-15.
-- Cada sección tiene: "caso que debe funcionar", "caso que debe fallar"
-- y un TODO para que el grupo escriba la sentencia real.
-- Restricción del TP: solo comentarios y TODO en este esqueleto.
-- =============================================================================

\echo '===== Inicio de db_tests.sql ====='

-- -----------------------------------------------------------------------------
-- RN-01: [regla del enunciado PDF, sección 4]
-- -----------------------------------------------------------------------------
-- Caso que debe funcionar:
-- TODO (grupo): sentencia que cumple RN-01

-- Caso que debe fallar (error esperado: ...):
-- TODO (grupo): sentencia que viola RN-01

-- -----------------------------------------------------------------------------
-- RN-02: [regla del enunciado PDF, sección 4]
-- -----------------------------------------------------------------------------
-- Caso que debe funcionar:
-- TODO (grupo): sentencia que cumple RN-02

-- Caso que debe fallar (error esperado: ...):
-- TODO (grupo): sentencia que viola RN-02

-- -----------------------------------------------------------------------------
-- RN-03: [regla del enunciado PDF, sección 4]
-- -----------------------------------------------------------------------------
-- Caso que debe funcionar:
-- TODO (grupo): sentencia que cumple RN-03

-- Caso que debe fallar (error esperado: ...):
-- TODO (grupo): sentencia que viola RN-03

-- -----------------------------------------------------------------------------
-- RN-04: [regla del enunciado PDF, sección 4]
-- -----------------------------------------------------------------------------
-- Caso que debe funcionar:
-- TODO (grupo): sentencia que cumple RN-04

-- Caso que debe fallar (error esperado: ...):
-- TODO (grupo): sentencia que viola RN-04

-- -----------------------------------------------------------------------------
-- RN-05: [regla del enunciado PDF, sección 4]
-- -----------------------------------------------------------------------------
-- Caso que debe funcionar:
-- TODO (grupo): sentencia que cumple RN-05

-- Caso que debe fallar (error esperado: ...):
-- TODO (grupo): sentencia que viola RN-05

-- -----------------------------------------------------------------------------
-- RN-06: [regla del enunciado PDF, sección 4]
-- -----------------------------------------------------------------------------
-- Caso que debe funcionar:
-- TODO (grupo): sentencia que cumple RN-06

-- Caso que debe fallar (error esperado: ...):
-- TODO (grupo): sentencia que viola RN-06

-- -----------------------------------------------------------------------------
-- RN-07: [regla del enunciado PDF, sección 4]
-- -----------------------------------------------------------------------------
-- Caso que debe funcionar:
-- TODO (grupo): sentencia que cumple RN-07

-- Caso que debe fallar (error esperado: ...):
-- TODO (grupo): sentencia que viola RN-07

-- -----------------------------------------------------------------------------
-- RN-08: [regla del enunciado PDF, sección 4]
-- -----------------------------------------------------------------------------
-- Caso que debe funcionar:
-- TODO (grupo): sentencia que cumple RN-08

-- Caso que debe fallar (error esperado: ...):
-- TODO (grupo): sentencia que viola RN-08

-- -----------------------------------------------------------------------------
-- RN-09: [regla del enunciado PDF, sección 4]
-- -----------------------------------------------------------------------------
-- Caso que debe funcionar:
-- TODO (grupo): sentencia que cumple RN-09

-- Caso que debe fallar (error esperado: ...):
-- TODO (grupo): sentencia que viola RN-09

-- -----------------------------------------------------------------------------
-- RN-10: [regla del enunciado PDF, sección 4]
-- -----------------------------------------------------------------------------
-- Caso que debe funcionar:
-- TODO (grupo): sentencia que cumple RN-10

-- Caso que debe fallar (error esperado: ...):
-- TODO (grupo): sentencia que viola RN-10

-- -----------------------------------------------------------------------------
-- RN-11: [regla del enunciado PDF, sección 4]
-- -----------------------------------------------------------------------------
-- Caso que debe funcionar:
-- TODO (grupo): sentencia que cumple RN-11

-- Caso que debe fallar (error esperado: ...):
-- TODO (grupo): sentencia que viola RN-11

-- -----------------------------------------------------------------------------
-- RN-12: [regla del enunciado PDF, sección 4]
-- -----------------------------------------------------------------------------
-- Caso que debe funcionar:
-- TODO (grupo): sentencia que cumple RN-12

-- Caso que debe fallar (error esperado: ...):
-- TODO (grupo): sentencia que viola RN-12

-- -----------------------------------------------------------------------------
-- RN-13: [regla del enunciado PDF, sección 4]
-- -----------------------------------------------------------------------------
-- Caso que debe funcionar:
-- TODO (grupo): sentencia que cumple RN-13

-- Caso que debe fallar (error esperado: ...):
-- TODO (grupo): sentencia que viola RN-13

-- -----------------------------------------------------------------------------
-- RN-14: [regla del enunciado PDF, sección 4]
-- -----------------------------------------------------------------------------
-- Caso que debe funcionar:
-- TODO (grupo): sentencia que cumple RN-14

-- Caso que debe fallar (error esperado: ...):
-- TODO (grupo): sentencia que viola RN-14

-- -----------------------------------------------------------------------------
-- RN-15: [regla del enunciado PDF, sección 4]
-- -----------------------------------------------------------------------------
-- Caso que debe funcionar:
-- TODO (grupo): sentencia que cumple RN-15

-- Caso que debe fallar (error esperado: ...):
-- TODO (grupo): sentencia que viola RN-15

-- -----------------------------------------------------------------------------
-- Demo de concurrencia (dos sesiones, con y sin FOR UPDATE)
-- -----------------------------------------------------------------------------
-- Sesión A (sin FOR UPDATE):
-- TODO (grupo): BEGIN; SELECT ...; UPDATE ...; COMMIT;

-- Sesión B (con FOR UPDATE):
-- TODO (grupo): BEGIN; SELECT ... FOR UPDATE; UPDATE ...; COMMIT;

-- Resultado esperado: la sesión con FOR UPDATE serializa; la otra puede perder
-- actualizaciones si no hay control de concurrencia.

\echo '===== Fin de db_tests.sql ====='
