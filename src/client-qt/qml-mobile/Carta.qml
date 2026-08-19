// Carta.qml (móvil) — idéntica a la de escritorio: puramente informativa,
// sin MouseArea/hover, no necesita ningún cambio para tacto.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Rectangle {
    readonly property bool bocaAbajo: codigo.length === 0
    property string codigo
    property string rango: codigo.slice(0, codigo.length - 1)
    property string letraPalo: codigo.slice(-1)
    readonly property string palo: letraPalo === "H" ? "♥" : letraPalo === "D" ? "♦" : letraPalo === "C" ? "♣" : letraPalo === "S" ? "♠" : "?"
    property bool propia: false
    readonly property bool esRojo: letraPalo === "H" || letraPalo === "D"
    readonly property int tamanoFuente: Math.round(width * 0.20)
    readonly property int margen: Math.round(width * 0.12)
    readonly property int separacionAro: Math.round(width * 0.08)
    color: bocaAbajo ? Tema.colorTapete : "#efe6d3"
    radius: 6 * Tema.escala
    border.width: bocaAbajo ? 2 : 0
    border.color: Tema.colorAccent
    width: (propia ? 80 : 60) * Tema.escala
    height: (propia ? 112 : 80) * Tema.escala

    Rectangle {
        visible: propia && !bocaAbajo
        anchors.centerIn: parent
        width: parent.width + separacionAro
        height: parent.height + separacionAro
        radius: parent.radius + separacionAro / 2
        color: "transparent"
        border.width: 2
        border.color: Tema.colorAccent
    }

    Rectangle {
        visible: bocaAbajo
        anchors.fill: parent
        anchors.margins: Math.round(parent.width * 0.14)
        radius: 4 * Tema.escala
        color: "transparent"
        border.width: 1
        border.color: Tema.colorAccent
        opacity: 0.7
    }
    Text {
        visible: bocaAbajo
        anchors.centerIn: parent
        text: "♣"
        color: Tema.colorAccent
        font.pixelSize: Math.round(parent.width * 0.4)
        font.family: Tema.fuenteElegante
        opacity: 0.8
    }

    Column {
        visible: !bocaAbajo
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: margen
        Text {
            text: rango
            color: esRojo ? "#c96a5c" : "#182019"
            font.pixelSize: tamanoFuente
            font.family: Tema.fuenteElegante
            font.bold: true
        }
        Text {
            text: palo
            color: esRojo ? "#c96a5c" : "#182019"
            font.pixelSize: tamanoFuente
            font.family: Tema.fuenteElegante
            font.bold: true
        }
    }
    Column {
        visible: !bocaAbajo
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: margen
        Text {
            text: rango
            color: esRojo ? "#c96a5c" : "#182019"
            font.pixelSize: tamanoFuente
            font.family: Tema.fuenteElegante
            font.bold: true
        }
        Text {
            text: palo
            color: esRojo ? "#c96a5c" : "#182019"
            font.pixelSize: tamanoFuente
            font.family: Tema.fuenteElegante
            font.bold: true
        }
    }
}
