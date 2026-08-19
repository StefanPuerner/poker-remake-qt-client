cmake_minimum_required(VERSION 3.16)

project(PokerRemakeQtClient VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include_directories(include)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Network)

# Políticas explícitas de qt_add_qml_module (silencian avisos de CMake):
# QTP0001 = usar el prefijo de recursos por defecto ':/qt/qml/'.
# QTP0004 = no exigir qmldir manual por cada subcarpeta con .qml.
# QTP0004 solo existe desde Qt 6.8 (confirmado leyendo el propio
# Qt6QmlMacros.cmake: "__qt_internal_setup_policy(QTP0004 "6.8.0" ...)")
# -- el build de Android usa Qt 6.7.3 (la versión más reciente que el
# catálogo de aqtinstall reconoce para Android, ver build-android.yml) y
# qt_policy(SET QTP0004 NEW) ahí aborta el configure entero con
# "QTP0004 is not a known Qt policy". Sin el guard, Qt6_VERSION < 6.8
# simplemente no lo pide -- comportamiento de antes de que la política
# existiera, no un cambio funcional real.
qt_policy(SET QTP0001 NEW)
if(Qt6_VERSION VERSION_GREATER_EQUAL "6.8.0")
    qt_policy(SET QTP0004 NEW)
endif()

qt_add_executable(PokerClientQt
    src/client-qt/main.cpp
    src/net/Protocol.cpp
    include/net-qt/NetworkClient.hpp
)
set_target_properties(PokerClientQt PROPERTIES AUTOMOC ON)

