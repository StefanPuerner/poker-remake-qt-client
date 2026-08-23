// CajonPartida.qml — sustituye a la barra de acciones inferior + el
// IconoAjustes flotante durante la pantalla de Partida: un panel fijo a la
// derecha de la mesa (1/3 del ancho, ver Main.qml) con pestañas propias en
// vez de una franja de botones siempre visible. Decisión del usuario tras
// ver el primer boceto de "bandas horizontales" (que sacrificaba la mesa
// clásica) — aquí se mantiene la mesa/asientos tal cual, solo se le da un
// contenedor más alto que ancho (2/3 en vez de casi toda la pantalla), lo
// que ya evita el solape de raíz sin tocar Mesa.qml.
//
// Pestañas: Turno (qué está pasando ahora, sin botones) / Cartas (las
// tuyas, grandes) / Estim. (predicción actual/probable/máxima, ausente en
// móvil hasta ahora) / Opciones (los botones de acción) / Historial (nuevo
// en móvil) / Chat (nuevo en móvil, resuelve el pendiente "Chat/historial
// en Partida móvil").
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile
import QtQuick.Controls

Rectangle {
    id: cajon

    property string turnoNombre: ""
    required property bool tuTurno
    property real fraccionTiempo: 1.0
    property int bote: 0
    property string rondaActual: ""
    property int manoActual: 0
    property int objetivoManos: 0
    property string comboActual: ""
    property string comboProbable: ""
    property string comboMaxima: ""
    property string miCarta1: ""
    property string miCarta2: ""
    property int miSaldoActual: 0
    property int aPagarParaIgualar: 0
    property int minSubidaActual: 0
    property int maxSubidaActual: 0
    property int ciegaActual: 0
    property bool puedoRecomprar: false
    property bool recompraSolicitada: false
    property bool conectado: true
    property string nombreJugador: ""
    // Ver "Cliente" en el cajón de ajustes (Main.qml) -- con el ajuste
    // activo, el botón ALL pide un segundo toque antes de mandar la
    // acción, para evitar un ALL-IN por error. Desactivado por defecto,
    // mismo criterio que escritorio (ventana.confirmarAllIn ahí).
    property bool confirmarAllIn: false
    required property var modeloHistorial
    required property var modeloChat
    signal abrirAjustes()
    // No se asigna a las propiedades "tuTurno"/"recompraSolicitada"
    // directamente desde dentro (romperían el binding de una vía que las
    // liga a ventana.tuTurno/ventana.recompraSolicitada en Main.qml — una
    // asignación local sustituye el binding para siempre). En su lugar,
    // estas señales dejan que Main.qml actualice la fuente de verdad.
    signal decisionEnviada()
    signal recompraPedida()

    property string pestanaActiva: "Turno"

    // Llamado desde Main.qml (onEsMiTurno) al empezar un turno nuevo:
    // resetea el estado LOCAL de los controles de "Opciones" que
    // Main.qml no puede tocar directamente (son ids internos de este
    // componente) — mismo efecto que antes tenía la barra de acciones
    // cuando vivía a nivel de Main.qml.
    function prepararNuevoTurno(valorInicialSubida) {
        botonAllInCajon.confirmando = false;
        selectorSubidaCajon.valor = valorInicialSubida;
    }

    radius: 10 * Tema.escala
    color: Tema.colorPanel
    border.width: tuTurno ? 2 : 1
    border.color: tuTurno ? Tema.colorAccent : Tema.colorBorde

    // Resplandor de turno: mismo lenguaje visual que el aro del asiento
    // activo (Asiento.qml, dos anillos rgba estáticos, sin animación) —
    // aquí alrededor de TODO el cajón, para que se note sin importar en
    // qué pestaña estés.
    Rectangle {
        visible: cajon.tuTurno
        anchors.centerIn: parent
        width: parent.width + 10
        height: parent.height + 10
        radius: parent.radius + 5
        color: "transparent"
        border.width: 8 * Tema.escala
        border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.10)
    }
    Rectangle {
        visible: cajon.tuTurno
        anchors.centerIn: parent
        width: parent.width + 4
        height: parent.height + 4
        radius: parent.radius + 2
        color: "transparent"
        border.width: 3 * Tema.escala
        border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.28)
    }

    Column {
        anchors.fill: parent
        anchors.margins: 1

        // ── Cabecera: logo + conexión + ajustes ─────────────────────────
        Item {
            width: parent.width
            height: Math.max(Tema.tamanoMinTactil, 40 * Tema.escala)

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10 * Tema.escala
                spacing: 6 * Tema.escala
                Text {
                    text: "♣"
                    color: Tema.colorAccent
                    font.pixelSize: 15 * Tema.escala
                }
                Text {
                    text: "PokerRemake"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 12 * Tema.escala
                    font.family: Tema.fuenteElegante
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7 * Tema.escala
                    height: 7 * Tema.escala
                    radius: width / 2
                    color: cajon.conectado ? Tema.colorNombreAjeno : Tema.colorAccent
                }
            }

            IconoAjustes {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 8 * Tema.escala
                onAbrirAjustes: cajon.abrirAjustes()
            }
        }

        Rectangle { width: parent.width; height: 1; color: Tema.colorBorde }

        // ── Tiras de pestañas ────────────────────────────────────────────
        Row {
            id: tiraPestanas
            width: parent.width
            height: 44 * Tema.escala

            // Sin iconos por pestaña a propósito: los símbolos usados antes
            // (⏱✓☰💬) tofu'ban en este build de Android (mismo problema
            // que "✎"/"🗑" en partidas guardadas) -- solo texto, garantizado.
            // "Opciones" se fusionó con "Turno" (pedido explícito, una
            // pestaña menos sin perder utilidad): la misma pestaña
            // muestra el estado del turno cuando no es el tuyo, y los
            // botones de acción en cuanto lo es.
            readonly property var nombres: ["Turno", "Cartas", "Estim.", "Historial", "Chat"]

            Repeater {
                model: tiraPestanas.nombres
                delegate: Item {
                    id: pestana
                    required property string modelData
                    required property int index
                    readonly property bool activa: cajon.pestanaActiva === modelData
                    width: tiraPestanas.width / tiraPestanas.nombres.length
                    height: tiraPestanas.height

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 2.5
                        color: pestana.activa ? Tema.colorAccent : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: pestana.modelData
                        color: pestana.activa ? Tema.colorAccent : Tema.colorTextoMuyTenue
                        font.pixelSize: 10 * Tema.escala
                        font.bold: pestana.activa
                    }
                    // Aviso de decisión pendiente: solo si es tu turno Y no
                    // estás ya mirando la pestaña que la resuelve.
                    Rectangle {
                        visible: cajon.tuTurno && pestana.modelData === "Turno" && !pestana.activa
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 4 * Tema.escala
                        width: 6 * Tema.escala
                        height: 6 * Tema.escala
                        radius: width / 2
                        color: Tema.colorPeligro
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: cajon.pestanaActiva = pestana.modelData
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Tema.colorBorde }

        // La cabecera fina con las cartas (visible en cualquier pestaña
        // que no fuera "Turno") se quitó: en real se veía permanentemente
        // por encima del resto del contenido en vez de quedarse en su
        // sitio en la columna. La pestaña "Cartas" ya cubre esa necesidad.

        // ── Contenido de la pestaña activa ───────────────────────────────
        Item {
            width: parent.width
            height: parent.height - y

            // — Cartas —
            Column {
                visible: cajon.pestanaActiva === "Cartas"
                anchors.centerIn: parent
                spacing: 10 * Tema.escala
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "TUS CARTAS"
                    color: Tema.colorTextoMuyTenue
                    font.pixelSize: 10 * Tema.escala
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10 * Tema.escala
                    Carta { codigo: cajon.miCarta1; propia: true }
                    Carta { codigo: cajon.miCarta2; propia: true }
                }
            }

            // — Estimación —
            Column {
                visible: cajon.pestanaActiva === "Estim."
                anchors.centerIn: parent
                width: parent.width - 30 * Tema.escala
                spacing: 12 * Tema.escala
                Repeater {
                    model: [
                        { etq: "Actual", val: cajon.comboActual, color: "white" },
                        { etq: "Probable", val: cajon.comboProbable, color: "#C7CFC9" },
                        { etq: "Máxima", val: cajon.comboMaxima, color: Tema.colorAccent }
                    ]
                    delegate: Column {
                        required property var modelData
                        width: parent.width
                        spacing: 2 * Tema.escala
                        Text {
                            text: modelData.etq.toUpperCase()
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 9 * Tema.escala
                        }
                        Text {
                            text: modelData.val !== "" ? modelData.val : "—"
                            color: modelData.color
                            font.bold: true
                            font.family: Tema.fuenteElegante
                            font.pixelSize: 15 * Tema.escala
                        }
                        Rectangle { width: parent.width; height: 1; color: Tema.colorBorde }
                    }
                }
            }

            // — Turno / Opciones (fusionadas) — la misma pestaña muestra el
            // estado del turno (anillo, de quién es, ronda/bote) cuando no
            // es el tuyo, y los botones de acción en cuanto lo es; pedido
            // explícito para quitar una pestaña sin perder ninguna
            // utilidad. Flickable porque en real los botones
            // (retirarse/igualar/subir/all + el stepper) no caben en el
            // alto disponible del cajón; así los de más abajo quedan
            // accesibles con scroll en vez de cortados.
            Flickable {
                visible: cajon.pestanaActiva === "Turno"
                anchors.fill: parent
                anchors.margins: 12 * Tema.escala
                contentWidth: width
                contentHeight: columnaOpcionesCajon.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

            Column {
                id: columnaOpcionesCajon
                width: parent.width
                spacing: 8 * Tema.escala

                // Estado informativo: no es tu turno y no puedes recomprar
                // -- lo que antes mostraba en solitario la pestaña "Turno".
                Column {
                    visible: !cajon.tuTurno && !cajon.puedoRecomprar
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    spacing: 10 * Tema.escala

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 64 * Tema.escala
                        height: 64 * Tema.escala
                        Canvas {
                            id: anilloCajon
                            anchors.fill: parent
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                var cx = width / 2, cy = height / 2, r = width / 2 - 3;
                                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.08);
                                ctx.lineWidth = 3;
                                ctx.beginPath();
                                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                                ctx.stroke();
                                ctx.strokeStyle = cajon.fraccionTiempo < 0.2 ? Tema.colorPeligro : Tema.colorAccent;
                                ctx.beginPath();
                                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + cajon.fraccionTiempo * 2 * Math.PI);
                                ctx.stroke();
                            }
                            // "onFraccionTiempoChanged" no puede ir en el Item
                            // padre: esa propiedad es de "cajon" (la raíz),
                            // asignarlo a un Item que no la tiene es un fallo
                            // de carga de QML, no solo un aviso -- rompe TODO
                            // el componente (visto en real: pantalla en blanco
                            // total, ver logcat). Connections sí puede
                            // escuchar la señal de un objeto ajeno.
                            Connections {
                                target: cajon
                                function onFraccionTiempoChanged() { anilloCajon.requestPaint(); }
                            }
                            Component.onCompleted: requestPaint()
                        }
                        Text {
                            anchors.centerIn: parent
                            text: cajon.turnoNombre.length > 0 ? cajon.turnoNombre.charAt(0) : "—"
                            color: Tema.colorAccent
                            font.family: Tema.fuenteElegante
                            font.bold: true
                            font.pixelSize: 20 * Tema.escala
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: cajon.turnoNombre !== "" ? "Turno de " + cajon.turnoNombre : "—"
                        color: "white"
                        font.bold: true
                        font.family: Tema.fuenteElegante
                        font.pixelSize: 14 * Tema.escala
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: cajon.rondaActual + " · Mano " + cajon.manoActual + " / " + cajon.objetivoManos
                        color: Tema.colorTextoTenue
                        font.pixelSize: 11 * Tema.escala
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Bote: " + cajon.bote
                        color: Tema.colorAccent
                        font.bold: true
                        font.family: Tema.fuenteElegante
                        font.pixelSize: 13 * Tema.escala
                    }
                }

                Column {
                    visible: cajon.tuTurno
                    width: parent.width
                    spacing: 8 * Tema.escala
                    BotonContorno {
                        width: parent.width
                        text: "Retirarse"
                        colorBorde: Tema.colorPeligro
                        onClicked: {
                            redcliente.enviarAccion("FOLD", 0);
                            cajon.decisionEnviada();
                        }
                    }
                    BotonContorno {
                        width: parent.width
                        text: cajon.aPagarParaIgualar > 0 ? "Igualar " + cajon.aPagarParaIgualar : "Pasar"
                        onClicked: {
                            redcliente.enviarAccion(cajon.aPagarParaIgualar > 0 ? "CALL" : "CHECK",
                                                     Math.min(cajon.aPagarParaIgualar, cajon.miSaldoActual));
                            cajon.decisionEnviada();
                        }
                    }
                    SelectorNumerico {
                        id: selectorSubidaCajon
                        anchors.horizontalCenter: parent.horizontalCenter
                        minimo: cajon.minSubidaActual
                        maximo: cajon.maxSubidaActual
                        paso: Math.max(1, cajon.ciegaActual)
                    }
                    BotonRelleno {
                        width: parent.width
                        text: "Subir"
                        enabled: cajon.maxSubidaActual > 0
                        onClicked: {
                            var total = Math.min(cajon.aPagarParaIgualar + selectorSubidaCajon.valor, cajon.miSaldoActual);
                            redcliente.enviarAccion("RAISE", total);
                            cajon.decisionEnviada();
                        }
                    }
                    BotonContorno {
                        id: botonAllInCajon
                        property bool confirmando: false
                        width: parent.width
                        text: confirmando ? "¿Seguro?" : "ALL"
                        colorBorde: Tema.colorPeligro
                        onClicked: {
                            if (cajon.confirmarAllIn && !confirmando) { confirmando = true; return; }
                            confirmando = false;
                            redcliente.enviarAccion("ALL_IN", cajon.miSaldoActual);
                            cajon.decisionEnviada();
                        }
                    }
                }

                Column {
                    visible: cajon.puedoRecomprar
                    width: parent.width
                    spacing: 8 * Tema.escala
                    Text {
                        width: parent.width
                        text: "Sin fichas"
                        color: Tema.colorTextoTenue
                        font.pixelSize: 12 * Tema.escala
                        horizontalAlignment: Text.AlignHCenter
                    }
                    BotonRelleno {
                        width: parent.width
                        text: cajon.recompraSolicitada ? "Enviada…" : "Recomprar"
                        enabled: !cajon.recompraSolicitada
                        onClicked: {
                            redcliente.pedirRecompra();
                            cajon.recompraPedida();
                        }
                    }
                }
            }
            }

            // — Historial —
            ListView {
                visible: cajon.pestanaActiva === "Historial"
                anchors.fill: parent
                anchors.margins: 10 * Tema.escala
                clip: true
                model: cajon.modeloHistorial
                onCountChanged: Qt.callLater(positionViewAtEnd)
                delegate: Item {
                    required property string linea
                    required property string tipo
                    required property string jugador
                    width: ListView.view.width
                    height: Math.max(textoLineaHist.height, 14 * Tema.escala)
                    Text {
                        id: textoLineaHist
                        width: parent.width
                        textFormat: Text.RichText
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11 * Tema.escala
                        color: "white"
                        text: "<font color=\"" + colorTipoHistCajon(tipo) + "\">●</font> " +
                              (jugador.length > 0
                                   ? "<font color=\"" + colorNombreHistCajon(jugador) + "\"><b>" +
                                     escapeHtmlCajon(jugador) + "</b></font> "
                                   : "") + escapeHtmlCajon(linea)
                    }
                }
            }

            // — Chat —
            Item {
                visible: cajon.pestanaActiva === "Chat"
                anchors.fill: parent
                anchors.margins: 10 * Tema.escala

                ListView {
                    id: listaChatCajon
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: filaEntradaChatCajon.top
                    anchors.bottomMargin: 8 * Tema.escala
                    clip: true
                    spacing: 6 * Tema.escala
                    model: cajon.modeloChat
                    onCountChanged: Qt.callLater(positionViewAtEnd)
                    delegate: Item {
                        required property string autor
                        required property string mensaje
                        readonly property bool esPropio: autor === cajon.nombreJugador
                        width: ListView.view.width
                        height: columnaBurbujaCajon.height

                        // Medidor invisible, sin wrap ni restricción de
                        // ancho -- ver columnaBurbujaCajon.width. Mismo
                        // motivo que en ChatBox.qml: sin esto, el ancho de
                        // la burbuja salía del implicitWidth de un Text
                        // que a su vez tomaba su propio ancho DE la
                        // burbuja (vía anchors.fill) -- con wrap activo
                        // eso es una dependencia circular que Qt no
                        // siempre resuelve bien, y el texto se salía por
                        // fuera en mensajes largos/multilínea (el bug
                        // reportado en el móvil).
                        Text {
                            id: medidorCajon
                            visible: false
                            text: mensaje
                            font.pixelSize: 11 * Tema.escala
                        }

                        Column {
                            id: columnaBurbujaCajon
                            x: esPropio ? parent.width - width : 0
                            width: Math.min(medidorCajon.implicitWidth + 20, parent.width * 0.85)
                            spacing: 1
                            Text {
                                text: esPropio ? "Tú" : autor
                                color: Tema.colorTextoMuyTenue
                                font.pixelSize: 9 * Tema.escala
                            }
                            Rectangle {
                                width: parent.width
                                height: textoBurbujaCajon.implicitHeight + 12 * Tema.escala
                                radius: 8 * Tema.escala
                                color: esPropio ? Qt.rgba(0.75, 0.56, 0.24, 0.18) : Tema.colorTapete
                                Text {
                                    id: textoBurbujaCajon
                                    anchors.fill: parent
                                    anchors.margins: 6 * Tema.escala
                                    text: mensaje
                                    color: "white"
                                    font.pixelSize: 11 * Tema.escala
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }

                Row {
                    id: filaEntradaChatCajon
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    spacing: 6 * Tema.escala
                    TextField {
                        id: textoChatCajon
                        width: parent.width - botonEnviarCajon.width - parent.spacing
                        height: Tema.tamanoMinTactil
                        color: "white"
                        font.pixelSize: 11 * Tema.escala
                        // Ver CampoEmergente.qml: sin esto, borrar una
                        // letra solo retrocedía el cursor sin borrarla.
                        inputMethodHints: Qt.ImhNoPredictiveText
                        placeholderText: "Escribe un mensaje…"
                        placeholderTextColor: Tema.colorTextoTenue
                        background: Rectangle {
                            color: Tema.colorFondo
                            radius: 6 * Tema.escala
                            border.width: 1
                            border.color: textoChatCajon.activeFocus ? Tema.colorAccent : Tema.colorBorde
                        }
                        onAccepted: botonEnviarCajon.clicked()
                    }
                    BotonRelleno {
                        id: botonEnviarCajon
                        height: Tema.tamanoMinTactil
                        text: "Enviar"
                        onClicked: {
                            if (textoChatCajon.text.length === 0) return;
                            redcliente.enviarChat(textoChatCajon.text, "partida");
                            cajon.modeloChat.append({
                                autor: cajon.nombreJugador,
                                mensaje: textoChatCajon.text,
                                hora: Qt.formatTime(new Date(), "hh:mm")
                            });
                            textoChatCajon.text = "";
                        }
                    }
                }
            }
        }
    }

    // Mismas funciones de color que PanelLateral.qml (escritorio) — ver su
    // comentario para la lista completa de categorías que manda
    // NetworkClient::eventoJuego().
    function colorTipoHistCajon(tipo) {
        switch (tipo) {
            case "fold": return Tema.colorHex(Tema.colorPeligro);
            case "agresion": return Tema.colorHex(Tema.colorAccent);
            case "showdown": return Tema.colorHex(Tema.colorAccent);
            case "error": return Tema.colorHex(Tema.colorPeligro);
            case "separador": return Tema.colorHex(Tema.colorTextoMuyTenue);
            case "sistema": return Tema.colorHex(Tema.colorTextoTenue);
            default: return Tema.colorHex(Tema.colorTextoTenue);
        }
    }
    function colorNombreHistCajon(jugador) {
        return Tema.colorHex(jugador === cajon.nombreJugador ? Tema.colorAccent : Tema.colorNombreAjeno);
    }
    function escapeHtmlCajon(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }
}
