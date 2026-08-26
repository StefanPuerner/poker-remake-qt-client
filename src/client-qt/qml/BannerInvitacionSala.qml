// BannerInvitacionSala.qml — aviso de que un amigo te invitó a su sala.
// Anclado a nivel de ventana raíz (mismo patrón que el overlay de
// reconexión de Main.qml): puede llegar en cualquier pantalla de menú, ya
// que solo se empuja mientras el socket de presencia está abierto (nunca
// en pleno EN_PARTIDA, ver el plan "Cerrar Social v1"). Se limita a
// avisar y a emitir "unirse" -- quien lo instancia decide cómo unirse de
// verdad (mismo flujo que el resto de la app).
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

    /// Muestra el banner con los datos de una invitación entrante, y
    /// arranca el auto-descarte a los ~20s.
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
    anchors.topMargin: 16 * Tema.escala
    // Por encima de cualquier overlay de pantalla -- mismo motivo que el
    // z: 100 del overlay de reconexión (Main.qml): un banner de invitación
    // debe verse aunque llegue mientras hay otro overlay de menú abierto.
    z: 200
    width: Math.min(420 * Tema.escala, (parent ? parent.width : 420) - 40 * Tema.escala)
    height: filaBanner.height + 24 * Tema.escala
    radius: 10 * Tema.escala
    color: Tema.colorPanel
    border.width: 1
    border.color: Tema.colorAccent

    Timer {
        id: temporizadorAutoDescarte
        interval: 20000
        onTriggered: banner.visible = false
    }

    Row {
        id: filaBanner
        anchors.centerIn: parent
        width: parent.width - 24 * Tema.escala
        spacing: 12 * Tema.escala

        Avatar {
            anchors.verticalCenter: parent.verticalCenter
            letra: banner.fromUsername.length > 0 ? banner.fromUsername.charAt(0).toUpperCase() : "?"
            tamano: 32 * Tema.escala
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 32 * Tema.escala - 2 * (12 * Tema.escala) - botonesBanner.width
            wrapMode: Text.WordWrap
            text: banner.fromUsername + " te invitó a su sala" +
                  (banner.nombreSala !== "" ? " (" + banner.nombreSala + ")" : "")
            color: Tema.colorTexto
            font.pixelSize: 12 * Tema.escala
        }
        Row {
            id: botonesBanner
            anchors.verticalCenter: parent.verticalCenter
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
