// VistaChatDirecto.qml (móvil) — mismo rol que el de escritorio (ver
// src/client-qt/qml/VistaChatDirecto.qml): conversación 1:1 con un amigo,
// como overlay (Popup), no un panel embebido en la pestaña "Chats" -- ver
// el comentario largo de la versión de escritorio para el porqué
// (corrección post-playtest 2026-08-27). Reutiliza ChatBox.qml.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Popup {
    id: popup
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(320 * Tema.escala, (parent ? parent.width : 320) - 32 * Tema.escala)
    padding: 14 * Tema.escala

    property int accountId: -1
    property string username: ""
    // Se mantiene al día desde reconstruirModeloAmigosConChat() (Main.qml),
    // no solo en el instante de abrir -- mismo criterio que escritorio, así
    // la cabecera no se queda con un estado de presencia congelado
    // mientras la conversación sigue abierta.
    property string estado: ""
    property string miUsername: ""
    property string servidorHost
    property int servidorPuerto

    ListModel {
        id: modeloConversacion
    }

    function abrir(id, nombre, estadoInicial) {
        popup.accountId = id;
        popup.username = nombre;
        popup.estado = estadoInicial || "";
        modeloConversacion.clear();
        redcliente.listarConversacion(popup.servidorHost, popup.servidorPuerto, id);
        popup.open();
    }

    Connections {
        target: redcliente
        function onConversacionActualizada(mensajes) {
            modeloConversacion.clear();
            for (var i = 0; i < mensajes.length; i++) {
                var m = mensajes[i];
                modeloConversacion.append({
                    autor: m.fromAccountId === popup.accountId ? popup.username : popup.miUsername,
                    mensaje: m.texto,
                    hora: Qt.formatTime(new Date(m.creadoEn * 1000), "hh:mm")
                });
            }
        }
        function onMensajeDirectoRecibido(fromAccountId, fromUsername, texto, creadoEn, mensajeId) {
            if (popup.visible && fromAccountId === popup.accountId) {
                redcliente.listarConversacion(popup.servidorHost, popup.servidorPuerto, popup.accountId);
            }
        }
    }

    background: Rectangle {
        color: Tema.colorPanel
        radius: 10 * Tema.escala
        border.width: 1
        border.color: Tema.colorAccent
    }

    contentItem: Column {
        spacing: 8 * Tema.escala

        Column {
            width: parent.width
            spacing: 3 * Tema.escala
            Text {
                width: parent.width
                text: popup.username
                color: Tema.colorTexto
                font.bold: true
                font.pixelSize: 13 * Tema.escala
            }
            Row {
                spacing: 5 * Tema.escala
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7 * Tema.escala
                    height: 7 * Tema.escala
                    radius: width / 2
                    color: popup.estado === "CONECTADO" ? "#7FAE7A"
                           : popup.estado === "EN_PARTIDA" ? Tema.colorAccent
                           : Tema.colorTextoMuyTenue
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: popup.estado === "CONECTADO" ? "Conectado"
                          : popup.estado === "EN_PARTIDA" ? "En partida"
                          : "Desconectado"
                    color: Tema.colorTextoTenue
                    font.pixelSize: 10 * Tema.escala
                }
            }
        }

        ChatBox {
            width: 292 * Tema.escala
            height: 340 * Tema.escala
            activo: true
            modelo: modeloConversacion
            miNombre: popup.miUsername
            onEnviar: (texto) => {
                redcliente.enviarMensajeDirecto(popup.servidorHost, popup.servidorPuerto, popup.accountId, texto);
            }
        }
    }
}
