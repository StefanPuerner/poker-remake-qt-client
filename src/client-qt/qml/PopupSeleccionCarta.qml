// PopupSeleccionCarta.qml — selector de "qué carta de la baraja"
// (pedido explícito 2026-08-31: "en el caso de las cartas, ponle un
// signo '+', eso abre un desplegable y eliges una carta cualquiera de
// la baraja, para que puedas comprar justo la carta que quieres").
// Sustituye a la antigua "carta_poker" fija (siempre el as de picas):
// ahora son 52 objetos de tienda sueltos, uno por rango/palo (ver la
// semilla en AccountManager.cpp), y este popup es el único sitio donde
// se eligen -- la tarjeta de la Tienda solo muestra un "+".
//
// Segunda ronda (mismo día, feedback en vivo): SOLO elige, no compra ni
// equipa por sí solo -- "pulsas encima de una, se cierra la ventana, y
// estará seleccionada y se verá en la previsualización, luego hay un
// botón al lado del + para comprar la que está seleccionada". Comprar/
// equipar de verdad vive en la tarjeta "Carta de póker" de la Tienda
// (Main.qml), no aquí.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Popup {
    id: popup
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    // Subido de 760/560 -- las cartas crecieron (pedido explícito
    // 2026-08-31: "aprovechar para hacer las cartas más grandes").
    width: Math.min(920 * Tema.escala, (parent ? parent.width : 920) - 60 * Tema.escala)
    height: Math.min(620 * Tema.escala, (parent ? parent.height : 620) - 60 * Tema.escala)
    padding: 20 * Tema.escala
    // Tamaño de cada carta del selector -- un único sitio, usado tanto
    // por el ancho de las filas como por cada celda (ver más abajo).
    readonly property real anchoCelda: 58 * Tema.escala
    readonly property real altoCelda: 80 * Tema.escala

    // Elegida cerrar el popup: onCartaElegida(codigo) -- Main.qml decide
    // qué hacer con ella (previsualizarla y ofrecer Comprar/Equipar en
    // la propia tarjeta de la Tienda).
    signal cartaElegida(string codigo)

    // Las 52 filas de tiendaCrudo con codigo "carta_*" (poseido/equipado
    // ya vienen de ahí, no hace falta pedirle nada nuevo al servidor).
    property var cartas: []
    property string decoracionLateral1: ""
    property string decoracionLateral2: ""
    // La carta actualmente elegida (Main.qml::cartaSeleccionada) -- solo
    // para resaltarla aquí dentro si se reabre el selector.
    property string seleccionActual: ""

    readonly property var suits: ["treboles", "diamantes", "corazones", "picas"]
    readonly property var suitsNombre: ({
        "treboles": "Tréboles", "diamantes": "Diamantes",
        "corazones": "Corazones", "picas": "Picas"
    })
    readonly property var rangos: ["2", "3", "4", "5", "6", "7", "8", "9", "10",
                                    "jack", "queen", "king", "ace"]

    function cartaDe(rango, palo) {
        var buscado = "carta_" + rango + "_" + palo;
        for (var i = 0; i < cartas.length; i++) {
            if (cartas[i].codigo === buscado) return cartas[i];
        }
        return null;
    }
    // Rojo para corazones/diamantes, negro para tréboles/picas -- como
    // una carta de verdad (pedido explícito: "donde esta el problema con
    // las cartas tradicionalmente negras y rojas??"). Mismo criterio que
    // Avatar.qml::colorPaloCarta() -- duplicado a propósito, es una
    // función de 3 líneas y este fichero no depende de Avatar.qml para
    // nada más.
    function colorPaloCarta(codigo) {
        return (codigo.indexOf("_corazones") >= 0 || codigo.indexOf("_diamantes") >= 0)
               ? "#8a2c22" : "#1c1c1c";
    }
    // Proporción del naipe y cuánto del PNG es margen transparente (el
    // naipe mide 218x288 en un lienzo de 320x320) -- mismo criterio y
    // mismos números que Avatar.qml::aspectoCarta/escalaLienzoCarta, ver
    // allí el porqué. Aquí pasaba lo mismo que en el avatar: la Image se
    // ponía "del tamaño de la celda" y PreserveAspectFit, con un lienzo
    // cuadrado dentro de una celda que no lo es, dejaba el naipe más
    // pequeño que su propio respaldo de color.
    readonly property real aspectoCarta: 0.756
    readonly property real escalaLienzoCarta: 320 / 218

    // Fondo a juego con el resto de la app -- el Popup por defecto del
    // estilo de QtQuick Controls es blanco brillante (bug real reportado
    // 2026-08-31: "se ve blanco brillante y no tiene nada que ver con el
    // resto de la app") -- se me olvidó ponerle uno propio, mismo
    // criterio que PopupInvitarAmigos.qml.
    background: Rectangle {
        color: Tema.colorPanel
        radius: 12 * Tema.escala
        border.width: 1
        border.color: Tema.colorAccent
    }

    contentItem: Column {
        spacing: 14 * Tema.escala

        Text {
            text: "Elige una carta"
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.pixelSize: 17 * Tema.escala
        }
        Text {
            width: popup.width - 40 * Tema.escala
            wrapMode: Text.WordWrap
            text: "Toca una carta para elegirla -- se verá en la previsualización. Comprar o equipar la que elijas se hace desde la propia tarjeta de la Tienda."
            color: Tema.colorTextoTenue
            font.pixelSize: 11 * Tema.escala
        }

        ScrollView {
            width: popup.width - 40 * Tema.escala
            height: popup.height - 110 * Tema.escala
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: popup.width - 60 * Tema.escala
                spacing: 10 * Tema.escala

                Repeater {
                    model: popup.suits
                    delegate: Column {
                        id: filaPalo
                        required property string modelData
                        width: parent ? parent.width : 0
                        spacing: 4 * Tema.escala

                        Text {
                            text: popup.suitsNombre[filaPalo.modelData]
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 10 * Tema.escala
                            font.letterSpacing: 1
                        }
                        Row {
                            width: parent.width
                            spacing: (width - 13 * popup.anchoCelda) / 12

                            Repeater {
                                model: popup.rangos
                                // "filaPalo" por id en vez de parent.parent -- un
                                // Repeater anidado dos niveles no garantiza un
                                // parent válido al evaluar bindings por primera
                                // vez, y bajo "pragma ComponentBehavior: Bound"
                                // (todo el fichero) el compilador ni siquiera
                                // puede tipar parent.parent.modelData (parent es
                                // Item genérico) -- mismo motivo que las marcas
                                // cardinales de Avatar.qml.
                                delegate: Rectangle {
                                    id: celdaCarta
                                    required property string modelData
                                    property string codigoCarta: "carta_" + modelData + "_" + filaPalo.modelData
                                    property var infoCarta: popup.cartaDe(modelData, filaPalo.modelData)
                                    property bool poseida: infoCarta ? infoCarta.poseido === 1 : false
                                    property bool equipada: codigoCarta === popup.decoracionLateral1 ||
                                                             codigoCarta === popup.decoracionLateral2
                                    property bool elegida: codigoCarta === popup.seleccionActual

                                    width: popup.anchoCelda
                                    height: popup.altoCelda
                                    // Alto del naipe dentro de la celda --
                                    // antes el naipe salía a ~0.47 del alto de
                                    // la celda; el respaldo, a 0.66.
                                    readonly property real altoCarta: popup.altoCelda * 0.74
                                    readonly property real anchoCarta: altoCarta * popup.aspectoCarta
                                    // Se encoge un poco al pasar el ratón por
                                    // encima -- pedido explícito 2026-08-31,
                                    // "así se nota más responsivo" (mismo
                                    // criterio en Amigos y Salas).
                                    scale: zonaClic.containsMouse ? 0.94 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 90 } }
                                    radius: 7 * Tema.escala
                                    // Bajado de 1.5/1 -- pedido explícito
                                    // 2026-08-31: "el borde es gigantesco,
                                    // sería mucho mejor un borde más fino".
                                    // Con la carta más grande (arriba) el
                                    // mismo borde ya se nota menos, y encima
                                    // se afina un poco más.
                                    border.width: (elegida || equipada) ? 1.2 : 1
                                    border.color: elegida ? Tema.colorAccent
                                                : (equipada ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(0, 0, 0, 0.35))
                                    color: Tema.colorPanel

                                    // Mismo respaldo de color por palo que
                                    // Avatar.qml -- sin esto el número/palo
                                    // (agujero transparente en el icono real)
                                    // no se ve, o se ve del mismo gris para las
                                    // 52 cartas en vez de rojo/negro.
                                    // El naipe manda: el respaldo se calcula a
                                    // partir de él con un margen fino, y la
                                    // Image se hace más grande que él para
                                    // compensar el margen transparente del PNG.
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: celdaCarta.anchoCarta * 1.06
                                        height: celdaCarta.altoCarta * 1.05
                                        radius: width * 0.14
                                        color: popup.colorPaloCarta(celdaCarta.codigoCarta)
                                    }
                                    Image {
                                        anchors.centerIn: parent
                                        width: celdaCarta.anchoCarta * popup.escalaLienzoCarta
                                        height: width
                                        opacity: celdaCarta.poseida ? 1.0 : 0.8
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        // Ver Avatar.qml: sin mipmap, encoger el
                                        // PNG a este tamaño deja bordes dentados.
                                        mipmap: true
                                        source: "qrc:/qt/qml/PokerQuick/assets/iconos/" + celdaCarta.codigoCarta + ".png"
                                    }
                                    Text {
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 2 * Tema.escala
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: !celdaCarta.poseida
                                        text: "30"
                                        color: "#f4f1ea"
                                        font.pixelSize: 8 * Tema.escala
                                        style: Text.Outline
                                        styleColor: "#000000"
                                    }
                                    Text {
                                        anchors.top: parent.top
                                        anchors.topMargin: 2 * Tema.escala
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: celdaCarta.equipada
                                        text: "✓"
                                        color: Tema.colorAccent
                                        font.bold: true
                                        font.pixelSize: 10 * Tema.escala
                                    }

                                    MouseArea {
                                        id: zonaClic
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            popup.cartaElegida(celdaCarta.codigoCarta);
                                            popup.close();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
