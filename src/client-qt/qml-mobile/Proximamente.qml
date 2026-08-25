// Proximamente.qml (móvil) — mismo rol que el de escritorio (ver
// src/client-qt/qml/Proximamente.qml): placeholder genérico para
// Ranking/Torneos/Social, sin datos de ejemplo. Tamaños algo más
// compactos que escritorio -- landscape corto, menos alto disponible.
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: raiz
    required property string titulo
    required property string descripcion

    Column {
        anchors.centerIn: parent
        spacing: 12 * Tema.escala
        width: Math.min(360 * Tema.escala, raiz.width - 40 * Tema.escala)

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 56 * Tema.escala
            height: 56 * Tema.escala
            radius: width / 2
            color: "transparent"
            border.width: 1.5
            border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.35)

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
                width: 2 * Tema.escala
                height: 10 * Tema.escala
                color: Tema.colorAccent
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.horizontalCenter
                width: 8 * Tema.escala
                height: 2 * Tema.escala
                color: Tema.colorAccent
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: raiz.titulo
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.pixelSize: 18 * Tema.escala
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: raiz.descripcion
            color: Tema.colorTextoTenue
            font.pixelSize: 12 * Tema.escala
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: textoProximamente.implicitWidth + 24 * Tema.escala
            height: 22 * Tema.escala
            radius: height / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.4)
            Text {
                id: textoProximamente
                anchors.centerIn: parent
                text: "PRÓXIMAMENTE"
                color: Tema.colorAccent
                font.pixelSize: 9 * Tema.escala
                font.letterSpacing: 0.5
            }
        }
    }
}
