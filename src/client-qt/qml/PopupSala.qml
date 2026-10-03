// PopupSala.qml -- pantalla previa de una sala de la lista (2026-10-03, modo
// espectador): al tocar la tarjeta se ve la sala y se elige entre sentarse
// ("Unirse") o solo mirar ("Observar"). No conecta por sí mismo: emite la
// elección y Main.qml llama a NetworkClient con los datos de la cuenta.
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

    property string salaId: ""
    property string nombreSala: ""
    property int conectados: 0
    property int esperados: 0
    readonly property bool espectadorDisponible: true

    signal unirse(string salaId)
    signal observar(string salaId)

    function abrir(id, nombre, conectadosActuales, esperadosTotales) {
        popup.salaId = id;
        popup.nombreSala = nombre;
        popup.conectados = conectadosActuales;
        popup.esperados = esperadosTotales;
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
            text: popup.nombreSala
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.bold: true
            font.pixelSize: 17 * Tema.escala
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: popup.conectados + " / " + popup.esperados
            color: Tema.colorTextoTenue
            font.pixelSize: 13 * Tema.escala
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12 * Tema.escala

            BotonContorno {
                text: Idioma.t("boton_cancelar")
                onClicked: popup.close()
            }
            BotonContorno {
                visible: popup.espectadorDisponible
                text: Idioma.t("boton_observar")
                onClicked: {
                    popup.observar(popup.salaId);
                    popup.close();
                }
            }
            BotonRelleno {
                text: Idioma.t("boton_unirse")
                enabled: popup.conectados < popup.esperados
                opacity: enabled ? 1.0 : 0.55
                onClicked: {
                    popup.unirse(popup.salaId);
                    popup.close();
                }
            }
        }
    }
}
