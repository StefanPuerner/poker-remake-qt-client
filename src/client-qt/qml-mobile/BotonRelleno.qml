// BotonRelleno.qml (móvil) — el contrario de BotonContorno: relleno por
// defecto, se vacía al PULSAR (no al pasar el dedo, que no existe) — para
// la acción principal de cada pantalla. Mismo cambio que BotonContorno.qml:
// "hovered"→"pressed" y suelo Tema.tamanoMinTactil. Ver Parte 7 del plan de
// diseño móvil, punto 1.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile
import QtQuick.Controls

Button {
    id: botonRelleno
    property color colorBorde: Tema.colorAccent
    property real radioBorde: 6 * Tema.escala
    padding: 10 * Tema.escala
    implicitHeight: Math.max(Tema.tamanoMinTactil,
                              contentItem.implicitHeight + topPadding + bottomPadding)
    background: Rectangle {
        color: botonRelleno.pressed ? "transparent" : botonRelleno.colorBorde
        radius: botonRelleno.radioBorde
        border.width: 1
        border.color: botonRelleno.colorBorde
        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }

        // Brillo metálico — mismo degradado de 3 paradas que escritorio,
        // ver el comentario largo en la versión de escritorio. Aquí se
        // desvanece al pulsar en vez de al pasar el ratón.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: botonRelleno.pressed ? 0 : 1
            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(botonRelleno.colorBorde, 1.35) }
                GradientStop { position: 0.5; color: botonRelleno.colorBorde }
                GradientStop { position: 1.0; color: Qt.darker(botonRelleno.colorBorde, 1.2) }
            }
        }
    }
    contentItem: Text {
        text: botonRelleno.text
        color: botonRelleno.pressed ? botonRelleno.colorBorde : Tema.colorPanel
        font.pixelSize: 14 * Tema.escala
        font.family: Tema.fuenteElegante
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
