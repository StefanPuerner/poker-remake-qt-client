# ── Base común: versión, estándar y flags de aviso ────────────────────────────
#  Compartido con el repo público poker-remake-qt-client: este fichero se
#  copia TAL CUAL allí (scripts/sincronizar_repo_publico.sh) y su
#  CMakeLists.txt lo incluye igual que el de aquí, en el mismo orden:
#  Comun.cmake → BibliotecasCliente.cmake → ClientesQt.cmake. Así los dos
#  repos compilan los clientes con las mismas reglas y el público no se
#  queda atrás sin que nadie lo note (pasó: en 2026-09 le faltaban el motor,
#  el modo offline, los iconos y el shader, y no habría compilado).
#  ⚠️ Nada de aquí puede depender de algo que solo exista en el repo
#  privado: servidor, tests, ncurses, SQLite, OpenSSL del sistema.

# Versión que se compila DENTRO de los clientes Qt (VersionChecker.hpp,
# vía POKER_APP_VERSION) para compararse contra el último tag publicado en
# GitHub y avisar si el binario instalado se quedó atrás. Único sitio a
# actualizar en cada release -- debe coincidir con el tag de git que se
# publique (v0.7.1 → "0.7.1", sin la "v").
set(POKER_APP_VERSION_STRING "0.7.1")

# Sin esto, "cmake -B build" sin más deja CMAKE_BUILD_TYPE vacío: ni -O2 ni
# -g, el peor de los dos mundos (lento de ejecutar y poco depurable). Solo
# aplica a generadores de un solo modo (Makefiles/Ninja) — los de varios
# modos (Visual Studio, Xcode) lo eligen aparte con --config al compilar.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "RelWithDebInfo" CACHE STRING "Tipo de build" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
                 "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

include_directories(include)

# ── Flags de aviso, por compilador ──────────────────────────────────────────
#  -Wall/-Wextra/-Wpedantic (y -Werror donde ya se exigía) son sintaxis de
#  GCC/Clang -- cl.exe (MSVC, usado en el workflow de Windows) no las
#  entiende y aborta la compilación entera con "invalid numeric argument"
#  en cuanto las ve. /W4 es el equivalente razonable de MSVC a -Wall -Wextra;
#  /WX es su -Werror. Una sola variable aquí en vez de repetir el if(MSVC)
#  en cada target de más abajo.
if(MSVC)
    set(POKER_WARN_FLAGS /W4)
    # SIN /WX en MSVC, a propósito (2026-09-10). El motor (PokerEngine) no se
    # compilaba en Windows hasta que el modo offline lo metió en los clientes,
    # y MSVC avisa a /W4 de cosas que GCC/Clang no (C4267/C4244: size_t o
    # double a int, ~48 sitios estimados con los avisos equivalentes de clang;
    # C4458, parámetros que tapan miembros...). Con /WX cada una tumbaría el
    # build de release de Windows, el único CI que usa MSVC y que no se puede
    # reproducir en local. Los avisos siguen saliendo en su log; -Werror se
    # queda en GCC/Clang, que es donde se desarrolla.
    set(POKER_WARN_FLAGS_ERROR /W4)
    # /utf-8: los fuentes son UTF-8 sin BOM, con tildes en los textos. Sin
    # esto MSVC los lee en la página de códigos del sistema (1252 en los
    # runners): avisos C4819 y literales con caracteres rotos. Qt solo lo
    # añade a los targets que enlazan Qt, y PokerEngine/PokerNetClient no.
    #
    # /bigobj: el C++ que genera qmlcachegen para qml/Main.qml (8400 líneas,
    # 2026-09-10) define ~17 600 funciones, y MSVC pone cada una en varias
    # secciones COFF (código, tablas de excepciones y, en RelWithDebInfo,
    # depuración): pasa del tope de 65 279 secciones de un .obj normal
    # (error C1128). Con las 5 364 líneas de la v0.7.1 aún cabía. /bigobj
    # solo cambia el formato del objeto; no afecta al programa.
    add_compile_options(/utf-8 /bigobj)
else()
    set(POKER_WARN_FLAGS -Wall -Wextra -Wpedantic)
    set(POKER_WARN_FLAGS_ERROR -Wall -Wextra -Wpedantic -Werror)
endif()

# Para silenciar un aviso concreto SOLO si el compilador lo conoce (ver sus
# usos más abajo): pasarle a un compilador una -Wno-... que no reconoce es
# cambiar un aviso por otro ("unknown warning option"). Se comprueba siempre
# la forma positiva (-Wfoo), porque hay compiladores que aceptan cualquier
# -Wno-foo en silencio y la comprobación daría un falso sí.
include(CheckCXXCompilerFlag)
