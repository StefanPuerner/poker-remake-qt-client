// AsientoMini.qml (móvil) — idéntico al de escritorio: no tiene ningún
// MouseArea/hover, solo texto e iconografía informativa, así que no
// necesita ningún cambio para tacto.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Column {
    property string nombre
    spacing: 8 * Tema.escala
    Rectangle {
        x: (parent.width - width) / 2
        width: 48 * Tema.escala
        height: 48 * Tema.escala
        radius: width / 2
        color: Tema.colorPanel
        border.width: 2
        border.color: Tema.colorBorde
        Text {
            anchors.centerIn: parent
            text: nombre.charAt(0)
            color: Tema.colorAccent
            font.pixelSize: 18 * Tema.escala
            font.family: Tema.fuenteElegante
        }
    }
    Text {
        x: (parent.width - width) / 2
        text: nombre
        color: Tema.colorTextoTenue
        font.pixelSize: 11 * Tema.escala
    }
}
