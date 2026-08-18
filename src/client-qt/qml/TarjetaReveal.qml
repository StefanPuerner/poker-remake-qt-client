// TarjetaReveal.qml — una tarjeta del showdown: nombre, cartas, combo, y
// el badge animado de premio si ganó. Extraído de Main.qml.
pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: tarjetaReveal
    required property var datos
    width: 130 * Tema.escala
    // Altura según el contenido, no fija — con "cartas: []" (ganó sin
    // showdown real, ver repartirBotes()) la fila de cartas
    // desaparece, y una altura fija de sobra dejaba un hueco vacío
    // enorme en medio de la tarjeta.
    height: columnaTarjetaReveal.height + 28 * Tema.escala
    radius: 12 * Tema.escala
    color: datos.esGanador ? Qt.rgba(0.75, 0.56, 0.24, 0.10) : "transparent"
    border.width: datos.esGanador ? 2 : 1
    border.color: datos.esGanador ? Tema.colorAccent : Tema.colorBorde

    Column {
        id: columnaTarjetaReveal
        anchors.centerIn: parent
        spacing: 8 * Tema.escala

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tarjetaReveal.datos.nombre
            color: tarjetaReveal.datos.esGanador ? Tema.colorAccent : "white"
            font.bold: tarjetaReveal.datos.esGanador
            font.pixelSize: 14 * Tema.escala
            font.family: Tema.fuenteElegante
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4 * Tema.escala
            Repeater {
                model: tarjetaReveal.datos.cartas
                delegate: Carta {
                    required property string modelData
                    codigo: modelData
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tarjetaReveal.datos.combo
            color: Tema.colorTextoTenue
            font.pixelSize: 11 * Tema.escala
        }
        Rectangle {
            visible: tarjetaReveal.datos.esGanador
            anchors.horizontalCenter: parent.horizontalCenter
            width: textoGanancia.implicitWidth + 16 * Tema.escala
            height: 20 * Tema.escala
            radius: 10 * Tema.escala
            color: Tema.colorAccent
            clip: true

            // Brillo animado — el único sitio "hero" del programa donde
            // se justifica (ver "Sistema visual", sección 16): una
            // franja clara que cruza en diagonal cada pocos segundos.
            // Nunca en botones normales — ahí competiría con lo que de
            // verdad hay que mirar.
            Rectangle {
                width: 10 * Tema.escala
                height: parent.height * 2.4
                rotation: 22
                anchors.verticalCenter: parent.verticalCenter
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.55) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                SequentialAnimation on x {
                    running: tarjetaReveal.datos.esGanador
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: -20; to: textoGanancia.implicitWidth + 30
                        duration: 1400; easing.type: Easing.InOutQuad
                    }
                    PauseAnimation { duration: 1800 }
                }
            }

            Text {
                id: textoGanancia
                anchors.centerIn: parent
                text: "+" + tarjetaReveal.datos.premio
                color: Tema.colorPanel
                font.bold: true
                font.pixelSize: 11 * Tema.escala
            }
        }
    }
}
