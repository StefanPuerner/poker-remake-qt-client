// PanelLateral.qml — panel lateral de la partida: historial + chat en una
// sola caja, con pestañas integradas arriba (en vez del botón suelto + dos
// cajas separadas que había antes) — como en el boceto. Extraído de
// Main.qml.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Rectangle {
    id: panelLateral
    property var modeloHistorial
    property var modeloChat
    property string miNombre
    property bool mostrandoChat: false
    radius: 6 * Tema.escala
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.3)
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
        GradientStop { position: 1.0; color: Tema.colorPanel }
    }

    // El historial usa Text.RichText para colorear el punto y el nombre
    // del jugador dentro de la misma línea — escapar por si un nombre de
    // jugador (no viene sanitizado contra HTML, solo contra el protocolo)
    // contuviera "<", ">" o "&". Solo lo usa este panel en todo el
    // programa, así que vive aquí en vez de en Main.qml.
    function escapeHtml(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // Color del punto de cada entrada del historial, según la
    // categoría que manda NetworkClient::eventoJuego() (ver su
    // comentario para la lista completa) — así se distinguen de un
    // vistazo los folds, subidas, showdown, avisos del sistema, etc.
    // Devuelve hex limpio (Tema.colorHex) porque esto se usa dentro
    // de un <font color=...>, no como property color directa.
    function colorTipoHistorial(tipo) {
        switch (tipo) {
            case "fold": return Tema.colorHex(Tema.colorPeligro);
            case "agresion": return Tema.colorHex(Tema.colorAccent);
            case "showdown": return Tema.colorHex(Tema.colorAccent);
            case "error": return Tema.colorHex(Tema.colorPeligro);
            case "separador": return Tema.colorHex(Tema.colorTextoMuyTenue);
            case "sistema": return Tema.colorHex(Tema.colorTextoTenue);
            default: return Tema.colorHex(Tema.colorTextoTenue); // "accion" (check/call) y cualquier otro
        }
    }

    // Color del nombre de jugador dentro de una línea: dorado si eres
    // tú, otro tono si es cualquier otro — así los nombres se
    // distinguen del resto del texto de un vistazo.
    function colorNombreHistorial(jugador) {
        return Tema.colorHex(jugador === miNombre ? Tema.colorAccent : Tema.colorNombreAjeno);
    }

    Row {
        id: pestanas
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 10 * Tema.escala
        spacing: 8 * Tema.escala

        Rectangle {
            width: textoTabHistorial.implicitWidth + 24 * Tema.escala
            height: 30 * Tema.escala
            radius: height / 2
            color: !panelLateral.mostrandoChat ? Tema.colorAccent : "transparent"
            Text {
                id: textoTabHistorial
                anchors.centerIn: parent
                text: "Historial"
                color: !panelLateral.mostrandoChat ? Tema.colorPanel : Tema.colorTextoTenue
                font.bold: !panelLateral.mostrandoChat
                font.pixelSize: 12 * Tema.escala
            }
            MouseArea {
                anchors.fill: parent
                onClicked: panelLateral.mostrandoChat = false
            }
        }
        Rectangle {
            width: textoTabChat.implicitWidth + 24 * Tema.escala
            height: 30 * Tema.escala
            radius: height / 2
            color: panelLateral.mostrandoChat ? Tema.colorAccent : "transparent"
            Text {
                id: textoTabChat
                anchors.centerIn: parent
                text: "Chat"
                color: panelLateral.mostrandoChat ? Tema.colorPanel : Tema.colorTextoTenue
                font.bold: panelLateral.mostrandoChat
                font.pixelSize: 12 * Tema.escala
            }
            MouseArea {
                anchors.fill: parent
                onClicked: panelLateral.mostrandoChat = true
            }
        }
    }

    ListView {
        visible: !panelLateral.mostrandoChat
        anchors.top: pestanas.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10 * Tema.escala
        anchors.topMargin: 12 * Tema.escala
        clip: true
        model: panelLateral.modeloHistorial
        onCountChanged: Qt.callLater(positionViewAtEnd)
        delegate: Item {
            required property string linea
            required property string hora
            required property string tipo
            required property string jugador
            width: ListView.view.width
            height: Math.max(textoLinea.height, 16 * Tema.escala)
            Text {
                id: textoLinea
                anchors.left: parent.left
                anchors.right: textoHoraHistorial.left
                anchors.rightMargin: 8 * Tema.escala
                // El punto lleva color por categoría (colorTipoHistorial)
                // y, si la línea tiene un protagonista, su nombre
                // también lleva color aparte (colorNombreHistorial:
                // dorado si eres tú, otro tono si es cualquier otro) —
                // así los nombres destacan del resto del texto, que
                // sigue en blanco normal.
                textFormat: Text.RichText
                font.pixelSize: 13 * Tema.escala
                text: "<font color=\"" + panelLateral.colorTipoHistorial(tipo) + "\">●</font> " +
                      (jugador.length > 0
                           ? "<font color=\"" + panelLateral.colorNombreHistorial(jugador) +
                                 "\"><b>" + panelLateral.escapeHtml(jugador) + "</b></font>"
                           : "") +
                      panelLateral.escapeHtml(linea)
                color: Tema.colorTexto
                wrapMode: Text.WordWrap
            }
            Text {
                id: textoHoraHistorial
                anchors.right: parent.right
                anchors.verticalCenter: textoLinea.verticalCenter
                text: hora
                color: Tema.colorTextoMuyTenue
                font.pixelSize: 10 * Tema.escala
            }
        }
    }

    Column {
        visible: panelLateral.mostrandoChat
        anchors.top: pestanas.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10 * Tema.escala
        anchors.topMargin: 12 * Tema.escala
        spacing: 8 * Tema.escala

        ListView {
            id: listaChat
            width: parent.width
            height: parent.height - filaEntradaChat.height - parent.spacing
            // Ver el comentario largo en el ListView de ChatBox: con
            // append(), "BottomToTop" mete los mensajes nuevos arriba,
            // no abajo — el orden normal + ir al final es lo correcto.
            clip: true
            model: panelLateral.modeloChat
            onCountChanged: Qt.callLater(positionViewAtEnd)
            // Mismo estilo de burbujas que ChatBox (chat de la sala):
            // las propias a la derecha con tinte dorado, las ajenas a
            // la izquierda en verde tapete — antes esto era una lista
            // plana "autor: mensaje" sin distinguir quién escribió qué.
            delegate: Item {
                required property string autor
                required property string mensaje
                required property string hora
                property bool esPropio: autor === panelLateral.miNombre
                width: ListView.view.width
                height: columnaBurbujaPartida.height

                // Medidor invisible, sin wrap ni restricción de ancho --
                // ver columnaBurbujaPartida.width. Mismo motivo que en
                // ChatBox.qml: sin esto, el ancho de la burbuja salía del
                // implicitWidth de un Text que a su vez tomaba su propio
                // ancho DE la burbuja (vía anchors.fill) -- con wrap
                // activo eso es una dependencia circular que Qt no
                // siempre resuelve bien, y el texto se salía por fuera en
                // mensajes largos/multilínea.
                Text {
                    id: medidorPartida
                    visible: false
                    text: mensaje
                    font.pixelSize: 13 * Tema.escala
                }

                Column {
                    id: columnaBurbujaPartida
                    x: esPropio ? parent.width - width : 0
                    width: Math.min(medidorPartida.implicitWidth + 24 * Tema.escala, parent.width * 0.8)
                    spacing: 2 * Tema.escala

                    Text {
                        text: (esPropio ? "Tú" : autor) + " · " + hora
                        color: Tema.colorTextoMuyTenue
                        font.pixelSize: 10 * Tema.escala
                    }
                    Rectangle {
                        width: parent.width
                        height: textoBurbujaPartida.implicitHeight + 16 * Tema.escala
                        radius: 12 * Tema.escala
                        color: esPropio ? Qt.rgba(0.75, 0.56, 0.24, 0.18) : Tema.colorTapete
                        border.width: esPropio ? 1 : 0
                        border.color: Tema.colorAccent
                        Text {
                            id: textoBurbujaPartida
                            anchors.fill: parent
                            anchors.margins: 8 * Tema.escala
                            text: mensaje
                            color: Tema.colorTexto
                            font.pixelSize: 13 * Tema.escala
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        Row {
            id: filaEntradaChat
            width: parent.width
            spacing: 8 * Tema.escala
            TextField {
                id: campoChatPanel
                width: parent.width - botonEnviarPanel.width - parent.spacing
                height: 44 * Tema.escala
                color: Tema.colorTexto
                font.pixelSize: 13 * Tema.escala
                // Ver el comentario largo en "textoChat" (ChatBox):
                // el placeholder de Material flota hacia arriba al
                // enfocar y se solapa con nuestro borde dibujado a
                // mano — más simple ocultarlo directamente.
                placeholderText: (activeFocus || text.length > 0) ? "" : "Escribe un mensaje..."
                placeholderTextColor: Tema.colorTextoTenue
                // Antes sin "background": salía con el estilo por
                // defecto de Qt Quick Controls (gris claro), fuera de
                // sitio en este tema oscuro — mismo fondo que ChatBox.
                background: Rectangle {
                    color: Tema.colorFondo
                    radius: 8 * Tema.escala
                    border.width: 1
                    border.color: campoChatPanel.activeFocus ? Tema.colorAccent : Tema.colorBorde
                }
                // Antes había que Tab + Espacio hasta "Enviar" tras
                // escribir — Enter manda el mensaje directamente.
                onAccepted: botonEnviarPanel.clicked()
            }
            BotonRelleno {
                id: botonEnviarPanel
                height: 44 * Tema.escala
                text: "Enviar"
                onClicked: {
                    // Enter en el campo vacío ya no debe mandar un
                    // mensaje en blanco (ver el comentario en ChatBox.qml).
                    if (campoChatPanel.text.length === 0) return;
                    redcliente.enviarChat(campoChatPanel.text, "partida");
                    panelLateral.modeloChat.append({
                        autor: panelLateral.miNombre,
                        mensaje: campoChatPanel.text,
                        hora: Qt.formatTime(new Date(), "hh:mm")
                    });  // eco local
                    campoChatPanel.text = "";
                }
            }
        }
    }
}
