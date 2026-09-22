//  PokerClientMobile — interfaz táctil/landscape para Android (en construcción)
//
//  Mismo patrón que src/client-qt/main.cpp (cliente de escritorio): un
//  QQmlApplicationEngine cargando un módulo QML propio, con el mismo
//  NetworkClient inyectado como contexto — la capa de red es la única pieza
//  compartida entre escritorio y móvil, ver decisión en la sesión de diseño
//  móvil (árbol QML separado en qml-mobile/).

#include <QDir>
#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QImage>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSslSocket>
#include <QTimer>
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

#ifdef Q_OS_ANDROID
#include <QJniObject>
#include <QtCore/qnativeinterface.h>

// Modo inmersivo "de toda la vida": oculta la barra de estado y la de
// navegación por defecto, y solo reaparecen un momento con un gesto desde
// el borde (SYSTEM_UI_FLAG_IMMERSIVE_STICKY) -- lo que pidió el usuario
// explícitamente, mismo comportamiento que cualquier juego a pantalla
// completa. Qt/QML no tiene una API multiplataforma para esto -- es
// puramente Android, así que hace falta JNI directo a las vistas nativas.
// Se reaplica en cada onResume (applicationStateChanged a Active) porque
// Android limpia estas flags solas al recuperar el foco.
void aplicarPantallaInmersiva() {
  QNativeInterface::QAndroidApplication::runOnAndroidMainThread([]() {
    QJniObject actividad = QNativeInterface::QAndroidApplication::context();
    if (!actividad.isValid()) return;
    QJniObject ventana = actividad.callObjectMethod("getWindow", "()Landroid/view/Window;");
    if (!ventana.isValid()) return;
    QJniObject vistaDecor = ventana.callObjectMethod("getDecorView", "()Landroid/view/View;");
    if (!vistaDecor.isValid()) return;
    // View.SYSTEM_UI_FLAG_LAYOUT_STABLE | LAYOUT_HIDE_NAVIGATION |
    // LAYOUT_FULLSCREEN | HIDE_NAVIGATION | FULLSCREEN | IMMERSIVE_STICKY
    constexpr int flags = 0x00000100 | 0x00000200 | 0x00000400 |
                          0x00000002 | 0x00000004 | 0x00001000;
    vistaDecor.callMethod<void>("setSystemUiVisibility", "(I)V", flags);
  });
}

// Sin esto, Android apaga la pantalla por inactividad TÁCTIL aunque la
// partida siga en marcha (turnos de bots, cartas repartiéndose...) — el
// usuario no está "tocando" nada mientras mira jugar a los demás, así que
// el sistema lo trata igual que si hubiese dejado el móvil olvidado en un
// cajón. No existe una categoría "juego" que resuelva esto sola (el
// atributo android:appCategory="game" del manifest es solo para
// clasificación de batería/datos en Ajustes, no toca el timeout de
// pantalla) — el mecanismo real es este flag de ventana. A diferencia del
// modo inmersivo, Android NO lo limpia solo al recuperar el foco, así que
// basta con aplicarlo una vez al arrancar.
void mantenerPantallaEncendida() {
  QNativeInterface::QAndroidApplication::runOnAndroidMainThread([]() {
    QJniObject actividad = QNativeInterface::QAndroidApplication::context();
    if (!actividad.isValid()) return;
    QJniObject ventana = actividad.callObjectMethod("getWindow", "()Landroid/view/Window;");
    if (!ventana.isValid()) return;
    // WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
    constexpr int flagKeepScreenOn = 0x00000080;
    ventana.callMethod<void>("addFlags", "(I)V", flagKeepScreenOn);
  });
}

// Respaldo directo por JNI de windowLayoutInDisplayCutoutMode="always" del
// manifest -- comprobado en real comparando el AndroidManifest.xml binario
// del APK instalado contra lo que escribe el workflow de CI: el atributo
// desaparecía por completo al compilar (probablemente un choque con uno
// que ya trae la plantilla de Qt en esa misma etiqueta -- ver el
// comentario en build-android-dev.yml). Esto no depende de que el
// manifest se compile bien: pone el campo directamente en el
// WindowManager.LayoutParams de la ventana ya creada, en tiempo de
// ejecución.
void extenderBajoElRecorte() {
  QNativeInterface::QAndroidApplication::runOnAndroidMainThread([]() {
    QJniObject actividad = QNativeInterface::QAndroidApplication::context();
    if (!actividad.isValid()) return;
    QJniObject ventana = actividad.callObjectMethod("getWindow", "()Landroid/view/Window;");
    if (!ventana.isValid()) return;
    QJniObject atributos = ventana.callObjectMethod(
        "getAttributes", "()Landroid/view/WindowManager$LayoutParams;");
    if (!atributos.isValid()) return;
    // WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
    // (el valor "always" es semántica de API 30+; el campo en sí existe
    // desde API 28 -- en un API 28/29 real esto simplemente no tendría
    // efecto especial, sin ninguna regresión posible).
    atributos.setField<jint>("layoutInDisplayCutoutMode", 3);
    ventana.callMethod<void>("setAttributes",
                             "(Landroid/view/WindowManager$LayoutParams;)V",
                             atributos.object());
  });
}
#endif

