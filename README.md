# PokerRemake — cliente Qt

Clientes gráficos (Qt Quick/QML) para jugar Texas Hold'em en red contra un
servidor [PokerRemake](https://github.com/StefanPuerner/poker-remake), o sin
conexión contra bots. Este repo contiene **los clientes** — de escritorio y
móvil — y todo lo que hace falta para compilarlos, incluido el motor de
juego, que va embebido para el modo sin conexión: crea/lista salas, juega la
partida, chatea, guarda/carga partidas y muestra estadísticas al terminar
(manos disputadas, mejor mano de la partida, racha de eliminaciones)
hablando el protocolo TCP/JSON del servidor. No incluye el servidor.

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
| Android | `PokerRemake.apk` — instalar directamente, sin descomprimir nada (móviles arm64; hay que permitir orígenes desconocidos). Hasta la v0.7.1 venía dentro de `PokerRemake-Android-arm64.zip`. |

El APK sale firmado con un keystore de release de verdad — Android seguirá
avisando de "aplicación de un desarrollador desconocido" al instalarlo
(normal para cualquier APK repartido fuera de Play Store), pero ya deja
instalar una versión nueva encima de la anterior sin desinstalar primero.

## Requisitos (para compilar desde el código)

- CMake ≥ 3.16
- Compilador C++17
- Qt6 (`Quick`, `QuickControls2`, `Network` y `ShaderTools`; además
  `Multimedia` para `PokerClientQt`) — para `PokerClientMobile` en
  Android hace falta además el SDK/NDK de Android y un Qt cross-compilado
  para Android; la forma más simple de conseguir un APK es lanzar el
  workflow `Build Android` desde la pestaña Actions de GitHub (o esperar
  al siguiente Release) en vez de montar ese entorno en local.
- Nada de OpenSSL que instalar a mano: en escritorio, `QSslSocket` usa el
  backend TLS que ya trae Qt; en Android, `CMakeLists.txt` descarga solo
  (vía `FetchContent`, necesita internet la primera vez) las `.so` de
  OpenSSL prebuilt que hacen falta empaquetar dentro del APK.

## Conectar a un servidor

La conexión va cifrada (TLS 1.2+) con el certificado del servidor
*pinneado* del lado del cliente — no vale con apuntar a cualquier
servidor, hace falta que su certificado coincida con el *pin* compilado
en el binario. Todo eso está en un único sitio,
[`include/net/ServerConfig.hpp`](include/net/ServerConfig.hpp):

```cpp
constexpr uint16_t    SERVER_PORT = 7777;
constexpr const char* SERVER_HOST = "labandadehalcones.duckdns.org";
constexpr const char* SERVER_CERT_PIN_SHA256 = "...";  // huella del certificado del servidor
```

Antes de compilar: edita `SERVER_HOST` con la dirección del servidor (IP,
[Tailscale](https://tailscale.com/), o un dominio como el de arriba — ya
no hace falta estar en la misma red que el servidor, solo que el puerto
esté alcanzable) y `SERVER_CERT_PIN_SHA256` con el *pin* de SU
certificado — lo genera `scripts/generar_cert_tls.sh` del lado servidor
(repo [poker-remake](https://github.com/StefanPuerner/poker-remake)) y lo
imprime al final. Si el certificado del servidor cambia, hay que repetir
esto y recompilar — el cliente rechaza a propósito cualquier certificado
que no coincida exactamente (ver el comentario de `sslErrors()` en
`NetworkClient.hpp`), así que un *pin* desactualizado no "casi funciona":
simplemente no conecta.

## Compilar

```bash
cmake -B build
cmake --build build -j$(nproc)
```

Genera `PokerClientQt` y `PokerClientMobile` en `build/` (los dos como
binarios de escritorio normales — cross-compilar `PokerClientMobile` a
Android es aparte, ver "Descargas" arriba). También salen `AvatarTest` y
`LocalOfflineSmokeTest`, dos bancos de prueba del desarrollo; para compilar
solo un cliente: `cmake --build build --target PokerClientQt`.

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
                                  — puente C++/Qt hacia el protocolo de red (QSslSocket,
                                    con pinning de certificado), compartido por los dos clientes
include/net/Protocol.hpp, src/net/Protocol.cpp
                                  — protocolo TCP/JSON compartido con el servidor
include/net/ServerConfig.hpp     — host/puerto/pin del certificado TLS por defecto (ver arriba)
include/local-qt/                — modo sin conexión: el motor en su propio hilo, hablando
                                    con el QML igual que lo haría el servidor
include/*.hpp, src/*.cpp         — motor de juego (reglas, bote, bots, evaluación de manos)
cmake/                           — reglas de compilación de los clientes (ver abajo)
assets/iconos/, assets/shaders/  — cosméticos del avatar y dithering de degradados
assets/fonts/                    — EB Garamond (SIL Open Font License)
docs/guia/                       — guía de Qt Quick/QML usada para construir este cliente
```

### De dónde sale el código

Este repo es una foto de los clientes del proyecto completo, sincronizada
desde allí con un script. El código y `cmake/` se editan allí, no aquí: la
siguiente sincronización pisaría cualquier cambio hecho en este repo.
`.sincronizado-desde-privado` lista los ficheros sueltos que trae el
script. Lo propio de este repo es el README, la licencia, los workflows de
release y el `CMakeLists.txt`, que se limita a incluir `cmake/`.

## Documentación

`docs/guia/` tiene una introducción a Qt Quick/QML desde cero
(`06-qt-fundamentos.md` a `09-qt-recursos-aprendizaje.md`) y el plan de
migración de este cliente (`10-migracion-qt.md`), por si quieres entender o
modificar el código.

## Licencia

MIT — ver [`LICENSE`](LICENSE).
