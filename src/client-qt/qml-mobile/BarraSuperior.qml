// BarraSuperior.qml (móvil) — versión reducida de la barra de escritorio,
// usada SOLO en Inicio/Salas/CrearSala (antes de sentarse a jugar). En
// Lobby/Partida/Fin la sustituye IconoAjustes.qml, no esto — ver Parte 7
// del plan de diseño móvil, punto 6. Sin estado de conexión ni
// host:puerto: en escritorio ocupan sitio siempre; aquí no aportan tanto a
// un jugador casual y cuestan una franja horizontal entera en una pantalla
// ya corta de alto — cuando exista el cajón de ajustes móvil, esa info
// vive ahí en vez de aquí. El botón de ajustes usa "pressed" en vez de
// "containsMouse" (no hay hover táctil) y respeta Tema.tamanoMinTactil.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Item {
    id: barra
    property string textoCentro: ""
    signal abrirAjustes()
    height: Math.max(Tema.tamanoMinTactil + 16 * Tema.escala, 56 * Tema.escala)

    Rectangle {
        id: fondoBarra
        anchors.fill: parent
        radius: 14 * Tema.escala
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.3)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.55) }
            GradientStop { position: 1.0; color: Tema.colorPanel }
        }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16 * Tema.escala
            spacing: 8 * Tema.escala
            Text {
                text: "♣"
                color: Tema.colorAccent
                font.pixelSize: 20 * Tema.escala
            }
            Text {
                text: "PokerRemake"
                color: Tema.colorTexto
                font.bold: true
                font.pixelSize: 16 * Tema.escala
                font.family: Tema.fuenteElegante
            }
        }

        Text {
            visible: barra.textoCentro !== ""
            anchors.centerIn: parent
            color: Tema.colorTextoTenue
            text: barra.textoCentro
            font.pixelSize: 13 * Tema.escala
        }

        Rectangle {
            id: botonAjustesBarra
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 12 * Tema.escala
            width: Tema.tamanoMinTactil
            height: Tema.tamanoMinTactil
            radius: width / 2
            border.width: 1
            border.color: areaAjustes.pressed ? Tema.colorAccent : Tema.colorBorde
            color: areaAjustes.pressed ? Tema.colorAccent : "transparent"

            Column {
                anchors.centerIn: parent
                spacing: 3 * Tema.escala
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        width: 4 * Tema.escala
                        height: 4 * Tema.escala
                        radius: width / 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: areaAjustes.pressed ? Tema.colorPanel : Tema.colorTextoTenue
                    }
                }
            }
            MouseArea {
                id: areaAjustes
                anchors.fill: parent
                onClicked: barra.abrirAjustes()
            }
        }
    }
}
