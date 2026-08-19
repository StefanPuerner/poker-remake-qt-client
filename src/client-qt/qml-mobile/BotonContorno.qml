// BotonContorno.qml (móvil) — mismo botón "de contorno" del cliente de
// escritorio (fondo transparente, borde de color temático), pero con
// feedback táctil: "pressed" en vez de "hovered" (no existe hover sin
// ratón), y un suelo de alto (Tema.tamanoMinTactil) para que el botón
// nunca quede por debajo del tamaño mínimo accesible al tacto, aunque la
// escala calculada para ese dispositivo diera un número menor. Ver Parte 7
// del plan de diseño móvil, punto 1.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile
import QtQuick.Controls

Button {
    id: botonContorno
    property color colorBorde: Tema.colorAccent
    property real radioBorde: 6 * Tema.escala
    padding: 10 * Tema.escala
    implicitHeight: Math.max(Tema.tamanoMinTactil,
                              contentItem.implicitHeight + topPadding + bottomPadding)
    background: Rectangle {
        color: botonContorno.pressed ? botonContorno.colorBorde : "transparent"
        radius: botonContorno.radioBorde
        border.width: 1
        border.color: botonContorno.colorBorde
        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }
    }
    contentItem: Text {
        text: botonContorno.text
        color: botonContorno.pressed ? Tema.colorPanel : botonContorno.colorBorde
        font.pixelSize: 14 * Tema.escala
        font.family: Tema.fuenteElegante
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