/// Construye la QFont del chat (familia normal + apoyo de emoji, ver el comentario
/// largo en main()) con el tamaño en píxeles que pida QML cada vez -- necesario porque
/// QML no expone `font.families` (no es una Q_PROPERTY de QFont, a diferencia de
/// `family`) y tampoco se puede combinar `font: unaQFont` con `font.pixelSize: ...` en
/// el mismo Item (error de compilación QML: "Property has already been assigned a
/// value") -- así que el tamaño tiene que venir YA puesto en la QFont que entrega esto,
/// no añadido aparte desde QML. Reactivo de verdad: al ser una llamada dentro del
/// binding (`font: fuenteChat.construir(13 * Tema.escala)`), QML la reevalúa solo
/// cuando cambia Tema.escala, igual que cualquier otra función llamada en un binding.
class FuenteChat : public QObject {
  Q_OBJECT
 public:
  explicit FuenteChat(QFont base, QObject* padre = nullptr) : QObject(padre), base_(std::move(base)) {}
  Q_INVOKABLE QFont construir(qreal pixelSize) const {
    QFont f = base_;
    f.setPixelSize(static_cast<int>(pixelSize));
    return f;
  }

 private:
  QFont base_;
};

int main(int argc, char* argv[]) {
  QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
      Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

  // Las imágenes de 256 px o más NO van al atlas de texturas de Qt. Ver el
  // comentario gemelo en src/client-qt/main.cpp; aquí va entero porque el
  // móvil es donde más se nota (pantallas pequeñas, iconos muy encogidos).
  //
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
  // Solo relevante cuando PokerClientMobile se compila como binario de
  // escritorio normal en Windows (ver el comentario en cmake/ClientesQt.cmake) --
  // mismo motivo y mismo orden que en src/client-qt/main.cpp (bug real,
  // 2026-09-16): tiene que ir DESPUÉS de construir QGuiApplication, o
  // QSslSocket no ve el plugin tls\qschannelbackend.dll que deja
  // windeployqt junto al .exe (Qt solo añade el directorio del propio
  // .exe a sus rutas de plugins una vez que QCoreApplication existe).
  if (!QSslSocket::setActiveBackend(QStringLiteral("schannel"))) {
    qWarning() << "No se pudo activar el backend TLS Schannel -- las "
                  "conexiones al servidor probablemente fallarán.";
  }
#endif
  // Mismo motivo que en src/client-qt/main.cpp: fija el estilo de Qt Quick
  // Controls de forma explícita en vez de confiar en el import de
  // "QtQuick.Controls.Material" de qml-mobile/Main.qml para seleccionarlo
  // solo -- en Windows el estilo nativo gana por defecto y no soporta la
  // personalización de background/contentItem que usan los componentes.
  QQuickStyle::setStyle(QStringLiteral("Material"));
  // Sin esto, Qt.labs.settings (nombre/sonido/tema persistentes, ver
  // qml-mobile/Main.qml) no sabe dónde escribir -- mismo motivo que en el
  // cliente de escritorio (src/client-qt/main.cpp). Nombre de aplicación
  // distinto del de escritorio a propósito: son ajustes independientes,
  // cada cliente guarda los suyos.
  QGuiApplication::setOrganizationName("PokerRemake");
  QGuiApplication::setApplicationName("PokerClientMobile");

  // Soporte de emoji -- ver el comentario en cmake/ClientesQt.cmake (RESOURCES)
  // para el porqué de esta fuente en concreto. Reportado 2026-09-22 (bug real
  // en dispositivo, no solo offscreen): meterla como familia EXTRA de la
  // fuente POR DEFECTO de toda la app (vía QGuiApplication::setFont(), como
  // se hacía antes) dejaba sin pintar los DÍGITOS (0-9) de cualquier Text que
  // no fijara su propio font.family -- que es la inmensa mayoría de la app
  // (versión instalada, estadísticas, fecha de mejor mano...). No es un
  // problema del renderizador offscreen de desarrollo: se confirmó también en
  // un teléfono real. Causa exacta sin confirmar del todo, pero el patrón es
  // claro: una QFont con VARIAS familias (la normal + esta, de color/COLR)
  // falla al pintar dígitos en algún punto del cauce de shaping/render de Qt;
  // una QFont de una sola familia (a mano, `font.family: Tema.fuenteElegante`
  // en vez de heredar la de la app) siempre funciona -- así se fueron
  // parcheando casos sueltos antes de encontrar la causa real.
  // Arreglo real: NO tocar la fuente por defecto de la app. Cargar esta
  // fuente pero dejarla FUERA del family chain global -- se construye una
  // QFont APARTE (fuenteChatBase, expuesta a QML más abajo) con la familia
  // de siempre + esta como apoyo, y solo el ÚNICO sitio que de verdad puede
  // recibir un emoji tecleado por otro jugador (el texto de los mensajes de
  // chat, ChatBox.qml) la usa -- el resto de la app ni se entera. Nota: QML
  // no expone `font.families` (QFont::families() no es una Q_PROPERTY, a
  // diferencia de `family`) -- por eso esto se construye aquí, como una
  // QFont completa, y ChatBox.qml la usa entera vía `font: fuenteChatBase`
  // en vez de intentar montarla campo a campo desde QML.
  const int idFuenteEmoji = QFontDatabase::addApplicationFont(
      QStringLiteral(":/qt/qml/PokerQuickMobile/assets/fonts/TwemojiMozilla.ttf"));
  QFont fuenteChatBase = QGuiApplication::font();
  if (idFuenteEmoji != -1) {
    const QStringList familiasEmoji = QFontDatabase::applicationFontFamilies(idFuenteEmoji);
    if (!familiasEmoji.isEmpty()) {
      QStringList familiasChat = fuenteChatBase.families();
      if (familiasChat.isEmpty()) familiasChat << fuenteChatBase.family();
      familiasChat << familiasEmoji.first();
      fuenteChatBase.setFamilies(familiasChat);
    }
  } else {
    qWarning() << "No se pudo cargar la fuente de apoyo para emoji (Twemoji Mozilla) -- "
                  "los emoji de verdad tecleados por otros jugadores pueden verse en blanco.";
  }
  // Destruido a mano al salir -- ver el comentario gemelo en
  // src/client-qt/main.cpp.
  auto engine = std::make_unique<QQmlApplicationEngine>();
  NetworkClient client;
  // Modo offline -- ver el comentario gemelo en src/client-qt/main.cpp.
  LocalGameClient clienteLocal;
  ModoJuegoCoordinador modoJuego(engine->rootContext(), &client, &clienteLocal);
  VersionChecker versionChecker;
  LectorRecursos lectorRecursos;
  engine->rootContext()->setContextProperty("redcliente", &client);
  engine->rootContext()->setContextProperty("modoJuego", &modoJuego);
  engine->rootContext()->setContextProperty("versionChecker", &versionChecker);
  // Lectura de recursos qrc desde QML (XMLHttpRequest no puede leer "qrc:"): la config de sonidos.
  engine->rootContext()->setContextProperty("recursos", &lectorRecursos);
  // Pestaña Torneos en desarrollo: apagada en los releases (ver
  // POKER_TORNEOS en cmake/ClientesQt.cmake).
  engine->rootContext()->setContextProperty("torneosHabilitados", POKER_TORNEOS != 0);
  engine->rootContext()->setContextProperty("SERVER_HOST_DEFAULT",
                                            QString::fromUtf8(net::SERVER_HOST));
  engine->rootContext()->setContextProperty("SERVER_PORT_DEFAULT",
                                            static_cast<int>(net::SERVER_PORT));
  // Ver el comentario largo de más arriba (carga de TwemojiMozilla.ttf) -- el único
  // consumidor pensado es el texto de los mensajes de ChatBox.qml, vía
  // `font: fuenteChat.construir(tamañoEnPíxeles)`. Propiedad del engine (como
  // "client"/"modoJuego" más abajo) para que viva mientras la app viva.
  auto* fuenteChat = new FuenteChat(fuenteChatBase, engine.get());
  engine->rootContext()->setContextProperty("fuenteChat", fuenteChat);

#ifdef Q_OS_ANDROID
  aplicarPantallaInmersiva();
  mantenerPantallaEncendida();
  extenderBajoElRecorte();
  QObject::connect(&app, &QGuiApplication::applicationStateChanged, [&client](Qt::ApplicationState estado) {
    if (estado == Qt::ApplicationActive) {
      aplicarPantallaInmersiva();
      extenderBajoElRecorte();
      // Android puede congelar el bucle de eventos entero mientras el
      // móvil está suspendido -- el QTimer de reintento de NetworkClient
      // no dispara ni una vez durante ese tiempo. Sin este empujón, al
      // volver había que esperar a que ese timer despertase solo (o,
      // antes del fix en NetworkClient::intentarReconexionAhora(), se
      // quedaba en un bucle que nunca se agotaba). Forzar un intento
      // aquí mismo resuelve la reconexión (o la da por perdida, si ya
      // pasaron los 60s reales) en el instante en que el usuario vuelve
      // a mirar la pantalla, no en el siguiente tick que le toque.
      client.intentarReconexionAhora();
    }
  });
#endif

  // Herramientas de desarrollo (no las usa el jugador), gemelas de las de src/client-qt/main.cpp:
  //   --demo-local             arranca sin conexión una partida contra 3 bots y la juega sola
  //   --demo-sin-voto          deja abierto el panel de decisiones de fin de mano
  //   --llamar FN              llama a una función de Main.qml al arrancar
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
    else if (args[i] == "--llamar" && i + 1 < args.size()) llamar = args[++i];
    else if (args[i] == "--demo-sin-voto") demoNoVota = true;
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
  engine->loadFromModule("PokerQuickMobile", "Main");
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

// FuenteChat tiene Q_OBJECT y está definida aquí mismo (no en un header) -- AUTOMOC
// necesita este include explícito para generar su moc (mismo patrón que exige CMake
// para cualquier Q_OBJECT declarado directamente en un .cpp).
#include "main-mobile.moc"
