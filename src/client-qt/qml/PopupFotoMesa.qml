// PopupFotoMesa.qml -- al elegir "Foto propia" (tapete_foto) en Personalizar
// se abre este popup en vez del selector de colores (2026-10-03). Muestra los
// 4 presets de foto de mesa de la cuenta: tocar una foto llena la activa
// (la que se ve en la mesa), tocar un hueco vacío sube una foto nueva ahí.
// Abajo, equipar o quitar el tapete. No conecta por sí mismo: emite la
// elección y Main.qml actúa (red, diálogo de archivo).
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Popup {
    id: popup
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(340 * Tema.escala, (parent ? parent.width : 340) - 60 * Tema.escala)
    padding: 20 * Tema.escala

    property string nombreObjeto: ""
    property bool equipado: false
    // 4 entradas: { slot, lleno, activa, base64 }. Las monta Main.qml.
    property var presets: []

    signal activar(int slot)
    signal subir(int slot)
    signal equipar()
    signal quitar()

    readonly property bool algunoLleno: presets.some(function(p) { return p.lleno; })
    readonly property int slotActivo: {
        for (var i = 0; i < presets.length; i++) if (presets[i].activa) return presets[i].slot;
        return 0;
    }
    readonly property int slotLibre: {
        for (var i = 0; i < presets.length; i++) if (!presets[i].lleno) return presets[i].slot;
        return 0;
    }

    function abrir(nombre, estaEquipado, lista) {
        popup.nombreObjeto = nombre;
        popup.equipado = estaEquipado;
        popup.presets = lista;
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
            text: popup.nombreObjeto
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.bold: true
            font.pixelSize: 17 * Tema.escala
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: Idioma.t("texto_foto_mesa_presets")
            color: Tema.colorTextoTenue
            font.pixelSize: 13 * Tema.escala
        }

        // Los 4 huecos. El activo lleva el borde dorado.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10 * Tema.escala

            Repeater {
                model: popup.presets

                delegate: Rectangle {
                    id: hueco
                    required property var modelData
                    width: 60 * Tema.escala
                    height: 60 * Tema.escala
                    radius: 8 * Tema.escala
                    clip: true
                    color: Tema.colorFondo
                    border.width: hueco.modelData.activa ? 2 : 1
                    border.color: hueco.modelData.activa ? Tema.colorAccent : Tema.colorTextoTenue

                    Image {
                        anchors.fill: parent
                        visible: hueco.modelData.lleno && hueco.modelData.base64 !== ""
                        source: visible ? "data:image/jpeg;base64," + hueco.modelData.base64 : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        // Miniatura: no decodificar la foto de 1536 px completa.
                        sourceSize.width: 128 * Tema.escala
                        sourceSize.height: 128 * Tema.escala
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !hueco.modelData.lleno
                        text: "+"
                        color: Tema.colorTextoTenue
                        font.pixelSize: 24 * Tema.escala
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (hueco.modelData.lleno) popup.activar(hueco.modelData.slot);
                            else popup.subir(hueco.modelData.slot);
                            popup.close();
                        }
                    }
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12 * Tema.escala

            BotonContorno {
                text: Idioma.t("boton_cancelar")
                onClicked: popup.close()
            }
            BotonRelleno {
                // Con foto activa, "cambiar" sustituye la activa; si no, sube a un hueco libre.
                text: popup.slotActivo > 0 ? Idioma.t("boton_cambiar_foto_mesa") : Idioma.t("boton_subir_foto_mesa")
                visible: popup.slotActivo > 0 || popup.slotLibre > 0
                onClicked: {
                    popup.subir(popup.slotActivo > 0 ? popup.slotActivo : popup.slotLibre);
                    popup.close();
                }
            }
        }

        // Equipar/quitar solo con alguna foto: sin ella el tapete no tendría nada que mostrar.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12 * Tema.escala
            visible: popup.algunoLleno

            BotonContorno {
                visible: popup.equipado
                text: Idioma.t("boton_quitar")
                onClicked: {
                    popup.quitar();
                    popup.close();
                }
            }
            BotonRelleno {
                visible: !popup.equipado
                text: Idioma.t("boton_equipar")
                onClicked: {
                    popup.equipar();
                    popup.close();
                }
            }
        }
    }
}
