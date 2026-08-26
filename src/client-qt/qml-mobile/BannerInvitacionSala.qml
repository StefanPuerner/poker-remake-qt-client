// BannerInvitacionSala.qml (móvil) — mismo rol que el de escritorio (ver
// src/client-qt/qml/BannerInvitacionSala.qml): aviso de que un amigo te
// invitó a su sala, anclado a nivel de ventana raíz.
pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: banner
    property int fromAccountId: -1
    property string fromUsername: ""
    property string salaId: ""
    property string codigo: ""
    property string nombreSala: ""
    signal unirse(string salaId, string codigo)

    function mostrar(from, username, sala, cod, nombre) {
        banner.fromAccountId = from;
        banner.fromUsername = username;
        banner.salaId = sala;
        banner.codigo = cod;
        banner.nombreSala = nombre;
        banner.visible = true;
        temporizadorAutoDescarte.restart();
    }

    visible: false
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.topMargin: 12 * Tema.escala
    z: 200
    width: Math.min(360 * Tema.escala, (parent ? parent.width : 360) - 32 * Tema.escala)
    height: columnaBanner.height + 20 * Tema.escala
    radius: 8 * Tema.escala
    color: Tema.colorPanel
    border.width: 1
    border.color: Tema.colorAccent

    Timer {
        id: temporizadorAutoDescarte
        interval: 20000
        onTriggered: banner.visible = false
    }

    Column {
        id: columnaBanner
        anchors.centerIn: parent
        width: parent.width - 20 * Tema.escala
        spacing: 8 * Tema.escala

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: banner.fromUsername + " te invitó a su sala" +
                  (banner.nombreSala !== "" ? " (" + banner.nombreSala + ")" : "")
            color: Tema.colorTexto
            font.pixelSize: 11 * Tema.escala
        }
        Row {
            anchors.right: parent.right
            spacing: 8 * Tema.escala
            BotonRelleno {
                text: "Unirse"
                onClicked: {
                    banner.unirse(banner.salaId, banner.codigo);
                    banner.visible = false;
                }
            }
            BotonContorno {
                text: "Descartar"
                onClicked: banner.visible = false
            }
        }
    }
}
