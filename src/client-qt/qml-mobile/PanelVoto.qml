// PanelVoto.qml (móvil) — mismo botón de confirmación que escritorio (ver
// PanelVoto.qml de qml/) antes de abandonar, con la diferencia de
// registrarse en EstadoOverlays.popupActivo -- mismo criterio que
// CampoEmergente.qml, para que el gesto de atrás de Android lo cierre en
// vez de hacer otra cosa mientras está abierto.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile
import QtQuick.Controls

Row {
    id: panelVoto
    required property bool soyHost
    // Ver el comentario largo en PanelVoto.qml de qml/: aproximación local
    // (invitado nunca cuenta + manos jugadas), no sabe si hay 2 cuentas
    // reales en la mesa -- puede sobrar el aviso alguna vez, nunca faltar.
    required property bool contariaComoPerdida
    signal abandonar()
    signal guardarYSalir()

    spacing: 8 * Tema.escala
    BotonRelleno {
        text: Idioma.t("boton_continuar_siguiente_mano")
        // Ya NO cierra el panel al pulsar -- ver el comentario largo en
        // PanelVoto.qml de qml/: quien instancie esto cierra su propio
        // "votoAbierto" solo con el ack real del servidor
        // (NetworkClient::votoConfirmado()), no de forma optimista.
        onClicked: redcliente.votar();
    }
    BotonContorno {
        text: Idioma.t("boton_abandonar_partida")
        colorBorde: Tema.colorPeligro
        onClicked: {
            if (panelVoto.contariaComoPerdida) {
                confirmarAbandonoMovil.open();
            } else {
                redcliente.abandonar();
                panelVoto.abandonar();
            }
        }
    }
    BotonContorno {
        visible: soyHost
        text: Idioma.t("boton_guardar_salir")
        onClicked: {
            redcliente.guardarYSalir();
            guardarYSalir();
        }
    }

    Popup {
        id: confirmarAbandonoMovil
        parent: Overlay.overlay
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(parent.width - 48 * Tema.escala, 420 * Tema.escala)
        padding: 18 * Tema.escala

        onOpened: EstadoOverlays.popupActivo = confirmarAbandonoMovil
        onClosed: if (EstadoOverlays.popupActivo === confirmarAbandonoMovil) EstadoOverlays.popupActivo = null

        background: Rectangle {
            color: Tema.colorPanel
            radius: 12 * Tema.escala
            border.width: 1
            border.color: Tema.colorPeligro
        }

        contentItem: Column {
            spacing: 14 * Tema.escala
            Text {
                width: parent.width
                text: Idioma.t("titulo_confirmar_abandono")
                color: Tema.colorTexto
                font.family: Tema.fuenteElegante
                font.bold: true
                font.pixelSize: 16 * Tema.escala
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: Idioma.t("texto_confirmar_abandono_descripcion")
                color: Tema.colorTextoTenue
                font.pixelSize: 12 * Tema.escala
                wrapMode: Text.WordWrap
            }
            Row {
                width: parent.width
                spacing: 12 * Tema.escala
                BotonContorno {
                    width: (parent.width - parent.spacing) / 2
                    text: Idioma.t("boton_cancelar")
                    onClicked: confirmarAbandonoMovil.close()
                }
                BotonRelleno {
                    width: (parent.width - parent.spacing) / 2
                    text: Idioma.t("boton_abandonar")
                    colorBorde: Tema.colorPeligro
                    onClicked: {
                        redcliente.abandonar();
                        panelVoto.abandonar();
                        confirmarAbandonoMovil.close();
                    }
                }
            }
        }
    }
}
