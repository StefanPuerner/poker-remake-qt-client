pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile
import QtQuick.Controls
import QtQuick.Controls.Material

ApplicationWindow {
    id: ventana
    visible: true
    width: 800
    height: 480
    title: "PokerRemake (móvil)"
    color: Tema.colorFondo
    Material.theme: Material.Dark
    Material.accent: Tema.colorAccent

    // Igual que en escritorio (ver Binding en el Main.qml de ahí), pero
    // atado al tamaño real de la ventana en vez de a un factor de zoom
    // manual — en un móvil la "ventana" YA es la pantalla completa (o el
    // recuadro que Hyprland le asigne en escritorio, da igual: se adapta
    // igual de bien a ambos casos porque solo mira su propio tamaño).
    Binding {
        target: Tema
        property: "escala"
        value: Math.min(ventana.width / Tema.anchoBase, ventana.height / Tema.altoBase)
    }

    // Igual que escritorio: FontLoader + Binding para que Tema.fuenteElegante
    // se resuelva de verdad (antes se leía en todo el fichero pero nunca lo
    // rellenaba nadie -- se quedaba en "", que Qt interpreta como "usa la
    // fuente del sistema", así que la app entera usaba una fuente distinta
    // a la pensada sin ningún aviso).
    FontLoader {
        id: cargadorFuenteEleganteMovil
        source: "qrc:/qt/qml/PokerQuickMobile/assets/fonts/EBGaramond.ttf"
    }
    Binding { target: Tema; property: "fuenteElegante"; value: cargadorFuenteEleganteMovil.name }

    // ── Navegación + gesto de atrás (Parte 7 del plan, punto 3) ─────────────
    // Mismo modelo de pantalla plana que escritorio. "mapaAtras" es el
    // mismo destino que ya usan los botones "Cancelar"/"Salir" de
    // escritorio (Salas→Inicio, CrearSala→Salas, Fin→Salas) — Lobby/Partida
    // quedan fuera a propósito: abandonar una partida en curso pasa por el
    // overlay de voto, no por un back que se salte esa confirmación.
    property string pantalla: "Inicio"
    readonly property var mapaAtras: ({
        "Salas": "Inicio",
        "CrearSala": "Salas",
        "Fin": "Salas"
    })
    property bool ajustesAbiertos: false

    // Prioridad compartida por el gesto de atrás real (Android, vía
    // onClosing más abajo) Y por Esc en escritorio (conveniencia de
    // prueba: Android no tiene tecla Esc, así que esto nunca se dispara
    // ahí — no hace falta gatearlo por plataforma). Devuelve true si
    // "consumió" el back (cerró/navegó algo).
    function consumirAtras() {
        if (EstadoOverlays.popupActivo !== null) { EstadoOverlays.popupActivo.close(); return true; }
        if (ajustesAbiertos) { ajustesAbiertos = false; return true; }
        if (mapaAtras[pantalla] !== undefined) { pantalla = mapaAtras[pantalla]; return true; }
        return false; // Inicio, nada abierto: no hay nada que consumir
    }

    // El botón/gesto de atrás de Android llega aquí como un cierre de
    // ventana normal (mismo evento que Alt+F4/la X en escritorio) — por
    // defecto nunca lo deja pasar (el gesto de atrás no debe cerrar la
    // app). "saliendoExplicitamente" es la única vía de escape real: el
    // botón "Salir" la activa justo antes de llamar a Qt.quit(), que
    // dispara este MISMO evento — sin la bandera, ese cierre también
    // quedaría bloqueado como cualquier otro (bug real, ya visto: "Salir"
    // no hacía nada).
    property bool saliendoExplicitamente: false
    onClosing: (close) => {
        if (saliendoExplicitamente) { close.accepted = true; return; }
        consumirAtras();
        close.accepted = false;
    }

    // Solo para poder probar el gesto de atrás en escritorio sin un
    // dispositivo Android a mano — el back real de Android llega por
    // onClosing, arriba, no por aquí.
    Shortcut {
        sequence: "Esc"
        onActivated: ventana.consumirAtras()
    }

    // ── Ajustes ──────────────────────────────────────────────────────────
    // En memoria por ahora, sin persistencia entre sesiones — mismo
    // criterio que escritorio (a la espera de un almacén de ajustes real).
    property bool sonidoActivado: true

    // ── Sesión / red ─────────────────────────────────────────────────────
    property string nombreJugador: ""
    property string servidorHost: SERVER_HOST_DEFAULT
    property int servidorPuerto: SERVER_PORT_DEFAULT
    // Compartido entre Inicio y Salas — las dos pueden iniciar una conexión
    // (refrescarSalas/unirseASala/cargarPartidaGuardada) y un fallo puede
    // llegar estando en cualquiera de las dos.
    property string mensajeErrorConexion: ""
    // Reconexión automática (60s, mismo mecanismo que ncurses/escritorio)
    // — más importante aún en móvil, donde cambiar de wifi o mandar la
    // app a segundo plano corta la conexión con mucha más frecuencia
    // que en un PC.
    property bool reconectandoAhora: false
    property int segundosReconexion: 0
    property bool viendoGuardadas: false
    // Deslizar-hacia-abajo-para-refrescar (pull-to-refresh) en las listas
    // de Salas/Guardadas -- puestas a true al soltar por debajo del
    // umbral, a false en cuanto llega la respuesta del servidor.
    property bool refrescandoSalas: false
    property bool refrescandoGuardadas: false
    // Qué archivo está renombrando el popup compartido campoRenombrarMovil
    // (una sola instancia para toda la lista, igual que campoNombre).
    property string archivoARenombrar: ""
    ListModel { id: salasDisponibles }
    ListModel { id: guardadasDisponibles }

    // ── Lobby ────────────────────────────────────────────────────────────
    property string codigoSalaPropia: ""
    property string nombresEsperadosLobby: ""
    property string hostActual: ""
    property bool soyHost: hostActual !== "" && hostActual === nombreJugador
    property string textoListos: ""
    property bool chatActive: false
    // Chat de sala (Lobby + quien espera a sentarse a mitad de partida) y
    // chat de partida (pestaña "Chat" del cajón, solo jugadores ya
    // sentados) van cada uno a su propia lista -- antes compartían una
    // sola (mensajesChat) y se mezclaban sin más: lo que alguien escribía
    // en la sala de espera aparecía igual en el chat de la mano en curso y
    // viceversa. El servidor ya los separa por el campo "canal" del CHAT
    // (ver NetworkObserver::relayPendingChat()/broadcastASala()).
    property string mensajeEnEspera: ""
    property var listaEsperando: []
    ListModel { id: jugadoresConectados }
    ListModel { id: mensajesChatSala }
    ListModel { id: mensajesChatPartida }

    // ── Partida ──────────────────────────────────────────────────────────
    ListModel { id: historialMovil }
    property int objetivoManos: 0
    property int tipoLimiteActual: 0
    property bool permitirRecompraActual: false
    property bool rellenarConBotsActual: false
    property bool preguntarExtensionActual: true
    property string rondaActual: ""
    property int boteActual: 0
    property string turnoNombre: ""
    property int manoActual: 0
    property int ciegaActual: 0
    property var cartasMesa: []
    property string miCarta1: ""
    property string miCarta2: ""
    property var retirados: []
    property bool tuTurno: false
    property int igualarActual: 0
    property int miApuestaActual: 0
    property int miSaldoActual: 0
    property int aPagarParaIgualar: Math.max(0, igualarActual - miApuestaActual)
    property int minSubidaActual: 0
    property int maxSubidaActual: 0
    property string comboActual: ""
    property string comboProbable: ""
    property string comboMaxima: ""
    property bool puedoRecomprar: false
    property bool recompraSolicitada: false
    property int timeoutMsActual: 30000
    ListModel { id: jugadoresPartida }

    // ── Showdown / voto de fin de mano / fin de partida ────────────────────
    property bool showdownAbierto: false
    property var revealsShowdown: []
    property var resumenBotes: []
    property bool votoAbierto: false
    property string mensajeVoto: ""
    property bool votoExtensionAbierto: false
    property string votoExtensionMensaje: ""
    property string ganadorFinal: ""
    property int saldoFinal: 0
    property bool finPorLimite: false
    property int manosDisputadasFinal: 0
    property string mejorManoFinal: ""
    property string mejorManoJugadorFinal: ""
    property var eliminacionesFinal: []
    property bool partidaGuardada: false

    // Mismo patrón que escritorio: el servidor manda timeout_ms en cada
    // turno de CUALQUIER jugador (onTurnoIniciado) — el Timer corre
    // mientras haya un turno activo, y Mesa aplica la fracción al asiento
    // que corresponda.
    property real inicioTurnoMs: 0
    property real fraccionTiempoRestante: 1.0
    Timer {
        interval: 100
        running: ventana.turnoNombre !== ""
        repeat: true
        onTriggered: {
            var transcurrido = Date.now() - ventana.inicioTurnoMs;
            ventana.fraccionTiempoRestante = Math.max(0, 1 - transcurrido / ventana.timeoutMsActual);
        }
    }

    // Antes de unirse/reanudar hace falta un nombre — si todavía no se ha
    // escrito, se abre el popup en vez de mandar una petición con nombre
    // vacío que el servidor tendría que autogenerar.
    function unirse(salaId, codigo) {
        if (nombreJugador === "") { campoNombre.abrir(""); return; }
        redcliente.unirseASala(servidorHost, servidorPuerto, nombreJugador, salaId, codigo);
    }
    function reanudar(archivo) {
        if (nombreJugador === "") { campoNombre.abrir(""); return; }
        redcliente.cargarPartidaGuardada(servidorHost, servidorPuerto, nombreJugador, archivo, "", false);
    }

    // El servidor va poniendo boteActual a 0 progresivamente A MEDIDA que
    // paga cada bote del showdown (Partida.cpp::showdown(), para que el
    // saldo/bote se vea fresco en otros clientes mientras se resuelven
    // varios side pots) -- si la pantalla de showdown usa boteActual
    // directamente, muestra "Bote: 0" casi todo el rato que estás viendo
    // las cartas reveladas, en vez del bote real que hubo en juego. Se
    // reconstruye sumando lo que YA se capturó en su momento (antes de que
    // lo pisaran): resumenBotes (viene de onBoteEvaluado, antes del pago) o,
    // si no hubo evaluación real (bote sin showdown, un solo jugador vivo),
    // el premio ya guardado en revealsShowdown.
    function boteTotalShowdown() {
        if (resumenBotes.length > 0)
            return resumenBotes.reduce(function(acc, b) { return acc + b.cantidad; }, 0);
        if (revealsShowdown.length > 0)
            return revealsShowdown.reduce(function(acc, r) { return acc + r.premio; }, 0);
        return boteActual;
    }

    Connections {
        target: redcliente
        function onConectado() {
            pantalla = "Lobby";
            chatActive = true;
            // Sin esto, el chat y el historial de una sesión anterior (con
            // otro nombre, en otra sala) se quedaban visibles para
            // siempre en la app -- nunca se vaciaban al empezar una
            // conexión nueva. No es una fuga del servidor entre salas: el
            // cliente simplemente nunca limpiaba su propia lista local.
            mensajesChatSala.clear();
            mensajesChatPartida.clear();
            historialMovil.clear();
            mensajeEnEspera = "";
            listaEsperando = [];
        }
        function onSalaCreada(salaId, codigo) {
            codigoSalaPropia = codigo;
        }
        function onLobbyActualizado(jugadoresCsv, listos, esperados, host, esperadosNombresCsv) {
            jugadoresConectados.clear();
            var nombres = jugadoresCsv.split(",");
            for (var i = 0; i < nombres.length; i++) {
                jugadoresConectados.append({ nombre: nombres[i] });
            }
            textoListos = listos + " / " + esperados + " listos";
            hostActual = host;
            nombresEsperadosLobby = esperadosNombresCsv;
        }
        function onChatRecibido(de, texto, canal) {
            var destino = canal === "partida" ? mensajesChatPartida : mensajesChatSala;
            destino.append({
                autor: de,
                mensaje: texto,
                hora: Qt.formatTime(new Date(), "hh:mm")
            });
        }
        function onEnEspera(mensaje) {
            mensajeEnEspera = mensaje;
        }
        function onSalaEsperandoActualizada(nombres) {
            listaEsperando = nombres;
        }
        function onPartidaIniciada(manos, tipoLimite, permitirRecompra, rellenarConBots, preguntarExtension) {
            pantalla = "Partida";
            chatActive = false;
            mensajeEnEspera = "";
            objetivoManos = manos;
            tipoLimiteActual = tipoLimite;
            permitirRecompraActual = permitirRecompra;
            rellenarConBotsActual = rellenarConBots;
            preguntarExtensionActual = preguntarExtension;
        }
        function onEstadoMesaActualizado(ronda, bote, turno, jugadoresStr, timeoutMs) {
            rondaActual = ronda;
            boteActual = bote;
            turnoNombre = turno;
            if (turno !== nombreJugador) tuTurno = false;
            if (timeoutMs > 0) {
                timeoutMsActual = timeoutMs;
                inicioTurnoMs = Date.now();
                fraccionTiempoRestante = 1.0;
            }
            jugadoresPartida.clear();
            var jugadores = jugadoresStr.split(";");
            for (var i = 0; i < jugadores.length; i++) {
                var campos = jugadores[i].split(":");
                jugadoresPartida.append({
                    nombre: campos[0],
                    saldo: campos[1],
                    apuesta: campos[2]
                });
                // No hay un evento dedicado de "recompra confirmada" — se
                // detecta viendo que el propio saldo ya no es 0.
                if (campos[0] === nombreJugador && parseInt(campos[1]) > 0) {
                    puedoRecomprar = false;
                    recompraSolicitada = false;
                }
            }
        }
        function onEventoJuego(evento, tipo, jugador) {
            historialMovil.append({
                linea: evento,
                tipo: tipo,
                jugador: jugador,
                hora: Qt.formatTime(new Date(), "hh:mm")
            });
        }
        function onNuevaMano(mano, ciega) {
            manoActual = mano;
            ciegaActual = ciega;
            retirados = [];
            cartasMesa = [];
            miCarta1 = "";
            miCarta2 = "";
            // Red de seguridad: si por lo que sea no llegó ESPERAR_VOTO (p.
            // ej. nadie tenía que votar), que el showdown no se quede
            // abierto para siempre tapando la mesa de la mano nueva.
            showdownAbierto = false;
        }
        function onMesaActualizada(cartasCsv) {
            cartasMesa = cartasCsv.length > 0 ? cartasCsv.split(",") : [];
        }
        function onMisCartasRepartidas(c1, c2) {
            miCarta1 = c1;
            miCarta2 = c2;
        }
        function onAccionRealizada(jugador, accion) {
            if (accion === "FOLD") {
                retirados = retirados.concat([jugador]);
            }
        }
        function onEsMiTurno(bote, igualar, miSaldo, miApuesta, timeoutMs, minSubida, maxSubida, c1, c2, comboA, comboP, comboM) {
            miCarta1 = c1;
            miCarta2 = c2;
            tuTurno = true;
            igualarActual = igualar;
            miApuestaActual = miApuesta;
            miSaldoActual = miSaldo;
            minSubidaActual = minSubida;
            maxSubidaActual = maxSubida;
            timeoutMsActual = timeoutMs;
            inicioTurnoMs = Date.now();
            fraccionTiempoRestante = 1.0;
            comboActual = comboA;
            comboProbable = comboP;
            comboMaxima = comboM;
            cajonPartidaMovil.prepararNuevoTurno(minSubida);
            for (var j = 0; j < jugadoresPartida.count; j++) {
                if (jugadoresPartida.get(j).nombre === nombreJugador) {
                    jugadoresPartida.setProperty(j, "saldo", miSaldo);
                    break;
                }
            }
        }
        function onComboActualizado(comboA, comboP, comboM) {
            comboActual = comboA;
            comboProbable = comboP;
            comboMaxima = comboM;
        }
        function onSaldosActualizados(jugadoresStr) {
            var jugadores = jugadoresStr.split(";");
            for (var i = 0; i < jugadores.length; i++) {
                var campos = jugadores[i].split(":");
                for (var j = 0; j < jugadoresPartida.count; j++) {
                    if (jugadoresPartida.get(j).nombre === campos[0]) {
                        jugadoresPartida.setProperty(j, "saldo", campos[1]);
                        break;
                    }
                }
            }
        }
        function onShowdownIniciado(cartasCsv) {
            cartasMesa = cartasCsv.length > 0 ? cartasCsv.split(",") : [];
            revealsShowdown = [];
            resumenBotes = [];
            showdownAbierto = true;
        }
        function onCartasMostradas(jugador, cartasCsv, combo) {
            // Un jugador elegible para varios botes (principal + side
            // pots) recibe un MUESTRA_CARTAS por CADA bote en el que
            // compite (Partida::showdown(), un bucle por bote) -- sin
            // este filtro, se le creaba una tarjeta nueva cada vez (vista
            // en real: "Stefan" duplicado, una con el total correcto y
            // otra suelta solo con el premio del side pot). El dinero
            // real del jugador no se veía afectado (eso lo gestiona el
            // servidor aparte), pero la tarjeta fantasma sí. La entrada ya
            // existente sigue sumando cada premio con normalidad
            // (onBoteGanado más abajo).
            if (revealsShowdown.some(function(r) { return r.nombre === jugador; })) return;
            revealsShowdown = revealsShowdown.concat([{
                nombre: jugador,
                cartas: cartasCsv.split(","),
                combo: combo,
                esGanador: false,
                premio: 0
            }]);
        }
        function onBoteEvaluado(numBote, cantidad, jugadoresCsv) {
            resumenBotes = resumenBotes.concat([{
                numBote: numBote,
                cantidad: cantidad,
                competidores: jugadoresCsv.length > 0 ? jugadoresCsv.split(",") : [],
                ganador: "",
                premioGanador: 0
            }]);
        }
        function onBoteGanado(jugador, premio, numBote, combo) {
            revealsShowdown = revealsShowdown.map(function(r) {
                if (r.nombre !== jugador) return r;
                return { nombre: r.nombre, cartas: r.cartas, combo: r.combo, esGanador: true, premio: r.premio + premio };
            });
            resumenBotes = resumenBotes.map(function(b) {
                if (b.numBote !== numBote) return b;
                return { numBote: b.numBote, cantidad: b.cantidad, competidores: b.competidores, ganador: jugador, premioGanador: premio };
            });
        }
        function onGanadorSinShowdown(jugador, bote) {
            cartasMesa = [];
            revealsShowdown = [{
                nombre: jugador, cartas: [], combo: "Se llevó el bote sin mostrar cartas",
                esGanador: true, premio: bote
            }];
            showdownAbierto = true;
        }
        function onEsperandoVoto(mensaje) {
            mensajeVoto = mensaje;
            votoAbierto = true;
            tuTurno = false;
            turnoNombre = "";
        }
        function onEsperandoVotoExtension(mensaje, manos) {
            votoExtensionMensaje = mensaje;
            votoExtensionAbierto = true;
            tuTurno = false;
            turnoNombre = "";
        }
        function onFinDePartida(ganador, saldo, porLimite, manosDisputadas, mejorMano, mejorManoJugador, eliminacionesCsv) {
            ganadorFinal = ganador;
            saldoFinal = saldo;
            finPorLimite = porLimite;
            manosDisputadasFinal = manosDisputadas;
            mejorManoFinal = mejorMano;
            mejorManoJugadorFinal = mejorManoJugador;
            eliminacionesFinal = eliminacionesCsv.length > 0
                ? eliminacionesCsv.split(";").map(function(par) {
                      var campos = par.split(":");
                      return { nombre: campos[0], mano: campos[1] };
                  })
                : [];
            partidaGuardada = false;
            tuTurno = false;
            turnoNombre = "";
            showdownAbierto = false;
            votoAbierto = false;
            votoExtensionAbierto = false;
            pantalla = "Fin";
        }
        function onPartidaGuardada(archivo) {
            // BUG corregido (visto en vivo: "Guardar y salir" desde dentro
            // del showdown dejaba la pantalla congelada): esto solo ponía
            // el booleano, pero nada disparaba ir a ningún sitio. La
            // pantalla Fin ya tenía preparado el texto "PARTIDA GUARDADA"
            // (ver partidaGuardada más abajo) — solo faltaba navegar ahí,
            // igual que ya hacen onFinDePartida/onAbandonaste.
            partidaGuardada = true;
            showdownAbierto = false;
            votoAbierto = false;
            votoExtensionAbierto = false;
            pantalla = "Fin";
        }
        function onAbandonaste(mensaje) {
            mensajeErrorConexion = mensaje;
            showdownAbierto = false;
            votoAbierto = false;
            pantalla = "Salas";
            redcliente.refrescarSalas(servidorHost, servidorPuerto);
        }
        function onError(mensaje) {
            mensajeErrorConexion = "Error: " + mensaje;
        }
        function onNombreRechazado(mensaje) {
            pantalla = "Inicio";
            mensajeErrorConexion = mensaje;
        }
        function onErrorSala(mensaje) {
            pantalla = "Salas";
            mensajeErrorConexion = mensaje;
        }
        function onNombreAsignado(nombre) {
            nombreJugador = nombre;
        }
        function onSalasActualizadas(salasCsv) {
            ventana.refrescandoSalas = false;
            salasDisponibles.clear();
            if (salasCsv.length === 0) return;
            var salas = salasCsv.split(";");
            for (var i = 0; i < salas.length; i++) {
                var campos = salas[i].split(":");
                salasDisponibles.append({
                    id: campos[0],
                    conectados: parseInt(campos[1]),
                    esperados: parseInt(campos[2]),
                    nombre: campos.slice(3).join(":")
                });
            }
        }
        function onGuardadasActualizadas(guardadasCsv) {
            ventana.refrescandoGuardadas = false;
            guardadasDisponibles.clear();
            if (guardadasCsv.length === 0) return;
            var guardadas = guardadasCsv.split(";");
            for (var i = 0; i < guardadas.length; i++) {
                var campos = guardadas[i].split(":");
                guardadasDisponibles.append({
                    archivo: campos[0],
                    humanos: parseInt(campos[1]),
                    bots: parseInt(campos[2]),
                    fecha: campos.slice(3).join(":")
                });
            }
        }
        function onGuardadaRenombrada(mensaje) {
            if (mensaje.length > 0) mensajeErrorConexion = mensaje;
            redcliente.listarGuardadas(servidorHost, servidorPuerto);
        }
        function onGuardadaBorrada(mensaje) {
            if (mensaje.length > 0) mensajeErrorConexion = mensaje;
            redcliente.listarGuardadas(servidorHost, servidorPuerto);
        }
        function onAvisoRecompra(puedeRecomprar) {
            puedoRecomprar = puedeRecomprar;
            recompraSolicitada = false;
        }
        function onReconectando(segundosRestantes) {
            reconectandoAhora = true;
            segundosReconexion = segundosRestantes;
        }
        function onReconectado() {
            reconectandoAhora = false;
        }
        function onReconexionFallida() {
            reconectandoAhora = false;
            pantalla = "Inicio";
            mensajeErrorConexion = "Se perdió la conexión con el servidor.";
        }
    }

    // ── Pantalla Inicio ──────────────────────────────────────────────────
    Column {
        visible: ventana.pantalla === "Inicio"
        anchors.centerIn: parent
        spacing: 20 * Tema.escala

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10 * Tema.escala
            Text {
                text: "♣"
                color: Tema.colorAccent
                font.pixelSize: 26 * Tema.escala
            }
            Text {
                text: "PokerRemake"
                color: "white"
                font.bold: true
                font.family: Tema.fuenteElegante
                font.pixelSize: 24 * Tema.escala
                y: 3 * Tema.escala
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "MESA PRIVADA · TEXAS HOLD'EM"
            color: Tema.colorTextoTenue
            font.pixelSize: 10 * Tema.escala
            font.letterSpacing: 2
        }

        // Campo "de mentira": solo abre CampoEmergente al tocarlo (punto 2
        // del plan de diseño móvil) — nunca activa el teclado del sistema
        // directamente desde la pantalla de Inicio.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 240 * Tema.escala
            height: Tema.tamanoMinTactil
            radius: 8 * Tema.escala
            color: Tema.colorPanel
            border.width: 1
            border.color: areaNombre.pressed ? Tema.colorAccent : Tema.colorBorde
            Text {
                anchors.centerIn: parent
                text: ventana.nombreJugador !== "" ? ventana.nombreJugador : "Toca para tu nombre"
                color: ventana.nombreJugador !== "" ? "white" : Tema.colorTextoMuyTenue
                font.pixelSize: 15 * Tema.escala
            }
            MouseArea {
                id: areaNombre
                anchors.fill: parent
                onClicked: campoNombre.abrir(ventana.nombreJugador)
            }
        }

        BotonRelleno {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Salas disponibles"
            radioBorde: 999
            onClicked: {
                ventana.mensajeErrorConexion = "";
                ventana.pantalla = "Salas";
                redcliente.refrescarSalas(ventana.servidorHost, ventana.servidorPuerto);
            }
        }
        BotonContorno {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Salir"
            colorBorde: Tema.colorPeligro
            radioBorde: 999
            onClicked: {
                ventana.saliendoExplicitamente = true;
                Qt.quit();
            }
        }
        Text {
            visible: ventana.mensajeErrorConexion !== "" && ventana.pantalla === "Inicio"
            anchors.horizontalCenter: parent.horizontalCenter
            width: 260 * Tema.escala
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Tema.colorPeligro
            font.pixelSize: 11 * Tema.escala
            text: ventana.mensajeErrorConexion
        }
    }

    // ── Pantalla Salas ───────────────────────────────────────────────────
    BarraSuperior {
        id: barraSalasMovil
        visible: ventana.pantalla === "Salas"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        textoCentro: "Salas disponibles"
        onAbrirAjustes: ventana.ajustesAbiertos = !ventana.ajustesAbiertos
    }

    Column {
        // Antes centrado verticalmente en toda la pantalla: en una
        // landscape corta el contenido quedaba casi pegado a la barra de
        // arriba (poco margen real entre los dos). Anclado ahora bajo la
        // propia barra, con un hueco fijo -- separación garantizada pase
        // lo que pase con el alto de pantalla.
        visible: ventana.pantalla === "Salas"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: barraSalasMovil.bottom
        anchors.topMargin: 22 * Tema.escala
        spacing: 12 * Tema.escala
        width: Math.min(560 * Tema.escala, ventana.width - 60 * Tema.escala)

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10 * Tema.escala
            SelectorPildoras {
                id: tabsSalas
                anchors.verticalCenter: parent.verticalCenter
                opciones: ["Salas públicas", "Partidas guardadas"]
                onSeleccionadoChanged: {
                    ventana.viendoGuardadas = seleccionado === 1;
                    if (ventana.viendoGuardadas)
                        redcliente.listarGuardadas(ventana.servidorHost, ventana.servidorPuerto);
                }
            }
            BotonContorno {
                anchors.verticalCenter: parent.verticalCenter
                text: "Crear sala nueva"
                onClicked: {
                    ventana.mensajeErrorConexion = "";
                    ventana.pantalla = "CrearSala";
                }
            }
        }

        Text {
            visible: ventana.mensajeErrorConexion !== "" && ventana.pantalla === "Salas"
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Tema.colorPeligro
            font.pixelSize: 11 * Tema.escala
            text: ventana.mensajeErrorConexion
        }

        Rectangle {
            width: parent.width
            height: 220 * Tema.escala
            radius: 8 * Tema.escala
            color: Tema.colorPanel
            border.width: 1
            border.color: Tema.colorBorde

            Text {
                anchors.centerIn: parent
                width: parent.width - 40 * Tema.escala
                visible: !ventana.viendoGuardadas && listaSalasMovil.count === 0
                text: "No hay salas públicas disponibles ahora mismo."
                color: Tema.colorTextoTenue
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: 13 * Tema.escala
            }
            Text {
                anchors.centerIn: parent
                width: parent.width - 40 * Tema.escala
                visible: ventana.viendoGuardadas && listaGuardadasMovil.count === 0
                text: "No hay partidas guardadas en el servidor."
                color: Tema.colorTextoTenue
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: 13 * Tema.escala
            }

            ListView {
                id: listaSalasMovil
                visible: !ventana.viendoGuardadas
                anchors.fill: parent
                anchors.margins: 10 * Tema.escala
                clip: true
                spacing: 8 * Tema.escala
                model: salasDisponibles
                header: CabeceraPullRefrescar {
                    vista: listaSalasMovil
                    refrescando: ventana.refrescandoSalas
                    onRefrescar: {
                        ventana.refrescandoSalas = true;
                        redcliente.refrescarSalas(ventana.servidorHost, ventana.servidorPuerto);
                    }
                }
                delegate: Rectangle {
                    id: filaSalaMovil
                    required property string id
                    required property string nombre
                    required property int conectados
                    required property int esperados
                    width: ListView.view.width
                    height: Tema.tamanoMinTactil + 12 * Tema.escala
                    radius: 6 * Tema.escala
                    color: Tema.colorFondo
                    border.width: 1
                    border.color: Tema.colorBorde

                    Column {
                        anchors.left: parent.left
                        anchors.right: botonUnirseMovil.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12 * Tema.escala
                        anchors.rightMargin: 10 * Tema.escala
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: filaSalaMovil.nombre !== "" ? filaSalaMovil.nombre : filaSalaMovil.id
                            color: "white"
                            font.pixelSize: 14 * Tema.escala
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: filaSalaMovil.conectados + " / " + filaSalaMovil.esperados + " jugadores"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 11 * Tema.escala
                        }
                    }
                    BotonRelleno {
                        id: botonUnirseMovil
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 10 * Tema.escala
                        text: "Unirse"
                        onClicked: ventana.unirse(filaSalaMovil.id, "")
                    }
                }
            }

            ListView {
                id: listaGuardadasMovil
                visible: ventana.viendoGuardadas
                anchors.fill: parent
                anchors.margins: 10 * Tema.escala
                clip: true
                spacing: 8 * Tema.escala
                model: guardadasDisponibles
                header: CabeceraPullRefrescar {
                    vista: listaGuardadasMovil
                    refrescando: ventana.refrescandoGuardadas
                    onRefrescar: {
                        ventana.refrescandoGuardadas = true;
                        redcliente.listarGuardadas(ventana.servidorHost, ventana.servidorPuerto);
                    }
                }
                delegate: Rectangle {
                    id: filaGuardadaMovil
                    required property string archivo
                    required property string fecha
                    required property int humanos
                    required property int bots
                    property bool confirmandoBorrado: false
                    width: ListView.view.width
                    height: Tema.tamanoMinTactil + 12 * Tema.escala
                    radius: 6 * Tema.escala
                    color: Tema.colorFondo
                    border.width: 1
                    border.color: Tema.colorBorde

                    Column {
                        anchors.left: parent.left
                        anchors.right: filaAccionesGuardadaMovil.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12 * Tema.escala
                        anchors.rightMargin: 10 * Tema.escala
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: filaGuardadaMovil.archivo
                            color: "white"
                            font.pixelSize: 13 * Tema.escala
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: filaGuardadaMovil.fecha + " · " + filaGuardadaMovil.humanos +
                                  " humano(s), " + filaGuardadaMovil.bots + " bot(s)"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 11 * Tema.escala
                        }
                    }
                    Row {
                        id: filaAccionesGuardadaMovil
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 10 * Tema.escala
                        spacing: 6 * Tema.escala
                        BotonRelleno {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Reanudar"
                            onClicked: ventana.reanudar(filaGuardadaMovil.archivo)
                        }
                        BotonContorno {
                            anchors.verticalCenter: parent.verticalCenter
                            // Texto en vez de "✎": ese glifo (y "🗑" abajo)
                            // no está ni en EBGaramond ni en el font de
                            // sistema de este build de Android -- se veía
                            // un cuadrado/tofu en vez del símbolo.
                            text: "Renombrar"
                            onClicked: {
                                ventana.archivoARenombrar = filaGuardadaMovil.archivo;
                                campoRenombrarMovil.abrir(filaGuardadaMovil.archivo.replace(/\.pok$/, ""));
                            }
                        }
                        BotonContorno {
                            anchors.verticalCenter: parent.verticalCenter
                            text: filaGuardadaMovil.confirmandoBorrado ? "¿Seguro?" : "Borrar"
                            colorBorde: Tema.colorPeligro
                            onClicked: {
                                if (filaGuardadaMovil.confirmandoBorrado) {
                                    redcliente.borrarGuardada(ventana.servidorHost, ventana.servidorPuerto,
                                                              filaGuardadaMovil.archivo);
                                } else {
                                    filaGuardadaMovil.confirmandoBorrado = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Pantalla CrearSala ───────────────────────────────────────────────
    BarraSuperior {
        visible: ventana.pantalla === "CrearSala"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        textoCentro: "Crear sala"
        onAbrirAjustes: ventana.ajustesAbiertos = !ventana.ajustesAbiertos
    }

    Column {
        id: columnaCrearSala
        visible: ventana.pantalla === "CrearSala"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 80 * Tema.escala
        anchors.bottomMargin: 14 * Tema.escala
        spacing: 10 * Tema.escala
        width: Math.min(560 * Tema.escala, ventana.width - 48 * Tema.escala)

        Rectangle {
            width: parent.width
            // Ocupa el hueco que sobra entre el título implícito de la
            // barra y la fila de botones de abajo — mismo cálculo que
            // escritorio, adaptado a que aquí no hay título propio (ya va
            // en la barra) ni mensaje de error dentro de esta cuenta.
            height: parent.height - filaBotonesCrearSalaMovil.height - parent.spacing
            radius: 8 * Tema.escala
            color: Tema.colorPanel
            border.width: 1
            border.color: Tema.colorBorde

            ScrollView {
                id: scrollCrearSalaMovil
                anchors.fill: parent
                anchors.margins: 14 * Tema.escala
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Column {
                    width: scrollCrearSalaMovil.availableWidth
                    spacing: 10 * Tema.escala

                    Column {
                        width: parent.width
                        spacing: 4 * Tema.escala
                        Text {
                            text: "SALA"
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 11 * Tema.escala
                            font.letterSpacing: 1
                        }
                        Rectangle { width: parent.width; height: 1; color: Tema.colorBorde }
                    }

                    // Nombre de sala: campo "de mentira" que abre
                    // CampoEmergente, igual que el nombre de jugador en
                    // Inicio (punto 2 del plan de diseño móvil).
                    Rectangle {
                        id: cajaNombreSalaMovil
                        width: parent.width
                        height: Tema.tamanoMinTactil
                        radius: 6 * Tema.escala
                        color: Tema.colorFondo
                        border.width: 1
                        border.color: areaNombreSala.pressed ? Tema.colorAccent : Tema.colorBorde
                        property string valor: ""
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10 * Tema.escala
                            anchors.verticalCenter: parent.verticalCenter
                            text: cajaNombreSalaMovil.valor !== "" ? cajaNombreSalaMovil.valor : "Nombre de la sala"
                            color: cajaNombreSalaMovil.valor !== "" ? "white" : Tema.colorTextoMuyTenue
                            font.pixelSize: 13 * Tema.escala
                        }
                        MouseArea {
                            id: areaNombreSala
                            anchors.fill: parent
                            onClicked: campoNombreSalaMovil.abrir(cajaNombreSalaMovil.valor)
                        }
                        CampoEmergente {
                            id: campoNombreSalaMovil
                            parent: Overlay.overlay
                            etiqueta: "Nombre de la sala"
                            onAceptado: (texto) => cajaNombreSalaMovil.valor = texto
                        }
                    }

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - interruptorPublicaMovil.width
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Sala pública"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                        }
                        Interruptor {
                            id: interruptorPublicaMovil
                            activo: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - selectorTamanoMovil.width
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Tamaño de sala (asientos, máx. 9)"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                            wrapMode: Text.WordWrap
                        }
                        SelectorNumerico {
                            id: selectorTamanoMovil
                            anchors.verticalCenter: parent.verticalCenter
                            valor: 6
                            minimo: 2
                            maximo: 9
                        }
                    }

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - interruptorRellenarMovil.width
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Rellenar con bots los asientos vacíos"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                            wrapMode: Text.WordWrap
                        }
                        Interruptor {
                            id: interruptorRellenarMovil
                            activo: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - interruptorAbiertaMovil.width
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Abierta tras iniciar"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                            wrapMode: Text.WordWrap
                        }
                        Interruptor {
                            id: interruptorAbiertaMovil
                            activo: false
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4 * Tema.escala
                        Text {
                            text: "REGLAS DE APUESTA"
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 11 * Tema.escala
                            font.letterSpacing: 1
                        }
                        Rectangle { width: parent.width; height: 1; color: Tema.colorBorde }
                    }

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - selectorDificultadMovil.width
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Dificultad de bots"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                        }
                        SelectorPildoras {
                            id: selectorDificultadMovil
                            anchors.verticalCenter: parent.verticalCenter
                            opciones: ["Fácil", "Normal", "Experto"]
                            seleccionado: 0
                        }
                    }

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - selectorLimiteMovil.width
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Tipo de límite"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                        }
                        SelectorPildoras {
                            id: selectorLimiteMovil
                            anchors.verticalCenter: parent.verticalCenter
                            opciones: ["Sin límite", "Límite bote", "Límite fijo"]
                            seleccionado: 0
                        }
                    }

                    Row {
                        width: parent.width
                        visible: selectorLimiteMovil.seleccionado === 2
                        Text {
                            width: parent.width - selectorMonteFijoMovil.width
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Cantidad fija por raise"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                        }
                        SelectorNumerico {
                            id: selectorMonteFijoMovil
                            anchors.verticalCenter: parent.verticalCenter
                            valor: 40
                            minimo: 1
                            maximo: 10000
                            paso: 10
                        }
                    }

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - interruptorMinRaiseMovil.width
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Min-raise obligatorio"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                            wrapMode: Text.WordWrap
                        }
                        Interruptor {
                            id: interruptorMinRaiseMovil
                            activo: false
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - interruptorRecompraMovil.width
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Permitir recompra al quedarse sin fichas"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                            wrapMode: Text.WordWrap
                        }
                        Interruptor {
                            id: interruptorRecompraMovil
                            activo: false
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4 * Tema.escala
                        Text {
                            text: "PARTIDA"
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 11 * Tema.escala
                            font.letterSpacing: 1
                        }
                        Rectangle { width: parent.width; height: 1; color: Tema.colorBorde }
                    }

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - selectorNumManosMovil.width
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Número de manos"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                        }
                        SelectorNumerico {
                            id: selectorNumManosMovil
                            anchors.verticalCenter: parent.verticalCenter
                            valor: 20
                            minimo: 1
                            maximo: 200
                        }
                    }

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - interruptorPreguntarExtensionMovil.width
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Preguntar si extender al llegar al límite"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                            wrapMode: Text.WordWrap
                        }
                        Interruptor {
                            id: interruptorPreguntarExtensionMovil
                            activo: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - selectorCiegaMovil.width
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Ciega grande"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                        }
                        SelectorNumerico {
                            id: selectorCiegaMovil
                            anchors.verticalCenter: parent.verticalCenter
                            valor: 20
                            minimo: 2
                            maximo: 1000
                            paso: 5
                        }
                    }

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - selectorSaldoMovil.width
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Saldo inicial"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                        }
                        SelectorNumerico {
                            id: selectorSaldoMovil
                            anchors.verticalCenter: parent.verticalCenter
                            valor: 1000
                            minimo: 100
                            maximo: 100000
                            paso: 100
                        }
                    }
                }
            }
        }

        Text {
            visible: ventana.mensajeErrorConexion !== "" && ventana.pantalla === "CrearSala"
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Tema.colorPeligro
            font.pixelSize: 11 * Tema.escala
            text: ventana.mensajeErrorConexion
        }

        Row {
            id: filaBotonesCrearSalaMovil
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10 * Tema.escala
            BotonContorno {
                text: "Cancelar"
                colorBorde: Tema.colorPeligro
                onClicked: ventana.pantalla = "Salas"
            }
            BotonRelleno {
                text: "Crear sala"
                onClicked: {
                    if (ventana.nombreJugador === "") { campoNombre.abrir(""); return; }
                    redcliente.crearSala(
                        ventana.servidorHost, ventana.servidorPuerto, ventana.nombreJugador,
                        cajaNombreSalaMovil.valor,
                        interruptorPublicaMovil.activo,
                        selectorTamanoMovil.valor,
                        selectorNumManosMovil.valor,
                        selectorCiegaMovil.valor,
                        selectorSaldoMovil.valor,
                        selectorLimiteMovil.seleccionado,
                        interruptorMinRaiseMovil.activo,
                        selectorMonteFijoMovil.valor,
                        selectorDificultadMovil.seleccionado,
                        interruptorRecompraMovil.activo,
                        interruptorRellenarMovil.activo,
                        interruptorAbiertaMovil.activo,
                        interruptorPreguntarExtensionMovil.activo
                    );
                }
            }
        }
    }

    // ── Pantalla Lobby ───────────────────────────────────────────────────
    // Sin BarraSuperior aquí a propósito (punto 6 del plan): Lobby usa el
    // IconoAjustes flotante de abajo, no la franja completa.
    Column {
        visible: ventana.pantalla === "Lobby"
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 28 * Tema.escala
        spacing: 16 * Tema.escala

        Column {
            spacing: 3 * Tema.escala
            Text {
                text: "Sala de " + (ventana.hostActual !== "" ? ventana.hostActual : "espera")
                color: "white"
                font.family: Tema.fuenteElegante
                font.bold: true
                font.pixelSize: 20 * Tema.escala
            }
            Text {
                text: ventana.textoListos
                color: Tema.colorTextoTenue
                font.pixelSize: 12 * Tema.escala
            }
            Text {
                visible: ventana.codigoSalaPropia !== ""
                text: "Código para invitar: " + ventana.codigoSalaPropia
                color: Tema.colorAccent
                font.bold: true
                font.pixelSize: 12 * Tema.escala
            }
            Text {
                visible: ventana.nombresEsperadosLobby !== ""
                text: "Nombres esperados: " + ventana.nombresEsperadosLobby
                color: Tema.colorTextoTenue
                font.pixelSize: 12 * Tema.escala
                wrapMode: Text.WordWrap
                width: 220 * Tema.escala
            }
        }

        Row {
            spacing: 14 * Tema.escala
            Repeater {
                model: jugadoresConectados
                delegate: Item {
                    id: posicionadorMiniMovil
                    required property string nombre
                    width: asientoMiniMovil.width
                    height: asientoMiniMovil.height
                    AsientoMini {
                        id: asientoMiniMovil
                        nombre: posicionadorMiniMovil.nombre
                    }
                }
            }
        }

        BotonRelleno {
            visible: ventana.soyHost
            text: "Empezar ahora"
            radioBorde: 999
            onClicked: redcliente.empezarPartida()
        }

        // Roster de quién está esperando a sentarse a mitad de partida
        // (JOIN_GAME aceptado en una sala "abierta tras inicio", todavía
        // sin asiento) -- antes esta gente era invisible del todo hasta
        // que por fin les tocaba jugar.
        Text {
            visible: ventana.listaEsperando.length > 0
            text: "Esperando a sentarse: " + ventana.listaEsperando.join(", ")
            color: Tema.colorTextoTenue
            font.pixelSize: 12 * Tema.escala
            wrapMode: Text.WordWrap
            width: 220 * Tema.escala
        }
        Text {
            visible: ventana.mensajeEnEspera !== ""
            text: ventana.mensajeEnEspera
            color: Tema.colorAccent
            font.pixelSize: 12 * Tema.escala
            wrapMode: Text.WordWrap
            width: 220 * Tema.escala
        }
    }

    ChatBox {
        visible: ventana.pantalla === "Lobby"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 28 * Tema.escala
        activo: ventana.chatActive
        modelo: mensajesChatSala
        miNombre: ventana.nombreJugador
    }

    // ── Pantalla Partida ─────────────────────────────────────────────────
    // Sin BarraSuperior ni PanelLateral todavía (punto 5/6 del plan): la
    // mesa ocupa casi toda la pantalla, el chat/historial en bottom-sheet
    // queda para la próxima ronda. Fila "ACTUAL/PROBABLE/MÁXIMA" reducida
    // a solo el combo actual por espacio — recuperar las otras dos si el
    // hueco lo permite una vez probado en un dispositivo real.
    Item {
        visible: ventana.pantalla === "Partida"
        anchors.fill: parent

        // Mesa a 2/3 del ancho (antes casi toda la pantalla): un óvalo tan
        // panorámico como el ancho completo es lo que causaba el solape
        // real entre asientos y cartas comunitarias (radio vertical
        // demasiado pequeño) — a 2/3 la proporción baja a algo mucho más
        // manejable sin tocar la trigonometría de Mesa.qml.
        Mesa {
            id: mesaJuegoMovil
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 8 * Tema.escala
            width: parent.width * 2 / 3 - 8 * Tema.escala
            jugadores: jugadoresPartida
            cartasMesa: ventana.cartasMesa
            bote: ventana.boteActual
            turnoNombre: ventana.turnoNombre
            miNombreJugador: ventana.nombreJugador
            fraccionTiempo: ventana.fraccionTiempoRestante
            retirados: ventana.retirados
        }

        // Cajón de pestañas al tercio restante — sustituye tanto la barra
        // de acciones inferior como el IconoAjustes flotante que había
        // aquí (el suyo ahora vive en la cabecera del propio cajón).
        CajonPartida {
            id: cajonPartidaMovil
            anchors.left: mesaJuegoMovil.right
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8 * Tema.escala
            anchors.leftMargin: 8 * Tema.escala
            turnoNombre: ventana.turnoNombre
            tuTurno: ventana.tuTurno
            fraccionTiempo: ventana.fraccionTiempoRestante
            bote: ventana.boteActual
            rondaActual: ventana.rondaActual
            manoActual: ventana.manoActual
            objetivoManos: ventana.objetivoManos
            comboActual: ventana.comboActual
            comboProbable: ventana.comboProbable
            comboMaxima: ventana.comboMaxima
            miCarta1: ventana.miCarta1
            miCarta2: ventana.miCarta2
            miSaldoActual: ventana.miSaldoActual
            aPagarParaIgualar: ventana.aPagarParaIgualar
            minSubidaActual: ventana.minSubidaActual
            maxSubidaActual: ventana.maxSubidaActual
            ciegaActual: ventana.ciegaActual
            puedoRecomprar: ventana.puedoRecomprar
            recompraSolicitada: ventana.recompraSolicitada
            conectado: !ventana.reconectandoAhora
            nombreJugador: ventana.nombreJugador
            modeloHistorial: historialMovil
            modeloChat: mensajesChatPartida
            onAbrirAjustes: ventana.ajustesAbiertos = !ventana.ajustesAbiertos
            onDecisionEnviada: {
                ventana.tuTurno = false;
                ventana.turnoNombre = "";
            }
            onRecompraPedida: ventana.recompraSolicitada = true
        }

        // ── Showdown / voto de fin de mano ──────────────────────────────
        // Mismo overlay para los dos casos (cartas reveladas de verdad, o
        // "se llevó el bote sin mostrar cartas") — onGanadorSinShowdown
        // también abre esto, con revealsShowdown de una sola tarjeta sin
        // cartas. El voto de continuar/abandonar vive DENTRO, para poder
        // votar sin dejar de ver el resultado.
        Rectangle {
            anchors.fill: parent
            visible: ventana.showdownAbierto
            color: "#0A140F"
            opacity: 0.94

            Flickable {
                id: flickableShowdownMovil
                anchors.fill: parent
                anchors.margins: 16 * Tema.escala
                contentWidth: width
                contentHeight: columnaShowdownMovil.height
                clip: true

                Column {
                    id: columnaShowdownMovil
                    width: parent.width
                    spacing: 14 * Tema.escala

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "SHOWDOWN"
                        color: Tema.colorAccent
                        font.letterSpacing: 3
                        font.pixelSize: 12 * Tema.escala
                        font.bold: true
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4 * Tema.escala
                        Repeater {
                            model: ventana.cartasMesa
                            delegate: Carta {
                                required property string modelData
                                codigo: modelData
                            }
                        }
                    }

                    Text {
                        visible: ventana.resumenBotes.length <= 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Bote: " + ventana.boteTotalShowdown()
                        color: Tema.colorTextoTenue
                        font.pixelSize: 12 * Tema.escala
                        font.family: Tema.fuenteElegante
                    }

                    Column {
                        visible: ventana.resumenBotes.length > 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        spacing: 3 * Tema.escala
                        Repeater {
                            model: ventana.resumenBotes
                            delegate: Text {
                                required property var modelData
                                anchors.horizontalCenter: parent.horizontalCenter
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                                wrapMode: Text.WordWrap
                                font.pixelSize: 11 * Tema.escala
                                font.family: Tema.fuenteElegante
                                color: Tema.colorTextoTenue
                                text: {
                                    var etiqueta = modelData.numBote === 0
                                            ? "Bote principal" : "Side pot " + modelData.numBote;
                                    var linea = etiqueta + ": " + modelData.cantidad +
                                            " — compiten " + modelData.competidores.join(", ");
                                    if (modelData.ganador !== "")
                                        linea += " · ganó " + modelData.ganador + " (+" + modelData.premioGanador + ")";
                                    return linea;
                                }
                            }
                        }
                    }

                    // Una tarjeta por jugador que llegó al showdown, en
                    // filas propias (cada Row se centra sola) — igual
                    // patrón que escritorio, con menos hueco disponible
                    // por fila al ser una pantalla más estrecha.
                    Column {
                        id: filaRevealsMovil
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12 * Tema.escala
                        readonly property real anchoItem: 130 * Tema.escala
                        readonly property int itemsPorFila: Math.max(1, Math.floor(
                                (parent.width + spacing) / (anchoItem + spacing)))
                        Repeater {
                            model: Math.ceil(ventana.revealsShowdown.length / filaRevealsMovil.itemsPorFila)
                            delegate: Row {
                                required property int index
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: filaRevealsMovil.spacing
                                Repeater {
                                    model: ventana.revealsShowdown.slice(
                                            index * filaRevealsMovil.itemsPorFila,
                                            (index + 1) * filaRevealsMovil.itemsPorFila)
                                    delegate: TarjetaReveal {
                                        required property var modelData
                                        datos: modelData
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        visible: ventana.votoAbierto
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10 * Tema.escala
                        Text {
                            // No se usa ventana.mensajeVoto tal cual: el
                            // servidor lo redacta pensando en el cliente
                            // ncurses ("Pulsa Enter para continuar..."),
                            // que no tiene sentido sin teclado físico. El
                            // botón de abajo (PanelVoto) ya deja claro qué
                            // hacer, este texto es solo la cabecera.
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Fin de la mano"
                            color: Tema.colorAccent
                            font.bold: true
                            font.pixelSize: 12 * Tema.escala
                        }
                        PanelVoto {
                            anchors.horizontalCenter: parent.horizontalCenter
                            soyHost: ventana.soyHost
                            onContinuar: { ventana.votoAbierto = false; ventana.mensajeVoto = ""; }
                            onAbandonar: ventana.votoAbierto = false
                            onGuardarYSalir: ventana.votoAbierto = false
                        }
                    }
                }
            }

            // Pista de que hay más contenido por debajo del scroll --
            // pedido explícito (algunos probadores no se daban cuenta de
            // que había que deslizar para llegar al botón de continuar).
            // Fundido + texto que rebota suavemente, visibles solo
            // mientras quede contenido sin ver por debajo (se ocultan
            // solos en cuanto se llega al final, no hace falta tocar nada
            // para que desaparezcan).
            Rectangle {
                id: fundidoInferiorShowdown
                visible: opacity > 0
                opacity: (flickableShowdownMovil.contentHeight > flickableShowdownMovil.height &&
                          flickableShowdownMovil.contentY <
                              flickableShowdownMovil.contentHeight - flickableShowdownMovil.height - 4) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 46 * Tema.escala
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0.04, 0.078, 0.059, 0.96) }
                }

                Text {
                    id: textoPistaScrollShowdown
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6 * Tema.escala
                    text: "más abajo"
                    color: Tema.colorTextoTenue
                    font.pixelSize: 10 * Tema.escala

                    // "transform", no animar anchors.bottomMargin directo:
                    // el anclaje reafirma la posición en cada layout y
                    // pelearía con la animación. Un Translate se aplica
                    // aparte, en tiempo de render, sin ese conflicto
                    // (mismo patrón que el desplazamiento del chat sobre
                    // el teclado en ChatBox.qml).
                    property real rebote: 0
                    transform: Translate { y: -textoPistaScrollShowdown.rebote }
                    SequentialAnimation on rebote {
                        loops: Animation.Infinite
                        running: fundidoInferiorShowdown.opacity > 0
                        NumberAnimation { from: 0; to: 4 * Tema.escala; duration: 550; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 4 * Tema.escala; to: 0; duration: 550; easing.type: Easing.InOutQuad }
                    }
                }
            }
        }

        // ── Voto de extensión de partida ────────────────────────────────
        Rectangle {
            visible: ventana.votoExtensionAbierto
            anchors.centerIn: parent
            width: columnaVotoExtMovil.width + 32 * Tema.escala
            height: columnaVotoExtMovil.height + 24 * Tema.escala
            radius: 12 * Tema.escala
            color: Tema.colorPanel
            border.width: 1
            border.color: Tema.colorAccent

            Column {
                id: columnaVotoExtMovil
                anchors.centerIn: parent
                spacing: 10 * Tema.escala
                width: Math.min(280 * Tema.escala, ventana.width - 80 * Tema.escala)
                Text {
                    width: parent.width
                    text: ventana.votoExtensionMensaje
                    color: Tema.colorAccent
                    font.bold: true
                    font.pixelSize: 13 * Tema.escala
                    wrapMode: Text.WordWrap
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8 * Tema.escala
                    BotonRelleno {
                        text: "Sí, extender"
                        onClicked: {
                            redcliente.votarExtension(true);
                            ventana.votoExtensionAbierto = false;
                        }
                    }
                    BotonContorno {
                        text: "No, terminar aquí"
                        colorBorde: Tema.colorPeligro
                        onClicked: {
                            redcliente.votarExtension(false);
                            ventana.votoExtensionAbierto = false;
                        }
                    }
                }
            }
        }
    }

    // ── Pantalla Fin ─────────────────────────────────────────────────────
    Item {
        visible: ventana.pantalla === "Fin"
        anchors.fill: parent

        Rectangle {
            anchors.centerIn: parent
            width: contenidoFinMovil.width + 48 * Tema.escala
            // Con las estadísticas nuevas (elimina uno por jugador, hasta 9)
            // el contenido puede pasarse del alto disponible en landscape
            // móvil -- se limita al alto de la ventana y se deja scrollear
            // en vez de desbordar sin forma de verlo (mismo patrón que el
            // showdown/CrearSala).
            height: Math.min(contenidoFinMovil.height + 36 * Tema.escala, ventana.height - 40 * Tema.escala)
            border.width: 1
            border.color: Tema.colorAccent
            radius: 14 * Tema.escala
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                GradientStop { position: 1.0; color: Tema.colorPanel }
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: 18 * Tema.escala
                contentWidth: contenidoFinMovil.width
                contentHeight: contenidoFinMovil.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

            Column {
                id: contenidoFinMovil
                width: Math.min(280 * Tema.escala, ventana.width - 80 * Tema.escala)
                spacing: 12 * Tema.escala

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ventana.partidaGuardada ? "PARTIDA GUARDADA" : "PARTIDA FINALIZADA"
                    color: Tema.colorAccent
                    font.letterSpacing: 2
                    font.pixelSize: 11 * Tema.escala
                    font.bold: true
                }
                Text {
                    visible: !ventana.partidaGuardada
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Ganador"
                    color: Tema.colorTextoTenue
                    font.pixelSize: 11 * Tema.escala
                }
                Text {
                    visible: !ventana.partidaGuardada
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ventana.ganadorFinal
                    color: "white"
                    font.family: Tema.fuenteElegante
                    font.pixelSize: 22 * Tema.escala
                    font.bold: true
                }
                Text {
                    visible: !ventana.partidaGuardada
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ventana.saldoFinal + " fichas"
                    color: Tema.colorAccent
                    font.pixelSize: 14 * Tema.escala
                }
                Text {
                    visible: !ventana.partidaGuardada
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: ventana.finPorLimite ? "Se alcanzó el límite de manos." : "El resto de jugadores ha quedado eliminado."
                    color: Tema.colorTextoTenue
                    font.pixelSize: 12 * Tema.escala
                }

                // ── Estadísticas de la partida ────────────────────
                Rectangle {
                    visible: !ventana.partidaGuardada
                    width: parent.width
                    height: 1
                    color: Tema.colorBorde
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !ventana.partidaGuardada
                    text: "Manos disputadas: " + ventana.manosDisputadasFinal
                    color: Tema.colorTextoTenue
                    font.pixelSize: 11 * Tema.escala
                }
                Column {
                    visible: !ventana.partidaGuardada && ventana.mejorManoFinal !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 1 * Tema.escala
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "MEJOR MANO DE LA PARTIDA"
                        color: Tema.colorTextoMuyTenue
                        font.pixelSize: 8 * Tema.escala
                        font.letterSpacing: 1
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ventana.mejorManoFinal + " — " + ventana.mejorManoJugadorFinal
                        color: Tema.colorAccent
                        font.bold: true
                        font.family: Tema.fuenteElegante
                        font.pixelSize: 13 * Tema.escala
                    }
                }
                Column {
                    visible: !ventana.partidaGuardada && ventana.eliminacionesFinal.length > 0
                    width: parent.width
                    spacing: 3 * Tema.escala
                    Repeater {
                        model: ventana.eliminacionesFinal
                        delegate: Row {
                            required property var modelData
                            width: parent.width
                            Text {
                                width: parent.width - textoManoEliminacionMovil.width
                                text: modelData.nombre
                                color: modelData.nombre === ventana.ganadorFinal ? Tema.colorAccent : "white"
                                font.bold: modelData.nombre === ventana.ganadorFinal
                                font.pixelSize: 10 * Tema.escala
                                elide: Text.ElideRight
                            }
                            Text {
                                id: textoManoEliminacionMovil
                                text: modelData.mano === "X" ? "Sigue en juego" : "Mano " + modelData.mano
                                color: Tema.colorTextoTenue
                                font.pixelSize: 10 * Tema.escala
                            }
                        }
                    }
                }

                Text {
                    visible: ventana.partidaGuardada
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "El Host puede continuar la partida desde sus partidas guardadas."
                    color: Tema.colorTextoTenue
                    font.pixelSize: 12 * Tema.escala
                }
                BotonRelleno {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Volver a salas"
                    radioBorde: 999
                    onClicked: {
                        ventana.codigoSalaPropia = "";
                        ventana.pantalla = "Salas";
                        redcliente.refrescarSalas(ventana.servidorHost, ventana.servidorPuerto);
                    }
                }
            }
            }
        }
    }

    IconoAjustes {
        // "Partida" ya no está aquí: su propio CajonPartida trae un
        // IconoAjustes en la cabecera, no hace falta el flotante también.
        visible: ventana.pantalla === "Lobby" || ventana.pantalla === "Fin"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        onAbrirAjustes: ventana.ajustesAbiertos = !ventana.ajustesAbiertos
    }

    // ── Cajón de ajustes ─────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: ventana.ajustesAbiertos
        color: "black"
        opacity: 0.35
        MouseArea {
            anchors.fill: parent
            onClicked: ventana.ajustesAbiertos = false
        }
    }
    Rectangle {
        id: cajonAjustesMovil
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: Math.min(320 * Tema.escala, ventana.width * 0.85)
        visible: ventana.ajustesAbiertos
        color: Tema.colorPanel

        ScrollView {
            anchors.fill: parent
            anchors.margins: 18 * Tema.escala
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: cajonAjustesMovil.width - 36 * Tema.escala
                spacing: 20 * Tema.escala

                Text {
                    text: "Ajustes"
                    color: "white"
                    font.family: Tema.fuenteElegante
                    font.pixelSize: 18 * Tema.escala
                }

                // ── Tema de color ────────────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 8 * Tema.escala
                    Text {
                        text: "TEMA DE COLOR"
                        color: Tema.colorTextoMuyTenue
                        font.pixelSize: 10 * Tema.escala
                        font.letterSpacing: 1
                    }
                    Repeater {
                        model: Tema.temas
                        delegate: Rectangle {
                            id: filaTemaMovil
                            required property var modelData
                            required property int index
                            width: parent.width
                            height: 48 * Tema.escala
                            radius: 8 * Tema.escala
                            color: Tema.temaActual === filaTemaMovil.index ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                            border.width: Tema.temaActual === filaTemaMovil.index ? 2 : 1
                            border.color: Tema.temaActual === filaTemaMovil.index ? filaTemaMovil.modelData.accent : Tema.colorBorde

                            Row {
                                anchors.fill: parent
                                anchors.margins: 10 * Tema.escala
                                spacing: 10 * Tema.escala
                                Rectangle {
                                    width: 26 * Tema.escala
                                    height: 26 * Tema.escala
                                    radius: width / 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: filaTemaMovil.modelData.tapete
                                    border.width: 2
                                    border.color: filaTemaMovil.modelData.accent
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: filaTemaMovil.modelData.nombre
                                    color: Tema.temaActual === filaTemaMovil.index ? "white" : Tema.colorTextoTenue
                                    font.bold: Tema.temaActual === filaTemaMovil.index
                                    font.pixelSize: 13 * Tema.escala
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: Tema.temaActual = filaTemaMovil.index
                            }
                        }
                    }
                }

                // ── Mesa actual (solo lectura, solo en Partida) ───────────
                Column {
                    width: parent.width
                    visible: ventana.pantalla === "Partida"
                    spacing: 8 * Tema.escala
                    Text {
                        text: "MESA ACTUAL"
                        color: Tema.colorTextoMuyTenue
                        font.pixelSize: 10 * Tema.escala
                        font.letterSpacing: 1
                    }
                    Repeater {
                        model: [
                            { etiqueta: "Ciega actual", valor: Math.round(ventana.ciegaActual / 2) + " / " + ventana.ciegaActual },
                            { etiqueta: "Mano", valor: ventana.manoActual + " / " + ventana.objetivoManos },
                            { etiqueta: "Tipo de límite", valor: ["Sin límite", "Límite bote", "Límite fijo"][ventana.tipoLimiteActual] || "—" },
                            { etiqueta: "Permite recompra", valor: ventana.permitirRecompraActual ? "Sí" : "No" },
                            { etiqueta: "Rellena con bots", valor: ventana.rellenarConBotsActual ? "Sí" : "No" },
                            { etiqueta: "Pregunta al extender", valor: ventana.preguntarExtensionActual ? "Sí" : "No" }
                        ].concat(ventana.codigoSalaPropia !== ""
                            ? [{ etiqueta: "Código de invitación", valor: ventana.codigoSalaPropia }]
                            : [])
                        delegate: Row {
                            required property var modelData
                            width: parent.width
                            Text {
                                width: parent.width - 80 * Tema.escala
                                text: modelData.etiqueta
                                color: Tema.colorTextoTenue
                                font.pixelSize: 11 * Tema.escala
                            }
                            Text {
                                text: modelData.valor
                                color: "white"
                                font.pixelSize: 11 * Tema.escala
                                font.bold: true
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }

                // ── Cliente ────────────────────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 12 * Tema.escala
                    Text {
                        text: "CLIENTE"
                        color: Tema.colorTextoMuyTenue
                        font.pixelSize: 10 * Tema.escala
                        font.letterSpacing: 1
                    }
                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - 46 * Tema.escala
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Sonido de notificaciones"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                            wrapMode: Text.WordWrap
                        }
                        Interruptor {
                            anchors.verticalCenter: parent.verticalCenter
                            activo: ventana.sonidoActivado
                            onAlternado: ventana.sonidoActivado = !ventana.sonidoActivado
                        }
                    }
                    BotonContorno {
                        text: "Ranking de manos"
                        onClicked: chuletaMovil.open()
                    }
                }
            }
        }
    }

    // Hermano de las pantallas (no dentro de ninguna), para quedar
    // siempre encima sin importar qué "pantalla" esté activa en ese
    // momento — mismo mecanismo de reconexión de 60s que ncurses/escritorio.
    Rectangle {
        anchors.fill: parent
        visible: ventana.reconectandoAhora
        color: "#0A140F"
        opacity: 0.92
        Column {
            anchors.centerIn: parent
            spacing: 10 * Tema.escala
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Conexión perdida — reconectando..."
                color: "white"
                font.pixelSize: 16 * Tema.escala
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ventana.segundosReconexion + "s restantes"
                color: Tema.colorTextoTenue
                font.pixelSize: 12 * Tema.escala
            }
        }
    }

    ChuletaFlotante {
        id: chuletaMovil
        parent: Overlay.overlay
    }

    CampoEmergente {
        id: campoNombre
        parent: Overlay.overlay
        etiqueta: "Tu nombre"
        onAceptado: (texto) => ventana.nombreJugador = texto
    }

    CampoEmergente {
        id: campoRenombrarMovil
        parent: Overlay.overlay
        etiqueta: "Nuevo nombre"
        onAceptado: (texto) => redcliente.renombrarGuardada(
            ventana.servidorHost, ventana.servidorPuerto,
            ventana.archivoARenombrar, texto)
    }
}
