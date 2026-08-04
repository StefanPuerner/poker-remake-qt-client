# Guía 6 — Fundamentos de Qt

Esta guía (6 a 9) es distinta a las anteriores: no explica el proyecto, te
enseña Qt desde cero. Es tu primer contacto con el framework, así que empieza
por aquí antes de mirar `10-migracion-qt.md`, que sí es específico del proyecto.

---

## 1. ¿Qué es Qt?

Qt es un framework de C++ para aplicaciones con interfaz gráfica,
multiplataforma (el mismo código compila en Linux, Windows, macOS, Android,
embedded...). No es solo una librería de widgets: trae su propio sistema de
tipos (`QString`, `QList`, `QVector`...), E/S de red y ficheros, XML/JSON,
concurrencia, y una extensión al propio lenguaje C++ llamada **meta-object
system** (sección 3) que es la base de todo lo demás.

Módulos que vas a usar en este proyecto:

| Módulo | Para qué |
|---|---|
| `QtCore` | Tipos base, señales/slots, event loop — todo depende de esto |
| `QtQml` / `QtQuick` | El motor de QML y los tipos visuales (`Item`, `Rectangle`...) |
| `QtQuickControls2` | Controles ya táctiles (`Button`, `Slider`...) sobre Qt Quick |
| `QtNetwork` | `QTcpSocket` — sustituye a los sockets crudos de las guías 1-2 |
| `QtGui` | Fuentes, colores, tipos base de dibujo (los usa Quick por debajo) |

### Widgets vs QML

Qt tiene dos formas de construir interfaces:

- **Qt Widgets** — C++ puro, imperativo: creas objetos (`QPushButton`,
  `QLabel`...) y los combinas con código. Es el modelo "clásico", más parecido
  a lo que ya conoces de C++, pero pensado para ratón/teclado de escritorio.
- **QML/Qt Quick** — declarativo, con un lenguaje propio (parecido a
  JSON+JavaScript) pensado para interfaces táctiles y muy animadas desde la
  base, con aceleración por GPU.

Este proyecto usa **Qt Quick/QML**, no Widgets: hay intención real de llevar
la interfaz a móvil con controles táctiles más adelante, y Widgets no da una
buena experiencia táctil (fue diseñado para ratón). El precio es que sí hay
un lenguaje nuevo que aprender (QML, guía 7) además de C++ — a cambio, el
día que el móvil se vuelva concreto no hay que reescribir la capa visual
entera. Los fundamentos de esta guía (QObject, señales/slots, event loop)
son exactamente los mismos debajo de Widgets o de Quick — QML es, en el
fondo, otra forma de instanciar y conectar los mismos objetos Qt.

---

## 2. Instalar y comprobar

En Arch (ya lo tienes instalado en este equipo): `qt6-base` trae el núcleo
(Core, Gui, Network, Widgets); Qt Quick/QML vive en un paquete aparte,
`qt6-declarative`.

```bash
sudo pacman -S qt6-base qt6-declarative
```

Comprobar que CMake lo encuentra:

```bash
pkg-config --modversion Qt6Quick
```

---

## 3. QObject y el meta-object system

Todas las clases de Qt con señales/slots heredan de `QObject`. Para que esto
funcione, Qt necesita generar código extra que el compilador de C++ no sabe
producir por sí solo (C++ no tiene introspección — no puede preguntarse en
tiempo de ejecución "¿qué señales tiene esta clase?"). Qt lo resuelve con una
herramienta que se ejecuta ANTES del compilador: **moc** (Meta-Object
Compiler).

```cpp
class MiWidget : public QWidget {
  Q_OBJECT              // ← marca esta clase para moc

 public:
  explicit MiWidget(QWidget* parent = nullptr);

 signals:
  void algoPaso(int valor);

 public slots:
  void hazAlgo();
};
```

`Q_OBJECT` es una macro que expande a métodos ocultos (`metaObject()`,
`qt_metacall()`...). **moc** lee el header, ve `Q_OBJECT`, y genera un fichero
`moc_MiWidget.cpp` con la implementación real de esas señales. CMake hace esto
automáticamente si activas `CMAKE_AUTOMOC` (ya está activado para
`PokerClientQt` — ver `10-migracion-qt.md`, que explica un error de enlazado
muy típico la primera vez que esto falla).

### Ownership: padres e hijos

Qt tiene su propio sistema de gestión de memoria, paralelo al de C++ normal.
Cuando creas un widget con otro como `parent`, Qt lo añade a una jerarquía:

```cpp
auto* boton = new QPushButton("Fold", this);  // 'this' es el padre
```

Cuando el padre se destruye, **destruye automáticamente a todos sus hijos**.
Por eso en Qt es normal ver `new` sin `delete` correspondiente — el padre se
encarga. Sigue siendo C++, sigues pudiendo tener fugas si creas un objeto sin
padre y no lo guardas en ningún sitio, pero el caso común (un widget dentro de
una ventana) se gestiona solo.

---

