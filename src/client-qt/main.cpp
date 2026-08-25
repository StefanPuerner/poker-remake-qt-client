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

#include "../../include/net-qt/NetworkClient.hpp"
#include "../../include/net/ServerConfig.hpp"

int main(int argc, char* argv[]) {
#ifdef Q_OS_WIN
  // Windows no trae OpenSSL instalado por defecto (a diferencia de Linux)
  // ni se empaqueta aquí (a diferencia de Android, ver
  // CMakeLists.txt::add_android_openssl_libraries) -- sin esto, QSslSocket
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
  QQmlApplicationEngine engine;
  NetworkClient client;
  engine.rootContext()->setContextProperty("redcliente", &client);
  // Mismo punto único de configuración que el cliente ncurses (ver
  // ServerConfig.hpp) — editar ahí la IP/puerto por defecto, no aquí.
  engine.rootContext()->setContextProperty("SERVER_HOST_DEFAULT",
                                            QString::fromUtf8(net::SERVER_HOST));
  engine.rootContext()->setContextProperty("SERVER_PORT_DEFAULT",
                                            static_cast<int>(net::SERVER_PORT));
  engine.loadFromModule("PokerQuick", "Main");
  return app.exec();
}
