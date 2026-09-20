// main.cpp (AnimTest) -- banco de pruebas standalone de sonidos y animaciones
// de la mesa, ANTES de integrarlos en la partida de verdad (ver
// docs/plan-animaciones-partida.md). Sin red ni motor: solo QML.
//
// Órdenes (todas opcionales):
//   --sonidos DIR   carpeta de sonidos candidatos: DIR/manifest.json con
//                   [{grupo, nombre, ruta, dur}]. Abre la pestaña de audición,
//                   donde se escucha cada uno y se asigna a un evento.
//   --autoprueba    prueba de humo sin intervención: monta una selección, la guarda,
//                   dispara los eventos y sale con 0 si todo fue bien (1 si no)
//   --autoprueba-showdown  humo de las tres secuencias de showdown (a cuádruple velocidad);
//                   veredicto en DIR/autoprueba-showdown.txt
//   --pestana N     abre la pestaña N (0 = sonidos, 1 = mesa)
//   --velocidad V   velocidad de la escena de la mesa (1, 0.5, 0.25...)
//   --demo          en la pestaña de mesa, reparte una mano al abrir (para capturas)
//   --evento E      con --pestana 1: tras repartir, dispara E (fold, allin, ganar, perder,
//                   eliminado) para capturarlo
//   --origen-dealer las cartas salen del dealer (modo móvil)
//   --retraso-captura MS  espera antes de --captura (por defecto 1200)
//   --tema N        índice de paleta de Tema.qml (0 = Verde clásico)
//   --captura RUTA  guarda un PNG de la ventana y sale
#include <QFile>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>

#include <iostream>

#include "Disco.hpp"

int main(int argc, char* argv[]) {
  QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
      Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);
  if (!qEnvironmentVariableIsSet("QSG_ATLAS_SIZE_LIMIT")) {
    qputenv("QSG_ATLAS_SIZE_LIMIT", "256");
  }
  QGuiApplication app(argc, argv);

  QString dirSonidos;
  QString rutaCaptura;
  int tema = 0;
  bool autoprueba = false;
  bool demo = false;
  bool autopruebaShowdown = false;
  bool origenDealer = false;
  QString evento;
  int retrasoCaptura = 1200;
  int pestana = 0;
  double velocidad = 1.0;
  const QStringList args = QCoreApplication::arguments();
  for (int i = 1; i < args.size(); ++i) {
    if (args[i] == "--sonidos" && i + 1 < args.size()) {
      dirSonidos = args[++i];
    } else if (args[i] == "--autoprueba") {
      autoprueba = true;
    } else if (args[i] == "--autoprueba-showdown") {
      autopruebaShowdown = true;
    } else if (args[i] == "--pestana" && i + 1 < args.size()) {
      pestana = args[++i].toInt();
    } else if (args[i] == "--velocidad" && i + 1 < args.size()) {
      velocidad = args[++i].toDouble();
    } else if (args[i] == "--evento" && i + 1 < args.size()) {
      evento = args[++i];
    } else if (args[i] == "--origen-dealer") {
      origenDealer = true;
    } else if (args[i] == "--retraso-captura" && i + 1 < args.size()) {
      retrasoCaptura = args[++i].toInt();
    } else if (args[i] == "--demo") {
      demo = true;
    } else if (args[i] == "--tema" && i + 1 < args.size()) {
      tema = args[++i].toInt();
    } else if (args[i] == "--captura" && i + 1 < args.size()) {
      rutaCaptura = args[++i];
    }
  }

  QVariantList candidatos;
  if (!dirSonidos.isEmpty()) {
    QFile f(dirSonidos + "/manifest.json");
    if (!f.open(QIODevice::ReadOnly)) {
      std::cerr << "AnimTest: no se pudo leer " << dirSonidos.toStdString() << "/manifest.json\n";
      return 1;
    }
    candidatos = QJsonDocument::fromJson(f.readAll()).array().toVariantList();
  }

  Disco disco;
  QQmlApplicationEngine engine;
  engine.rootContext()->setContextProperty("Disco", &disco);
  engine.setInitialProperties({{"candidatos", candidatos},
                               {"dirSonidos", dirSonidos},
                               {"temaInicial", tema},
                               {"autoprueba", autoprueba},
                               {"pestanaInicial", pestana},
                               {"velocidadInicial", velocidad},
                               {"demo", demo},
                               {"autopruebaShowdown", autopruebaShowdown},
                               {"demoEvento", evento},
                               {"origenDealerInicial", origenDealer}});
  engine.loadFromModule("PokerAnimTest", "Main");
  if (engine.rootObjects().isEmpty()) return 1;

  if (!rutaCaptura.isEmpty()) {
    auto* ventana = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
    if (!ventana) return 1;
    QTimer::singleShot(retrasoCaptura, ventana, [ventana, rutaCaptura]() {
      const QImage imagen = ventana->grabWindow();
      if (imagen.isNull() || !imagen.save(rutaCaptura)) {
        std::cerr << "AnimTest: no se pudo guardar la captura en " << rutaCaptura.toStdString() << "\n";
        QCoreApplication::exit(1);
        return;
      }
      std::cout << "AnimTest: captura guardada en " << rutaCaptura.toStdString() << "\n";
      QCoreApplication::quit();
    });
  }
  return app.exec();
}
