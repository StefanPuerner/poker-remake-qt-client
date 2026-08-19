# PokerRemake — cliente Qt

Clientes gráficos (Qt Quick/QML) para jugar Texas Hold'em en red contra un
servidor [PokerRemake](https://github.com/StefanPuerner/poker-remake). Este
repo contiene **solo el cliente** — de escritorio y móvil —: crea/lista
salas, juega la partida, chatea y guarda/carga partidas hablando el
protocolo TCP/JSON del servidor. No incluye el motor de juego ni la lógica
de servidor.

- **`PokerClientQt`** — interfaz de escritorio, ratón/teclado.
- **`PokerClientMobile`** — interfaz táctil, pensada para landscape en
  Android (objetivos de toque grandes, teclado emergente anclado arriba en
  vez de tapar la mesa, cajón de pestañas en vez de barra de botones fija).
  En Linux/Windows es un binario de escritorio normal, útil para probar la
  interfaz táctil sin un móvil a mano.

## Descargas

Cada [Release](https://github.com/StefanPuerner/poker-remake-qt-client/releases)
trae, listos para usar (sin compilar nada):

| Plataforma | Archivo |
|---|---|
| Windows | `PokerRemake-Windows-x86_64.zip` — descomprimir y ejecutar `PokerClientQt.exe` |
| Linux | `PokerRemake-x86_64.AppImage` — dar permiso de ejecución y lanzar |
| Android | `PokerRemake-Android-arm64.zip` — descomprimir e instalar el `.apk` (`PokerClientMobile`, orígenes desconocidos) |

El APK sale firmado con el keystore de depuración de Gradle (sin firma de
código real todavía) — Android avisará de "aplicación de un desarrollador
desconocido" al instalarlo, es normal.

## Requisitos (para compilar desde el código)

- CMake ≥ 3.16
- Compilador C++17
- Qt6 (`Quick`, `QuickControls2`, `Network`) — para `PokerClientMobile` en
  Android hace falta además el SDK/NDK de Android y un Qt cross-compilado
  para Android; la forma más simple de conseguir un APK es lanzar el
  workflow `Build Android` desde la pestaña Actions de GitHub (o esperar
  al siguiente Release) en vez de montar ese entorno en local.

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

Genera `PokerClientQt` y `PokerClientMobile` en `build/` (los dos como
binarios de escritorio normales — cross-compilar `PokerClientMobile` a
Android es aparte, ver "Descargas" arriba).

## Ejecutar

```bash
./build/PokerClientQt       # escritorio
./build/PokerClientMobile   # interfaz táctil, en una ventana de escritorio
```

Desde "Inicio" → "Salas disponibles": crea una sala nueva o únete a una
pública de la lista / privada por código.

## Estructura

```
src/client-qt/qml/Main.qml       — cliente de escritorio: pantallas, componentes, lógica de UI
src/client-qt/qml-mobile/Main.qml — cliente móvil: mismas pantallas, componentes propios (táctil)
src/client-qt/main.cpp, main-mobile.cpp
                                  — arranque de cada cliente: QGuiApplication + motor QML
src/client-qt/android/           — manifest de referencia + iconos adaptativos (Android)
include/net-qt/NetworkClient.hpp
                                  — puente C++/Qt hacia el protocolo de red (QTcpSocket),
                                    compartido por los dos clientes
include/net/Protocol.hpp, src/net/Protocol.cpp
                                  — protocolo TCP/JSON compartido con el servidor
include/net/ServerConfig.hpp     — host/puerto por defecto (ver arriba)
assets/fonts/                    — EB Garamond (SIL Open Font License)
docs/guia/                       — guía de Qt Quick/QML usada para construir este cliente
```

## Documentación

`docs/guia/` tiene una introducción a Qt Quick/QML desde cero
(`06-qt-fundamentos.md` a `09-qt-recursos-aprendizaje.md`) y el plan de
migración de este cliente (`10-migracion-qt.md`), por si quieres entender o
modificar el código.

## Licencia

MIT — ver [`LICENSE`](LICENSE).
