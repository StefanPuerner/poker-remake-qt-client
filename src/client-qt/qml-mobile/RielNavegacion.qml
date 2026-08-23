// RielNavegacion.qml (móvil) — mismo rol que el de escritorio (ver
// src/client-qt/qml/RielNavegacion.qml): riel vertical entre las 4
// pantallas "hub" (Salas/Ranking/Torneos/Social), separado del cajón de
// ajustes. Diferencia deliberada respecto a escritorio (decisión tomada
// en el propio lienzo de diseño): solo icono, sin etiqueta debajo -- en
// landscape corto el alto es el recurso escaso, no el ancho.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Rectangle {
    id: riel
    required property string pantallaActual
    signal seccionElegida(string nombre)

    readonly property var secciones: ["Salas", "Ranking", "Torneos", "Social"]
    // Mismo criterio que el resto de componentes táctiles (ver Tema.qml,
    // móvil): nunca por debajo del suelo de accesibilidad, aunque la
    // escala calculada para el dispositivo diera menos.
    readonly property real tamanoIcono: Math.max(Tema.tamanoMinTactil, 44 * Tema.escala)

    width: riel.tamanoIcono + 20 * Tema.escala
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.35)
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
        GradientStop { position: 1.0; color: Tema.colorPanel }
    }

    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 12 * Tema.escala
        spacing: 12 * Tema.escala

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "♣"
            color: Tema.colorAccent
            font.family: Tema.fuenteElegante
            font.pixelSize: 18 * Tema.escala
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 24 * Tema.escala
            height: 1
            color: Qt.rgba(1, 1, 1, 0.12)
        }

        Repeater {
            model: riel.secciones
            delegate: Rectangle {
                id: cajaIcono
                required property string modelData
                required property int index
                readonly property bool activo: cajaIcono.modelData === riel.pantallaActual
                anchors.horizontalCenter: parent.horizontalCenter
                width: riel.tamanoIcono
                height: riel.tamanoIcono
                radius: 14 * Tema.escala
                color: cajaIcono.activo ? Qt.rgba(1, 1, 1, 0.10) : (areaRiel.pressed ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                border.width: cajaIcono.activo ? 1 : 0
                border.color: Tema.colorAccent

                // Mismos cuatro glifos geométricos que en escritorio (ver
                // RielNavegacion.qml de qml/) -- sin depender de un
                // fichero compartido: ambos árboles QML ya son
                // independientes por diseño en todo el proyecto.
                Item {
                    id: glifo
                    anchors.centerIn: parent
                    width: 22 * Tema.escala
                    height: 22 * Tema.escala
                    readonly property color colorIcono: cajaIcono.activo ? Tema.colorAccent : Tema.colorTextoTenue

                    // Salas (0): dos barras horizontales.
                    Rectangle {
                        visible: cajaIcono.index === 0
                        x: 0; y: 3 * Tema.escala
                        width: glifo.width; height: 6 * Tema.escala
                        radius: 2 * Tema.escala
                        color: "transparent"
                        border.width: 1.6
                        border.color: glifo.colorIcono
                    }
                    Rectangle {
                        visible: cajaIcono.index === 0
                        x: 0; y: 13 * Tema.escala
                        width: glifo.width; height: 6 * Tema.escala
                        radius: 2 * Tema.escala
                        color: "transparent"
                        border.width: 1.6
                        border.color: glifo.colorIcono
                    }

                    // Ranking (1): tres barras a modo de podio.
                    Rectangle {
                        visible: cajaIcono.index === 1
                        x: 0; y: 9 * Tema.escala
                        width: 5 * Tema.escala; height: 13 * Tema.escala
                        color: glifo.colorIcono
                    }
                    Rectangle {
                        visible: cajaIcono.index === 1
                        x: 8.5 * Tema.escala; y: 3 * Tema.escala
                        width: 5 * Tema.escala; height: 19 * Tema.escala
                        color: glifo.colorIcono
                    }
                    Rectangle {
                        visible: cajaIcono.index === 1
                        x: 17 * Tema.escala; y: 12 * Tema.escala
                        width: 5 * Tema.escala; height: 10 * Tema.escala
                        color: glifo.colorIcono
                    }

                    // Torneos (2): llave de eliminatorias.
                    Rectangle {
                        visible: cajaIcono.index === 2
                        x: 0; y: 4 * Tema.escala
                        width: 9 * Tema.escala; height: 2 * Tema.escala
                        color: glifo.colorIcono
                    }
                    Rectangle {
                        visible: cajaIcono.index === 2
                        x: 0; y: 16 * Tema.escala
                        width: 9 * Tema.escala; height: 2 * Tema.escala
                        color: glifo.colorIcono
                    }
                    Rectangle {
                        visible: cajaIcono.index === 2
                        x: 9 * Tema.escala; y: 4 * Tema.escala
                        width: 2 * Tema.escala; height: 14 * Tema.escala
                        color: glifo.colorIcono
                    }
                    Rectangle {
                        visible: cajaIcono.index === 2
                        x: 9 * Tema.escala; y: 10 * Tema.escala
                        width: 13 * Tema.escala; height: 2 * Tema.escala
                        color: glifo.colorIcono
                    }

                    // Social (3): dos círculos superpuestos.
                    Rectangle {
                        visible: cajaIcono.index === 3
                        x: 1 * Tema.escala; y: 5 * Tema.escala
                        width: 12 * Tema.escala; height: 12 * Tema.escala
                        radius: width / 2
                        color: "transparent"
                        border.width: 1.6
                        border.color: glifo.colorIcono
                    }
                    Rectangle {
                        visible: cajaIcono.index === 3
                        x: 9 * Tema.escala; y: 5 * Tema.escala
                        width: 12 * Tema.escala; height: 12 * Tema.escala
                        radius: width / 2
                        color: "transparent"
                        border.width: 1.6
                        border.color: glifo.colorIcono
                    }
                }

                MouseArea {
                    id: areaRiel
                    anchors.fill: parent
                    onClicked: riel.seccionElegida(cajaIcono.modelData)
                }
            }
        }
    }
}
