// PopupSeleccionCarta.qml (móvil) — mismo rol que el de escritorio (ver
// src/client-qt/qml/PopupSeleccionCarta.qml): selector de "qué carta de
// la baraja" para la tarjeta sintética "Carta de póker" de la Tienda.
// Port de escritorio, Fase M2 del port de progresión a móvil
// (2026-09-01, ver memoria qt_mobile_progression_port_plan), con DOS
// diferencias deliberadas:
// - Layout en Flow (envuelve solo) en vez de una Row fija de 13
//   columnas por palo -- a 58*escala por carta, 13 en fila son ~750px,
//   más ancho que la mayoría de móviles en vertical. Flow deja que cada
//   palo ocupe las filas que hagan falta según el ancho real.
// - "pressed" en vez de "hover" para el feedback al tocar (no hay ratón
//   en móvil, ver el resto de qml-mobile/).
// Solo ELIGE (cartaElegida) y se cierra -- comprar/equipar de verdad
// vive en la tarjeta "Carta de póker" de la Tienda (Main.qml), igual
// que escritorio.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Popup {
    id: popup
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(480 * Tema.escala, (parent ? parent.width : 480) - 32 * Tema.escala)
    height: Math.min(620 * Tema.escala, (parent ? parent.height : 620) - 32 * Tema.escala)
    padding: 16 * Tema.escala
    // Registro en EstadoOverlays -- mismo criterio que CampoEmergente/
    // PanelVoto/ChuletaFlotante: "closePolicy: CloseOnEscape" ya cierra
    // con la tecla Esc de verdad, pero el gesto de atrás de Android
    // llega como cierre de ventana, no como tecla -- sin este registro,
    // Main.qml::consumirAtras() no sabe que este popup está abierto y
    // se salta directo a navegar la pantalla de detrás (bug real
    // reportado 2026-09-02, "no funciona en las secciones nuevas").
    onOpened: EstadoOverlays.popupActivo = popup
    onClosed: if (EstadoOverlays.popupActivo === popup) EstadoOverlays.popupActivo = null
    // Tamaño de cada carta del selector -- más compacto que escritorio
    // (58/80) para caber varias por fila en un móvil en vertical, sin
    // bajar del suelo de accesibilidad táctil.
    readonly property real anchoCelda: Math.max(Tema.tamanoMinTactil, 50 * Tema.escala)
    readonly property real altoCelda: anchoCelda * 1.35

    signal cartaElegida(string codigo)

    property var cartas: []
    property string decoracionLateral1: ""
    property string decoracionLateral2: ""
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
    // Duplicado a propósito de Avatar.qml::colorPaloCarta() -- mismo
    // criterio que escritorio, este fichero no depende de Avatar.qml
    // para nada más.
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

    background: Rectangle {
        color: Tema.colorPanel
        radius: 12 * Tema.escala
        border.width: 1
        border.color: Tema.colorAccent
    }

    contentItem: Column {
        spacing: 12 * Tema.escala

        Text {
            text: "Elige una carta"
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.pixelSize: 16 * Tema.escala
        }
        Text {
            width: popup.width - 32 * Tema.escala
            wrapMode: Text.WordWrap
            text: "Toca una carta para elegirla -- se verá en la previsualización. Comprar o equipar la que elijas se hace desde la propia tarjeta de la Tienda."
            color: Tema.colorTextoTenue
            font.pixelSize: 11 * Tema.escala
        }

        ScrollView {
            width: popup.width - 32 * Tema.escala
            height: popup.height - 96 * Tema.escala
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: popup.width - 48 * Tema.escala
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
                        Flow {
                            width: parent.width
                            spacing: 6 * Tema.escala

                            Repeater {
                                model: popup.rangos
                                // "filaPalo" por id -- mismo motivo que
                                // escritorio: bajo "pragma
                                // ComponentBehavior: Bound" un Repeater
                                // anidado dos niveles no puede tipar
                                // parent.parent.modelData.
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
                                    scale: zonaClic.pressed ? 0.94 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 90 } }
                                    radius: 6 * Tema.escala
                                    border.width: (elegida || equipada) ? 1.2 : 1
                                    border.color: elegida ? Tema.colorAccent
                                                : (equipada ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(0, 0, 0, 0.35))
                                    color: Tema.colorPanel

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
                                        source: "qrc:/qt/qml/PokerQuickMobile/assets/iconos/" + celdaCarta.codigoCarta + ".png"
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
