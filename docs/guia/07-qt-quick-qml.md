# Guía 7 — Qt Quick y QML

Seguimos en fundamentos generales (no del proyecto todavía). Aquí está la
razón real de elegir Qt Quick en vez de Qt Widgets para este proyecto: hay
intención de llevar la interfaz a móvil con controles táctiles, y Quick está
diseñado para eso desde la base. El precio es un lenguaje nuevo — QML — que
aprender junto a C++.

---

## 1. ¿Qué es QML?

Un lenguaje declarativo (parecido a JSON con lógica embebida en JavaScript)
para describir interfaces como un **árbol de objetos con propiedades**:

```qml
import QtQuick

Rectangle {
    width: 200
    height: 100
    color: "steelblue"

    Text {
        anchors.centerIn: parent
        text: "Hola"
        color: "white"
    }
}
```

Cada bloque `Tipo { ... }` crea un objeto; los pares `propiedad: valor` lo
configuran; anidar bloques anida objetos hijos. No hay `new`, no hay punto y
coma obligatorio, no hay que compilarlo tú — Qt lo interpreta (o lo compila
por adelantado, ver `qt_add_qml_module` en la guía 10) en tiempo de carga.

Debajo de esto siguen estando `QObject`, propiedades y señales de la guía 6
— QML es, literalmente, una forma más cómoda de instanciar y conectar
objetos Qt, no un sistema aparte.

---

## 2. `ApplicationWindow` — la raíz

```qml
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    width: 960
    height: 640
    visible: true
    title: "Mi app"

    // el contenido va aquí dentro
}
```

Es el equivalente Quick de `QMainWindow` (guía 7 de Widgets, ya retirada):
la ventana de nivel superior. `visible: true` es necesario explícitamente —
a diferencia de Widgets, donde llamabas a `.show()` desde C++, en QML lo
declaras como una propiedad más.

---

## 3. Posicionamiento: anchors, Row/Column, Layouts

Tres formas distintas, cada una para un caso:

### Anchors — relativo a otro elemento

```qml
Rectangle {
    id: fondo
    anchors.fill: parent          // ocupa todo el padre

    Text {
        anchors.centerIn: parent  // centrado en 'fondo'
    }
    Button {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 12
    }
}
```

Es el sistema más usado en QML — declaras "mi borde X está pegado al borde Y
de otro elemento", y Qt resuelve las posiciones. No hay equivalente directo
en ncurses (ahí todo era `mvwaddstr(win, y, x, ...)` absoluto).

### Row / Column / Grid — apilar elementos

```qml
Column {
    spacing: 8
    Text { text: "Bote: 320" }
    Button { text: "Fold" }
}
```

Parecido a `QVBoxLayout`/`QHBoxLayout` de Widgets, pero es un tipo de
elemento más (`Column`), no un objeto "layout" separado que se le asigna a
un widget.

### Positional Layouts (`QtQuick.Layouts`) — igual que Widgets pero declarativo

```qml
import QtQuick.Layouts

RowLayout {
    Button { text: "Igualar"; Layout.fillWidth: true }
    Button { text: "Subir" }
}
```

Para la mesa ovalada con asientos en posiciones específicas (no una
cuadrícula), ninguno de los tres encaja perfectamente — se usan coordenadas
explícitas (`x`, `y`) calculadas a partir del ángulo de cada asiento, el
equivalente Quick de lo que ya harías con `widget->move(x, y)` en Widgets.

---

## 4. Qt Quick Controls — widgets ya táctiles de fábrica

```qml
import QtQuick.Controls

Button {
    text: "Retirarse"
    onClicked: /* ... */
}

Slider {
    from: minRaise
    to: saldo
    onValueChanged: /* ... */
}

TextField {
    placeholderText: "Escribe..."
    onAccepted: /* Enter pulsado */
}
```

Misma idea que `QPushButton`/`QSlider`/`QLineEdit` de Widgets, pero
dimensionados y con feedback visual pensados para dedo, no solo para
puntero de ratón — de fábrica, sin tocar nada.

---

## 5. Dibujo propio: `Canvas` vs `Shape` vs composición

Para la mesa, las cartas, los indicadores de asiento, tienes tres caminos:

**Composición simple** (lo más común, y probablemente lo que uses para las
cartas): `Rectangle` + `Text` + `Image`, como cualquier otro elemento QML.
Una carta es solo un `Rectangle` blanco redondeado con un `Text` encima.

```qml
Rectangle {
    width: 40; height: 56; radius: 5
    color: "white"
    Text { anchors.centerIn: parent; text: "A♠"; color: "black" }
}
```

**`Canvas`** — dibujo inmediato estilo HTML5 Canvas, con JavaScript:

```qml
Canvas {
    anchors.fill: parent
    onPaint: {
        var ctx = getContext("2d");
        ctx.fillStyle = "#163A2C";
        ctx.fillRect(0, 0, width, height);
    }
}
```

Útil para formas orgánicas (la mesa ovalada de fieltro) que serían
incómodas como composición de rectángulos.

**`Shape`** (`QtQuick.Shapes`) — vectorial declarativo (paths, curvas
Bézier), la opción "correcta" cuando quieres que la forma en sí reaccione a
bindings (p.ej. que el óvalo cambie de tamaño con la ventana de forma
fluida). Más para pulir más adelante que para el primer mockup.

---

## 6. States y Transitions — animación declarativa

Esto es lo que Widgets no tenía de serie y Quick sí: un widget puede
declarar **estados** con valores de propiedad distintos, y Qt anima la
transición entre ellos solo:

```qml
Rectangle {
    id: cartaAsiento
    width: 40; height: 56

    state: activo ? "resaltado" : "normal"

    states: [
        State {
            name: "resaltado"
            PropertyChanges { target: cartaAsiento; scale: 1.15; border.width: 3 }
        },
        State {
            name: "normal"
            PropertyChanges { target: cartaAsiento; scale: 1.0; border.width: 1 }
        }
    ]

    transitions: Transition {
        NumberAnimation { properties: "scale"; duration: 200; easing.type: Easing.OutQuad }
    }
}
```

Cuando `activo` cambia, `state` cambia, y Qt anima automáticamente cualquier
propiedad que difiera entre estados (aquí `scale` y `border.width`) durante
200ms. No hay que orquestar el `QPropertyAnimation` a mano como en Widgets —
declaras el "antes" y el "después", Qt se encarga del "durante".

---

## 7. El puente C++ ↔ QML

Tu lógica de red (`NetworkClient`) sigue siendo C++. Para que QML pueda
usarla, expones una instancia como **propiedad de contexto** antes de cargar
el QML:

```cpp
// main.cpp
NetworkClient cliente;
engine.rootContext()->setContextProperty("redCliente", &cliente);
```

```qml
// Main.qml — ya se puede usar directamente
Button {
    text: "Enviar"
    onClicked: redCliente.enviarAccion(/* ... */)
}

Connections {
    target: redCliente
    function onTurnoRecibido(payload) {
        // actualizar la UI con el payload
    }
}
```

`Q_PROPERTY` en la clase C++ permite además **binding en dos direcciones**
(un cambio en C++ actualiza la UI sola, sin `connect` manual):

```cpp
class NetworkClient : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString bote READ bote NOTIFY boteChanged)
 public:
  QString bote() const { return bote_; }
 signals:
  void boteChanged();
 private:
  QString bote_;
};
```

```qml
Text { text: "Bote: " + redCliente.bote }   // se actualiza sola cuando boteChanged()
```

Esto es lo que hace `10-migracion-qt.md` en detalle para `NetworkClient`.

---

## Preguntas de comprensión

1. ¿Qué diferencia hay entre `anchors.fill: parent` y darle manualmente
   `width`/`height` iguales a los del padre?
2. ¿Por qué la mesa ovalada con asientos en posiciones fijas no encaja bien
   en `Column` ni en `RowLayout`? ¿Qué usarías en su lugar?
3. En el ejemplo de `states`/`transitions`, ¿qué pasaría si quitas el bloque
   `transitions`? ¿Se seguiría animando el cambio de `scale`?
4. ¿Qué necesita una clase C++ para poder usarse desde QML con
   `redCliente.algo()`? ¿Y para que un cambio en C++ actualice la UI sin
   `connect` explícito en QML?
5. ¿Por qué `Qt Quick Controls` es más apropiado que reinventar botones con
   `Rectangle` + `MouseArea` a mano para un proyecto real?
