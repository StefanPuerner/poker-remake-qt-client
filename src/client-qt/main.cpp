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
#include <QTcpSocket>
#include <QDebug>

#include "../../include/net-qt/NetworkClient.hpp"
#include "../../include/net/ServerConfig.hpp"

int main(int argc, char* argv[]) {
  QGuiApplication app(argc, argv);
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
