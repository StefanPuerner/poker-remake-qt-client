// PopupColorFicha.qml -- color de las fichas orbitando del avatar (2026-10-04).
// Igual que PopupPalo: al equipar el efecto sale este popup en vez de equiparse
// directo. Elegir un color emite elegido(codigo, color); el servidor valida el
// color (varianteFichaValida) y lo guarda como "destello:<color>".
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import PokerQuickMobile

Popup {
    id: popup
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(320 * Tema.escala, (parent ? parent.width : 320) - 40 * Tema.escala)
    padding: 18 * Tema.escala

    property string codigo: "destello"
    property string nombre: ""
    property string actual: ""

    signal elegido(string codigo, string color)

    // Los clásicos del póker, y el dorado de siempre.
    readonly property var colores: [
        { clave: "dorado", color: Tema.colorAccent },
        { clave: "rojo", color: "#b3261e" },
        { clave: "azul", color: "#1f4e9c" },
        { clave: "verde", color: "#1e7a3c" },
        { clave: "negro", color: "#2a2a2a" },
        { clave: "blanco", color: "#e8e4da" }
    ]

    function abrir(c, n, colorActual) {
        popup.codigo = c;
        popup.nombre = n;
        popup.actual = colorActual && colorActual !== "" ? colorActual : "dorado";
        popup.open();
    }

    background: Rectangle {
        color: Tema.colorPanel
        radius: 12 * Tema.escala
        border.width: 1
        border.color: Tema.colorAccent
    }

    contentItem: Column {
        width: popup.availableWidth
        spacing: 14 * Tema.escala

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: popup.nombre
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.bold: true
            font.pixelSize: 17 * Tema.escala
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Idioma.t("popup_color_ficha_titulo")
            color: Tema.colorTextoTenue
            font.pixelSize: 13 * Tema.escala
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10 * Tema.escala

            Repeater {
                model: popup.colores
                delegate: Rectangle {
                    id: ficha
                    required property var modelData
                    width: 40 * Tema.escala
                    height: width
                    radius: width / 2
                    color: ficha.modelData.color
                    border.width: popup.actual === ficha.modelData.clave ? 3 : 1
                    border.color: popup.actual === ficha.modelData.clave ? Tema.colorTexto : Qt.rgba(0, 0, 0, 0.5)
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.5
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.45)
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            popup.elegido(popup.codigo, ficha.modelData.clave);
                            popup.close();
                        }
                    }
                }
            }
        }

        BotonContorno {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Idioma.t("boton_cancelar")
            onClicked: popup.close()
        }
    }
}
