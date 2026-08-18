// BotonRelleno.qml — el contrario de BotonContorno: relleno por defecto,
// se vacía al pasar el ratón por encima — para la acción principal de cada
// pantalla, así destaca sobre las secundarias (que usan BotonContorno).
// Extraído de Main.qml.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Button {
    id: botonRelleno
    property color colorBorde: Tema.colorAccent
    property real radioBorde: 6 * Tema.escala
    hoverEnabled: true
    // Ver el comentario largo en BotonContorno.qml: sin esto, el botón
    // entero se quedaba fijo de tamaño pase lo que pase con Tema.escala,
    // porque su sizing implícito dependía de la fuente por defecto de Qt
    // Quick Controls, nunca de la nuestra.
    padding: 10 * Tema.escala
    background: Rectangle {
        color: botonRelleno.hovered ? "transparent" : botonRelleno.colorBorde
        radius: botonRelleno.radioBorde
        border.width: 1
        border.color: botonRelleno.colorBorde
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        // Brillo metálico: capa de degradado de 3 paradas por encima
        // del relleno plano de arriba, que se desvanece junto con él
        // al pasar el ratón — ver "Sistema visual", sección 14/16.
        // Deriva siempre de "colorBorde" (Qt.lighter/darker), así que
        // funciona igual en los cuatro temas sin valores por tema.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: botonRelleno.hovered ? 0 : 1
            Behavior on opacity {
                NumberAnimation { duration: 120 }
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
        color: botonRelleno.hovered ? botonRelleno.colorBorde : Tema.colorPanel
        font.pixelSize: 14 * Tema.escala
        font.family: Tema.fuenteElegante
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
