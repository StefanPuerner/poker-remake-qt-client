//  PokerClientQt — cliente con interfaz gráfica Qt Quick/QML (en construcción)
//
//  Qt Quick en vez de Qt Widgets: hay intención real de llevar esta interfaz
//  a móvil con controles táctiles más adelante, y Quick está diseñado para
//  tacto y animación fluida desde la base (Widgets no). La lógica de red
//  (NetworkClient, ver docs/guia/10-migracion-qt.md) será C++ igual que aquí;
//  solo la capa visual se escribe en QML.

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QDir>
#include <QTimer>
#include <QQuickWindow>
#include <QImage>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSslSocket>
#include <QDebug>

#include <memory>

#include "../../include/local-qt/LocalGameClient.hpp"
#include "../../include/local-qt/ModoJuegoCoordinador.hpp"
#include "../../include/net-qt/NetworkClient.hpp"
#include "../../include/net-qt/VersionChecker.hpp"
#include "../../include/net-qt/LectorRecursos.hpp"
#include "../../include/net/ServerConfig.hpp"

// Lo pone cmake/ClientesQt.cmake (POKER_TORNEOS); 0 si no llega.
#ifndef POKER_TORNEOS
#define POKER_TORNEOS 0
#endif

int main(int argc, char* argv[]) {
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

  // Las imágenes de 256 px o más NO van al atlas de texturas de Qt.
  // Todas las nuestras (iconos de 512, naipes de 320) se pintan con mipmap,
  // y una Image con mipmap saca su textura del atlas (QQuickImage::
  // updatePaintNode → removedFromAtlas()). Si el atlas ya la había subido a
  // la GPU, ya no guarda la QImage (la suelta al subirla), la copia sale sin
  // datos y Qt IGNORA el mipmap: el icono se ve dentado igual, y solo lo
  // delata un "QSGPlainTexture: Mipmap settings changed without having image
  // data available" (9 veces en el log del móvil del 2026-09-10). El límite
  // por defecto es la mitad del atlas, que crece con la ventana (1024 px con
  // una de 1920 de ancho), así que los iconos caían dentro. 256 es lo que
  // Qt usa con la ventana más pequeña; las imágenes pequeñas de verdad siguen
  // aprovechando el atlas. Solo si nadie lo ha fijado ya desde fuera.
  if (!qEnvironmentVariableIsSet("QSG_ATLAS_SIZE_LIMIT")) {
    qputenv("QSG_ATLAS_SIZE_LIMIT", "256");
  }

  QGuiApplication app(argc, argv);
#ifdef Q_OS_WIN
  // Windows no trae OpenSSL instalado por defecto (a diferencia de Linux)
  // ni se empaqueta aquí (a diferencia de Android, ver
  // cmake/ClientesQt.cmake::add_android_openssl_libraries) -- sin esto, QSslSocket
  // intenta el backend OpenSSL por defecto, no encuentra sus .dll y el
  // *handshake* TLS del servidor nunca llega a completarse (confirmado en
  // real: el build de Windows no conectaba). Schannel es el backend TLS
  // NATIVO de Windows -- viene con el sistema operativo, cero .dll que
  // empaquetar.
  //
  // Tiene que fijarse DESPUÉS de construir QGuiApplication, no antes
  // (bug real, 2026-09-16): Qt solo añade el directorio del propio .exe
  // -- donde windeployqt/el paso "Asegurar el plugin TLS" del workflow
  // dejan tls\qschannelbackend.dll -- a sus rutas de búsqueda de plugins
  // una vez que QCoreApplication existe (necesita argv[0] para calcular
  // applicationDirPath()). Llamar a esto antes de QGuiApplication hacía
  // que QSslSocket no viera ese plugin aunque estuviera físicamente en la
  // carpeta, y setActiveBackend fallaba con "Cannot set unavailable
  // backend named schannel as active" -- el cliente de Windows solo podía
  // jugar offline desde que se introdujo TLS.
  if (!QSslSocket::setActiveBackend(QStringLiteral("schannel"))) {
    qWarning() << "No se pudo activar el backend TLS Schannel -- las "
                  "conexiones al servidor probablemente fallarán.";
  }
#endif
  // Fija el estilo de Qt Quick Controls de forma explícita, en vez de
  // confiar en el import de "QtQuick.Controls.Material" de Main.qml para
  // seleccionarlo solo. Sin esto, en Linux el estilo por defecto resulta
  // "Fusion" (soporta personalizar background/contentItem, como hacen
  // BotonContorno/BotonRelleno/CampoTexto/MarcoHueco -- cero avisos), pero
  // en Windows gana el estilo nativo "Windows", que NO soporta esa
  // personalización -- de ahí los cientos de "The current style does not
  // support customization" en la consola de Windows (bug real,
  // 2026-09-16), y probablemente también los avisos de DirectWrite por
  // "MS Sans Serif" (ese estilo nativo consulta fuentes de diálogo
  // clásicas de Win32 que este estilo no necesita). Debe fijarse antes de
  // que el motor QML cargue cualquier QML que importe Qt Quick Controls.
  QQuickStyle::setStyle(QStringLiteral("Material"));
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
  LectorRecursos lectorRecursos;
  engine->rootContext()->setContextProperty("redcliente", &client);
  engine->rootContext()->setContextProperty("modoJuego", &modoJuego);
  engine->rootContext()->setContextProperty("versionChecker", &versionChecker);
  engine->rootContext()->setContextProperty("recursos", &lectorRecursos);
  // Pestaña Torneos en desarrollo: apagada en los releases (ver
  // POKER_TORNEOS en cmake/ClientesQt.cmake).
  engine->rootContext()->setContextProperty("torneosHabilitados", POKER_TORNEOS != 0);
  // Mismo punto único de configuración que el cliente ncurses (ver
  // ServerConfig.hpp) — editar ahí la IP/puerto por defecto, no aquí.
  engine->rootContext()->setContextProperty("SERVER_HOST_DEFAULT",
                                            QString::fromUtf8(net::SERVER_HOST));
  engine->rootContext()->setContextProperty("SERVER_PORT_DEFAULT",
                                            static_cast<int>(net::SERVER_PORT));
  // Herramientas de desarrollo (no las usa el jugador): una partida local que se juega sola para
  // comprobar la mesa con eventos reales del motor, y una captura de la ventana.
  //   --demo-local             arranca sin conexión una partida contra 3 bots y la juega sola
  //   --captura RUTA [--retraso-captura MS]   guarda un PNG de la ventana y sale
  //   --serie DIR --cada MS --n N   guarda N capturas (una cada MS) en DIR y sale
  //   --tam ANCHOxALTO         tamaño de la ventana (la de sin pantalla es pequeña)
  bool demoLocal = false;
  bool demoNoVota = false;
  QString llamar;
  QString rutaCaptura;
  int retrasoCaptura = 5000;
  QString dirSerie;
  int cadaMs = 1000, nSerie = 10;
  int anchoVentana = 0, altoVentana = 0;
  const QStringList args = QCoreApplication::arguments();
  for (int i = 1; i < args.size(); ++i) {
    if (args[i] == "--demo-local") demoLocal = true;
    else if (args[i] == "--llamar" && i + 1 < args.size()) llamar = args[++i];   // función de Main.qml
    else if (args[i] == "--demo-sin-voto") demoNoVota = true;   // deja abierto el panel de decisiones
    else if (args[i] == "--captura" && i + 1 < args.size()) rutaCaptura = args[++i];
    else if (args[i] == "--retraso-captura" && i + 1 < args.size()) retrasoCaptura = args[++i].toInt();
    else if (args[i] == "--serie" && i + 1 < args.size()) dirSerie = args[++i];
    else if (args[i] == "--cada" && i + 1 < args.size()) cadaMs = args[++i].toInt();
    else if (args[i] == "--n" && i + 1 < args.size()) nSerie = args[++i].toInt();
    else if (args[i] == "--tam" && i + 1 < args.size()) {
      const QStringList wh = args[++i].split('x');
      if (wh.size() == 2) { anchoVentana = wh[0].toInt(); altoVentana = wh[1].toInt(); }
    }
  }
  QVariantMap propsIniciales{{"demoAuto", demoLocal}, {"demoNoVota", demoNoVota}};
  if (anchoVentana > 0 && altoVentana > 0) {
    propsIniciales["width"] = anchoVentana;
    propsIniciales["height"] = altoVentana;
  }
  engine->setInitialProperties(propsIniciales);
  engine->loadFromModule("PokerQuick", "Main");
  if (demoLocal && !engine->rootObjects().isEmpty()) {
    QObject* raiz = engine->rootObjects().first();
    QTimer::singleShot(300, raiz, [raiz]() { QMetaObject::invokeMethod(raiz, "iniciarDemoLocal"); });
  }
  if (!llamar.isEmpty() && !engine->rootObjects().isEmpty()) {
    QObject* raiz = engine->rootObjects().first();
    QTimer::singleShot(300, raiz, [raiz, llamar]() { QMetaObject::invokeMethod(raiz, llamar.toUtf8().constData()); });
  }
  if (!rutaCaptura.isEmpty() && !engine->rootObjects().isEmpty()) {
    auto* ventana = qobject_cast<QQuickWindow*>(engine->rootObjects().first());
    if (ventana) {
      QTimer::singleShot(retrasoCaptura, ventana, [ventana, rutaCaptura]() {
        const QImage imagen = ventana->grabWindow();
        if (imagen.isNull() || !imagen.save(rutaCaptura)) QCoreApplication::exit(1);
        else QCoreApplication::quit();
      });
    }
  }
  if (!dirSerie.isEmpty() && !engine->rootObjects().isEmpty()) {
    auto* ventana = qobject_cast<QQuickWindow*>(engine->rootObjects().first());
    QDir().mkpath(dirSerie);
    if (ventana) {
      auto* reloj = new QTimer(ventana);
      auto* contador = new int(0);
      QObject::connect(reloj, &QTimer::timeout, ventana, [=]() {
        const QImage img = ventana->grabWindow();
        img.save(QString("%1/f_%03d.png").arg(dirSerie).arg(*contador));
        if (++(*contador) >= nSerie) QCoreApplication::exit(0);
      });
      reloj->start(cadaMs);
    }
  }
  const int codigo = app.exec();
  // Primero la interfaz, luego lo que usa (ver la declaración de "engine").
  // modoJuego guarda el rootContext() de este motor, pero solo lo toca desde
  // activarModoLocal()/activarModoRed(), que ya no pueden llamarse.
  engine.reset();
  return codigo;
}
