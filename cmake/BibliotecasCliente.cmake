# ── Bibliotecas que enlazan los clientes: red (solo cliente) y motor ──────────
#  Compartido con el repo público poker-remake-qt-client: este fichero se
#  copia TAL CUAL allí (scripts/sincronizar_repo_publico.sh) y su
#  CMakeLists.txt lo incluye igual que el de aquí, en el mismo orden:
#  Comun.cmake → BibliotecasCliente.cmake → ClientesQt.cmake. Así los dos
#  repos compilan los clientes con las mismas reglas y el público no se
#  queda atrás sin que nadie lo note (pasó: en 2026-09 le faltaban el motor,
#  el modo offline, los iconos y el shader, y no habría compilado).
#  ⚠️ Nada de aquí puede depender de algo que solo exista en el repo
#  privado: servidor, tests, ncurses, SQLite, OpenSSL del sistema.
#  El motor va entero porque el modo offline lo embebe en los dos
#  clientes (ver docs/plan-modo-offline.md del repo privado).

# ── Fuentes de red SOLO para el cliente Qt (sin sockets POSIX) ────────────────
#  NetworkClient.hpp habla directo con QTcpSocket, no con los sockets POSIX
#  crudos de NET_SOURCES, en el CMakeLists del repo privado (SocketIO/SocketServer/SocketClient/NetworkObserver/
#  NetworkPlayer/RoomRegistry son código de servidor o de los otros
#  clientes) — de todo NET_SOURCES, esto es lo único que de verdad usa:
#  Protocol.cpp (buildMsg/jsonGetStr/jsonGetInt, texto puro, sin sockets),
#  Logger.cpp y Serializer.cpp. Enlazar PokerClientQt/PokerClientMobile
#  contra esto en vez de PokerNet completo es lo que permite que compilen
#  en Windows sin necesitar puertos de <unistd.h>/<arpa/inet.h>/<poll.h> que
#  ese código nunca ejecuta de todas formas.
set(NET_CLIENT_SOURCES
    src/Logger.cpp
    src/net/Protocol.cpp
    src/net/Serializer.cpp
)


# ── Fuentes del motor de juego (compartidas entre local y servidor) ────────────
set(ENGINE_SOURCES
    src/Partida.cpp
    src/Persona.cpp
    src/Bot.cpp
    src/Carta.cpp
    src/Baraja.cpp
    src/Mesa.cpp
    src/Bote.cpp
    src/Analyzer.cpp
    src/HandPredictor.cpp
    src/FileManager.cpp
    src/Interfaz.cpp
    src/TexasHoldem.cpp
    src/DecisionEngine.cpp
    src/LocalObserver.cpp
)

# ── Biblioteca estática de red, solo cliente Qt (ver NET_CLIENT_SOURCES) ──────
add_library(PokerNetClient STATIC ${NET_CLIENT_SOURCES})
target_include_directories(PokerNetClient PRIVATE include)
target_compile_options(PokerNetClient PRIVATE ${POKER_WARN_FLAGS})

# ── Biblioteca estática del motor ──────────────────────────────────────────────
add_library(PokerEngine STATIC ${ENGINE_SOURCES})
target_include_directories(PokerEngine PRIVATE include)
target_compile_options(PokerEngine PRIVATE ${POKER_WARN_FLAGS_ERROR})
target_compile_definitions(PokerEngine PRIVATE SAVEPATH="../data/")
