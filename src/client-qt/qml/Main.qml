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
// QtCore en vez de Qt.labs.settings (2026-09-10): el de labs está
// obsoleto y avisaba en cada arranque. Mismo backend -- comprobado con
// el runtime de Qt 6 que QtCore.Settings lee lo que escribió el viejo
// con la misma category, así que nadie pierde su sesión al actualizar.
// Existe desde Qt 6.5; el CI más viejo (Android) usa 6.7.3.
import QtCore
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
    // (ver cmake/ClientesQt.cmake, RESOURCES de qt_add_qml_module) y se carga aquí.
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
        // Aviso de versión antigua: en segundo plano, sin bloquear nada de
        // lo de arriba -- si falla (sin red, API caída) no pasa nada, ver
        // VersionChecker.hpp.
        versionChecker.comprobar();
    }
    Connections {
        target: versionChecker
        function onHayVersionNuevaChanged() {
            if (versionChecker.hayVersionNueva) {
                bannerVersionNueva.mostrar(versionChecker.versionRemota, versionChecker.urlRelease);
            }
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
    // Modo offline (Torneos > Solitario, Fase 6/7 -- ver
    // docs/plan-modo-offline.md) -- true SOLO mientras "redcliente" está
    // reasignado a LocalGameClient (modoJuego.activarModoLocal()). Los
    // MISMOS handlers de fin de partida que ya usa el flujo online
    // (onFinDePartida/onAbandonaste/onPartidaGuardada) lo comprueban para
    // devolver "redcliente" a NetworkClient antes de que la pantalla
    // "Fin" pueda intentar usarlo para algo de red de verdad.
    property bool modoOfflineActivo: false
    // Distinto de modoOfflineActivo: eso es "redcliente apunta AHORA MISMO
    // al cliente local"; esto es "toda la sesión es sin conexión" (se entró
    // por 'Jugar sin conexión' en Inicio). En una sesión offline, redcliente
    // se queda en local para siempre y el riel va reducido; jugando un
    // Solitario estando conectado, en cambio, solo dura lo que dura la
    // partida y luego se vuelve a red. Ver docs/plan-modo-offline.md.
    property bool sesionOffline: false
    // Identidad con la que se entró sin conexión: true = cuenta cacheada de
    // la última sesión con servidor, false = invitado (sandbox puro, sin
    // nada persistido). Ver LocalGameClient::hayIdentidadCacheada().
    property bool offlineConCuenta: false
    // "¿Hay una cuenta detrás de esta sesión?" para decidir qué PINTAR.
    // Ojo: NO sustituye a tokenSesion en los guards de llamadas de red
    // (esos preguntan "¿tengo un token que mandar?", y offline no lo hay).
    // Sin esto, Cuenta enseñaba "estás jugando como invitado" en una sesión
    // offline con cuenta cacheada, porque miraba solo el token -- que
    // offline está vacío por definición (bug reportado en vivo).
    readonly property bool hayCuenta: tokenSesion !== "" || offlineConCuenta
    // Cuenta se mudó al riel (2026-08-31) -- el cajón ya solo tiene
    // "Ajustes" (tema/mesa/cliente), así que ya no hace falta consultar
    // estadísticas al abrirlo (eso ahora lo hace onSeccionElegida() al
    // entrar en "Cuenta"), ni recordar una pestaña que ya no existe --
    // solo queda volver el scroll al principio al cerrar.
    onAjustesAbiertosChanged: {
        if (!ajustesAbiertos && scrollAjustes.contentItem) {
            scrollAjustes.contentItem.contentY = 0;
        }
    }
    // Pestaña activa de la pantalla Cuenta (riel): 0=Perfil, 1=Progreso,
    // 2=Logros. Sin persistir, mismo criterio que pestanaSocialActual.
    property int pestanaCuentaActual: 0
    // Bug real reportado 2026-09-02 (visto primero en móvil, mismo
    // componente aquí): las 4 pestañas comparten el MISMO Flickable
    // (scrollCuenta) -- solo cambia qué Column interna es visible, la
    // instancia nunca se destruye. Sin esto, si bajabas del todo en una
    // pestaña y cambiabas a otra, esa otra se abría igual de bajada
    // (contentY sobrevive al cambio de pestaña).
    onPestanaCuentaActualChanged: scrollCuenta.contentY = 0
    // Formularios de cambiar usuario/contraseña de la pestaña Perfil,
    // colapsados detrás de un botón hasta que se pulsa (pedido explícito
    // 2026-08-31: antes los campos estaban siempre puestos, ocupando
    // sitio aunque no se fueran a usar).
    property bool formularioUsernameAbierto: false
    property bool formularioPasswordAbierto: false
    // Resultado de exportarEstadisticas() (Fase 1 del sistema de
    // progresión, solo visible para cuentas admin) -- ver
    // estadisticasCuenta.esAdmin y las Connections de redcliente más abajo.
    property string mensajeExportacion: ""
    // Herramienta de pruebas/admin, punto 2 de la prioridad confirmada
    // (2026-09-01, ver memoria qt_progression_review_2026_09_01) -- mismo
    // criterio que mensajeExportacion de arriba.
    property string mensajeAdminConceder: ""
    // Segunda mitad del punto 2 (mismo día) -- mismo criterio.
    property string mensajeAdminFabricar: ""
    // Fase 2 del sistema de progresión: nivel/progreso calculado a partir
    // de estadisticasCuenta.xpTotal -- binding vivo, se recalcula solo
    // cada vez que estadisticasCuenta cambia (ver progresoNivel() más
    // abajo). Property en vez de llamar a la función suelta en cada sitio
    // que la necesita -- evita repetir el mismo cálculo 3 veces por bind.
    property var progresoNivelActual: progresoNivel(redcliente.estadisticasCuenta.xpTotal || 0)
    // Pestaña activa de la pantalla Social: 0=Amigos, 1=Buscar jugadores,
    // 2=Jugadores Recientes, 3=Solicitudes. Mismo criterio sin persistir
    // que pestanaCuentaActual.
    property int pestanaSocialActual: 0
    // Ajustes de cliente (sección "Cliente" del cajón). Desactivado por
    // defecto a propósito (pedido explícito) — quien lo quiera, lo activa
    // él mismo una vez y queda recordado (ver Settings arriba).
    property bool sonidoActivado: false

    // Aviso de "tu turno" — dos tonos sintetizados, ver assets/sonidos/.
    SoundEffect {
        id: sonidoTurno
        source: "qrc:/qt/qml/PokerQuick/assets/sonidos/turno.wav"
    }
    // Crash real en producción (backtrace con gdb, 2026-08-28):
    // "corrupted double-linked list" / SIGABRT SIEMPRE al cerrar la
    // ventana, dentro de pw_stream_destroy() (PipeWire) llamado desde
    // QRtAudioEngine::~QRtAudioEngine() -- el motor de audio de
    // QtMultimedia se destruye en cascada junto con el resto del árbol de
    // QObject cuando ~QQmlApplicationEngine() tira la ventana abajo,
    // FUERA del bucle de eventos ya funcionando con normalidad. Sin
    // relación con NetworkClient/presencia (confirmado en el backtrace).
    // Parando el sonido (y soltando su "source", lo que libera el stream
    // de PipeWire de verdad) en cuanto se sabe que la app va a cerrar --
    // mientras el bucle de eventos SIGUE vivo -- el stream se cierra
    // limpio en vez de quedar a medio destruir cuando le toca el turno en
    // la cascada de destructores.
    Connections {
        target: Qt.application
        function onAboutToQuit() {
            sonidoTurno.stop();
            sonidoTurno.source = "";
        }
    }
    property bool confirmarAllIn: false
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
    // "Entrando…" en el botón mientras viaja el login: con el margen de 12 s
    // de las peticiones de cuenta (NetworkClient::kTimeoutCuentaMs), sin esto
    // parecía que el botón no hacía nada, y se pulsaba otra vez.
    property bool enviandoLogin: false
    // Ver onReautenticacionSinRespuesta.
    property bool reautenticacionPendiente: false
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
    // El sala_id propio -- antes solo lo conocía quien CREABA la sala
    // (nunca se guardaba en ningún sitio, ver SALA_CREADA); ahora también
    // llega al unirse (SALA_UNIDA, mismo evento del lado NetworkClient::
    // salaCreada). Necesario para invitarASala() desde la sala de espera.
    property string salaIdPropia: ""
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
    // 0 = más victorias, 1 = mejor ratio, 2 = Elo (Fase 3 del sistema de
    // progresión -- pestaña por defecto al ENTRAR a esta pantalla, ver
    // onSeccionElegida más abajo, aunque no sea la primera de la lista:
    // mide habilidad, no dedicación, así que es la que de verdad importa).
    property int ordenRankingActual: 2
    ListModel {
        id: rankingModel
    }
    // Podio (2026-09-01, ver memoria qt_progression_review_2026_09_01) --
    // top 3 de la pestaña activa, en un bloque grande aparte de la lista
    // normal. Array de JS normal (máximo 3 elementos, no hace falta un
    // ListModel) reconstruido en cada reordenarRanking() junto con
    // rankingModel. "" (longitud 0) si aún no hay al menos 3 cuentas en el
    // ranking -- entonces la lista de siempre se ve completa desde el 1º,
    // sin podio a medias.
    property var rankingPodio: []
    // ── Logros (Fase 4 del sistema de progresión) ────────────────────────
    ListModel {
        id: logrosModel
    }
    // ── Tienda (Fase 5 del sistema de progresión) ────────────────────────
    // tiendaCrudo guarda el catálogo entero tal cual llegó -- reordenarTienda()
    // reconstruye tiendaModel (lo que de verdad pinta la pestaña activa,
    // Marco o Perfil) sin pedir nada nuevo al servidor solo por cambiar de
    // sub-pestaña, mismo criterio que rankingCrudo/rankingModel.
    property var tiendaCrudo: []
    property int pestanaTiendaActual: 0  // 0 = Marco (textura/efecto/decoraciones), 1 = Perfil (títulos)
    // Cuenta > Personalizar (2026-09-01, "Tienda" ya no vive aquí -- ver el
    // riel) -- 4 pestañas para EQUIPAR lo que ya tienes, sin precios ni
    // botón de Comprar (eso se quedó en Tienda). Sin pestaña "Marco" --
    // se quitó el mismo día ("en personalizar no vamos a duplicar
    // progreso"), ese contenido vive ahora en Progreso.
    property int pestanaPersonalizarActual: 0  // 0=Texturas,1=Efectos,2=Decoraciones,3=Títulos
    property string mensajeTienda: ""
    // Búsqueda en vivo del catálogo (pedido explícito 2026-08-31: "añade
    // facilidad al buscar") -- filtra por nombre, sin distinguir
    // mayúsculas/minúsculas, sobre lo que ya haya en tiendaCrudo (sin
    // pedir nada nuevo al servidor, igual que el cambio de pestaña
    // Marco/Perfil de justo aquí abajo).
    property string busquedaTienda: ""
    // Carta elegida en PopupSeleccionCarta -- "" = ninguna. Segunda
    // ronda de la baraja (pedido explícito 2026-08-31): el popup solo
    // ELIGE (y se cierra); comprar/equipar de verdad pasa por los
    // botones de la propia tarjeta "Carta de póker" de abajo, que miran
    // esta property para saber cuál es "la elegida".
    property string cartaSeleccionada: ""
    function infoCartaSeleccionada() {
        for (var i = 0; i < tiendaCrudo.length; i++) {
            if (tiendaCrudo[i].codigo === cartaSeleccionada) return tiendaCrudo[i];
        }
        return null;
    }
    // Búsqueda genérica por código sobre el catálogo ya cargado -- el
    // catálogo es el mismo para cualquier cuenta (no hay precios/nombres
    // por jugador), así que sirve tanto para resolver TU título equipado
    // (redcliente.loadoutMarco.titulo) como el de OTRO jugador (perfil
    // público) sin pedir nada nuevo al servidor. "" o sin catálogo
    // cargado todavía -- null (usado por CajaTitulo.qml).
    function objetoTiendaPorCodigo(codigo) {
        if (codigo === "") return null;
        for (var i = 0; i < tiendaCrudo.length; i++) {
            if (tiendaCrudo[i].codigo === codigo) return tiendaCrudo[i];
        }
        return null;
    }
    // Título propio equipado, ya resuelto (nombre+rareza) -- consumido
    // por CajaTitulo.qml en Perfil. Se re-evalúa sola tanto si cambia el
    // loadout como si termina de cargar el catálogo (las dos son
    // propiedades normales de QML/Qt, ambas con notificación).
    readonly property var infoTituloPropio: objetoTiendaPorCodigo(redcliente.loadoutMarco.titulo || "")

    // ── Cuenta > Personalizar (2026-09-01) ────────────────────────────────
    // Categoría(s) de shop_items que corresponde a cada pestaña de
    // Personalizar. Un solo sitio para este mapeo -- lo usan tanto el
    // filtro de abajo como (si hiciera falta en el futuro) cualquier otro
    // sitio que necesite lo mismo.
    function categoriasPersonalizar(indice) {
        if (indice === 0) return ["textura"];
        if (indice === 1) return ["efecto"];
        if (indice === 2) return ["decoracion_lateral", "decoracion_superior"];
        if (indice === 3) return ["titulo"];
        return [];
    }
    // Objetos YA POSEÍDOS de la pestaña activa -- la rejilla de Personalizar
    // solo equipa, nunca compra, así que a diferencia de reordenarTienda()
    // (que lista el catálogo entero) esto filtra a poseido===1 sin más.
    readonly property var itemsPersonalizar: {
        var cats = categoriasPersonalizar(pestanaPersonalizarActual);
        return tiendaCrudo.filter(function(o) {
            return o.poseido === 1 && cats.indexOf(o.categoria) >= 0;
        });
    }
    // Objeto bajo el cursor/seleccionado en la tienda, para la
    // previsualización en vivo del avatar -- "" = ninguno, se ve el
    // marco REAL equipado. Solo tiene efecto mientras estás en la pestaña
    // Tienda; nunca se guarda nada hasta pulsar "Equipar" de verdad.
    property string previewCodigo: ""
    property string previewCategoria: ""
    ListModel {
        id: tiendaModel
    }
    function reordenarTienda() {
        var categoriasMarco = ["textura", "efecto", "decoracion_lateral", "decoracion_superior"];
        var busqueda = busquedaTienda.trim().toLowerCase();
        var esCartaBaraja = function(o) { return o.codigo.indexOf("carta_") === 0; };

        // Las 52 cartas sueltas NO se listan como tarjetas propias -- van
        // todas dentro del selector "+" (PopupSeleccionCarta), ver más
        // abajo. Sin esto la rejilla entera de la pestaña Marco serían
        // solo cartas.
        var filas = tiendaCrudo.filter(function(o) {
            if (esCartaBaraja(o)) return false;
            var pasaPestana = ventana.pestanaTiendaActual === 0
                   ? categoriasMarco.indexOf(o.categoria) >= 0
                   : o.categoria === "titulo";
            var pasaBusqueda = busqueda === "" || o.nombre.toLowerCase().indexOf(busqueda) >= 0;
            return pasaPestana && pasaBusqueda;
        });

        // Una única tarjeta sintética representando la baraja entera --
        // "poseido"/"equipado" reflejan si TIENES o llevas puesta alguna
        // carta cualquiera, para que el borde/etiqueta de la tarjeta se
        // comporte igual que las demás sin necesitar 52 tarjetas sueltas.
        if (ventana.pestanaTiendaActual === 0) {
            var cartas = tiendaCrudo.filter(esCartaBaraja);
            var nombreBaraja = "Carta de póker";
            var pasaBusquedaBaraja = busqueda === "" || nombreBaraja.toLowerCase().indexOf(busqueda) >= 0;
            if (pasaBusquedaBaraja && cartas.length > 0) {
                var algunaPoseida = cartas.some(function(c) { return c.poseido === 1; });
                var lateral1 = redcliente.loadoutMarco.decoracionLateral1 || "";
                var lateral2 = redcliente.loadoutMarco.decoracionLateral2 || "";
                var algunaEquipada = cartas.some(function(c) {
                    return c.codigo === lateral1 || c.codigo === lateral2;
                });
                filas.push({
                    codigo: "_baraja",
                    categoria: "decoracion_lateral",
                    nombre: nombreBaraja,
                    precioTreboles: 30,
                    nivelMinimo: 1,
                    esDeLogro: 0,
                    poseido: algunaPoseida ? 1 : 0,
                    equipado: algunaEquipada ? 1 : 0
                });
            }
        }

        tiendaModel.clear();
        for (var i = 0; i < filas.length; i++) tiendaModel.append(filas[i]);
    }
    // Iconos de decoración (Fase 5, game-icons.net) -- MISMO criterio que
    // Avatar.qml::rutaIconoDecoracion() (simplificado igual, 2026-09-01):
    // el nombre de fichero es el propio código, así que una decoración
    // SIMPLE nueva no toca esta función. La Tienda necesita el icono de
    // un CÓDIGO suelto (sin un Avatar instanciado detrás) así que no vale
    // la pena inventar un singleton compartido solo para reusar la de
    // Avatar.qml -- de ahí la categoría como segundo parámetro, para
    // distinguir "decoración sin icono todavía" (no debería pasar) de
    // "textura/efecto/título, que no son un objeto dibujable" (siempre
    // "", oculta la miniatura sin más).
    function rutaIconoObjetoTienda(codigo, categoria) {
        var base = "qrc:/qt/qml/PokerQuick/assets/iconos/";
        // "palos_en_fila" tenía aquí su propio case (devolvía suit_club.png
        // como representante de los cuatro palos). Desde 2026-09-09 la
        // placa con los cuatro va compuesta en el propio PNG
        // (scripts/generar_iconos.sh), así que cumple la regla del nombre
        // y cae sola en el return de más abajo -- un caso especial menos.
        switch (codigo) {
        case "": return "";
        case "mano_real":
            return base + "carta_ace_picas.png";  // representativo -- el avatar sí compone el arco de 5
        case "escalera_diamantes":
            return base + "carta_7_diamantes.png";  // representativo -- el avatar sí compone el arco de 5
        case "cuatro_ases":
            return base + "carta_ace_corazones.png";  // representativo -- el avatar sí compone el arco de 4
        case "_baraja":
            return base + "carta_ace_picas.png";  // representativo -- el selector "+" tiene las 52
        }
        if (categoria === "decoracion_lateral" || categoria === "decoracion_superior") {
            return base + codigo + ".png";
        }
        // Un símbolo genérico por categoría (no por objeto suelto, a
        // diferencia de las decoraciones) -- pedido explícito 2026-09-02:
        // "necesitamos un simbolo de efecto y textura para poner en las
        // esquinas de las tarjetas que ahora mismo estan vacias". Gema
        // facetada (lorc_gems, game-icons.net) para textura, llama
        // (carl-olsen_flame, game-icons.net) para efecto -- las dos
        // recoloreadas al dorado del tema al convertirlas, igual que el
        // resto del catálogo de iconos.
        if (categoria === "textura") return base + "textura_generica.png";
        if (categoria === "efecto") return base + "efecto_generico.png";
        return "";
    }
    // El valor a pintar en el Avatar de previsualización para una capa
    // concreta -- el objeto bajo preview si es de ESA categoría, si no el
    // que ya tengas equipado de verdad (redcliente.loadoutMarco).
    // Prioridad: 1) hover transitorio (solo mientras el cursor está
    // encima del cuadro), 2) lo que ya llevas puesto de verdad. SIN
    // estado pegajoso -- la carta elegida en el selector usa esta MISMA
    // regla que cualquier otro objeto de la tienda (ver el MouseArea de
    // la tarjeta "_baraja" más abajo, que dispara el hover con
    // cartaSeleccionada como código). Antes ( 2026-08-31→2026-09-01) la
    // carta elegida se quedaba fija en la preview sin soltar el ratón --
    // pedido explícito 2026-09-01: "solo debería aparecer cuando estés
    // encima del cuadro con el cursor", igual que el resto.
    function valorPreview(categoria, valorReal) {
        if (previewCategoria === categoria && previewCodigo !== "") return previewCodigo;
        return valorReal || "";
    }
    // Cambia el objeto en preview de una sola vez. El orden importa: con
    // la categoría nueva y el código VIEJO todavía puesto, valorPreview()
    // se re-evalúa en medio y le pasa ese código a otra capa -- pasar de
    // una textura a una decoración superior pintaba un instante la textura
    // como decoración ("Cannot open: .../iconos/facetado.png", log del
    // 2026-09-10). Vaciando antes el código, todo paso intermedio es "sin
    // preview", que es un estado válido.
    function fijarPreview(categoria, codigo) {
        previewCodigo = "";
        previewCategoria = categoria;
        previewCodigo = codigo;
    }
    // Acabado en la vista previa: el de la decoración que llevas puesta,
    // salvo que estés previsualizando OTRA de esa categoría -- entonces el
    // del marco (""), que es con el que se equiparía por defecto.
    function acabadoPreview(categoria, codigoReal, acabadoReal) {
        if (previewCategoria === categoria && previewCodigo !== "" && previewCodigo !== codigoReal) return "";
        return acabadoReal || "";
    }

    // ── Acabado al equipar (fase 2 del material) ─────────────────────────
    // Pedido del usuario (2026-09-10): "al equipar un cosmético que tiene
    // color intercambiable, antes de equiparse salta una ventana flotante
    // donde eliges el color, y luego sigue la asignación normal". Solo si es
    // una decoración de metal y hay de verdad dónde elegir (con marco de
    // hierro solo cabe el hierro); quitar (codigo "") nunca pregunta. Para
    // cambiarle el metal a una que ya llevas: quitarla y volver a equiparla.
    readonly property string marcoPropio: Tema.marcoPorPartidasGanadas(statsPartidasGanadas, statsTieneMarcoBasico)
    // Sin marco todavía (ninguna partida ganada), los accesorios se
    // previsualizan con Hierro -- el marco de la primera victoria -- y un
    // aviso bajo el avatar lo dice (decisión del usuario, 2026-09-10). Antes
    // salía el avatar sin marco, y todo lo que se monta sobre el metal
    // (engaste de las gemas, respaldo de los naipes, aro del "pulso") se
    // pintaba en negro. Los títulos no pasan por aquí: no van en el marco.
    readonly property bool sinMarcoPropio: Tema.metalesHasta(marcoPropio).length === 0
    readonly property bool previsualizandoConHierro: sinMarcoPropio && previewCodigo !== "" && previewCategoria !== "titulo"
    readonly property string marcoPreview: previsualizandoConHierro ? "hierro" : marcoPropio
    function equiparConAcabado(slot, codigo) {
        if (codigo === "" || !Tema.decoracionesMetalicas[codigo] || Tema.metalesHasta(marcoPropio).length < 2) {
            redcliente.equiparObjeto(servidorHost, servidorPuerto, tokenSesion, slot, codigo);
            return;
        }
        popupAcabado.abrir(slot, codigo, marcoPropio);
    }

    // ── Progreso de marco de avatar (pestaña Cuenta > Progreso) ──────────
    // Mismos umbrales que Tema.marcoPorPartidasGanadas() -- duplicados a
    // propósito aquí como una progresión explícita (anterior→siguiente),
    // en vez de reescribir esa función para que devuelva más que un
    // nombre de marco.
    function nombreMarco(m) {
        return m === "platino" ? "Platino" : m === "oro" ? "Oro" : m === "plata" ? "Plata"
               : m === "bronce" ? "Bronce" : m === "hierro" ? "Hierro" : "Sin marco";
    }
    // tieneMarcoBasico: si ya tienes Hierro por haber ganado CUALQUIER
    // partida (también con bots, ver statsTieneMarcoBasico), el siguiente
    // marco de verdad es Bronce, aunque n (partidasGanadas, con el
    // antifarm de siempre) siga en 0 -- si no, la barra de progreso
    // pediría "1/1" para un marco que ya tienes.
    function nombreProximoMarco(n, tieneMarcoBasico) {
        if (n < 1 && !tieneMarcoBasico) return "Hierro";
        if (n < 5) return "Bronce";
        if (n < 15) return "Plata";
        if (n < 25) return "Oro";
        if (n < 50) return "Platino";
        return "";  // ya en platino, no hay siguiente
    }
    function proximoUmbralMarco(n, tieneMarcoBasico) {
        if (n < 1 && !tieneMarcoBasico) return 1;
        if (n < 5) return 5;
        if (n < 15) return 15;
        if (n < 25) return 25;
        return 50;
    }
    // Sin tieneMarcoBasico a propósito: el progreso real hacia Bronce
    // siempre arranca en 0 partidas ganadas (con antifarm), tengas Hierro
    // por bots o no -- ese flag no adelanta nada de n.
    function umbralAnteriorMarco(n) {
        if (n < 1) return 0;
        if (n < 5) return 1;
        if (n < 15) return 5;
        if (n < 25) return 15;
        return 25;
    }
    // Estadísticas y loadout propios, pedidos al AUTENTICARSE y no solo al
    // entrar en Cuenta (que era el único sitio que los pedía). Dos motivos:
    //  - El modo sin conexión cachea lo último que contó el servidor (ver
    //    ModoJuegoCoordinador). Si nadie los pedía, la caché se quedaba
    //    solo con el nombre y la sesión offline entraba con tu cuenta pero
    //    sin nivel, sin XP y sin cosméticos -- indistinguible de un
    //    invitado (bug real, reportado en vivo).
    //  - El contador de Tréboles de la barra superior los lee igual
    //    (estadisticasCuenta.treboles), así que hasta ahora salía a 0
    //    hasta que visitaras Cuenta.
    function pedirDatosDeCuenta() {
        if (tokenSesion === "") return;
        redcliente.consultarEstadisticas(servidorHost, servidorPuerto, tokenSesion);
        redcliente.consultarLoadout(servidorHost, servidorPuerto, tokenSesion);
        // Logros también: la pestaña Logros es accesible sin conexión, y
        // solo se cachea lo que el servidor haya llegado a mandar.
        redcliente.consultarLogros(servidorHost, servidorPuerto, tokenSesion);
        // XP ganado sin conexión desde la última vez que hubo servidor. El
        // servidor lo acota (ver AccountManager::sincronizarXpOffline()), así
        // que la bolsa local solo se vacía al confirmar cuánto acreditó.
        if (modoJuego.xpOfflinePendiente > 0) {
            redcliente.sincronizarXpOffline(servidorHost, servidorPuerto, tokenSesion,
                                            modoJuego.xpOfflinePendiente);
        }
    }

    // ── Modo sin conexión (Fase 7) ────────────────────────────────────────
    // Entra en una sesión offline completa: "redcliente" pasa a ser el
    // cliente local para TODA la sesión (no solo durante una partida, ver
    // sesionOffline) y el riel se reduce a lo que funciona sin servidor.
    // @param conCuenta true = identidad cacheada de la última sesión con
    // servidor (nombre y cosméticos reales); false = invitado, sandbox puro.
    function entrarSinConexion(conCuenta) {
        // Sin nombre cacheado utilizable no hay "con cuenta" que valga --
        // antes esto habría dejado nombreUsuario vacío, que es peor que
        // entrar de invitado.
        var usarCuenta = conCuenta && modoJuego.usernameCacheado !== "";
        modoJuego.activarModoLocal();
        sesionOffline = true;
        modoOfflineActivo = true;
        offlineConCuenta = usarCuenta;
        // redcliente ya es el cliente local (activarModoLocal() arriba), así
        // que este método existe. Solo se acumula XP con cuenta: de invitado
        // no hay a quién acreditárselo.
        redcliente.setAcumularXpOffline(usarCuenta);
        nombreUsuario.text = usarCuenta ? modoJuego.usernameCacheado
                                        : "Invitado" + Math.floor(Math.random() * 100000);
        mensajeErrorConexion = "";
        // Torneos (Solitario) donde está habilitado. Si no -- los releases, ver
        // POKER_TORNEOS en cmake/ClientesQt.cmake --, Salas, que ya crea la
        // sala local.
        pantalla = torneosHabilitados ? "Torneos" : "Salas";
    }

    // Volver a Inicio desde una sesión offline la termina: se recupera el
    // cliente de red para que el sondeo de conexión (ver el Timer de más
    // abajo) vuelva a tener sentido y se pueda entrar con cuenta si el
    // servidor ya responde.
    onPantallaChanged: {
        if (pantalla === "Inicio" && sesionOffline) {
            sesionOffline = false;
            offlineConCuenta = false;
            modoOfflineActivo = false;
            modoJuego.activarModoRed();
        }
    }

    // Fase 2 del sistema de progresión (ver memoria qt_progression_system_design):
    // nivel 1→2 a 150 XP, cada nivel siguiente pide un 20% más que el
    // anterior (150 → 180 → 216 → 260...), sin techo -- números de
    // arranque, se recalibran con datos reales. El nivel se CALCULA aquí a
    // partir de xpTotal en vez de guardarse aparte en el servidor -- una
    // sola fuente de verdad, sin arrastrar dos números que podrían
    // desincronizarse.
    function progresoNivel(xpTotal) {
        var nivel = 1;
        var umbral = 150;
        var restante = xpTotal;
        while (restante >= umbral) {
            restante -= umbral;
            nivel++;
            umbral = Math.round(umbral * 1.2);
        }
        return { nivel: nivel, xpEnNivel: restante, xpParaSiguiente: umbral };
    }
    // Fase 4 del sistema de progresión: colores/etiquetas de rareza,
    // reutilizando los mismos tonos "materia prima" que ya usa Avatar.qml
    // para bronce/plata/oro (segunda parada de su degradado -- aquí, sin
    // degradado, un solo tono representativo basta para una insignia
    // pequeña).
    // Con "" (sin rareza -- objeto comprable suelto, no ligado a ningún
    // logro, p.ej. un título comprado con tréboles) caía en el "else"
    // de Bronce sin más -- un título comprado no debería verse como un
    // logro de verdad conseguido. Tono neutro (el mismo gris claro que
    // Avatar.qml usa para el tier Hierro) para ese caso, en vez de
    // fingir una rareza que no tiene.
    function colorRareza(r) {
        return r === "oro" ? "#e3bb82" : r === "plata" ? "#9aa4ab" : r === "bronce" ? "#c98f5f" : "#7d848f";
    }
    function etiquetaRareza(r) {
        return r === "oro" ? "Oro" : r === "plata" ? "Plata" : r === "bronce" ? "Bronce" : "";
    }
    function logrosDesbloqueados() {
        var n = 0;
        for (var i = 0; i < logrosModel.count; i++) {
            if (logrosModel.get(i).desbloqueado) n++;
        }
        return n;
    }
    // Orden fijo Bronce→Plata→Oro, desbloqueados siempre al final (sea
    // cual sea su rareza) -- pedido explícito 2026-08-31: "implementa un
    // mecanismo que siempre ordene por B,P,O, así solo añades [logros] y
    // se muestra ordenado". Con esto, un logro nuevo en el catálogo
    // (AccountManager.cpp) cae solo en su sitio -- no hay lista de orden
    // que mantener a mano en el cliente.
    function ordenarLogros(logros) {
        var rango = { "bronce": 0, "plata": 1, "oro": 2 };
        var copia = logros.slice();
        copia.sort(function(a, b) {
            if (a.desbloqueado !== b.desbloqueado) return a.desbloqueado ? 1 : -1;
            var ra = rango[a.rareza] !== undefined ? rango[a.rareza] : 99;
            var rb = rango[b.rareza] !== undefined ? rango[b.rareza] : 99;
            return ra - rb;
        });
        return copia;
    }
    // "Cuánto te queda" en el extremo derecho de la tarjeta -- pedido
    // explícito 2026-08-31. Solo para los logros con un contador
    // numérico de verdad ya expuesto al cliente (el resto son eventos
    // puntuales -- "termina una partida después de medianoche", "4+
    // amigos a la vez"-- sin una fracción que tenga sentido mostrar, o
    // "Manos de Hierro" cuya racha de manos seguidas no se guarda hoy
    // como stat consultable). "" oculta el indicador sin más.
    function progresoLogro(codigo) {
        if (codigo === "primera_sangre") {
            return Math.min(statsPartidasGanadas, 1) + " / 1";
        }
        if (codigo === "club_de_los_cien") {
            return Math.min(statsManosJugadas, 100) + " / 100";
        }
        // "Centurión" (2026-09-09) -- manos GANADAS, el contrapeso del
        // Club de los Cien, que cuenta las jugadas.
        if (codigo === "centurion") {
            return Math.min(statsManosGanadas, 100) + " / 100";
        }
        if (codigo === "el_farolero") {
            return Math.min(statsVecesGanoSinShowdown, 15) + " / 15";
        }
        if (codigo === "manos_de_hierro") {
            return Math.min(statsRachaManosGanadas, 5) + " / 5";
        }
        // El resto (trasnochador, circulo_cerrado, el_fenix, la_corona, y
        // los 3 añadidos 2026-09-01: escalera_color, poker_ases,
        // barrida_total) son eventos puntuales de verdad -- se cumplen o
        // no en una mano/partida concreta, sin ningún "vas por la mitad"
        // real (a diferencia de los 4 de arriba, que sí acumulan). Un
        // logro puntual nuevo cae aquí solo, sin tocar esta función.
        // Antes se dejaban en blanco sin más -- se veía como un
        // descuido, no como una decisión (pedido explícito 2026-08-31:
        // "por qué poner contador en unas y en otras no"). Ahora lo dice
        // la propia etiqueta, en vez de dejar el hueco vacío.
        return "Puntual";
    }
    function reordenarRanking() {
        var filas = rankingCrudo.slice();
        if (ordenRankingActual === 0) {
            filas.sort((a, b) => b.partidasGanadas - a.partidasGanadas);
        } else if (ordenRankingActual === 1) {
            filas.sort((a, b) => (b.partidasGanadas / b.partidasJugadas) -
                                  (a.partidasGanadas / a.partidasJugadas));
        } else {
            filas.sort((a, b) => b.elo - a.elo);
        }
        // "posicion" es el puesto REAL (1º, 2º...) según el orden ya
        // aplicado arriba -- se guarda ANTES de repartir entre podio/resto
        // para que la lista de abajo, aunque empiece en el 4º puesto,
        // siga mostrando "4", "5"... en vez de reiniciar en "1" (el índice
        // del ListView ya no coincidiría con el puesto real una vez el
        // top 3 sale de su modelo).
        for (var i = 0; i < filas.length; i++) filas[i].posicion = i + 1;

        // Podio: top 3 en un bloque grande aparte, la lista de siempre
        // sigue desde el 4º puesto (pedido explícito 2026-09-01: "no me
        // parece mal que la lista siga debajo a partir del cuarto puesto
        // mientras se note que forma parte") -- nada de duplicar el top 3
        // en las dos partes. Con menos de 3 cuentas en el ranking, ningún
        // podio a medias -- la lista de siempre se ve completa desde el 1º.
        rankingPodio = filas.length >= 3 ? filas.slice(0, 3) : [];
        var resto = filas.length >= 3 ? filas.slice(3) : filas;
        rankingModel.clear();
        for (var j = 0; j < resto.length; j++) rankingModel.append(resto[j]);
        // Reactiva el "pin" de contentY=0 (ver el comentario grande junto
        // a listaRanking.anclarArriba) para este reordenamiento -- cubre
        // tanto el primer dato que llega como un cambio de pestaña
        // Ganadas/Ratio/Elo.
        listaRanking.anclarArriba = true;
        Qt.callLater(() => { listaRanking.contentY = 0; });
    }
    // ── Social ───────────────────────────────────────────────────────────
    ListModel {
        id: modeloAmigos
    }
    ListModel {
        id: modeloBusqueda
    }
    ListModel {
        id: modeloRecientes
    }
    ListModel {
        id: modeloSolicitudes
    }
    // Username de la solicitud en curso -- para saber a qué fila marcar
    // "pendiente" cuando llega solicitudAmistadEnviada() (la señal no trae
    // parámetros, ver el comentario largo en NetworkClient.hpp).
    property string pendienteSolicitudUsername: ""
    property string mensajeErrorSocial: ""
    // ── Amigos + chat fusionados (Cerrar Social v1) ─────────────────────
    // "Chats" no es una pestaña aparte -- cada fila de Amigos ya muestra
    // presencia Y el último mensaje (si lo hay), decisión tomada tras
    // playtest real (2026-08-27): la pestaña separada dejaba "atrás" en un
    // callejón sin salida. modeloResumenChats sigue siendo la fuente
    // cruda (llega de listarResumenChats()); modeloAmigosConChat es el
    // cruce por accountId que de verdad pinta la lista, reconstruido cada
    // vez que cualquiera de las dos fuentes cambia.
    ListModel {
        id: modeloResumenChats
    }
    ListModel {
        id: modeloAmigosConChat
    }
    function reconstruirModeloAmigosConChat() {
        var resumenPorId = {};
        for (var i = 0; i < modeloResumenChats.count; i++) {
            var r = modeloResumenChats.get(i);
            resumenPorId[r.accountId] = r;
        }
        modeloAmigosConChat.clear();
        for (var j = 0; j < modeloAmigos.count; j++) {
            var a = modeloAmigos.get(j);
            var r2 = resumenPorId[a.accountId];
            modeloAmigosConChat.append({
                accountId: a.accountId,
                username: a.username,
                estado: a.estado,
                ultimoTexto: r2 ? r2.ultimoTexto : "",
                // !! fuerza booleano de verdad -- parsearFilasChat() (C++)
                // detecta "0"/"1" como número y los manda como int, no
                // bool; sin el !!, el primer amigo sin chat aún (rama
                // "false" de abajo, sí boolean) fijaba el rol de
                // ListModel como Bool, y el siguiente amigo CON chat
                // (r2.ultimoEsMio como int) rompía con "Can't assign to
                // existing role 'ultimoEsMio' of different type".
                ultimoEsMio: r2 ? !!r2.ultimoEsMio : false,
                noLeidos: r2 ? r2.noLeidos : 0
            });
            if (chatAmigoSeleccionado === a.accountId) chatAmigoSeleccionadoEstado = a.estado;
        }
    }
    // Chat embebido en la pestaña Amigos, estilo WhatsApp Web (lista a la
    // izquierda, conversación a la derecha) -- reemplaza al popup flotante
    // VistaChatDirecto de antes (2026-08-27): con la pestaña ya rediseñada
    // como una pantalla de chat de verdad, ya no hacía falta un overlay
    // aparte para evitar el "callejón sin salida" del primer intento (ver
    // el historial de qt_gameplay_ui_backlog/memoria de esa sesión).
    // -1 = ningún amigo seleccionado, el panel derecho muestra el placeholder.
    property int chatAmigoSeleccionado: -1
    property string chatAmigoSeleccionadoNombre: ""
    // Se mantiene al día en cada reconstruirModeloAmigosConChat() (presencia
    // se refresca sola cada 15s, ver el Timer de la pestaña Amigos), no solo
    // en el instante de abrir -- así la cabecera del chat no se queda con un
    // estado de presencia congelado mientras la conversación sigue abierta.
    property string chatAmigoSeleccionadoEstado: ""
    ListModel {
        id: modeloConversacionAmigos
    }
    function abrirChatAmigo(id, nombre, estado) {
        chatAmigoSeleccionado = id;
        chatAmigoSeleccionadoNombre = nombre;
        chatAmigoSeleccionadoEstado = estado;
        modeloConversacionAmigos.clear();
        redcliente.listarConversacion(servidorHost, servidorPuerto, id);
    }
    // El estado "pendiente" de cada fila viene del SERVIDOR (buscarJugadores()/
    // listarJugadoresRecientes() ya lo calculan, ver AccountManager.cpp) --
    // no de una lista local en memoria. Antes se marcaba "enviada" a mano
    // en un array que solo sabía de ESTA sesión: volver a buscar a alguien
    // a quien ya se le había mandado solicitud ANTES (otra sesión, o antes
    // de reabrir la pestaña) no lo reflejaba, y encima nunca se limpiaba
    // si la solicitud se rechazaba (bug real reportado en pruebas). Esta
    // función solo hace la actualización OPTIMISTA de la fila que se
    // acaba de mandar -- para no esperar a la próxima búsqueda para ver el
    // cambio -- el servidor sigue siendo la fuente de verdad en cualquier
    // refresco posterior.
    function marcarPendienteEnModelos(username) {
        for (var i = 0; i < modeloBusqueda.count; i++) {
            if (modeloBusqueda.get(i).username === username) modeloBusqueda.setProperty(i, "pendiente", 1);
        }
        for (var j = 0; j < modeloRecientes.count; j++) {
            if (modeloRecientes.get(j).username === username) modeloRecientes.setProperty(j, "pendiente", 1);
        }
    }
    // ── Estadísticas propias (pestaña Cuenta del cajón) ─────────────────
    property int statsManosJugadas: 0
    property int statsManosGanadas: 0
    property int statsPartidasJugadas: 0
    property int statsPartidasGanadas: 0
    // Marco Hierro (ver Tema.marcoPorPartidasGanadas) -- a diferencia de
    // statsPartidasGanadas de arriba, se pone con CUALQUIER partida
    // ganada, también solo contra bots (pedido explícito 2026-08-31).
    property bool statsTieneMarcoBasico: false
    // Contador de "El Farolero" (>=15 desbloquea) -- para el "cuánto te
    // queda" de la pantalla de Logros (pedido explícito 2026-08-31).
    property int statsVecesGanoSinShowdown: 0
    // Racha de manos ganadas seguidas -- para "Manos de Hierro" (>=5
    // desbloquea), mismo motivo que statsVecesGanoSinShowdown de arriba.
    property int statsRachaManosGanadas: 0
    property int statsRachaActual: 0
    property int statsRachaMaxima: 0
    property int statsMayorBote: 0
    property string statsMejorManoNombre: ""
    property int statsMejorManoFecha: 0  // unix timestamp, 0 = todavía ninguna
    property int statsVecesCartaAlta: 0
    property int statsVecesPareja: 0
    property int statsVecesDoblePareja: 0
    property int statsVecesTrio: 0
    property int statsVecesEscalera: 0
    property int statsVecesColor: 0
    property int statsVecesFullHouse: 0
    property int statsVecesPoker: 0
    property int statsVecesEscaleraColor: 0
    property int statsVecesEscaleraReal: 0
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
    // soyHost es SIEMPRE verdad de servidor: se recalcula comparando el
    // "host" que manda LOBBY_UPDATE/PARTIDA_INICIADA contra el nombre
    // propio (ver onLobbyActualizado/onPartidaIniciada más abajo). Antes
    // había un flag local optimista (creadorDeLaSala) puesto a mano en
    // "Crear sala"/"Reanudar" -- funcionaba para salas nuevas, pero para
    // una partida RECARGADA cualquiera que pulsara "Reanudar" se creía
    // host aunque el servidor hubiera asignado el puesto a otro (bug real
    // reportado: dos personas viéndose como host de la misma sala tras
    // recargar un guardado). La comparación es segura porque
    // nombreUsuario.text ya se corrige al nombre real que usa el
    // servidor vía onNombreAsignado(), que llega antes que ambos eventos.
    property bool soyHost: false
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

        // Cualquier TextField enfocado (campo de código de sala, búsqueda,
        // renombrar guardada...) se quedaba con el foco -- y el aro/subrayado
        // de "activo" encendido -- indefinidamente si dejabas de escribir y
        // pulsabas en otro sitio que no fuera OTRO control con foco propio,
        // en vez de perderlo como en cualquier formulario normal (pedido
        // explícito 2026-08-28). Un único MouseArea de fondo, DEBAJO de
        // toda pantalla (primer hijo = z más bajo entre hermanos sin "z"
        // explícito) que ninguna otra pantalla reclama: cualquier click que
        // no toque un control real "cae" hasta aquí y se lleva el foco a un
        // Item neutro, sin quitárselo a nada que sí lo necesite (un botón
        // pulsado, por ejemplo, ya consume el evento antes de llegar aquí).
        Item {
            id: capturaFocoFondo
            anchors.fill: parent
            focus: true
            MouseArea {
                anchors.fill: parent
                onClicked: capturaFocoFondo.forceActiveFocus()
            }
        }

        // ── Riel de navegación (Salas/Ranking/Torneos/Social) ─────────────
        // Instancia única, visible solo en las 4 pantallas "hub" -- ver
        // RielNavegacion.qml. Las demás pantallas (Inicio/Login/Registro/
        // CrearSala/Lobby/Partida/Fin) no lo llevan.
        RielNavegacion {
            id: rielNavegacion
            visible: ["Salas", "Ranking", "Torneos", "Social", "Tienda", "Cuenta"].indexOf(ventana.pantalla) !== -1
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            pantallaActual: ventana.pantalla
            modoOffline: ventana.sesionOffline
            onSeccionElegida: (nombre) => {
                ventana.pantalla = nombre;
                // Sin conexión, "Salas" solo enseña las partidas guardadas
                // LOCALES (no hay salas ajenas): se fuerza esa pestaña y se
                // pide la lista al entrar, igual que hace la pestaña normal.
                if (nombre === "Salas" && ventana.sesionOffline) {
                    viendoGuardadas = true;
                    redcliente.listarGuardadas(servidorHost, servidorPuerto);
                }
                // Refresca cada vez que se entra -- consulta barata, y así
                // no hace falta un botón "Refrescar" aparte para esto.
                if (nombre === "Ranking") {
                    // Elo por defecto al entrar (Fase 3 del sistema de
                    // progresión) -- mismo criterio de reset-al-reentrar
                    // que Social/Cuenta: siempre la pestaña que de verdad
                    // importa, no lo que se hubiera dejado elegido antes.
                    ordenRankingActual = 2;
                    redcliente.consultarRanking(servidorHost, servidorPuerto);
                    // Bug real reportado 2026-09-02 (visto primero en
                    // móvil, mismo componente aquí): el ListView nunca se
                    // destruye (solo cambia "visible"), así que su scroll
                    // sobrevivía entre visitas -- al reentrar tras haber
                    // bajado la vez anterior, el 4º puesto quedaba pegado
                    // arriba y había que subir a mano para ver el podio.
                    // El reset real (el que importa, tras la respuesta
                    // del servidor) vive en reordenarRanking() -- este de
                    // aquí solo cubre el instante de reentrar con datos
                    // ya cargados de antes. anclarArriba=true reactiva el
                    // "pin" de contentY=0 (ver el comentario grande junto a
                    // listaRanking) para esta visita nueva a la pantalla.
                    listaRanking.anclarArriba = true;
                    Qt.callLater(() => { listaRanking.contentY = 0; });
                }
                if (nombre === "Social" && tokenSesion !== "") {
                    // Estado inicial de verdad al reentrar -- pestaña
                    // Amigos y sin chat abierto, no lo que se hubiera
                    // dejado a medias la última vez (pedido explícito
                    // 2026-08-28: el estado efímero de una pantalla se
                    // reinicia al salir de ella, no se queda "congelado").
                    pestanaSocialActual = 0;
                    chatAmigoSeleccionado = -1;
                    mensajeErrorSocial = "";
                    redcliente.listarAmigos(servidorHost, servidorPuerto);
                    // El resumen trae los avisos de no leídos: sin pedirlo al
                    // entrar se veían los de la última visita, aunque esos
                    // mensajes ya estuvieran leídos (visto 2026-09-10).
                    redcliente.listarResumenChats(servidorHost, servidorPuerto);
                }
                if (nombre === "Cuenta") {
                    // Mismo criterio de reset-al-reentrar que Social:
                    // siempre Perfil, formularios de usuario/contraseña
                    // cerrados, no lo que se hubiera dejado a medias.
                    pestanaCuentaActual = 0;
                    formularioUsernameAbierto = false;
                    formularioPasswordAbierto = false;
                    mensajeErrorLogin = "";
                    mensajeExportacion = "";
                    pestanaPersonalizarActual = 0;
                    previewCodigo = "";
                    previewCategoria = "";
                    if (tokenSesion !== "") {
                        redcliente.consultarEstadisticas(servidorHost, servidorPuerto, tokenSesion);
                        // Fase 4/5 del sistema de progresión: se piden ya
                        // mismo (no solo al entrar en cada pestaña) para
                        // que estén listas en cuanto se pulsen, sin
                        // esperar a la ida y vuelta.
                        redcliente.consultarLogros(servidorHost, servidorPuerto, tokenSesion);
                        redcliente.consultarTienda(servidorHost, servidorPuerto, tokenSesion);
                        redcliente.consultarLoadout(servidorHost, servidorPuerto, tokenSesion);
                    }
                }
                if (nombre === "Tienda") {
                    // Tienda dejó de ser una pestaña de Cuenta (2026-09-01,
                    // "en nuestro diseño original... la tienda debería
                    // estar en el riel, no escondida") -- pantalla propia,
                    // así que su reset-al-reentrar vive suelto aquí en vez
                    // de colgar del bloque de "Cuenta" de arriba.
                    pestanaTiendaActual = 0;
                    mensajeTienda = "";
                    busquedaTienda = "";
                    // El TextField no está atado a busquedaTienda con un
                    // binding de verdad (se rompería en cuanto el usuario
                    // escribiera algo) -- se limpia a mano aquí, igual que
                    // antes.
                    campoBusquedaTienda.text = "";
                    previewCodigo = "";
                    previewCategoria = "";
                    if (tokenSesion !== "") {
                        redcliente.consultarEstadisticas(servidorHost, servidorPuerto, tokenSesion);
                        redcliente.consultarTienda(servidorHost, servidorPuerto, tokenSesion);
                        redcliente.consultarLoadout(servidorHost, servidorPuerto, tokenSesion);
                    }
                }
            }
        }

        // Versión instalada, discreta, en la esquina (pendiente 9 de CLAUDE.md,
        // 2026-09-10). Si hay una más nueva lo dice aquí mismo, además del banner.
        Text {
            visible: pantalla === "Inicio"
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14 * Tema.escala
            textFormat: Text.StyledText
            text: "v" + versionChecker.versionActual
                  + (versionChecker.hayVersionNueva
                     ? " · <font color=\"" + Tema.colorHex(Tema.colorAccent) + "\">hay una nueva: v"
                       + versionChecker.versionRemota + "</font>"
                     : "")
            color: Tema.colorTextoMuyTenue
            font.pixelSize: 11 * Tema.escala
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
                    color: Tema.colorTexto
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
            // Inicio tiene TRES estados (Fase 7, ver CLAUDE.md), no dos:
            //  - comprobando: ni un botón de entrar, solo el indicador de
            //    arriba. Antes salían los tres en gris, que invitaba a
            //    pulsarlos justo cuando todavía no se sabía nada.
            //  - conectado: los tres de siempre (cuenta / registro / invitado).
            //  - sin conexión: se puede jugar igual, en local.
            // Ya no hay campo de nombre libre: la identidad viene de una
            // cuenta (login/registro) o de un nombre de invitado generado
            // aquí mismo, sin persistencia.
            BotonRelleno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Iniciar sesión"
                radioBorde: 999
                visible: conectadoAlServidor
                onClicked: {
                    mensajeErrorLogin = "";
                    pantalla = "Login";
                }
            }
            BotonContorno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Crear cuenta"
                radioBorde: 999
                visible: conectadoAlServidor
                onClicked: {
                    mensajeErrorLogin = "";
                    pantalla = "Registro";
                }
            }
            BotonContorno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Entrar como invitado"
                radioBorde: 999
                visible: conectadoAlServidor
                onClicked: {
                    // Sin persistencia -- token_ ya está vacío (nunca se
                    // llegó a fijar, o se limpió al cerrar sesión) así que
                    // conectar()/crearSala()/etc. lo mandan vacío solos.
                    nombreUsuario.text = "Invitado" + Math.floor(Math.random() * 100000);
                    pantalla = "Salas";
                    redcliente.refrescarSalas(servidorHost, servidorPuerto);
                }
            }

            // ── Sin conexión: jugar en local ──────────────────────────────
            // Con cuenta cacheada conservas identidad y cosméticos reales
            // (ver LocalGameClient::estadisticasCuenta); de invitado es un
            // sandbox puro. En los dos casos, ni Tréboles ni Elo -- eso
            // solo existe con servidor de por medio.
            BotonRelleno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Jugar sin conexión"
                radioBorde: 999
                visible: !conectadoAlServidor && !comprobandoConexion
                         && modoJuego.hayIdentidadCacheada
                onClicked: ventana.entrarSinConexion(true)
            }
            // Etiqueta sin "sin conexión" a propósito: las dos opciones ya
            // están bajo el estado "sin conexión", y llamarlas parecido
            // ("Jugar sin conexión" / "Jugar sin conexión (invitado)")
            // hacía imposible distinguirlas de un vistazo.
            BotonContorno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Jugar como invitado"
                radioBorde: 999
                visible: !conectadoAlServidor && !comprobandoConexion
                onClicked: ventana.entrarSinConexion(false)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !conectadoAlServidor && !comprobandoConexion
                         && modoJuego.hayIdentidadCacheada
                color: Tema.colorTextoTenue
                font.pixelSize: 11 * Tema.escala
                text: "Como " + modoJuego.usernameCacheado + " · sin Tréboles ni Elo"
            }
            // Sin cuenta cacheada solo cabe entrar de invitado -- decirlo,
            // en vez de dejar que parezca que falta una opción.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 260 * Tema.escala
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: !conectadoAlServidor && !comprobandoConexion
                         && !modoJuego.hayIdentidadCacheada
                color: Tema.colorTextoTenue
                font.pixelSize: 11 * Tema.escala
                text: "Inicia sesión al menos una vez con el servidor disponible para poder jugar sin conexión con tu cuenta."
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

            CampoTexto {
                id: campoUsuarioLogin
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 16 * Tema.escala
                placeholderText: (activeFocus || text.length > 0) ? "" : "Usuario"
                onAccepted: campoPasswordLogin.forceActiveFocus()
            }
            CampoTexto {
                id: campoPasswordLogin
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 16 * Tema.escala
                echoMode: TextInput.Password
                placeholderText: (activeFocus || text.length > 0) ? "" : "Contraseña"
                onAccepted: botonEntrarLogin.clicked()
            }
            BotonRelleno {
                id: botonEntrarLogin
                anchors.horizontalCenter: parent.horizontalCenter
                text: enviandoLogin ? "Entrando…" : "Entrar"
                enabled: !enviandoLogin
                radioBorde: 999
                // Siempre pulsable (salvo mientras viaja el login, que dice
                // "Entrando…") -- ver el comentario largo en
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
                    enviandoLogin = true;
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

            CampoTexto {
                id: campoUsuarioRegistro
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 16 * Tema.escala
                placeholderText: (activeFocus || text.length > 0) ? "" : "Usuario (mín. 3 caracteres)"
                onAccepted: campoPasswordRegistro.forceActiveFocus()
            }
            CampoTexto {
                id: campoPasswordRegistro
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 16 * Tema.escala
                echoMode: TextInput.Password
                placeholderText: (activeFocus || text.length > 0) ? "" : "Contraseña (8+ caracteres)"
                onAccepted: campoPasswordRegistroConfirmar.forceActiveFocus()
            }
            CampoTexto {
                id: campoPasswordRegistroConfirmar
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 16 * Tema.escala
                echoMode: TextInput.Password
                placeholderText: (activeFocus || text.length > 0) ? "" : "Repite la contraseña"
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
            id: barraSalas
            visible: ventana.pantalla === "Salas"
            anchors.top: parent.top
            anchors.left: rielNavegacion.right
            anchors.right: parent.right
            textoCentro: ventana.sesionOffline ? "Partida local" : "Salas disponibles"
            pantalla: ventana.pantalla
            miSaldoActual: ventana.miSaldoActual
            reconectandoAhora: ventana.reconectandoAhora
            servidorHost: ventana.servidorHost
            servidorPuerto: ventana.servidorPuerto
            mostrarRefrescar: true
            mostrarSalir: true
            onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
            onRefrescar: viendoGuardadas ? redcliente.listarGuardadas(servidorHost, servidorPuerto)
                                          : redcliente.refrescarSalas(servidorHost, servidorPuerto)
            // "ventana." explícito -- mismo bug de scoping que el
            // comentario de arriba ("pragma ComponentBehavior: Bound"):
            // "pantalla" a secas aquí se resolvería contra la required
            // property PROPIA de BarraSuperior (pantalla: ventana.pantalla,
            // un binding de solo lectura), no navegaría a ningún sitio y
            // de paso rompería ese binding -- bug real, "Salir" no hacía
            // nada (2026-08-28).
            onSalir: ventana.pantalla = "Inicio"
        }
        Column {
            // Sin conexión esta misma pantalla se reduce a las PARTIDAS
            // GUARDADAS locales + "nueva partida": no hay salas ajenas que
            // listar ni códigos a los que unirse, pero el resto (lista,
            // renombrar, borrar, cargar, refrescar) vale tal cual porque
            // LocalGameClient implementa las mismas llamadas contra la
            // carpeta local. Ver ahí carpetaGuardadoLocal().
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
            // Tope subido de 680 a 1040*escala (rediseño "aprovechar el
            // ancho de la ventana", 2026-08-27) -- con la ventana de
            // referencia (1040×780, escala=1) esto sigue siendo el mismo
            // 680 de antes gracias al Math.min de abajo; el salto real solo
            // se nota en ventanas más anchas, donde antes sobraba la mitad
            // del hueco junto al riel.
            width: Math.min(1040 * Tema.escala, ventana.width - 60 * Tema.escala)

            // Título + "unirse por código" en la misma fila -- antes el
            // campo de código vivía suelto al final de la pantalla, lejos
            // del título y de las salas a las que en realidad se refiere.
            Item {
                width: parent.width
                height: Math.max(textoTituloSalas.implicitHeight, filaCodigoSalas.implicitHeight)
                Text {
                    id: textoTituloSalas
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: viendoGuardadas ? "Partidas guardadas" : "Salas disponibles"
                    // (offline viendoGuardadas va siempre a true, ver el riel)
                    color: Tema.colorTexto
                    font.family: Tema.fuenteElegante
                    font.pixelSize: 24 * Tema.escala
                }
                Row {
                    id: filaCodigoSalas
                    visible: !viendoGuardadas && !ventana.sesionOffline
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * Tema.escala
                    CampoTexto {
                        id: campoCodigoUnion
                        anchors.verticalCenter: parent.verticalCenter
                        width: 170 * Tema.escala
                        placeholderText: (activeFocus || text.length > 0) ? "" : "Código de sala privada"
                        font.pixelSize: 13 * Tema.escala
                        // Mismo campo "subrayado" sin caja que Login/Registro
                        // -- ver el comentario original en el punto donde
                        // vivía antes esta fila.
                        onAccepted: botonUnirsePorCodigo.clicked()
                    }
                    BotonContorno {
                        id: botonUnirsePorCodigo
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Unirse por código"
                        onClicked: {
                            redcliente.unirseASala(servidorHost, servidorPuerto, nombreUsuario.text, "", campoCodigoUnion.text);
                        }
                    }
                }
            }

            // Barra de pestañas (mismo componente que Social/Ranking, en vez
            // del selector de píldoras suelto de antes) + "Crear sala
            // nueva" en la misma barra -- antes vivía abajo del todo, lejos
            // de las pestañas a las que en realidad pertenece.
            Row {
                width: parent.width
                spacing: 10 * Tema.escala
                SelectorSegmentado {
                    id: tabsSalas
                    // Offline solo existe una de las dos pestañas, así que el
                    // selector sobra (ver viendoGuardadas, forzado a true al
                    // entrar en Salas sin conexión).
                    visible: !ventana.sesionOffline
                    width: parent.width - botonCrearSalaTab.width - parent.spacing
                    opciones: ["Salas", "Partidas guardadas"]
                    seleccionado: viendoGuardadas ? 1 : 0
                    onElegido: (indice) => {
                        viendoGuardadas = indice === 1;
                        if (viendoGuardadas) redcliente.listarGuardadas(servidorHost, servidorPuerto);
                    }
                }
                BotonRelleno {
                    id: botonCrearSalaTab
                    anchors.verticalCenter: parent.verticalCenter
                    text: ventana.sesionOffline ? "Nueva partida local" : "Crear sala nueva"
                    onClicked: pantalla = "CrearSala"
                }
            }

            // ── Estados vacíos -- una caja modesta, no el panel entero ────
            Rectangle {
                width: parent.width
                height: 200 * Tema.escala
                visible: !viendoGuardadas && salasDisponibles.count === 0
                radius: 10 * Tema.escala
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.35)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                    GradientStop { position: 1.0; color: Tema.colorPanel }
                }
                // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                layer.enabled: true
                layer.effect: ShaderEffect {
                    property variant source
                    property real amplitud: 30.0
                    fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
                }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 60 * Tema.escala
                    text: "No hay salas públicas disponibles ahora mismo."
                    color: Tema.colorTextoTenue
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13 * Tema.escala
                }
            }
            Rectangle {
                width: parent.width
                height: 200 * Tema.escala
                visible: viendoGuardadas && guardadasDisponibles.count === 0
                radius: 10 * Tema.escala
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.35)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                    GradientStop { position: 1.0; color: Tema.colorPanel }
                }
                // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                layer.enabled: true
                layer.effect: ShaderEffect {
                    property variant source
                    property real amplitud: 30.0
                    fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
                }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 60 * Tema.escala
                    text: "No hay partidas guardadas en el servidor."
                    color: Tema.colorTextoTenue
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13 * Tema.escala
                }
            }

            // ── Salas: rejilla de tarjetas en vez de filas finas dentro de
            // un panel único -- cada tarjeta lleva su propio degradado y
            // borde (mismo "elevado sobre el fondo" que ya usan las
            // tarjetas de Social/Amigos). Nº de columnas = las que quepan a
            // ~320*escala cada una, repartiendo el sobrante entre todas
            // (mismo criterio que el "realce" de SelectorSegmentado) --
            // altura acotada a 4 filas con scroll propio si hay más salas,
            // para no desbordar la ventana con un servidor muy cargado.
            GridView {
                id: gridSalas
                visible: !viendoGuardadas && salasDisponibles.count > 0
                width: parent.width
                height: Math.min(contentHeight, 4 * cellHeight)
                clip: true
                cellWidth: Math.floor(width / Math.max(1, Math.floor(width / (320 * Tema.escala))))
                cellHeight: 130 * Tema.escala
                model: salasDisponibles
                delegate: Item {
                    id: celdaSala
                    required property string id
                    required property string nombre
                    required property int conectados
                    required property int esperados
                    width: gridSalas.cellWidth
                    height: gridSalas.cellHeight

                    // "Ficha de casino" (2026-09-02, pedido explícito:
                    // "me gusta mucho como dejaste las tarjetas de la
                    // tienda... aplicar el mismo estilo a los amigos y
                    // salas") -- sombra desplazada barata (mismo criterio
                    // que BarraSuperior.qml), SIN escalar con la tarjeta.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 6 * Tema.escala
                        anchors.topMargin: 6 * Tema.escala + 3 * Tema.escala
                        radius: 10 * Tema.escala
                        color: "black"
                        opacity: 0.35
                    }

                    Rectangle {
                        id: tarjetaSala
                        anchors.fill: parent
                        anchors.margins: 6 * Tema.escala
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
                        // Se encoge un poco al pasar el ratón por encima --
                        // pedido explícito 2026-08-31, "así se nota más
                        // responsivo" (mismo criterio en Amigos y en el
                        // selector de cartas de la Tienda). Sin
                        // acceptedButtons: el "Unirse" de abajo sigue
                        // recibiendo su propio clic con normalidad.
                        scale: zonaHoverSala.containsMouse ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        MouseArea {
                            id: zonaHoverSala
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        // Hilo dorado por dentro del bisel exterior -- el
                        // "doble bisel" de ficha de casino.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2 * Tema.escala
                            radius: parent.radius - 2 * Tema.escala
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.16)
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14 * Tema.escala
                            spacing: 10 * Tema.escala

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: celdaSala.nombre !== "" ? celdaSala.nombre : celdaSala.id
                                color: Tema.colorTexto
                                font.bold: true
                                font.pixelSize: 15 * Tema.escala
                            }

                            Row {
                                width: parent.width
                                spacing: 10 * Tema.escala
                                Rectangle {
                                    id: pistaOcupacion
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - textoOcupacion.width - parent.spacing
                                    height: 5 * Tema.escala
                                    radius: height / 2
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                    Rectangle {
                                        width: pistaOcupacion.width * (celdaSala.esperados > 0
                                                   ? Math.min(1.0, celdaSala.conectados / celdaSala.esperados) : 0)
                                        height: parent.height
                                        radius: height / 2
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: Qt.lighter(Tema.colorAccent, 1.3) }
                                            GradientStop { position: 1.0; color: Tema.colorAccent }
                                        }
                                        // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                                        layer.enabled: true
                                        layer.effect: ShaderEffect {
                                            property variant source
                                            property real amplitud: 3.0
                                            fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
                                        }
                                    }
                                }
                                Text {
                                    id: textoOcupacion
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: celdaSala.conectados + " / " + celdaSala.esperados
                                    color: Tema.colorTextoTenue
                                    font.pixelSize: 11 * Tema.escala
                                }
                            }

                            BotonRelleno {
                                text: "Unirse"
                                enabled: celdaSala.conectados < celdaSala.esperados
                                opacity: enabled ? 1.0 : 0.55
                                onClicked: {
                                    redcliente.unirseASala(servidorHost, servidorPuerto, nombreUsuario.text, celdaSala.id, "");
                                }
                            }
                        }
                    }
                }
            }

            // ── Partidas guardadas: se queda en una columna (el modo
            // renombrar y las 3 acciones necesitan más ancho por fila del
            // que daría una rejilla de 2 columnas), pero con el mismo
            // degradado/borde/radio que las tarjetas de arriba en vez del
            // relleno plano de antes.
            ListView {
                id: listaGuardadas
                visible: viendoGuardadas && guardadasDisponibles.count > 0
                width: parent.width
                height: Math.min(contentHeight, 380 * Tema.escala)
                clip: true
                spacing: 10 * Tema.escala
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
                    height: 56 * Tema.escala
                    radius: 10 * Tema.escala
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.35)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                        GradientStop { position: 1.0; color: Tema.colorPanel }
                    }
                    // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                    layer.enabled: true
                    layer.effect: ShaderEffect {
                        property variant source
                        property real amplitud: 30.0
                        fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
                    }

                    Column {
                        visible: !filaGuardada.renombrando
                        anchors.left: parent.left
                        anchors.right: filaAcciones.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 14 * Tema.escala
                        anchors.rightMargin: 10 * Tema.escala
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: filaGuardada.archivo
                            color: Tema.colorTexto
                            font.pixelSize: 14 * Tema.escala
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: filaGuardada.fecha + " · " + filaGuardada.humanos +
                                  " humano(s), " + filaGuardada.bots + " bot(s)"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 12 * Tema.escala
                        }
                    }

                    // Modo renombrar: sustituye la columna de arriba por
                    // un campo de texto + confirmar, en vez de una
                    // pantalla/diálogo aparte.
                    Row {
                        visible: filaGuardada.renombrando
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 14 * Tema.escala
                        spacing: 6 * Tema.escala
                        TextField {
                            id: campoRenombrar
                            anchors.verticalCenter: parent.verticalCenter
                            width: 160 * Tema.escala
                            text: filaGuardada.archivo.replace(/\.pok$/, "")
                            color: Tema.colorTexto
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

                    // Alto EXPLÍCITO y metido respecto del de la fila -- ver
                    // el bloque gemelo del cliente móvil: con el alto
                    // implícito, los botones acababan midiendo lo mismo que
                    // la tarjeta y sus bordes horizontales se confundían con
                    // el canto de esta.
                    Row {
                        id: filaAcciones
                        readonly property real altoBoton: filaGuardada.height - 16 * Tema.escala
                        visible: !filaGuardada.renombrando
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 10 * Tema.escala
                        spacing: 6 * Tema.escala
                        BotonRelleno {
                            anchors.verticalCenter: parent.verticalCenter
                            height: filaAcciones.altoBoton
                            text: "Reanudar"
                            onClicked: {
                                redcliente.cargarPartidaGuardada(
                                    servidorHost, servidorPuerto, nombreUsuario.text,
                                    filaGuardada.archivo, filaGuardada.archivo, true);
                            }
                        }
                        BotonContorno {
                            anchors.verticalCenter: parent.verticalCenter
                            height: filaAcciones.altoBoton
                            text: "✎"
                            onClicked: filaGuardada.renombrando = true
                        }
                        BotonContorno {
                            anchors.verticalCenter: parent.verticalCenter
                            height: filaAcciones.altoBoton
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

            // "Refrescar"/"Salir" viven ahora en BarraSuperior (arriba,
            // junto a Ajustes) -- ver mostrarRefrescar/mostrarSalir. Dos
            // píldoras sueltas al final de una pantalla que ya tiene su
            // propia barra de pestañas y rejilla de tarjetas quedaban
            // descolgadas del resto del rediseño.
            Text {
                id: estadoTextoSalas
                anchors.horizontalCenter: parent.horizontalCenter
                color: Tema.colorPeligro
                font.pixelSize: 11 * Tema.escala
                text: mensajeErrorConexion
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
            mostrarSalir: true
            onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
            onSalir: ventana.pantalla = "Inicio"
        }
        // Título + selector de pestañas FIJOS, fuera del área que
        // scrollea -- mismo criterio que cabeceraCuenta/cabeceraTienda
        // ("el selector de pestaña arriba tiene que quedarse, el
        // contenido baja"). Aquí "el selector" es tabsRanking.
        Column {
            id: cabeceraRanking
            visible: pantalla === "Ranking"
            anchors.top: barraRanking.bottom
            anchors.topMargin: 24 * Tema.escala
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: rielNavegacion.width / 2
            spacing: 10 * Tema.escala
            // Mismo tope subido que Salas/Social (680 → 1040*escala) --
            // rediseño "aprovechar el ancho de la ventana", 2026-08-27. La
            // tabla en sí no cambia de estructura, solo se agranda.
            width: Math.min(1040 * Tema.escala, ventana.width - rielNavegacion.width - 60 * Tema.escala)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Ranking global"
                color: Tema.colorTexto
                font.family: Tema.fuenteElegante
                font.pixelSize: 22 * Tema.escala
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6 * Tema.escala
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Cuentas con al menos 5 partidas jugadas · ordenado por " +
                          (ordenRankingActual === 0 ? "victorias" : ordenRankingActual === 1 ? "ratio" : "Elo")
                    color: Tema.colorTextoMuyTenue
                    font.pixelSize: 11 * Tema.escala
                }
                // Desplegable flotante: qué hace que una partida "cuente" no
                // es obvio a simple vista (umbral antifarm, ver
                // popupInfoRanking más abajo) -- pedido explícito tras
                // confusión real con estadísticas que no subían.
                Rectangle {
                    id: iconoInfoRanking
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15 * Tema.escala
                    height: 15 * Tema.escala
                    radius: width / 2
                    color: "transparent"
                    border.width: 1.2
                    border.color: Tema.colorTextoMuyTenue
                    Text {
                        anchors.centerIn: parent
                        text: "i"
                        font.italic: true
                        font.bold: true
                        font.pixelSize: 10 * Tema.escala
                        color: Tema.colorTextoMuyTenue
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popupInfoRanking.open()
                    }
                }
            }

            Popup {
                id: popupInfoRanking
                parent: Overlay.overlay
                anchors.centerIn: parent
                modal: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                width: Math.min(420 * Tema.escala, (parent ? parent.width : 420) - 60 * Tema.escala)
                padding: 20 * Tema.escala

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
                        text: "¿Cuándo cuenta una partida?"
                        color: Tema.colorTexto
                        font.family: Tema.fuenteElegante
                        font.bold: true
                        font.pixelSize: 16 * Tema.escala
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        width: parent.width
                        text: "Para las estadísticas personales (manos y partidas jugadas/ganadas, racha, mayor bote) hacen falta al menos 2 cuentas reales en la mesa y al menos 5 manos jugadas. Jugar en solitario contra bots no cuenta nunca, sea cual sea la duración."
                        color: Tema.colorTextoTenue
                        font.pixelSize: 13 * Tema.escala
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        width: parent.width
                        text: "Las combinaciones mostradas en un showdown (mejor mano, contador por tipo) sí cuentan siempre, sin ese requisito."
                        color: Tema.colorTextoTenue
                        font.pixelSize: 13 * Tema.escala
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        width: parent.width
                        text: "Para aparecer en este ranking hace falta además al menos 5 partidas jugadas de las que sí cuentan."
                        color: Tema.colorTextoTenue
                        font.pixelSize: 13 * Tema.escala
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        width: parent.width
                        text: "Elo (pestaña por defecto) mide habilidad, no dedicación: +10 al ganar una partida oficial, −3 al perderla, sin ajustar por el nivel del rival. \"Más victorias\" y \"ratio\" son históricos y nunca se resetean; Elo sí -- se reinicia con cada temporada nueva."
                        color: Tema.colorTextoTenue
                        font.pixelSize: 13 * Tema.escala
                        wrapMode: Text.WordWrap
                    }
                }
            }
            SelectorSegmentado {
                id: tabsRanking
                width: parent.width
                opciones: ["Más victorias", "Mejor ratio", "Elo"]
                seleccionado: ordenRankingActual
                onElegido: (indice) => {
                    ordenRankingActual = indice;
                    reordenarRanking();
                }
            }
        }

        // Podio + lista, TODO scrolleable como un único conjunto (2026-09-01,
        // pedido explícito: "que sea scrolleable en su conjunto, no que se
        // queden los top3 arriba... el espacio que queda para scrollear es
        // pequeño y algo encerrado, no se siente ranking como tal"). El
        // panel ya NO tiene una altura fija -- llena el resto de la
        // pantalla bajo cabeceraRanking (mismo patrón que scrollCuenta/
        // panelTienda/panelSocial). El podio vive en ListView.header, así que se
        // desplaza junto con las filas de siempre, no fijo arriba.
        Rectangle {
            visible: pantalla === "Ranking"
            anchors.top: cabeceraRanking.bottom
            anchors.topMargin: 10 * Tema.escala
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16 * Tema.escala
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: rielNavegacion.width / 2
            width: Math.min(1040 * Tema.escala, ventana.width - rielNavegacion.width - 60 * Tema.escala)
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.3)
            radius: 10 * Tema.escala
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                GradientStop { position: 1.0; color: Tema.colorPanel }
            }
            // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
            layer.enabled: true
            layer.effect: ShaderEffect {
                property variant source
                property real amplitud: 30.0
                fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 40
                visible: rankingModel.count === 0 && rankingPodio.length === 0
                text: "Todavía no hay cuentas con partidas suficientes para aparecer en el ranking."
                color: Tema.colorTextoTenue
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: 13 * Tema.escala
            }

            ListView {
                id: listaRanking
                // rankingPodio.length===3 en el OR -- con exactamente 3
                // cuentas en el ranking (todo el mundo en el podio, nada
                // para la lista de siempre) el header debe seguir
                // viéndose aunque rankingModel esté vacío.
                visible: rankingModel.count > 0 || rankingPodio.length === 3
                anchors.fill: parent
                anchors.margins: 16 * Tema.escala
                clip: true
                spacing: 8 * Tema.escala
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                model: rankingModel
                // Bug real reportado 2026-09-02, CUARTO Y QUINTO intento --
                // los 3 anteriores (llamada inmediata, movida a
                // reordenarRanking, Qt.callLater, reactiva a
                // onHeightChanged de la cabecera) fallaron TODOS según
                // confirmó el usuario, siempre de la misma forma
                // determinista ("siempre empieza en el 4to, no importa que
                // haga"). Sospecha fundada: Flickable tiene su PROPIO
                // mecanismo interno de "preservar la posición visible" --
                // cuando el contenido crece POR ENCIMA de lo que ya se ve
                // (aquí, la cabecera-podio pasando de invisible a visible
                // de golpe cuando llegan los datos), Qt Quick compensa
                // moviendo contentY para que la fila que ya estaba arriba
                // (la del 4º puesto, antes de que el podio existiera) se
                // quede arriba -- exactamente el síntoma. Un reset puntual,
                // por pronto o tarde que se dispare, siempre puede perder
                // esa carrera contra la compensación interna. En vez de
                // adivinar OTRA VEZ el momento exacto, esto FIJA contentY a
                // 0 en cada cambio real de contentHeight (se dispara TANTAS
                // veces como haga falta, incluida la propia compensación
                // de Qt, que también dispara este mismo signal) hasta que
                // el usuario mueva la lista de verdad -- entonces se deja
                // de pelear con su scroll.
                property bool anclarArriba: true
                onContentHeightChanged: if (anclarArriba) contentY = 0
                onMovementStarted: anclarArriba = false
                onFlickStarted: anclarArriba = false
                header: Column {
                    id: cabeceraListaRanking
                    width: parent ? parent.width : 0
                    spacing: 14 * Tema.escala
                    // Bug real reportado 2026-09-02, TERCER intento -- los
                    // dos anteriores adivinaban EN QUÉ MOMENTO del ciclo de
                    // JS resetear el scroll (mismo tick, luego
                    // Qt.callLater) y los dos fallaron -- estaban
                    // resolviendo el problema equivocado. Esto SÍ ataca la
                    // causa real: el alto de esta Column cambia de golpe
                    // cuando el podio aparece/desaparece (Column excluye
                    // del layout a los hijos invisibles), y ESE cambio de
                    // alto es lo que descoloca a ListView -- no importa
                    // cuándo se rellene el modelo, lo que importa es
                    // cuándo cambia el alto de la cabecera. Reaccionar
                    // directamente a ESE evento, en vez de intentar
                    // adivinar el momento adecuado en otro sitio.
                    onHeightChanged: Qt.callLater(() => { listaRanking.contentY = 0; })

                    // ── Podio: top 3 de la pestaña activa (2026-09-01,
                    // ver memoria qt_progression_review_2026_09_01) -- el
                    // único sitio de todo el Ranking donde el avatar es
                    // lo bastante grande para que textura/efecto/
                    // decoraciones se lean de verdad. Orden visual
                    // 2º-1º-3º (podio físico de siempre), no el orden de
                    // mérito -- 1º con avatar más grande, en el centro.
                    // Reutiliza colorRareza() para las placas oro/plata/
                    // bronce (los mismos 3 colores que ya usa Logros/
                    // CajaTitulo) y el mismo lenguaje "círculo con letra"
                    // que el disco de dealer en Asiento.qml -- a
                    // propósito NADA de anillo/insignia nueva alrededor
                    // del avatar (3 intentos anteriores con corona/
                    // estrella/destello se rechazaron por "no cohesionado"
                    // -- ver memoria qt_nav_redesign_and_stats_plan; el
                    // anillo del marco ya dice "cuánto has jugado", el
                    // podio solo necesita decir "qué puesto es", sin pelear
                    // por el mismo círculo). Como header del ListView (no
                    // como hermano suelto) para que scrollee junto con el
                    // resto, ver el comentario grande de arriba.
                    Row {
                        visible: rankingPodio.length === 3
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 28 * Tema.escala
                        // "model: 3" + "index" (0,1,2), NO "model: [1,0,2]"
                        // + "modelData" -- bug real encontrado en vivo
                        // 2026-09-01 ("algo te fallo al conectar la
                        // información"): con un array de números sueltos
                        // como modelo, columnaPodio.fila (indexado por
                        // modelData) se quedaba sin resolver -- letra,
                        // marco, username y stat en blanco, badge de
                        // puesto sin color válido (se veía negro). "index"
                        // es el context property MÁS básico y fiable de
                        // Repeater (el mismo que ya usa, p.ej., el
                        // "posicionador" de Mesa.qml) -- el array [1,0,2]
                        // ahora solo se usa como tabla de mapeo pura en
                        // JS, no como modelo de Repeater.
                        Repeater {
                            model: 3
                            delegate: Column {
                                id: columnaPodio
                                required property int index
                                readonly property int idxFila: [1, 0, 2][columnaPodio.index]
                                readonly property var fila: rankingPodio.length === 3
                                                             ? rankingPodio[columnaPodio.idxFila] : null
                                readonly property bool esPrimero: columnaPodio.idxFila === 0
                                readonly property real tamanoAvatar: (columnaPodio.esPrimero ? 96 : 76) * Tema.escala
                                readonly property color colorPuesto: colorRareza(
                                    !columnaPodio.fila ? "" :
                                    columnaPodio.fila.posicion === 1 ? "oro" :
                                    columnaPodio.fila.posicion === 2 ? "plata" : "bronce")
                                spacing: 6 * Tema.escala

                                Item {
                                    id: envolturaAvatarPodio
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: columnaPodio.tamanoAvatar * 2.1
                                    height: width
                                    Avatar {
                                        anchors.centerIn: parent
                                        letra: columnaPodio.fila && columnaPodio.fila.username.length > 0
                                               ? columnaPodio.fila.username.charAt(0).toUpperCase() : "?"
                                        tamano: columnaPodio.tamanoAvatar
                                        marco: columnaPodio.fila
                                               ? Tema.marcoPorPartidasGanadas(columnaPodio.fila.partidasGanadas,
                                                                               columnaPodio.fila.tieneMarcoBasico)
                                               : "ninguno"
                                        textura: columnaPodio.fila ? columnaPodio.fila.textura : ""
                                        efecto: columnaPodio.fila ? columnaPodio.fila.efecto : ""
                                        decoracionLateral1: columnaPodio.fila ? columnaPodio.fila.decoracionLateral1 : ""
                                        decoracionLateral2: columnaPodio.fila ? columnaPodio.fila.decoracionLateral2 : ""
                                        decoracionSuperior: columnaPodio.fila ? columnaPodio.fila.decoracionSuperior : ""
                                        acabadoLateral1: columnaPodio.fila ? columnaPodio.fila.acabadoLateral1 : ""
                                        acabadoLateral2: columnaPodio.fila ? columnaPodio.fila.acabadoLateral2 : ""
                                        acabadoSuperior: columnaPodio.fila ? columnaPodio.fila.acabadoSuperior : ""
                                    }
                                    // Tocar el avatar abre el perfil público
                                    // -- pedido explícito 2026-09-02
                                    // ("importante"), el podio se había
                                    // quedado sin esto aunque la lista
                                    // normal de abajo ya lo tenía.
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: columnaPodio.fila !== null
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: popupPerfilJugador.abrir(columnaPodio.fila.accountId)
                                    }
                                    // Placa de puesto -- mismo lenguaje que
                                    // el disco "D" de dealer en Asiento.qml
                                    // (círculo relleno + letra/número en
                                    // negrita), no un icono nuevo. Centrada
                                    // con un offset desde el CENTRO del
                                    // envolvente (no "parent.right/bottom",
                                    // que ancla a la esquina del Item 2.1x
                                    // de sobra para el sangrado del marco,
                                    // muy lejos del avatar que de verdad se
                                    // ve -- bug real encontrado en el mismo
                                    // turno junto al de arriba).
                                    Rectangle {
                                        width: 24 * Tema.escala
                                        height: width
                                        radius: width / 2
                                        x: envolturaAvatarPodio.width / 2 + columnaPodio.tamanoAvatar * 0.30 - width / 2
                                        y: envolturaAvatarPodio.height / 2 + columnaPodio.tamanoAvatar * 0.30 - height / 2
                                        color: columnaPodio.colorPuesto
                                        border.width: 1.5
                                        border.color: Tema.colorFondo
                                        z: 10
                                        Text {
                                            anchors.centerIn: parent
                                            text: columnaPodio.fila ? (columnaPodio.fila.posicion + "") : ""
                                            font.bold: true
                                            font.family: Tema.fuenteElegante
                                            font.pixelSize: 12 * Tema.escala
                                            color: Tema.colorFondo
                                        }
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 130 * Tema.escala
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: columnaPodio.fila ? columnaPodio.fila.username : ""
                                    font.bold: true
                                    color: Tema.colorTexto
                                    font.pixelSize: 13 * Tema.escala
                                }
                                CajaTitulo {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    readonly property var infoTitulo: columnaPodio.fila
                                        ? objetoTiendaPorCodigo(columnaPodio.fila.titulo || "") : null
                                    nombre: infoTitulo ? infoTitulo.nombre : ""
                                    colorTier: colorRareza(infoTitulo ? infoTitulo.rareza : "")
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: !columnaPodio.fila ? ""
                                          : ordenRankingActual === 2 ? (columnaPodio.fila.elo + " Elo")
                                          : ordenRankingActual === 1
                                            ? (Math.round(100 * columnaPodio.fila.partidasGanadas / columnaPodio.fila.partidasJugadas) + "% de ratio")
                                            : (columnaPodio.fila.partidasGanadas + " victorias")
                                    color: Tema.colorTextoTenue
                                    font.pixelSize: 11 * Tema.escala
                                }
                            }
                        }
                    }
                    Rectangle {
                        visible: rankingPodio.length === 3
                        width: parent.width
                        height: 1
                        color: Qt.rgba(0, 0, 0, 0.25)
                    }
                    Row {
                        width: parent.width
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
                            // Fase 3: la pestaña Elo enseña ELO + PARTIDAS
                            // (contexto de cuántas partidas respaldan ese
                            // número) en vez de GANADAS/RATIO -- ganadas ya
                            // no es lo que ordena esta pestaña.
                            text: ordenRankingActual === 2 ? "ELO" : "GANADAS"
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 10 * Tema.escala
                        }
                        Text {
                            width: 110 * Tema.escala
                            horizontalAlignment: Text.AlignRight
                            text: ordenRankingActual === 2 ? "PARTIDAS" : "RATIO"
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 10 * Tema.escala
                        }
                    }
                }
                delegate: Rectangle {
                        id: filaRanking
                        required property int accountId
                        required property string username
                        required property int partidasJugadas
                        required property int partidasGanadas
                        required property int elo
                        required property int posicion
                        required property bool tieneMarcoBasico
                        required property int index
                        readonly property bool esUsuarioPropio:
                            username.toLowerCase() === nombreUsuario.text.toLowerCase()
                        width: ListView.view.width
                        // 56 → 68 (2026-09-01, pedido explícito: "aumenta
                        // el tamaño del resto de la lista" -- el podio de
                        // arriba subió mucho de escala y dejó estas filas
                        // pequeñas en comparación).
                        height: 68 * Tema.escala
                        radius: 10 * Tema.escala
                        // Fila normal: mismo degradado elevado que el resto
                        // del rediseño (antes plano, Tema.colorFondo). La
                        // fila propia lleva el mismo degradado pero teñido
                        // de acento -- distinguible sin caer en un relleno
                        // plano (un Rectangle con "gradient" fijado ignora
                        // "color" del todo, así que no se puede alternar
                        // entre las dos con una condición en "gradient"
                        // mismo -- por eso el color se decide en cada
                        // GradientStop en vez de en el Gradient entero).
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: filaRanking.esUsuarioPropio
                                       ? Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.18)
                                       : Qt.lighter(Tema.colorPanel, 1.5)
                            }
                            GradientStop {
                                position: 1.0
                                color: filaRanking.esUsuarioPropio
                                       ? Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.08)
                                       : Tema.colorPanel
                            }
                        }
                        // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                        layer.enabled: true
                        layer.effect: ShaderEffect {
                            property variant source
                            property real amplitud: 30.0
                            fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
                        }
                        border.width: esUsuarioPropio ? 1.5 : 1
                        border.color: esUsuarioPropio ? Tema.colorAccent : Qt.rgba(0, 0, 0, 0.35)

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 14 * Tema.escala
                            anchors.rightMargin: 14 * Tema.escala
                            Text {
                                width: 34 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                // "posicion", no "index+1" -- el top 3 ya no
                                // vive en este modelo (ver el podio más
                                // arriba), así que el índice del ListView ya
                                // no coincide con el puesto real.
                                text: filaRanking.posicion + ""
                                font.family: Tema.fuenteElegante
                                color: Tema.colorTextoTenue
                                font.pixelSize: 18 * Tema.escala
                            }
                            Row {
                                width: filaRanking.width - 34 * Tema.escala - 220 * Tema.escala - 28 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12 * Tema.escala
                                Avatar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    letra: filaRanking.username.length > 0 ? filaRanking.username.charAt(0).toUpperCase() : "?"
                                    // 34 → 44 (2026-09-01, pedido explícito:
                                    // "aumenta el tamaño del resto de la
                                    // lista"). Sigue sin textura/efecto/
                                    // decoraciones -- decisión mantenida a
                                    // propósito, no solo por tamaño: esas se
                                    // reservan como el "premio" exclusivo
                                    // del podio de arriba, no porque a 44px
                                    // se vean mal (a 44px ya se leerían
                                    // razonablemente bien).
                                    tamano: 44 * Tema.escala
                                    // tieneMarcoBasico real desde 2026-09-01
                                    // (podio de Ranking) -- antes era false a
                                    // propósito, así que Hierro nunca se veía
                                    // aquí (solo Bronce en adelante).
                                    marco: Tema.marcoPorPartidasGanadas(filaRanking.partidasGanadas, filaRanking.tieneMarcoBasico)
                                    colorBorde: filaRanking.esUsuarioPropio ? Tema.colorAccent : Qt.rgba(1, 1, 1, 0.18)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: filaRanking.username + (filaRanking.esUsuarioPropio ? " (tú)" : "")
                                    font.bold: filaRanking.esUsuarioPropio
                                    color: Tema.colorTexto
                                    elide: Text.ElideRight
                                    font.pixelSize: 15 * Tema.escala
                                }
                            }
                            Text {
                                width: 110 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                text: ordenRankingActual === 2 ? (filaRanking.elo + "") : (filaRanking.partidasGanadas + "")
                                color: Tema.colorTexto
                                font.pixelSize: 15 * Tema.escala
                            }
                            Text {
                                width: 110 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                text: ordenRankingActual === 2
                                      ? (filaRanking.partidasJugadas + "")
                                      : (Math.round(100 * filaRanking.partidasGanadas / filaRanking.partidasJugadas) + "%")
                                color: Tema.colorTextoTenue
                                font.pixelSize: 14 * Tema.escala
                            }
                        }
                        // Fila completa abre el perfil público -- mismo
                        // criterio que filaBusqueda/filaReciente.
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popupPerfilJugador.abrir(filaRanking.accountId)
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
            mostrarSalir: true
            onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
            onSalir: ventana.pantalla = "Inicio"
        }
        // Torneos bloqueado (los releases, ver POKER_TORNEOS en
        // cmake/ClientesQt.cmake): lo mismo que había antes de Solitario.
        Proximamente {
            visible: ventana.pantalla === "Torneos" && !torneosHabilitados
            anchors.top: barraTorneos.bottom
            anchors.left: rielNavegacion.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            titulo: "Torneos"
            descripcion: "Organiza partidas por eliminatorias para un grupo fijo de jugadores -- como crear una sala, pero con llave de torneo."
        }
        // Torneos Solitario (Fase 6, ver CLAUDE.md) -- primer desafío fijo
        // de lo que será una escalera completa (diseño de la escalera
        // todavía sin cerrar, ver el propio CLAUDE.md: "hay que pulirlo").
        // Deliberadamente mínimo por ahora: un único reto contra bots, sin
        // premio ni logro todavía (eso engancha al motor de logros ya
        // existente, pendiente de decidir el código/nombre del logro) --
        // sirve para validar en un cliente real LocalGameClient/
        // LocalGameObserver/JugadorLocalQt (ver docs/plan-modo-offline.md),
        // ya probados en aislado vía LocalOfflineSmokeTest pero nunca
        // todavía contra la UI de verdad. "Multijugador" (eliminatorias con
        // jugadores reales) sigue siendo un placeholder puro -- ni
        // diseñado, ver CLAUDE.md.
        Item {
            visible: pantalla === "Torneos" && torneosHabilitados
            anchors.top: barraTorneos.bottom
            anchors.left: rielNavegacion.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            Column {
                anchors.centerIn: parent
                spacing: 20 * Tema.escala
                width: 340 * Tema.escala

                Text {
                    text: "Torneos Solitario"
                    color: Tema.colorTexto
                    font.bold: true
                    font.pixelSize: 20 * Tema.escala
                    font.family: Tema.fuenteElegante
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: Tema.colorTextoTenue
                    font.pixelSize: 12 * Tema.escala
                    text: "Una escalera de desafíos contra bots está en camino. De momento, un único reto para probarlo."
                }

                // Tarjeta del reto -- mismo lenguaje visual "ficha de
                // casino" que el resto de la app (ver CLAUDE.md,
                // "Convenciones de diseño").
                Rectangle {
                    width: parent.width
                    height: columnaReto.height + 28 * Tema.escala
                    radius: 12 * Tema.escala
                    color: Tema.colorPanel
                    border.width: 1
                    border.color: Tema.colorBorde
                    // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                    layer.enabled: true
                    layer.effect: ShaderEffect {
                        property variant source
                        property real amplitud: 30.0
                        fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
                    }

                    Column {
                        id: columnaReto
                        anchors.centerIn: parent
                        width: parent.width - 32 * Tema.escala
                        spacing: 10 * Tema.escala

                        Text {
                            text: "Reto 1 · Primeros pasos"
                            color: Tema.colorAccent
                            font.bold: true
                            font.pixelSize: 14 * Tema.escala
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: "2 bots, dificultad fácil, hasta que alguien se quede con todas las fichas."
                            color: Tema.colorTexto
                            font.pixelSize: 12 * Tema.escala
                        }
                        BotonRelleno {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Jugar"
                            onClicked: {
                                // Reasignar "redcliente" ANTES de llamar a
                                // iniciarPartidaLocal() -- confirmado que la
                                // reasignación se propaga de inmediato,
                                // dentro del mismo bloque de JS (ver el
                                // comentario de ModoJuegoCoordinador.hpp).
                                modoJuego.activarModoLocal();
                                ventana.modoOfflineActivo = true;
                                redcliente.iniciarPartidaLocal(
                                    nombreUsuario.text, /*numBots=*/2, /*numManos=*/200,
                                    /*ciegaGrande=*/20, /*saldo=*/500, /*tipoLimite=*/0,
                                    /*aplicarMinRaise=*/false, /*monteFijo=*/0,
                                    /*dificultadBots=*/0, /*permitirRecompra=*/false,
                                    /*preguntarExtension=*/false);
                            }
                        }
                    }
                }
            }
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
            mostrarSalir: true
            onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
            onSalir: ventana.pantalla = "Inicio"
        }
        // ── Social: invitados ven un aviso + acceso a login/registro, mismo
        // criterio que la pestaña Cuenta del cajón lateral (no tiene
        // sentido sin cuenta -- amigos/solicitudes son datos de cuenta).
        Column {
            visible: pantalla === "Social" && tokenSesion === ""
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: rielNavegacion.width / 2
            spacing: 14 * Tema.escala
            width: Math.min(360 * Tema.escala, ventana.width - rielNavegacion.width - 60 * Tema.escala)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Social"
                color: Tema.colorTexto
                font.family: Tema.fuenteElegante
                font.pixelSize: 22 * Tema.escala
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Estás jugando como invitado. Inicia sesión o crea una cuenta para añadir amigos y ver quién está conectado."
                color: Tema.colorTextoTenue
                font.pixelSize: 13 * Tema.escala
            }
            BotonRelleno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Iniciar sesión"
                onClicked: { mensajeErrorLogin = ""; pantalla = "Login"; }
            }
            BotonContorno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Crear cuenta"
                onClicked: { mensajeErrorLogin = ""; pantalla = "Registro"; }
            }
        }

        // Título + selector de pestañas + error FIJOS, fuera del área que
        // llena el resto de la pantalla -- bug real reportado 2026-09-02
        // ("en los campos scrolleables no aprovechamos la altura... esto
        // pasa en la tienda, pasa al buscar jugadores"): antes las 4
        // pestañas vivían en un único Column sin límite de altura, cada
        // lista interior con un alto FIJO/tope propio (440, 380*escala)
        // sin relación con el alto real de la ventana. Mismo criterio que
        // cabeceraRanking/listaRanking: cabecera fija + panelSocial de
        // abajo que ocupa TODO el hueco restante, y dentro cada pestaña
        // rellena panelSocial en vez de un tope inventado.
        Column {
            id: cabeceraSocial
            visible: pantalla === "Social" && tokenSesion !== ""
            anchors.top: barraSocial.bottom
            anchors.topMargin: 24 * Tema.escala
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: rielNavegacion.width / 2
            spacing: 10 * Tema.escala
            // Mismo tope subido que Salas/Ranking (680 → 1040*escala) --
            // rediseño "aprovechar el ancho de la ventana", 2026-08-27.
            width: Math.min(1040 * Tema.escala, ventana.width - rielNavegacion.width - 60 * Tema.escala)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Social"
                color: Tema.colorTexto
                font.family: Tema.fuenteElegante
                font.pixelSize: 22 * Tema.escala
            }

            SelectorSegmentado {
                id: tabsSocial
                width: parent.width
                opciones: ["Amigos", "Buscar jugadores", "Jugadores Recientes", "Solicitudes"]
                seleccionado: pestanaSocialActual
                onElegido: (indice) => {
                    pestanaSocialActual = indice;
                    mensajeErrorSocial = "";
                    // Amigos fusiona presencia + último mensaje en la misma
                    // fila (ya no hay pestaña "Chats" aparte) -- pide las
                    // dos listas juntas.
                    if (indice === 0) {
                        redcliente.listarAmigos(servidorHost, servidorPuerto);
                        // Con un chat abierto, recargarlo marca sus mensajes
                        // como leídos y su respuesta ya pide el resumen (ver
                        // onConversacionActualizada). Pedir las dos cosas a
                        // la vez podía traer antes el resumen, con mensajes
                        // que sí estás viendo contados como no leídos.
                        if (chatAmigoSeleccionado !== -1)
                            redcliente.listarConversacion(servidorHost, servidorPuerto, chatAmigoSeleccionado);
                        else
                            redcliente.listarResumenChats(servidorHost, servidorPuerto);
                    }
                    else if (indice === 2) redcliente.listarJugadoresRecientes(servidorHost, servidorPuerto);
                    else if (indice === 3) redcliente.listarSolicitudesPendientes(servidorHost, servidorPuerto);
                }
            }

            Text {
                visible: mensajeErrorSocial !== ""
                width: parent.width
                wrapMode: Text.WordWrap
                text: mensajeErrorSocial
                color: Tema.colorPeligro
                font.pixelSize: 12 * Tema.escala
            }

            // Refresco de presencia mientras la pestaña Amigos esté abierta
            // -- V1 no empuja de verdad (ver PresenceRegistry/plan), así
            // que esto es sondeo acotado a esta única pestaña, no un
            // heartbeat global.
            Timer {
                interval: 15000
                repeat: true
                running: pantalla === "Social" && pestanaSocialActual === 0 && tokenSesion !== ""
                onTriggered: redcliente.listarAmigos(servidorHost, servidorPuerto)
            }
        } // fin de cabeceraSocial

        // Cuerpo de Social: ocupa TODO el hueco entre cabeceraSocial y el
        // borde inferior de la ventana (mismo patrón que la Rectangle de
        // Ranking) -- las 4 pestañas viven aquí dentro, cada una anclada a
        // anchors.fill: parent en vez de un alto fijo/tope propio.
        Item {
            id: panelSocial
            visible: pantalla === "Social" && tokenSesion !== ""
            anchors.top: cabeceraSocial.bottom
            anchors.topMargin: 10 * Tema.escala
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16 * Tema.escala
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: rielNavegacion.width / 2
            width: cabeceraSocial.width

            // ── Amigos -- vista dividida estilo WhatsApp Web: lista de
            // amigos a la izquierda (≤ mitad del ancho, reutiliza el mismo
            // lenguaje de tarjeta -- degradado + borde -- que el resto del
            // rediseño), conversación a la derecha (reutiliza ChatBox.qml,
            // igual que hacía el popup VistaChatDirecto que sustituye este
            // panel). El panel de chat solo "se enciende" (borde dorado)
            // con una conversación elegida -- apagado (borde neutro) en el
            // placeholder, para que se note que no hay nada seleccionado.
            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 200 * Tema.escala
                visible: pestanaSocialActual === 0 && modeloAmigos.count === 0
                radius: 10 * Tema.escala
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.35)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                    GradientStop { position: 1.0; color: Tema.colorPanel }
                }
                // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                layer.enabled: true
                layer.effect: ShaderEffect {
                    property variant source
                    property real amplitud: 30.0
                    fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
                }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 60 * Tema.escala
                    text: "Todavía no tienes amigos añadidos. Búscalos en \"Buscar jugadores\" o mira \"Jugadores Recientes\"."
                    color: Tema.colorTextoTenue
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13 * Tema.escala
                }
            }
            // Alto ligado a panelSocial entero (antes 440*escala fijo --
            // bug de "no aprovecha la altura", 2026-09-02) -- listaAmigosChat
            // y panelChatAmigo ya usan height: parent.height cada uno, así
            // que este único cambio basta para que los dos crezcan con la
            // ventana.
            Row {
                visible: pestanaSocialActual === 0 && modeloAmigos.count > 0
                width: parent.width
                height: parent.height
                spacing: 14 * Tema.escala

                ListView {
                    id: listaAmigosChat
                    width: parent.width * 0.42
                    height: parent.height
                    clip: true
                    spacing: 8 * Tema.escala
                    model: modeloAmigosConChat
                    delegate: Item {
                        id: filaAmigoChat
                        required property int accountId
                        required property string estado
                        required property string username
                        required property string ultimoTexto
                        required property bool ultimoEsMio
                        required property int noLeidos
                        width: ListView.view.width
                        height: 76 * Tema.escala

                        // "Ficha de casino" (2026-09-02, pedido explícito:
                        // "aplicar el mismo estilo a los amigos y salas")
                        // -- sombra desplazada barata, SIN escalar. Nuevo
                        // Item envolvente (antes filaAmigoChat era el
                        // Rectangle raíz) solo para poder meter esto
                        // detrás -- el resto de la fila sigue igual,
                        // sigue todo colgando de "parent" como antes.
                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 3 * Tema.escala
                            radius: 10 * Tema.escala
                            color: "black"
                            opacity: 0.35
                        }

                        Rectangle {
                            id: tarjetaAmigoChat
                            anchors.fill: parent
                            radius: 10 * Tema.escala
                            border.width: 1.2
                            border.color: chatAmigoSeleccionado === filaAmigoChat.accountId
                                              ? Tema.colorAccent : Qt.rgba(0, 0, 0, 0.4)
                            Behavior on border.color { ColorAnimation { duration: 120 } }
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
                            // Se encoge un poco al pasar el ratón por encima --
                            // pedido explícito 2026-08-31, mismo criterio que
                            // Salas y el selector de cartas de la Tienda.
                            scale: zonaHoverAmigo.containsMouse ? 0.97 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            // Hilo dorado por dentro del bisel exterior --
                            // el "doble bisel" de ficha de casino, más
                            // marcado con la conversación seleccionada.
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2 * Tema.escala
                                radius: parent.radius - 2 * Tema.escala
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b,
                                                       chatAmigoSeleccionado === filaAmigoChat.accountId ? 0.55 : 0.2)
                            }

                        // Avatar y columna de estado son hijos DIRECTOS de
                        // filaAmigoChat (no de un Row intermedio) a
                        // propósito: la segunda MouseArea de abajo ancla
                        // "centerIn: avatarFilaAmigo", y QML solo permite
                        // anclar contra el propio padre o un hermano
                        // directo -- anidado dentro de un Row habría sido
                        // un hermano del Row, no de avatarFilaAmigo (bug
                        // real en producción: "Cannot anchor to an item
                        // that isn't a parent or sibling", 2026-08-27).
                        Avatar {
                            id: avatarFilaAmigo
                            anchors.left: parent.left
                            anchors.leftMargin: 12 * Tema.escala
                            anchors.verticalCenter: parent.verticalCenter
                            letra: filaAmigoChat.username.length > 0 ? filaAmigoChat.username.charAt(0).toUpperCase() : "?"
                            tamano: 40 * Tema.escala
                        }
                        Column {
                            anchors.left: avatarFilaAmigo.right
                            anchors.leftMargin: 10 * Tema.escala
                            anchors.right: columnaEstadoAmigo.left
                            anchors.rightMargin: 8 * Tema.escala
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4 * Tema.escala
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: filaAmigoChat.username
                                color: Tema.colorTexto
                                font.pixelSize: 13.5 * Tema.escala
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: filaAmigoChat.ultimoTexto !== ""
                                          ? (filaAmigoChat.ultimoEsMio ? "Tú: " : "") + filaAmigoChat.ultimoTexto
                                          : "Toca para chatear"
                                color: Tema.colorTextoTenue
                                font.pixelSize: 11.5 * Tema.escala
                            }
                        }
                        // Estado de presencia (punto + palabra, no solo el
                        // punto -- pedido explícito tras probar la
                        // pestaña: un color solo puede confundir) + badge
                        // de no-leídos, apilados a la derecha.
                        Column {
                            id: columnaEstadoAmigo
                            anchors.right: parent.right
                            anchors.rightMargin: 12 * Tema.escala
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6 * Tema.escala
                            Row {
                                anchors.right: parent.right
                                spacing: 5 * Tema.escala
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 7 * Tema.escala
                                    height: 7 * Tema.escala
                                    radius: width / 2
                                    color: filaAmigoChat.estado === "CONECTADO" ? "#7FAE7A"
                                           : filaAmigoChat.estado === "EN_PARTIDA" ? Tema.colorAccent
                                           : Tema.colorTextoMuyTenue
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: filaAmigoChat.estado === "CONECTADO" ? "Conectado"
                                          : filaAmigoChat.estado === "EN_PARTIDA" ? "En partida"
                                          : "Desconectado"
                                    color: Tema.colorTextoTenue
                                    font.pixelSize: 11 * Tema.escala
                                }
                            }
                            Rectangle {
                                id: badgeNoLeidosAmigo
                                visible: filaAmigoChat.noLeidos > 0
                                anchors.right: parent.right
                                width: 20 * Tema.escala
                                height: 20 * Tema.escala
                                radius: width / 2
                                color: Tema.colorAccent
                                Text {
                                    anchors.centerIn: parent
                                    text: filaAmigoChat.noLeidos > 9 ? "9+" : filaAmigoChat.noLeidos + ""
                                    color: Tema.colorTextoSobreOscuro
                                    font.pixelSize: 10 * Tema.escala
                                    font.bold: true
                                }
                            }
                        }
                        // Hit-test dividido: el resto de la fila selecciona
                        // la conversación (se muestra en el panel derecho),
                        // un área de toque encima del avatar (MÁS grande
                        // que su bounding box de 40px, declarada DESPUÉS =
                        // prioridad de hit-test sobre la de abajo) abre el
                        // perfil público.
                        MouseArea {
                            id: zonaHoverAmigo
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: abrirChatAmigo(filaAmigoChat.accountId, filaAmigoChat.username, filaAmigoChat.estado)
                        }
                        MouseArea {
                            width: 46 * Tema.escala
                            height: 46 * Tema.escala
                            cursorShape: Qt.PointingHandCursor
                            anchors.centerIn: avatarFilaAmigo
                            onClicked: popupPerfilJugador.abrir(filaAmigoChat.accountId)
                        }
                        }
                    }
                }

                Rectangle {
                    id: panelChatAmigo
                    width: parent.width - listaAmigosChat.width - parent.spacing
                    height: parent.height
                    radius: 12 * Tema.escala
                    border.width: 1
                    border.color: chatAmigoSeleccionado >= 0 ? Tema.colorAccent : Qt.rgba(0, 0, 0, 0.35)
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                        GradientStop { position: 1.0; color: Tema.colorPanel }
                    }
                    // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                    layer.enabled: true
                    layer.effect: ShaderEffect {
                        property variant source
                        property real amplitud: 30.0
                        fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
                    }

                    // Placeholder -- "apagado", sin conversación elegida.
                    Column {
                        visible: chatAmigoSeleccionado < 0
                        anchors.centerIn: parent
                        spacing: 10 * Tema.escala
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "💬"
                            font.pixelSize: 34 * Tema.escala
                            opacity: 0.35
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Elige una conversación de la lista"
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 13 * Tema.escala
                        }
                    }

                    // Conversación activa.
                    Column {
                        visible: chatAmigoSeleccionado >= 0
                        anchors.fill: parent
                        anchors.margins: 16 * Tema.escala
                        spacing: 12 * Tema.escala

                        Row {
                            id: cabeceraChatAmigo
                            width: parent.width
                            spacing: 10 * Tema.escala
                            BotonContorno {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "←"
                                onClicked: chatAmigoSeleccionado = -1
                            }
                            Avatar {
                                anchors.verticalCenter: parent.verticalCenter
                                letra: chatAmigoSeleccionadoNombre.length > 0
                                           ? chatAmigoSeleccionadoNombre.charAt(0).toUpperCase() : "?"
                                tamano: 34 * Tema.escala
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3 * Tema.escala
                                Text {
                                    text: chatAmigoSeleccionadoNombre
                                    color: Tema.colorTexto
                                    font.bold: true
                                    font.pixelSize: 15 * Tema.escala
                                }
                                Row {
                                    spacing: 5 * Tema.escala
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 7 * Tema.escala
                                        height: 7 * Tema.escala
                                        radius: width / 2
                                        color: chatAmigoSeleccionadoEstado === "CONECTADO" ? "#7FAE7A"
                                               : chatAmigoSeleccionadoEstado === "EN_PARTIDA" ? Tema.colorAccent
                                               : Tema.colorTextoMuyTenue
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: chatAmigoSeleccionadoEstado === "CONECTADO" ? "Conectado"
                                              : chatAmigoSeleccionadoEstado === "EN_PARTIDA" ? "En partida"
                                              : "Desconectado"
                                        color: Tema.colorTextoTenue
                                        font.pixelSize: 11 * Tema.escala
                                    }
                                }
                            }
                        }

                        ChatBox {
                            width: parent.width
                            height: parent.height - cabeceraChatAmigo.height - parent.spacing
                            activo: true
                            modelo: modeloConversacionAmigos
                            miNombre: nombreUsuario.text
                            onEnviar: (texto) => {
                                redcliente.enviarMensajeDirecto(servidorHost, servidorPuerto, chatAmigoSeleccionado, texto);
                            }
                        }
                    }
                }
            }

            // ── Buscar jugadores ──────────────────────────────────────────
            // Item en vez de Column -- la fila de búsqueda queda FIJA
            // arriba y la lista de resultados llena todo lo que sobra de
            // panelSocial (antes tenía un tope de 380*escala sin relación
            // con el alto real de la ventana, mismo bug que Tienda).
            Item {
                visible: pestanaSocialActual === 1
                anchors.fill: parent

                Row {
                    id: filaBusquedaSocial
                    anchors.top: parent.top
                    spacing: 8 * Tema.escala
                    CampoTexto {
                        id: campoBusquedaSocial
                        anchors.verticalCenter: parent.verticalCenter
                        width: 260 * Tema.escala
                        placeholderText: (activeFocus || text.length > 0) ? "" : "Nombre de usuario"
                        font.pixelSize: 13 * Tema.escala
                        onAccepted: botonBuscarSocial.clicked()
                    }
                    BotonContorno {
                        id: botonBuscarSocial
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Buscar"
                        onClicked: {
                            mensajeErrorSocial = "";
                            if (campoBusquedaSocial.text.length > 0)
                                redcliente.buscarJugadores(servidorHost, servidorPuerto, campoBusquedaSocial.text);
                        }
                    }
                }

                Rectangle {
                    anchors.top: filaBusquedaSocial.bottom
                    anchors.topMargin: 12 * Tema.escala
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: 200 * Tema.escala
                    visible: modeloBusqueda.count === 0
                    radius: 10 * Tema.escala
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.35)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                        GradientStop { position: 1.0; color: Tema.colorPanel }
                    }
                    // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                    layer.enabled: true
                    layer.effect: ShaderEffect {
                        property variant source
                        property real amplitud: 30.0
                        fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
                    }
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 60 * Tema.escala
                        text: "Busca por nombre de usuario para mandar una solicitud de amistad."
                        color: Tema.colorTextoTenue
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: 13 * Tema.escala
                    }
                }
                ListView {
                    visible: modeloBusqueda.count > 0
                    anchors.top: filaBusquedaSocial.bottom
                    anchors.topMargin: 12 * Tema.escala
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    clip: true
                    spacing: 8 * Tema.escala
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    model: modeloBusqueda
                    delegate: Rectangle {
                        id: filaBusqueda
                        required property int accountId
                        required property int pendiente
                        required property string username
                        readonly property bool solicitudEnviada: filaBusqueda.pendiente === 1
                        width: ListView.view.width
                        height: 58 * Tema.escala
                        radius: 10 * Tema.escala
                        border.width: 1
                        border.color: Qt.rgba(0, 0, 0, 0.35)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                            GradientStop { position: 1.0; color: Tema.colorPanel }
                        }
                        // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                        layer.enabled: true
                        layer.effect: ShaderEffect {
                            property variant source
                            property real amplitud: 30.0
                            fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 14 * Tema.escala
                            spacing: 12 * Tema.escala
                            Avatar {
                                anchors.verticalCenter: parent.verticalCenter
                                letra: filaBusqueda.username.length > 0 ? filaBusqueda.username.charAt(0).toUpperCase() : "?"
                                tamano: 36 * Tema.escala
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: filaBusqueda.username
                                color: Tema.colorTexto
                                font.pixelSize: 14 * Tema.escala
                            }
                        }
                        // Fila completa abre el perfil público -- estas
                        // listas nunca compiten con la acción de chat
                        // (por diseño no son ya-amigos, ver el plan).
                        // Declarada ANTES del botón para que este último
                        // (declarado después) tenga prioridad de hit-test
                        // en su propia área.
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popupPerfilJugador.abrir(filaBusqueda.accountId)
                        }
                        BotonContorno {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 14 * Tema.escala
                            enabled: !filaBusqueda.solicitudEnviada
                            opacity: filaBusqueda.solicitudEnviada ? 0.6 : 1.0
                            text: filaBusqueda.solicitudEnviada ? "Enviada" : "Enviar solicitud"
                            onClicked: {
                                pendienteSolicitudUsername = filaBusqueda.username;
                                redcliente.enviarSolicitudAmistad(servidorHost, servidorPuerto, filaBusqueda.username);
                            }
                        }
                    }
                }
            }

            // ── Jugadores Recientes ────────────────────────────────────────
            // Ambos, directos hijos de panelSocial (Item) -- mismo criterio
            // que Buscar/Solicitudes: sin tope de altura fijo.
            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 200 * Tema.escala
                visible: pestanaSocialActual === 2 && modeloRecientes.count === 0
                radius: 10 * Tema.escala
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.35)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                    GradientStop { position: 1.0; color: Tema.colorPanel }
                }
                // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                layer.enabled: true
                layer.effect: ShaderEffect {
                    property variant source
                    property real amplitud: 30.0
                    fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
                }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 60 * Tema.escala
                    text: "Todavía no has compartido mesa con nadie en las últimas 24h."
                    color: Tema.colorTextoTenue
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13 * Tema.escala
                }
            }
            ListView {
                visible: pestanaSocialActual === 2 && modeloRecientes.count > 0
                anchors.fill: parent
                clip: true
                spacing: 8 * Tema.escala
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                model: modeloRecientes
                delegate: Rectangle {
                    id: filaReciente
                    required property int accountId
                    required property int pendiente
                    required property string username
                    readonly property bool solicitudEnviada: filaReciente.pendiente === 1
                    width: ListView.view.width
                    height: 58 * Tema.escala
                    radius: 10 * Tema.escala
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.35)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                        GradientStop { position: 1.0; color: Tema.colorPanel }
                    }
                    // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                    layer.enabled: true
                    layer.effect: ShaderEffect {
                        property variant source
                        property real amplitud: 30.0
                        fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 14 * Tema.escala
                        spacing: 12 * Tema.escala
                        Avatar {
                            anchors.verticalCenter: parent.verticalCenter
                            letra: filaReciente.username.length > 0 ? filaReciente.username.charAt(0).toUpperCase() : "?"
                            tamano: 36 * Tema.escala
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: filaReciente.username
                            color: Tema.colorTexto
                            font.pixelSize: 14 * Tema.escala
                        }
                    }
                    // Fila completa abre el perfil público -- mismo
                    // criterio que filaBusqueda (ver el comentario ahí).
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popupPerfilJugador.abrir(filaReciente.accountId)
                    }
                    BotonContorno {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 14 * Tema.escala
                        enabled: !filaReciente.solicitudEnviada
                        opacity: filaReciente.solicitudEnviada ? 0.6 : 1.0
                        text: filaReciente.solicitudEnviada ? "Enviada" : "Enviar solicitud"
                        onClicked: {
                            pendienteSolicitudUsername = filaReciente.username;
                            redcliente.enviarSolicitudAmistad(servidorHost, servidorPuerto, filaReciente.username);
                        }
                    }
                }
            }

            // ── Solicitudes ────────────────────────────────────────────────
            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 200 * Tema.escala
                visible: pestanaSocialActual === 3 && modeloSolicitudes.count === 0
                radius: 10 * Tema.escala
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.35)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                    GradientStop { position: 1.0; color: Tema.colorPanel }
                }
                // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                layer.enabled: true
                layer.effect: ShaderEffect {
                    property variant source
                    property real amplitud: 30.0
                    fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
                }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 60 * Tema.escala
                    text: "No tienes solicitudes de amistad pendientes."
                    color: Tema.colorTextoTenue
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13 * Tema.escala
                }
            }
            ListView {
                visible: pestanaSocialActual === 3 && modeloSolicitudes.count > 0
                anchors.fill: parent
                clip: true
                spacing: 8 * Tema.escala
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                model: modeloSolicitudes
                delegate: Rectangle {
                    id: filaSolicitud
                    required property int solicitudId
                    required property int fromAccountId
                    required property int creadoEn
                    required property string fromUsername
                    width: ListView.view.width
                    height: 60 * Tema.escala
                    radius: 10 * Tema.escala
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.35)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                        GradientStop { position: 1.0; color: Tema.colorPanel }
                    }
                    // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                    layer.enabled: true
                    layer.effect: ShaderEffect {
                        property variant source
                        property real amplitud: 30.0
                        fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 14 * Tema.escala
                        spacing: 12 * Tema.escala
                        Avatar {
                            anchors.verticalCenter: parent.verticalCenter
                            letra: filaSolicitud.fromUsername.length > 0 ? filaSolicitud.fromUsername.charAt(0).toUpperCase() : "?"
                            tamano: 36 * Tema.escala
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: filaSolicitud.fromUsername
                            color: Tema.colorTexto
                            font.pixelSize: 14 * Tema.escala
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 14 * Tema.escala
                        spacing: 8 * Tema.escala
                        BotonContorno {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Rechazar"
                            onClicked: redcliente.responderSolicitud(
                                servidorHost, servidorPuerto, filaSolicitud.solicitudId, false)
                        }
                        BotonRelleno {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Aceptar"
                            onClicked: redcliente.responderSolicitud(
                                servidorHost, servidorPuerto, filaSolicitud.solicitudId, true)
                        }
                    }
                }
            }
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
                text: ventana.sesionOffline ? "Nueva partida local" : "Crear sala"
                color: Tema.colorTexto
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
                // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                layer.enabled: true
                layer.effect: ShaderEffect {
                    property variant source
                    property real amplitud: 30.0
                    fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
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
                        // Sin conexión no hay "sala" que crear ni con quién
                        // compartirla: se reutiliza el MISMO formulario, pero
                        // la sección de red entera (nombre, pública, tamaño,
                        // rellenar, abierta) se oculta y en su lugar se elige
                        // contra cuántos bots jugar. El resto de reglas
                        // (apuesta y partida) valen igual en local.
                        Column {
                            width: parent.width
                            spacing: 6 * Tema.escala
                            visible: ventana.sesionOffline
                            Text {
                                text: "PARTIDA LOCAL"
                                color: Tema.colorTextoMuyTenue
                                font.pixelSize: 11 * Tema.escala
                                font.letterSpacing: 1
                            }
                            Rectangle { width: parent.width; height: 1; color: Tema.colorBorde }
                        }
                        Row {
                            width: parent.width
                            spacing: 12 * Tema.escala
                            visible: ventana.sesionOffline
                            Text {
                                width: 330 * Tema.escala
                                font.pixelSize: 13 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Número de bots (rivales)"
                                color: Tema.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            TextField {
                                id: campoNumBots
                                width: 60 * Tema.escala
                                text: "3"
                                color: Tema.colorTexto
                                font.pixelSize: 13 * Tema.escala
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 1; top: 8 }
                                background: MarcoHueco {
                                    radius: 6 * Tema.escala
                                    activo: campoNumBots.activeFocus
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 6 * Tema.escala
                            visible: !ventana.sesionOffline
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
                            visible: !ventana.sesionOffline
                            width: parent.width
                            placeholderText: (activeFocus || text.length > 0) ? "" : "Nombre de la sala"
                            color: Tema.colorTexto
                            font.pixelSize: 13 * Tema.escala
                            placeholderTextColor: Tema.colorTextoMuyTenue
                            background: MarcoHueco {
                                radius: 6 * Tema.escala
                                activo: campoNombreSala.activeFocus
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 12 * Tema.escala
                            visible: !ventana.sesionOffline
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
                            visible: !ventana.sesionOffline
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
                                color: Tema.colorTexto
                                font.pixelSize: 13 * Tema.escala
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 2; top: 9 }
                                background: MarcoHueco {
                                    radius: 6 * Tema.escala
                                    activo: campoTamanoSala.activeFocus
                                }
                            }
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12 * Tema.escala
                            visible: !ventana.sesionOffline
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
                            visible: !ventana.sesionOffline
                            text: "Si faltan humanos al arrancar (o alguien se va con fichas), un bot ocupa el asiento en vez de perderlo o repartir sus fichas."
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 10 * Tema.escala
                            wrapMode: Text.WordWrap
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12 * Tema.escala
                            visible: !ventana.sesionOffline
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
                            visible: !ventana.sesionOffline
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
                                onElegido: (indice) => seleccionado = indice
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
                                onElegido: (indice) => seleccionado = indice
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
                                color: Tema.colorTexto
                                font.pixelSize: 13 * Tema.escala
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 1; top: 10000 }
                                background: MarcoHueco {
                                    radius: 6 * Tema.escala
                                    activo: campoMonteFijo.activeFocus
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
                                color: Tema.colorTexto
                                font.pixelSize: 13 * Tema.escala
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 1; top: 200 }
                                background: MarcoHueco {
                                    radius: 6 * Tema.escala
                                    activo: campoNumManos.activeFocus
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
                                color: Tema.colorTexto
                                font.pixelSize: 13 * Tema.escala
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 2; top: 1000 }
                                background: MarcoHueco {
                                    radius: 6 * Tema.escala
                                    activo: campoCiegaGrande.activeFocus
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
                                color: Tema.colorTexto
                                font.pixelSize: 13 * Tema.escala
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 100; top: 100000 }
                                background: MarcoHueco {
                                    radius: 6 * Tema.escala
                                    activo: campoSaldoInicial.activeFocus
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
                    text: ventana.sesionOffline ? "Empezar partida" : "Crear sala"
                    onClicked: {
                        // Sin conexión el mismo formulario arranca una
                        // partida LOCAL: mismas reglas de apuesta y de
                        // partida, sin nada de sala/red. Ver
                        // LocalGameClient::iniciarPartidaLocal().
                        if (ventana.sesionOffline) {
                            ventana.modoOfflineActivo = true;
                            redcliente.iniciarPartidaLocal(
                                nombreUsuario.text,
                                parseInt(campoNumBots.text) || 3,
                                parseInt(campoNumManos.text) || 20,
                                parseInt(campoCiegaGrande.text) || 20,
                                parseInt(campoSaldoInicial.text) || 1000,
                                selectorLimite.seleccionado,
                                interruptorMinRaise.activo,
                                parseInt(campoMonteFijo.text) || 40,
                                selectorDificultad.seleccionado,
                                interruptorRecompra.activo,
                                interruptorPreguntarExtension.activo);
                            return;
                        }
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
                // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                layer.enabled: true
                layer.effect: ShaderEffect {
                    property variant source
                    property real amplitud: 30.0
                    fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
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
                        color: Tema.colorTexto
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
                                    color: modelData.nombre === ganadorFinal ? Tema.colorAccent : Tema.colorTexto
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
                            salaIdPropia = "";
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
                        color: Tema.colorTexto
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

                // Con sesión iniciada únicamente -- un invitado no tiene
                // amigos que invitar. Funciona igual en sala pública o
                // privada (a diferencia de "Código para invitar", que solo
                // se ve en privadas).
                BotonContorno {
                    visible: tokenSesion !== "" && salaIdPropia !== ""
                    text: "Invitar amigos"
                    radioBorde: 999
                    onClicked: popupInvitarAmigos.abrir()
                }

                BotonContorno {
                    text: "Abandonar sala"
                    radioBorde: 999
                    onClicked: {
                        // abandonar() ya manda LEAVE y marca
                        // desconexionEsperada_ = true del lado C++ (evita
                        // que el cierre del socket que sigue dispare el
                        // overlay de "reconectando") -- optimista, sin
                        // esperar confirmación del servidor: el LEAVE ya
                        // está manejado del lado servidor desde siempre,
                        // esto solo le faltaba un botón.
                        redcliente.abandonar();
                        ventana.pantalla = "Salas";
                    }
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
                onEnviar: (texto) => redcliente.enviarChat(texto, "sala")
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
                mostrarChuleta: true
                onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
                onAbrirChuleta: popupChuleta.open()
            }

            // Chuleta de manos, accesible con un clic desde la mesa (antes
            // enterrada dentro del cajón de ajustes -- pedido explícito: un
            // botón de ayuda junto a los 3 puntos). Mismo molde que
            // popupInfoRanking (ver pantalla "Ranking" más arriba).
            Popup {
                id: popupChuleta
                parent: Overlay.overlay
                anchors.centerIn: parent
                modal: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                width: Math.min(560 * Tema.escala, (parent ? parent.width : 560) - 60 * Tema.escala)
                height: Math.min(620 * Tema.escala, (parent ? parent.height : 620) - 60 * Tema.escala)
                padding: 20 * Tema.escala

                background: Rectangle {
                    color: Tema.colorPanel
                    radius: 12 * Tema.escala
                    border.width: 1
                    border.color: Tema.colorAccent
                }

                contentItem: ScrollView {
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    // Chuleta "de verdad": una fila de 5 cartas por cada
                    // combinación, como la que viene con una baraja física
                    // — mucho más rápida de leer que una lista de nombres.
                    Column {
                        width: popupChuleta.availableWidth
                        spacing: 10 * Tema.escala
                        Text {
                            width: parent.width
                            text: "Ranking de manos"
                            color: Tema.colorTexto
                            font.family: Tema.fuenteElegante
                            font.bold: true
                            font.pixelSize: 16 * Tema.escala
                        }
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
                            color: Tema.colorTexto
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
                            color: Tema.colorTextoTenue
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
                        color: Tema.colorTexto
                        font.pixelSize: 14 * Tema.escala
                        selectionColor: Tema.colorAccent
                        horizontalAlignment: Text.AlignHCenter
                        // Fondo/borde a mano — por defecto un TextField de
                        // Qt Quick Controls sale gris claro/blanco, fuera de
                        // sitio en esta paleta. El borde se ilumina con el
                        // color de acento solo cuando tiene el foco.
                        background: MarcoHueco {
                            radius: 6 * Tema.escala
                            activo: campoSubida.activeFocus
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
                redcliente.conectarPresencia(servidorHost, servidorPuerto);
                // Catálogo de la tienda, ya mismo -- pedido para poder
                // resolver nombre/rareza de un título AJENO (perfil
                // público de otro jugador, ver PopupPerfilJugador.qml) sin
                // depender de haber visitado Cuenta/Tienda antes en esta
                // sesión (visibilidad a otros jugadores, 2026-09-01).
                redcliente.consultarTienda(servidorHost, servidorPuerto, tokenSesion);
                ventana.pedirDatosDeCuenta();
            }
            function onRegistroError(mensaje) {
                mensajeErrorLogin = mensaje;
            }
            function onLoginOk(accountId, username, token) {
                enviandoLogin = false;
                reautenticacionPendiente = false;
                nombreUsuario.text = username;
                tokenSesion = token;
                mensajeErrorLogin = "";
                pantalla = "Salas";
                redcliente.refrescarSalas(servidorHost, servidorPuerto);
                redcliente.conectarPresencia(servidorHost, servidorPuerto);
                // Ver el comentario gemelo en onRegistroOk.
                redcliente.consultarTienda(servidorHost, servidorPuerto, tokenSesion);
                ventana.pedirDatosDeCuenta();
            }
            function onLoginError(mensaje) {
                enviandoLogin = false;
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
            // El login automático con el token guardado no tuvo respuesta (red caída
            // o lenta). NO es una sesión inválida: el token se queda y se reintenta
            // en cuanto el indicador de Inicio confirme servidor (onConexionComprobada).
            function onReautenticacionSinRespuesta() {
                reautenticacionPendiente = true;
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
            // Fase 1 del sistema de progresión -- herramienta de
            // estadísticas mínima (ver el botón admin en la pestaña Perfil).
            function onEstadisticasExportadas(archivo) {
                mensajeExportacion = "Exportado a data/" + archivo + " en el servidor.";
            }
            function onEstadisticasExportadasError(mensaje) {
                mensajeExportacion = mensaje;
            }
            // Herramienta de pruebas/admin, punto 2 (ver el bloque admin en
            // la pestaña Perfil) -- mismo criterio que las dos de arriba.
            function onAdminConcederOk(mensaje) {
                mensajeAdminConceder = mensaje;
                // Mismo motivo que onObjetoEquipado() -- si te lo has
                // concedido a ti mismo, sin esto el resultado no se ve
                // hasta salir y volver a entrar en Cuenta (loadoutMarco/
                // tiendaCrudo se quedan con el valor de antes de conceder).
                // Barato/inofensivo pedirlo también cuando se concede a
                // OTRA cuenta -- solo trae tu propio loadout de nuevo, sin
                // cambios reales.
                redcliente.consultarLoadout(servidorHost, servidorPuerto, tokenSesion);
                redcliente.consultarTienda(servidorHost, servidorPuerto, tokenSesion);
            }
            function onAdminConcederError(mensaje) {
                mensajeAdminConceder = mensaje;
            }
            function onAdminFabricarOk(mensaje) {
                mensajeAdminFabricar = mensaje;
            }
            function onAdminFabricarError(mensaje) {
                mensajeAdminFabricar = mensaje;
            }
            // Fase 4 del sistema de progresión -- ya llega parseado
            // (parsearFilasChat() en C++, ver NetworkClient.hpp), un
            // QVariantMap por logro.
            function onLogrosActualizados(logros) {
                var ordenados = ordenarLogros(logros);
                logrosModel.clear();
                for (var i = 0; i < ordenados.length; i++) logrosModel.append(ordenados[i]);
            }
            // ── Tienda (Fase 5 del sistema de progresión) ───────────────────
            function onTiendaActualizada(tienda) {
                tiendaCrudo = tienda;
                reordenarTienda();
            }
            function onObjetoComprado(codigo) {
                mensajeTienda = "";
                // Refresca el catálogo (poseido pasa a true) -- no hace
                // falta tocar el loadout, comprar no equipa solo.
                redcliente.consultarTienda(servidorHost, servidorPuerto, tokenSesion);
            }
            function onObjetoCompraError(mensaje) {
                mensajeTienda = mensaje;
            }
            function onObjetoEquipado(slot, codigo) {
                mensajeTienda = "";
                redcliente.consultarLoadout(servidorHost, servidorPuerto, tokenSesion);
                redcliente.consultarTienda(servidorHost, servidorPuerto, tokenSesion);
            }
            function onObjetoEquiparError(mensaje) {
                mensajeTienda = mensaje;
            }
            // ── Social ────────────────────────────────────────────────────
            function onJugadoresBusquedaActualizados(jugadores) {
                modeloBusqueda.clear();
                for (var i = 0; i < jugadores.length; i++) modeloBusqueda.append(jugadores[i]);
            }
            function onAmigosActualizados(amigos) {
                modeloAmigos.clear();
                for (var i = 0; i < amigos.length; i++) modeloAmigos.append(amigos[i]);
                reconstruirModeloAmigosConChat();
            }
            function onSolicitudesActualizadas(solicitudes) {
                modeloSolicitudes.clear();
                for (var i = 0; i < solicitudes.length; i++) modeloSolicitudes.append(solicitudes[i]);
            }
            function onJugadoresRecientesActualizados(recientes) {
                modeloRecientes.clear();
                for (var i = 0; i < recientes.length; i++) modeloRecientes.append(recientes[i]);
            }
            function onResumenChatsActualizado(chats) {
                modeloResumenChats.clear();
                for (var i = 0; i < chats.length; i++) modeloResumenChats.append(chats[i]);
                reconstruirModeloAmigosConChat();
            }
            // PUSH por el socket de presencia: si estamos mirando Amigos,
            // refresca el resumen para que el último mensaje/badge se
            // pongan al día sin esperar a salir y volver a entrar en la
            // pestaña. Si además es justo la conversación abierta en el
            // panel derecho, releer también esa -- más barato que tocar el
            // modelo a mano y de paso marca leído server-side.
            function onMensajeDirectoRecibido(fromAccountId, fromUsername, texto, creadoEn, mensajeId) {
                // Releer la conversación la marca como leída, así que solo se
                // hace si se está VIENDO: chatAmigoSeleccionado sigue puesto
                // aunque estés en otra pantalla, y antes el mensaje quedaba
                // leído sin que nadie lo viera. Y en ese caso el resumen lo
                // pide la respuesta (onConversacionActualizada), ya con el
                // mensaje leído -- pedirlo aquí a la vez podía llegar antes.
                var viendoEseChat = pantalla === "Social" && pestanaSocialActual === 0
                                    && chatAmigoSeleccionado === fromAccountId;
                if (viendoEseChat) {
                    redcliente.listarConversacion(servidorHost, servidorPuerto, chatAmigoSeleccionado);
                } else if (pestanaSocialActual === 0) {
                    redcliente.listarResumenChats(servidorHost, servidorPuerto);
                }
            }
            function onConversacionActualizada(mensajes) {
                // El servidor marca como leídos los mensajes de esta
                // conversación ANTES de devolverla
                // (AccountManager::listarConversacion), así que ahora el
                // resumen sí sale con el aviso de no leídos al día. Sin esto,
                // abrir un chat no quitaba su aviso de la lista (visto
                // 2026-09-10).
                redcliente.listarResumenChats(servidorHost, servidorPuerto);
                modeloConversacionAmigos.clear();
                for (var i = 0; i < mensajes.length; i++) {
                    var m = mensajes[i];
                    modeloConversacionAmigos.append({
                        autor: m.fromAccountId === chatAmigoSeleccionado ? chatAmigoSeleccionadoNombre : nombreUsuario.text,
                        mensaje: m.texto,
                        hora: Qt.formatTime(new Date(m.creadoEn * 1000), "hh:mm")
                    });
                }
            }
            function onInvitacionSalaRecibida(fromAccountId, fromUsername, salaId, codigo, nombreSala) {
                bannerInvitacionSala.mostrar(fromAccountId, fromUsername, salaId, codigo, nombreSala);
            }
            function onSolicitudAmistadEnviada() {
                mensajeErrorSocial = "";
                if (pendienteSolicitudUsername !== "") marcarPendienteEnModelos(pendienteSolicitudUsername);
                pendienteSolicitudUsername = "";
            }
            function onSolicitudAmistadError(mensaje) {
                pendienteSolicitudUsername = "";
                mensajeErrorSocial = mensaje;
            }
            function onSolicitudRespondida() {
                redcliente.listarSolicitudesPendientes(servidorHost, servidorPuerto);
                if (pestanaSocialActual === 0) redcliente.listarAmigos(servidorHost, servidorPuerto);
            }
            function onSolicitudRespondidaError(mensaje) {
                mensajeErrorSocial = mensaje;
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
                // Login automático que se quedó sin respuesta (onReautenticacionSinRespuesta):
                // en cuanto vuelve a haber servidor, se reintenta con el mismo token.
                if (conectado && reautenticacionPendiente) {
                    reautenticacionPendiente = false;
                    if (tokenSesion !== "" && pantalla === "Inicio")
                        redcliente.iniciarSesionConToken(servidorHost, servidorPuerto, tokenSesion);
                }
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
                salaIdPropia = salaId;
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
            function onRankingActualizado(rankingCsv, acabadosCsv) {
                var filas = [];
                // Acabados (fase 2 del material): llegan en una lista aparte, por
                // accountId -- ver CONSULTAR_RANKING en el servidor. "" con un
                // servidor anterior, y entonces todo sigue al marco.
                var acabadosPorCuenta = ({});
                if (acabadosCsv) {
                    var filasAcabado = acabadosCsv.split(";");
                    for (var k = 0; k < filasAcabado.length; k++) {
                        var ca = filasAcabado[k].split(":");
                        acabadosPorCuenta[ca[0]] = ca;
                    }
                }
                if (rankingCsv.length > 0) {
                    var partes = rankingCsv.split(";");
                    for (var i = 0; i < partes.length; i++) {
                        var campos = partes[i].split(":");
                        // "username" es el resto tras los 11 primeros campos,
                        // no campos[11] a secas -- mismo motivo que "nombre"/
                        // "fecha" en salas/guardadas más arriba. accountId
                        // antepuesto (Cerrar Social v1) -- abre el perfil
                        // público de cada fila. "elo" es la Fase 3. Los 7
                        // campos de loadout son el podio de Ranking
                        // (2026-09-01, ver memoria qt_progression_review_2026_09_01).
                        filas.push({
                            accountId: parseInt(campos[0]),
                            partidasJugadas: parseInt(campos[1]),
                            partidasGanadas: parseInt(campos[2]),
                            elo: parseInt(campos[3]),
                            tieneMarcoBasico: campos[4] === "1",
                            textura: campos[5],
                            efecto: campos[6],
                            decoracionLateral1: campos[7],
                            decoracionLateral2: campos[8],
                            decoracionSuperior: campos[9],
                            acabadoLateral1: acabadosPorCuenta[campos[0]] ? acabadosPorCuenta[campos[0]][1] || "" : "",
                            acabadoLateral2: acabadosPorCuenta[campos[0]] ? acabadosPorCuenta[campos[0]][2] || "" : "",
                            acabadoSuperior: acabadosPorCuenta[campos[0]] ? acabadosPorCuenta[campos[0]][3] || "" : "",
                            titulo: campos[10],
                            username: campos.slice(11).join(":")
                        });
                    }
                }
                rankingCrudo = filas;
                reordenarRanking();
            }
            // redcliente.estadisticasCuenta es una Q_PROPERTY (QVariantMap),
            // no parámetros de la señal -- ver el comentario largo junto a
            // consultarEstadisticas() en NetworkClient.hpp (bug real de
            // Android con señales de muchos parámetros).
            // Respuesta a sincronizarXpOffline(). "acreditado" puede ser MENOR que
            // "reclamado": el servidor acota el XP ganado sin conexión a lo plausible
            // para el tiempo transcurrido (ver AccountManager::sincronizarXpOffline()).
            // Se confirma con lo ACREDITADO y se refrescan las estadísticas para que
            // el nivel de la pantalla refleje ya lo nuevo.
            function onXpOfflineSincronizado(acreditado, reclamado, mensaje) {
                modoJuego.confirmarXpOfflineSincronizado(acreditado);
                if (acreditado > 0) {
                    redcliente.consultarEstadisticas(servidorHost, servidorPuerto, tokenSesion);
                }
                mensajeErrorConexion = mensaje;
            }
            function onEstadisticasCuentaCambiaron() {
                var m = redcliente.estadisticasCuenta;
                statsManosJugadas = m.manosJugadas;
                statsManosGanadas = m.manosGanadas;
                statsPartidasJugadas = m.partidasJugadas;
                statsPartidasGanadas = m.partidasGanadas;
                statsTieneMarcoBasico = m.tieneMarcoBasico;
                statsVecesGanoSinShowdown = m.vecesGanoSinShowdown;
                statsRachaManosGanadas = m.rachaManosGanadas;
                statsRachaActual = m.rachaActual;
                statsRachaMaxima = m.rachaMaxima;
                statsMayorBote = m.mayorBote;
                statsMejorManoNombre = m.mejorManoNombre;
                statsMejorManoFecha = m.mejorManoFecha;
                statsVecesCartaAlta = m.vecesCartaAlta;
                statsVecesPareja = m.vecesPareja;
                statsVecesDoblePareja = m.vecesDoblePareja;
                statsVecesTrio = m.vecesTrio;
                statsVecesEscalera = m.vecesEscalera;
                statsVecesColor = m.vecesColor;
                statsVecesFullHouse = m.vecesFullHouse;
                statsVecesPoker = m.vecesPoker;
                statsVecesEscaleraColor = m.vecesEscaleraColor;
                statsVecesEscaleraReal = m.vecesEscaleraReal;
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
                if (tokenSesion !== "") redcliente.conectarPresencia(servidorHost, servidorPuerto);
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
                soyHost = (host === nombreUsuario.text);
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
            function onPartidaIniciada(manos, tipoLimite, permitirRecompra, rellenarConBots, preguntarExtension, host) {
                pantalla = "Partida";
                chatActive = false;
                mensajeEnEspera = "";
                objetivoManos = manos;
                tipoLimiteActual = tipoLimite;
                permitirRecompraActual = permitirRecompra;
                rellenarConBotsActual = rellenarConBots;
                preguntarExtensionActual = preguntarExtension;
                soyHost = (host === nombreUsuario.text);
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
                    // campos[4..9]: visibilidad a otros jugadores, parte B
                    // (2026-09-01, ver memoria qt_progression_review_2026_09_01)
                    // -- loadout completo de cada jugador sentado, no solo
                    // partidasGanadas, para que Asiento.qml pinte marco+
                    // textura+efecto+decoraciones reales de los rivales.
                    jugadoresPartida.append({
                        nombre: campos[0],
                        saldo: campos[1],
                        apuesta: campos[2],
                        partidasGanadas: campos.length > 3 ? parseInt(campos[3]) : 0,
                        tieneMarcoBasico: campos.length > 4 ? campos[4] === "1" : false,
                        textura: campos.length > 5 ? campos[5] : "",
                        efecto: campos.length > 6 ? campos[6] : "",
                        decoracionLateral1: campos.length > 7 ? campos[7] : "",
                        decoracionLateral2: campos.length > 8 ? campos[8] : "",
                        decoracionSuperior: campos.length > 9 ? campos[9] : "",
                        acabadoLateral1: campos.length > 10 ? campos[10] : "",
                        acabadoLateral2: campos.length > 11 ? campos[11] : "",
                        acabadoSuperior: campos.length > 12 ? campos[12] : ""
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
                        jugadoresPartida.setProperty(j, "saldo", String(miSaldo));  // el rol nace texto en el append() (campos[1]) y Asiento lo declara string
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
            function onVotoConfirmado() {
                // Ack real del servidor a votar() -- el panel de voto ya
                // NO se cierra al pulsar "Continuar" (optimista, sin
                // esperar respuesta); se cierra aquí. Si el voto nunca
                // llega (socket ya muerto sin detectar la caída aún), el
                // panel se queda visible en vez de desaparecer -- evita el
                // softlock real reportado (overlay de showdown abierto,
                // sin panel dentro, tras una reconexión fallida).
                votoAbierto = false;
                mensajeVoto = "";
            }
            function onHostCambiado(host) {
                // El host efectivo cambió a mitad de partida (el anterior
                // se fue/cayó, o el creador original recuperó el puesto) --
                // mismo recálculo que onLobbyActualizado/onPartidaIniciada.
                hostActual = host;
                soyHost = (host === nombreUsuario.text);
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
                // Modo offline (Torneos > Solitario) -- devolver "redcliente"
                // a NetworkClient ANTES de las dos llamadas de red de abajo
                // (leídas ya de LocalGameClient más arriba, no hace falta
                // esperar más). Ver la propiedad modoOfflineActivo.
                if (ventana.modoOfflineActivo && !ventana.sesionOffline) {
                    modoJuego.activarModoRed();
                    ventana.modoOfflineActivo = false;
                }
                if (tokenSesion !== "") redcliente.conectarPresencia(servidorHost, servidorPuerto);
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
                // Bug real reportado: sin esto, "soyHost" se quedaba en
                // true para siempre tras abandonar (nada lo reseteaba), así
                // que al volver a unirse a la misma sala en curso (cola de
                // "abierta tras inicio") aparecía el botón "Empezar ahora"
                // aunque ya no tuviera ningún sentido ahí.
                soyHost = false;
                // Sin conexión, "Salas" está oculta del riel (lista salas
                // del servidor) -- volver a Torneos, que es de donde se
                // sale a jugar en local.
                pantalla = (ventana.sesionOffline && torneosHabilitados) ? "Torneos" : "Salas";
                // Ver el comentario gemelo en onFinDePartida -- aquí va
                // ANTES de las llamadas de red porque ninguna lee nada de
                // LocalGameClient primero.
                if (ventana.modoOfflineActivo && !ventana.sesionOffline) {
                    modoJuego.activarModoRed();
                    ventana.modoOfflineActivo = false;
                }
                redcliente.refrescarSalas(servidorHost, servidorPuerto);
                if (tokenSesion !== "") redcliente.conectarPresencia(servidorHost, servidorPuerto);
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
                // Ver el comentario en onFinDePartida.
                if (ventana.modoOfflineActivo && !ventana.sesionOffline) {
                    modoJuego.activarModoRed();
                    ventana.modoOfflineActivo = false;
                }
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
                // Mismo motivo que onAbandonaste/onFinDePartida/
                // onPartidaGuardada: sin esto, un showdown/voto que
                // seguía abierto cuando se cayó la conexión se quedaba
                // tapando la pantalla de Inicio para siempre (bug real
                // reportado, parte del softlock de reconexión).
                showdownAbierto = false;
                votoAbierto = false;
                votoExtensionAbierto = false;
                esperandoManosExtra = false;
                soyYoQuienElige = false;
                pantalla = "Inicio";
                mensajeErrorConexion = "Se perdió la conexión con el servidor.";
                if (tokenSesion !== "") redcliente.conectarPresencia(servidorHost, servidorPuerto);
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

        // ── Pantalla Cuenta (riel) ─────────────────────────────────────────────
        // Mudada aquí desde el cajón lateral (2026-08-31) -- ya tiene sitio de
        // sobra para crecer (Progreso/Logros) sin apretar un cajón de 340px
        // pensado solo para Tema/Cliente. Perfil es básicamente el bloque que
        // vivía en el cajón, con los formularios de usuario/contraseña ahora
        // colapsados detrás de un botón en vez de siempre puestos.
        BarraSuperior {
            id: barraCuenta
            visible: ventana.pantalla === "Cuenta"
            anchors.top: parent.top
            anchors.left: rielNavegacion.right
            anchors.right: parent.right
            textoCentro: "Cuenta"
            pantalla: ventana.pantalla
            miSaldoActual: ventana.miSaldoActual
            reconectandoAhora: ventana.reconectandoAhora
            servidorHost: ventana.servidorHost
            servidorPuerto: ventana.servidorPuerto
            mostrarSalir: true
            onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
            onSalir: ventana.pantalla = "Inicio"
        }
        // Título + selector de pestañas FIJOS, fuera del Flickable -- pedido
        // explícito 2026-09-01: "el selector de pestaña arriba tiene que
        // quedarse, el contenido baja... eso aplica a todos los sitios".
        // Antes vivían dentro de columnaCuenta (el Column que scrollCuenta
        // desplaza entero), así que en cuanto una pestaña larga (Progreso
        // con el roadmap, Logros con el catálogo entero) empujaba el
        // contenido más abajo del hueco visible, el propio selector se iba
        // scroll arriba con él -- para volver a otra pestaña había que
        // scrollear hacia arriba primero. Ahora es un Column aparte, sin
        // Flickable, siempre en el mismo sitio.
        Column {
            id: cabeceraCuenta
            visible: ventana.pantalla === "Cuenta"
            anchors.top: barraCuenta.bottom
            anchors.topMargin: 24 * Tema.escala
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: rielNavegacion.width / 2
            width: Math.min(1040 * Tema.escala, ventana.width - rielNavegacion.width - 60 * Tema.escala)
            spacing: 16 * Tema.escala

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Cuenta"
                color: Tema.colorTexto
                font.family: Tema.fuenteElegante
                font.pixelSize: 22 * Tema.escala
            }

            SelectorSegmentado {
                width: parent.width
                opciones: ["Perfil", "Progreso", "Logros", "Personalizar"]
                seleccionado: ventana.pestanaCuentaActual
                onElegido: (indice) => ventana.pestanaCuentaActual = indice
            }
        }
        // Flickable en vez de Column a secas: Logros y Tienda pueden crecer
        // más alto que la ventana (catálogo entero, logros desbloqueados o
        // no) y antes se recortaban sin ninguna forma de llegar al resto —
        // bug real reportado (2026-08-31). anchors.bottom: parent.bottom
        // acota la altura visible al hueco bajo la cabecera fija; el
        // contenido real vive en columnaCuenta y decide cuánto hay que
        // desplazar.
        Flickable {
            id: scrollCuenta
            visible: pantalla === "Cuenta"
            anchors.top: cabeceraCuenta.bottom
            anchors.topMargin: 16 * Tema.escala
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16 * Tema.escala
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: rielNavegacion.width / 2
            // Tope subido de 560 a 1040*escala (mismo criterio que Salas/
            // Ranking/Social) -- de columna estrecha y centrada a aprovechar
            // el ancho real de la ventana en vez del alto (pedido explícito
            // 2026-08-31): cabecera, estadísticas y formularios pasan de
            // apilados a lado a lado.
            width: Math.min(1040 * Tema.escala, ventana.width - rielNavegacion.width - 60 * Tema.escala)
            contentWidth: width
            contentHeight: columnaCuenta.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: columnaCuenta
                width: parent.width
                spacing: 16 * Tema.escala

            // ── Perfil: invitado ────────────────────────────────────────────
            Column {
                width: parent.width
                visible: ventana.pestanaCuentaActual === 0 && !hayCuenta
                spacing: 14 * Tema.escala
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "Estás jugando como invitado. Inicia sesión o crea una cuenta para ver tu perfil, tus estadísticas y gestionarla."
                    color: Tema.colorTextoTenue
                    font.pixelSize: 13 * Tema.escala
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10 * Tema.escala
                    BotonRelleno {
                        text: "Iniciar sesión"
                        onClicked: { mensajeErrorLogin = ""; pantalla = "Login"; }
                    }
                    BotonContorno {
                        text: "Crear cuenta"
                        onClicked: { mensajeErrorLogin = ""; pantalla = "Registro"; }
                    }
                }
            }

            // ── Perfil: con sesión ──────────────────────────────────────────
            Column {
                width: parent.width
                visible: ventana.pestanaCuentaActual === 0 && hayCuenta
                spacing: 18 * Tema.escala

                // Sin conexión, lo que se ve aquí es la foto de la última
                // sesión con servidor (ver LocalGameClient::estadisticasCuenta)
                // -- decirlo, para que nadie interprete estos números como
                // el estado real de su cuenta ahora mismo.
                Text {
                    visible: ventana.sesionOffline
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: Tema.colorTextoTenue
                    font.pixelSize: 11 * Tema.escala
                    text: "Sin conexión · datos de tu última sesión con el servidor, solo lectura."
                }

                // Cabecera horizontal (avatar a la izquierda, identidad a la
                // derecha) en vez de apilada y centrada -- aprovecha el ancho
                // en vez del alto (pedido explícito 2026-08-31).
                Row {
                    width: parent.width
                    spacing: 20 * Tema.escala
                    // Item envolvente en vez de que el Avatar cuelgue
                    // directo del Row -- el anillo de marco (marcoMetalico
                    // en Avatar.qml) se dibuja más grande que avatar.tamano
                    // a propósito, y las decoraciones (laterales/superior)
                    // sobresalen todavía más -- un Row solo reserva espacio
                    // según tamano/tamano, no según lo que de verdad se
                    // pinta. Bug real reportado varias veces 2026-08-31 (el
                    // anillo recortado contra el Flickable de la pantalla
                    // Cuenta) -- 2.1x de lado en vez de intentar calcular el
                    // mínimo exacto: cubre con margen de sobra el peor caso
                    // (corona de 5 cartas arriba + decoración lateral a
                    // cada lado), así que esto ya no hace falta volver a
                    // tocarlo si Perfil algún día también pinta el loadout
                    // completo (pedido explícito: "imagínate que tengamos
                    // cosméticos puestos en los lados o arriba... crea
                    // espacio para ello").
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 72 * Tema.escala * 2.1
                        height: width
                        Avatar {
                            anchors.centerIn: parent
                            letra: nombreUsuario.text.length > 0 ? nombreUsuario.text.charAt(0).toUpperCase() : "?"
                            tamano: 72 * Tema.escala
                            marco: Tema.marcoPorPartidasGanadas(statsPartidasGanadas, statsTieneMarcoBasico)
                            // Bug real encontrado 2026-09-01 (QA en vivo del
                            // usuario con la herramienta admin: "los tengo
                            // equipados... en personalizar, pero en mi
                            // página de cuenta no está") -- este Avatar,
                            // a diferencia del de Progreso más abajo, nunca
                            // recibió el loadout completo, solo el marco.
                            // El Item envolvente ya reservaba de sobra el
                            // espacio para esto desde el comentario de
                            // arriba ("si Perfil algún día también pinta el
                            // loadout completo") -- solo faltaban los 5
                            // bindings.
                            textura: redcliente.loadoutMarco.textura || ""
                            efecto: redcliente.loadoutMarco.efecto || ""
                            decoracionLateral1: redcliente.loadoutMarco.decoracionLateral1 || ""
                            decoracionLateral2: redcliente.loadoutMarco.decoracionLateral2 || ""
                            decoracionSuperior: redcliente.loadoutMarco.decoracionSuperior || ""
                            acabadoLateral1: redcliente.loadoutMarco.acabadoLateral1 || ""
                            acabadoLateral2: redcliente.loadoutMarco.acabadoLateral2 || ""
                            acabadoSuperior: redcliente.loadoutMarco.acabadoSuperior || ""
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4 * Tema.escala
                        Text {
                            text: nombreUsuario.text
                            color: Tema.colorTexto
                            font.bold: true
                            font.family: Tema.fuenteElegante
                            font.pixelSize: 20 * Tema.escala
                        }
                        Text {
                            text: nombreMarco(Tema.marcoPorPartidasGanadas(statsPartidasGanadas, statsTieneMarcoBasico)) +
                                  (statsPartidasJugadas > 0 ? " · " + statsPartidasGanadas + " partidas ganadas" : "")
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                        }
                        // Título equipado (si hay uno) -- ver CajaTitulo.qml
                        // para el porqué del diseño. El spacing del Column
                        // (4*escala) ya separa esto de la línea de arriba.
                        CajaTitulo {
                            nombre: infoTituloPropio ? infoTituloPropio.nombre : ""
                            colorTier: colorRareza(infoTituloPropio ? infoTituloPropio.rareza : "")
                        }
                    }
                }

                // ── Estadísticas + combinaciones, lado a lado (antes
                // apiladas) -- mismo tamaño de letra en las dos listas (antes
                // las combinaciones se veían más pequeñas que el resto sin
                // motivo real, 11px contra 12px -- pedido explícito
                // 2026-08-31: "todo debe quedar con el mismo tamaño de letra
                // respectivo"). Ocultas hasta la primera partida contada -- 0
                // partidas jugadas no distingue "invitado nunca jugó" de
                // "cuenta nueva".
                Row {
                    width: parent.width
                    visible: statsPartidasJugadas > 0
                    spacing: 40 * Tema.escala

                    Column {
                        width: (parent.width - 40 * Tema.escala) / 2
                        spacing: 6 * Tema.escala
                        Text {
                            text: "ESTADÍSTICAS"
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 11 * Tema.escala
                            font.letterSpacing: 1
                        }
                        Repeater {
                            model: [
                                { etiqueta: "Partidas jugadas", valor: statsPartidasJugadas + "" },
                                { etiqueta: "Partidas ganadas", valor: statsPartidasGanadas + "" },
                                { etiqueta: "Ratio de victorias", valor: Math.round(100 * statsPartidasGanadas / statsPartidasJugadas) + "%" },
                                { etiqueta: "Racha actual", valor: statsRachaActual + "" },
                                { etiqueta: "Mejor racha", valor: statsRachaMaxima + "" },
                                { etiqueta: "Manos jugadas", valor: statsManosJugadas + "" },
                                { etiqueta: "Manos ganadas", valor: statsManosGanadas + "" },
                                { etiqueta: "Mayor bote ganado", valor: statsMayorBote + "", esDinero: true },
                                { etiqueta: "Mejor mano", valor: statsMejorManoFecha > 0
                                      ? statsMejorManoNombre + " (" + new Date(statsMejorManoFecha * 1000).toLocaleDateString() + ")"
                                      : "—" }
                            ]
                            delegate: Row {
                                required property var modelData
                                width: parent.width
                                Text {
                                    width: parent.width - 150 * Tema.escala
                                    text: modelData.etiqueta
                                    color: Tema.colorTextoTenue
                                    font.pixelSize: 12 * Tema.escala
                                }
                                Row {
                                    width: 150 * Tema.escala
                                    layoutDirection: Qt.RightToLeft
                                    spacing: 3 * Tema.escala
                                    IconoFicha {
                                        visible: modelData.esDinero === true
                                        width: 10 * Tema.escala
                                        height: width
                                        anchors.verticalCenter: parent.verticalCenter
                                        colorFicha: Tema.colorTexto
                                    }
                                    Text {
                                        text: modelData.valor
                                        color: Tema.colorTexto
                                        font.pixelSize: 12 * Tema.escala
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    // Combinaciones mostradas alguna vez en un showdown --
                    // TODAS cuentan, sin umbral antifarm -- no es gameable, la
                    // carta que te toca es solo suerte. Lista de una columna
                    // (antes rejilla de 2 columnas apretadas) para que quepa
                    // igual de cómoda que Estadísticas al ir lado a lado.
                    Column {
                        width: (parent.width - 40 * Tema.escala) / 2
                        spacing: 6 * Tema.escala
                        Text {
                            text: "COMBINACIONES MOSTRADAS"
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 11 * Tema.escala
                            font.letterSpacing: 1
                        }
                        Repeater {
                            model: [
                                { etiqueta: "Carta alta", valor: statsVecesCartaAlta },
                                { etiqueta: "Pareja", valor: statsVecesPareja },
                                { etiqueta: "Doble pareja", valor: statsVecesDoblePareja },
                                { etiqueta: "Trío", valor: statsVecesTrio },
                                { etiqueta: "Escalera", valor: statsVecesEscalera },
                                { etiqueta: "Color", valor: statsVecesColor },
                                { etiqueta: "Full House", valor: statsVecesFullHouse },
                                { etiqueta: "Póker", valor: statsVecesPoker },
                                { etiqueta: "Escalera de color", valor: statsVecesEscaleraColor },
                                { etiqueta: "Escalera real", valor: statsVecesEscaleraReal }
                            ]
                            delegate: Row {
                                required property var modelData
                                width: parent.width
                                Text {
                                    width: parent.width - 60 * Tema.escala
                                    text: modelData.etiqueta
                                    color: modelData.valor > 0 ? Tema.colorTextoTenue : Tema.colorTextoMuyTenue
                                    font.pixelSize: 12 * Tema.escala
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: 60 * Tema.escala
                                    text: modelData.valor + ""
                                    color: modelData.valor > 0 ? Tema.colorAccent : Tema.colorTextoMuyTenue
                                    font.bold: modelData.valor > 0
                                    font.pixelSize: 12 * Tema.escala
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
                Text {
                    width: parent.width
                    visible: statsPartidasJugadas === 0
                    wrapMode: Text.WordWrap
                    text: "Todavía no tienes partidas oficiales registradas."
                    color: Tema.colorTextoTenue
                    font.pixelSize: 12 * Tema.escala
                }

                // ── Cambiar usuario / cambiar contraseña, lado a lado -- cada
                // uno colapsado detrás de su propio botón (antes los campos
                // estaban siempre puestos, ocupando sitio aunque no se fueran
                // a usar -- pedido explícito 2026-08-31).
                Row {
                    width: parent.width
                    spacing: 40 * Tema.escala
                    // Gestionar la cuenta exige servidor -- sin conexión los
                    // controles se ocultan en vez de quedarse ahí sin hacer
                    // nada al pulsarlos (los Q_INVOKABLE de LocalGameClient
                    // son no-ops a propósito, ver su comentario).
                    visible: !ventana.sesionOffline

                    Column {
                        width: (parent.width - 40 * Tema.escala) / 2
                        spacing: 8 * Tema.escala
                        BotonContorno {
                            text: formularioUsernameAbierto ? "Cancelar" : "Cambiar nombre de usuario"
                            onClicked: {
                                formularioUsernameAbierto = !formularioUsernameAbierto;
                                campoNuevoUsername.text = "";
                                mensajeErrorLogin = "";
                            }
                        }
                        Column {
                            width: parent.width
                            visible: formularioUsernameAbierto
                            spacing: 8 * Tema.escala
                            CampoTexto {
                                id: campoNuevoUsername
                                width: parent.width
                                font.pixelSize: 13 * Tema.escala
                                placeholderText: (activeFocus || text.length > 0) ? "" : "Nuevo nombre de usuario"
                                onAccepted: botonCambiarUsername.clicked()
                            }
                            BotonRelleno {
                                id: botonCambiarUsername
                                text: "Confirmar"
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
                        }
                    }

                    Column {
                        width: (parent.width - 40 * Tema.escala) / 2
                        spacing: 8 * Tema.escala
                        BotonContorno {
                            text: formularioPasswordAbierto ? "Cancelar" : "Cambiar contraseña"
                            onClicked: {
                                formularioPasswordAbierto = !formularioPasswordAbierto;
                                campoPasswordActualCuenta.text = "";
                                campoPasswordNuevaCuenta.text = "";
                                mensajeErrorLogin = "";
                            }
                        }
                        Column {
                            width: parent.width
                            visible: formularioPasswordAbierto
                            spacing: 8 * Tema.escala
                            CampoTexto {
                                id: campoPasswordActualCuenta
                                width: parent.width
                                font.pixelSize: 13 * Tema.escala
                                echoMode: TextInput.Password
                                placeholderText: (activeFocus || text.length > 0) ? "" : "Contraseña actual"
                                onAccepted: campoPasswordNuevaCuenta.forceActiveFocus()
                            }
                            CampoTexto {
                                id: campoPasswordNuevaCuenta
                                width: parent.width
                                font.pixelSize: 13 * Tema.escala
                                echoMode: TextInput.Password
                                placeholderText: (activeFocus || text.length > 0) ? "" : "Contraseña nueva (8+ caracteres)"
                                onAccepted: botonCambiarPassword.clicked()
                            }
                            BotonRelleno {
                                id: botonCambiarPassword
                                text: "Confirmar"
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
                        }
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
                    visible: !ventana.sesionOffline
                    onClicked: redcliente.cerrarSesion(servidorHost, servidorPuerto, tokenSesion)
                }

                // ── Fase 1 del sistema de progresión: herramienta de
                // estadísticas mínima, solo visible para cuentas admin (ver
                // AccountManager::esAdmin() -- se marca a mano en la base, sin
                // flujo en la app todavía para concederlo).
                BotonContorno {
                    visible: !ventana.sesionOffline && redcliente.estadisticasCuenta.esAdmin === true
                    text: "Exportar estadísticas (admin)"
                    onClicked: {
                        mensajeExportacion = "Exportando...";
                        redcliente.exportarEstadisticas(servidorHost, servidorPuerto, tokenSesion);
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    visible: !ventana.sesionOffline && redcliente.estadisticasCuenta.esAdmin === true && mensajeExportacion !== ""
                    color: Tema.colorTextoTenue
                    font.pixelSize: 11 * Tema.escala
                    text: mensajeExportacion
                }

                // Herramienta de pruebas/admin, punto 2 de la prioridad
                // confirmada (2026-09-01, ver memoria
                // qt_progression_review_2026_09_01) -- cierra el hueco real
                // de "todo QA de logros/tienda ha sido SQL a mano". MVP a
                // propósito: dos campos de texto sueltos con el username y
                // el código (de logro O de objeto de tienda -- el servidor
                // decide cuál de los dos es), sin selector visual bonito
                // todavía (ver memoria, quedó fuera del alcance de hoy).
                Column {
                    width: parent.width
                    visible: !ventana.sesionOffline && redcliente.estadisticasCuenta.esAdmin === true
                    spacing: 6 * Tema.escala
                    Text {
                        text: "Conceder logro/objeto (admin)"
                        color: Tema.colorTextoTenue
                        font.pixelSize: 11 * Tema.escala
                        font.letterSpacing: 0.5
                    }
                    CampoTexto {
                        id: campoAdminUsername
                        width: parent.width
                        font.pixelSize: 13 * Tema.escala
                        placeholderText: (activeFocus || text.length > 0) ? "" : "Username destino"
                        onAccepted: campoAdminCodigo.forceActiveFocus()
                    }
                    CampoTexto {
                        id: campoAdminCodigo
                        width: parent.width
                        font.pixelSize: 13 * Tema.escala
                        placeholderText: (activeFocus || text.length > 0) ? "" : "Código (logro u objeto de tienda)"
                    }
                    BotonContorno {
                        text: "Conceder"
                        onClicked: {
                            if (campoAdminUsername.text.length === 0 || campoAdminCodigo.text.length === 0) {
                                mensajeAdminConceder = "Rellena username y código.";
                                return;
                            }
                            mensajeAdminConceder = "Concediendo...";
                            redcliente.adminConcederItem(servidorHost, servidorPuerto, tokenSesion,
                                                          campoAdminUsername.text, campoAdminCodigo.text);
                        }
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        visible: mensajeAdminConceder !== ""
                        color: Tema.colorTextoTenue
                        font.pixelSize: 11 * Tema.escala
                        text: mensajeAdminConceder
                    }
                }

                // Segunda mitad del punto 2 (mismo día) -- MVP a propósito:
                // sin campo de cantidad, un botón fijo (15 -- de sobra para
                // ver variedad real en el Ranking) en vez de otro control
                // más que rellenar.
                Column {
                    width: parent.width
                    visible: !ventana.sesionOffline && redcliente.estadisticasCuenta.esAdmin === true
                    spacing: 6 * Tema.escala
                    BotonContorno {
                        text: "Fabricar 15 cuentas de prueba (admin)"
                        onClicked: {
                            mensajeAdminFabricar = "Fabricando...";
                            redcliente.adminFabricarCuentasPrueba(servidorHost, servidorPuerto, tokenSesion, 15);
                        }
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        visible: mensajeAdminFabricar !== ""
                        color: Tema.colorTextoTenue
                        font.pixelSize: 11 * Tema.escala
                        text: mensajeAdminFabricar
                    }
                }
            }

            // ── Progreso: invitado ──────────────────────────────────────────
            Text {
                width: parent.width
                visible: ventana.pestanaCuentaActual === 1 && !hayCuenta
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Inicia sesión para ver tu progreso hacia el siguiente marco de avatar."
                color: Tema.colorTextoTenue
                font.pixelSize: 13 * Tema.escala
            }

            // ── Progreso: con sesión -- nivel/XP (Fase 2) arriba, barra hacia
            // el siguiente marco de avatar (bronce/plata/oro/platino, ya
            // existente) debajo. Elo encajará aquí cuando se construya la
            // Fase 3.
            Column {
                width: parent.width
                visible: ventana.pestanaCuentaActual === 1 && hayCuenta
                spacing: 24 * Tema.escala

                // El NIVEL es el dato protagonista (dentro del anillo, grande)
                // -- el XP en sí es solo el detalle de apoyo que explica el
                // progreso hacia el siguiente, nunca al revés.
                Row {
                    width: parent.width
                    spacing: 24 * Tema.escala
                    AnilloNivel {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 72 * Tema.escala
                        height: width
                        nivel: progresoNivelActual.nivel
                        fraccion: progresoNivelActual.xpEnNivel / Math.max(1, progresoNivelActual.xpParaSiguiente)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: progresoNivelActual.xpEnNivel + " / " + progresoNivelActual.xpParaSiguiente + " XP para el siguiente nivel"
                        color: Tema.colorTextoTenue
                        font.pixelSize: 12 * Tema.escala
                    }
                }

                Row {
                    width: parent.width
                    spacing: 24 * Tema.escala

                    // Item envolvente MÁS grande que el propio avatar --
                    // mismo motivo que el equivalente de Perfil más arriba
                    // (2.1x de lado, cubre con margen de sobra decoración
                    // superior + laterales a la vez): este Avatar SÍ pinta
                    // el loadout real completo, así que aquí hacía falta de
                    // verdad, no solo "por si acaso" -- se recortaba contra
                    // el Flickable de la pantalla Cuenta en cuanto tenías
                    // marco Y una decoración equipada a la vez (bug real
                    // reportado varias veces 2026-08-31, la última "vuelve
                    // a recortar el marco por la izquierda" -- el ancho
                    // nunca había tenido en cuenta lo que sobresale una
                    // decoración lateral, solo el propio anillo).
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 84 * Tema.escala * 2.1
                        height: width
                        Avatar {
                            id: avatarProgreso
                            anchors.centerIn: parent
                            letra: nombreUsuario.text.length > 0 ? nombreUsuario.text.charAt(0).toUpperCase() : "?"
                            tamano: 84 * Tema.escala
                            marco: Tema.marcoPorPartidasGanadas(statsPartidasGanadas, statsTieneMarcoBasico)
                            // Fase 5 del sistema de progresión: aquí SÍ se pinta el
                            // marco REAL equipado (no la previsualización de la
                            // Tienda) -- esta es la vista "así te ve todo el mundo
                            // cuando algún día se difunda" (por ahora solo tú lo ves).
                            textura: redcliente.loadoutMarco.textura || ""
                            efecto: redcliente.loadoutMarco.efecto || ""
                            decoracionLateral1: redcliente.loadoutMarco.decoracionLateral1 || ""
                            decoracionLateral2: redcliente.loadoutMarco.decoracionLateral2 || ""
                            decoracionSuperior: redcliente.loadoutMarco.decoracionSuperior || ""
                            acabadoLateral1: redcliente.loadoutMarco.acabadoLateral1 || ""
                            acabadoLateral2: redcliente.loadoutMarco.acabadoLateral2 || ""
                            acabadoSuperior: redcliente.loadoutMarco.acabadoSuperior || ""
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        // El Item del avatar mide 84*2.1 de lado ahora (ver
                        // el comentario de arriba), no 84 -- actualizado a
                        // juego para que esta columna siga calculando bien
                        // el ancho que le queda.
                        width: parent.width - 84 * Tema.escala * 2.1 - 24 * Tema.escala
                        spacing: 10 * Tema.escala

                        Text {
                            text: "Marco actual: " + nombreMarco(Tema.marcoPorPartidasGanadas(statsPartidasGanadas, statsTieneMarcoBasico))
                            color: Tema.colorTexto
                            font.bold: true
                            font.pixelSize: 15 * Tema.escala
                        }

                        Column {
                            width: parent.width
                            visible: statsPartidasGanadas < 50
                            spacing: 6 * Tema.escala
                            Row {
                                width: parent.width
                                Text {
                                    width: parent.width - 170 * Tema.escala
                                    text: "Siguiente marco: " + nombreProximoMarco(statsPartidasGanadas, statsTieneMarcoBasico)
                                    color: Tema.colorTextoTenue
                                    font.pixelSize: 12 * Tema.escala
                                }
                                Text {
                                    width: 170 * Tema.escala
                                    horizontalAlignment: Text.AlignRight
                                    text: statsPartidasGanadas + " / " + proximoUmbralMarco(statsPartidasGanadas, statsTieneMarcoBasico) + " victorias"
                                    color: Tema.colorTexto
                                    font.bold: true
                                    font.pixelSize: 12 * Tema.escala
                                }
                            }
                            Rectangle {
                                id: pistaProgresoMarco
                                width: parent.width
                                height: 8 * Tema.escala
                                radius: height / 2
                                color: Qt.rgba(1, 1, 1, 0.08)
                                Rectangle {
                                    width: pistaProgresoMarco.width * Math.min(1.0,
                                        (statsPartidasGanadas - umbralAnteriorMarco(statsPartidasGanadas)) /
                                        Math.max(1, proximoUmbralMarco(statsPartidasGanadas, statsTieneMarcoBasico) - umbralAnteriorMarco(statsPartidasGanadas)))
                                    height: parent.height
                                    radius: parent.radius
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: Qt.lighter(Tema.colorAccent, 1.3) }
                                        GradientStop { position: 1.0; color: Tema.colorAccent }
                                    }
                                    // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                                    layer.enabled: true
                                    layer.effect: ShaderEffect {
                                        property variant source
                                        property real amplitud: 3.0
                                        fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
                                    }
                                }
                            }
                        }
                        Text {
                            width: parent.width
                            visible: statsPartidasGanadas >= 50
                            wrapMode: Text.WordWrap
                            text: "Has desbloqueado el marco más alto: Platino."
                            color: Tema.colorAccent
                            font.bold: true
                            font.pixelSize: 13 * Tema.escala
                        }
                        Text {
                            width: parent.width
                            visible: statsPartidasJugadas === 0
                            wrapMode: Text.WordWrap
                            text: "Gana partidas oficiales (con otras personas reales) para avanzar de marco."
                            color: Tema.colorTextoTenue
                            font.pixelSize: 12 * Tema.escala
                        }
                    }
                }

                // ── Roadmap de marcos: TODOS los tiers a la vez, no solo el
                // actual/siguiente -- pedido explícito 2026-09-01: "añade
                // abajo todos los demas marcos de progreso, con su barra
                // de como vas, asi se llena esa pestaña y ves lo que
                // puedes conseguir". Cada fila reutiliza el propio Avatar
                // (con ese marco puesto, sin decoraciones) como muestra
                // real en vez de un swatch de color inventado -- así se ve
                // EXACTAMENTE cómo queda cada uno, no una aproximación.
                // Repeater suelto, SIN scroll propio -- hubo una vuelta
                // intermedia por ListView acotado (mismo criterio que
                // gridTienda/gridPersonalizar) pero revertida el mismo día
                // (pedido explícito: "scrollear aparte los demas marcos es
                // demasiado, una pagina con el progreso y roadmap todo
                // scrolleable como conjunto es mejor") -- toda la pestaña
                // Progreso (XP, marco actual, roadmap) se desplaza como UN
                // solo bloque dentro del scroll de Cuenta, sin un scroll
                // anidado aparte solo para esta sección.
                Column {
                    width: parent.width
                    spacing: 16 * Tema.escala

                    Text {
                        text: "Todos los marcos"
                        color: Tema.colorTexto
                        font.bold: true
                        font.pixelSize: 15 * Tema.escala
                    }

                    Column {
                        width: parent.width
                        spacing: 10 * Tema.escala

                        Repeater {
                            model: [
                                { tier: "hierro",  etiqueta: "Hierro",  umbral: 1 },
                                { tier: "bronce",  etiqueta: "Bronce",  umbral: 5 },
                                { tier: "plata",   etiqueta: "Plata",   umbral: 15 },
                                { tier: "oro",     etiqueta: "Oro",     umbral: 25 },
                                { tier: "platino", etiqueta: "Platino", umbral: 50 }
                            ]
                            delegate: Item {
                                id: filaMarcoRoadmap
                                required property var modelData
                                width: parent.width
                                height: 76 * Tema.escala
                                // Hierro es el único con una segunda vía (bots,
                                // ver statsTieneMarcoBasico) -- el resto solo
                                // cuenta victorias oficiales de verdad.
                                readonly property bool conseguido: filaMarcoRoadmap.modelData.tier === "hierro"
                                    ? (statsPartidasGanadas >= 1 || statsTieneMarcoBasico)
                                    : statsPartidasGanadas >= filaMarcoRoadmap.modelData.umbral

                                Row {
                                    // El anillo del Avatar se dibuja un 16% más
                                    // grande que su propio tamano (a propósito,
                                    // ver Avatar.qml) -- pegado al borde
                                    // izquierdo de golpe, ese sobrante quedaba
                                    // recortado por el "clip: true" del scroll
                                    // que lo contenga (bug real reportado
                                    // 2026-09-01: "el marco se ve cortado por
                                    // el lado izquierdo"). Este margen le da
                                    // sitio de sobra (bastante más que el
                                    // ~4.5*escala que hace falta de verdad)
                                    // antes de llegar al borde recortado --
                                    // sigue haciendo falta aunque ya no haya
                                    // un ListView propio: scrollCuenta (el
                                    // scroll de toda la pestaña Cuenta) también
                                    // recorta en su propio borde izquierdo.
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10 * Tema.escala
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 16 * Tema.escala

                                    Avatar {
                                        anchors.verticalCenter: parent.verticalCenter
                                        letra: nombreUsuario.text.length > 0 ? nombreUsuario.text.charAt(0).toUpperCase() : "?"
                                        tamano: 56 * Tema.escala
                                        marco: filaMarcoRoadmap.modelData.tier
                                    }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 56 * Tema.escala - 90 * Tema.escala - 2 * parent.spacing
                                        spacing: 6 * Tema.escala
                                        Text {
                                            text: filaMarcoRoadmap.modelData.etiqueta
                                            color: filaMarcoRoadmap.conseguido ? Tema.colorTexto : Tema.colorTextoTenue
                                            font.bold: true
                                            font.pixelSize: 14 * Tema.escala
                                        }
                                        Rectangle {
                                            width: parent.width
                                            height: 7 * Tema.escala
                                            radius: height / 2
                                            color: Qt.rgba(1, 1, 1, 0.08)
                                            Rectangle {
                                                width: parent.width * Math.min(1.0, statsPartidasGanadas / filaMarcoRoadmap.modelData.umbral)
                                                height: parent.height
                                                radius: parent.radius
                                                color: filaMarcoRoadmap.conseguido ? Tema.colorAccent : Qt.lighter(Tema.colorAccent, 1.3)
                                            }
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 90 * Tema.escala
                                        horizontalAlignment: Text.AlignRight
                                        text: filaMarcoRoadmap.conseguido ? "Conseguido" : (statsPartidasGanadas + " / " + filaMarcoRoadmap.modelData.umbral)
                                        color: filaMarcoRoadmap.conseguido ? Tema.colorAccent : Tema.colorTextoTenue
                                        font.pixelSize: 11 * Tema.escala
                                        font.bold: filaMarcoRoadmap.conseguido
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Logros: invitado ─────────────────────────────────────────────
            Text {
                width: parent.width
                visible: ventana.pestanaCuentaActual === 2 && !hayCuenta
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Inicia sesión para ver tus logros."
                color: Tema.colorTextoTenue
                font.pixelSize: 13 * Tema.escala
            }

            // ── Logros: con sesión (Fase 4 del sistema de progresión) -- se
            // muestran TODOS, desbloqueados o no (atenuados si no): la idea es
            // que se vea qué se puede conseguir y cómo, no solo lo ya logrado.
            Column {
                width: parent.width
                visible: ventana.pestanaCuentaActual === 2 && hayCuenta
                spacing: 14 * Tema.escala

                Text {
                    text: logrosDesbloqueados() + " / " + logrosModel.count + " desbloqueados"
                    color: Tema.colorTextoTenue
                    font.pixelSize: 12 * Tema.escala
                }

                Repeater {
                    model: logrosModel
                    delegate: Rectangle {
                        id: tarjetaLogro
                        required property string codigo
                        required property string rareza
                        required property int xpRecompensa
                        required property int desbloqueado
                        required property int desbloqueadoEn
                        required property string nombre
                        required property string descripcion

                        width: parent ? parent.width : 0
                        height: filaLogro.height + 24 * Tema.escala
                        radius: 10 * Tema.escala
                        opacity: desbloqueado ? 1.0 : 0.55
                        border.width: 1
                        border.color: desbloqueado ? colorRareza(rareza) : Qt.rgba(1, 1, 1, 0.12)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
                            GradientStop { position: 1.0; color: Tema.colorPanel }
                        }
                        // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                        layer.enabled: true
                        layer.effect: ShaderEffect {
                            property variant source
                            property real amplitud: 30.0
                            fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
                        }

                        // Franja lateral de rareza -- mismo lenguaje de color
                        // que la insignia redonda de la izquierda, para que
                        // "de qué tipo es este logro" se lea de un vistazo
                        // incluso en la lista entera, no solo tarjeta a tarjeta.
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 5 * Tema.escala
                            radius: 3 * Tema.escala
                            color: colorRareza(tarjetaLogro.rareza)
                        }

                        Row {
                            id: filaLogro
                            anchors.left: parent.left
                            anchors.leftMargin: 20 * Tema.escala
                            anchors.right: parent.right
                            anchors.rightMargin: 16 * Tema.escala
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14 * Tema.escala

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 40 * Tema.escala
                                height: width
                                radius: width / 2
                                color: tarjetaLogro.desbloqueado ? colorRareza(tarjetaLogro.rareza) : "transparent"
                                border.width: 1.5
                                border.color: colorRareza(tarjetaLogro.rareza)
                                Text {
                                    anchors.centerIn: parent
                                    text: tarjetaLogro.desbloqueado ? "✓" : tarjetaLogro.rareza.charAt(0).toUpperCase()
                                    color: tarjetaLogro.desbloqueado ? Tema.colorFondo : colorRareza(tarjetaLogro.rareza)
                                    font.bold: true
                                    font.pixelSize: 16 * Tema.escala
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                // Ancho reservado para el indicador de progreso de
                                // la derecha (70*escala + su propio spacing de fila)
                                // SIEMPRE, esté visible o no -- así la columna no
                                // cambia de ancho según el logro, solo el texto de
                                // al lado aparece o no.
                                width: parent.width - 40 * Tema.escala - 14 * Tema.escala - 70 * Tema.escala - 14 * Tema.escala
                                spacing: 4 * Tema.escala

                                Row {
                                    width: parent.width
                                    spacing: 8 * Tema.escala
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tarjetaLogro.nombre
                                        color: Tema.colorTexto
                                        font.bold: true
                                        font.pixelSize: 14 * Tema.escala
                                    }
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: etiquetaRarezaTexto.width + 12 * Tema.escala
                                        height: 16 * Tema.escala
                                        radius: height / 2
                                        color: "transparent"
                                        border.width: 1
                                        border.color: colorRareza(tarjetaLogro.rareza)
                                        Text {
                                            id: etiquetaRarezaTexto
                                            anchors.centerIn: parent
                                            text: etiquetaRareza(tarjetaLogro.rareza)
                                            color: colorRareza(tarjetaLogro.rareza)
                                            font.pixelSize: 9 * Tema.escala
                                            font.bold: true
                                        }
                                    }
                                }
                                Text {
                                    width: parent.width
                                    text: tarjetaLogro.descripcion
                                    color: Tema.colorTextoTenue
                                    font.pixelSize: 12 * Tema.escala
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    visible: tarjetaLogro.desbloqueado === 1
                                    text: "Desbloqueado el " +
                                          Qt.formatDate(new Date(tarjetaLogro.desbloqueadoEn * 1000), "d MMM yyyy") +
                                          " · +" + tarjetaLogro.xpRecompensa + " XP"
                                    color: colorRareza(tarjetaLogro.rareza)
                                    font.pixelSize: 10 * Tema.escala
                                }
                            }

                            // "Cuánto te queda" en el extremo derecho --
                            // pedido explícito 2026-08-31 -- SIEMPRE algo (un
                            // contador de verdad si existe, "Puntual" si no,
                            // ver progresoLogro()) mientras no esté
                            // desbloqueado, nunca en blanco -- ya desbloqueado
                            // ya tiene su propia línea de "Desbloqueado el...".
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 70 * Tema.escala
                                horizontalAlignment: Text.AlignRight
                                visible: tarjetaLogro.desbloqueado !== 1
                                text: progresoLogro(tarjetaLogro.codigo)
                                color: Tema.colorTextoTenue
                                font.pixelSize: 11 * Tema.escala
                            }
                        }
                    }
                }
            }

            // ── Personalizar: invitado ────────────────────────────────────────
            Text {
                width: parent.width
                visible: ventana.pestanaCuentaActual === 3 && !hayCuenta
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Inicia sesión para personalizar tu avatar."
                color: Tema.colorTextoTenue
                font.pixelSize: 13 * Tema.escala
            }

            // ── Personalizar: con sesión (2026-09-01, revisado el mismo
            // día) -- reemplaza a la vieja pestaña "Tienda" de aquí (que
            // ahora es pantalla propia, ver el riel): esto solo EQUIPA lo
            // que ya tienes, nunca compra. La pestaña "Marco" se quitó
            // (pedido explícito: "en personalizar no vamos a duplicar
            // progreso" -- ese contenido vive ahora, ampliado, en
            // Progreso) -- quedan 4: Texturas/Efectos/Decoraciones/
            // Títulos, así que un cosmético nuevo no pide tocar esta
            // pantalla para nada, solo su categoría ya decide en qué
            // pestaña cae (ver categoriasPersonalizar()). El avatar de la
            // derecha es FIJO, no una pestaña más -- pedido explícito:
            // "el avatar siempre tiene que ser visible, si no no ves lo
            // que estas aplicando" -- mismo Item/Avatar que la propia
            // Tienda usa para su "VISTA PREVIA", con el mismo
            // valorPreview() de siempre (hover en una tarjeta = se ve al
            // momento; sin hover = lo que ya llevas puesto de verdad). Los
            // títulos no son una decoración del propio anillo (Avatar no
            // los pinta) así que llevan además su propia CajaTitulo justo
            // debajo, resuelta igual por hover/equipado real.
            Column {
                width: parent.width
                visible: ventana.pestanaCuentaActual === 3 && hayCuenta
                spacing: 16 * Tema.escala

                SelectorSegmentado {
                    width: parent.width
                    opciones: ["Texturas", "Efectos", "Decoraciones", "Títulos"]
                    seleccionado: ventana.pestanaPersonalizarActual
                    onElegido: (indice) => ventana.pestanaPersonalizarActual = indice
                }

                // (Sin Text de mensajeTienda aquí -- bug real reportado
                // 2026-09-02: "el mensaje tambien aparece en la
                // personalizacion, ya que antes teniamos esa
                // funcionalidad implementada por error". Confirmado: este
                // Text era un resto de cuando Personalizar ERA la vieja
                // pestaña "Tienda" (antes de que Tienda saliera a su
                // propia pantalla en el riel, 2026-09-01) -- Personalizar
                // "solo equipa, nunca compra" (ver el comentario grande de
                // arriba), así que un error de COMPRA de la pantalla
                // Tienda no tiene nada que hacer aquí; al compartir la
                // misma property `mensajeTienda`, un error visto en Tienda
                // se quedaba pegado también aquí sin ninguna acción propia
                // de esta pestaña que lo limpiara -- de ahí la sensación
                // de "el mensaje no desaparece".)

                Row {
                    width: parent.width
                    spacing: 24 * Tema.escala

                    Column {
                        id: columnaGridPersonalizar
                        width: parent.width - columnaPreviewPersonalizar.width - parent.spacing
                        spacing: 12 * Tema.escala

                        // ── Texturas/Efectos/Decoraciones/Títulos: rejilla
                        // de equipar, filtrada a lo que YA tienes
                        // (itemsPersonalizar, poseido === 1) -- sin precio
                        // ni botón de Comprar, eso vive en Tienda ahora.
                        Text {
                            width: parent.width
                            visible: itemsPersonalizar.length === 0
                            wrapMode: Text.WordWrap
                            text: "Todavía no tienes nada de esto -- consíguelo en la Tienda."
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                        }
                        GridView {
                            id: gridPersonalizar
                            width: parent.width
                            visible: itemsPersonalizar.length > 0
                            height: Math.min(contentHeight, 3 * cellHeight)
                            clip: true
                            cellWidth: Math.floor(width / Math.max(1, Math.floor(width / (230 * Tema.escala))))
                            // 130 → 90*escala (pedido explícito 2026-09-02,
                            // "reducir la altura de las tarjetas a 2/3") --
                            // aquí no hay precio/nivel que fusionar (ya son
                            // tuyos), la bajada sale de apretar márgenes/
                            // espaciados de la Column de abajo.
                            cellHeight: 90 * Tema.escala
                            model: itemsPersonalizar
                            delegate: Item {
                                id: celdaPersonalizar
                                required property string codigo
                                required property string categoria
                                required property string nombre
                                required property int equipado
                                width: gridPersonalizar.cellWidth
                                height: gridPersonalizar.cellHeight

                                // "Ficha de casino" (2026-09-02, diseño A
                                // elegido por el usuario tras el artifact
                                // "Tarjetas de Mesa Real") -- sombra
                                // desplazada barata (mismo criterio que
                                // BarraSuperior.qml), SIN escalar con la
                                // tarjeta.
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 6 * Tema.escala
                                    anchors.topMargin: 6 * Tema.escala + 3 * Tema.escala
                                    radius: 10 * Tema.escala
                                    color: "black"
                                    opacity: 0.35
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 6 * Tema.escala
                                    radius: 10 * Tema.escala
                                    // Bug real reportado 2026-09-02: "la
                                    // caja se queda igual, solo se
                                    // desequipa" -- el borde de "no
                                    // equipado" copiaba el de "no poseído"
                                    // de la Tienda (negro semitransparente,
                                    // Qt.rgba(0,0,0,0.3)), que en un tema
                                    // oscuro se confunde con el fondo y
                                    // parece que la tarjeta entera
                                    // desaparece. Aquí TODO lo que se ve ya
                                    // es tuyo (itemsPersonalizar solo lista
                                    // poseído===1) -- el borde SIEMPRE debe
                                    // notarse, solo cambia de intensidad
                                    // según esté puesto o no.
                                    border.width: celdaPersonalizar.equipado ? 1.8 : 1.2
                                    border.color: celdaPersonalizar.equipado ? Tema.colorAccent : Qt.darker(Tema.colorAccent, 1.8)
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
                                    // Mismo detalle "responsivo" que el resto de la
                                    // app -- ver Tienda/Amigos/Salas.
                                    scale: zonaHoverPersonalizar.containsMouse ? 0.97 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }

                                    // Hilo dorado por dentro del bisel
                                    // exterior -- el "doble bisel" de ficha
                                    // de casino.
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 2 * Tema.escala
                                        radius: parent.radius - 2 * Tema.escala
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b,
                                                               celdaPersonalizar.equipado ? 0.55 : 0.28)
                                    }

                                    MouseArea {
                                        id: zonaHoverPersonalizar
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: fijarPreview(celdaPersonalizar.categoria, celdaPersonalizar.codigo)
                                        onExited: {
                                            if (previewCodigo === celdaPersonalizar.codigo) {
                                                previewCodigo = "";
                                                previewCategoria = "";
                                            }
                                        }
                                    }

                                    Column {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 10 * Tema.escala
                                        spacing: 6 * Tema.escala

                                        Row {
                                            width: parent.width
                                            spacing: 8 * Tema.escala
                                            Image {
                                                id: miniaturaPersonalizar
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: source !== ""
                                                width: visible ? 18 * Tema.escala : 0
                                                height: width
                                                fillMode: Image.PreserveAspectFit
                                                smooth: true
                                                // mipmap aunque la miniatura sea pequeña: Qt comparte la
                                                // textura de un PNG entre todas las Image que lo cargan, y
                                                // si la sube primero una sin mipmap, el Avatar de la
                                                // preview (que sí lo pide) se queda sin él y Qt lo avisa
                                                // por la terminal ("Mipmap settings changed without...").
                                                mipmap: true
                                                source: rutaIconoObjetoTienda(celdaPersonalizar.codigo, celdaPersonalizar.categoria)
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - miniaturaPersonalizar.width - (miniaturaPersonalizar.visible ? parent.spacing : 0)
                                                elide: Text.ElideRight
                                                text: celdaPersonalizar.nombre + (celdaPersonalizar.equipado === 1 ? " · Equipado" : "")
                                                color: Tema.colorTexto
                                                font.bold: true
                                                font.pixelSize: 13 * Tema.escala
                                            }
                                        }

                                        // Textura/Efecto/Superior/Título -- un único hueco.
                                        // Ancho completo -- mismo pedido que
                                        // Tienda (2026-09-02).
                                        BotonContorno {
                                            visible: celdaPersonalizar.categoria !== "decoracion_lateral"
                                            width: parent.width
                                            text: celdaPersonalizar.equipado === 1 ? "Quitar" : "Equipar"
                                            colorBorde: celdaPersonalizar.equipado === 1 ? Tema.colorPeligro : Tema.colorBorde
                                            onClicked: equiparConAcabado(celdaPersonalizar.categoria,
                                                celdaPersonalizar.equipado === 1 ? "" : celdaPersonalizar.codigo)
                                        }
                                        // Decoraciones laterales -- DOS huecos (izq./der.),
                                        // mismo criterio que ya usaba Tienda.
                                        Row {
                                            visible: celdaPersonalizar.categoria === "decoracion_lateral"
                                            width: parent.width
                                            spacing: 4 * Tema.escala
                                            BotonContorno {
                                                readonly property bool aqui: redcliente.loadoutMarco.decoracionLateral1 === celdaPersonalizar.codigo
                                                width: (parent.width - parent.spacing) / 2
                                                text: aqui ? "Quitar izq." : "A la izq."
                                                colorBorde: aqui ? Tema.colorPeligro : Tema.colorBorde
                                                onClicked: equiparConAcabado("decoracion_lateral_1", aqui ? "" : celdaPersonalizar.codigo)
                                            }
                                            BotonContorno {
                                                readonly property bool aqui: redcliente.loadoutMarco.decoracionLateral2 === celdaPersonalizar.codigo
                                                width: (parent.width - parent.spacing) / 2
                                                text: aqui ? "Quitar der." : "A la der."
                                                colorBorde: aqui ? Tema.colorPeligro : Tema.colorBorde
                                                onClicked: equiparConAcabado("decoracion_lateral_2", aqui ? "" : celdaPersonalizar.codigo)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Avatar SIEMPRE visible, mismo diseño que la
                    // columna "VISTA PREVIA" de Tienda -- pedido explícito
                    // 2026-09-01, ver el comentario de arriba.
                    Column {
                        id: columnaPreviewPersonalizar
                        width: 220 * Tema.escala
                        spacing: 14 * Tema.escala

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "VISTA PREVIA"
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 10 * Tema.escala
                            font.letterSpacing: 1
                        }
                        Item {
                            width: parent.width
                            height: 120 * Tema.escala + 60 * Tema.escala
                            Avatar {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                letra: nombreUsuario.text.length > 0 ? nombreUsuario.text.charAt(0).toUpperCase() : "?"
                                tamano: 120 * Tema.escala
                                marco: marcoPreview
                                textura: valorPreview("textura", redcliente.loadoutMarco.textura)
                                efecto: valorPreview("efecto", redcliente.loadoutMarco.efecto)
                                decoracionLateral1: valorPreview("decoracion_lateral", redcliente.loadoutMarco.decoracionLateral1)
                                decoracionLateral2: redcliente.loadoutMarco.decoracionLateral2 || ""
                                decoracionSuperior: valorPreview("decoracion_superior", redcliente.loadoutMarco.decoracionSuperior)
                                acabadoLateral1: acabadoPreview("decoracion_lateral", redcliente.loadoutMarco.decoracionLateral1, redcliente.loadoutMarco.acabadoLateral1)
                                acabadoLateral2: redcliente.loadoutMarco.acabadoLateral2 || ""
                                acabadoSuperior: acabadoPreview("decoracion_superior", redcliente.loadoutMarco.decoracionSuperior, redcliente.loadoutMarco.acabadoSuperior)
                            }
                        }
                        // Sin marco todavía: la vista previa usa Hierro (ver marcoPreview) y aquí
                        // se dice. Solo ocupa sitio si no tienes marco, y se enciende al
                        // previsualizar, así la columna no salta al pasar por los accesorios.
                        Text {
                            visible: sinMarcoPropio
                            opacity: previsualizandoConHierro ? 1 : 0
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: "Así se verá con tu primer marco, Hierro. Gana una partida para desbloquear los accesorios."
                            color: Tema.colorTextoTenue
                            font.pixelSize: 11 * Tema.escala
                        }
                        // Los títulos no son una decoración del anillo --
                        // el Avatar de arriba no cambia al pasar el ratón
                        // por una tarjeta de Títulos, así que necesitan su
                        // propia previsualización aparte.
                        CajaTitulo {
                            anchors.horizontalCenter: parent.horizontalCenter
                            readonly property var infoTituloVista: objetoTiendaPorCodigo(valorPreview("titulo", redcliente.loadoutMarco.titulo || ""))
                            nombre: infoTituloVista ? infoTituloVista.nombre : ""
                            colorTier: colorRareza(infoTituloVista ? infoTituloVista.rareza : "")
                        }
                    }
                }
            }
            } // fin de columnaCuenta
        }

        // ── Pantalla Tienda (riel) ───────────────────────────────────────────
        // Mudada aquí desde la pestaña "Tienda" de Cuenta (2026-09-01,
        // "en nuestro diseño original... la tienda debería estar en el
        // riel, no escondida") -- pantalla propia, mismo patrón que
        // Salas/Ranking/Cuenta (BarraSuperior + Flickable con scroll
        // propio). El contenido de aquí abajo es EXACTAMENTE el que vivía
        // en Cuenta > Tienda, solo con las condiciones de "pestaña activa"
        // quitadas (ya no hace falta estar en la pestaña 3 de Cuenta para
        // verlo, esta pantalla ES eso).
        BarraSuperior {
            id: barraTienda
            visible: ventana.pantalla === "Tienda"
            anchors.top: parent.top
            anchors.left: rielNavegacion.right
            anchors.right: parent.right
            textoCentro: "Tienda"
            pantalla: ventana.pantalla
            miSaldoActual: ventana.miSaldoActual
            reconectandoAhora: ventana.reconectandoAhora
            servidorHost: ventana.servidorHost
            servidorPuerto: ventana.servidorPuerto
            mostrarSalir: true
            // Mejor sitio que dentro de la columna del catálogo (pedido
            // explícito 2026-09-02) -- -1 mientras no hay sesión.
            treboles: tokenSesion !== "" ? (redcliente.estadisticasCuenta.treboles || 0) : -1
            onAbrirAjustes: ajustesAbiertos = !ajustesAbiertos
            onSalir: ventana.pantalla = "Inicio"
        }
        // Título + selector Marco/Perfil FIJOS, fuera del Flickable -- mismo
        // criterio que cabeceraCuenta (pedido explícito 2026-09-01: "el
        // selector de pestaña arriba tiene que quedarse, el contenido
        // baja... eso aplica a todos los sitios").
        Column {
            id: cabeceraTienda
            visible: ventana.pantalla === "Tienda"
            anchors.top: barraTienda.bottom
            anchors.topMargin: 24 * Tema.escala
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: rielNavegacion.width / 2
            width: Math.min(1040 * Tema.escala, ventana.width - rielNavegacion.width - 60 * Tema.escala)
            spacing: 16 * Tema.escala

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Tienda"
                color: Tema.colorTexto
                font.family: Tema.fuenteElegante
                font.pixelSize: 22 * Tema.escala
            }

            SelectorSegmentado {
                width: parent.width
                visible: tokenSesion !== ""
                opciones: ["Marco", "Perfil"]
                seleccionado: ventana.pestanaTiendaActual
                onElegido: (indice) => {
                    ventana.pestanaTiendaActual = indice;
                    // Bug real reportado 2026-09-02 ("el mensaje no
                    // desaparece"): un error de compra/equipar se quedaba
                    // pegado al cambiar de Marco a Perfil (o viceversa) sin
                    // ninguna acción que lo limpiara.
                    mensajeTienda = "";
                    reordenarTienda();
                }
            }
        }
        // Item en vez de Flickable+Column -- bug real reportado 2026-09-02
        // ("no aprovechamos la altura y el espacio en la pantalla de pc...
        // esto pasa en la tienda"): antes gridTienda tenía un tope de
        // 3*cellHeight sin relación con el alto real de la ventana, así que
        // sobraba media pantalla en blanco bajo 3 filas de tarjetas. Mismo
        // patrón que panelSocial/listaRanking: cabecera fija (búsqueda) +
        // GridView que llena TODO el hueco de aquí abajo, con su propio
        // scroll (ya es un Flickable por herencia).
        Item {
            id: panelTienda
            visible: pantalla === "Tienda"
            anchors.top: cabeceraTienda.bottom
            anchors.topMargin: 16 * Tema.escala
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16 * Tema.escala
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: rielNavegacion.width / 2
            width: Math.min(1040 * Tema.escala, ventana.width - rielNavegacion.width - 60 * Tema.escala)

            // ── Tienda: invitado ─────────────────────────────────────────────
            Text {
                anchors.centerIn: parent
                width: parent.width
                visible: tokenSesion === ""
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Inicia sesión para entrar en la tienda."
                color: Tema.colorTextoTenue
                font.pixelSize: 13 * Tema.escala
            }

            // ── Tienda: con sesión (Fase 5 del sistema de progresión) --
            // catálogo a la izquierda, previsualización en vivo del avatar a
            // la derecha (pedido explícito del diseño: "tu avatar en grande
            // para que puedas previsualizar cómo quedaría lo que compres").
            // Solo las pestañas Marco/Perfil -- Mesa (reverso de cartas/
            // tapete) queda pendiente, necesita su propio sistema de
            // visibilidad en mesa que todavía no existe.
            Row {
                anchors.fill: parent
                visible: tokenSesion !== ""
                spacing: 24 * Tema.escala

                Item {
                    id: columnaCatalogoTienda
                    width: parent.width - columnaPreviewTienda.width - parent.spacing
                    height: parent.height

                    // El saldo de Tréboles vive en la barra superior desde
                    // 2026-09-02 (pedido explícito: "hay que encontrar
                    // mejor sitio") -- ver BarraSuperior.qml::treboles,
                    // barraTienda más arriba. Antes estaba aquí, tapado en
                    // cuanto había suficientes tarjetas encima.

                    // Cabecera FIJA (búsqueda + mensaje de error) -- el
                    // GridView de abajo se ancla a su borde inferior en vez
                    // de compartir un Column con él, así crece o encoge sin
                    // desplazar nada más.
                    Column {
                        id: cabeceraCatalogoTienda
                        width: parent.width
                        spacing: 12 * Tema.escala

                        // Buscar en el catálogo -- pedido explícito 2026-08-31,
                        // filtra en vivo (sin botón/servidor, mismo criterio que
                        // el cambio de pestaña de arriba). Mismo estilo de
                        // TextField subrayado que campoBusquedaSocial (pestaña
                        // Social > Buscar).
                        CampoTexto {
                            id: campoBusquedaTienda
                            width: parent.width
                            placeholderText: (activeFocus || text.length > 0) ? "" : "Buscar en la tienda..."
                            font.pixelSize: 13 * Tema.escala
                            onTextChanged: {
                                busquedaTienda = text;
                                reordenarTienda();
                            }
                        }

                        Text {
                            width: parent.width
                            visible: mensajeTienda !== ""
                            wrapMode: Text.WordWrap
                            color: Tema.colorPeligro
                            text: mensajeTienda
                            font.pixelSize: 11 * Tema.escala
                        }
                    }

                    // Catálogo en tarjetas (mismo lenguaje visual que las
                    // salas del Lobby) en vez de una lista de filas -- y con
                    // su PROPIO scroll interno (GridView): antes el catálogo
                    // entero compartía el mismo campo scroleable que la
                    // vista previa, así que bajar en la lista se llevaba la
                    // previsualización con ella y dejaba de verse (pedido
                    // explícito 2026-08-31). Con el scroll aislado aquí
                    // dentro, columnaPreviewTienda de al lado ya no se mueve
                    // nunca. Alto ligado a columnaCatalogoTienda entero
                    // (antes tope de 3*cellHeight sin relación con la
                    // ventana -- bug de "no aprovecha la altura",
                    // 2026-09-02) en vez de anchors.fill: parent -- así dejar
                    // sitio a cabeceraCatalogoTienda arriba.
                    GridView {
                        id: gridTienda
                        anchors.top: cabeceraCatalogoTienda.bottom
                        anchors.topMargin: 12 * Tema.escala
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / (230 * Tema.escala))))
                        // 100 → 122*escala (2026-09-02, pedido explícito:
                        // "las tarjetas de tienda en pc pueden sin problema
                        // ser un poco mas altos para que quepa el boton" --
                        // a 100*escala el botón/par izq-der quedaba casi sin
                        // margen bajo el nombre, sobre todo con la fila de
                        // "Logro: X"/código admin encima).
                        cellHeight: 122 * Tema.escala
                        model: tiendaModel
                        delegate: Item {
                            id: celdaTienda
                            required property string codigo
                            required property string categoria
                            required property int precioTreboles
                            required property int nivelMinimo
                            required property int esDeLogro
                            required property int poseido
                            required property int equipado
                            required property string nombre
                            required property string logroNombre
                            width: gridTienda.cellWidth
                            height: gridTienda.cellHeight

                            // "Ficha de casino" (2026-09-02, diseño A
                            // elegido por el usuario tras el artifact
                            // "Tarjetas de Mesa Real") -- sombra desplazada
                            // barata (mismo criterio que BarraSuperior.qml),
                            // SIN escalar con la tarjeta: al hundirse en el
                            // hover, la sombra se queda fija y asoma más.
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 6 * Tema.escala
                                anchors.topMargin: 6 * Tema.escala + 3 * Tema.escala
                                radius: 10 * Tema.escala
                                color: "black"
                                opacity: 0.35
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 6 * Tema.escala
                                radius: 10 * Tema.escala
                                // Tres estados, un solo color -- pedido explícito
                                // 2026-09-01: "los objetos obtenidos... se queden
                                // marcados, con un borde de color dependiendo del
                                // tema". Ya tenías/tienes (poseido) se distingue de
                                // "no lo tienes" por el mismo dorado/acento del tema
                                // (Tema.colorAccent -- literalmente dorado en Verde
                                // clásico); equipado suma un borde más grueso encima
                                // del mismo color, así sigue notándose cuál llevas
                                // puesto AHORA entre lo que ya posees.
                                border.width: celdaTienda.equipado ? 1.8 : (celdaTienda.poseido ? 1.2 : 1)
                                border.color: celdaTienda.equipado ? Tema.colorAccent
                                              : (celdaTienda.poseido ? Qt.darker(Tema.colorAccent, 1.8) : Qt.rgba(0, 0, 0, 0.4))
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
                                // Se encoge un poco al pasar el ratón por
                                // encima -- pedido explícito 2026-08-31,
                                // mismo criterio que Amigos y Salas.
                                scale: zonaHoverTienda.containsMouse ? 0.97 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                // Hilo dorado por dentro del bisel exterior
                                // -- el "doble bisel" de ficha de casino.
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2 * Tema.escala
                                    radius: parent.radius - 2 * Tema.escala
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b,
                                                           celdaTienda.equipado ? 0.6 : (celdaTienda.poseido ? 0.32 : 0.14))
                                }

                                // Preview en vivo al pasar el ratón -- se
                                // limpia sola al salir, NUNCA se guarda
                                // hasta pulsar Comprar/Equipar de verdad.
                                MouseArea {
                                    id: zonaHoverTienda
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        // "_baraja" no es una decoración real -- no
                                        // tiene código propio que previsualizar, así
                                        // que al pasar el ratón por ENCIMA de esta
                                        // tarjeta se previsualiza la carta elegida en
                                        // el selector (si hay alguna), exactamente
                                        // igual que cualquier otra tarjeta de la
                                        // tienda con su propio código (pedido
                                        // explícito 2026-09-01: "solo debería
                                        // aparecer cuando estés encima del cuadro con
                                        // el cursor"). Sin selección todavía, no hay
                                        // nada que previsualizar.
                                        if (celdaTienda.codigo === "_baraja") {
                                            if (ventana.cartaSeleccionada === "") return;
                                            fijarPreview("decoracion_lateral", ventana.cartaSeleccionada);
                                            return;
                                        }
                                        fijarPreview(celdaTienda.categoria, celdaTienda.codigo);
                                    }
                                    onExited: {
                                        if (previewCodigo === (celdaTienda.codigo === "_baraja" ? ventana.cartaSeleccionada : celdaTienda.codigo)) {
                                            previewCodigo = "";
                                            previewCategoria = "";
                                        }
                                    }
                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 12 * Tema.escala
                                    spacing: 5 * Tema.escala

                                    // Nombre + precio/nivel EN LA MISMA línea
                                    // (2026-09-02, pedido explícito: "podemos
                                    // poner el coste en treboles y el nivel al
                                    // lado del nombre, el efecto de
                                    // secundariedad lo tiene porque usa un
                                    // color mas apagado") -- antes eran dos
                                    // filas separadas; el color apagado ya
                                    // distingue lo secundario sin necesitar su
                                    // propia fila, y así la tarjeta baja de
                                    // altura de verdad.
                                    Row {
                                        width: parent.width
                                        spacing: 8 * Tema.escala
                                        // Miniatura real del objeto (pedido explícito
                                        // 2026-08-31) -- vacía en vez de un icono
                                        // inventado para Textura/Efecto/Título, que
                                        // todavía no tienen uno propio (ver
                                        // rutaIconoObjetoTienda()).
                                        Image {
                                            id: miniaturaTienda
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: source !== ""
                                            width: visible ? 20 * Tema.escala : 0
                                            height: width
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            // mipmap aunque la miniatura sea pequeña: Qt comparte la
                                            // textura de un PNG entre todas las Image que lo cargan, y
                                            // si la sube primero una sin mipmap, el Avatar de la
                                            // preview (que sí lo pide) se queda sin él y Qt lo avisa
                                            // por la terminal ("Mipmap settings changed without...").
                                            mipmap: true
                                            source: rutaIconoObjetoTienda(celdaTienda.codigo, celdaTienda.categoria)
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - miniaturaTienda.width - (miniaturaTienda.visible ? parent.spacing : 0)
                                                   - (sufijoPrecioTienda.visible ? sufijoPrecioTienda.width + parent.spacing : 0)
                                            elide: Text.ElideRight
                                            text: celdaTienda.nombre + (celdaTienda.equipado === 1 ? " · Equipado" : "")
                                            color: Tema.colorTexto
                                            font.bold: true
                                            font.pixelSize: 13 * Tema.escala
                                        }
                                        Row {
                                            id: sufijoPrecioTienda
                                            visible: celdaTienda.esDeLogro === 0
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4 * Tema.escala
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "· " + celdaTienda.precioTreboles
                                                color: Tema.colorTextoTenue
                                                font.pixelSize: 11 * Tema.escala
                                            }
                                            IconoTrebol {
                                                width: 9 * Tema.escala
                                                height: width
                                                anchors.verticalCenter: parent.verticalCenter
                                                colorTrebol: Tema.colorTextoTenue
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "· nivel " + celdaTienda.nivelMinimo
                                                color: Tema.colorTextoTenue
                                                font.pixelSize: 11 * Tema.escala
                                            }
                                        }
                                    }
                                    // Con cuál -- pedido explícito
                                    // 2026-09-02: "ya no solo pondrá que se
                                    // consigue con un logro, sino con cual".
                                    Text {
                                        visible: celdaTienda.esDeLogro === 1
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: celdaTienda.logroNombre !== ""
                                              ? "Logro: " + celdaTienda.logroNombre
                                              : "Se consigue con un logro"
                                        color: Tema.colorTextoMuyTenue
                                        font.pixelSize: 11 * Tema.escala
                                    }
                                    // Código real del objeto, SOLO visible para admin
                                    // (2026-09-01, pedido explícito: "necesito saber
                                    // los codigos de los objetos... haz visibles los
                                    // codigos para poder darme cosas a mi mismo") --
                                    // es justo el "codigo" que pide el botón "Conceder
                                    // logro/objeto (admin)" de Cuenta→Perfil. Nadie
                                    // más lo ve -- no es información de un jugador
                                    // normal.
                                    Text {
                                        visible: !ventana.sesionOffline && redcliente.estadisticasCuenta.esAdmin === true
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: celdaTienda.codigo
                                        color: Tema.colorTextoMuyTenue
                                        font.family: "monospace"
                                        font.pixelSize: 10 * Tema.escala
                                    }

                                    // "Carta de póker" es una tarjeta sintética que
                                    // representa la baraja entera. "+" abre el
                                    // selector de las 52 (pedido explícito
                                    // 2026-08-31: "eso abre un desplegable y eliges
                                    // una carta cualquiera"); al lado, según la
                                    // carta ya elegida (ventana.cartaSeleccionada,
                                    // rellenada por PopupSeleccionCarta), un botón
                                    // de Comprar (si no la tienes) o el mismo par
                                    // izq./der. que el resto de decoraciones
                                    // laterales (si ya la tienes) -- pedido
                                    // explícito: "no se dejan comprar cartas ya
                                    // obtenidas", elegir y comprar son dos pasos
                                    // separados, no uno solo dentro del selector.
                                    Row {
                                        visible: celdaTienda.codigo === "_baraja"
                                        spacing: 6 * Tema.escala
                                        BotonContorno {
                                            text: "+"
                                            onClicked: popupSeleccionCarta.open()
                                        }
                                        BotonContorno {
                                            readonly property var info: ventana.infoCartaSeleccionada()
                                            visible: ventana.cartaSeleccionada !== "" && info !== null && info.poseido === 0
                                            text: "Comprar"
                                            onClicked: redcliente.comprarObjeto(servidorHost, servidorPuerto,
                                                                                tokenSesion, ventana.cartaSeleccionada)
                                        }
                                        Row {
                                            readonly property var info: ventana.infoCartaSeleccionada()
                                            visible: ventana.cartaSeleccionada !== "" && info !== null && info.poseido === 1
                                            spacing: 4 * Tema.escala
                                            BotonContorno {
                                                readonly property bool aqui: redcliente.loadoutMarco.decoracionLateral1 === ventana.cartaSeleccionada
                                                text: aqui ? "Quitar izq." : "A la izq."
                                                colorBorde: aqui ? Tema.colorPeligro : Tema.colorBorde
                                                onClicked: redcliente.equiparObjeto(servidorHost, servidorPuerto, tokenSesion,
                                                    "decoracion_lateral_1", aqui ? "" : ventana.cartaSeleccionada)
                                            }
                                            BotonContorno {
                                                readonly property bool aqui: redcliente.loadoutMarco.decoracionLateral2 === ventana.cartaSeleccionada
                                                text: aqui ? "Quitar der." : "A la der."
                                                colorBorde: aqui ? Tema.colorPeligro : Tema.colorBorde
                                                onClicked: redcliente.equiparObjeto(servidorHost, servidorPuerto, tokenSesion,
                                                    "decoracion_lateral_2", aqui ? "" : ventana.cartaSeleccionada)
                                            }
                                        }
                                    }
                                    // Ancho completo de la tarjeta -- pedido
                                    // explícito 2026-09-02: "el boton de
                                    // comprar o quitar... se ve raro [en la
                                    // esquina]... quedaria mejor...
                                    // extendido a lo ancho de la tarjeta".
                                    BotonContorno {
                                        visible: celdaTienda.codigo !== "_baraja" &&
                                                 celdaTienda.poseido === 0 && celdaTienda.esDeLogro === 0
                                        width: parent.width
                                        text: "Comprar"
                                        onClicked: redcliente.comprarObjeto(servidorHost, servidorPuerto,
                                                                            tokenSesion, celdaTienda.codigo)
                                    }
                                    // "Comprado" -- estado final, visiblemente
                                    // inactivo (2026-09-02, pedido explícito:
                                    // "creo que 'quitar' en la tienda sobra,
                                    // coloca un boton que no funcione
                                    // visiblemente inactivo que ponga
                                    // 'comprado'" -- equipar/desequipar ya
                                    // vive solo en Personalizar, así que la
                                    // Tienda deja de tener un botón que hace
                                    // dos cosas distintas). Sustituye tanto
                                    // al viejo botón Equipar/Quitar de un
                                    // hueco como al par izq./der. de
                                    // decoraciones laterales -- mismo
                                    // criterio "enabled + opacity" que
                                    // "Enviada" en Social > Buscar/Recientes.
                                    // "_baraja" queda fuera -- su propio flujo
                                    // vive dentro del selector.
                                    BotonContorno {
                                        visible: celdaTienda.codigo !== "_baraja" && celdaTienda.poseido === 1
                                        width: parent.width
                                        enabled: false
                                        opacity: 0.6
                                        text: "Comprado"
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    id: columnaPreviewTienda
                    width: 220 * Tema.escala
                    spacing: 14 * Tema.escala

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "VISTA PREVIA"
                        color: Tema.colorTextoMuyTenue
                        font.pixelSize: 10 * Tema.escala
                        font.letterSpacing: 1
                    }
                    // Item envolvente en vez de que el Avatar cuelgue
                    // directo del Column -- decoracionSuperior sobresale
                    // por encima del propio anillo a propósito (ver el
                    // comentario de Avatar.qml), y con solo el spacing del
                    // Column (14*escala) se comía la etiqueta "VISTA
                    // PREVIA" de arriba en cuanto había algo puesto ahí
                    // (bug real reportado 2026-08-31). Alto de sobra
                    // reservado ARRIBA del propio avatar para ese
                    // sobresaliente, con el avatar anclado abajo del todo.
                    Item {
                        width: parent.width
                        // Reserva subida otra vez (26→46→60*escala) --
                        // la corona de 5 cartas de "mano_real" (coronaManoReal
                        // en Avatar.qml) sube más que el viejo decoSuperior.
                        height: 120 * Tema.escala + 60 * Tema.escala
                        Avatar {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            letra: nombreUsuario.text.length > 0 ? nombreUsuario.text.charAt(0).toUpperCase() : "?"
                            tamano: 120 * Tema.escala
                            marco: marcoPreview
                            textura: valorPreview("textura", redcliente.loadoutMarco.textura)
                            efecto: valorPreview("efecto", redcliente.loadoutMarco.efecto)
                            decoracionLateral1: valorPreview("decoracion_lateral", redcliente.loadoutMarco.decoracionLateral1)
                            decoracionLateral2: redcliente.loadoutMarco.decoracionLateral2 || ""
                            decoracionSuperior: valorPreview("decoracion_superior", redcliente.loadoutMarco.decoracionSuperior)
                            acabadoLateral1: acabadoPreview("decoracion_lateral", redcliente.loadoutMarco.decoracionLateral1, redcliente.loadoutMarco.acabadoLateral1)
                            acabadoLateral2: redcliente.loadoutMarco.acabadoLateral2 || ""
                            acabadoSuperior: acabadoPreview("decoracion_superior", redcliente.loadoutMarco.decoracionSuperior, redcliente.loadoutMarco.acabadoSuperior)
                        }
                    }
                    // Sin marco todavía: la vista previa usa Hierro (ver marcoPreview) y aquí
                    // se dice. Solo ocupa sitio si no tienes marco, y se enciende al
                    // previsualizar, así la columna no salta al pasar por los accesorios.
                    Text {
                        visible: sinMarcoPropio
                        opacity: previsualizandoConHierro ? 1 : 0
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "Así se verá con tu primer marco, Hierro. Gana una partida para desbloquear los accesorios."
                        color: Tema.colorTextoTenue
                        font.pixelSize: 11 * Tema.escala
                    }
                    // Los títulos no son una decoración del anillo -- el
                    // Avatar de arriba no reacciona al pasar el ratón por
                    // una tarjeta de la pestaña Perfil (títulos), así que
                    // necesitan su propia previsualización aparte (mismo
                    // criterio que la columna gemela de Personalizar).
                    CajaTitulo {
                        anchors.horizontalCenter: parent.horizontalCenter
                        readonly property var infoTituloVista: objetoTiendaPorCodigo(valorPreview("titulo", redcliente.loadoutMarco.titulo || ""))
                        nombre: infoTituloVista ? infoTituloVista.nombre : ""
                        colorTier: colorRareza(infoTituloVista ? infoTituloVista.rareza : "")
                    }
                }
            }
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
            color: Tema.colorTextoSobreOscuro
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
        // z alto a propósito: este overlay se declara ANTES que el de
        // showdown (más abajo), pero un showdown puede seguir "abierto"
        // (showdownAbierto) cuando la conexión se cae -- sin esto, el
        // aviso de reconexión quedaba tapado por el showdown en vez de
        // encima (parte del softlock de reconexión real reportado).
        z: 100
        color: "#0A140F"
        opacity: 0.92

        Column {
            anchors.centerIn: parent
            spacing: 12 * Tema.escala

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Conexión perdida — reconectando..."
                color: Tema.colorTextoSobreOscuro
                font.pixelSize: 18 * Tema.escala
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: segundosReconexion + "s restantes"
                color: Tema.colorTextoTenueSobreOscuro
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
                color: Tema.colorTextoTenueSobreOscuro
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
                        color: Tema.colorTextoTenueSobreOscuro
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
                        color: Tema.colorTexto
                        font.pixelSize: 13 * Tema.escala
                        horizontalAlignment: Text.AlignHCenter
                        validator: IntValidator { bottom: 1; top: 500 }
                        background: MarcoHueco {
                            radius: 6 * Tema.escala
                            activo: campoManosExtra.activeFocus
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

    // ── Cerrar Social v1: perfil público, invitar a sala, banner ──────────
    // Instancias únicas a nivel de ventana raíz -- mismo motivo que los
    // overlays de arriba: el perfil se abre desde varias pantallas (Social,
    // Ranking), y el banner de invitación puede llegar en cualquier
    // pantalla de menú.
    PopupPerfilJugador {
        id: popupPerfilJugador
        servidorHost: ventana.servidorHost
        servidorPuerto: ventana.servidorPuerto
        tiendaCrudo: ventana.tiendaCrudo
    }
    PopupInvitarAmigos {
        id: popupInvitarAmigos
        servidorHost: ventana.servidorHost
        servidorPuerto: ventana.servidorPuerto
        salaId: ventana.salaIdPropia
        listaAmigos: modeloAmigos
    }
    PopupAcabado {
        id: popupAcabado
        onAcabadoElegido: (slot, codigo, acabado) =>
            redcliente.equiparObjeto(servidorHost, servidorPuerto, tokenSesion, slot, codigo, acabado)
    }
    PopupSeleccionCarta {
        id: popupSeleccionCarta
        cartas: tiendaCrudo.filter(function(o) { return o.codigo.indexOf("carta_") === 0; })
        decoracionLateral1: redcliente.loadoutMarco.decoracionLateral1 || ""
        decoracionLateral2: redcliente.loadoutMarco.decoracionLateral2 || ""
        seleccionActual: ventana.cartaSeleccionada
        onCartaElegida: (codigo) => {
            ventana.cartaSeleccionada = codigo;
            fijarPreview("decoracion_lateral", codigo);
        }
    }
    BannerInvitacionSala {
        id: bannerInvitacionSala
        onUnirse: (salaId, codigo) => {
            redcliente.unirseASala(servidorHost, servidorPuerto, nombreUsuario.text, salaId, codigo);
        }
    }
    BannerVersionNueva {
        id: bannerVersionNueva
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
        // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
        layer.enabled: true
        layer.effect: ShaderEffect {
            property variant source
            property real amplitud: 30.0
            fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
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

            // Título único otra vez -- "Cuenta" se mudó al riel (pestaña
            // propia, 2026-08-31), así que este cajón ya solo tiene
            // "cómo se ve/comporta el cliente" (tema, mesa, cliente), sin
            // necesidad de un selector para elegir entre dos secciones
            // cuando ya solo queda una.
            Text {
                text: "AJUSTES"
                color: Tema.colorTextoMuyTenue
                font.pixelSize: 11 * Tema.escala
                font.letterSpacing: 1
            }

            Column {
                width: parent.width
                spacing: 10 * Tema.escala

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
                                color: Tema.temaActual === filaTema.index ? Tema.colorTexto : Tema.colorTextoTenue
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
                visible: pantalla === "Partida"
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
                            color: Tema.colorTexto
                            font.pixelSize: 12 * Tema.escala
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            // ── Cliente ────────────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 10 * Tema.escala

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
            }

            // ── Versión (pendiente 9 de CLAUDE.md, 2026-09-10) ──────────────────
            // Descarga DIRECTA del fichero de esta plataforma en la última release
            // pública -- ver VersionChecker::urlDescarga().
            Column {
                width: parent.width
                spacing: 10 * Tema.escala
                Text {
                    text: "VERSIÓN"
                    color: Tema.colorTextoMuyTenue
                    font.pixelSize: 11 * Tema.escala
                    font.letterSpacing: 1
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Instalada: v" + versionChecker.versionActual
                          + (versionChecker.hayVersionNueva ? " · hay una nueva: v" + versionChecker.versionRemota : "")
                    color: versionChecker.hayVersionNueva ? Tema.colorAccent : Tema.colorTextoTenue
                    font.pixelSize: 13 * Tema.escala
                }
                BotonContorno {
                    width: parent.width
                    text: "Descargar la última versión"
                    onClicked: Qt.openUrlExternally(versionChecker.urlDescarga)
                }
            }
        }
        }
    }
}
