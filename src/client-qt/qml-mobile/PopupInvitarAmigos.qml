// PopupInvitarAmigos.qml (móvil) — mismo rol que el de escritorio (ver
// src/client-qt/qml/PopupInvitarAmigos.qml): invita a un amigo CONECTADO
// ahora mismo a la sala actual, desde el Lobby.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Popup {
    id: popup
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(320 * Tema.escala, (parent ? parent.width : 320) - 40 * Tema.escala)
    padding: 18 * Tema.escala

    property string servidorHost
    property int servidorPuerto
    property string salaId
    property var listaAmigos

    // Filtro ESTRICTO a "CONECTADO" -- ver el comentario largo en la
    // versión de escritorio (un amigo EN_PARTIDA nunca es alcanzable por
    // el socket de presencia).
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

    function abrir() {
        mensajeEstado = "";
        redcliente.listarAmigos(servidorHost, servidorPuerto);
        popup.open();
    }

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
        radius: 10 * Tema.escala
        border.width: 1
        border.color: Tema.colorAccent
    }

    contentItem: Column {
        spacing: 10 * Tema.escala

        Text {
            width: parent.width
            text: "Invitar a la sala"
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.bold: true
            font.pixelSize: 15 * Tema.escala
        }

        Text {
            width: parent.width
            visible: popup.amigosConectados.length === 0
            wrapMode: Text.WordWrap
            text: "Ninguno de tus amigos está conectado ahora mismo."
            color: Tema.colorTextoTenue
            font.pixelSize: 11 * Tema.escala
        }

        Repeater {
            model: popup.amigosConectados
            delegate: Row {
                required property var modelData
                width: 284 * Tema.escala
                height: Tema.tamanoMinTactil
                spacing: 8 * Tema.escala
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 150 * Tema.escala
                    text: modelData.username
                    color: Tema.colorTexto
                    font.pixelSize: 12 * Tema.escala
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
            font.pixelSize: 11 * Tema.escala
        }
    }
}
