// PopupAcabado.qml (móvil) — mismo papel que el de escritorio (ver
// src/client-qt/qml/PopupAcabado.qml, con el porqué completo): elegir el
// metal de una decoración al equiparla, entre los de los marcos que ya has
// ganado, con el de tu marco marcado ("" = sigue al marco).
//
// Diferencias con escritorio, las de siempre en qml-mobile/: celdas del
// tamaño táctil (Tema.tactil), respuesta al pulsar en vez de al pasar el
// ratón, y registro en EstadoOverlays para que el gesto de atrás de Android
// cierre este popup y no navegue la pantalla de detrás.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Popup {
    id: popup
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 16 * Tema.escala
    onOpened: EstadoOverlays.popupActivo = popup
    onClosed: if (EstadoOverlays.popupActivo === popup) EstadoOverlays.popupActivo = null

    signal acabadoElegido(string slot, string codigo, string acabado)

    property string slot: ""
    property string codigo: ""
    property string marco: ""
    property string elegido: ""
    readonly property var metales: Tema.metalesHasta(popup.marco)
    readonly property real anchoCelda: Math.max(Tema.tactil, 72 * Tema.escala)

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
        return "qrc:/qt/qml/PokerQuickMobile/assets/iconos/" + popup.codigo
               + (metal === "oro" ? "" : "_" + metal) + ".png";
    }

    background: Rectangle {
        color: Tema.colorPanel
        radius: 12 * Tema.escala
        border.width: 1
        border.color: Tema.colorAccent
    }

    contentItem: Column {
        spacing: 12 * Tema.escala

        Text {
            text: "Elige el acabado"
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.pixelSize: 16 * Tema.escala
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
            spacing: 8 * Tema.escala

            Repeater {
                model: popup.metales
                delegate: Rectangle {
                    id: celda
                    required property string modelData
                    readonly property bool marcado: popup.elegido === celda.modelData
                    width: popup.anchoCelda
                    height: popup.anchoCelda * 1.35
                    radius: 10 * Tema.escala
                    color: celda.marcado
                           ? Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.14)
                           : (zona.pressed
                              ? Qt.rgba(Tema.colorTexto.r, Tema.colorTexto.g, Tema.colorTexto.b, 0.08)
                              : "transparent")
                    border.width: celda.marcado ? 2 : 1
                    border.color: celda.marcado ? Tema.colorAccent : Tema.colorBorde

                    Column {
                        anchors.centerIn: parent
                        spacing: 3 * Tema.escala

                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: popup.anchoCelda * 0.66
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
                            font.pixelSize: 11 * Tema.escala
                            font.bold: celda.marcado
                        }
                        // Opacidad y no "visible": así todas las celdas miden
                        // lo mismo y los iconos quedan a la misma altura.
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "tu marco"
                            opacity: celda.modelData === popup.marco ? 1 : 0
                            color: Tema.colorTextoTenue
                            font.pixelSize: 9 * Tema.escala
                        }
                    }
                    MouseArea {
                        id: zona
                        anchors.fill: parent
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
