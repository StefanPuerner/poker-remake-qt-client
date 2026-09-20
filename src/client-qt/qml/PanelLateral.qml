// PanelLateral.qml — panel lateral de la partida: historial + chat en una sola tarjeta.
//
// Estilo "ficha de casino" como el resto de la app (tarjetas de Salas, Social...): sombra corta,
// degradado con dithering, doble bisel con hilo dorado interior y selector segmentado con punto
// de aviso cuando llega un mensaje de chat estando en el historial. Extraído de Main.qml.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Item {
    id: panelLateral
    property var modeloHistorial
    property var modeloChat
    property string miNombre
    property bool mostrandoChat: false
    // Mensajes de chat llegados con la pestaña de historial abierta (punto de aviso en "Chat").
    property int chatSinLeer: 0
    property int _ultimoConteoChat: 0
    onMostrandoChatChanged: if (mostrandoChat) chatSinLeer = 0
    Connections {
        target: panelLateral.modeloChat
        function onCountChanged() {
            var n = panelLateral.modeloChat.count;
            if (n > panelLateral._ultimoConteoChat && !panelLateral.mostrandoChat) panelLateral.chatSinLeer += n - panelLateral._ultimoConteoChat;
            panelLateral._ultimoConteoChat = n;
        }
    }

    // Sombra desplazada (sin blur real): separa la tarjeta del tapete.
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3 * Tema.escala
        anchors.leftMargin: 2 * Tema.escala
        anchors.rightMargin: -2 * Tema.escala
        anchors.bottomMargin: -3 * Tema.escala
        radius: 10 * Tema.escala
        color: "black"
        opacity: 0.35
    }
    Rectangle {
        id: tarjeta
        anchors.fill: parent
        radius: 10 * Tema.escala
        border.width: 1.2
        border.color: Qt.rgba(0, 0, 0, 0.4)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.65) }
            GradientStop { position: 0.18; color: Qt.lighter(Tema.colorPanel, 1.4) }
            GradientStop { position: 1.0; color: Tema.colorPanel }
        }
        // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
        layer.enabled: true
        layer.effect: ShaderEffect {
            property variant source
            property real amplitud: 30.0
            fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
        }
        // Hilo dorado por dentro del bisel exterior -- el "doble bisel" de ficha de casino.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2 * Tema.escala
            radius: parent.radius - 2 * Tema.escala
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.16)
        }
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

    SelectorSegmentado {
        id: pestanas
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12 * Tema.escala
        height: 38 * Tema.escala
        width: parent.width - 24 * Tema.escala
        opciones: [Idioma.t("tab_historial"), Idioma.t("tab_chat")]
        avisos: [false, panelLateral.chatSinLeer > 0]
        seleccionado: panelLateral.mostrandoChat ? 1 : 0
        onElegido: (indice) => panelLateral.mostrandoChat = indice === 1
    }

    // ── Historial: una fila por evento, con una marca de color a la izquierda según su tipo; las
    // cabeceras de mano ("── Mano 13 ──") van como separadores centrados.
    ListView {
        id: listaHistorial
        visible: !panelLateral.mostrandoChat
        anchors.top: pestanas.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12 * Tema.escala
        anchors.topMargin: 12 * Tema.escala
        clip: true
        spacing: 2 * Tema.escala
        model: panelLateral.modeloHistorial
        onCountChanged: Qt.callLater(positionViewAtEnd)
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 4 * Tema.escala
                radius: width / 2
                color: Tema.colorAccent
                opacity: 0.45
            }
        }
        delegate: Item {
            id: filaHistorial
            required property string linea
            required property string hora
            required property string tipo
            required property string jugador
            readonly property bool esSeparador: tipo === "separador"
            readonly property bool esMio: jugador === panelLateral.miNombre && jugador.length > 0
            width: ListView.view.width - 8 * Tema.escala
            height: esSeparador ? 26 * Tema.escala : Math.max(textoLinea.implicitHeight + 8 * Tema.escala, 22 * Tema.escala)

            // Separador de mano: línea — texto — línea.
            Row {
                visible: filaHistorial.esSeparador
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 8 * Tema.escala
                Rectangle {
                    width: (parent.width - textoSeparador.implicitWidth - 2 * parent.spacing) / 2
                    height: 1
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.35)
                }
                Text {
                    id: textoSeparador
                    text: filaHistorial.linea.replace(/[─—-]/g, "").trim()
                    color: Tema.colorAccent
                    font.pixelSize: 11 * Tema.escala
                    font.bold: true
                    font.letterSpacing: 1
                    font.family: Tema.fuenteElegante
                }
                Rectangle {
                    width: (parent.width - textoSeparador.implicitWidth - 2 * parent.spacing) / 2
                    height: 1
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.35)
                }
            }

            // Fila normal.
            Rectangle {
                visible: !filaHistorial.esSeparador
                anchors.fill: parent
                radius: 6 * Tema.escala
                color: filaHistorial.esMio ? Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.09)
                                            : Qt.rgba(1, 1, 1, 0.025)
                Rectangle {   // marca de color del tipo de evento
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 3 * Tema.escala
                    anchors.bottomMargin: 3 * Tema.escala
                    anchors.leftMargin: 3 * Tema.escala
                    width: 3 * Tema.escala
                    radius: width / 2
                    color: panelLateral.colorTipoHistorial(filaHistorial.tipo)
                }
                Text {
                    id: textoLinea
                    anchors.left: parent.left
                    anchors.leftMargin: 12 * Tema.escala
                    anchors.right: textoHoraHistorial.left
                    anchors.rightMargin: 8 * Tema.escala
                    anchors.verticalCenter: parent.verticalCenter
                    // El nombre del protagonista lleva su color aparte (dorado si eres tú).
                    textFormat: Text.RichText
                    font.pixelSize: 13 * Tema.escala
                    text: (filaHistorial.jugador.length > 0
                               ? "<font color=\"" + panelLateral.colorNombreHistorial(filaHistorial.jugador)
                                     + "\"><b>" + panelLateral.escapeHtml(filaHistorial.jugador) + "</b></font>"
                               : "") + panelLateral.escapeHtml(filaHistorial.linea)
                    color: Tema.colorTexto
                    wrapMode: Text.WordWrap
                }
                Text {
                    id: textoHoraHistorial
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * Tema.escala
                    anchors.verticalCenter: parent.verticalCenter
                    text: filaHistorial.hora
                    color: Tema.colorTextoMuyTenue
                    font.pixelSize: 10 * Tema.escala
                }
            }
        }
    }

    // ── Chat de la partida: burbujas (las propias a la derecha con filo dorado, las ajenas a la
    // izquierda) y el campo de texto + enviar abajo.
    Column {
        visible: panelLateral.mostrandoChat
        anchors.top: pestanas.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12 * Tema.escala
        anchors.topMargin: 12 * Tema.escala
        spacing: 8 * Tema.escala

        ListView {
            id: listaChat
            width: parent.width
            height: parent.height - filaEntradaChat.height - parent.spacing
            // Con append(), "BottomToTop" mete los mensajes nuevos arriba, no abajo: el orden
            // normal + ir al final es lo correcto (ver ChatBox).
            clip: true
            spacing: 4 * Tema.escala
            model: panelLateral.modeloChat
            onCountChanged: Qt.callLater(positionViewAtEnd)
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 4 * Tema.escala
                    radius: width / 2
                    color: Tema.colorAccent
                    opacity: 0.45
                }
            }
            delegate: Item {
                required property string autor
                required property string mensaje
                required property string hora
                property bool esPropio: autor === panelLateral.miNombre
                width: ListView.view.width - 8 * Tema.escala
                height: columnaBurbujaPartida.height

                // Medidor invisible, sin wrap ni restricción de ancho (evita la dependencia circular
                // ancho de burbuja <-> ancho del texto; ver ChatBox.qml).
                Text {
                    id: medidorPartida
                    visible: false
                    text: mensaje
                    font.pixelSize: 13 * Tema.escala
                }

                Column {
                    id: columnaBurbujaPartida
                    x: esPropio ? parent.width - width : 0
                    width: Math.min(medidorPartida.implicitWidth + 26 * Tema.escala, parent.width * 0.82)
                    spacing: 2 * Tema.escala

                    Text {
                        anchors.right: esPropio ? parent.right : undefined
                        text: (esPropio ? Idioma.t("yo_chat") : autor) + " · " + hora
                        color: esPropio ? Tema.colorAccent : Tema.colorTextoMuyTenue
                        font.pixelSize: 10 * Tema.escala
                    }
                    Rectangle {
                        width: parent.width
                        height: textoBurbujaPartida.implicitHeight + 16 * Tema.escala
                        radius: 12 * Tema.escala
                        border.width: 1
                        border.color: esPropio ? Tema.colorAccent : Qt.rgba(1, 1, 1, 0.08)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: esPropio ? Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.26)
                                                                            : Qt.lighter(Tema.colorTapete, 1.25) }
                            GradientStop { position: 1.0; color: esPropio ? Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.12)
                                                                            : Tema.colorTapete }
                        }
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
                // El placeholder de Material flota hacia arriba al enfocar y se solapa con nuestro
                // borde dibujado a mano: más simple ocultarlo directamente.
                placeholderText: (activeFocus || text.length > 0) ? "" : Idioma.t("placeholder_mensaje_chat")
                placeholderTextColor: Tema.colorTextoTenue
                background: MarcoHueco {
                    radius: 8 * Tema.escala
                    activo: campoChatPanel.activeFocus
                }
                // Enter manda el mensaje directamente.
                onAccepted: botonEnviarPanel.clicked()
            }
            BotonRelleno {
                id: botonEnviarPanel
                height: 44 * Tema.escala
                text: Idioma.t("boton_enviar")
                onClicked: {
                    // Enter en el campo vacío no manda un mensaje en blanco (ver ChatBox.qml).
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
