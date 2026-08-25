// Proximamente.qml — placeholder genérico para las pantallas "hub" que
// todavía no tienen backend real detrás (Ranking/Torneos/Social, ver
// RielNavegacion.qml). Un único componente para las tres, solo cambia
// título/descripción -- deliberadamente sin datos de ejemplo (ninguna
// tabla de ranking ni lista de amigos "de mentira"): mostrar eso sería un
// dato falso presentado como real. player_stats existe en el esquema SQL
// pero está vacío; torneos/social no tienen esquema todavía.
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: raiz
    required property string titulo
    required property string descripcion

    Column {
        anchors.centerIn: parent
        spacing: 18 * Tema.escala
        width: Math.min(420 * Tema.escala, raiz.width - 60 * Tema.escala)

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 88 * Tema.escala
            height: 88 * Tema.escala
            radius: width / 2
            color: "transparent"
            border.width: 1.5
            border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.35)

            // Reloj sencillo (dos manecillas) en vez de un icono importado
            // -- mismo criterio "barato" que el resto de glifos de la
            // interfaz (ver RielNavegacion.qml).
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
                width: 2 * Tema.escala
                height: 16 * Tema.escala
                color: Tema.colorAccent
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.horizontalCenter
                width: 12 * Tema.escala
                height: 2 * Tema.escala
                color: Tema.colorAccent
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: raiz.titulo
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.pixelSize: 22 * Tema.escala
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: raiz.descripcion
            color: Tema.colorTextoTenue
            font.pixelSize: 13 * Tema.escala
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: textoProximamente.implicitWidth + 28 * Tema.escala
            height: 26 * Tema.escala
            radius: height / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.4)
            Text {
                id: textoProximamente
                anchors.centerIn: parent
                text: "PRÓXIMAMENTE"
                color: Tema.colorAccent
                font.pixelSize: 10 * Tema.escala
                font.letterSpacing: 0.5
            }
        }
    }
}
