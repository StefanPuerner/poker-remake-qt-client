// Main.qml — ventana raíz de PokerClientQt (andamiaje inicial)
//
// Punto de partida deliberadamente vacío: aquí empieza a construirse la
// interfaz real (mesa, panel de turno, chat, perfiles de rivales) siguiendo
// el documento de diseño de la rama variante-Qt. De momento solo confirma
// que Qt Quick compila, carga el módulo QML y se conecta con C++.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Window
import Qt.labs.settings
import QtMultimedia

ApplicationWindow {
    id: ventana
    Material.accent: Tema.colorAccent

    // ── Tema de color y escala ────────────────────────────────────────────
    // La paleta, los colorX y "escala" viven en el singleton Tema.qml (así
    // cualquier fichero puede usar "Tema.colorX"/"Tema.escala" sin tener
    // que pasarlos a mano por cada componente) — aquí solo se mantienen
    // sincronizados con lo que depende del tamaño real de ESTA ventana en
    // concreto, que el singleton no puede saber por sí solo.
    Binding { target: Tema; property: "escala"; value: Math.min(ventana.width / 1040, ventana.height / 780) * Tema.zoomManual }

    // Zoom manual — la detección automática de DPI entre entornos de
    // escritorio de Linux no dio resultado (mismo portátil, mismo
    // Hyprland vs GNOME, tamaños distintos sin explicación fiable), así
    // que en vez de perseguir eso, control directo del usuario. "Ctrl+="
    // además de "Ctrl++" porque en la mayoría de teclados "+" pide Shift
    // y el atajo "sin Shift" (donde vive el "=") es el que de verdad se
    // pulsa sin pensar.
    Shortcut {
        sequences: ["Ctrl++", "Ctrl+="]
        onActivated: Tema.subirZoom()
    }
    Shortcut {
        sequence: "Ctrl+-"
        onActivated: Tema.bajarZoom()
    }
    Shortcut {
        sequence: "Ctrl+0"
        onActivated: Tema.reiniciarZoom()
    }



    // color.toString() en QML devuelve "#AARRGGBB" (con canal alfa) o
    // "#RRGGBB" según la versión — ninguno de los dos es fiable a pelo
    // dentro de un <font color=...>: el de 8 dígitos lo ignora en
    // silencio. Los últimos 6 caracteres son siempre "RRGGBB" en los dos
    // casos, así que esto da un hex limpio pase lo que pase.
    // (Implementación real en Tema.colorHex() — accesible tal cual desde
    // aquí porque Tema es un singleton, no hace falta redeclararla.)

    // ── Fuente empaquetada (fuera de QML puro) ────────────────────────────
    // Los nombres de fuente de sistema del boceto ("Iowan Old Style",
    // "Georgia"...) no existen en Linux ni están garantizados en Android, así
    // que en vez de referenciar una fuente por nombre y confiar en que el
    // sistema la tenga, se empaqueta el fichero real como recurso Qt
    // (ver CMakeLists.txt, RESOURCES de qt_add_qml_module) y se carga aquí.
    // Así el resultado es idéntico en cualquier plataforma, sin depender de
    // qué tenga instalado quien lo ejecute.
    // EB Garamond — SIL Open Font License 1.1, ver assets/fonts/OFL.txt.
    FontLoader {
        id: cargadorFuenteElegante
        source: "qrc:/qt/qml/PokerQuick/assets/fonts/EBGaramond.ttf"
    }
    // Un id (como "cargadorFuenteElegante") no se puede leer desde fuera como
    // si fuera una property del objeto que lo contiene — por eso se
    // reenvía aquí a Tema.fuenteElegante (singleton), que es lo que
    // "Carta" y el resto de componentes leen de verdad.
    Binding { target: Tema; property: "fuenteElegante"; value: cargadorFuenteElegante.name }

    // ── Ajustes persistentes (nombre, sonido, tema) ─────────────────────
    // Qt.labs.settings los guarda solo (INI en ~/.config en Linux, registro
    // en Windows) sin escribir nada de C++: cada "property alias" lee el
    // valor guardado nada más arrancar, y vuelve a guardarlo en cuanto
    // cambia. "nombreUsuario" y "Tema" se declaran más abajo/en otro
    // fichero, pero un id es visible en todo el documento QML sin
    // importar el orden -- para cuando este Settings arranca de verdad
    // (Component.onCompleted), el resto del árbol ya existe.
    Settings {
        id: ajustesPersistentes
        category: "PokerRemake"
        // Reemplaza al viejo "nombreGuardado" (nombre libre persistido) --
        // ahora la identidad la da la cuenta (o un nombre de invitado
        // efímero, sin persistir). Apunta a una property NORMAL de
        // "ventana" (nunca a un singleton -- ver el aviso de "tema" un
        // poco más abajo, ya documentado el mismo problema).
        property alias tokenGuardado: ventana.tokenSesion
        property alias sonido: ventana.sonidoActivado
        // "tema" NO es un property alias a Tema.temaActual a propósito:
        // un alias a una propiedad de un SINGLETON (a diferencia de un id
        // normal dentro de este mismo documento) da un alias que el
        // linter marca como no resoluble -- comprobado en real que no es
        // solo un aviso cosmético: con ese alias puesto, este Settings
        // entero dejaba de escribir NADA en disco (ni siquiera
        // nombreGuardado/sonido, que sí funcionan solos). Se guarda como
        // un entero normal y se sincroniza a mano en los dos sentidos más
        // abajo, mismo patrón que la Binding de fuenteElegante de arriba.
        property int temaGuardado: 0
    }
    Component.onCompleted: {
        Tema.temaActual = ajustesPersistentes.temaGuardado;
        // Reautenticación silenciosa: si hay un token guardado de una
        // sesión anterior, se intenta ANTES de que el usuario vea nada de
        // Inicio -- si el servidor lo acepta (onLoginOk), se entra directo
        // a Salas sin pedir contraseña; si no (onSesionInvalida), se
        // limpia y Inicio se muestra normal (sus 3 botones de siempre).
        if (tokenSesion !== "") {
            redcliente.iniciarSesionConToken(servidorHost, servidorPuerto, tokenSesion);
        }
    }
    Connections {
        target: Tema
        function onTemaActualChanged() { ajustesPersistentes.temaGuardado = Tema.temaActual; }
    }
    property string pantalla: "Inicio"
    // Token de sesión de la cuenta activa ("" = invitado o sin sesión) --
    // persistido vía Settings.tokenGuardado (alias de arriba). NetworkClient
    // lleva su propia copia interna (token_); esta es la del lado QML, para
    // poder guardarla en disco y mandarla a iniciarSesionConToken() al
    // arrancar.
    property string tokenSesion: ""
    // Compartido por las pantallas Login y Registro -- se limpia al entrar
    // en cualquiera de las dos o al reintentar, para no dejar un error de
    // un intento anterior (o de la otra pantalla) visible sin motivo.
    property string mensajeErrorLogin: ""

    // cambiarNombreUsuario()/cambiarPassword() pueden fallar por el mismo
    // motivo que un token caducado en iniciarSesionConToken() -- si el
    // usuario tenía la sesión abierta en otro sitio y cerró sesión ahí, o
    // el servidor revocó el token por lo que sea, el mensaje que vuelve es
    // literalmente el mismo que usa AccountManager::resolverToken() al
    // fallar (ver AccountManager.cpp). Sin esto, el usuario se quedaba con
    // una sesión rota reintentando la misma acción una y otra vez sin que
    // nada le dijera que el problema real es "vuelve a iniciar sesión".
    function tratarErrorCuenta(mensaje) {
        mensajeErrorLogin = mensaje;
        if (mensaje.indexOf("Sesión caducada") === 0) {
            tokenSesion = "";
            nombreUsuario.text = "";
            ajustesAbiertos = false;
            pantalla = "Inicio";
        }
    }
    // Identidad efectiva del jugador -- ya no es un TextField editable
    // (Inicio perdió el campo de nombre libre): la fija el login/registro
    // (username real de la cuenta), "Entrar como invitado" (nombre
    // genérico) o el propio servidor vía NOMBRE_ASIGNADO si lo sanea. Sigue
    // llamándose "nombreUsuario" y sigue siendo ".text" a propósito -- el
    // resto del fichero (Mesa, PanelLateral, comparaciones de turno...) ya
    // lo lee así en más de diez sitios distintos; cambiar el nombre habría
    // significado tocar todos esos sitios sin necesidad real.
    QtObject {
        id: nombreUsuario
        property string text: ""
    }
    property bool ajustesAbiertos: false
    // Cada vez que se abre el cajón (cualquier pestaña -- no solo Cuenta,
    // para tenerlas ya listas si se cambia a esa pestaña) se refrescan las
    // estadísticas propias. Consulta barata, sin problema en repetirla
    // cada apertura. No-op sin sesión (consultarEstadisticas() ya
    // descarta un token vacío por su cuenta).
    onAjustesAbiertosChanged: {
        if (ajustesAbiertos && tokenSesion !== "") {
            redcliente.consultarEstadisticas(servidorHost, servidorPuerto, tokenSesion);
        }
    }
    // Pestaña activa del cajón lateral: 0 = Ajustes (tema/mesa/cliente),
    // 1 = Cuenta (gestión de cuenta o, sin sesión, acceso a login/
    // registro). Sin persistir -- mismo criterio que el resto de estado
    // de UI efímero de este cajón (chuletaAbierta, etc.).
    property int pestanaAjustesActual: 0
    // Ajustes de cliente (sección "Cliente" del cajón). Desactivado por
    // defecto a propósito (pedido explícito) — quien lo quiera, lo activa
    // él mismo una vez y queda recordado (ver Settings arriba).
    property bool sonidoActivado: false

    // Aviso de "tu turno" — dos tonos sintetizados, ver assets/sonidos/.
    SoundEffect {
        id: sonidoTurno
        source: "qrc:/qt/qml/PokerQuick/assets/sonidos/turno.wav"
    }
    property bool confirmarAllIn: false
    property bool chuletaAbierta: false
    // Centralizados para que la barra superior pueda mostrarlos, y para no
    // repetir el mismo literal en cada llamada a conectar/crearSala/
    // unirseASala/refrescarSalas. Valores por defecto desde ServerConfig.hpp
    // (inyectados por main.cpp) — mismo punto único de configuración que
    // usa el cliente ncurses, no un campo editable en la interfaz.
    property string servidorHost: SERVER_HOST_DEFAULT
    property int servidorPuerto: SERVER_PORT_DEFAULT
    // Estado de conectividad mostrado en Inicio -- comprobandoConexion
    // distingue "aún no sabemos" (primer arranque) de "ya sabemos que no
    // hay servidor", para no enseñar el aviso rojo un instante antes de
    // tener respuesta real.
    property bool conectadoAlServidor: false
    property bool comprobandoConexion: true
    // Sonda periódica mientras se está en Inicio -- host/puerto son fijos
    // en tiempo de ejecución (sin campo editable en la interfaz), así que
    // no hace falta relanzarla por ningún cambio de ajustes, solo al
    // llegar a esta pantalla y cada intervalo mientras se siga en ella.
    // triggeredOnStart dispara una comprobación inmediata tanto al
    // arrancar la app (pantalla ya vale "Inicio" desde el principio) como
    // cada vez que se vuelve a Inicio desde otra pantalla.
    Timer {
        interval: 12000
        running: pantalla === "Inicio"
        repeat: true
        triggeredOnStart: true
        onTriggered: redcliente.comprobarConexion(servidorHost, servidorPuerto)
    }
    // Mensaje de error de conexión/sala compartido entre Inicio, Salas y
    // CrearSala — las tres pueden iniciar una conexión (conectar/crearSala/
    // unirseASala) y un fallo puede llegar estando en cualquiera de ellas,
    // no solo en la que lo originó.
    property string mensajeErrorConexion: ""
    // Antes se quedaba en pantalla para siempre hasta la próxima acción
    // que lo reasignara (a veces solo al volver de otra partida) --
    // reportado en vivo. Se autolimpia sola a los 5s en vez de exigir una
    // acción del usuario para que desaparezca.
    onMensajeErrorConexionChanged: {
        if (mensajeErrorConexion !== "") timerErrorConexion.restart();
    }
    Timer {
        id: timerErrorConexion
        interval: 5000
        onTriggered: mensajeErrorConexion = ""
    }
    // Código de la sala recién creada (pantalla "Crear sala") — solo tiene
    // valor si se creó como privada; se muestra en el Lobby para que el
    // host pueda compartirlo. Se limpia al volver a Inicio.
    property string codigoSalaPropia: ""
    ListModel {
        id: salasDisponibles
    }
    ListModel {
        id: guardadasDisponibles
    }
    // ── Ranking global ──────────────────────────────────────────────────
    // rankingCrudo guarda las filas tal cual llegaron (sin ordenar) --
    // reordenarRanking() reconstruye rankingModel (lo que de verdad pinta
    // el ListView) según la pestaña elegida, sin pedir nada nuevo al
    // servidor solo por cambiar de "Más victorias" a "Mejor ratio".
    property var rankingCrudo: []
    property int ordenRankingActual: 0  // 0 = más victorias, 1 = mejor ratio
    ListModel {
        id: rankingModel
    }
    function reordenarRanking() {
        var filas = rankingCrudo.slice();
        if (ordenRankingActual === 0) {
            filas.sort((a, b) => b.partidasGanadas - a.partidasGanadas);
        } else {
            filas.sort((a, b) => (b.partidasGanadas / b.partidasJugadas) -
                                  (a.partidasGanadas / a.partidasJugadas));
        }
        rankingModel.clear();
        for (var i = 0; i < filas.length; i++) rankingModel.append(filas[i]);
    }
    // ── Estadísticas propias (pestaña Cuenta del cajón) ─────────────────
    property int statsManosJugadas: 0
    property int statsManosGanadas: 0
    property int statsPartidasJugadas: 0
    property int statsPartidasGanadas: 0
    property int statsFichasNetas: 0
    // Toggle de la pantalla "Salas": públicas en curso vs. partidas
    // guardadas que se pueden reanudar como sala nueva.
    property bool viendoGuardadas: false
    // Nombres humanos esperados de la partida reanudada (separados por
    // coma), si la sala actual viene de CARGAR_PARTIDA — vacío en una sala
    // nueva normal. Se muestra en el Lobby para que quien entra sepa con
    // qué nombre unirse aunque no lo recuerde.
    property string nombresEsperadosLobby: ""
    property bool tuTurno: false
    property bool votoAbierto: false
    // Antes vivía solo como el texto de un id ("votoTexto.text = ...") —
    // ahora es una property porque el mismo mensaje se muestra en DOS
    // sitios a la vez: la fila de acciones normal Y dentro del overlay de
    // showdown (ver más abajo, el usuario quiere poder votar sin dejar de
    // ver las cartas reveladas).
    property string mensajeVoto: ""
    // Te quedaste sin fichas y la sala permite recompra (AVISO_RECOMPRA con
    // puede_recomprar=1) — se apaga solo en cuanto onEstadoMesaActualizado
    // vea que tu propio saldo ya es > 0 (no hay un evento dedicado de
    // "recompra confirmada", así que se detecta por esa vía).
    property bool puedoRecomprar: false
    property bool recompraSolicitada: false
    // Showdown: se abre con el evento SHOWDOWN, se va llenando con cada
    // MUESTRA_CARTAS/GANADOR_BOTE, y se cierra al llegar el turno de votar
    // (o una mano nueva, por si acaso) — ver la pantalla superpuesta al
    // final del archivo. Cada entrada: {nombre, cartas:[c1,c2], combo,
    // esGanador, premio}.
    property bool showdownAbierto: false
    property var revealsShowdown: []
    // Uno por bote resuelto en la mano actual — normalmente uno solo (el
    // bote principal), más de uno si hubo varios all-in de distinto
    // tamaño (side pots). Cada entrada: numBote, cantidad, competidores
    // (nombres), y ganador/premioGanador/comboGanador una vez resuelto.
    property var resumenBotes: []

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

    property bool votoExtensionAbierto: false
    // FASE 2 de la extensión de partida (tras la unanimidad del voto de
    // arriba): cuántas manos más se juegan. Solo el host lo elige
    // (soyYoQuienElige); el resto solo ve el mensaje de espera.
    property bool esperandoManosExtra: false
    property string manosExtraMensaje: ""
    property bool soyYoQuienElige: false
    property bool chatActive: false
    // Mensaje de "te has unido a mitad de partida, esperando a la próxima
    // mano" (EN_ESPERA) y roster de quién más está esperando a sentarse en
    // esta sala ahora mismo (SALA_ESPERANDO_UPDATE) — antes esta gente era
    // invisible del todo hasta que por fin les tocaba jugar.
    property string mensajeEnEspera: ""
    property var listaEsperando: []
    property string ganadorFinal: ""
    property int saldoFinal: 0
    property bool finPorLimite: false
    // Estadísticas de la partida terminada -- ya las calculaba el motor
    // (Partida::generarEstadisticas()) para el historial de ncurses, pero
    // nunca llegaban al cliente Qt en el momento de terminar.
    property int manosDisputadasFinal: 0
    property string mejorManoFinal: ""
    property string mejorManoJugadorFinal: ""
    property var eliminacionesFinal: []  // [{nombre, mano}, ...]
    property bool partidaGuardada: false
    property string archivoGuardado: ""
    property bool reconectandoAhora: false
    property int segundosReconexion: 0
    property string hostActual: ""
    // BUG real encontrado en vivo: comparar hostActual (nombre que devuelve
    // el servidor, ya pasado por sanitizarNombre() -- quita tildes/ñ/etc)
    // contra nombreUsuario.text (el texto crudo tal cual se escribió) deja
    // de coincidir en cuanto el nombre lleva un carácter que el servidor
    // recorta, y "Guardar y salir" desaparece para el host real sin motivo
    // aparente. En vez de perseguir la sanitización desde QML, se recuerda
    // directamente si ESTE cliente fue quien creó la sala (creadorDeLaSala,
    // fijado en "Crear sala"/"Unirse" más abajo) -- no depende de que
    // ningún nombre coincida carácter a carácter.
    property bool creadorDeLaSala: false
    property bool soyHost: creadorDeLaSala
    property int igualarActual: 0
    property int miApuestaActual: 0
    property int miSaldoActual: 0
    property int aPagarParaIgualar: Math.max(0, igualarActual - miApuestaActual)
    // Rango real de subida (min/max "extra" sobre aPagarParaIgualar) que
    // manda el servidor en cada TU_TURNO — antes el slider solo aproximaba
    // el máximo con el saldo, sin límite mínimo ni respetar pot-limit/fixed-limit.
    property int minSubidaActual: 0
    property int maxSubidaActual: 0
    property string miCarta1: ""
    property string miCarta2: ""
    property var cartasMesa: []
    property int manoActual: 0
    property int ciegaActual: 0
    // Reglas de la sala actual, para la sección "Mesa actual" del cajón
    // de ajustes — llegan una vez, al empezar la partida (fijas toda la
    // sesión, ver onPartidaIniciada).
    property int objetivoManos: 0
    property int tipoLimiteActual: 0
    property bool permitirRecompraActual: false
    property bool rellenarConBotsActual: false
    property bool preguntarExtensionActual: true
    property string turnoNombre: ""
    // Dealer/ciegas de la mano actual (campos "dealer"/"sb"/"bb" de
    // GAME_STATE) -- para los marcadores D/SB/BB de Mesa/Asiento.
    property string dealerNombre: ""
    property string sbNombre: ""
    property string bbNombre: ""
    property string rondaActual: ""
    // Jugadores retirados en la mano actual — el servidor no manda esto
    // como estado (GAME_STATE solo da nombre/saldo/apuesta), así que se
    // infiere del lado del cliente viendo pasar los FOLD en el historial de
    // acciones, y se vacía en cada mano nueva (INICIO_MANO).
    property var retirados: []
    property string comboActual: ""
    property string comboProbable: ""
    property string comboMaxima: ""
    property int timeoutMsActual: 30000
    property int boteActual: 0

    // ── Cuenta atrás del turno (para el anillo del avatar) ────────────────
    // El servidor ahora manda "timeout_ms" en cada turno (onTurnoIniciado),
    // no solo al humano en TU_TURNO — por eso el Timer corre para CUALQUIER
    // turno activo (turnoNombre no vacío), y Mesa aplica la fracción al
    // asiento que corresponda cada vez, no solo al propio. "inicioTurnoMs"
    // guarda cuándo empezó (Date.now(), fuera de QML puro pero JavaScript
    // normal) y este Timer recalcula la fracción restante 10 veces/segundo.
    property real inicioTurnoMs: 0
    property real fraccionTiempoRestante: 1.0
    Timer {
        interval: 100
        running: turnoNombre !== ""
        repeat: true
        onTriggered: {
            var transcurrido = Date.now() - inicioTurnoMs;
            fraccionTiempoRestante = Math.max(0, 1 - transcurrido / timeoutMsActual);
        }
    }
    // Tamaño inicial: un porcentaje generoso de la pantalla disponible
    // ("Screen" es un attached property de QtQuick.Window, disponible en
    // cualquier Item/Window; "desktopAvailableWidth/Height" ya descuenta
    // barras de tareas del sistema). Ni fijo ni "lo más grande posible" —
    // así aprovecha pantallas grandes (FHD y más) sin llegar a taparse con
    // el propio sistema operativo, y se adapta sola si la pantalla es más
    // pequeña.
    width: Screen.desktopAvailableWidth * 0.75
    height: Screen.desktopAvailableHeight * 0.85
    // Unidad de escala: 1040x780 es el tamaño "de diseño", con el que se
    // pensaron las medidas de Mesa/Carta/Asiento. "escala" da el factor por
    // el que hay que multiplicar cada tamaño para que todo crezca o encoja
    // junto según el tamaño real de la ventana, en vez de quedarse en
    // píxeles fijos que no se adaptan a la pantalla. Se usa como
    // "Tema.escala" desde los componentes aparte (Carta, Asiento...),
    // igual que "ventana.chatActive".
    readonly property real escala: Math.min(width / 1040, height / 780)
    // Por debajo de este factor, el contenido ya no cabe de forma legible
    // — mejor avisar con un mensaje que dejar botones inaccesibles o texto
    // solapado.
    readonly property real escalaMinima: 0.55
    visible: true
    title: "PokerClient (Qt Quick) — en construcción"

    Rectangle {
        anchors.fill: parent
        color: Tema.colorFondo

        // ── Riel de navegación (Salas/Ranking/Torneos/Social) ─────────────
        // Instancia única, visible solo en las 4 pantallas "hub" -- ver
        // RielNavegacion.qml. Las demás pantallas (Inicio/Login/Registro/
        // CrearSala/Lobby/Partida/Fin) no lo llevan.
        RielNavegacion {
            id: rielNavegacion
            visible: ["Salas", "Ranking", "Torneos", "Social"].indexOf(ventana.pantalla) !== -1
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            pantallaActual: ventana.pantalla
            onSeccionElegida: (nombre) => {
                ventana.pantalla = nombre;
                // Refresca cada vez que se entra -- consulta barata, y así
                // no hace falta un botón "Refrescar" aparte para esto.
                if (nombre === "Ranking") redcliente.consultarRanking(servidorHost, servidorPuerto);
            }
        }

        // ── Pantalla 1: conectar ──────────────────────────
        Column {
            visible: pantalla === "Inicio"
            anchors.centerIn: parent
            spacing: 22 * Tema.escala

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10 * Tema.escala
                Text {
                    text: "♣"
                    color: Tema.colorAccent
                    font.pixelSize: 30 * Tema.escala
                }
                Text {
                    text: "PokerRemake"
                    color: "white"
                    font.family: Tema.fuenteElegante
                    font.pixelSize: 32 * Tema.escala
                    // Mismo ajuste que en la barra superior: el trébol y el
                    // texto no comparten línea base por defecto en un Row.
                    y: 4
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "MESA PRIVADA · TEXAS HOLD'EM"
                color: Tema.colorTextoTenue
                font.pixelSize: 11 * Tema.escala
                font.letterSpacing: 2
            }
            // Indicador de conectividad: sin esto, la única señal de "no hay
            // servidor" era el error que salía DESPUÉS de intentar entrar a
            // Salas — ahora se ve de antemano, en Inicio, y los botones ni
            // siquiera dejan pasar mientras no haya servidor confirmado.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6 * Tema.escala
                Rectangle {
                    width: 8 * Tema.escala
                    height: 8 * Tema.escala
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: comprobandoConexion ? Tema.colorTextoTenue
                           : (conectadoAlServidor ? Tema.colorAccent : Tema.colorPeligro)
                }
                Text {
                    color: Tema.colorTextoTenue
                    font.pixelSize: 11 * Tema.escala
                    text: comprobandoConexion ? "Comprobando conexión…"
                          : (conectadoAlServidor ? "Conectado al servidor" : "Sin conexión con el servidor")
                }
            }
            // Ya no hay campo de nombre libre: la identidad viene de una
            // cuenta (login/registro) o de un nombre de invitado generado
            // aquí mismo, sin persistencia. Las tres deshabilitadas sin
            // servidor confirmado, mismo criterio que antes tenía el único
            // botón "Salas disponibles".
            BotonRelleno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Iniciar sesión"
                radioBorde: 999
                enabled: conectadoAlServidor
                opacity: enabled ? 1.0 : 0.5
                onClicked: {
                    mensajeErrorLogin = "";
                    pantalla = "Login";
                }
            }
            BotonContorno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Crear cuenta"
                radioBorde: 999
                enabled: conectadoAlServidor
                opacity: enabled ? 1.0 : 0.5
                onClicked: {
                    mensajeErrorLogin = "";
                    pantalla = "Registro";
                }
            }
            BotonContorno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Entrar como invitado"
                radioBorde: 999
                enabled: conectadoAlServidor
                opacity: enabled ? 1.0 : 0.5
                onClicked: {
                    // Sin persistencia -- token_ ya está vacío (nunca se
                    // llegó a fijar, o se limpió al cerrar sesión) así que
                    // conectar()/crearSala()/etc. lo mandan vacío solos.
                    nombreUsuario.text = "Invitado" + Math.floor(Math.random() * 100000);
                    pantalla = "Salas";
                    redcliente.refrescarSalas(servidorHost, servidorPuerto);
                }
            }
            BotonContorno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Salir"
                colorBorde: Tema.colorPeligro
                radioBorde: 999
                onClicked: Qt.quit()
            }
            Text {
                id: estadoTexto
                anchors.horizontalCenter: parent.horizontalCenter
                color: Tema.colorPeligro
                font.pixelSize: 11 * Tema.escala
                text: mensajeErrorConexion
            }
        }

        // ── Pantalla Login ─────────────────────────────────────────────────
        BarraSuperior {
            id: barraLogin
            visible: ventana.pantalla === "Login"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            textoCentro: "Iniciar sesión"
            pantalla: ventana.pantalla
            miSaldoActual: ventana.miSaldoActual
            reconectandoAhora: ventana.reconectandoAhora
            servidorHost: ventana.servidorHost
            servidorPuerto: ventana.servidorPuerto
            onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
        }
        Column {
            visible: pantalla === "Login"
            anchors.centerIn: parent
            spacing: 16 * Tema.escala
            width: 260 * Tema.escala

            TextField {
                id: campoUsuarioLogin
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: "white"
                font.pixelSize: 16 * Tema.escala
                placeholderText: (activeFocus || text.length > 0) ? "" : "Usuario"
                placeholderTextColor: Tema.colorTextoMuyTenue
                background: Rectangle {
                    color: "transparent"
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: campoUsuarioLogin.activeFocus ? Tema.colorAccent : Tema.colorBorde
                    }
                }
                onAccepted: campoPasswordLogin.forceActiveFocus()
            }
            TextField {
                id: campoPasswordLogin
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: "white"
                font.pixelSize: 16 * Tema.escala
                echoMode: TextInput.Password
                placeholderText: (activeFocus || text.length > 0) ? "" : "Contraseña"
                placeholderTextColor: Tema.colorTextoMuyTenue
                background: Rectangle {
                    color: "transparent"
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: campoPasswordLogin.activeFocus ? Tema.colorAccent : Tema.colorBorde
                    }
                }
                onAccepted: botonEntrarLogin.clicked()
            }
            BotonRelleno {
                id: botonEntrarLogin
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Entrar"
                radioBorde: 999
                // Siempre pulsable -- ver el comentario largo en
                // botonCrearCuenta sobre por qué un botón atenuado y mudo
                // no basta como mensaje de error.
                onClicked: {
                    if (campoUsuarioLogin.text.length === 0) {
                        mensajeErrorLogin = "Escribe tu nombre de usuario.";
                        return;
                    }
                    if (campoPasswordLogin.text.length === 0) {
                        mensajeErrorLogin = "Escribe tu contraseña.";
                        return;
                    }
                    mensajeErrorLogin = "";
                    redcliente.iniciarSesion(servidorHost, servidorPuerto,
                                             campoUsuarioLogin.text, campoPasswordLogin.text);
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "¿No tienes cuenta? Crear una"
                color: Tema.colorAccent
                font.pixelSize: 12 * Tema.escala
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        mensajeErrorLogin = "";
                        campoPasswordLogin.text = "";
                        pantalla = "Registro";
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Tema.colorPeligro
                font.pixelSize: 11 * Tema.escala
                text: mensajeErrorLogin
                visible: mensajeErrorLogin !== ""
            }
            BotonContorno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Volver"
                radioBorde: 999
                onClicked: {
                    campoPasswordLogin.text = "";
                    pantalla = "Inicio";
                }
            }
        }

        // ── Pantalla Registro ──────────────────────────────────────────────
        BarraSuperior {
            id: barraRegistro
            visible: ventana.pantalla === "Registro"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            textoCentro: "Crear cuenta"
            pantalla: ventana.pantalla
            miSaldoActual: ventana.miSaldoActual
            reconectandoAhora: ventana.reconectandoAhora
            servidorHost: ventana.servidorHost
            servidorPuerto: ventana.servidorPuerto
            onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
        }
        Column {
            visible: pantalla === "Registro"
            anchors.centerIn: parent
            spacing: 16 * Tema.escala
            width: 260 * Tema.escala

            TextField {
                id: campoUsuarioRegistro
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: "white"
                font.pixelSize: 16 * Tema.escala
                placeholderText: (activeFocus || text.length > 0) ? "" : "Usuario (mín. 3 caracteres)"
                placeholderTextColor: Tema.colorTextoMuyTenue
                background: Rectangle {
                    color: "transparent"
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: campoUsuarioRegistro.activeFocus ? Tema.colorAccent : Tema.colorBorde
                    }
                }
                onAccepted: campoPasswordRegistro.forceActiveFocus()
            }
            TextField {
                id: campoPasswordRegistro
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: "white"
                font.pixelSize: 16 * Tema.escala
                echoMode: TextInput.Password
                placeholderText: (activeFocus || text.length > 0) ? "" : "Contraseña (8+ caracteres)"
                placeholderTextColor: Tema.colorTextoMuyTenue
                background: Rectangle {
                    color: "transparent"
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: campoPasswordRegistro.activeFocus ? Tema.colorAccent : Tema.colorBorde
                    }
                }
                onAccepted: campoPasswordRegistroConfirmar.forceActiveFocus()
            }
            TextField {
                id: campoPasswordRegistroConfirmar
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: "white"
                font.pixelSize: 16 * Tema.escala
                echoMode: TextInput.Password
                placeholderText: (activeFocus || text.length > 0) ? "" : "Repite la contraseña"
                placeholderTextColor: Tema.colorTextoMuyTenue
                background: Rectangle {
                    color: "transparent"
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: campoPasswordRegistroConfirmar.activeFocus ? Tema.colorAccent : Tema.colorBorde
                    }
                }
                onAccepted: botonCrearCuenta.clicked()
            }
            BotonRelleno {
                id: botonCrearCuenta
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Crear cuenta"
                radioBorde: 999
                // Siempre pulsable a propósito -- antes, con enabled ligado
                // a los mínimos, no pasar el mínimo dejaba el botón mudo
                // (atenuado, sin más) y un fallo real de validación se veía
                // exactamente igual que "no ha pasado nada": no había forma
                // de distinguir "me equivoqué yo" de "esto está roto". Cada
                // caso ahora deja un mensaje explícito antes de intentar
                // nada contra el servidor -- las mismas reglas mínimas que
                // ya exige AccountManager (servidor, la única autoridad
                // real), repetidas aquí solo para dar el mensaje al
                // instante en vez de esperar la ida y vuelta de red.
                onClicked: {
                    if (campoUsuarioRegistro.text.length < 3) {
                        mensajeErrorLogin = "El nombre de usuario debe tener al menos 3 caracteres.";
                        return;
                    }
                    if (campoPasswordRegistro.text.length < 8) {
                        mensajeErrorLogin = "La contraseña debe tener al menos 8 caracteres.";
                        return;
                    }
                    if (campoPasswordRegistro.text !== campoPasswordRegistroConfirmar.text) {
                        mensajeErrorLogin = "Las contraseñas no coinciden.";
                        return;
                    }
                    mensajeErrorLogin = "";
                    redcliente.registrar(servidorHost, servidorPuerto,
                                         campoUsuarioRegistro.text, campoPasswordRegistro.text);
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "¿Ya tienes cuenta? Iniciar sesión"
                color: Tema.colorAccent
                font.pixelSize: 12 * Tema.escala
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        mensajeErrorLogin = "";
                        pantalla = "Login";
                    }
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Tema.colorPeligro
                font.pixelSize: 11 * Tema.escala
                text: mensajeErrorLogin
                visible: mensajeErrorLogin !== ""
            }
            BotonContorno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Volver"
                radioBorde: 999
                onClicked: {
                    campoPasswordRegistro.text = "";
                    campoPasswordRegistroConfirmar.text = "";
                    pantalla = "Inicio";
                }
            }
        }

        // ── Pantalla Salas: lista de salas públicas disponibles ───────────
        BarraSuperior {
            // BUG real encontrado en vivo (capturas de pantalla): con
            // "pragma ComponentBehavior: Bound" activo (arriba del
            // fichero), la referencia suelta "pantalla" aquí se resuelve
            // contra la propiedad PROPIA de BarraSuperior (required
            // property string pantalla, fijada más abajo con
            // "pantalla: pantalla") en vez de la de esta ventana --
            // autorreferencia bajo scope estricto, da undefined, así que
            // "visible" nunca era true y la barra entera desaparecía en
            // "Salas"/"CrearSala"/"Lobby". "Fin"/"Partida" no lo sufrían
            // porque ahí el "visible" vive en el Item envolvente, no en el
            // propio BarraSuperior. Cualificar contra "ventana" (id de la
            // ApplicationWindow raíz) rompe la ambigüedad.
            visible: ventana.pantalla === "Salas"
            anchors.top: parent.top
            anchors.left: rielNavegacion.right
            anchors.right: parent.right
            textoCentro: "Salas disponibles"
            pantalla: ventana.pantalla
            miSaldoActual: ventana.miSaldoActual
            reconectandoAhora: ventana.reconectandoAhora
            servidorHost: ventana.servidorHost
            servidorPuerto: ventana.servidorPuerto
            onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
        }
        Column {
            visible: pantalla === "Salas"
            anchors.horizontalCenter: parent.horizontalCenter
            // El riel de navegación le come 76px de ancho por la
            // izquierda -- sin este desplazamiento, "centrado en parent"
            // quedaría descentrado respecto al hueco real disponible
            // (parent entero menos el riel), corrido hacia la izquierda.
            anchors.horizontalCenterOffset: rielNavegacion.width / 2
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 25 * Tema.escala
            spacing: 16 * Tema.escala
            // Antes 420 — con archivo + fecha + 3 botones en cada fila de
            // guardadas, se quedaba corta y el texto se solapaba con los
            // botones. Más ancha, y con tope según el ancho de ventana
            // (mismo patrón que CrearSala) para pantallas pequeñas.
            width: Math.min(680 * Tema.escala, ventana.width - 60 * Tema.escala)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: viendoGuardadas ? "Partidas guardadas" : "Salas disponibles"
                color: "white"
                font.family: Tema.fuenteElegante
                font.pixelSize: 22 * Tema.escala
            }

            // Mismo patrón de pestañas que Historial/Chat en PanelLateral.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8 * Tema.escala
                Rectangle {
                    width: textoTabSalasPub.implicitWidth + 24 * Tema.escala
                    height: 30 * Tema.escala
                    radius: height / 2
                    color: !viendoGuardadas ? Tema.colorAccent : "transparent"
                    Text {
                        id: textoTabSalasPub
                        anchors.centerIn: parent
                        text: "Salas públicas"
                        color: !viendoGuardadas ? Tema.colorPanel : Tema.colorTextoTenue
                        font.bold: !viendoGuardadas
                        font.pixelSize: 13 * Tema.escala
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: viendoGuardadas = false
                    }
                }
                Rectangle {
                    width: textoTabGuardadas.implicitWidth + 24 * Tema.escala
                    height: 30 * Tema.escala
                    radius: height / 2
                    color: viendoGuardadas ? Tema.colorAccent : "transparent"
                    Text {
                        id: textoTabGuardadas
                        anchors.centerIn: parent
                        text: "Partidas guardadas"
                        color: viendoGuardadas ? Tema.colorPanel : Tema.colorTextoTenue
                        font.bold: viendoGuardadas
                        font.pixelSize: 13 * Tema.escala
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            viendoGuardadas = true;
                            redcliente.listarGuardadas(servidorHost, servidorPuerto);
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 340 * Tema.escala
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.3)
                radius: 8 * Tema.escala
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                    GradientStop { position: 1.0; color: Tema.colorPanel }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    visible: !viendoGuardadas && listaSalas.count === 0
                    text: "No hay salas públicas disponibles ahora mismo."
                    color: Tema.colorTextoTenue
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13 * Tema.escala
                }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    visible: viendoGuardadas && listaGuardadas.count === 0
                    text: "No hay partidas guardadas en el servidor."
                    color: Tema.colorTextoTenue
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13 * Tema.escala
                }

                ListView {
                    id: listaSalas
                    visible: !viendoGuardadas
                    anchors.fill: parent
                    anchors.margins: 10 * Tema.escala
                    clip: true
                    spacing: 8 * Tema.escala
                    model: salasDisponibles
                    delegate: Rectangle {
                        id: filaSala
                        required property string id
                        required property string nombre
                        required property int conectados
                        required property int esperados
                        width: ListView.view.width
                        height: 44 * Tema.escala
                        radius: 6 * Tema.escala
                        color: Tema.colorFondo
                        border.width: 1
                        border.color: Tema.colorBorde

                        Column {
                            anchors.left: parent.left
                            anchors.right: botonUnirse.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10 * Tema.escala
                            anchors.rightMargin: 10 * Tema.escala
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: filaSala.nombre !== "" ? filaSala.nombre : filaSala.id
                                color: "white"
                                font.pixelSize: 13 * Tema.escala
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: filaSala.conectados + " / " + filaSala.esperados + " jugadores"
                                color: Tema.colorTextoTenue
                                font.pixelSize: 11 * Tema.escala
                            }
                        }
                        BotonRelleno {
                            id: botonUnirse
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 10 * Tema.escala
                            text: "Unirse"
                            onClicked: {
                                creadorDeLaSala = false;
                                redcliente.unirseASala(servidorHost, servidorPuerto, nombreUsuario.text, filaSala.id, "");
                            }
                        }
                    }
                }

                ListView {
                    id: listaGuardadas
                    visible: viendoGuardadas
                    anchors.fill: parent
                    anchors.margins: 10 * Tema.escala
                    clip: true
                    spacing: 8 * Tema.escala
                    model: guardadasDisponibles
                    delegate: Rectangle {
                        id: filaGuardada
                        required property string archivo
                        required property string fecha
                        required property int humanos
                        required property int bots
                        property bool renombrando: false
                        property bool confirmandoBorrado: false
                        width: ListView.view.width
                        height: 44 * Tema.escala
                        radius: 6 * Tema.escala
                        color: Tema.colorFondo
                        border.width: 1
                        border.color: Tema.colorBorde

                        Column {
                            visible: !filaGuardada.renombrando
                            anchors.left: parent.left
                            anchors.right: filaAcciones.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10 * Tema.escala
                            anchors.rightMargin: 10 * Tema.escala
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: filaGuardada.archivo
                                color: "white"
                                font.pixelSize: 13 * Tema.escala
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: filaGuardada.fecha + " · " + filaGuardada.humanos +
                                      " humano(s), " + filaGuardada.bots + " bot(s)"
                                color: Tema.colorTextoTenue
                                font.pixelSize: 11 * Tema.escala
                            }
                        }

                        // Modo renombrar: sustituye la columna de arriba por
                        // un campo de texto + confirmar, en vez de una
                        // pantalla/diálogo aparte.
                        Row {
                            visible: filaGuardada.renombrando
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10 * Tema.escala
                            spacing: 6 * Tema.escala
                            TextField {
                                id: campoRenombrar
                                anchors.verticalCenter: parent.verticalCenter
                                width: 160 * Tema.escala
                                text: filaGuardada.archivo.replace(/\.pok$/, "")
                                color: "white"
                                font.pixelSize: 13 * Tema.escala
                                background: Rectangle {
                                    color: Tema.colorPanel
                                    radius: 6 * Tema.escala
                                    border.width: 1
                                    border.color: Tema.colorAccent
                                }
                                Keys.onReturnPressed: {
                                    redcliente.renombrarGuardada(servidorHost, servidorPuerto,
                                                                 filaGuardada.archivo, text);
                                    filaGuardada.renombrando = false;
                                }
                            }
                            BotonContorno {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "OK"
                                onClicked: {
                                    redcliente.renombrarGuardada(servidorHost, servidorPuerto,
                                                                 filaGuardada.archivo, campoRenombrar.text);
                                    filaGuardada.renombrando = false;
                                }
                            }
                        }

                        Row {
                            id: filaAcciones
                            visible: !filaGuardada.renombrando
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 10 * Tema.escala
                            spacing: 6 * Tema.escala
                            BotonRelleno {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Reanudar"
                                onClicked: {
                                    creadorDeLaSala = true;
                                    redcliente.cargarPartidaGuardada(
                                        servidorHost, servidorPuerto, nombreUsuario.text,
                                        filaGuardada.archivo, filaGuardada.archivo, true);
                                }
                            }
                            BotonContorno {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "✎"
                                onClicked: filaGuardada.renombrando = true
                            }
                            BotonContorno {
                                anchors.verticalCenter: parent.verticalCenter
                                text: filaGuardada.confirmandoBorrado ? "¿Seguro?" : "🗑"
                                colorBorde: Tema.colorPeligro
                                onClicked: {
                                    if (filaGuardada.confirmandoBorrado) {
                                        redcliente.borrarGuardada(servidorHost, servidorPuerto,
                                                                  filaGuardada.archivo);
                                    } else {
                                        filaGuardada.confirmandoBorrado = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8 * Tema.escala
                BotonContorno {
                    text: "Refrescar"
                    onClicked: viendoGuardadas ? redcliente.listarGuardadas(servidorHost, servidorPuerto)
                                                : redcliente.refrescarSalas(servidorHost, servidorPuerto)
                }
                BotonRelleno {
                    visible: !viendoGuardadas
                    text: "Crear sala nueva"
                    onClicked: pantalla = "CrearSala"
                }
            }

            Row {
                visible: !viendoGuardadas
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8 * Tema.escala
                // Row no centra verticalmente hijos de distinta altura por
                // defecto (el TextField y el botón no miden lo mismo) — se
                // centra cada uno a mano, mismo motivo que en los campos de
                // chat.
                TextField {
                    id: campoCodigoUnion
                    anchors.verticalCenter: parent.verticalCenter
                    width: 160 * Tema.escala
                    placeholderText: (activeFocus || text.length > 0) ? "" : "Código de sala privada"
                    color: "white"
                    font.pixelSize: 13 * Tema.escala
                    placeholderTextColor: Tema.colorTextoMuyTenue
                    // Mismo campo "subrayado" sin caja que Login/Registro/el
                    // viejo nombreUsuario -- antes tenía fondo propio y
                    // borde redondeado en las cuatro esquinas, el único
                    // campo de todo el programa con ese estilo distinto.
                    background: Rectangle {
                        color: "transparent"
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: campoCodigoUnion.activeFocus ? Tema.colorAccent : Tema.colorBorde
                        }
                    }
                    // Igual que en Inicio: Enter hace lo mismo que pulsar
                    // el botón de al lado, sin tener que ir hasta él con Tab.
                    onAccepted: botonUnirsePorCodigo.clicked()
                }
                BotonContorno {
                    id: botonUnirsePorCodigo
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Unirse por código"
                    onClicked: {
                        creadorDeLaSala = false;
                        redcliente.unirseASala(servidorHost, servidorPuerto, nombreUsuario.text, "", campoCodigoUnion.text);
                    }
                }
            }

            Text {
                id: estadoTextoSalas
                anchors.horizontalCenter: parent.horizontalCenter
                color: Tema.colorPeligro
                font.pixelSize: 11 * Tema.escala
                text: mensajeErrorConexion
            }

            BotonContorno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Salir"
                colorBorde: Tema.colorPeligro
                onClicked: pantalla = "Inicio"
            }
        }

        // ── Pantallas hub sin backend todavía: Ranking/Torneos/Social ─────
        // ── Pantalla Ranking: ranking global de verdad (ver AccountManager::
        // obtenerRanking() -- solo cuentas con ≥10 partidas jugadas, para
        // que una partida suelta no dispare a nadie al primer puesto).
        // Torneos/Social sí siguen siendo placeholder -- ver más abajo.
        BarraSuperior {
            id: barraRanking
            visible: ventana.pantalla === "Ranking"
            anchors.top: parent.top
            anchors.left: rielNavegacion.right
            anchors.right: parent.right
            textoCentro: "Ranking global"
            pantalla: ventana.pantalla
            miSaldoActual: ventana.miSaldoActual
            reconectandoAhora: ventana.reconectandoAhora
            servidorHost: ventana.servidorHost
            servidorPuerto: ventana.servidorPuerto
            onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
        }
        Column {
            visible: pantalla === "Ranking"
            anchors.top: barraRanking.bottom
            anchors.topMargin: 24 * Tema.escala
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: rielNavegacion.width / 2
            spacing: 10 * Tema.escala
            width: Math.min(680 * Tema.escala, ventana.width - rielNavegacion.width - 60 * Tema.escala)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Ranking global"
                color: "white"
                font.family: Tema.fuenteElegante
                font.pixelSize: 22 * Tema.escala
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Cuentas con al menos 10 partidas jugadas · ordenado por " +
                      (ordenRankingActual === 0 ? "victorias" : "ratio")
                color: Tema.colorTextoMuyTenue
                font.pixelSize: 11 * Tema.escala
            }
            SelectorPildoras {
                id: tabsRanking
                anchors.horizontalCenter: parent.horizontalCenter
                opciones: ["Más victorias", "Mejor ratio"]
                seleccionado: ordenRankingActual
                onSeleccionadoChanged: {
                    ordenRankingActual = seleccionado;
                    reordenarRanking();
                }
            }

            Rectangle {
                width: parent.width
                height: 380 * Tema.escala
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.3)
                radius: 8 * Tema.escala
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                    GradientStop { position: 1.0; color: Tema.colorPanel }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    visible: rankingModel.count === 0
                    text: "Todavía no hay cuentas con partidas suficientes para aparecer en el ranking."
                    color: Tema.colorTextoTenue
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13 * Tema.escala
                }

                ListView {
                    visible: rankingModel.count > 0
                    anchors.fill: parent
                    anchors.margins: 14 * Tema.escala
                    clip: true
                    spacing: 6 * Tema.escala
                    model: rankingModel
                    header: Row {
                        width: parent ? parent.width : 0
                        height: 24 * Tema.escala
                        Text {
                            width: 34 * Tema.escala
                            text: "#"
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 10 * Tema.escala
                        }
                        Text {
                            width: parent.width - 34 * Tema.escala - 220 * Tema.escala
                            text: "JUGADOR"
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 10 * Tema.escala
                        }
                        Text {
                            width: 110 * Tema.escala
                            horizontalAlignment: Text.AlignRight
                            text: "GANADAS"
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 10 * Tema.escala
                        }
                        Text {
                            width: 110 * Tema.escala
                            horizontalAlignment: Text.AlignRight
                            text: "RATIO"
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 10 * Tema.escala
                        }
                    }
                    delegate: Rectangle {
                        id: filaRanking
                        required property string username
                        required property int partidasJugadas
                        required property int partidasGanadas
                        required property int index
                        readonly property bool esUsuarioPropio:
                            username.toLowerCase() === nombreUsuario.text.toLowerCase()
                        width: ListView.view.width
                        height: 46 * Tema.escala
                        radius: 8 * Tema.escala
                        color: esUsuarioPropio ? Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.1) : Tema.colorFondo
                        border.width: esUsuarioPropio ? 1.5 : 1
                        border.color: esUsuarioPropio ? Tema.colorAccent : Qt.rgba(0, 0, 0, 0.3)

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12 * Tema.escala
                            anchors.rightMargin: 12 * Tema.escala
                            Text {
                                width: 34 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: (filaRanking.index + 1) + ""
                                font.family: Tema.fuenteElegante
                                color: filaRanking.index < 3 ? Tema.colorAccent : Tema.colorTextoTenue
                                font.pixelSize: 15 * Tema.escala
                            }
                            Row {
                                width: filaRanking.width - 34 * Tema.escala - 220 * Tema.escala - 24 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10 * Tema.escala
                                Rectangle {
                                    width: 28 * Tema.escala
                                    height: 28 * Tema.escala
                                    radius: width / 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Tema.colorPanel
                                    border.width: 1
                                    border.color: filaRanking.esUsuarioPropio ? Tema.colorAccent : Qt.rgba(1, 1, 1, 0.18)
                                    Text {
                                        anchors.centerIn: parent
                                        text: filaRanking.username.length > 0 ? filaRanking.username.charAt(0).toUpperCase() : "?"
                                        font.family: Tema.fuenteElegante
                                        color: filaRanking.esUsuarioPropio ? Tema.colorAccent : "white"
                                        font.pixelSize: 13 * Tema.escala
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: filaRanking.username + (filaRanking.esUsuarioPropio ? " (tú)" : "")
                                    font.bold: filaRanking.esUsuarioPropio
                                    color: "white"
                                    elide: Text.ElideRight
                                    font.pixelSize: 13 * Tema.escala
                                }
                            }
                            Text {
                                width: 110 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                text: filaRanking.partidasGanadas + ""
                                color: "white"
                                font.pixelSize: 13 * Tema.escala
                            }
                            Text {
                                width: 110 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(100 * filaRanking.partidasGanadas / filaRanking.partidasJugadas) + "%"
                                color: Tema.colorTextoTenue
                                font.pixelSize: 13 * Tema.escala
                            }
                        }
                    }
                }
            }
        }

        // Torneos/Social: comparten estructura (BarraSuperior + Proximamente)
        // -- ver RielNavegacion.qml y Proximamente.qml para el porqué de no
        // construir cada una a medias con datos de ejemplo.
        BarraSuperior {
            id: barraTorneos
            visible: ventana.pantalla === "Torneos"
            anchors.top: parent.top
            anchors.left: rielNavegacion.right
            anchors.right: parent.right
            textoCentro: "Torneos"
            pantalla: ventana.pantalla
            miSaldoActual: ventana.miSaldoActual
            reconectandoAhora: ventana.reconectandoAhora
            servidorHost: ventana.servidorHost
            servidorPuerto: ventana.servidorPuerto
            onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
        }
        Proximamente {
            visible: pantalla === "Torneos"
            anchors.top: barraTorneos.bottom
            anchors.left: rielNavegacion.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            titulo: "Torneos"
            descripcion: "Organiza partidas por eliminatorias para un grupo fijo de jugadores -- como crear una sala, pero con llave de torneo."
        }

        BarraSuperior {
            id: barraSocial
            visible: ventana.pantalla === "Social"
            anchors.top: parent.top
            anchors.left: rielNavegacion.right
            anchors.right: parent.right
            textoCentro: "Social"
            pantalla: ventana.pantalla
            miSaldoActual: ventana.miSaldoActual
            reconectandoAhora: ventana.reconectandoAhora
            servidorHost: ventana.servidorHost
            servidorPuerto: ventana.servidorPuerto
            onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
        }
        Proximamente {
            visible: pantalla === "Social"
            anchors.top: barraSocial.bottom
            anchors.left: rielNavegacion.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            titulo: "Social"
            descripcion: "Añade amigos y ve quién está conectado antes de crear una sala."
        }

        // ── Pantalla CrearSala: formulario de nueva sala ──────────────────
        // Mismos campos que menuNuevaPartida() en el servidor ncurses
        // (server/main.cpp) — un formulario, no una fila de prompts, pero
        // exactamente las mismas opciones y los mismos valores por defecto.
        //
        // El título y los botones quedan FIJOS (fuera del scroll); solo los
        // campos del medio se desplazan — así "Crear sala"/"Cancelar" están
        // siempre a la vista sin importar cuántos campos haya ni lo pequeña
        // que sea la ventana.
        BarraSuperior {
            id: barraCrearSala
            // Mismo bug que en "Salas" -- ver comentario ahí.
            visible: ventana.pantalla === "CrearSala"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            textoCentro: "Crear sala"
            pantalla: ventana.pantalla
            miSaldoActual: ventana.miSaldoActual
            reconectandoAhora: ventana.reconectandoAhora
            servidorHost: ventana.servidorHost
            servidorPuerto: ventana.servidorPuerto
            onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
        }
        Column {
            visible: pantalla === "CrearSala"
            anchors.top: barraCrearSala.bottom
            anchors.topMargin: 24 * Tema.escala
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 30 * Tema.escala
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16 * Tema.escala
            // Más ancha que antes (era 700) — las filas con interruptor +
            // etiqueta larga ("Permitir recompra al quedarse sin fichas")
            // iban muy justas de espacio.
            width: Math.min(820 * Tema.escala, ventana.width - 60 * Tema.escala)

            Text {
                id: tituloCrearSala
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Crear sala"
                color: "white"
                font.family: Tema.fuenteElegante
                font.pixelSize: 22 * Tema.escala
            }

            Rectangle {
                width: parent.width
                // Ocupa todo el hueco vertical que sobra entre el título y
                // los botones/mensaje de error de abajo — nunca más de eso,
                // para que los botones no se salgan de la ventana.
                height: parent.height - tituloCrearSala.height - filaBotonesCrearSala.height -
                        textoErrorCrearSala.height - parent.spacing * 3
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.3)
                radius: 8 * Tema.escala
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                    GradientStop { position: 1.0; color: Tema.colorPanel }
                }

                ScrollView {
                    id: scrollCrearSala
                    anchors.fill: parent
                    anchors.margins: 18 * Tema.escala
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    Column {
                        width: scrollCrearSala.availableWidth
                        spacing: 14 * Tema.escala

                        // Antes era una lista plana de filas — con tantas
                        // opciones, agruparlas por tema (igual que las
                        // secciones de menuNuevaPartida() en el servidor
                        // ncurses: JUGADORES / REGLAS DE APUESTA / PARTIDA)
                        // ayuda a leerlo de un vistazo.
                        Column {
                            width: parent.width
                            spacing: 6 * Tema.escala
                            Text {
                                text: "SALA"
                                color: Tema.colorTextoMuyTenue
                                font.pixelSize: 11 * Tema.escala
                                font.letterSpacing: 1
                            }
                            Rectangle { width: parent.width; height: 1; color: Tema.colorBorde }
                        }

                        TextField {
                            id: campoNombreSala
                            width: parent.width
                            placeholderText: (activeFocus || text.length > 0) ? "" : "Nombre de la sala"
                            color: "white"
                            font.pixelSize: 13 * Tema.escala
                            placeholderTextColor: Tema.colorTextoMuyTenue
                            background: Rectangle {
                                color: Tema.colorFondo
                                radius: 6 * Tema.escala
                                border.width: 1
                                border.color: campoNombreSala.activeFocus ? Tema.colorAccent : Tema.colorBorde
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 12 * Tema.escala
                            Text {
                                width: 330 * Tema.escala
                                font.pixelSize: 13 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Sala pública"
                                color: Tema.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            Interruptor {
                                id: interruptorPublica
                                activo: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12 * Tema.escala
                            Text {
                                width: 330 * Tema.escala
                                font.pixelSize: 13 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Tamaño de sala (asientos totales, máx. 9)"
                                color: Tema.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            TextField {
                                id: campoTamanoSala
                                width: 60 * Tema.escala
                                text: "6"
                                color: "white"
                                font.pixelSize: 13 * Tema.escala
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 2; top: 9 }
                                background: Rectangle {
                                    color: Tema.colorPanel
                                    radius: 6 * Tema.escala
                                    border.width: 1
                                    border.color: campoTamanoSala.activeFocus ? Tema.colorAccent : Tema.colorBorde
                                }
                            }
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12 * Tema.escala
                            Text {
                                width: 330 * Tema.escala
                                font.pixelSize: 13 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Rellenar con bots los asientos vacíos"
                                color: Tema.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            Interruptor {
                                id: interruptorRellenar
                                activo: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Text {
                            width: parent.width
                            text: "Si faltan humanos al arrancar (o alguien se va con fichas), un bot ocupa el asiento en vez de perderlo o repartir sus fichas."
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 10 * Tema.escala
                            wrapMode: Text.WordWrap
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12 * Tema.escala
                            Text {
                                width: 330 * Tema.escala
                                font.pixelSize: 13 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Abierta tras iniciar"
                                color: Tema.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            Interruptor {
                                id: interruptorAbierta
                                activo: false
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Text {
                            width: parent.width
                            text: "Con esto activo, cualquier asiento ocupado por un bot se puede sustituir por un jugador nuevo en cualquier momento de la partida."
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 10 * Tema.escala
                            wrapMode: Text.WordWrap
                        }
            
                        Column {
                            width: parent.width
                            spacing: 6 * Tema.escala
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
                            spacing: 12 * Tema.escala
                            Text {
                                width: 330 * Tema.escala
                                font.pixelSize: 13 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Dificultad de bots"
                                color: Tema.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            SelectorPildoras {
                                id: selectorDificultad
                                opciones: ["Fácil", "Normal", "Experto"]
                                seleccionado: 0
                            }
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12 * Tema.escala
                            Text {
                                width: 330 * Tema.escala
                                font.pixelSize: 13 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Tipo de límite"
                                color: Tema.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            SelectorPildoras {
                                id: selectorLimite
                                opciones: ["Sin límite", "Límite bote", "Límite fijo"]
                                seleccionado: 0
                            }
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12 * Tema.escala
                            visible: selectorLimite.seleccionado === 2
                            Text {
                                width: 330 * Tema.escala
                                font.pixelSize: 13 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Cantidad fija por raise"
                                color: Tema.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            TextField {
                                id: campoMonteFijo
                                width: 80 * Tema.escala
                                text: "40"
                                color: "white"
                                font.pixelSize: 13 * Tema.escala
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 1; top: 10000 }
                                background: Rectangle {
                                    color: Tema.colorPanel
                                    radius: 6 * Tema.escala
                                    border.width: 1
                                    border.color: campoMonteFijo.activeFocus ? Tema.colorAccent : Tema.colorBorde
                                }
                            }
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12 * Tema.escala
                            Text {
                                width: 330 * Tema.escala
                                font.pixelSize: 13 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Min-raise obligatorio"
                                color: Tema.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            Interruptor {
                                id: interruptorMinRaise
                                activo: false
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12 * Tema.escala
                            Text {
                                width: 330 * Tema.escala
                                font.pixelSize: 13 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Permitir recompra al quedarse sin fichas"
                                color: Tema.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            Interruptor {
                                id: interruptorRecompra
                                activo: false
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
            
                        Column {
                            width: parent.width
                            spacing: 6 * Tema.escala
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
                            spacing: 12 * Tema.escala
                            Text {
                                width: 330 * Tema.escala
                                font.pixelSize: 13 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Número de manos"
                                color: Tema.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            TextField {
                                id: campoNumManos
                                width: 80 * Tema.escala
                                text: "20"
                                color: "white"
                                font.pixelSize: 13 * Tema.escala
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 1; top: 200 }
                                background: Rectangle {
                                    color: Tema.colorPanel
                                    radius: 6 * Tema.escala
                                    border.width: 1
                                    border.color: campoNumManos.activeFocus ? Tema.colorAccent : Tema.colorBorde
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 12 * Tema.escala
                            Text {
                                width: 330 * Tema.escala
                                font.pixelSize: 13 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Preguntar si extender al llegar al límite de manos"
                                color: Tema.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            Interruptor {
                                id: interruptorPreguntarExtension
                                activo: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 12 * Tema.escala
                            Text {
                                width: 330 * Tema.escala
                                font.pixelSize: 13 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Ciega grande"
                                color: Tema.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            TextField {
                                id: campoCiegaGrande
                                width: 80 * Tema.escala
                                text: "20"
                                color: "white"
                                font.pixelSize: 13 * Tema.escala
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 2; top: 1000 }
                                background: Rectangle {
                                    color: Tema.colorPanel
                                    radius: 6 * Tema.escala
                                    border.width: 1
                                    border.color: campoCiegaGrande.activeFocus ? Tema.colorAccent : Tema.colorBorde
                                }
                            }
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12 * Tema.escala
                            Text {
                                width: 330 * Tema.escala
                                font.pixelSize: 13 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Saldo inicial"
                                color: Tema.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            TextField {
                                id: campoSaldoInicial
                                width: 80 * Tema.escala
                                text: "1000"
                                color: "white"
                                font.pixelSize: 13 * Tema.escala
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 100; top: 100000 }
                                background: Rectangle {
                                    color: Tema.colorPanel
                                    radius: 6 * Tema.escala
                                    border.width: 1
                                    border.color: campoSaldoInicial.activeFocus ? Tema.colorAccent : Tema.colorBorde
                                }
                            }
                        }
                    }
                    // fin de la Column interior del ScrollView
                }
                // fin del ScrollView
            }
            // fin del Rectangle-tarjeta

            Text {
                id: textoErrorCrearSala
                anchors.horizontalCenter: parent.horizontalCenter
                color: Tema.colorPeligro
                font.pixelSize: 11 * Tema.escala
                text: mensajeErrorConexion
            }

            Row {
                id: filaBotonesCrearSala
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10 * Tema.escala
                BotonContorno {
                    text: "Cancelar"
                    colorBorde: Tema.colorPeligro
                    onClicked: pantalla = "Salas"
                }
                BotonRelleno {
                    text: "Crear sala"
                    onClicked: {
                        creadorDeLaSala = true;
                        redcliente.crearSala(
                            servidorHost, servidorPuerto, nombreUsuario.text,
                            campoNombreSala.text,
                            interruptorPublica.activo,
                            parseInt(campoTamanoSala.text) || 6,
                            parseInt(campoNumManos.text) || 20,
                            parseInt(campoCiegaGrande.text) || 20,
                            parseInt(campoSaldoInicial.text) || 1000,
                            selectorLimite.seleccionado,
                            interruptorMinRaise.activo,
                            parseInt(campoMonteFijo.text) || 40,
                            selectorDificultad.seleccionado,
                            interruptorRecompra.activo,
                            interruptorRellenar.activo,
                            interruptorAbierta.activo,
                            interruptorPreguntarExtension.activo
                        );
                    }
                }
            }
        }

        // ── Pantalla Fin: resultado de la partida ─────────────────────
        // Antes era texto suelto flotando en medio de la pantalla — ahora
        // una tarjeta como el resto de paneles (mismo lenguaje que el
        // showdown/entre-manos), con el ganador como protagonista.
        Item {
            visible: pantalla === "Fin"
            anchors.fill: parent

            BarraSuperior {
                id: barraFin
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                pantalla: ventana.pantalla
                miSaldoActual: ventana.miSaldoActual
                reconectandoAhora: ventana.reconectandoAhora
                servidorHost: ventana.servidorHost
                servidorPuerto: ventana.servidorPuerto
                onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 25 * Tema.escala
                width: contenidoFin.width + 64 * Tema.escala
                height: contenidoFin.height + 48 * Tema.escala
                border.width: 1
                border.color: Tema.colorAccent
                radius: 16 * Tema.escala
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                    GradientStop { position: 1.0; color: Tema.colorPanel }
                }

                Column {
                    id: contenidoFin
                    anchors.centerIn: parent
                    width: 300 * Tema.escala
                    spacing: 14 * Tema.escala

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: partidaGuardada ? "PARTIDA GUARDADA" : "PARTIDA FINALIZADA"
                        color: Tema.colorAccent
                        font.letterSpacing: 2
                        font.pixelSize: 12 * Tema.escala
                        font.bold: true
                    }
                    Text {
                        visible: !partidaGuardada
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Ganador"
                        color: Tema.colorTextoTenue
                        font.pixelSize: 11 * Tema.escala
                    }
                    Text {
                        visible: !partidaGuardada
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ganadorFinal
                        color: "white"
                        font.family: Tema.fuenteElegante
                        font.pixelSize: 26 * Tema.escala
                        font.bold: true
                    }
                    Text {
                        visible: !partidaGuardada
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: saldoFinal + " fichas"
                        color: Tema.colorAccent
                        font.pixelSize: 15 * Tema.escala
                    }
                    Text {
                        visible: !partidaGuardada
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: finPorLimite ? "Se alcanzó el límite de manos." : "El resto de jugadores ha quedado eliminado."
                        color: Tema.colorTextoTenue
                        font.pixelSize: 12 * Tema.escala
                    }

                    // ── Estadísticas de la partida ────────────────────
                    // El motor ya las calculaba (Partida::generarEstadisticas(),
                    // el mismo dato que ncurses guarda en su historial) pero
                    // nunca llegaban al cliente Qt en el momento de terminar.
                    Rectangle {
                        visible: !partidaGuardada
                        width: parent.width
                        height: 1
                        color: Tema.colorBorde
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !partidaGuardada
                        text: "Manos disputadas: " + manosDisputadasFinal
                        color: Tema.colorTextoTenue
                        font.pixelSize: 12 * Tema.escala
                    }
                    Column {
                        visible: !partidaGuardada && mejorManoFinal !== ""
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 1 * Tema.escala
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "MEJOR MANO DE LA PARTIDA"
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 9 * Tema.escala
                            font.letterSpacing: 1
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: mejorManoFinal + " — " + mejorManoJugadorFinal
                            color: Tema.colorAccent
                            font.bold: true
                            font.family: Tema.fuenteElegante
                            font.pixelSize: 14 * Tema.escala
                        }
                    }
                    Column {
                        visible: !partidaGuardada && eliminacionesFinal.length > 0
                        width: parent.width
                        spacing: 3 * Tema.escala
                        Repeater {
                            model: eliminacionesFinal
                            delegate: Row {
                                required property var modelData
                                width: parent.width
                                Text {
                                    width: parent.width - textoManoEliminacion.width
                                    text: modelData.nombre
                                    color: modelData.nombre === ganadorFinal ? Tema.colorAccent : "white"
                                    font.bold: modelData.nombre === ganadorFinal
                                    font.pixelSize: 11 * Tema.escala
                                    elide: Text.ElideRight
                                }
                                Text {
                                    id: textoManoEliminacion
                                    text: modelData.mano === "X" ? "Sigue en juego" : "Mano " + modelData.mano
                                    color: Tema.colorTextoTenue
                                    font.pixelSize: 11 * Tema.escala
                                }
                            }
                        }
                    }

                    Text {
                        visible: partidaGuardada
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
                            codigoSalaPropia = "";
                            pantalla = "Salas";
                            redcliente.refrescarSalas(servidorHost, servidorPuerto);
                        }
                    }
                }
            }
        }

        // ── Pantalla 2: sala de espera ─────────────────────────────────
        BarraSuperior {
            id: barraLobby
            // Mismo bug que en "Salas" -- ver comentario ahí.
            visible: ventana.pantalla === "Lobby"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            textoCentro: hostActual !== "" ? "Sala de " + hostActual : ""
            pantalla: ventana.pantalla
            miSaldoActual: ventana.miSaldoActual
            reconectandoAhora: ventana.reconectandoAhora
            servidorHost: ventana.servidorHost
            servidorPuerto: ventana.servidorPuerto
            onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
        }

        // Item, no Row: mismo motivo que en la mesa — un Row no centra
        // verticalmente hijos de distinta altura, así que cada bloque se
        // centra por su cuenta con su propio "anchors.verticalCenter".
        Item {
            visible: pantalla === "Lobby"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 25 * Tema.escala
            width: columnaSala.width + 40 + chatLobby.width
            height: Math.max(columnaSala.height, chatLobby.height)

            Column {
                id: columnaSala
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 22 * Tema.escala

                Column {
                    spacing: 2 * Tema.escala
                    Text {
                        text: "Sala de " + (hostActual !== "" ? hostActual : "espera")
                        color: "white"
                        font.family: Tema.fuenteElegante
                        font.pixelSize: 22 * Tema.escala
                        font.bold: true
                    }
                    Text {
                        id: contadorListos
                        color: Tema.colorTextoTenue
                        font.pixelSize: 12 * Tema.escala
                    }
                    Row {
                        visible: codigoSalaPropia !== ""
                        spacing: 8 * Tema.escala
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Código para invitar: " + codigoSalaPropia
                            color: Tema.colorAccent
                            font.pixelSize: 12 * Tema.escala
                            font.bold: true
                        }
                        BotonContorno {
                            id: botonCopiarCodigo
                            property bool copiado: false
                            anchors.verticalCenter: parent.verticalCenter
                            text: copiado ? "Copiado" : "Copiar"
                            onClicked: {
                                // Sin API de portapapeles en QML puro — el
                                // truco establecido es un TextEdit oculto:
                                // seleccionar todo y copiar hace lo mismo
                                // que Ctrl+C en cualquier campo de texto.
                                portapapelesCodigoSala.text = codigoSalaPropia;
                                portapapelesCodigoSala.selectAll();
                                portapapelesCodigoSala.copy();
                                copiado = true;
                                temporizadorCopiado.restart();
                            }
                            Timer {
                                id: temporizadorCopiado
                                interval: 1500
                                onTriggered: botonCopiarCodigo.copiado = false
                            }
                        }
                        TextEdit {
                            id: portapapelesCodigoSala
                            visible: false
                        }
                    }
                    Text {
                        // Solo relevante si esta sala viene de reanudar una
                        // partida guardada (CARGAR_PARTIDA) — para que quien
                        // se una sepa con qué nombre entrar aunque no lo
                        // recuerde.
                        visible: nombresEsperadosLobby !== ""
                        text: "Nombres esperados: " + nombresEsperadosLobby
                        color: Tema.colorTextoTenue
                        font.pixelSize: 12 * Tema.escala
                        wrapMode: Text.WordWrap
                        width: 260 * Tema.escala
                    }
                }

                Row {
                    spacing: 18 * Tema.escala
                    Repeater {
                        model: jugadoresConectados
                        // Item posicionador con la property "required" (así
                        // lo exige el modo Bound para leer el modelo), que
                        // mete dentro un AsientoMini normal — igual patrón
                        // que los asientos de la mesa real.
                        delegate: Item {
                            id: posicionadorMini
                            required property string nombre
                            width: asientoMiniReal.width
                            height: asientoMiniReal.height
                            AsientoMini {
                                id: asientoMiniReal
                                nombre: posicionadorMini.nombre
                            }
                        }
                    }
                }

                BotonRelleno {
                    visible: soyHost
                    text: "Empezar ahora"
                    radioBorde: 999
                    onClicked: redcliente.empezarPartida()
                }

                Text {
                    visible: listaEsperando.length > 0
                    text: "Esperando a sentarse: " + listaEsperando.join(", ")
                    color: Tema.colorTextoTenue
                    font.pixelSize: 12 * Tema.escala
                    wrapMode: Text.WordWrap
                    width: 260 * Tema.escala
                }
                Text {
                    visible: mensajeEnEspera !== ""
                    text: mensajeEnEspera
                    color: Tema.colorAccent
                    font.pixelSize: 12 * Tema.escala
                    wrapMode: Text.WordWrap
                    width: 260 * Tema.escala
                }
            }

            // No hay historial en el lobby — solo chat, directamente, sin
            // pestañas que elegir (ChatBox ya es chat-only).
            ChatBox {
                id: chatLobby
                anchors.left: columnaSala.right
                anchors.leftMargin: 40 * Tema.escala
                anchors.verticalCenter: parent.verticalCenter
                activo: chatActive
                modelo: mensajesChatSala
                miNombre: nombreUsuario.text
            }
        }
        // ------------------- PARTIDA --------------------------------
        Item {
            visible: pantalla === "Partida"
            anchors.fill: parent

            // ── Barra superior: identidad + estado de la mano + tu saldo ──
            BarraSuperior {
                id: barraSuperior
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                mostrarSaldo: true
                // Binding declarativo — nunca le asignes texto a mano en
                // otro sitio (p. ej. en un handler de C++), porque eso
                // rompe este binding para siempre. Cualquier dato nuevo que
                // quiera mostrarse aquí debe pasar por una property (como
                // "rondaActual") y entrar en esta misma expresión.
                textoCentro: rondaActual + " · Mano " + manoActual + " · Ciega " + Math.round(ciegaActual / 2) + "/" + ciegaActual + " · Turno de " + turnoNombre
                pantalla: ventana.pantalla
                miSaldoActual: ventana.miSaldoActual
                reconectandoAhora: ventana.reconectandoAhora
                servidorHost: ventana.servidorHost
                servidorPuerto: ventana.servidorPuerto
                onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
            }

            // ── Centro: la mesa, pieza principal, con el panel de
            // historial/chat al lado — un Item normal, no un Row, porque un
            // Row no centra verticalmente hijos de distinta altura (cada
            // uno se queda pegado arriba); así cada pieza se centra sola
            // con su propio "anchors.verticalCenter".
            Item {
                id: zonaCentral
                anchors.top: barraSuperior.bottom
                anchors.bottom: barraInferior.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 12 * Tema.escala
                anchors.bottomMargin: 12 * Tema.escala
                width: mesaJuego.width + 20 + panelLateralJuego.width

                Mesa {
                    id: mesaJuego
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 820 * Tema.escala
                    height: 460 * Tema.escala
                    jugadores: jugadoresPartida
                    cartasMesa: ventana.cartasMesa
                    bote: boteActual
                    turnoNombre: ventana.turnoNombre
                    miNombreJugador: nombreUsuario.text
                    fraccionTiempo: ventana.fraccionTiempoRestante
                    retirados: ventana.retirados
                    dealerNombre: ventana.dealerNombre
                    sbNombre: ventana.sbNombre
                    bbNombre: ventana.bbNombre
                }

                PanelLateral {
                    id: panelLateralJuego
                    anchors.left: mesaJuego.right
                    anchors.leftMargin: 20 * Tema.escala
                    anchors.verticalCenter: parent.verticalCenter
                    width: 340 * Tema.escala
                    height: mesaJuego.height
                    modeloHistorial: historial
                    modeloChat: mensajesChatPartida
                    miNombre: nombreUsuario.text
                }
            }

            // ── Barra inferior: tu mano + estimación a la izquierda,
            // acciones (o el voto de fin de mano) a la derecha ───────────
            Rectangle {
                id: barraInferior
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 90 * Tema.escala
                color: Tema.colorPanel
                border.color: Tema.colorBorde
                border.width: 1

                // Tus cartas asoman por encima del borde de la barra — el
                // Rectangle no recorta a sus hijos por defecto, así que
                // basta con centrar verticalmente este Row sobre el propio
                // borde superior de la barra ("parent.top", no
                // "parent.verticalCenter") en vez de dejarlo dentro del
                // todo.
                Row {
                    id: filaCartasPropias
                    anchors.left: parent.left
                    anchors.leftMargin: 16 * Tema.escala
                    anchors.verticalCenter: parent.top
                    spacing: 6 * Tema.escala
                    Carta {
                        codigo: miCarta1
                        propia: true
                    }
                    Carta {
                        codigo: miCarta2
                        propia: true
                    }
                }

                Row {
                    anchors.left: filaCartasPropias.right
                    anchors.leftMargin: 16 * Tema.escala
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16 * Tema.escala

                    Column {
                        spacing: 2 * Tema.escala
                        Text {
                            text: "ACTUAL"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 10 * Tema.escala
                        }
                        Text {
                            text: comboActual
                            color: "white"
                            font.bold: true
                            font.pixelSize: 13 * Tema.escala
                            font.family: Tema.fuenteElegante
                        }
                    }
                    Column {
                        spacing: 2 * Tema.escala
                        Text {
                            text: "PROBABLE"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 10 * Tema.escala
                        }
                        Text {
                            text: comboProbable
                            color: "#C7CFC9"
                            font.pixelSize: 13 * Tema.escala
                            font.family: Tema.fuenteElegante
                        }
                    }
                    Column {
                        spacing: 2 * Tema.escala
                        Text {
                            text: "MÁXIMA"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 10 * Tema.escala
                        }
                        Text {
                            text: comboMaxima
                            color: Tema.colorAccent
                            font.bold: true
                            font.pixelSize: 13 * Tema.escala
                            font.family: Tema.fuenteElegante
                        }
                    }
                }

                // Acciones del turno: retirarse / igualar-pasar / subir (con
                // slider) / all-in, todo en una sola franja — como en el
                // boceto, sin un modo "subir" aparte que tape lo demás.
                Row {
                    visible: tuTurno
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 16 * Tema.escala
                    spacing: 10 * Tema.escala

                    BotonContorno {
                        text: "Retirarse"
                        colorBorde: Tema.colorPeligro
                        onClicked: {
                            redcliente.enviarAccion("FOLD", 0);
                            tuTurno = false;
                            // Parar el anillo/cuenta atrás ya mismo, sin
                            // esperar al próximo GAME_STATE del servidor —
                            // si no, sigue drenándose con el turnoNombre
                            // viejo durante el hueco de red hasta que
                            // llegue el turno real del siguiente jugador.
                            turnoNombre = "";
                        }
                    }
                    BotonContorno {
                        text: aPagarParaIgualar > 0 ? "Igualar · " + aPagarParaIgualar : "Pasar"
                        onClicked: {
                            redcliente.enviarAccion(aPagarParaIgualar > 0 ? "CALL" : "CHECK", Math.min(aPagarParaIgualar, miSaldoActual));
                            tuTurno = false;
                            // Parar el anillo/cuenta atrás ya mismo, sin
                            // esperar al próximo GAME_STATE del servidor —
                            // si no, sigue drenándose con el turnoNombre
                            // viejo durante el hueco de red hasta que
                            // llegue el turno real del siguiente jugador.
                            turnoNombre = "";
                        }
                    }
                    Slider {
                        id: sliderSubida
                        width: 220 * Tema.escala
                        // Antes 0..saldo, una aproximación sin mínimo ni
                        // tope real de pot-limit/fixed-limit. Ahora el rango
                        // exacto que manda el servidor en cada TU_TURNO.
                        from: minSubidaActual
                        to: maxSubidaActual
                        value: minSubidaActual
                        // Arrastrar el slider escribe directamente en su
                        // propia "value" — eso rompe el binding de arriba
                        // para siempre (comportamiento normal de QML con
                        // cualquier control interactivo). Sin este
                        // onMoved, el campo de texto dejaba de seguir al
                        // slider en cuanto lo arrastrabas una vez.
                        onMoved: campoSubida.text = String(Math.round(value))
                    }
                    // El slider solo no basta en escritorio (ratón/touchpad
                    // es incómodo para precisión) — un SpinBox ocupaba mucho
                    // sitio para lo poco que aportaba (seguía siendo tan
                    // lento llegar al número deseado). Un campo de texto
                    // simple es más directo: "text" sigue al slider, y al
                    // terminar de escribir (Enter o perder el foco) empuja
                    // el valor de vuelta, igual que hacía el SpinBox.
                    TextField {
                        id: campoSubida
                        width: 90 * Tema.escala
                        // Mismo motivo que el wordmark de arriba: Row no
                        // centra hijos de distinta altura entre sí (botones,
                        // slider y campo de texto no miden lo mismo por
                        // defecto) — se baja a mano. Ajusta este número si
                        // no queda perfecto a simple vista.
                        y: 6 * Tema.escala
                        color: "white"
                        font.pixelSize: 14 * Tema.escala
                        selectionColor: Tema.colorAccent
                        horizontalAlignment: Text.AlignHCenter
                        // Fondo/borde a mano — por defecto un TextField de
                        // Qt Quick Controls sale gris claro/blanco, fuera de
                        // sitio en esta paleta. El borde se ilumina con el
                        // color de acento solo cuando tiene el foco.
                        background: Rectangle {
                            color: Tema.colorPanel
                            radius: 6 * Tema.escala
                            border.width: 1
                            border.color: campoSubida.activeFocus ? Tema.colorAccent : Tema.colorBorde
                        }
                        // bottom/top NO se atan a minSubidaActual/maxSubidaActual:
                        // IntValidator rechaza cada pulsación cuyo resultado
                        // parcial exceda "top", así que con un máximo bajo
                        // era imposible teclear un número más largo (se
                        // quedaba pegado en 1 dígito). El rango real ya se
                        // aplica al terminar de escribir (onEditingFinished).
                        validator: IntValidator {
                            bottom: 0
                            top: 2147483647
                        }
                        text: Math.round(sliderSubida.value)
                        // Igual que onMoved del slider: escribir aquí rompe
                        // el binding de "text" de arriba para siempre, así
                        // que hay que fijar el valor final a mano en los dos
                        // sitios (slider Y el propio texto, por si lo
                        // tecleado se salía de rango y quedó sin recortar).
                        onEditingFinished: {
                            var v = Math.max(minSubidaActual, Math.min(parseInt(text) || 0, sliderSubida.to));
                            sliderSubida.value = v;
                            text = String(v);
                        }
                    }
                    BotonRelleno {
                        text: "Subir"
                        enabled: maxSubidaActual > 0
                        onClicked: {
                            var total = Math.min(aPagarParaIgualar + Math.round(sliderSubida.value), miSaldoActual);
                            redcliente.enviarAccion("RAISE", total);
                            tuTurno = false;
                            // Parar el anillo/cuenta atrás ya mismo, sin
                            // esperar al próximo GAME_STATE del servidor —
                            // si no, sigue drenándose con el turnoNombre
                            // viejo durante el hueco de red hasta que
                            // llegue el turno real del siguiente jugador.
                            turnoNombre = "";
                        }
                    }
                    BotonContorno {
                        id: botonAllIn
                        property bool confirmando: false
                        text: confirmando ? "¿Seguro?" : "ALL"
                        colorBorde: Tema.colorPeligro
                        onClicked: {
                            // Ver "Cliente" en el cajón de ajustes — con el
                            // interruptor activo, hace falta un segundo
                            // clic para evitar un ALL-IN por error.
                            if (confirmarAllIn && !confirmando) {
                                confirmando = true;
                                return;
                            }
                            confirmando = false;
                            redcliente.enviarAccion("ALL_IN", miSaldoActual);
                            tuTurno = false;
                            // Parar el anillo/cuenta atrás ya mismo, sin
                            // esperar al próximo GAME_STATE del servidor —
                            // si no, sigue drenándose con el turnoNombre
                            // viejo durante el hueco de red hasta que
                            // llegue el turno real del siguiente jugador.
                            turnoNombre = "";
                        }
                    }
                }

                // ------ RECOMPRA (te quedaste sin fichas, la sala lo permite) ------
                Row {
                    visible: puedoRecomprar
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 16 * Tema.escala
                    spacing: 10 * Tema.escala

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Te has quedado sin fichas"
                        color: Tema.colorTextoTenue
                        font.pixelSize: 13 * Tema.escala
                    }
                    BotonRelleno {
                        text: recompraSolicitada ? "Recompra enviada…" : "Recomprar"
                        enabled: !recompraSolicitada
                        onClicked: {
                            redcliente.pedirRecompra();
                            recompraSolicitada = true;
                        }
                    }
                }

                // El voto de fin de mano (continuar/abandonar/guardar) y el
                // de extender la partida ya NO viven aquí — los dos se
                // movieron dentro del overlay de showdown (ver más abajo,
                // PanelVoto y el Column de votoExtensionAbierto) para poder
                // votar mientras se ven las cartas reveladas, en vez de un
                // menú aparte que tapaba la mesa de golpe. El de extensión
                // se quedó aquí olvidado una temporada (bug real: tapado
                // por el propio showdown en el momento exacto en que hacía
                // falta) hasta que se corrigió.
                // onGanadorSinShowdown() abre ese mismo overlay (sin cartas
                // que mostrar) para que el voto siga teniendo un único
                // sitio también cuando la mano termina sin showdown real
                // (todos se retiran menos uno).
            }
        }

        Connections {
            target: redcliente
            // ── Cuentas de usuario ──────────────────────────────────────────
            // registroOk/loginOk comparten handler -- en los dos casos el
            // destino es el mismo (Salas, como ya hacía "Entrar como
            // invitado"), tanto si viene de las pantallas Login/Registro
            // como del intento silencioso al arrancar (iniciarSesionConToken,
            // ver Component.onCompleted).
            function onRegistroOk(accountId, username, token) {
                nombreUsuario.text = username;
                tokenSesion = token;
                mensajeErrorLogin = "";
                pantalla = "Salas";
                redcliente.refrescarSalas(servidorHost, servidorPuerto);
            }
            function onRegistroError(mensaje) {
                mensajeErrorLogin = mensaje;
            }
            function onLoginOk(accountId, username, token) {
                nombreUsuario.text = username;
                tokenSesion = token;
                mensajeErrorLogin = "";
                pantalla = "Salas";
                redcliente.refrescarSalas(servidorHost, servidorPuerto);
            }
            function onLoginError(mensaje) {
                mensajeErrorLogin = mensaje;
            }
            function onSesionInvalida(mensaje) {
                // Token caducado/revocado -- se olvida y se deja Inicio tal
                // cual (ya es la pantalla por defecto al arrancar, antes de
                // que esto pueda llegar). Sin mensaje visible: el usuario
                // nunca llegó a pedir nada explícitamente, no hay nada que
                // explicarle salvo que ya no está conectado con su cuenta.
                tokenSesion = "";
            }
            function onLogoutOk() {
                tokenSesion = "";
                nombreUsuario.text = "";
                pantalla = "Inicio";
            }
            function onUsernameCambiado(nuevoUsername) {
                nombreUsuario.text = nuevoUsername;
                mensajeErrorLogin = "";
                campoNuevoUsername.text = "";
            }
            function onUsernameError(mensaje) {
                tratarErrorCuenta(mensaje);
            }
            function onPasswordCambiada() {
                mensajeErrorLogin = "";
                campoPasswordActualCuenta.text = "";
                campoPasswordNuevaCuenta.text = "";
            }
            function onPasswordError(mensaje) {
                tratarErrorCuenta(mensaje);
            }
            function onConectado() {
                pantalla = "Lobby";
                chatActive = true;
                // Sin esto, el chat y el historial de una sesión anterior
                // (con otro nombre, en otra sala) se quedaban visibles
                // para siempre en la app -- nunca se vaciaban al empezar
                // una conexión nueva. No es una fuga del servidor entre
                // salas: el cliente simplemente nunca limpiaba su propia
                // lista local.
                mensajesChatSala.clear();
                mensajesChatPartida.clear();
                historial.clear();
                mensajeEnEspera = "";
                listaEsperando = [];
            }
            function onError(mensaje) {
                // Sin pantalla propia: puede llegar estando en Inicio, Salas
                // o CrearSala (las tres inician una conexión) — el mensaje
                // vive en una property compartida que las tres muestran.
                mensajeErrorConexion = "Error: " + mensaje;
            }
            function onConexionComprobada(conectado) {
                comprobandoConexion = false;
                conectadoAlServidor = conectado;
            }
            function onNombreRechazado(mensaje) {
                // onConectado ya nos había pasado a "Lobby" (llega antes de
                // saber si el servidor acepta el nombre) — deshacemos ese
                // salto y dejamos el mensaje donde el usuario puede verlo.
                pantalla = "Inicio";
                mensajeErrorConexion = mensaje;
            }
            function onSalasActualizadas(salasCsv) {
                salasDisponibles.clear();
                if (salasCsv.length === 0) return;
                var salas = salasCsv.split(";");
                for (var i = 0; i < salas.length; i++) {
                    var campos = salas[i].split(":");
                    // "nombre" es el resto tras los 3 primeros campos, no
                    // campos[3] a secas — es texto libre del host y podría
                    // traer sus propios ':'.
                    salasDisponibles.append({
                        id: campos[0],
                        conectados: parseInt(campos[1]),
                        esperados: parseInt(campos[2]),
                        nombre: campos.slice(3).join(":")
                    });
                }
            }
            function onSalaCreada(salaId, codigo) {
                codigoSalaPropia = codigo;
            }
            function onGuardadasActualizadas(guardadasCsv) {
                guardadasDisponibles.clear();
                if (guardadasCsv.length === 0) return;
                var guardadas = guardadasCsv.split(";");
                for (var i = 0; i < guardadas.length; i++) {
                    var campos = guardadas[i].split(":");
                    // "fecha" es el resto tras los 3 primeros campos, no
                    // campos[3] a secas — trae su propio ':' (hora) que
                    // split(":") ya partió por su cuenta.
                    guardadasDisponibles.append({
                        archivo: campos[0],
                        humanos: parseInt(campos[1]),
                        bots: parseInt(campos[2]),
                        fecha: campos.slice(3).join(":")
                    });
                }
            }
            function onRankingActualizado(rankingCsv) {
                var filas = [];
                if (rankingCsv.length > 0) {
                    var partes = rankingCsv.split(";");
                    for (var i = 0; i < partes.length; i++) {
                        var campos = partes[i].split(":");
                        // "username" es el resto tras los 2 primeros campos,
                        // no campos[2] a secas -- mismo motivo que "nombre"/
                        // "fecha" en salas/guardadas más arriba.
                        filas.push({
                            partidasJugadas: parseInt(campos[0]),
                            partidasGanadas: parseInt(campos[1]),
                            username: campos.slice(2).join(":")
                        });
                    }
                }
                rankingCrudo = filas;
                reordenarRanking();
            }
            function onEstadisticasActualizadas(manosJugadas, manosGanadas, partidasJugadas, partidasGanadas, fichasNetas) {
                statsManosJugadas = manosJugadas;
                statsManosGanadas = manosGanadas;
                statsPartidasJugadas = partidasJugadas;
                statsPartidasGanadas = partidasGanadas;
                statsFichasNetas = fichasNetas;
            }
            function onGuardadaRenombrada(mensaje) {
                // mensaje vacío = fue bien; en los dos casos se refresca
                // para ver el resultado (nombre nuevo, o simplemente que no
                // cambió nada si falló).
                if (mensaje.length > 0) mensajeErrorConexion = mensaje;
                redcliente.listarGuardadas(servidorHost, servidorPuerto);
            }
            function onGuardadaBorrada(mensaje) {
                if (mensaje.length > 0) mensajeErrorConexion = mensaje;
                redcliente.listarGuardadas(servidorHost, servidorPuerto);
            }
            function onNombreAsignado(nombre) {
                // Corrige nombreUsuario.text si el servidor usó un nombre
                // distinto del escrito (vacío o sanitizado) — de lo
                // contrario "soyHost" y el resaltado del propio nombre en
                // el historial se comparan contra un valor que ya no coincide.
                nombreUsuario.text = nombre;
            }
            function onAvisoRecompra(puedeRecomprar) {
                puedoRecomprar = puedeRecomprar;
                recompraSolicitada = false;
            }
            function onErrorSala(mensaje) {
                // Mismo motivo que onNombreRechazado: onConectado ya nos
                // había mandado a "Lobby" antes de saber si el servidor
                // aceptaba la unión — se deshace el salto.
                pantalla = "Salas";
                mensajeErrorConexion = mensaje;
            }
            function onLobbyActualizado(jugadoresCsv, listos, esperados, host, esperadosNombresCsv) {
                jugadoresConectados.clear();
                var nombres = jugadoresCsv.split(",");
                for (var i = 0; i < nombres.length; i++) {
                    jugadoresConectados.append({
                        nombre: nombres[i]
                    });
                }
                contadorListos.text = listos + " / " + esperados + " listos";
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
            function onEstadoMesaActualizado(ronda, bote, turno, jugadoresStr, timeoutMs,
                                             dealer, sb, bb) {
                rondaActual = ronda;
                boteActual = bote;
                turnoNombre = turno;
                dealerNombre = dealer;
                sbNombre = sb;
                bbNombre = bb;
                // Si el servidor ya dice que el turno es de otro (o de
                // nadie), asegurar que la fila de acciones se oculte aunque
                // nunca se haya pulsado un botón — pasa cuando el turno
                // termina por timeout del servidor en vez de por clic, y
                // antes se quedaba con tuTurno=true para siempre (los
                // botones seguían ahí incluso con la mano ya terminada).
                if (turno !== nombreUsuario.text) tuTurno = false;
                // timeoutMs > 0: este GAME_STATE viene de onTurnoIniciado (un
                // turno de verdad empezando, de cualquier jugador) — arranca
                // la cuenta atrás del anillo para quien tenga el turno ahora.
                // El GAME_STATE "viejo" (justo antes de onPreTurnoHumano) no
                // manda timeout_ms (llega como 0) y no debe reiniciar nada.
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
                    if (campos[0] === nombreUsuario.text) {
                        // BUG real encontrado en vivo: miSaldoActual (el de
                        // la barra superior, "X fichas") solo se ponía al
                        // día dentro de onEsMiTurno -- si aún no te ha
                        // tocado (o llevas varias manos sin turno, p. ej.
                        // acabas de unirte a mitad de partida), se quedaba
                        // a 0 aunque tu saldo real en la mesa fuera otro.
                        // Este GAME_STATE llega en CADA turno de CUALQUIERA
                        // (no solo el tuyo), así que es el sitio correcto
                        // para mantenerlo al día siempre.
                        miSaldoActual = parseInt(campos[1]);
                        // No hay un evento dedicado de "recompra
                        // confirmada" -- se detecta viendo que el propio
                        // saldo ya no es 0.
                        if (miSaldoActual > 0) {
                            puedoRecomprar = false;
                            recompraSolicitada = false;
                        }
                    }
                }
            }
            function onEventoJuego(evento, tipo, jugador) {
                historial.append({
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
                // Sin esto, el preflop de la mano nueva sigue mostrando las
                // 5 cartas comunitarias de la mano anterior hasta que llega
                // el primer MESA_UPDATE (flop) — onMesaActualizada() es lo
                // único que las toca, y solo se dispara al revelar cartas.
                cartasMesa = [];
                // Mismo motivo con la propia mano: sin esto se verían las
                // cartas de la mano anterior hasta que llegue TUS_CARTAS.
                miCarta1 = "";
                miCarta2 = "";
                // Red de seguridad: si por lo que sea no llegó ESPERAR_VOTO
                // (p. ej. nadie tenía que votar), que el showdown no se
                // quede abierto para siempre tapando la mesa de la mano nueva.
                showdownAbierto = false;
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
                // este filtro, se le creaba una tarjeta nueva cada vez
                // (vista en real: un jugador duplicado, una tarjeta con el
                // total correcto y otra suelta solo con el premio del
                // side pot). El dinero real del jugador no se veía
                // afectado (eso lo gestiona el servidor aparte), pero la
                // tarjeta fantasma sí. La entrada ya existente sigue
                // sumando cada premio con normalidad (onBoteGanado más
                // abajo).
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
                    return {
                        nombre: r.nombre,
                        cartas: r.cartas,
                        combo: r.combo,
                        esGanador: true,
                        premio: r.premio + premio
                    };
                });
                resumenBotes = resumenBotes.map(function(b) {
                    if (b.numBote !== numBote) return b;
                    return {
                        numBote: b.numBote,
                        cantidad: b.cantidad,
                        competidores: b.competidores,
                        ganador: jugador,
                        premioGanador: premio
                    };
                });
            }
            function onGanadorSinShowdown(jugador, bote) {
                // Todos se retiraron menos uno — no hay MUESTRA_CARTAS que
                // narre nada, pero el voto de fin de mano (ver PanelVoto)
                // solo vive dentro de este overlay, así que se abre igual,
                // con una única tarjeta sin cartas que enseñar.
                cartasMesa = [];
                revealsShowdown = [{
                    nombre: jugador,
                    cartas: [],
                    combo: "Se llevó el bote sin mostrar cartas",
                    esGanador: true,
                    premio: bote
                }];
                showdownAbierto = true;
            }
            function onMisCartasRepartidas(c1, c2) {
                // Llega justo al repartir, antes de cualquier turno — sin
                // esto, la propia mano se mostraba como "?" hasta el primer
                // turno propio (TU_TURNO es lo único que las traía antes).
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
                if (sonidoActivado) sonidoTurno.play();
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
                // Nuevo turno: si el anterior quedó a medio confirmar
                // (tocaste "ALL" pero no llegaste a confirmar), no debe
                // arrastrarse al turno siguiente.
                botonAllIn.confirmando = false;

                // Reset explícito, no un binding: en cuanto el usuario toca
                // el slider o escribe en el campo una vez, QML rompe para
                // siempre el binding declarativo de esa propiedad — sin
                // esto, a partir de la segunda vez que interactúas, el
                // slider/campo dejaban de volver al mínimo en el turno
                // siguiente y podían quedarse desincronizados entre sí.
                sliderSubida.value = minSubida;
                campoSubida.text = String(minSubida);

                for (var j = 0; j < jugadoresPartida.count; j++) {
                    if (jugadoresPartida.get(j).nombre === nombreUsuario.text) {
                        jugadoresPartida.setProperty(j, "saldo", miSaldo);
                        break;
                    }
                }
            }
            // BUG corregido: el servidor ya manda esto en cada turno de
            // CUALQUIERA (no solo el propio), pero antes el cliente lo
            // ignoraba del todo — comboActual/etc. solo se actualizaban
            // dentro de onEsMiTurno, así que se quedaban congelados hasta
            // que volvía a tocarte, en cada ronda de apuestas.
            function onComboActualizado(comboA, comboP, comboM) {
                comboActual = comboA;
                comboProbable = comboP;
                comboMaxima = comboM;
            }
            function onEsperandoVoto(mensaje) {
                mensajeVoto = mensaje;
                votoAbierto = true;
                // Cierra la fila de acciones pase lo que pase: si tu último
                // turno de la mano fue el ÚLTIMO turno de toda la mano (p.
                // ej. quedaste tú solo por actuar antes del showdown), no
                // vuelve a haber ningún GAME_STATE con "turno" de otro
                // jugador que dispare el reset de onEstadoMesaActualizado —
                // turno se queda con tu nombre durante todo el showdown, y
                // los botones se quedan visibles hasta que alguien haga
                // clic. Aquí no hace falta ninguna condición: si se abre el
                // menú de voto, por definición ya no es el turno de nadie.
                tuTurno = false;
                // Mismo problema con el aro de tiempo: si tu turno (o el de
                // un bot) fue el último de la mano, turnoNombre se queda
                // apuntando a ese jugador durante todo el showdown — nadie
                // más vuelve a tener turno, así que el Timer sigue
                // girándole el aro hasta agotar la cuenta sola, aunque la
                // decisión ya esté tomada hace rato. Vaciarlo para el resto
                // de la ronda de fin de mano.
                turnoNombre = "";
                // El showdown YA NO se cierra aquí a propósito: el usuario
                // quiere seguir viendo las cartas reveladas mientras se
                // vota la siguiente mano (el botón de votar vive también
                // dentro del overlay de showdown, ver más abajo). Se cierra
                // solo con la mano nueva (onNuevaMano).
            }
            function onEsperandoVotoExtension(mensaje) {
                votoExtensionTexto.text = mensaje;
                votoExtensionAbierto = true;
                // Mismo motivo que onEsperandoVoto: por definición ya no es
                // el turno de nadie si se está votando la extensión.
                tuTurno = false;
                turnoNombre = "";
            }
            // FASE 2 (unanimidad conseguida): al host le llega este evento
            // en concreto (unicast) -- muestra el selector de cuántas
            // manos añadir en vez del mensaje genérico de espera.
            function onElegirManosExtraPedido(mensaje) {
                manosExtraMensaje = mensaje;
                soyYoQuienElige = true;
                esperandoManosExtra = true;
            }
            // FASE 2 para el resto (broadcast, incluido el propio host,
            // pero onElegirManosExtraPedido ya puso soyYoQuienElige=true
            // para él, así que ve el selector en vez de este aviso).
            function onEsperandoEleccionManos(mensaje, host) {
                manosExtraMensaje = mensaje;
                esperandoManosExtra = true;
            }
            function onPartidaExtendida(manosExtra, nuevoObjetivoManos) {
                esperandoManosExtra = false;
                soyYoQuienElige = false;
                // BUG real encontrado en vivo: "Mano X/Y" se quedaba con el
                // objetivo original tras extender (ej. "3/1") porque nunca
                // se actualizaba objetivoManos -- ya viene calculado del
                // servidor, no hace falta sumarlo aquí.
                objetivoManos = nuevoObjetivoManos;
            }
            function onMesaActualizada(cartasCsv) {
                cartasMesa = cartasCsv.length > 0 ? cartasCsv.split(",") : [];
            }
            // manosDisputadasFinal/mejorManoFinal/mejorManoJugadorFinal/
            // eliminacionesFinal se leen de redcliente (propiedades, no
            // parámetros de la señal) -- ver el comentario largo en
            // NetworkClient.hpp junto a esas Q_PROPERTY: en el APK de
            // Android real, una señal de 7 parámetros aquí perdía los 4
            // últimos en silencio (bug visto solo ahí, nunca en escritorio
            // ni en el propio móvil como ventana de escritorio).
            // estadisticasFinCambiaron() se emite justo antes que esta
            // señal, así que las propiedades ya están al día para cuando
            // se leen aquí.
            function onFinDePartida(ganador, saldo, porLimite) {
                ganadorFinal = ganador;
                saldoFinal = saldo;
                finPorLimite = porLimite;
                manosDisputadasFinal = redcliente.manosDisputadasFinal;
                mejorManoFinal = redcliente.mejorManoFinal;
                mejorManoJugadorFinal = redcliente.mejorManoJugadorFinal;
                var eliminacionesCsv = redcliente.eliminacionesFinalCsv;
                eliminacionesFinal = eliminacionesCsv.length > 0
                    ? eliminacionesCsv.split(";").map(function(par) {
                          var campos = par.split(":");
                          return { nombre: campos[0], mano: campos[1] };
                      })
                    : [];
                partidaGuardada = false;
                // Mismo motivo que onEsperandoVoto: la partida terminó, ya
                // no hay ningún turno de acción pendiente que mostrar.
                tuTurno = false;
                turnoNombre = "";
                // Sin esto, el showdown/voto de la última mano se quedaba
                // abierto tapando la pantalla de Fin de fondo.
                showdownAbierto = false;
                votoAbierto = false;
                votoExtensionAbierto = false;
                esperandoManosExtra = false;
                soyYoQuienElige = false;
                pantalla = "Fin";
            }
            function onAbandonaste(mensaje) {
                mensajeErrorConexion = mensaje;
                // Mismo motivo que onFinDePartida: si abandonas desde dentro
                // del overlay de showdown, no debe quedarse tapando la
                // pantalla de Salas de fondo.
                showdownAbierto = false;
                votoAbierto = false;
                esperandoManosExtra = false;
                soyYoQuienElige = false;
                pantalla = "Salas";
                redcliente.refrescarSalas(servidorHost, servidorPuerto);
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
            function onPartidaGuardada(archivo) {
                partidaGuardada = true;
                // Sin esto, "Guardar y salir" desde el overlay de showdown
                // se quedaba con el showdown encima de la pantalla de Fin
                // para siempre (showdownAbierto nunca se cerraba con este
                // evento) — igual que votoAbierto/votoExtensionAbierto,
                // que tampoco tenían por qué seguir abiertos.
                showdownAbierto = false;
                votoAbierto = false;
                votoExtensionAbierto = false;
                esperandoManosExtra = false;
                soyYoQuienElige = false;
                pantalla = "Fin";
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

        // Chat de sala (Lobby + quien espera a sentarse a mitad de partida)
        // y chat de partida (pestaña "Chat" de PanelLateral, solo
        // jugadores ya sentados) van cada uno a su propia lista -- antes
        // compartían una sola (mensajesChat) y se mezclaban sin más. El
        // servidor ya los separa por el campo "canal" del CHAT (ver
        // NetworkObserver::relayPendingChat()/broadcastASala()).
        ListModel {
            id: mensajesChatSala
        }
        ListModel {
            id: mensajesChatPartida
        }
        ListModel {
            id: jugadoresConectados
        }
        ListModel {
            id: jugadoresPartida
        }
        ListModel {
            id: historial
        }
    }

    // Aviso de tamaño mínimo: por debajo de "escalaMinima" el contenido ya
    // no cabría de forma legible (botones inaccesibles, texto solapado) —
    // mejor un aviso claro que una interfaz rota. Se declara como hermano
    // de la pantalla principal (no dentro), para quedar siempre por encima
    // de todo, sea cual sea el valor de "pantalla" en ese momento.
    Rectangle {
        anchors.fill: parent
        visible: escala < escalaMinima
        color: "#0A140F"

        Text {
            anchors.centerIn: parent
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "La ventana es demasiado pequeña para mostrar la partida correctamente.\nAgrándala para continuar."
            color: "white"
            font.pixelSize: 16 * Tema.escala
        }
    }

    // Mismo patrón que el aviso de tamaño mínimo de arriba: hermano de la
    // pantalla principal para quedar siempre encima, sea cual sea "pantalla".
    // Se ve mientras NetworkClient reintenta la conexión (mismo mecanismo de
    // reconexión de 60s que ya tiene el servidor/cliente ncurses).
    Rectangle {
        anchors.fill: parent
        visible: reconectandoAhora
        color: "#0A140F"
        opacity: 0.92

        Column {
            anchors.centerIn: parent
            spacing: 12 * Tema.escala

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Conexión perdida — reconectando..."
                color: "white"
                font.pixelSize: 18 * Tema.escala
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: segundosReconexion + "s restantes"
                color: Tema.colorTextoTenue
                font.pixelSize: 13 * Tema.escala
            }
        }
    }

    // Mismo patrón que los overlays de arriba: hermano de la pantalla
    // principal para quedar siempre encima. Se abre con SHOWDOWN y se
    // cierra al llegar el turno de votar (o una mano nueva) — ver
    // onShowdownIniciado/onEsperandoVoto/onNuevaMano más arriba.
    Rectangle {
        anchors.fill: parent
        visible: showdownAbierto
        color: "#0A140F"
        opacity: 0.94

        Column {
            anchors.centerIn: parent
            // Nunca más ancho que la ventana menos aire a los lados — con
            // hasta 9 jugadores en el showdown, la fila de abajo (Flow) ya
            // se encarga de partir en varias líneas si no caben en una.
            width: Math.min(parent.width - 80 * Tema.escala, 900 * Tema.escala)
            spacing: 18 * Tema.escala

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "SHOWDOWN"
                color: Tema.colorAccent
                font.letterSpacing: 3
                font.pixelSize: 13 * Tema.escala
                font.bold: true
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6 * Tema.escala
                Repeater {
                    model: cartasMesa
                    delegate: Carta {
                        required property string modelData
                        codigo: modelData
                    }
                }
            }

            // Caso normal (un solo bote, sin all-in de por medio): el
            // número total ya lo dice todo, no hace falta desglosar nada.
            Text {
                visible: resumenBotes.length <= 1
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Bote: " + boteTotalShowdown()
                color: Tema.colorTextoTenue
                font.pixelSize: 13 * Tema.escala
                font.family: Tema.fuenteElegante
            }

            // Con side pots (varios all-in de distinto tamaño en la misma
            // mano) un solo número no dice quién compite por cuál — eso es
            // justo lo que hace sentir "opaco" el reparto. Una línea por
            // bote, compacta a propósito (puede haber 2-3 líneas más aquí
            // encima de la fila de cartas, que ya usa bastante alto).
            Column {
                visible: resumenBotes.length > 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                spacing: 3 * Tema.escala

                Repeater {
                    model: resumenBotes
                    delegate: Text {
                        required property var modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12 * Tema.escala
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

            // Una tarjeta por jugador que llegó al showdown — los que se
            // retiraron antes ni aparecen aquí (nunca llega su
            // MUESTRA_CARTAS). Agrupadas a mano en filas de tamaño fijo, en
            // vez de un "Flow": Flow empaqueta el contenido pegado a la
            // izquierda de su propio ancho, así que en cuanto no cabía todo
            // en una línea (mesas grandes) o quedaba una fila incompleta al
            // final, esa fila salía descentrada hacia la izquierda en vez
            // de centrada como el resto — bug real visto en pruebas. Cada
            // fila es su propio "Row" con su propio anchors.horizontalCenter,
            // así que se centra sola sin importar cuántos elementos tenga.
            Column {
                id: filaReveals
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16 * Tema.escala

                readonly property real anchoItem: 130 * Tema.escala
                // Cuántas tarjetas caben en una fila sin salirse del ancho
                // disponible — fórmula estándar de "cuántos ítems de ancho w
                // con hueco g caben en un espacio W": floor((W+g)/(w+g)).
                readonly property int itemsPorFila: Math.max(1, Math.floor(
                        (parent.width + spacing) / (anchoItem + spacing)))

                Repeater {
                    model: Math.ceil(revealsShowdown.length / filaReveals.itemsPorFila)
                    delegate: Row {
                        required property int index
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: filaReveals.spacing

                        Repeater {
                            model: revealsShowdown.slice(
                                    index * filaReveals.itemsPorFila,
                                    (index + 1) * filaReveals.itemsPorFila)
                            delegate: TarjetaReveal {
                                required property var modelData
                                datos: modelData
                            }
                        }
                    }
                }
            }

            // El voto de fin de mano vive TAMBIÉN aquí (mismo mensaje y
            // mismos botones que la fila de acciones normal, ver
            // PanelVoto) — así se puede votar sin dejar de ver las cartas
            // reveladas, en vez de que el showdown se cierre de golpe en
            // cuanto empieza a poder votarse.
            Column {
                visible: votoAbierto
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10 * Tema.escala

                Text {
                    // No se usa mensajeVoto tal cual: el servidor lo
                    // redacta pensando en el cliente ncurses ("Pulsa
                    // Enter para continuar..."), que no pinta nada aquí
                    // con un botón real al lado. Este texto es solo la
                    // cabecera, el botón de abajo (PanelVoto) ya dice
                    // qué hacer.
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Fin de la mano"
                    color: Tema.colorAccent
                    font.bold: true
                    font.pixelSize: 13 * Tema.escala
                }
                PanelVoto {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Mismo bug de scope que la barra superior (ver
                    // comentario en la instanciación de "Salas" más
                    // arriba) -- PanelVoto declara su propio "soyHost", así
                    // que bajo ComponentBehavior: Bound la referencia
                    // suelta se autorreferenciaba en vez de leer la de la
                    // ventana.
                    soyHost: ventana.soyHost
                    // 5 = MIN_MANOS_PARA_STATS en NetworkObserver.cpp (servidor) -- si cambia ahí, cambiar aquí también.
                    contariaComoPerdida: ventana.tokenSesion !== "" && ventana.manoActual >= 5
                    onContinuar: { votoAbierto = false; mensajeVoto = ""; }
                    onAbandonar: votoAbierto = false
                    onGuardarYSalir: votoAbierto = false
                }
            }

            // BUG real encontrado en vivo: este bloque se quedó en la fila
            // de acciones de abajo (donde antes vivía TAMBIÉN el voto
            // normal de "continuar", ver comentario más arriba) cuando ese
            // otro se movió aquí dentro del showdown para que quedara
            // visible -- este se quedó atrás, tapado por el propio overlay
            // del showdown (opacity 0.94) justo en el momento en que más
            // hace falta verlo (se llega al límite de manos justo después
            // de un showdown). Debe vivir aquí, no en la fila de acciones.
            Column {
                visible: votoExtensionAbierto
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10 * Tema.escala

                Text {
                    id: votoExtensionTexto
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Tema.colorAccent
                    font.bold: true
                    font.pixelSize: 13 * Tema.escala
                    wrapMode: Text.WordWrap
                    width: 260 * Tema.escala
                    horizontalAlignment: Text.AlignHCenter
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8 * Tema.escala
                    BotonRelleno {
                        text: "Sí, extender"
                        onClicked: {
                            redcliente.votarExtension(true);
                            votoExtensionAbierto = false;
                        }
                    }
                    BotonContorno {
                        text: "No, terminar aquí"
                        colorBorde: Tema.colorPeligro
                        onClicked: {
                            redcliente.votarExtension(false);
                            votoExtensionAbierto = false;
                        }
                    }
                }
            }

            // FASE 2: unanimidad conseguida -- el host elige cuántas manos
            // más, el resto solo ve el mensaje de espera (mismo bloque,
            // "soyYoQuienElige" decide qué contenido mostrar).
            Column {
                visible: esperandoManosExtra
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10 * Tema.escala

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Tema.colorAccent
                    font.bold: true
                    font.pixelSize: 13 * Tema.escala
                    wrapMode: Text.WordWrap
                    width: 260 * Tema.escala
                    horizontalAlignment: Text.AlignHCenter
                    text: manosExtraMensaje
                }
                Row {
                    visible: soyYoQuienElige
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10 * Tema.escala
                    TextField {
                        id: campoManosExtra
                        anchors.verticalCenter: parent.verticalCenter
                        width: 80 * Tema.escala
                        text: "10"
                        color: "white"
                        font.pixelSize: 13 * Tema.escala
                        horizontalAlignment: Text.AlignHCenter
                        validator: IntValidator { bottom: 1; top: 500 }
                        background: Rectangle {
                            color: Tema.colorPanel
                            radius: 6 * Tema.escala
                            border.width: 1
                            border.color: campoManosExtra.activeFocus ? Tema.colorAccent : Tema.colorBorde
                        }
                        onAccepted: botonConfirmarManosExtra.clicked()
                    }
                    BotonRelleno {
                        id: botonConfirmarManosExtra
                        text: "Confirmar"
                        onClicked: {
                            redcliente.elegirManosExtra(parseInt(campoManosExtra.text) || 10);
                            esperandoManosExtra = false;
                            soyYoQuienElige = false;
                        }
                    }
                }
            }
        }
    }

    // ── Cajón lateral de ajustes ───────────────────────────────────────────
    // El botón que lo abre ya no flota aparte — vive dentro de la
    // BarraSuperior de cada pantalla (ver el componente más arriba), así
    // que aquí solo queda el propio cajón + su fondo oscurecido.
    // Fondo oscurecido — clic fuera del cajón para cerrarlo.
    Rectangle {
        anchors.fill: parent
        visible: ajustesAbiertos
        color: "black"
        opacity: 0.35
        z: 58
        MouseArea {
            anchors.fill: parent
            onClicked: ajustesAbiertos = false
        }
    }

    Rectangle {
        id: cajonAjustes
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // 300 se quedaba corto -- la fila de zoom (etiqueta + "−" + "%" +
        // "+") no cabía entera y se recortaba (reportado en vivo).
        width: 340 * Tema.escala
        // Se desliza desde fuera de la ventana en vez de aparecer/desaparecer
        // de golpe — "x" en vez de "anchors.right" porque necesita animarse.
        x: ajustesAbiertos ? parent.width - width : parent.width
        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.3)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
            GradientStop { position: 1.0; color: Tema.colorPanel }
        }
        z: 62

        // ScrollView en vez de Column a secas: con "Mesa actual" + "Cliente"
        // + la chuleta de manos, el contenido ya no cabe siempre en una
        // ventana pequeña — mismo patrón que el formulario de Crear sala.
        ScrollView {
            id: scrollAjustes
            anchors.fill: parent
            anchors.margins: 22 * Tema.escala
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Column {
            width: scrollAjustes.availableWidth
            spacing: 20 * Tema.escala

            // Antes un único título "Ajustes" -- ahora dos pestañas: "quién
            // eres" (Cuenta) separado de "cómo se ve/comporta el cliente"
            // (Ajustes), en vez de una única lista larga con todo mezclado.
            // SelectorSegmentado en vez de SelectorPildoras a propósito:
            // aquí cambiar de opción cambia TODO el contenido de debajo,
            // no un simple filtro -- pedido explícito de que se viera más
            // grande y distinto de un botón normal, para que el
            // deslizamiento del realce deje claro que ha cambiado el panel
            // entero. SelectorPildoras se queda para filtros normales
            // (Salas públicas/Guardadas, dificultad, tipo de límite...).
            SelectorSegmentado {
                width: parent.width
                opciones: ["Ajustes", "Cuenta"]
                seleccionado: ventana.pestanaAjustesActual
                onSeleccionadoChanged: ventana.pestanaAjustesActual = seleccionado
            }

            Column {
                width: parent.width
                spacing: 10 * Tema.escala
                visible: ventana.pestanaAjustesActual === 0

                Text {
                    text: "TEMA DE COLOR"
                    color: Tema.colorTextoMuyTenue
                    font.pixelSize: 11 * Tema.escala
                    font.letterSpacing: 1
                }

                Repeater {
                    model: Tema.temas
                    delegate: Rectangle {
                        id: filaTema
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: 52 * Tema.escala
                        radius: 8 * Tema.escala
                        color: Tema.temaActual === filaTema.index ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                        border.width: Tema.temaActual === filaTema.index ? 2 : 1
                        border.color: Tema.temaActual === filaTema.index ? filaTema.modelData.accent : Tema.colorBorde

                        Row {
                            anchors.fill: parent
                            anchors.margins: 10 * Tema.escala
                            spacing: 12 * Tema.escala

                            Rectangle {
                                width: 30 * Tema.escala
                                height: 30 * Tema.escala
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: filaTema.modelData.tapete
                                border.width: 2
                                border.color: filaTema.modelData.accent
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: filaTema.modelData.nombre
                                color: Tema.temaActual === filaTema.index ? "white" : Tema.colorTextoTenue
                                font.bold: Tema.temaActual === filaTema.index
                                font.pixelSize: 13 * Tema.escala
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: Tema.temaActual = filaTema.index
                        }
                    }
                }
            }

            // ── Mesa actual (solo lectura, solo tiene sentido en Partida) ──
            Column {
                width: parent.width
                visible: ventana.pestanaAjustesActual === 0 && pantalla === "Partida"
                spacing: 10 * Tema.escala

                Text {
                    text: "MESA ACTUAL"
                    color: Tema.colorTextoMuyTenue
                    font.pixelSize: 11 * Tema.escala
                    font.letterSpacing: 1
                }

                Repeater {
                    // "Código de invitación" solo se añade si la sala es
                    // privada (codigoSalaPropia no vacío) — antes este dato
                    // solo se veía en la pantalla de Lobby y desaparecía en
                    // cuanto arrancaba la partida, así que si alguien se
                    // unía después no había forma de recuperarlo.
                    model: [
                        { etiqueta: "Ciega actual", valor: Math.round(ciegaActual / 2) + " / " + ciegaActual },
                        { etiqueta: "Mano", valor: manoActual + " / " + objetivoManos },
                        { etiqueta: "Tipo de límite", valor: ["Sin límite", "Límite bote", "Límite fijo"][tipoLimiteActual] || "—" },
                        { etiqueta: "Permite recompra", valor: permitirRecompraActual ? "Sí" : "No" },
                        { etiqueta: "Rellena con bots", valor: rellenarConBotsActual ? "Sí" : "No" },
                        { etiqueta: "Pregunta al extender", valor: preguntarExtensionActual ? "Sí" : "No" }
                    ].concat(codigoSalaPropia !== ""
                        ? [{ etiqueta: "Código de invitación", valor: codigoSalaPropia }]
                        : [])
                    delegate: Row {
                        required property var modelData
                        width: parent.width
                        Text {
                            width: parent.width - 80 * Tema.escala
                            text: modelData.etiqueta
                            color: Tema.colorTextoTenue
                            font.pixelSize: 12 * Tema.escala
                        }
                        Text {
                            text: modelData.valor
                            color: "white"
                            font.pixelSize: 12 * Tema.escala
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            // ── Cuenta: invitados ven un aviso + acceso a login/registro en
            // vez de la gestión de cuenta (que no tiene sentido sin sesión).
            Column {
                width: parent.width
                visible: ventana.pestanaAjustesActual === 1 && tokenSesion === ""
                spacing: 14 * Tema.escala

                Text {
                    text: "CUENTA"
                    color: Tema.colorTextoMuyTenue
                    font.pixelSize: 11 * Tema.escala
                    font.letterSpacing: 1
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Estás jugando como invitado. Inicia sesión o crea una cuenta para poder cambiar tu nombre de usuario o tu contraseña."
                    color: Tema.colorTextoTenue
                    font.pixelSize: 12 * Tema.escala
                }
                BotonRelleno {
                    text: "Iniciar sesión"
                    onClicked: {
                        ajustesAbiertos = false;
                        mensajeErrorLogin = "";
                        pantalla = "Login";
                    }
                }
                BotonContorno {
                    text: "Crear cuenta"
                    onClicked: {
                        ajustesAbiertos = false;
                        mensajeErrorLogin = "";
                        pantalla = "Registro";
                    }
                }
            }

            // ── Cuenta: con sesión activa, gestión real (cambiar
            // usuario/contraseña, cerrar sesión). ─────────────────────────
            Column {
                width: parent.width
                visible: ventana.pestanaAjustesActual === 1 && tokenSesion !== ""
                spacing: 10 * Tema.escala

                Text {
                    text: "CUENTA"
                    color: Tema.colorTextoMuyTenue
                    font.pixelSize: 11 * Tema.escala
                    font.letterSpacing: 1
                }

                Row {
                    width: parent.width
                    Text {
                        width: parent.width - 80 * Tema.escala
                        text: "Usuario"
                        color: Tema.colorTextoTenue
                        font.pixelSize: 12 * Tema.escala
                    }
                    Text {
                        text: nombreUsuario.text
                        color: "white"
                        font.pixelSize: 12 * Tema.escala
                        font.bold: true
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // ── Estadísticas propias -- mismos datos que alimentan el
                // Ranking (ver AccountManager::obtenerEstadisticas()).
                // Ocultas hasta la primera partida contada (ver
                // MIN_MANOS_PARA_STATS/MIN_CUENTAS_REALES_PARA_STATS en
                // NetworkObserver.cpp): 0 partidas jugadas no distingue
                // "invitado nunca jugó" de "cuenta nueva" -- no aporta nada
                // mostrarlo a cero.
                Column {
                    width: parent.width
                    visible: statsPartidasJugadas > 0
                    spacing: 6 * Tema.escala
                    Repeater {
                        model: [
                            { etiqueta: "Partidas jugadas", valor: statsPartidasJugadas + "" },
                            { etiqueta: "Partidas ganadas", valor: statsPartidasGanadas + "" },
                            { etiqueta: "Ratio de victorias", valor: Math.round(100 * statsPartidasGanadas / statsPartidasJugadas) + "%" },
                            { etiqueta: "Manos jugadas", valor: statsManosJugadas + "" },
                            { etiqueta: "Fichas netas", valor: (statsFichasNetas >= 0 ? "+" : "") + statsFichasNetas }
                        ]
                        delegate: Row {
                            required property var modelData
                            width: parent.width
                            Text {
                                width: parent.width - 80 * Tema.escala
                                text: modelData.etiqueta
                                color: Tema.colorTextoTenue
                                font.pixelSize: 12 * Tema.escala
                            }
                            Text {
                                text: modelData.valor
                                color: modelData.etiqueta === "Fichas netas"
                                       ? (statsFichasNetas >= 0 ? Tema.colorAccent : Tema.colorPeligro)
                                       : "white"
                                font.pixelSize: 12 * Tema.escala
                                font.bold: true
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }

                TextField {
                    id: campoNuevoUsername
                    width: parent.width
                    color: "white"
                    font.pixelSize: 13 * Tema.escala
                    placeholderText: (activeFocus || text.length > 0) ? "" : "Nuevo nombre de usuario"
                    placeholderTextColor: Tema.colorTextoMuyTenue
                    background: Rectangle {
                        color: "transparent"
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: campoNuevoUsername.activeFocus ? Tema.colorAccent : Tema.colorBorde
                        }
                    }
                    onAccepted: botonCambiarUsername.clicked()
                }
                BotonContorno {
                    id: botonCambiarUsername
                    text: "Cambiar nombre de usuario"
                    onClicked: {
                        if (campoNuevoUsername.text.length < 3) {
                            mensajeErrorLogin = "El nombre de usuario debe tener al menos 3 caracteres.";
                            return;
                        }
                        mensajeErrorLogin = "";
                        redcliente.cambiarNombreUsuario(servidorHost, servidorPuerto,
                                                        tokenSesion, campoNuevoUsername.text);
                    }
                }

                TextField {
                    id: campoPasswordActualCuenta
                    width: parent.width
                    color: "white"
                    font.pixelSize: 13 * Tema.escala
                    echoMode: TextInput.Password
                    placeholderText: (activeFocus || text.length > 0) ? "" : "Contraseña actual"
                    placeholderTextColor: Tema.colorTextoMuyTenue
                    background: Rectangle {
                        color: "transparent"
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: campoPasswordActualCuenta.activeFocus ? Tema.colorAccent : Tema.colorBorde
                        }
                    }
                    onAccepted: campoPasswordNuevaCuenta.forceActiveFocus()
                }
                TextField {
                    id: campoPasswordNuevaCuenta
                    width: parent.width
                    color: "white"
                    font.pixelSize: 13 * Tema.escala
                    echoMode: TextInput.Password
                    placeholderText: (activeFocus || text.length > 0) ? "" : "Contraseña nueva (8+ caracteres)"
                    placeholderTextColor: Tema.colorTextoMuyTenue
                    background: Rectangle {
                        color: "transparent"
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: campoPasswordNuevaCuenta.activeFocus ? Tema.colorAccent : Tema.colorBorde
                        }
                    }
                    onAccepted: botonCambiarPassword.clicked()
                }
                BotonContorno {
                    id: botonCambiarPassword
                    text: "Cambiar contraseña"
                    onClicked: {
                        if (campoPasswordActualCuenta.text.length === 0) {
                            mensajeErrorLogin = "Escribe tu contraseña actual.";
                            return;
                        }
                        if (campoPasswordNuevaCuenta.text.length < 8) {
                            mensajeErrorLogin = "La contraseña nueva debe tener al menos 8 caracteres.";
                            return;
                        }
                        mensajeErrorLogin = "";
                        redcliente.cambiarPassword(servidorHost, servidorPuerto, tokenSesion,
                                                   campoPasswordActualCuenta.text, campoPasswordNuevaCuenta.text);
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: Tema.colorPeligro
                    font.pixelSize: 11 * Tema.escala
                    text: mensajeErrorLogin
                    visible: mensajeErrorLogin !== ""
                }

                BotonContorno {
                    text: "Cerrar sesión"
                    colorBorde: Tema.colorPeligro
                    onClicked: {
                        ajustesAbiertos = false;
                        redcliente.cerrarSesion(servidorHost, servidorPuerto, tokenSesion);
                    }
                }
            }

            // ── Cliente ────────────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 10 * Tema.escala
                visible: ventana.pestanaAjustesActual === 0

                Text {
                    text: "CLIENTE"
                    color: Tema.colorTextoMuyTenue
                    font.pixelSize: 11 * Tema.escala
                    font.letterSpacing: 1
                }

                Row {
                    width: parent.width
                    Text {
                        width: parent.width - 46
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Sonido de notificaciones"
                        color: Tema.colorTextoTenue
                        font.pixelSize: 13 * Tema.escala
                        wrapMode: Text.WordWrap
                    }
                    Interruptor {
                        anchors.verticalCenter: parent.verticalCenter
                        activo: sonidoActivado
                        onAlternado: sonidoActivado = !sonidoActivado
                    }
                }
                Row {
                    width: parent.width
                    Text {
                        width: parent.width - 46
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Confirmar antes de ALL-IN"
                        color: Tema.colorTextoTenue
                        font.pixelSize: 13 * Tema.escala
                        wrapMode: Text.WordWrap
                    }
                    Interruptor {
                        anchors.verticalCenter: parent.verticalCenter
                        activo: confirmarAllIn
                        onAlternado: confirmarAllIn = !confirmarAllIn
                    }
                }
                Row {
                    width: parent.width
                    spacing: 8 * Tema.escala
                    Text {
                        // 118 le dejaba muy poco margen a "−"/"%"/"+" (se
                        // recortaban) -- ensanchar el cajón por sí solo no
                        // arreglaba esto: esta resta es un presupuesto FIJO,
                        // así que todo el ancho de más se lo llevaba la
                        // etiqueta en vez de los botones.
                        width: parent.width - 150 * Tema.escala
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Tamaño de la interfaz"
                        color: Tema.colorTextoTenue
                        font.pixelSize: 13 * Tema.escala
                        wrapMode: Text.WordWrap
                    }
                    // Mismo control que Ctrl+/Ctrl-/Ctrl+0 (ver Main.qml,
                    // Shortcut) — para quien no conozca el atajo de
                    // teclado o esté en una máquina donde no funcione.
                    // Sin width/height explícitos: igual que cualquier
                    // otro BotonContorno, su tamaño lo da el padding/font
                    // ya escalados — fijarlo a 32x32 recortaría el glifo
                    // a zoom alto, porque el texto interior sí crece.
                    BotonContorno {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "−"
                        onClicked: Tema.bajarZoom()
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        horizontalAlignment: Text.AlignHCenter
                        text: Math.round(Tema.zoomManual * 100) + "%"
                        color: Tema.colorAccent
                        font.bold: true
                        font.pixelSize: 13 * Tema.escala
                    }
                    BotonContorno {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+"
                        onClicked: Tema.subirZoom()
                    }
                }

                // Chuleta de manos — acordeón simple, plegado por defecto.
                // Pensado para amigos con distinto nivel de experiencia
                // jugando en la misma mesa.
                Column {
                    width: parent.width
                    spacing: 8 * Tema.escala
                    Item {
                        // Antes el MouseArea era hijo del Row de arriba —
                        // un Row coloca a sus hijos EN FILA, así que el
                        // MouseArea quedaba puesto a la derecha del texto
                        // en vez de encima suyo, y el clic no tocaba nada.
                        // Con un Item como contenedor y el MouseArea
                        // anclado a rellenarlo entero, sí cubre el texto.
                        width: parent.width
                        height: textoRanking.height
                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6 * Tema.escala
                            Text {
                                id: textoRanking
                                text: "Ranking de manos"
                                color: Tema.colorTextoTenue
                                font.pixelSize: 13 * Tema.escala
                            }
                            Text {
                                text: chuletaAbierta ? "▲" : "▼"
                                color: Tema.colorTextoMuyTenue
                                font.pixelSize: 10 * Tema.escala
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: chuletaAbierta = !chuletaAbierta
                        }
                    }
                    // Chuleta "de verdad": una fila de 5 cartas por cada
                    // combinación, como la que viene con una baraja física
                    // — mucho más rápida de leer que una lista de nombres.
                    Column {
                        width: parent.width
                        visible: chuletaAbierta
                        spacing: 10 * Tema.escala
                        Repeater {
                            model: [
                                { nombre: "1. Escalera Real", cartas: ["AS", "KS", "QS", "JS", "TS"] },
                                { nombre: "2. Escalera Color", cartas: ["9H", "8H", "7H", "6H", "5H"] },
                                { nombre: "3. Póker", cartas: ["KS", "KH", "KD", "KC", "5S"] },
                                { nombre: "4. Full House", cartas: ["JS", "JH", "JD", "4C", "4S"] },
                                { nombre: "5. Color", cartas: ["AC", "JC", "8C", "6C", "2C"] },
                                { nombre: "6. Escalera", cartas: ["TS", "9H", "8D", "7C", "6S"] },
                                { nombre: "7. Trío", cartas: ["7S", "7H", "7D", "KC", "2S"] },
                                { nombre: "8. Doble Pareja", cartas: ["QS", "QH", "9D", "9C", "4S"] },
                                { nombre: "9. Pareja", cartas: ["TS", "TH", "KD", "6C", "2S"] },
                                { nombre: "10. Carta Alta", cartas: ["AS", "JH", "8D", "6C", "3S"] }
                            ]
                            delegate: Column {
                                required property var modelData
                                required property int index
                                width: parent.width
                                spacing: 4 * Tema.escala
                                Text {
                                    text: modelData.nombre
                                    color: index < 3 ? Tema.colorAccent : Tema.colorTextoTenue
                                    font.bold: index < 3
                                    font.pixelSize: 12 * Tema.escala
                                }
                                Row {
                                    spacing: 3 * Tema.escala
                                    Repeater {
                                        model: modelData.cartas
                                        delegate: Carta {
                                            required property string modelData
                                            codigo: modelData
                                            // Mismo componente Carta de la mesa, solo
                                            // más pequeño — el tamaño de fuente interno
                                            // ya es proporcional a "width". Lo más grande
                                            // que cabe sin desbordar el cajón (300 de
                                            // ancho, 22 de margen a cada lado): 5 cartas
                                            // + 4 huecos de separación ≤ 256.
                                            width: 46 * Tema.escala
                                            height: 64 * Tema.escala
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        }
    }
}
