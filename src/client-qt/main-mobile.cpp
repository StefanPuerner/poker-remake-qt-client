//  PokerClientMobile — interfaz táctil/landscape para Android (en construcción)
//
//  Mismo patrón que src/client-qt/main.cpp (cliente de escritorio): un
//  QQmlApplicationEngine cargando un módulo QML propio, con el mismo
//  NetworkClient inyectado como contexto — la capa de red es la única pieza
//  compartida entre escritorio y móvil, ver decisión en la sesión de diseño
//  móvil (árbol QML separado en qml-mobile/).

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QTcpSocket>
#include <QDebug>

#include "../../include/net-qt/NetworkClient.hpp"
#include "../../include/net/ServerConfig.hpp"

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

int main(int argc, char* argv[]) {
  QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
      Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

  QGuiApplication app(argc, argv);
  QQmlApplicationEngine engine;
  NetworkClient client;
  engine.rootContext()->setContextProperty("redcliente", &client);
  engine.rootContext()->setContextProperty("SERVER_HOST_DEFAULT",
                                            QString::fromUtf8(net::SERVER_HOST));
  engine.rootContext()->setContextProperty("SERVER_PORT_DEFAULT",
                                            static_cast<int>(net::SERVER_PORT));

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

  engine.loadFromModule("PokerQuickMobile", "Main");
  return app.exec();
}
