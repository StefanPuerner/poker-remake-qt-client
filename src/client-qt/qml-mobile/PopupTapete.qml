// PopupTapete.qml — elegir el COLOR (paño) o la MADERA de un tapete al equiparlo.
// El tapete se compra por tipo (la textura: rombos, palos, lino...) y el color se
// elige aquí, sin coste -- mismo esquema que el acabado de las decoraciones
// (PopupAcabado.qml). Cada opción se enseña con el propio tapete en miniatura.
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
    padding: 18 * Tema.escala
    onOpened: EstadoOverlays.popupActivo = popup
    onClosed: if (EstadoOverlays.popupActivo === popup) EstadoOverlays.popupActivo = null

    signal elegido(string codigo, string variante)
    signal quitado()

    property string codigo: ""
    property string nombre: ""
    property string variante: ""     // la elegida ahora mismo en la ventana
    property bool equipado: false
    // ⚠️ Mismas listas que varianteTapeteValida() (AccountManager.cpp) y Tapete.qml.
    readonly property bool esMadera: popup.codigo === "tapete_madera" || popup.codigo === "tapete_casino"
    readonly property var opciones: popup.esMadera
        ? ["roble", "roble_oscuro", "nogal"]
        : ["verde", "granate", "azul", "grafito", "taberna", "porcelana", "violeta", "petroleo"]
    readonly property real anchoOpcion: Math.max(Tema.tactil * 2, 104 * Tema.escala)

    function abrir(codigo, nombre, varianteActual, equipado) {
        popup.codigo = codigo;
        popup.nombre = nombre;
        popup.equipado = equipado;
        var valida = popup.opciones.indexOf(varianteActual) >= 0;
        popup.variante = valida ? varianteActual : popup.opciones[0];
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
            width: cuadricula.width
            wrapMode: Text.WordWrap
            text: popup.esMadera ? Idioma.t("popup_tapete_descripcion_madera") : Idioma.t("popup_tapete_descripcion_pano")
            color: Tema.colorTextoTenue
            font.pixelSize: 11 * Tema.escala
        }

        Grid {
            id: cuadricula
            columns: Math.max(1, Math.min(4, Math.floor((popup.parent.width - 2 * popup.padding - 24 * Tema.escala) / (popup.anchoOpcion + 10 * Tema.escala))))
            spacing: 10 * Tema.escala

            Repeater {
                model: popup.opciones
                delegate: Rectangle {
                    id: opcion
                    required property string modelData
                    readonly property bool marcada: popup.variante === opcion.modelData
                    width: popup.anchoOpcion
                    height: popup.anchoOpcion * 0.62 + 30 * Tema.escala
                    radius: 10 * Tema.escala
                    color: opcion.marcada
                           ? Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.14)
                           : "transparent"
                    border.width: opcion.marcada ? 2 : 1
                    border.color: opcion.marcada ? Tema.colorAccent : Tema.colorBorde

                    Column {
                        anchors.centerIn: parent
                        spacing: 6 * Tema.escala
                        Tapete {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: popup.anchoOpcion - 16 * Tema.escala
                            height: width * 0.5
                            miniatura: true
                            preset: popup.codigo + ":" + opcion.modelData
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Idioma.t("tapete_variante_" + opcion.modelData)
                            color: opcion.marcada ? Tema.colorAccent : Tema.colorTexto
                            font.bold: opcion.marcada
                            font.pixelSize: 12 * Tema.escala
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: popup.variante = opcion.modelData
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
            BotonContorno {
                visible: popup.equipado
                text: Idioma.t("boton_quitar")
                colorBorde: Tema.colorPeligro
                onClicked: {
                    popup.quitado();
                    popup.close();
                }
            }
            BotonRelleno {
                text: Idioma.t("boton_equipar")
                onClicked: {
                    popup.elegido(popup.codigo, popup.variante);
                    popup.close();
                }
            }
        }
    }
}