# qt_add_qml_module no detecta solo el "pragma Singleton" de Tema.qml —
# sin esto, el qmldir generado lo lista como un tipo normal en vez de
# "singleton Tema ...", y qmllint (que sí lee el qmldir al pie de la
# letra) no reconoce ninguna de sus propiedades (falsos positivos
# "Member ... not found on type Tema" en cualquier fichero que use
# Tema.colorX/escala). El motor de Qt en tiempo de ejecución no se ve
# afectado, esto es solo para que el linter entienda el singleton.
set_source_files_properties(src/client-qt/qml/Tema.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(PokerClientQt
    URI PokerQuick
    VERSION 1.0
    QML_FILES
        src/client-qt/qml/Main.qml
        src/client-qt/qml/Tema.qml
        src/client-qt/qml/Carta.qml
        src/client-qt/qml/Asiento.qml
        src/client-qt/qml/AsientoMini.qml
        src/client-qt/qml/Mesa.qml
        src/client-qt/qml/Interruptor.qml
        src/client-qt/qml/SelectorPildoras.qml
        src/client-qt/qml/BotonContorno.qml
        src/client-qt/qml/BotonRelleno.qml
        src/client-qt/qml/PanelVoto.qml
        src/client-qt/qml/TarjetaReveal.qml
        src/client-qt/qml/BarraSuperior.qml
        src/client-qt/qml/ChatBox.qml
        src/client-qt/qml/PanelLateral.qml
    RESOURCES
        # EB Garamond (SIL Open Font License) empaquetada con el binario —
        # los nombres de fuente del sistema no son fiables entre plataformas.
        # Licencia completa en assets/fonts/OFL.txt.
        assets/fonts/EBGaramond.ttf
        # Aviso de "tu turno" — dos tonos sintetizados (sin depender de
        # audio con licencia de terceros), ver assets/sonidos/.
        assets/sonidos/turno.wav
)

target_include_directories(PokerClientQt PRIVATE include)
target_link_libraries(PokerClientQt PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::Network)

# Sonido de notificación ("tu turno") — Multimedia es un módulo ADICIONAL
# de Qt6 (no viene con Quick), y solo hace falta para PokerClientQt, nunca
# para PokerClientMobile. "if(NOT ANDROID)": al cross-compilar para
# Android este mismo fichero se procesa entero igualmente con el kit de
# Qt-para-Android como CMAKE_TOOLCHAIN (ver build-android.yml) -- ese kit
# no tiene por qué traer Multimedia instalado, así que buscarlo ahí
# rompería el configure entero de una build que ni siquiera compila
# PokerClientQt. target_link_libraries usa "if(TARGET ...)" en vez de
# asumir que existe, por el mismo motivo.
if(NOT ANDROID)
    find_package(Qt6 REQUIRED COMPONENTS Multimedia)
endif()
if(TARGET Qt6::Multimedia)
    target_link_libraries(PokerClientQt PRIVATE Qt6::Multimedia)
endif()

# -Wall/-Wextra/-Wpedantic son flags de GCC/Clang — MSVC (el compilador que
# usa Windows) no los reconoce y falla directamente al verlos. Su
# equivalente de "avisos exigentes" es /W4.
if(MSVC)
    target_compile_options(PokerClientQt PRIVATE /W4)
else()
    target_compile_options(PokerClientQt PRIVATE -Wall -Wextra -Wpedantic)
endif()

# ── PokerClientMobile — interfaz táctil/landscape. En Linux/escritorio es
#  un binario normal, igual que PokerClientQt; al cross-compilar para
#  Android (ver build-android.yml) se empaqueta como APK. Árbol QML
#  separado de PokerClientQt: reutiliza solo la capa de red
#  (NetworkClient.hpp), el resto de componentes parte de cero en
#  qml-mobile/ pensado para tamaños de objetivo táctil, feedback "pressed"
#  en vez de hover, y tipografía a la densidad de un móvil. URI distinto
#  (PokerQuickMobile en vez de PokerQuick) para evitar colisión de
#  carpetas en el directorio de build.
qt_add_executable(PokerClientMobile
    src/client-qt/main-mobile.cpp
    src/net/Protocol.cpp
    include/net-qt/NetworkClient.hpp
)
set_target_properties(PokerClientMobile PROPERTIES AUTOMOC ON)

# Solo importa al cross-compilar para Android (androiddeployqt la lee para
# generar el APK) — en Linux/escritorio esta propiedad simplemente no se
# usa. Fija el bloqueo a horizontal y de dónde salen manifest/iconos.
if(ANDROID)
    set_target_properties(PokerClientMobile PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src/client-qt/android
        QT_ANDROID_MIN_SDK_VERSION 28
    )
endif()

# Mismo motivo que el Tema.qml de escritorio más arriba.
set_source_files_properties(src/client-qt/qml-mobile/Tema.qml
                             src/client-qt/qml-mobile/EstadoOverlays.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(PokerClientMobile
    URI PokerQuickMobile
    VERSION 1.0
    NO_CACHEGEN
    QML_FILES
        src/client-qt/qml-mobile/Main.qml
        src/client-qt/qml-mobile/Tema.qml
        src/client-qt/qml-mobile/EstadoOverlays.qml
        src/client-qt/qml-mobile/BotonContorno.qml
        src/client-qt/qml-mobile/BotonRelleno.qml
        src/client-qt/qml-mobile/TecladoNumerico.qml
        src/client-qt/qml-mobile/CampoEmergente.qml
        src/client-qt/qml-mobile/SelectorNumerico.qml
        src/client-qt/qml-mobile/Interruptor.qml
        src/client-qt/qml-mobile/SelectorPildoras.qml
        src/client-qt/qml-mobile/BarraSuperior.qml
        src/client-qt/qml-mobile/IconoAjustes.qml
        src/client-qt/qml-mobile/CabeceraPullRefrescar.qml
        src/client-qt/qml-mobile/AsientoMini.qml
        src/client-qt/qml-mobile/ChatBox.qml
        src/client-qt/qml-mobile/Carta.qml
        src/client-qt/qml-mobile/Asiento.qml
        src/client-qt/qml-mobile/Mesa.qml
        src/client-qt/qml-mobile/CajonPartida.qml
        src/client-qt/qml-mobile/PanelVoto.qml
        src/client-qt/qml-mobile/TarjetaReveal.qml
        src/client-qt/qml-mobile/ChuletaFlotante.qml
    RESOURCES
        assets/fonts/EBGaramond.ttf
)

target_include_directories(PokerClientMobile PRIVATE include)
target_link_libraries(PokerClientMobile PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::Network)

if(MSVC)
    target_compile_options(PokerClientMobile PRIVATE /W4)
else()
    target_compile_options(PokerClientMobile PRIVATE -Wall -Wextra -Wpedantic)
endif()

message(STATUS "Configuración de PokerRemakeQtClient completada con éxito.")
