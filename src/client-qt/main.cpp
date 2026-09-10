//  PokerClientQt — cliente con interfaz gráfica Qt Quick/QML (en construcción)
//
//  Qt Quick en vez de Qt Widgets: hay intención real de llevar esta interfaz
//  a móvil con controles táctiles más adelante, y Quick está diseñado para
//  tacto y animación fluida desde la base (Widgets no). La lógica de red
//  (NetworkClient, ver docs/guia/10-migracion-qt.md) será C++ igual que aquí;
//  solo la capa visual se escribe en QML.

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSslSocket>
#include <QDebug>

#include <memory>

#include "../../include/local-qt/LocalGameClient.hpp"
#include "../../include/local-qt/ModoJuegoCoordinador.hpp"
#include "../../include/net-qt/NetworkClient.hpp"
#include "../../include/net-qt/VersionChecker.hpp"
#include "../../include/net/ServerConfig.hpp"

int main(int argc, char* argv[]) {
#ifdef Q_OS_WIN
  // Windows no trae OpenSSL instalado por defecto (a diferencia de Linux)
  // ni se empaqueta aquí (a diferencia de Android, ver
  // cmake/ClientesQt.cmake::add_android_openssl_libraries) -- sin esto, QSslSocket
  // intenta el backend OpenSSL por defecto, no encuentra sus .dll y el
  // *handshake* TLS del servidor nunca llega a completarse (confirmado en
  // real: el build de Windows no conectaba). Schannel es el backend TLS
  // NATIVO de Windows -- viene con el sistema operativo, cero .dll que
  // empaquetar. Tiene que fijarse ANTES de cualquier uso real de
  // QSslSocket (la primera conexión ocurre bastante después, desde QML,
  // pero fijarlo aquí, lo primero de main(), es lo más seguro).
  if (!QSslSocket::setActiveBackend(QStringLiteral("schannel"))) {
    qWarning() << "No se pudo activar el backend TLS Schannel -- las "
                  "conexiones al servidor probablemente fallarán.";
  }
#endif

  // Sin esto, Qt REDONDEA el factor de escala fraccional que reporta el
  // compositor (habitual en GNOME/Wayland con paneles de más resolución:
  // 125%, 150%...) al entero más cercano antes de decidir cuántos píxeles
  // "lógicos" tiene la pantalla — Screen.desktopAvailableWidth/Height en
  // QML usa ese valor ya redondeado, así que la ventana se calcula sobre
  // un tamaño lógico distinto al que el compositor termina mostrando de
  // verdad, y todo sale más pequeño de lo esperado. PassThrough respeta
  // el factor exacto que reporta el sistema en vez de redondearlo. Debe
  // fijarse ANTES de construir QGuiApplication.
  QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
      Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

  QGuiApplication app(argc, argv);
  // Sin esto, Qt.labs.settings (usado en Main.qml para recordar nombre,
  // sonido y tema entre sesiones) no sabe dónde escribir el fichero de
  // ajustes -- QSettings en formato nativo necesita al menos el nombre de
  // la aplicación (y por convención también el de la organización) para
  // construir esa ruta por defecto; sin ellos, escribe silenciosamente en
  // ninguna parte (comprobado en real: cero fichero de settings creado).
  QGuiApplication::setOrganizationName("PokerRemake");
  QGuiApplication::setApplicationName("PokerClientQt");
  // En un puntero y destruido a mano al salir (ver el final de main()): el
  // motor QML tiene que morir ANTES que los objetos que expone. Declarado
  // como variable local el primero, moría el último: "redcliente" y compañía
  // se destruían con la ventana QML todavía viva, sus bindings se
  // re-evaluaban contra null y cada cierre soltaba ~85 "TypeError: Cannot
  // read property ... of null" por la terminal (log del 2026-09-10).
  auto engine = std::make_unique<QQmlApplicationEngine>();
  NetworkClient client;
  // Modo offline (Fase 6/7, ver docs/plan-modo-offline.md) -- vive todo el
  // proceso, igual que "client", no solo mientras hay una partida local en
  // curso: así "redcliente" puede reasignarse de vuelta a "client" en
  // cuanto la partida local termina sin perder el objeto. ModoJuegoCoordinador
  // es el único sitio que toca setContextProperty("redcliente", ...) tras
  // este arranque -- ver su comentario.
  LocalGameClient clienteLocal;
  ModoJuegoCoordinador modoJuego(engine->rootContext(), &client, &clienteLocal);
  VersionChecker versionChecker;
  engine->rootContext()->setContextProperty("redcliente", &client);
  engine->rootContext()->setContextProperty("modoJuego", &modoJuego);
  engine->rootContext()->setContextProperty("versionChecker", &versionChecker);
  // Mismo punto único de configuración que el cliente ncurses (ver
  // ServerConfig.hpp) — editar ahí la IP/puerto por defecto, no aquí.
  engine->rootContext()->setContextProperty("SERVER_HOST_DEFAULT",
                                            QString::fromUtf8(net::SERVER_HOST));
  engine->rootContext()->setContextProperty("SERVER_PORT_DEFAULT",
                                            static_cast<int>(net::SERVER_PORT));
  engine->loadFromModule("PokerQuick", "Main");
  const int codigo = app.exec();
  // Primero la interfaz, luego lo que usa (ver la declaración de "engine").
  // modoJuego guarda el rootContext() de este motor, pero solo lo toca desde
  // activarModoLocal()/activarModoRed(), que ya no pueden llamarse.
  engine.reset();
  return codigo;
}
