cmake_minimum_required(VERSION 3.16)

project(PokerRemakeQtClient VERSION 0.1.0 LANGUAGES CXX)

# ── Las reglas de verdad viven en cmake/, no aquí ──────────────────────────────
#  cmake/*.cmake se copia TAL CUAL desde el repo del proyecto completo
#  (poker-remake, con scripts/sincronizar_repo_publico.sh) y este fichero
#  solo lo incluye, en el mismo orden que el CMakeLists.txt de allí. Así los
#  dos repos compilan los clientes exactamente igual. No edites cmake/*.cmake
#  en este repo: la siguiente sincronización lo pisaría.
#
#  Qué se compila:
#    * PokerClientQt      -- escritorio, ratón/teclado.
#    * PokerClientMobile  -- táctil; APK al cross-compilar para Android.
#    * PokerEngine        -- el motor de juego, embebido en los dos clientes
#                            para el modo sin conexión (partidas contra bots).
#    * PokerNetClient     -- protocolo y serialización de la parte de red.
#    * AvatarTest y LocalOfflineSmokeTest -- bancos de prueba del desarrollo.
#                            Los workflows no los compilan (usan --target).
#
#  La pestaña Torneos sale como "Próximamente" mientras está en desarrollo
#  (POKER_TORNEOS, apagada por defecto en cmake/ClientesQt.cmake).
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/Comun.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/BibliotecasCliente.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/ClientesQt.cmake)

# En el repo completo los clientes son opcionales (hay builds de solo
# servidor, sin Qt). Aquí son lo único que hay: sin Qt no tiene sentido
# seguir con un build vacío.
if(NOT TARGET PokerClientQt)
    message(FATAL_ERROR "Qt6 (Quick, QuickControls2, Network, ShaderTools) no encontrado -- "
                        "este repo solo contiene los clientes Qt, no hay nada que compilar sin él.")
endif()

message(STATUS "Configuración de PokerRemakeQtClient completada con éxito.")
