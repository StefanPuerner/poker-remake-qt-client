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

qt_add_qml_module(PokerClientQt
    URI PokerQuick
    VERSION 1.0
    QML_FILES
        src/client-qt/qml/Main.qml
    RESOURCES
        # EB Garamond (SIL Open Font License) empaquetada con el binario —
        # los nombres de fuente del sistema no son fiables entre plataformas.
        # Licencia completa en assets/fonts/OFL.txt.
        assets/fonts/EBGaramond.ttf
)

target_include_directories(PokerClientQt PRIVATE include)
target_link_libraries(PokerClientQt PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::Network)
target_compile_options(PokerClientQt PRIVATE -Wall -Wextra -Wpedantic)

message(STATUS "Configuración de PokerRemakeQtClient completada con éxito.")
