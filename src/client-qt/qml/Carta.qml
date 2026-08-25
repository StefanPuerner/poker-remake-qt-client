// Carta.qml — una carta de la baraja (o su dorso, si no se pasa "codigo").
// Extraída de Main.qml — ver Tema.qml para de dónde salen "Tema.colorX"/
// "Tema.escala"/"Tema.fuenteElegante".
pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: carta
    // "bocaAbajo" o codigo vacío: dorso de carta (comunitaria todavía
    // no revelada). Con codigo real, siempre se ve la cara — así que
    // basta con no pasar "codigo" (o pasar "") para pedir un dorso.
    readonly property bool bocaAbajo: codigo.length === 0
    property string codigo
    property string rango: codigo.slice(0, codigo.length - 1)
    // El servidor manda la letra cruda del palo (H/D/C/S); PaloIcono la
    // dibuja directamente (ver ese fichero) -- ya no hace falta derivar
    // un símbolo Unicode de texto a partir de ella.
    property string letraPalo: codigo.slice(-1)
    property bool propia: false
    readonly property bool esRojo: letraPalo === "H" || letraPalo === "D"
    // Proporcional al propio tamaño de la carta, no un número fijo — así
    // si el ancho cambia (otra pantalla, otro contexto), el texto escala con él.
    readonly property int tamanoFuente: Math.round(width * 0.20)
    // Margen entre el índice de esquina y el borde de la carta, también
    // proporcional — para que no quede pegado si el tamaño cambia.
    readonly property int margen: Math.round(width * 0.12)
    // Separación entre el borde real de la carta y el aro dorado — QML no
    // tiene el "outline-offset" de CSS (un borde que flota fuera del
    // elemento, con hueco), así que se imita con un Rectangle aparte, sin
    // relleno, más grande que la carta y centrado sobre ella.
    readonly property int separacionAro: Math.round(width * 0.08)
    color: bocaAbajo ? Tema.colorTapete : "#efe6d3"
    radius: 6 * Tema.escala
    border.width: bocaAbajo ? 2 : 0
    border.color: Tema.colorAccent
    width: (propia ? 80 : 60) * Tema.escala // medidas quasi aleatorias, habra que ver lo que sea ideal
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

    // Dorso: marco interior a juego con el borde exterior + emblema
    // centrado, en vez de un patrón importado (barato de mantener,
    // reescala con la carta sin necesitar ninguna imagen).
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
    PaloIcono {
        visible: bocaAbajo
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.4)
        height: width
        letraPalo: "C"
        colorPalo: Tema.colorAccent
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
        PaloIcono {
            width: tamanoFuente
            height: width
            letraPalo: carta.letraPalo
            colorPalo: esRojo ? "#c96a5c" : "#182019"
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
        PaloIcono {
            width: tamanoFuente
            height: width
            letraPalo: carta.letraPalo
            colorPalo: esRojo ? "#c96a5c" : "#182019"
        }
    }
}
