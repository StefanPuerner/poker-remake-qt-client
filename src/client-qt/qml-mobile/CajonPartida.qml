// CajonPartida.qml — sustituye a la barra de acciones inferior + el
// IconoAjustes flotante durante la pantalla de Partida: un panel fijo a la
// derecha de la mesa (unos 2/7 del ancho, ver Main.qml) con pestañas propias
// en vez de una franja de botones siempre visible. Decisión del usuario tras
// ver el primer boceto de "bandas horizontales" (que sacrificaba la mesa
// clásica) — aquí se mantiene la mesa/asientos tal cual, solo se le da un
// contenedor más alto que ancho, lo que ya evita el solape de raíz sin
// tocar Mesa.qml.
//
// Pestañas: Turno (qué está pasando ahora; los botones de apuesta cuando te
// toca y las decisiones de fin de mano) / Estim. (predicción actual/probable/
// máxima) / Historial / Chat. La pestaña "Cartas" se quitó (2026-09-20): tus
// cartas se ven, más grandes, en tu propio asiento de la mesa, y así el
// cajón puede ser más estrecho y la mesa más ancha. Historial y chat
// comparten el estilo de PanelLateral.qml de escritorio.
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
    signal abrirChuleta()
    // No se asigna a las propiedades "tuTurno"/"recompraSolicitada"
    // directamente desde dentro (romperían el binding de una vía que las
    // liga a ventana.tuTurno/ventana.recompraSolicitada en Main.qml — una
    // asignación local sustituye el binding para siempre). En su lugar,
    // estas señales dejan que Main.qml actualice la fuente de verdad.
    signal decisionEnviada()
    signal recompraPedida()
    // Decisiones de fin de mano (seguir / abandonar / guardar y "Mostrar cartas"): van en la pestaña
    // Turno, en el hueco de los botones de apuesta (nunca a la vez que ellos).
    property bool votoAbierto: false
    property int votoRestanteSegundos: 60
    property bool enRed: false
    property bool soyHost: false
    property bool contariaComoPerdida: false
    property bool puedeMostrarCartas: false
    signal mostrarCartasPedido()
    signal votoCerrado()

    // Código estable (no el texto mostrado, que se traduce vía
    // nombrePestana()) -- ver el comentario largo junto a
    // tiraPestanas.codigosPestanas más abajo.
    property string pestanaActiva: "turno"
    // Lo que hay que decidir salta a la vista: al empezar tu turno y al abrirse el voto de fin de mano.
    onTuTurnoChanged: if (tuTurno) pestanaActiva = "turno"
    onVotoAbiertoChanged: if (votoAbierto) pestanaActiva = "turno"

    // Llamado desde Main.qml (onEsMiTurno) al empezar un turno nuevo:
    // resetea el estado LOCAL de los controles de "Opciones" que
    // Main.qml no puede tocar directamente (son ids internos de este
    // componente) — mismo efecto que antes tenía la barra de acciones
    // cuando vivía a nivel de Main.qml.
    function prepararNuevoTurno(valorInicialSubida) {
        botonAllInCajon.confirmando = false;
        selectorSubidaCajon.valor = valorInicialSubida;
    }

    // Traduce un código estable de tiraPestanas.codigosPestanas al texto
    // que se pinta -- ver el comentario largo junto a esa property.
    function nombrePestana(codigo) {
        switch (codigo) {
            case "turno": return Idioma.t("tab_turno");
            case "estimacion": return Idioma.t("tab_estimacion");
            case "historial": return Idioma.t("tab_historial");
            case "chat": return Idioma.t("tab_chat");
        }
        return codigo;
    }

    radius: 10 * Tema.escala
    color: "transparent"
    border.width: tuTurno ? 2 : 1
    border.color: tuTurno ? Tema.colorAccent : Tema.colorBorde
    // Mensajes de chat llegados con otra pestaña abierta (punto de aviso en "Chat").
    property int chatSinLeer: 0
    property int _ultimoConteoChat: 0
    onPestanaActivaChanged: if (pestanaActiva === "chat") chatSinLeer = 0
    Connections {
        target: cajon.modeloChat
        function onCountChanged() {
            var n = cajon.modeloChat.count;
            if (n > cajon._ultimoConteoChat && cajon.pestanaActiva !== "chat") cajon.chatSinLeer += n - cajon._ultimoConteoChat;
            cajon._ultimoConteoChat = n;
        }
    }
    // Fondo "ficha de casino" como el resto de la app: degradado con dithering y un hilo dorado por
    // dentro del borde (mismo aspecto que PanelLateral.qml de escritorio).
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.45) }
            GradientStop { position: 0.16; color: Qt.lighter(Tema.colorPanel, 1.3) }
            GradientStop { position: 1.0; color: Tema.colorPanel }
        }
        // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
        layer.enabled: true
        layer.effect: ShaderEffect {
            property variant source
            property real amplitud: 30.0
            fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2 * Tema.escala
            radius: parent.radius - 2 * Tema.escala
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.16)
        }
    }

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
                    color: Tema.colorTexto
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
                id: iconoAjustesCajon
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 8 * Tema.escala
                onAbrirAjustes: cajon.abrirAjustes()
            }
            IconoChuleta {
                anchors.right: iconoAjustesCajon.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 8 * Tema.escala
                onAbrirChuleta: cajon.abrirChuleta()
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
            //
            // Códigos estables, NO el texto mostrado -- antes el propio
            // nombre en español era el identificador de estado
            // (cajon.pestanaActiva), así que traducirlo habría roto todas
            // las comparaciones ("=== 'Turno'", etc.) y las hubiera dejado
            // dependiendo del idioma activo. nombrePestana() hace la
            // traducción solo en el texto que se pinta.
            readonly property var codigosPestanas: ["turno", "estimacion", "historial", "chat"]

            Repeater {
                model: tiraPestanas.codigosPestanas
                delegate: Item {
                    id: pestana
                    required property string modelData
                    required property int index
                    readonly property bool activa: cajon.pestanaActiva === modelData
                    width: tiraPestanas.width / tiraPestanas.codigosPestanas.length
                    height: tiraPestanas.height

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 2.5
                        color: pestana.activa ? Tema.colorAccent : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: cajon.nombrePestana(pestana.modelData)
                        color: pestana.activa ? Tema.colorAccent : Tema.colorTextoMuyTenue
                        font.pixelSize: 10 * Tema.escala
                        font.bold: pestana.activa
                    }
                    // Chat con mensajes sin leer.
                    Rectangle {
                        visible: pestana.modelData === "chat" && cajon.chatSinLeer > 0 && !pestana.activa
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 4 * Tema.escala
                        width: 6 * Tema.escala
                        height: 6 * Tema.escala
                        radius: width / 2
                        color: Tema.colorAccent
                    }
                    // Aviso de decisión pendiente: solo si es tu turno Y no
                    // estás ya mirando la pestaña que la resuelve.
                    Rectangle {
                        visible: cajon.tuTurno && pestana.modelData === "turno" && !pestana.activa
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

            // — Estimación —
            Column {
                visible: cajon.pestanaActiva === "estimacion"
                anchors.centerIn: parent
                width: parent.width - 30 * Tema.escala
                spacing: 12 * Tema.escala
                Repeater {
                    model: [
                        { etq: Idioma.t("etiqueta_combo_actual"), val: cajon.comboActual, color: Tema.colorTexto },
                        { etq: Idioma.t("etiqueta_combo_probable"), val: cajon.comboProbable, color: Tema.colorTextoTenue },
                        { etq: Idioma.t("etiqueta_combo_maxima"), val: cajon.comboMaxima, color: Tema.colorAccent }
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
                visible: cajon.pestanaActiva === "turno"
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
                    visible: !cajon.tuTurno && !cajon.puedoRecomprar && !cajon.votoAbierto
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
                        text: cajon.turnoNombre !== "" ? Idioma.tf("etiqueta_turno_de", [cajon.turnoNombre]) : "—"
                        color: Tema.colorTexto
                        font.bold: true
                        font.family: Tema.fuenteElegante
                        font.pixelSize: 14 * Tema.escala
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Idioma.tf("etiqueta_ronda_mano", [cajon.rondaActual, cajon.manoActual, cajon.objetivoManos])
                        color: Tema.colorTextoTenue
                        font.pixelSize: 11 * Tema.escala
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4 * Tema.escala
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Idioma.tf("etiqueta_bote_total", [cajon.bote])
                            color: Tema.colorAccent
                            font.bold: true
                            font.family: Tema.fuenteElegante
                            font.pixelSize: 13 * Tema.escala
                        }
                        IconoFicha {
                            width: 11 * Tema.escala
                            height: width
                            anchors.verticalCenter: parent.verticalCenter
                            colorFicha: Tema.colorAccent
                        }
                    }
                }

                // ── Fin de la mano: tarjeta con el título (y la cuenta atrás del plazo, en red: el
                // servidor sigue solo al vencer) y debajo las decisiones. Solo si no te toca jugar.
                Column {
                    visible: cajon.votoAbierto && !cajon.tuTurno
                    width: parent.width
                    spacing: 10 * Tema.escala
                    Item {
                        width: parent.width
                        height: (cajon.enRed ? 54 : 40) * Tema.escala
                        Rectangle {   // sombra corta
                            anchors.fill: parent
                            anchors.topMargin: 3 * Tema.escala
                            anchors.leftMargin: 2 * Tema.escala
                            radius: 10 * Tema.escala
                            color: "black"
                            opacity: 0.35
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 10 * Tema.escala
                            border.width: 1.2
                            border.color: Qt.rgba(0, 0, 0, 0.4)
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.65) }
                                GradientStop { position: 0.18; color: Qt.lighter(Tema.colorPanel, 1.4) }
                                GradientStop { position: 1.0; color: Tema.colorPanel }
                            }
                            // Hilo dorado interior: el "doble bisel" de ficha de casino.
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2 * Tema.escala
                                radius: parent.radius - 2 * Tema.escala
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.30)
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: 2 * Tema.escala
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Idioma.t("titulo_fin_mano")
                                    color: Tema.colorAccent
                                    font.family: Tema.fuenteElegante
                                    font.pixelSize: 16 * Tema.escala
                                    font.bold: true
                                    font.letterSpacing: 2
                                }
                                Text {
                                    visible: cajon.enRed
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Idioma.tf("voto_continua_solo", [cajon.votoRestanteSegundos])
                                    color: Tema.colorTextoTenue
                                    font.family: Tema.fuenteElegante
                                    font.pixelSize: 10 * Tema.escala
                                }
                            }
                        }
                    }
                    BotonContorno {
                        width: parent.width
                        visible: cajon.puedeMostrarCartas
                        text: Idioma.t("boton_mostrar_cartas")
                        onClicked: cajon.mostrarCartasPedido()
                    }
                    PanelVoto {
                        width: parent.width
                        soyHost: cajon.soyHost
                        contariaComoPerdida: cajon.contariaComoPerdida
                        onAbandonar: cajon.votoCerrado()
                        onGuardarYSalir: cajon.votoCerrado()
                    }
                }

                Column {
                    visible: cajon.tuTurno
                    width: parent.width
                    spacing: 8 * Tema.escala
                    BotonContorno {
                        width: parent.width
                        text: Idioma.t("boton_retirarse")
                        colorBorde: Tema.colorPeligro
                        onClicked: {
                            redcliente.enviarAccion("FOLD", 0);
                            cajon.decisionEnviada();
                        }
                    }
                    BotonContorno {
                        width: parent.width
                        text: cajon.aPagarParaIgualar > 0 ? Idioma.tf("boton_igualar_movil", [cajon.aPagarParaIgualar]) : Idioma.t("boton_pasar")
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
                        text: Idioma.t("boton_subir")
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
                        text: confirmando ? Idioma.t("boton_confirmar_borrado") : Idioma.t("texto_all")
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
                        text: Idioma.t("texto_sin_fichas_corto")
                        color: Tema.colorTextoTenue
                        font.pixelSize: 12 * Tema.escala
                        horizontalAlignment: Text.AlignHCenter
                    }
                    BotonRelleno {
                        width: parent.width
                        text: cajon.recompraSolicitada ? Idioma.t("texto_enviada_corta") : Idioma.t("boton_recomprar")
                        enabled: !cajon.recompraSolicitada
                        onClicked: {
                            redcliente.pedirRecompra();
                            cajon.recompraPedida();
                        }
                    }
                }
            }
            }

            // — Historial — una fila por evento con una marca de color a la izquierda según su tipo;
            // las cabeceras de mano ("── Mano 13 ──") van como separadores centrados. Mismo estilo
            // que PanelLateral.qml de escritorio.
            ListView {
                id: listaHistorialCajon
                visible: cajon.pestanaActiva === "historial"
                anchors.fill: parent
                anchors.margins: 10 * Tema.escala
                clip: true
                spacing: 2 * Tema.escala
                model: cajon.modeloHistorial
                onCountChanged: Qt.callLater(positionViewAtEnd)
                // Indicador fino (táctil: se desliza con el dedo, no hace falta una barra que agarrar).
                ScrollIndicator.vertical: ScrollIndicator {
                    contentItem: Rectangle {
                        implicitWidth: 3 * Tema.escala
                        radius: width / 2
                        color: Tema.colorAccent
                        opacity: 0.45
                    }
                }
                delegate: Item {
                    id: filaHistorialCajon
                    required property string linea
                    required property string tipo
                    required property string jugador
                    readonly property bool esSeparador: tipo === "separador"
                    readonly property bool esMio: jugador === cajon.nombreJugador && jugador.length > 0
                    width: ListView.view.width - 6 * Tema.escala
                    height: esSeparador ? 24 * Tema.escala : Math.max(textoLineaHist.implicitHeight + 8 * Tema.escala, 20 * Tema.escala)

                    // Separador de mano: línea — texto — línea.
                    Row {
                        visible: filaHistorialCajon.esSeparador
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        spacing: 6 * Tema.escala
                        Rectangle {
                            width: Math.max(0, (parent.width - textoSeparadorCajon.implicitWidth - 2 * parent.spacing) / 2)
                            height: 1
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.35)
                        }
                        Text {
                            id: textoSeparadorCajon
                            text: filaHistorialCajon.linea.replace(/[─—-]/g, "").trim()
                            color: Tema.colorAccent
                            font.pixelSize: 10 * Tema.escala
                            font.bold: true
                            font.letterSpacing: 1
                            font.family: Tema.fuenteElegante
                        }
                        Rectangle {
                            width: Math.max(0, (parent.width - textoSeparadorCajon.implicitWidth - 2 * parent.spacing) / 2)
                            height: 1
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.35)
                        }
                    }

                    // Fila normal.
                    Rectangle {
                        visible: !filaHistorialCajon.esSeparador
                        anchors.fill: parent
                        radius: 6 * Tema.escala
                        color: filaHistorialCajon.esMio ? Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.09)
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
                            color: cajon.colorTipoHistCajon(filaHistorialCajon.tipo)
                        }
                        Text {
                            id: textoLineaHist
                            anchors.left: parent.left
                            anchors.leftMargin: 11 * Tema.escala
                            anchors.right: parent.right
                            anchors.rightMargin: 6 * Tema.escala
                            anchors.verticalCenter: parent.verticalCenter
                            // El nombre del protagonista lleva su color aparte (dorado si eres tú).
                            textFormat: Text.RichText
                            font.pixelSize: 11 * Tema.escala
                            color: Tema.colorTexto
                            wrapMode: Text.WordWrap
                            text: (filaHistorialCajon.jugador.length > 0
                                       ? "<font color=\"" + cajon.colorNombreHistCajon(filaHistorialCajon.jugador)
                                             + "\"><b>" + cajon.escapeHtmlCajon(filaHistorialCajon.jugador) + "</b></font>"
                                       : "") + cajon.escapeHtmlCajon(filaHistorialCajon.linea)
                        }
                    }
                }
            }

            // — Chat —
            Item {
                visible: cajon.pestanaActiva === "chat"
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
                    ScrollIndicator.vertical: ScrollIndicator {
                        contentItem: Rectangle {
                            implicitWidth: 3 * Tema.escala
                            radius: width / 2
                            color: Tema.colorAccent
                            opacity: 0.45
                        }
                    }
                    delegate: Item {
                        required property string autor
                        required property string mensaje
                        required property string hora
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
                            width: Math.min(medidorCajon.implicitWidth + 22 * Tema.escala, parent.width * 0.86)
                            spacing: 2 * Tema.escala
                            Text {
                                anchors.right: esPropio ? parent.right : undefined
                                text: (esPropio ? Idioma.t("yo_chat") : autor) + " · " + hora
                                color: esPropio ? Tema.colorAccent : Tema.colorTextoMuyTenue
                                font.pixelSize: 9 * Tema.escala
                            }
                            // Las propias con filo dorado y tinte dorado; las ajenas con el tono del tapete.
                            Rectangle {
                                width: parent.width
                                height: textoBurbujaCajon.implicitHeight + 14 * Tema.escala
                                radius: 10 * Tema.escala
                                border.width: 1
                                border.color: esPropio ? Tema.colorAccent : Qt.rgba(1, 1, 1, 0.08)
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: esPropio ? Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.26)
                                                                                   : Qt.lighter(Tema.colorTapete, 1.25) }
                                    GradientStop { position: 1.0; color: esPropio ? Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.12)
                                                                                   : Tema.colorTapete }
                                }
                                Text {
                                    id: textoBurbujaCajon
                                    anchors.fill: parent
                                    anchors.margins: 7 * Tema.escala
                                    text: mensaje
                                    color: Tema.colorTexto
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
                        height: Tema.tactil
                        color: Tema.colorTexto
                        font.pixelSize: 11 * Tema.escala
                        // Ver CampoEmergente.qml: sin esto, borrar una
                        // letra solo retrocedía el cursor sin borrarla.
                        inputMethodHints: Qt.ImhNoPredictiveText
                        placeholderText: Idioma.t("placeholder_mensaje_chat")
                        placeholderTextColor: Tema.colorTextoTenue
                        background: MarcoHueco {
                            radius: 6 * Tema.escala
                            activo: textoChatCajon.activeFocus
                        }
                        onAccepted: botonEnviarCajon.clicked()
                    }
                    BotonRelleno {
                        id: botonEnviarCajon
                        height: Tema.tactil
                        text: Idioma.t("boton_enviar")
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
