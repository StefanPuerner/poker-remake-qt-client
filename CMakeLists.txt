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
qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)

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
)

target_include_directories(PokerClientQt PRIVATE include)
target_link_libraries(PokerClientQt PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::Network)

# -Wall/-Wextra/-Wpedantic son flags de GCC/Clang — MSVC (el compilador que
# usa Windows) no los reconoce y falla directamente al verlos. Su
# equivalente de "avisos exigentes" es /W4.
if(MSVC)
    target_compile_options(PokerClientQt PRIVATE /W4)
else()
    target_compile_options(PokerClientQt PRIVATE -Wall -Wextra -Wpedantic)
endif()

message(STATUS "Configuración de PokerRemakeQtClient completada con éxito.")
