// RielNavegacion.qml — riel vertical de navegación entre las 4 pantallas
// "hub" post-identidad (Salas/Ranking/Torneos/Social) — separado del
// cajón lateral de ajustes ya existente: el cajón es "quién eres" (tema,
// cuenta, cliente), esto es "a dónde vas". Instancia única en Main.qml
// (no una por pantalla), visible solo mientras "pantalla" sea una de esas
// cuatro. Solo "Salas" tiene funcionalidad real hoy -- las otras tres
// muestran Proximamente.qml (ver ese fichero: sin datos de mentira,
// porque no hay backend real detrás de ninguna de las tres todavía).
pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: riel
    required property string pantallaActual
    signal seccionElegida(string nombre)

    readonly property var secciones: [
        { nombre: "Salas", etiqueta: "SALAS" },
        { nombre: "Ranking", etiqueta: "RANKING" },
        { nombre: "Torneos", etiqueta: "TORNEOS" },
        { nombre: "Social", etiqueta: "SOCIAL" }
    ]

    width: 76 * Tema.escala
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.35)
    // Mismo degradado sutil que BarraSuperior/cajonAjustes -- coherencia
    // visual con el resto de "chrome" de la interfaz.
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
        GradientStop { position: 1.0; color: Tema.colorPanel }
    }

    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 18 * Tema.escala
        spacing: 18 * Tema.escala

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "♣"
            color: Tema.colorAccent
            font.family: Tema.fuenteElegante
            font.pixelSize: 22 * Tema.escala
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32 * Tema.escala
            height: 1
            color: Qt.rgba(1, 1, 1, 0.12)
        }

        Repeater {
            model: riel.secciones
            delegate: Column {
                id: itemRiel
                required property var modelData
                required property int index
                readonly property bool activo: itemRiel.modelData.nombre === riel.pantallaActual
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6 * Tema.escala

                Rectangle {
                    id: cajaIcono
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 48 * Tema.escala
                    height: 48 * Tema.escala
                    radius: 14 * Tema.escala
                    color: itemRiel.activo ? Qt.rgba(1, 1, 1, 0.10)
                           : (areaRiel.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                    border.width: itemRiel.activo ? 1 : 0
                    border.color: Tema.colorAccent

                    // Cuatro glifos geométricos sencillos (sin SVG/iconos
                    // externos, mismo criterio "barato" que el resto de la
                    // interfaz -- ver los tres puntos del botón de ajustes
                    // en BarraSuperior.qml) -- uno visible según el índice.
                    Item {
                        id: glifo
                        anchors.centerIn: parent
                        width: 22 * Tema.escala
                        height: 22 * Tema.escala
                        readonly property color colorIcono: itemRiel.activo ? Tema.colorAccent : Tema.colorTextoTenue

                        // Salas (0): dos barras horizontales -- lista de salas.
                        Rectangle {
                            visible: itemRiel.index === 0
                            x: 0; y: 3 * Tema.escala
                            width: glifo.width; height: 6 * Tema.escala
                            radius: 2 * Tema.escala
                            color: "transparent"
                            border.width: 1.6
                            border.color: glifo.colorIcono
                        }
                        Rectangle {
                            visible: itemRiel.index === 0
                            x: 0; y: 13 * Tema.escala
                            width: glifo.width; height: 6 * Tema.escala
                            radius: 2 * Tema.escala
                            color: "transparent"
                            border.width: 1.6
                            border.color: glifo.colorIcono
                        }

                        // Ranking (1): tres barras a modo de podio.
                        Rectangle {
                            visible: itemRiel.index === 1
                            x: 0; y: 9 * Tema.escala
                            width: 5 * Tema.escala; height: 13 * Tema.escala
                            color: glifo.colorIcono
                        }
                        Rectangle {
                            visible: itemRiel.index === 1
                            x: 8.5 * Tema.escala; y: 3 * Tema.escala
                            width: 5 * Tema.escala; height: 19 * Tema.escala
                            color: glifo.colorIcono
                        }
                        Rectangle {
                            visible: itemRiel.index === 1
                            x: 17 * Tema.escala; y: 12 * Tema.escala
                            width: 5 * Tema.escala; height: 10 * Tema.escala
                            color: glifo.colorIcono
                        }

                        // Torneos (2): llave de eliminatorias (dos líneas
                        // que convergen en una sola).
                        Rectangle {
                            visible: itemRiel.index === 2
                            x: 0; y: 4 * Tema.escala
                            width: 9 * Tema.escala; height: 2 * Tema.escala
                            color: glifo.colorIcono
                        }
                        Rectangle {
                            visible: itemRiel.index === 2
                            x: 0; y: 16 * Tema.escala
                            width: 9 * Tema.escala; height: 2 * Tema.escala
                            color: glifo.colorIcono
                        }
                        Rectangle {
                            visible: itemRiel.index === 2
                            x: 9 * Tema.escala; y: 4 * Tema.escala
                            width: 2 * Tema.escala; height: 14 * Tema.escala
                            color: glifo.colorIcono
                        }
                        Rectangle {
                            visible: itemRiel.index === 2
                            x: 9 * Tema.escala; y: 10 * Tema.escala
                            width: 13 * Tema.escala; height: 2 * Tema.escala
                            color: glifo.colorIcono
                        }

                        // Social (3): dos círculos superpuestos.
                        Rectangle {
                            visible: itemRiel.index === 3
                            x: 1 * Tema.escala; y: 5 * Tema.escala
                            width: 12 * Tema.escala; height: 12 * Tema.escala
                            radius: width / 2
                            color: "transparent"
                            border.width: 1.6
                            border.color: glifo.colorIcono
                        }
                        Rectangle {
                            visible: itemRiel.index === 3
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
                        hoverEnabled: true
                        onClicked: riel.seccionElegida(itemRiel.modelData.nombre)
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: itemRiel.modelData.etiqueta
                    color: itemRiel.activo ? Tema.colorAccent : Tema.colorTextoMuyTenue
                    font.bold: itemRiel.activo
                    font.pixelSize: 9 * Tema.escala
                    font.letterSpacing: 0.5
                }
            }
        }
    }
}
