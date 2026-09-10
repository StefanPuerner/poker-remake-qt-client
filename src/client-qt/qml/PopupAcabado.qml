// PopupAcabado.qml — elegir el acabado (el metal) de una decoración al
// equiparla. Fase 2 del material (ver docs/plan-material-cosmeticos.md);
// pedido del usuario, 2026-09-10: "al equipar un cosmético que tiene color
// intercambiable, antes de equiparse salta una ventana flotante donde eliges
// el color, y luego sigue la asignación normal".
//
// Enseña la decoración en cada metal que ya has ganado, del hierro al de tu
// marco ("solo se puede bajar, nunca subir" -- el servidor lo vuelve a
// comprobar), con el de tu marco ya marcado. Ese se manda como "" = sigue al
// marco: si tu marco sube, la decoración sube con él. Uno más bajo se queda
// fijo. Main.qml::equiparConAcabado() decide si hace falta preguntar.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Popup {
    id: popup
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 20 * Tema.escala

    signal acabadoElegido(string slot, string codigo, string acabado)

    property string slot: ""
    property string codigo: ""
    property string marco: ""
    property string elegido: ""
    readonly property var metales: Tema.metalesHasta(popup.marco)

    function abrir(slot, codigo, marco) {
        popup.slot = slot;
        popup.codigo = codigo;
        popup.marco = marco;
        popup.elegido = marco;
        popup.open();
    }
    // Mismos nombres de fichero que Avatar.qml::sufijoAcabado(): el oro es el
    // fichero base, que ya es dorado.
    function rutaIcono(metal) {
        return "qrc:/qt/qml/PokerQuick/assets/iconos/" + popup.codigo
               + (metal === "oro" ? "" : "_" + metal) + ".png";
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
            text: "Elige el acabado"
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.pixelSize: 17 * Tema.escala
        }
        Text {
            width: filaMetales.width
            wrapMode: Text.WordWrap
            text: "Los metales de los marcos que ya has conseguido. Con el de tu marco, la decoración sube con él cuando tu marco suba."
            color: Tema.colorTextoTenue
            font.pixelSize: 11 * Tema.escala
        }

        Row {
            id: filaMetales
            spacing: 10 * Tema.escala

            Repeater {
                model: popup.metales
                delegate: Rectangle {
                    id: celda
                    required property string modelData
                    readonly property bool marcado: popup.elegido === celda.modelData
                    width: 88 * Tema.escala
                    height: 116 * Tema.escala
                    radius: 10 * Tema.escala
                    color: celda.marcado
                           ? Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.14)
                           : (zona.containsMouse
                              ? Qt.rgba(Tema.colorTexto.r, Tema.colorTexto.g, Tema.colorTexto.b, 0.06)
                              : "transparent")
                    border.width: celda.marcado ? 2 : 1
                    border.color: celda.marcado ? Tema.colorAccent : Tema.colorBorde

                    Column {
                        anchors.centerIn: parent
                        spacing: 4 * Tema.escala

                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 56 * Tema.escala
                            height: width
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            source: popup.rutaIcono(celda.modelData)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Tema.nombresMetal[celda.modelData]
                            color: celda.marcado ? Tema.colorAccent : Tema.colorTexto
                            font.pixelSize: 12 * Tema.escala
                            font.bold: celda.marcado
                        }
                        // Opacidad y no "visible": así todas las celdas miden
                        // lo mismo y los iconos quedan a la misma altura.
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "tu marco"
                            opacity: celda.modelData === popup.marco ? 1 : 0
                            color: Tema.colorTextoTenue
                            font.pixelSize: 10 * Tema.escala
                        }
                    }
                    MouseArea {
                        id: zona
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.elegido = celda.modelData
                    }
                }
            }
        }

        Row {
            x: parent.width - width
            spacing: 8 * Tema.escala

            BotonContorno {
                text: "Cancelar"
                colorBorde: Tema.colorBorde
                onClicked: popup.close()
            }
            BotonRelleno {
                text: "Equipar"
                onClicked: {
                    popup.acabadoElegido(popup.slot, popup.codigo,
                                         popup.elegido === popup.marco ? "" : popup.elegido);
                    popup.close();
                }
            }
        }
    }
}
