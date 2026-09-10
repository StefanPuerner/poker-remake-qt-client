// main.cpp (AvatarTest) — banco de pruebas standalone para los marcos y
// los cosméticos de avatar, ANTES de integrarlos en Asiento/Ranking/
// Tienda de verdad. Sin NetworkClient ni nada de red: solo carga el mismo
// Tema.qml/Avatar.qml que usará el cliente real, para ver los marcos con
// los colores/fuente exactos de la app sin arrancar servidor ni partida.
//
// Órdenes (todas opcionales):
//   --solo-cosmeticos   solo la parte de Fase 5 (texturas y decoraciones),
//                       que así cabe entera en la ventana
//   --tema N            índice de paleta de Tema.qml (0 = Verde clásico,
//                       4 = Porcelana dorada, el tema CLARO)
//   --captura RUTA      guarda un PNG de la ventana y sale
//
// El "--captura" existe por un motivo concreto: revisar un cosmético
// obliga a mirarlo, y mirarlo en los dos extremos de tema. Poder sacar
// las dos capturas de una orden hace que se revise de verdad, en vez de
// dar por bueno que "compila".
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QTimer>

#include <iostream>

int main(int argc, char* argv[]) {
  QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
      Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);
  QGuiApplication app(argc, argv);

  bool soloCosmeticos = false;
  int tema = 0;
  QString rutaCaptura;
  const QStringList args = QCoreApplication::arguments();
  for (int i = 1; i < args.size(); ++i) {
    if (args[i] == "--solo-cosmeticos") {
      soloCosmeticos = true;
    } else if (args[i] == "--tema" && i + 1 < args.size()) {
      tema = args[++i].toInt();
    } else if (args[i] == "--captura" && i + 1 < args.size()) {
      rutaCaptura = args[++i];
    }
  }

  QQmlApplicationEngine engine;
  engine.setInitialProperties({{"soloCosmeticos", soloCosmeticos}, {"temaInicial", tema}});
  engine.loadFromModule("PokerAvatarTest", "Main");
  if (engine.rootObjects().isEmpty()) return 1;

  if (!rutaCaptura.isEmpty()) {
    auto* ventana = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
    if (!ventana) return 1;
    // Un margen generoso a propósito: hay cosméticos ANIMADOS (el brillo
    // de platino, el efecto "pulso") y las imágenes se cargan de forma
    // asíncrona, así que capturar en el primer frame pillaría la ventana
    // a medio montar. Esto es una herramienta de desarrollo, no algo que
    // se ejecute en bucle -- un segundo de más no le cuesta nada a nadie.
    QTimer::singleShot(1200, ventana, [ventana, rutaCaptura]() {
      const QImage imagen = ventana->grabWindow();
      if (imagen.isNull() || !imagen.save(rutaCaptura)) {
        std::cerr << "AvatarTest: no se pudo guardar la captura en "
                  << rutaCaptura.toStdString() << "\n";
        QCoreApplication::exit(1);
        return;
      }
      std::cout << "AvatarTest: captura guardada en " << rutaCaptura.toStdString() << "\n";
      QCoreApplication::quit();
    });
  }
  return app.exec();
}
