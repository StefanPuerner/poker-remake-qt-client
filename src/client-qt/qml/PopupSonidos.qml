// PopupSonidos.qml — ventana flotante para ajustar el volumen y qué grupos de
// sonido suenan. Antes esto era una lista fija dentro de Ajustes (volumen + 6
// interruptores de grupo) que se desplegaba entera con el interruptor general
// encendido y dejaba el resto del panel muy apretado (pedido explícito del
// usuario, 2026-09-22); ahora Ajustes solo tiene el interruptor general y un
// botón que abre esto -- mismo criterio ya usado para los temas de color
// (PopupTemas.qml).
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

    // Volumen y grupos silenciados viven en "ventana" (Main.qml) -- esto solo
    // los refleja y pide cambios por señal, mismo esquema que PopupTapete.
    property real volumen: 0.8
    property string sonidosSilenciados: ""
    signal volumenCambiado(real valor)
    signal grupoAlternado(string grupo)

    function abrir() { popup.open(); }
    function grupoSilenciado(grupo) {
        return popup.sonidosSilenciados.split(",").indexOf(grupo) >= 0;
    }

    background: Rectangle {
        color: Tema.colorPanel
        radius: 12 * Tema.escala
        border.width: 1
        border.color: Tema.colorAccent
    }

    contentItem: Column {
        width: 320 * Tema.escala
        spacing: 16 * Tema.escala

        Text {
            text: Idioma.t("ajustes_sonidos_titulo")
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.pixelSize: 17 * Tema.escala
        }

        Row {
            width: parent.width
            spacing: 10 * Tema.escala
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Idioma.t("ajustes_sonidos_volumen")
                color: Tema.colorTextoTenue
                font.pixelSize: 13 * Tema.escala
            }
            Slider {
                width: parent.width - 100 * Tema.escala
                anchors.verticalCenter: parent.verticalCenter
                from: 0
                to: 1
                value: popup.volumen
                onMoved: popup.volumenCambiado(value)
            }
        }

        Repeater {
            model: ["cartas", "fichas", "allin", "resultado", "retirarse", "turno"]
            delegate: Row {
                id: filaGrupoSonido
                required property string modelData
                width: parent.width
                Text {
                    width: parent.width - 46 * Tema.escala
                    anchors.verticalCenter: parent.verticalCenter
                    text: Idioma.t("sonido_grupo_" + filaGrupoSonido.modelData)
                    color: Tema.colorTextoTenue
                    font.pixelSize: 13 * Tema.escala
                    wrapMode: Text.WordWrap
                }
                Interruptor {
                    anchors.verticalCenter: parent.verticalCenter
                    activo: !popup.grupoSilenciado(filaGrupoSonido.modelData)
                    onAlternado: popup.grupoAlternado(filaGrupoSonido.modelData)
                }
            }
        }

        BotonRelleno {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Idioma.t("boton_cerrar")
            onClicked: popup.close()
        }
    }
}