## 4. Señales y slots — el cambio de paradigma real

Esto es lo más importante de toda la guía. En ncurses, el patrón del proyecto
es **preguntar y bloquear**:

```cpp
// Patrón ncurses (PokerUI::askAction) — bloquea hasta tener una respuesta
net::Message accion = ui.askAction(payload);   // no vuelve hasta que decides
enviar(accion);
```

En Qt, nunca bloqueas esperando una interacción. En su lugar, **conectas** una
señal (algo que "pasó") a un slot (una función que reacciona):

```cpp
QObject::connect(origen, &Origen::algoPaso,
                  destino, &Destino::reaccionar);
```

Cuando `origen` emite `algoPaso()`, Qt llama automáticamente a
`reaccionar()`. Tu código nunca "espera el evento" — simplemente declara qué
debe pasar cuando ocurra, y vuelve al bucle principal inmediatamente. La
construcción de los objetos y la reacción a los eventos quedan separadas: los
conectas UNA VEZ, y la conexión queda activa para siempre (hasta que uno de
los dos objetos se destruye).

Esto no es exclusivo de C++: en QML (guía 7), un `Button { onClicked: ... }`
es exactamente el mismo mecanismo con otra sintaxis — la señal `clicked` de
un botón conectada a un bloque de código que reacciona.

```cpp
// Así se verá NetworkClient (guía 8/10): un QObject normal, sin ningún widget,
// que emite señales cuando llega algo del servidor.
class NetworkClient : public QObject {
  Q_OBJECT
 public:
  void enviarAccion(const Accion& a);   // llamado desde QML

 signals:
  void turnoRecibido(QString payload);  // "algo pasó: es tu turno"
};
```

`NetworkClient` no sabe ni le importa qué hay conectado a `turnoRecibido` —
podría ser un slot de C++ o, como en este proyecto, un handler de QML
(`Connections { onTurnoRecibido: ... }`, guía 7 sección 7).

Quien use `ActionBar` no necesita saber CÓMO se construyó el botón — solo se
conecta a `accionElegida` y reacciona cuando llegue.

---

## 5. El event loop

```cpp
int main(int argc, char* argv[]) {
  QGuiApplication app(argc, argv);   // inicializa Qt (sin Widgets: QGuiApplication)

  QQmlApplicationEngine engine;
  engine.loadFromModule("PokerQuick", "Main");  // carga Main.qml y lo muestra

  return app.exec();                 // ← aquí se queda "para siempre"
}
```

`app.exec()` arranca el **event loop**: un bucle infinito, gestionado por Qt,
que espera eventos (toque, tecla, temporizador, dato de red...) y llama a la
función correspondiente (slot conectado, handler `onXxx` de QML, etc.).
`main()` no vuelve hasta que cierras la ventana — por eso no hay un `while`
escrito a mano como en `client/main.cpp`. Es la misma idea que tu `poll()` de
la guía 2 (esperar a que algo esté listo y reaccionar), pero Qt te esconde el
`poll()` y en su lugar te da señales.

---

## 6. Lo mínimo para arrancar una app

Esto es exactamente lo que hay en `src/client-qt/main.cpp` ahora mismo:

```cpp
#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char* argv[]) {
  QGuiApplication app(argc, argv);

  QQmlApplicationEngine engine;
  engine.loadFromModule("PokerQuick", "Main");

  return app.exec();
}
```

`QGuiApplication` (no `QApplication`, que es la variante con Widgets) más
`QQmlApplicationEngine`, que se encarga de cargar y mostrar el QML. El
primer argumento de `loadFromModule` es el URI del módulo QML declarado en
`CMakeLists.txt` (`qt_add_qml_module(... URI PokerQuick ...)`), el segundo
es el nombre del fichero raíz sin extensión (`Main.qml`).

Y la ventana en sí, en QML — nota que aquí no hay ninguna clase C++, solo el
árbol declarativo de la guía 7:

```qml
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    width: 960
    height: 640
    visible: true
    title: "Mi primera ventana Qt"
}
```

Compílalo (target `PokerClientQt`, ya configurado en `CMakeLists.txt`) y
ejecútalo — deberías ver una ventana vacía. Si no tienes pantalla a mano
(por ejemplo, probando dentro de un contenedor o por SSH), puedes forzar un
backend sin pantalla real para comprobar que al menos arranca sin errores:

```bash
QT_QPA_PLATFORM=offscreen ./PokerClientQt
```

---

## Preguntas de comprensión

1. ¿Qué hace exactamente **moc**, y por qué C++ normal no puede hacerlo solo?
2. Si conectas dos señales/slots y luego destruyes uno de los dos objetos,
   ¿qué pasa con la conexión?
3. ¿Por qué `askAction()` (ncurses) no tiene equivalente directo en Qt? ¿Qué
   patrón lo sustituye?
4. ¿Qué ocurre si nunca llamas a `app.exec()`?
5. Un objeto creado con `new NetworkClient(this)` — ¿quién lo destruye, y cuándo?
