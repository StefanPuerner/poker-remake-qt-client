// Carta.qml (móvil) — idéntica a la de escritorio: puramente informativa,
// sin MouseArea/hover, no necesita ningún cambio para tacto.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Rectangle {
    id: carta
    readonly property bool bocaAbajo: codigo.length === 0
    property string codigo
    property string rango: codigo.slice(0, codigo.length - 1)
    // PaloIcono dibuja el símbolo directamente a partir de esta letra
    // cruda (H/D/C/S) -- ver ese fichero.
    property string letraPalo: codigo.slice(-1)
    property bool propia: false
    // Reverso de carta equipado -- ver el comentario gemelo en
    // src/client-qt/qml/Carta.qml (escritorio).
    property string reversoSkin: ""
    function rutaIconoReverso(codigoReverso) {
        return codigoReverso === "" ? ""
             : "qrc:/qt/qml/PokerQuickMobile/assets/iconos/" + codigoReverso + ".png";
    }
    readonly property bool esRojo: letraPalo === "H" || letraPalo === "D"
    readonly property int tamanoFuente: Math.round(width * 0.20)
    readonly property int margen: Math.round(width * 0.12)
    readonly property int separacionAro: Math.round(width * 0.08)
    // Con un reverso equipado, la carta ES la imagen (llena todo el dorso, con
    // sus esquinas redondeadas ya horneadas): ni relleno ni borde propios, o
    // se veía el PNG pequeño dentro de un marco grueso.
    readonly property bool dorsoConImagen: bocaAbajo && reversoSkin !== ""
    color: dorsoConImagen ? "transparent" : (bocaAbajo ? Tema.colorTapete : "#efe6d3")
    radius: 6 * Tema.escala
    border.width: bocaAbajo && !dorsoConImagen ? 2 : 0
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
        visible: bocaAbajo && carta.reversoSkin === ""
        anchors.fill: parent
        anchors.margins: Math.round(parent.width * 0.14)
        radius: 4 * Tema.escala
        color: "transparent"
        border.width: 1
        border.color: Tema.colorAccent
        opacity: 0.7
    }
    PaloIcono {
        visible: bocaAbajo && carta.reversoSkin === ""
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.4)
        height: width
        letraPalo: "C"
        colorPalo: Tema.colorAccent
        opacity: 0.8
    }
    // Reverso de carta equipado -- sustituye al dorso programático de
    // arriba. mipmap obligatorio (regla del proyecto: si un solo Image
    // que comparte este PNG se la salta, rompe el mipmap para todos los
    // que lo usan).
    Image {
        visible: bocaAbajo && carta.reversoSkin !== ""
        anchors.fill: parent
        source: carta.rutaIconoReverso(carta.reversoSkin)
        // Stretch: el PNG es 3:4 igual que la carta de mesa; la propia (5:7)
        // lo estira un 5%, imperceptible y sin bandas.
        fillMode: Image.Stretch
        mipmap: true
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
