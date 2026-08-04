# PokerRemake — cliente Qt

Cliente gráfico (Qt Quick/QML) para jugar Texas Hold'em en red contra un
servidor [PokerRemake](https://github.com/StefanPuerner/poker-remake). Este
repo contiene **solo el cliente**: crea/lista salas, juega la partida, chatea
y guarda/carga partidas hablando el protocolo TCP/JSON del servidor — no
incluye el motor de juego ni la lógica de servidor.

## Requisitos

- CMake ≥ 3.16
- Compilador C++17
- Qt6 (`Quick`, `QuickControls2`, `Network`)

## Conectar a un servidor

La IP y el puerto por defecto están en un único sitio,
[`include/net/ServerConfig.hpp`](include/net/ServerConfig.hpp):

```cpp
constexpr uint16_t    SERVER_PORT = 7777;
constexpr const char* SERVER_HOST = "100.83.246.15";
```

Edita `SERVER_HOST` con la IP del servidor al que te vas a conectar (por
ejemplo, una IP [Tailscale](https://tailscale.com/)) antes de compilar.

## Compilar

```bash
cmake -B build
cmake --build build -j$(nproc)
```

Genera `PokerClientQt` en `build/`.

## Ejecutar

```bash
./build/PokerClientQt
```

Desde "Inicio" → "Salas disponibles": crea una sala nueva o únete a una
pública de la lista / privada por código.

## Estructura

```
src/client-qt/qml/Main.qml   — toda la interfaz: pantallas, componentes, lógica de UI
src/client-qt/main.cpp       — arranque: QGuiApplication + motor QML
include/net-qt/NetworkClient.hpp
                              — puente C++/Qt hacia el protocolo de red (QTcpSocket)
include/net/Protocol.hpp, src/net/Protocol.cpp
                              — protocolo TCP/JSON compartido con el servidor
include/net/ServerConfig.hpp — host/puerto por defecto (ver arriba)
assets/fonts/                — EB Garamond (SIL Open Font License)
docs/guia/                   — guía de Qt Quick/QML usada para construir este cliente
```

## Documentación

`docs/guia/` tiene una introducción a Qt Quick/QML desde cero
(`06-qt-fundamentos.md` a `09-qt-recursos-aprendizaje.md`) y el plan de
migración de este cliente (`10-migracion-qt.md`), por si quieres entender o
modificar el código.

## Licencia

MIT — ver [`LICENSE`](LICENSE).
