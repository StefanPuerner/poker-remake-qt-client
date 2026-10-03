// EtiquetaInfo.qml (móvil) -- etiqueta de un ajuste con un botón "i". Al pulsarlo se
// abre un pop-up con la explicación completa: la tarjeta no cambia de tamaño.
// Sin "detalle" no se pinta el botón.
import QtQuick
import QtQuick.Controls
import PokerQuickMobile

Column {
    id: raiz
    property string etiqueta: ""
    property string detalle: ""

    Row {
        spacing: 8 * Tema.escala
        Text {
            anchors.verticalCenter: parent.verticalCenter
            // Ocupa solo su texto (sin pasarse del ancho que deja el botón "i"), así
            // el "i" va pegado al final de la etiqueta y el hueco queda antes del interruptor.
            width: Math.min(implicitWidth, raiz.width - (raiz.detalle !== "" ? 30 * Tema.escala : 0))
            wrapMode: Text.WordWrap
            text: raiz.etiqueta
            color: Tema.colorTextoTenue
            font.pixelSize: 13 * Tema.escala
        }
        Rectangle {
            visible: raiz.detalle !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 22 * Tema.escala
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Tema.colorAccent
            Text {
                anchors.centerIn: parent
                text: "i"
                font.bold: true
                font.pixelSize: 11 * Tema.escala
                font.family: Tema.fuenteElegante
                color: Tema.colorAccent
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6 * Tema.escala
                cursorShape: Qt.PointingHandCursor
                onClicked: popupInfo.open()
            }
        }
    }

    Popup {
        id: popupInfo
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(320 * Tema.escala, (parent ? parent.width : 320) - 40 * Tema.escala)
        padding: 18 * Tema.escala

        background: Rectangle {
            color: Tema.colorPanel
            radius: 12 * Tema.escala
            border.width: 1
            border.color: Tema.colorAccent
        }

        contentItem: Column {
            width: popupInfo.availableWidth
            spacing: 14 * Tema.escala
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: raiz.etiqueta
                color: Tema.colorTexto
                font.family: Tema.fuenteElegante
                font.bold: true
                font.pixelSize: 16 * Tema.escala
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: raiz.detalle
                color: Tema.colorTexto
                font.pixelSize: 14 * Tema.escala
            }
            BotonRelleno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Idioma.t("boton_aceptar")
                onClicked: popupInfo.close()
            }
        }
    }
}
