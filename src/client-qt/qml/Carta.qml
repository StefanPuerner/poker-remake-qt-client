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
    // Cara con degradado blanco -> gris claro (para las cartas pequeñas reveladas de los asientos, que
    // se solapan). tonoCara 0 = la de atrás (un poco más gris), 1 = la de delante.
    property bool degradadoCara: false
    property int tonoCara: 1
    readonly property bool conDegradado: degradadoCara && !bocaAbajo
    // Reverso de carta equipado (Fase 1 de "segunda ola de cosméticos",
    // 2026-09-17) -- "" = dorso programático de siempre (el bloque de
    // abajo), cualquier otro valor cambia el dorso por la imagen de ese
    // reverso. Quien decide QUÉ reverso toca (el del dealer, o el propio
    // si es solo-vs-bots) es Mesa.qml -- este componente solo pinta lo
    // que le llega, igual que "codigo" para la cara.
    property string reversoSkin: ""
    function rutaIconoReverso(codigoReverso) {
        return codigoReverso === "" ? ""
             : "qrc:/qt/qml/PokerQuick/assets/iconos/" + codigoReverso + ".png";
    }
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
    // Con un reverso equipado, la carta ES la imagen (llena todo el dorso, con
    // sus esquinas redondeadas ya horneadas): ni relleno ni borde propios, o
    // se veía el PNG pequeño dentro de un marco grueso.
    readonly property bool dorsoConImagen: bocaAbajo && reversoSkin !== ""
    color: dorsoConImagen ? "transparent" : (bocaAbajo ? Tema.colorTapete : "#efe6d3")
    radius: 6 * Tema.escala
    // Base del degradado: sin dithering (se ve a bandas), pero siempre visible. Encima va la capa con
    // dithering, que la cubre entera; si el shader no se dibuja (o falla), esto es lo que queda.
    gradient: conDegradado ? gradienteBase : null
    Gradient {
        id: gradienteBase
        GradientStop { position: 0.0; color: carta.tonoCara === 0 ? "#F4F5F7" : "#FFFFFF" }
        GradientStop { position: 1.0; color: carta.tonoCara === 0 ? "#CDD1D8" : "#DEE1E6" }
    }
    // El mismo degradado con la capa de dithering de la app (assets/shaders/dither.frag): un degradado tan
    // corto se ve a bandas en 8 bits. Va en un hijo DECLARADO ANTES que el texto y los palos (se pinta
    // debajo de ellos), para que ninguno se renderice dentro de la capa.
    Rectangle {
        visible: carta.conDegradado
        anchors.fill: parent
        radius: carta.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: carta.tonoCara === 0 ? "#F4F5F7" : "#FFFFFF" }
            GradientStop { position: 1.0; color: carta.tonoCara === 0 ? "#CDD1D8" : "#DEE1E6" }
        }
        layer.enabled: carta.conDegradado
        layer.effect: ShaderEffect {
            property variant source
            property real amplitud: 30.0
            fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
        }
    }
    border.width: bocaAbajo && !dorsoConImagen ? 2 : 0
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

    // Dorso programático de siempre (sin reverso equipado): marco interior
    // a juego con el borde exterior + emblema centrado, en vez de un
    // patrón importado (barato de mantener, reescala con la carta sin
    // necesitar ninguna imagen).
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
