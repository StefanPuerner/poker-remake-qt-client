// PopupInvitarAmigos.qml — invita a un amigo CONECTADO ahora mismo a la
// sala actual. Vive en la sala de espera, junto a "Código para invitar"
// (decisión de producto ya confirmada, ver el plan "Cerrar Social v1"),
// no en la pestaña Social.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Popup {
    id: popup
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(360 * Tema.escala, (parent ? parent.width : 360) - 60 * Tema.escala)
    padding: 20 * Tema.escala

    property string servidorHost
    property int servidorPuerto
    property string salaId
    // El mismo modeloAmigos que ya carga la pestaña Social (ListModel de
    // Main.qml) -- reutilizado en vez de mantener una copia propia.
    property var listaAmigos

    // Filtro ESTRICTO a "CONECTADO" -- NO "!== DESCONECTADO". Un amigo
    // EN_PARTIDA nunca es alcanzable por el socket de presencia (se cierra
    // en cuanto entra a una sala, ver el plan), así que invitarlo fallaría
    // sin más explicación.
    property var amigosConectados: []
    function recalcularAmigosConectados() {
        var out = [];
        for (var i = 0; i < (popup.listaAmigos ? popup.listaAmigos.count : 0); i++) {
            var f = popup.listaAmigos.get(i);
            if (f.estado === "CONECTADO") out.push(f);
        }
        popup.amigosConectados = out;
    }

    property string mensajeEstado: ""

    /// Refresca la lista de amigos (para tener presencia al día) y abre.
    function abrir() {
        mensajeEstado = "";
        redcliente.listarAmigos(servidorHost, servidorPuerto);
        popup.open();
    }

    // modeloAmigos.clear()+append() (ver Main.qml::onAmigosActualizados)
    // siempre pasa por count=0 antes de repoblarse, así que reaccionar a
    // countChanged del modelo en sí es más fiable que escuchar la señal de
    // red directamente -- no depende del orden relativo entre los
    // Connections de este popup y los de Main.qml sobre esa misma señal.
    Connections {
        target: popup.listaAmigos
        function onCountChanged() { popup.recalcularAmigosConectados(); }
    }
    Connections {
        target: redcliente
        function onInvitacionEnviada() { popup.mensajeEstado = "Invitación enviada."; }
        function onInvitacionError(mensaje) { popup.mensajeEstado = mensaje; }
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
            width: parent.width
            text: "Invitar a la sala"
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.bold: true
            font.pixelSize: 16 * Tema.escala
        }

        Text {
            width: parent.width
            visible: popup.amigosConectados.length === 0
            wrapMode: Text.WordWrap
            text: "Ninguno de tus amigos está conectado ahora mismo."
            color: Tema.colorTextoTenue
            font.pixelSize: 12 * Tema.escala
        }

        Repeater {
            model: popup.amigosConectados
            delegate: Row {
                required property var modelData
                width: 320 * Tema.escala
                height: 40 * Tema.escala
                spacing: 10 * Tema.escala
                Avatar {
                    anchors.verticalCenter: parent.verticalCenter
                    letra: modelData.username.length > 0 ? modelData.username.charAt(0).toUpperCase() : "?"
                    tamano: 28 * Tema.escala
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 180 * Tema.escala
                    text: modelData.username
                    color: Tema.colorTexto
                    font.pixelSize: 13 * Tema.escala
                    elide: Text.ElideRight
                }
                BotonContorno {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Invitar"
                    onClicked: {
                        popup.mensajeEstado = "";
                        redcliente.invitarASala(popup.servidorHost, popup.servidorPuerto,
                                                 modelData.accountId, popup.salaId);
                    }
                }
            }
        }

        Text {
            visible: popup.mensajeEstado !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            text: popup.mensajeEstado
            color: Tema.colorTextoTenue
            font.pixelSize: 12 * Tema.escala
        }
    }
}
