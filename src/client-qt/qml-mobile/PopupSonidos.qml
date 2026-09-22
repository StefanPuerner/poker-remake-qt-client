// PopupSonidos.qml — ventana flotante para ajustar el volumen y qué grupos de
// sonido suenan. Antes esto era una lista fija dentro de Ajustes (volumen + 6
// interruptores de grupo) que se desplegaba entera con el interruptor general
// encendido y dejaba el resto del panel muy apretado (pedido explícito del
// usuario, 2026-09-22); ahora Ajustes solo tiene el interruptor general y un
// botón que abre esto -- mismo criterio ya usado para los temas de color
// (PopupTemas.qml), registro en EstadoOverlays para el gesto de atrás incluido.
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
    padding: 20 * Tema.escala
    onOpened: EstadoOverlays.popupActivo = popup
    onClosed: if (EstadoOverlays.popupActivo === popup) EstadoOverlays.popupActivo = null

    // Volumen y grupos silenciados viven en "ventana" (Main.qml) -- esto solo
    // los refleja y pide cambios por señal, mismo esquema que PopupTapete.
    property real volumen: 0.8
    property string sonidosSilenciados: ""
    // Diagnóstico (bancoSonidos, solo móvil -- ver el comentario original en
    // Main.qml sobre el mezclador de Android): cuántas mezclas cargaron, con
    // error, y cuántas han sonado, más un botón para probar una de verdad.
    property int diagListos: 0
    property int diagErrores: 0
    property int diagReproducidos: 0
    signal volumenCambiado(real valor)
    signal grupoAlternado(string grupo)
    signal probarSonido()

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

    // El contenido (título + volumen + diagnóstico + 6 grupos + cerrar) no cabe entero
    // en un móvil en landscape (pantalla corta) -- envuelto en Flickable con tope de
    // alto, mismo patrón que PopupPerfilJugador.qml (el otro popup con contenido largo).
    contentItem: Flickable {
        implicitWidth: 300 * Tema.escala
        implicitHeight: Math.min(contenidoSonidosMovil.height,
                                  (popup.parent ? popup.parent.height : 480 * Tema.escala) - 80 * Tema.escala)
        contentWidth: width
        contentHeight: contenidoSonidosMovil.height
        clip: true

        Column {
        id: contenidoSonidosMovil
        width: parent.width
        spacing: 14 * Tema.escala

        Text {
            text: Idioma.t("ajustes_sonidos_titulo")
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.pixelSize: 16 * Tema.escala
        }

        Row {
            width: parent.width
            spacing: 10 * Tema.escala
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Idioma.t("ajustes_sonidos_volumen")
                color: Tema.colorTextoTenue
                font.pixelSize: 12 * Tema.escala
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

        Row {
            width: parent.width
            spacing: 10 * Tema.escala
            Text {
                width: parent.width - botonProbarSonidoMovil.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: Idioma.tf("ajustes_sonidos_diagnostico", [popup.diagListos, popup.diagErrores, popup.diagReproducidos])
                color: Tema.colorTextoMuyTenue
                font.pixelSize: 11 * Tema.escala
                wrapMode: Text.WordWrap
            }
            BotonContorno {
                id: botonProbarSonidoMovil
                anchors.verticalCenter: parent.verticalCenter
                text: Idioma.t("ajustes_sonidos_probar")
                onClicked: popup.probarSonido()
            }
        }

        Repeater {
            model: ["cartas", "fichas", "allin", "resultado", "retirarse", "turno"]
            delegate: Row {
                id: filaGrupoSonidoMovil
                required property string modelData
                width: parent.width
                Text {
                    width: parent.width - 46 * Tema.escala
                    anchors.verticalCenter: parent.verticalCenter
                    text: Idioma.t("sonido_grupo_" + filaGrupoSonidoMovil.modelData)
                    color: Tema.colorTextoTenue
                    font.pixelSize: 12 * Tema.escala
                    wrapMode: Text.WordWrap
                }
                Interruptor {
                    anchors.verticalCenter: parent.verticalCenter
                    activo: !popup.grupoSilenciado(filaGrupoSonidoMovil.modelData)
                    onAlternado: popup.grupoAlternado(filaGrupoSonidoMovil.modelData)
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
}
