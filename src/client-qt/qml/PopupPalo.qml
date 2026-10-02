// PopupPalo.qml — elegir el PALO con el que se componen "Mano Real"/
// "Escalera de Color" al equiparlas ("elegir palo", 2026-10-01). Mismo
// patrón que PopupTapete.qml: una fila de opciones, cada una con una
// vista previa real (una carta del mazo ya existente), sin arte nuevo.
// Solo se abre para EQUIPAR con un palo -- quitar la decoración sigue el
// camino normal de siempre (equiparConAcabado con código vacío), no pasa
// por aquí.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Popup {
    id: popup
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 18 * Tema.escala

    signal elegido(string codigo, string palo)

    property string codigo: ""
    property string nombre: ""
    property string palo: ""     // el elegido ahora mismo en la ventana
    // Rango representativo para la vista previa -- mismo criterio que
    // rutaIconoObjetoTienda() en Main.qml (el as para mano_real, el 7
    // para escalera_diamantes).
    readonly property var rangoRepresentativo: ({"mano_real": "ace", "escalera_diamantes": "7"})
    readonly property var opciones: ["picas", "diamantes", "treboles", "corazones"]
    readonly property real anchoOpcion: 96 * Tema.escala

    function abrir(codigo, nombre, paloActual) {
        popup.codigo = codigo;
        popup.nombre = nombre;
        popup.palo = popup.opciones.indexOf(paloActual) >= 0 ? paloActual : popup.opciones[0];
        popup.open();
    }

    background: Rectangle {
        color: Tema.colorPanel
        radius: 12 * Tema.escala
        border.width: 1
        border.color: Tema.colorAccent
    }

    contentItem: Column {
        spacing: 14 * Tema.escala

        Text {
            text: popup.nombre
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.pixelSize: 17 * Tema.escala
        }
        Text {
            width: fila.width
            wrapMode: Text.WordWrap
            text: Idioma.t("popup_palo_descripcion")
            color: Tema.colorTextoTenue
            font.pixelSize: 11 * Tema.escala
        }

        Row {
            id: fila
            spacing: 10 * Tema.escala

            Repeater {
                model: popup.opciones
                delegate: Rectangle {
                    id: opcion
                    required property string modelData
                    readonly property bool marcada: popup.palo === opcion.modelData
                    width: popup.anchoOpcion
                    height: popup.anchoOpcion * 1.5
                    radius: 10 * Tema.escala
                    color: opcion.marcada
                           ? Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.14)
                           : "transparent"
                    border.width: opcion.marcada ? 2 : 1
                    border.color: opcion.marcada ? Tema.colorAccent : Tema.colorBorde

                    Column {
                        anchors.centerIn: parent
                        spacing: 6 * Tema.escala
                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: popup.anchoOpcion - 20 * Tema.escala
                            height: width * 84 / 63
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            source: "qrc:/qt/qml/PokerQuick/assets/iconos/carta_"
                                    + (popup.rangoRepresentativo[popup.codigo] || "ace") + "_" + opcion.modelData + ".png"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Idioma.t("palo_" + opcion.modelData)
                            color: opcion.marcada ? Tema.colorAccent : Tema.colorTexto
                            font.bold: opcion.marcada
                            font.pixelSize: 12 * Tema.escala
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: popup.palo = opcion.modelData
                    }
                }
            }
        }

        Row {
            x: parent.width - width
            spacing: 8 * Tema.escala

            BotonContorno {
                text: Idioma.t("boton_cancelar")
                colorBorde: Tema.colorBorde
                onClicked: popup.close()
            }
            BotonRelleno {
                text: Idioma.t("boton_equipar")
                onClicked: {
                    popup.elegido(popup.codigo, popup.palo);
                    popup.close();
                }
            }
        }
    }
}
