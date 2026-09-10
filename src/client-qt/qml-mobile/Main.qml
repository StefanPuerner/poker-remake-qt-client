pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile
import QtQuick.Controls
import QtQuick.Controls.Material
// QtCore en vez de Qt.labs.settings (2026-09-10): el de labs está
// obsoleto y avisaba en cada arranque. Mismo backend -- comprobado con
// el runtime de Qt 6 que QtCore.Settings lee lo que escribió el viejo
// con la misma category, así que nadie pierde su sesión al actualizar.
// Existe desde Qt 6.5; el CI más viejo (Android) usa 6.7.3.
import QtCore
// SOLO para el brillo del botón activo del mini-riel de Personalizar
// (2026-09-02, "en el riel... en el artifact se simula un brillo desde
// el boton"). Nativo de Qt 6.5+ (viene con el propio módulo Quick, no
// hace falta enlazar nada nuevo en CMake) -- a diferencia del resto de
// "sombras baratas" del proyecto (Rectangle desplazado, sin blur real),
// aquí sí compensa: son como mucho 4 botones en pantalla a la vez, no
// una rejilla de decenas de tarjetas.
import QtQuick.Effects

ApplicationWindow {
    id: ventana
    visible: true
    width: 800
    height: 480
    title: "PokerRemake (móvil)"
    color: Tema.colorFondo
    Material.theme: Material.Dark
    Material.accent: Tema.colorAccent

    // Mismo motivo que escritorio (ver Main.qml de qml/): cualquier
    // TextField enfocado se quedaba con el foco indefinidamente si dejabas
    // de escribir y tocabas en otro sitio sin control propio, en vez de
    // perderlo (y cerrar el teclado en pantalla) como en cualquier
    // formulario normal. z explícito -- aquí no hay un único Rectangle
    // raíz que envuelva todas las pantallas como en escritorio, así que no
    // basta con ser "el primer hijo" para garantizar quedar debajo de
    // todo.
    Item {
        id: capturaFocoFondoMovil
        anchors.fill: parent
        z: -1000
        focus: true
        MouseArea {
            anchors.fill: parent
            onClicked: capturaFocoFondoMovil.forceActiveFocus()
        }
    }

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
    // escritorio -- las 6 pantallas "hub" con riel (Salas/Ranking/Torneos/
    // Social/Tienda/Cuenta) van a Inicio (pedido explícito 2026-08-28:
    // antes solo Salas tenía salida por gesto de atrás, las otras se
    // tragaban el back sin hacer nada; "Tienda"/"Cuenta" llegaron después
    // -- Fases M1/M2 del port de progresión -- y se quedaron fuera de
    // este mapa por descuido, bug real reportado 2026-09-02: "no funciona
    // en las secciones nuevas"), CrearSala→Salas, Fin→Salas. Lobby/Partida
    // quedan fuera a propósito: abandonar una partida en curso pasa por
    // el overlay de voto, no por un back que se salte esa confirmación.
    property string pantalla: "Inicio"
    readonly property var mapaAtras: ({
        "Salas": "Inicio",
        "Ranking": "Inicio",
        "Torneos": "Inicio",
        "Social": "Inicio",
        "Tienda": "Inicio",
        "Cuenta": "Inicio",
        "CrearSala": "Salas",
        "Fin": "Salas"
    })
    property bool ajustesAbiertos: false
    // Modo offline (Torneos > Solitario) -- ver el comentario gemelo en
    // qml/Main.qml (escritorio).
    property bool modoOfflineActivo: false
    property bool sesionOffline: false
    property bool offlineConCuenta: false
    // "¿Hay cuenta detrás de esta sesión?" para decidir qué PINTAR -- ver
    // el comentario gemelo en qml/Main.qml (escritorio). No sustituye a
    // tokenSesion en los guards de llamadas de red.
    readonly property bool hayCuenta: tokenSesion !== "" || offlineConCuenta

    // Estadísticas y loadout propios al autenticarse -- ver el comentario
    // gemelo en qml/Main.qml (escritorio): sin esto la caché offline se
    // quedaba solo con el nombre y la sesión sin conexión entraba con tu
    // cuenta pero sin nivel, XP ni cosméticos.
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

    // Entra en una sesión sin conexión completa -- ver el comentario
    // gemelo en qml/Main.qml (escritorio).
    function entrarSinConexion(conCuenta) {
        var usarCuenta = conCuenta && modoJuego.usernameCacheado !== "";
        modoJuego.activarModoLocal();
        sesionOffline = true;
        modoOfflineActivo = true;
        offlineConCuenta = usarCuenta;
        // redcliente ya es el cliente local (activarModoLocal() arriba), así
        // que este método existe. Solo se acumula XP con cuenta: de invitado
        // no hay a quién acreditárselo.
        redcliente.setAcumularXpOffline(usarCuenta);
        decisionInicioTomada = true;
        tokenSesion = "";
        nombreJugador = usarCuenta ? modoJuego.usernameCacheado
                                   : "Invitado" + Math.floor(Math.random() * 100000);
        mensajeErrorConexion = "";
        // Ver el comentario gemelo en qml/Main.qml: Torneos solo donde está
        // habilitado (POKER_TORNEOS); si no, Salas.
        pantalla = torneosHabilitados ? "Torneos" : "Salas";
    }

    onPantallaChanged: {
        if (pantalla === "Inicio" && sesionOffline) {
            sesionOffline = false;
            offlineConCuenta = false;
            modoOfflineActivo = false;
            modoJuego.activarModoRed();
        }
    }
    // Refresca las estadísticas propias cada vez que se abre el cajón --
    // mismo criterio que escritorio (ver Main.qml de qml/). No-op sin
    // sesión (consultarEstadisticas() descarta un token vacío por su cuenta).
    onAjustesAbiertosChanged: {
        if (ajustesAbiertos && ventana.tokenSesion !== "") {
            redcliente.consultarEstadisticas(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion);
        }
        // Al cerrar: vuelve a la pestaña "Ajustes" y al principio del
        // scroll -- mismo criterio que escritorio (ver Main.qml de qml/),
        // estado inicial de verdad la próxima vez que se abra.
        if (!ajustesAbiertos) {
            ventana.pestanaAjustesActual = 0;
            if (scrollAjustesMovil.contentItem) scrollAjustesMovil.contentItem.contentY = 0;
        }
    }

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

    // ── Ajustes persistentes (nombre, sonido, tema) ─────────────────────
    // Mismo patrón que escritorio (ver Main.qml de qml/) -- antes esto
    // vivía solo en memoria, se perdía al cerrar la app. "tema" NO es un
    // property alias directo a Tema.temaActual a propósito: un alias a una
    // propiedad de un SINGLETON rompe el Settings entero en silencio (nada
    // se guarda, ni siquiera el resto de aliases) -- comprobado en real en
    // el cliente de escritorio. Se guarda como entero normal y se
    // sincroniza a mano en los dos sentidos, justo debajo.
    Settings {
        id: ajustesPersistentesMovil
        category: "PokerRemake"
        // Reemplaza al viejo "nombreGuardado" (nombre libre persistido) --
        // ahora la identidad la da la cuenta (o un nombre de invitado
        // efímero, sin persistir). Property normal de "ventana", nunca un
        // alias a un singleton (mismo aviso de "tema" un poco más abajo).
        property alias tokenGuardado: ventana.tokenSesion
        property alias sonido: ventana.sonidoActivado
        property int temaGuardado: 0
    }
    Component.onCompleted: {
        Tema.temaActual = ajustesPersistentesMovil.temaGuardado;
        // Reautenticación silenciosa: si hay un token guardado de una
        // sesión anterior, se intenta ANTES de que el usuario vea nada de
        // Inicio -- si el servidor lo acepta (onLoginOk), se entra directo
        // a Salas sin pedir contraseña; si no (onSesionInvalida), se
        // limpia y Inicio se muestra normal.
        if (tokenSesion !== "") {
            redcliente.iniciarSesionConToken(servidorHost, servidorPuerto, tokenSesion);
        }
        // Aviso de versión antigua: en segundo plano, sin bloquear nada de
        // lo de arriba -- si falla (sin red, API caída) no pasa nada, ver
        // VersionChecker.hpp.
        versionChecker.comprobar();
    }
    Connections {
        target: Tema
        function onTemaActualChanged() { ajustesPersistentesMovil.temaGuardado = Tema.temaActual; }
    }
    Connections {
        target: versionChecker
        function onHayVersionNuevaChanged() {
            if (versionChecker.hayVersionNueva) {
                bannerVersionNueva.mostrar(versionChecker.versionRemota, versionChecker.urlRelease);
            }
        }
    }
    // ── Ajustes ──────────────────────────────────────────────────────────
    // Desactivado por defecto (misma decisión que en escritorio).
    property bool sonidoActivado: false
    // "Confirmar antes de ALL-IN" -- no existía en móvil (el botón ALL
    // pedía confirmación SIEMPRE, sin ajuste que lo controle). Mismo
    // criterio que escritorio: desactivado por defecto, sin persistir.
    property bool confirmarAllIn: false
    // Cajón lateral: SOLO Ajustes desde 2026-09-01 (Fase M1 del port de
    // progresión a móvil -- "Cuenta" se mudó a su propia pantalla en el
    // riel, mismo criterio ya aprobado en escritorio 2026-08-31). El
    // valor en sí ya no distingue nada (una sola pestaña), se deja para
    // no romper los bindings que ya lo usan.
    property int pestanaAjustesActual: 0
    // Pestaña activa de la pantalla Cuenta (riel): 0=Perfil, 1=Progreso,
    // 2=Logros, 3=Personalizar. Mismo criterio que escritorio.
    property int pestanaCuentaActual: 0
    // Bug real reportado 2026-09-02: Perfil/Progreso/Logros comparten el
    // MISMO ScrollView (scrollCuentaMovil) -- solo cambia qué Column
    // interna es visible, la instancia nunca se destruye. Sin esto, si
    // bajabas del todo en una pestaña y cambiabas a otra, esa otra se
    // abría igual de bajada (contentY sobrevive al cambio de pestaña).
    // "if (contentItem)" -- mismo guard que scrollAjustesMovil, la
    // primera vez que corre este handler el ScrollView puede no tener
    // contentItem todavía.
    onPestanaCuentaActualChanged: {
        if (scrollCuentaMovil.contentItem) scrollCuentaMovil.contentItem.contentY = 0;
    }
    // Pestaña activa de la pantalla Social: 0=Amigos, 1=Buscar jugadores,
    // 2=Jugadores Recientes, 3=Solicitudes. Mismo criterio que escritorio.
    property int pestanaSocialActual: 0

    // ── Sesión / red ─────────────────────────────────────────────────────
    property string nombreJugador: ""
    // Token de sesión de la cuenta activa ("" = invitado o sin sesión) --
    // persistido vía Settings.tokenGuardado (alias de arriba).
    property string tokenSesion: ""
    // Evita una carrera real en dispositivo (no se ve en el PC de prueba,
    // donde todo es local e instantáneo): la reautenticación silenciosa de
    // Component.onCompleted puede tardar en responder, y "Entrar como
    // invitado" se habilita en cuanto conectadoAlServidor lo hace (una
    // sonda de red aparte, normalmente más rápida). Si el usuario pulsa
    // invitado antes de que la reautenticación responda, un onLoginOk
    // tardío volvía a rellenar tokenSesion segundos después -- la sección
    // Cuenta del cajón de Ajustes reaparecía sola aun jugando de invitado
    // (bug real reportado). true en cuanto la identidad de esta sesión
    // queda decidida (invitado explícito, o login/registro con éxito);
    // onLoginOk/onRegistroOk ignoran cualquier respuesta que llegue
    // después de eso.
    property bool decisionInicioTomada: false
    // Compartido por las pantallas Login y Registro, y por la sección
    // Cuenta del cajón de ajustes -- se limpia al entrar en cualquiera de
    // ellas o al reintentar, para no dejar visible el error de un intento
    // anterior.
    property string mensajeErrorLogin: ""
    // cambiarNombreUsuario()/cambiarPassword() pueden fallar por el mismo
    // motivo que un token caducado en iniciarSesionConToken() -- mismo
    // mensaje exacto que manda AccountManager::resolverToken() al fallar
    // (ver AccountManager.cpp). Sin esto, el usuario se quedaba con una
    // sesión rota reintentando la misma acción sin que nada le dijera que
    // el problema real es "vuelve a iniciar sesión".
    function tratarErrorCuenta(mensaje) {
        mensajeErrorLogin = mensaje;
        if (mensaje.indexOf("Sesión caducada") === 0) {
            tokenSesion = "";
            nombreJugador = "";
            decisionInicioTomada = false;
            ajustesAbiertos = false;
            pantalla = "Inicio";
        }
    }
    property string servidorHost: SERVER_HOST_DEFAULT
    property int servidorPuerto: SERVER_PORT_DEFAULT
    // Estado de conectividad mostrado en Inicio -- mismo mecanismo que
    // escritorio (comprobandoConexion distingue "aún no sabemos" de "ya
    // sabemos que no hay servidor", para no enseñar el aviso rojo un
    // instante antes de tener respuesta real).
    property bool conectadoAlServidor: false
    property bool comprobandoConexion: true
    // Sonda periódica mientras se está en Inicio -- host/puerto son fijos
    // en tiempo de ejecución, así que no hace falta relanzarla por ningún
    // cambio de ajustes, solo al llegar a esta pantalla y cada intervalo
    // mientras se siga en ella. triggeredOnStart dispara una comprobación
    // inmediata tanto al arrancar la app como al volver a Inicio.
    Timer {
        interval: 12000
        running: ventana.pantalla === "Inicio"
        repeat: true
        triggeredOnStart: true
        onTriggered: redcliente.comprobarConexion(ventana.servidorHost, ventana.servidorPuerto)
    }
    // Compartido entre Inicio y Salas — las dos pueden iniciar una conexión
    // (refrescarSalas/unirseASala/cargarPartidaGuardada) y un fallo puede
    // llegar estando en cualquiera de las dos.
    property string mensajeErrorConexion: ""
    // Mismo criterio que escritorio (ver Main.qml de qml/): se autolimpia
    // a los 5s en vez de quedarse hasta la próxima acción que lo reasigne.
    onMensajeErrorConexionChanged: {
        if (mensajeErrorConexion !== "") timerErrorConexion.restart();
    }
    Timer {
        id: timerErrorConexion
        interval: 5000
        onTriggered: mensajeErrorConexion = ""
    }
    // Reconexión automática (60s, mismo mecanismo que ncurses/escritorio)
    // — más importante aún en móvil, donde cambiar de wifi o mandar la
    // app a segundo plano corta la conexión con mucha más frecuencia
    // que en un PC.
    property bool reconectandoAhora: false
    property int segundosReconexion: 0
    property bool viendoGuardadas: false
    // Pestaña "Sala privada" del selector de Salas -- unirse por código
    // (ver SelectorPildoras más abajo). Independiente de viendoGuardadas
    // porque el selector ahora tiene 3 opciones, no un simple on/off.
    property bool viendoPrivada: false
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
    // Filas de hasta 3 salas cada una -- lo que de verdad pinta la lista
    // de Salas (ver listaSalasMovil), reconstruida cada vez que cambia
    // salasDisponibles (mismo patrón que modeloAmigosConChat). Necesario
    // para poder seguir usando ListView (no GridView) como contenedor de
    // scroll -- ver el comentario largo junto a listaSalasMovil.
    ListModel { id: salasAgrupadasMovil }
    function reconstruirSalasAgrupadas() {
        salasAgrupadasMovil.clear();
        var fila = [];
        for (var i = 0; i < salasDisponibles.count; i++) {
            var s = salasDisponibles.get(i);
            fila.push({ id: s.id, conectados: s.conectados, esperados: s.esperados, nombre: s.nombre });
            if (fila.length === 3) {
                salasAgrupadasMovil.append({ salas: fila });
                fila = [];
            }
        }
        if (fila.length > 0) salasAgrupadasMovil.append({ salas: fila });
    }

    // ── Ranking global -- mismo criterio que escritorio (ver Main.qml de
    // qml/): rankingCrudo sin ordenar, reordenarRanking() reconstruye
    // rankingModel según la pestaña elegida sin volver a preguntar al
    // servidor.
    property var rankingCrudo: []
    // 0 = más victorias, 1 = mejor ratio, 2 = Elo (Fase M3 del port de
    // progresión a móvil, 2026-09-01) -- pestaña por defecto al ENTRAR
    // (mide habilidad, no dedicación), mismo criterio que escritorio.
    property int ordenRankingActual: 2
    ListModel { id: rankingModel }
    // Podio (Fase M3) -- top 3 de la pestaña activa, mismo criterio que
    // escritorio: array de JS normal (máx. 3), "" si aún no hay 3
    // cuentas en el ranking.
    property var rankingPodio: []

    // ── Logros (Fase 4 del sistema de progresión) -- Fase M1 del port a
    // móvil (2026-09-01, ver memoria qt_mobile_progression_port_plan).
    ListModel { id: logrosModel }

    // ── Tienda (Fase 5) -- catálogo crudo + los 2 helpers para resolver
    // un título ajeno (ver PopupPerfilJugador.qml), Fase M0 del port de
    // progresión a móvil (2026-09-01, ver memoria
    // qt_mobile_progression_port_plan). La pantalla Tienda en sí
    // (comprar/equipar, pestaña propia en el riel) es la Fase M2, mismo
    // turno -- port directo de escritorio (catálogo + búsqueda + selector
    // de carta), con la MISMA diferencia deliberada que Personalizar: sin
    // previsualización al pasar el dedo.
    property var tiendaCrudo: []
    function objetoTiendaPorCodigo(codigo) {
        if (codigo === "") return null;
        for (var i = 0; i < tiendaCrudo.length; i++) {
            if (tiendaCrudo[i].codigo === codigo) return tiendaCrudo[i];
        }
        return null;
    }
    function colorRareza(r) {
        return r === "oro" ? "#e3bb82" : r === "plata" ? "#9aa4ab" : r === "bronce" ? "#c98f5f" : "#7d848f";
    }
    property int pestanaTiendaActual: 0  // 0 = Marco (textura/efecto/decoraciones), 1 = Perfil (títulos)
    // Búsqueda en vivo del catálogo -- mismo criterio que escritorio,
    // filtra sobre tiendaCrudo sin pedir nada nuevo al servidor.
    property string busquedaTienda: ""
    // Carta elegida en PopupSeleccionCarta -- "" = ninguna. Solo ELIGE
    // (y se cierra); comprar/equipar de verdad pasa por los botones de
    // la propia tarjeta "Carta de póker" de la Tienda, que miran esta
    // property para saber cuál es "la elegida".
    property string cartaSeleccionada: ""
    function infoCartaSeleccionada() {
        for (var i = 0; i < tiendaCrudo.length; i++) {
            if (tiendaCrudo[i].codigo === cartaSeleccionada) return tiendaCrudo[i];
        }
        return null;
    }
    // Previsualización en vivo del avatar (Fase M2.1, 2026-09-02, pedido
    // explícito: "no existe preview en tienda... en movil pulsar en el
    // cuadro" -- port directo de escritorio, mismo criterio SIN estado
    // pegajoso). En escritorio se dispara con el ratón encima
    // (hoverEnabled + onEntered/onExited); en móvil no hay hover táctil,
    // así que el equivalente real es "mientras el dedo está apoyado"
    // (MouseArea.pressed) -- se ve mientras tocas la tarjeta, desaparece
    // al soltar, igual de efímera que el hover.
    property string previewCodigo: ""
    property string previewCategoria: ""
    function valorPreview(categoria, valorReal) {
        if (previewCategoria === categoria && previewCodigo !== "") return previewCodigo;
        return valorReal || "";
    }
    // Cambia el objeto en preview de una sola vez -- ver el comentario gemelo
    // en qml/Main.qml: con la categoría nueva y el código viejo todavía
    // puesto, valorPreview() le pasaba un instante ese código a otra capa.
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
    ListModel { id: tiendaModel }
    function reordenarTienda() {
        var categoriasMarco = ["textura", "efecto", "decoracion_lateral", "decoracion_superior"];
        var busqueda = busquedaTienda.trim().toLowerCase();
        var esCartaBaraja = function(o) { return o.codigo.indexOf("carta_") === 0; };

        // Las 52 cartas sueltas no se listan como tarjetas propias -- van
        // todas dentro del selector "+" (PopupSeleccionCarta).
        var filas = tiendaCrudo.filter(function(o) {
            if (esCartaBaraja(o)) return false;
            var pasaPestana = ventana.pestanaTiendaActual === 0
                   ? categoriasMarco.indexOf(o.categoria) >= 0
                   : o.categoria === "titulo";
            var pasaBusqueda = busqueda === "" || o.nombre.toLowerCase().indexOf(busqueda) >= 0;
            return pasaPestana && pasaBusqueda;
        });

        // Tarjeta sintética representando la baraja entera -- mismo
        // criterio que escritorio.
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

    // ── Cuenta > Personalizar (Fase M1 del port a móvil, 2026-09-01) ────
    property int pestanaPersonalizarActual: 0  // 0=Texturas,1=Efectos,2=Decoraciones,3=Títulos
    property string mensajeTienda: ""
    // Categoría(s) de shop_items que corresponde a cada pestaña -- port
    // directo de escritorio.
    function categoriasPersonalizar(indice) {
        if (indice === 0) return ["textura"];
        if (indice === 1) return ["efecto"];
        if (indice === 2) return ["decoracion_lateral", "decoracion_superior"];
        if (indice === 3) return ["titulo"];
        return [];
    }
    // Objetos YA POSEÍDOS de la pestaña activa -- Personalizar solo
    // equipa, nunca compra (comprar es la Tienda, pantalla propia en el
    // riel desde la Fase M2).
    readonly property var itemsPersonalizar: {
        var cats = categoriasPersonalizar(pestanaPersonalizarActual);
        return tiendaCrudo.filter(function(o) {
            return o.poseido === 1 && cats.indexOf(o.categoria) >= 0;
        });
    }
    // Iconos de decoración -- mismo criterio que Avatar.qml::
    // rutaIconoDecoracion() (el nombre de fichero es el propio código).
    function rutaIconoObjetoTienda(codigo, categoria) {
        var base = "qrc:/qt/qml/PokerQuickMobile/assets/iconos/";
        // "palos_en_fila" tenía aquí su propio case (devolvía suit_club.png
        // como representante de los cuatro palos). Desde 2026-09-09 la
        // placa con los cuatro va compuesta en el propio PNG
        // (scripts/generar_iconos.sh), así que cumple la regla del nombre
        // y cae sola en el return de más abajo -- un caso especial menos.
        switch (codigo) {
        case "": return "";
        case "mano_real":
            return base + "carta_ace_picas.png";
        case "escalera_diamantes":
            return base + "carta_7_diamantes.png";
        case "cuatro_ases":
            return base + "carta_ace_corazones.png";
        // Representativo -- el selector "+" tiene las 52. Faltaba aquí y no en
        // escritorio: la miniatura pedía "_baraja.png", que no existe
        // ("Cannot open", log del móvil del 2026-09-10).
        case "_baraja":
            return base + "carta_ace_picas.png";
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
        // "posicion" es el puesto REAL -- se guarda ANTES de repartir
        // entre podio/resto, mismo motivo que escritorio: la lista de
        // abajo empieza en el 4º puesto pero debe seguir mostrando "4",
        // "5"... no reiniciar en "1".
        for (var i = 0; i < filas.length; i++) filas[i].posicion = i + 1;

        // Podio: top 3 aparte, la lista de siempre sigue desde el 4º
        // puesto -- mismo criterio que escritorio, sin duplicar el top 3.
        rankingPodio = filas.length >= 3 ? filas.slice(0, 3) : [];
        var resto = filas.length >= 3 ? filas.slice(3) : filas;
        rankingModel.clear();
        for (var i = 0; i < resto.length; i++) rankingModel.append(resto[i]);
        // Reactiva el "pin" de contentY=0 (ver el comentario grande junto
        // a listaRankingMovil.anclarArriba) para este reordenamiento.
        listaRankingMovil.anclarArriba = true;
        Qt.callLater(() => { listaRankingMovil.contentY = 0; });
    }
    // ── Social -- mismo criterio que escritorio (ver Main.qml de qml/) ──
    ListModel { id: modeloAmigos }
    ListModel { id: modeloBusqueda }
    ListModel { id: modeloRecientes }
    ListModel { id: modeloSolicitudes }
    property string pendienteSolicitudUsername: ""
    property string mensajeErrorSocial: ""
    // ── Amigos + chat fusionados (Cerrar Social v1) ─────────────────────
    // Mismo criterio que escritorio (ver Main.qml de qml/): "Chats" no es
    // una pestaña aparte, cada fila de Amigos ya muestra presencia Y el
    // último mensaje. modeloResumenChats es la fuente cruda; modeloAmigosConChat
    // es el cruce por accountId que de verdad pinta la lista.
    ListModel { id: modeloResumenChats }
    ListModel { id: modeloAmigosConChat }
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
                // !! fuerza booleano de verdad -- mismo bug/arreglo que
                // escritorio (parsearFilasChat() en C++ manda "0"/"1" como
                // número, no bool; sin el !!, el primer amigo sin chat aún
                // fija el rol de ListModel como Bool y el siguiente con
                // chat rompe "Can't assign to existing role... of
                // different type").
                ultimoEsMio: r2 ? !!r2.ultimoEsMio : false,
                noLeidos: r2 ? r2.noLeidos : 0
            });
            // Cabecera del chat flotante al día si está abierta justo para
            // este amigo -- mismo criterio que escritorio (chatAmigoSeleccionadoEstado).
            if (popupChatDirecto.accountId === a.accountId) popupChatDirecto.estado = a.estado;
        }
    }
    // El estado "pendiente" viene del SERVIDOR (ver el comentario largo en
    // Main.qml de qml/) -- esta función solo hace la actualización
    // optimista de la fila recién mandada, sin esperar a la próxima
    // búsqueda.
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
    // Fase M0 del port de progresión a móvil (2026-09-01, ver memoria
    // qt_mobile_progression_port_plan) -- sin esto, el marco Hierro
    // (ganado también contra bots) nunca se activaba en el propio avatar
    // de Cuenta, solo el tier real desde partidasGanadas.
    property bool statsTieneMarcoBasico: false
    // Fase M1 del port de progresión a móvil (2026-09-01) -- XP total,
    // para la pestaña Progreso (Cuenta). Sin esto móvil no tenía forma
    // de saber en qué nivel está el jugador.
    property int statsXpTotal: 0
    property int statsRachaActual: 0
    property int statsRachaMaxima: 0
    property int statsMayorBote: 0
    property string statsMejorManoNombre: ""
    property int statsMejorManoFecha: 0
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
    // Fase M1 del port de progresión a móvil (2026-09-01) -- para
    // progresoLogro() en la pestaña Logros ("cuánto te queda").
    property int statsVecesGanoSinShowdown: 0
    property int statsRachaManosGanadas: 0
    // Fase M2 del port de progresión a móvil (2026-09-01) -- saldo de
    // Tréboles (precio de la Tienda) y si la cuenta es admin (código de
    // objeto visible en las tarjetas, mismo criterio que escritorio).
    property int statsTreboles: 0
    property bool statsEsAdmin: false

    // Fase 4 del sistema de progresión: colores/etiquetas de rareza --
    // port directo de escritorio, sin diferencias.
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
    // Orden fijo Bronce→Plata→Oro, desbloqueados siempre al final.
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
    // "Cuánto te queda" -- solo para los logros con un contador numérico
    // de verdad ya expuesto al cliente, el resto son eventos puntuales.
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
        return "Puntual";
    }

    // ── Progreso de marco de avatar + nivel (pestaña Cuenta > Progreso) ──
    // Fase M1 del port de progresión a móvil (2026-09-01, ver memoria
    // qt_mobile_progression_port_plan) -- port directo de las mismas
    // funciones de escritorio (Main.qml de qml/), sin diferencias.
    function nombreMarco(m) {
        return m === "platino" ? "Platino" : m === "oro" ? "Oro" : m === "plata" ? "Plata"
               : m === "bronce" ? "Bronce" : m === "hierro" ? "Hierro" : "Sin marco";
    }
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
    function umbralAnteriorMarco(n) {
        if (n < 1) return 0;
        if (n < 5) return 1;
        if (n < 15) return 5;
        if (n < 25) return 15;
        return 25;
    }
    // Fase 2 del sistema de progresión: nivel 1→2 a 150 XP, cada nivel
    // siguiente pide un 20% más que el anterior, sin techo -- el nivel se
    // CALCULA aquí a partir de xpTotal en vez de guardarse aparte.
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
    property var progresoNivelActual: progresoNivel(statsXpTotal || 0)

    // ── Lobby ────────────────────────────────────────────────────────────
    property string codigoSalaPropia: ""
    // El sala_id propio -- mismo motivo que en escritorio: antes solo lo
    // conocía quien CREABA la sala (SALA_CREADA); ahora también llega al
    // unirse (SALA_UNIDA). Necesario para invitarASala() desde el Lobby.
    property string salaIdPropia: ""
    property string nombresEsperadosLobby: ""
    property string hostActual: ""
    // soyHost es SIEMPRE verdad de servidor (ver Main.qml de qml/, mismo
    // criterio): se recalcula comparando el "host" que manda
    // LOBBY_UPDATE/PARTIDA_INICIADA contra nombreJugador, ya corregido al
    // nombre real vía onNombreAsignado(). El flag local optimista de
    // antes (creadorDeLaSala) hacía que cualquiera que pulsase "Reanudar"
    // en una partida guardada se creyera host, aunque el servidor hubiera
    // asignado el puesto a otro -- bug real reportado en playtest.
    property bool soyHost: false
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
    // Dealer/ciegas de la mano actual (campos "dealer"/"sb"/"bb" de
    // GAME_STATE) -- para los marcadores D/SB/BB de Mesa/Asiento.
    property string dealerNombre: ""
    property string sbNombre: ""
    property string bbNombre: ""
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
    // FASE 2 de la extensión de partida (tras la unanimidad del voto de
    // arriba): cuántas manos más se juegan. Solo el host lo elige
    // (soyYoQuienElige); el resto solo ve el mensaje de espera.
    property bool esperandoManosExtra: false
    property string manosExtraMensaje: ""
    property bool soyYoQuienElige: false
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
        // El "false" de público/privado que sigue aquí abajo ya NO decide
        // nada -- el servidor usa el público/privado guardado de verdad en
        // el snapshot para CARGAR_PARTIDA (ver server/main.cpp), no lo que
        // mande el cliente. Antes SÍ mandaba a fuego "privada" en cada
        // recarga, así que cualquier sala pública se volvía privada con
        // código nuevo sin que nadie lo pidiera (bug real reportado).
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

    // Fecha de "mejor mano" (pestaña Cuenta): toLocaleDateString() da un
    // formato largo ("martes, 25 de agosto de 2026") que no cabe en la
    // columna de valor de esta pantalla, mucho más estrecha que la de
    // escritorio -- se corta a la mitad (visto en real). AA/MM/DD numérico
    // en vez de intentar acortar el formato largo por locale.
    function formatearFechaCorta(unixSegundos) {
        var d = new Date(unixSegundos * 1000);
        var dosDigitos = function(n) { return (n < 10 ? "0" : "") + n; };
        return dosDigitos(d.getFullYear() % 100) + "/" +
               dosDigitos(d.getMonth() + 1) + "/" +
               dosDigitos(d.getDate());
    }

    Connections {
        target: redcliente
        // ── Cuentas de usuario ──────────────────────────────────────────
        // registroOk/loginOk comparten handler -- en los dos casos el
        // destino es el mismo (Salas, como ya hacía "Entrar como
        // invitado"), tanto si viene de las pantallas Login/Registro como
        // del intento silencioso al arrancar (iniciarSesionConToken, ver
        // Component.onCompleted).
        function onRegistroOk(accountId, username, token) {
            if (decisionInicioTomada) return;
            decisionInicioTomada = true;
            nombreJugador = username;
            tokenSesion = token;
            mensajeErrorLogin = "";
            pantalla = "Salas";
            redcliente.refrescarSalas(servidorHost, servidorPuerto);
            redcliente.conectarPresencia(servidorHost, servidorPuerto);
            // Fase M0 del port de progresión a móvil (2026-09-01, ver
            // memoria qt_mobile_progression_port_plan) -- se pide ya
            // mismo, no solo al entrar en Tienda (que en móvil ni existe
            // todavía), para que tiendaCrudo esté listo y se pueda
            // resolver el nombre/rareza de un título ajeno desde
            // cualquier pantalla (ver PopupPerfilJugador.qml).
            redcliente.consultarTienda(servidorHost, servidorPuerto, tokenSesion);
            ventana.pedirDatosDeCuenta();
        }
        function onRegistroError(mensaje) {
            mensajeErrorLogin = mensaje;
        }
        function onLoginOk(accountId, username, token) {
            // Ver decisionInicioTomada más arriba -- si el usuario ya
            // eligió "Entrar como invitado" mientras esto viajaba, se
            // ignora: llega tarde y no debe suplantar esa elección.
            if (decisionInicioTomada) return;
            decisionInicioTomada = true;
            nombreJugador = username;
            tokenSesion = token;
            mensajeErrorLogin = "";
            // Sala/partida guardada en disco de una sesión anterior
            // (Android mató el proceso mientras seguíamos dentro) -- ver
            // el comentario largo en NetworkClient::intentarRecuperarSesion().
            // El propio C++ decide si hay algo que recuperar (persistencia
            // vive ahí, no aquí, para poder forzar sync() a disco en el
            // momento exacto en que cambia -- ver esa función). El overlay
            // de "reconectando" lo dispara solo la señal reconectando()
            // que esto emite si de verdad intenta algo (mismo mecanismo
            // que cualquier otra reconexión, ver onReconectando más abajo);
            // si falla, onReconexionFallida ya limpia lo persistido.
            var recuperacion = redcliente.intentarRecuperarSesion(servidorHost, servidorPuerto);
            if (recuperacion.recuperando) {
                pantalla = recuperacion.enPartida ? "Partida" : "Lobby";
            } else {
                pantalla = "Salas";
                redcliente.refrescarSalas(servidorHost, servidorPuerto);
                redcliente.conectarPresencia(servidorHost, servidorPuerto);
            }
            // Ver el mismo comentario en onRegistroOk.
            redcliente.consultarTienda(servidorHost, servidorPuerto, tokenSesion);
            ventana.pedirDatosDeCuenta();
        }
        function onLoginError(mensaje) {
            mensajeErrorLogin = mensaje;
        }
        // Fase M2 del port de progresión a móvil -- ver el comentario
        // junto a "tiendaCrudo" más arriba.
        function onTiendaActualizada(tienda) {
            tiendaCrudo = tienda;
            reordenarTienda();
        }
        // Fase M2 -- comprar (Tienda), mismo criterio que
        // onObjetoEquipado/onObjetoEquiparError de abajo.
        function onObjetoComprado(codigo) {
            ventana.mensajeTienda = "";
            redcliente.consultarTienda(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion);
        }
        function onObjetoCompraError(mensaje) {
            ventana.mensajeTienda = mensaje;
        }
        // Fase 4 del sistema de progresión -- ya llega parseado
        // (parsearFilasChat() en C++, ver NetworkClient.hpp), un
        // QVariantMap por logro.
        function onLogrosActualizados(logros) {
            var ordenados = ordenarLogros(logros);
            logrosModel.clear();
            for (var i = 0; i < ordenados.length; i++) logrosModel.append(ordenados[i]);
        }
        // Personalizar (Fase M1 del port a móvil) -- refresca loadout Y
        // tienda tras equipar/desequipar, mismo criterio que escritorio.
        function onObjetoEquipado(slot, codigo) {
            ventana.mensajeTienda = "";
            redcliente.consultarLoadout(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion);
            redcliente.consultarTienda(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion);
        }
        function onObjetoEquiparError(mensaje) {
            ventana.mensajeTienda = mensaje;
        }
        function onSesionInvalida(mensaje) {
            // Token caducado/revocado -- se olvida y se deja Inicio tal
            // cual (ya es la pantalla por defecto al arrancar, antes de
            // que esto pueda llegar).
            tokenSesion = "";
        }
        function onLogoutOk() {
            tokenSesion = "";
            nombreJugador = "";
            decisionInicioTomada = false;
            pantalla = "Inicio";
        }
        function onUsernameCambiado(nuevoUsername) {
            nombreJugador = nuevoUsername;
            mensajeErrorLogin = "";
            cajaNuevoUsernameMovil.valor = "";
        }
        function onUsernameError(mensaje) {
            tratarErrorCuenta(mensaje);
        }
        function onPasswordCambiada() {
            mensajeErrorLogin = "";
            cajaPasswordActualMovil.valor = "";
            cajaPasswordNuevaMovil.valor = "";
        }
        function onPasswordError(mensaje) {
            tratarErrorCuenta(mensaje);
        }
        // ── Social ────────────────────────────────────────────────────────
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
        // refresca el resumen para que el último mensaje/badge se pongan
        // al día sin salir y volver a entrar en la pestaña.
        function onMensajeDirectoRecibido(fromAccountId, fromUsername, texto, creadoEn, mensajeId) {
            if (pestanaSocialActual === 0) {
                redcliente.listarResumenChats(servidorHost, servidorPuerto);
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
            salaIdPropia = salaId;
        }
        function onLobbyActualizado(jugadoresCsv, listos, esperados, host, esperadosNombresCsv) {
            jugadoresConectados.clear();
            var nombres = jugadoresCsv.split(",");
            for (var i = 0; i < nombres.length; i++) {
                jugadoresConectados.append({ nombre: nombres[i] });
            }
            textoListos = listos + " / " + esperados + " listos";
            hostActual = host;
            soyHost = (host === nombreJugador);
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
            soyHost = (host === nombreJugador);
        }
        function onEstadoMesaActualizado(ronda, bote, turno, jugadoresStr, timeoutMs,
                                         dealer, sb, bb) {
            rondaActual = ronda;
            boteActual = bote;
            turnoNombre = turno;
            dealerNombre = dealer;
            sbNombre = sb;
            bbNombre = bb;
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
                // campos[4..9]: visibilidad a otros jugadores, parte B
                // (2026-09-01, ver memoria qt_progression_review_2026_09_01,
                // portado el mismo día a móvil) -- loadout completo de
                // cada jugador sentado, no solo partidasGanadas.
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
                if (campos[0] === nombreJugador) {
                    // Mismo bug que en escritorio: miSaldoActual solo se
                    // ponía al día en onEsMiTurno -- si aún no te ha
                    // tocado, se quedaba a 0. Este GAME_STATE llega en
                    // cada turno de cualquiera, así que es el sitio
                    // correcto para mantenerlo al día siempre.
                    miSaldoActual = parseInt(campos[1]);
                    // No hay un evento dedicado de "recompra confirmada" —
                    // se detecta viendo que el propio saldo ya no es 0.
                    if (miSaldoActual > 0) {
                        puedoRecomprar = false;
                        recompraSolicitada = false;
                    }
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
                    jugadoresPartida.setProperty(j, "saldo", String(miSaldo));  // el rol nace texto en el append() (campos[1]) y Asiento lo declara string
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
        function onVotoConfirmado() {
            // Ack real del servidor a votar() -- ver el comentario largo
            // en Main.qml de qml/: el panel ya no se cierra al pulsar
            // "Continuar" de forma optimista, evita el softlock real
            // reportado (showdown abierto sin panel, tras una
            // reconexión fallida).
            votoAbierto = false;
            mensajeVoto = "";
        }
        function onHostCambiado(host) {
            // El host efectivo cambió a mitad de partida -- mismo
            // recálculo que onLobbyActualizado/onPartidaIniciada.
            hostActual = host;
            soyHost = (host === nombreJugador);
        }
        function onEsperandoVotoExtension(mensaje) {
            votoExtensionMensaje = mensaje;
            votoExtensionAbierto = true;
            tuTurno = false;
            turnoNombre = "";
        }
        // FASE 2 (unanimidad conseguida): al host le llega este evento en
        // concreto (unicast) -- muestra el selector de cuántas manos
        // añadir en vez del mensaje genérico de espera.
        function onElegirManosExtraPedido(mensaje) {
            manosExtraMensaje = mensaje;
            soyYoQuienElige = true;
            esperandoManosExtra = true;
        }
        // FASE 2 para el resto (broadcast, incluido el propio host, pero
        // onElegirManosExtraPedido ya puso soyYoQuienElige=true para él).
        function onEsperandoEleccionManos(mensaje, host) {
            manosExtraMensaje = mensaje;
            esperandoManosExtra = true;
        }
        function onPartidaExtendida(manosExtra, nuevoObjetivoManos) {
            esperandoManosExtra = false;
            soyYoQuienElige = false;
            // BUG real encontrado en vivo: "Mano X/Y" se quedaba con el
            // objetivo original tras extender -- ya viene calculado del
            // servidor, no hace falta sumarlo aquí.
            objetivoManos = nuevoObjetivoManos;
        }
        // manosDisputadasFinal/mejorManoFinal/mejorManoJugadorFinal/
        // eliminacionesFinal se leen de redcliente (propiedades, no
        // parámetros de la señal) -- ver el comentario largo en
        // NetworkClient.hpp junto a esas Q_PROPERTY: en el APK de Android
        // real, una señal de 7 parámetros aquí perdía los 4 últimos en
        // silencio (bug visto solo ahí). estadisticasFinCambiaron() se
        // emite justo antes que esta señal, así que las propiedades ya
        // están al día para cuando se leen aquí.
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
            tuTurno = false;
            turnoNombre = "";
            showdownAbierto = false;
            votoAbierto = false;
            votoExtensionAbierto = false;
            esperandoManosExtra = false;
            soyYoQuienElige = false;
            pantalla = "Fin";
            // Modo offline (Torneos > Solitario) -- ver el comentario
            // gemelo en qml/Main.qml (escritorio). Va ANTES de las
            // llamadas de red de abajo (los datos de LocalGameClient ya
            // se leyeron más arriba).
            if (ventana.modoOfflineActivo && !ventana.sesionOffline) {
                modoJuego.activarModoRed();
                ventana.modoOfflineActivo = false;
            }
            if (tokenSesion !== "") redcliente.conectarPresencia(servidorHost, servidorPuerto);
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
            esperandoManosExtra = false;
            soyYoQuienElige = false;
            pantalla = "Fin";
            if (ventana.modoOfflineActivo && !ventana.sesionOffline) {
                modoJuego.activarModoRed();
                ventana.modoOfflineActivo = false;
            }
        }
        function onAbandonaste(mensaje) {
            mensajeErrorConexion = mensaje;
            showdownAbierto = false;
            votoAbierto = false;
            votoExtensionAbierto = false;
            esperandoManosExtra = false;
            soyYoQuienElige = false;
            // Bug real reportado: sin esto, soyHost se quedaba en true
            // para siempre tras abandonar -- ver Main.qml de qml/.
            soyHost = false;
            // Ver el comentario gemelo en qml/Main.qml.
            pantalla = (ventana.sesionOffline && torneosHabilitados) ? "Torneos" : "Salas";
            // Ver el comentario en onFinDePartida -- aquí va ANTES de las
            // llamadas de red porque ninguna lee nada de LocalGameClient primero.
            if (ventana.modoOfflineActivo && !ventana.sesionOffline) {
                modoJuego.activarModoRed();
                ventana.modoOfflineActivo = false;
            }
            redcliente.refrescarSalas(servidorHost, servidorPuerto);
            if (tokenSesion !== "") redcliente.conectarPresencia(servidorHost, servidorPuerto);
        }
        function onError(mensaje) {
            mensajeErrorConexion = "Error: " + mensaje;
        }
        function onConexionComprobada(conectado) {
            comprobandoConexion = false;
            conectadoAlServidor = conectado;
        }
        function onNombreRechazado(mensaje) {
            pantalla = "Inicio";
            mensajeErrorConexion = mensaje;
        }
        function onErrorSala(mensaje) {
            pantalla = "Salas";
            mensajeErrorConexion = mensaje;
            if (tokenSesion !== "") redcliente.conectarPresencia(servidorHost, servidorPuerto);
        }
        function onNombreAsignado(nombre) {
            nombreJugador = nombre;
        }
        function onSalasActualizadas(salasCsv) {
            ventana.refrescandoSalas = false;
            salasDisponibles.clear();
            if (salasCsv.length === 0) { reconstruirSalasAgrupadas(); return; }
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
            reconstruirSalasAgrupadas();
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
                    // accountId antepuesto (Cerrar Social v1) -- abre el
                    // perfil público de cada fila. "elo" es la Fase 3. Los
                    // 7 campos de loadout son el podio de Ranking (Fase
                    // M3 del port a móvil, 2026-09-01) -- mismo formato
                    // exacto que escritorio.
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
            ventana.rankingCrudo = filas;
            ventana.reordenarRanking();
        }
        // redcliente.estadisticasCuenta es una Q_PROPERTY (QVariantMap), no
        // parámetros de la señal -- ver el comentario largo junto a
        // consultarEstadisticas() en NetworkClient.hpp (bug real de Android
        // con señales de muchos parámetros).
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
            ventana.statsManosJugadas = m.manosJugadas;
            ventana.statsManosGanadas = m.manosGanadas;
            ventana.statsPartidasJugadas = m.partidasJugadas;
            ventana.statsPartidasGanadas = m.partidasGanadas;
            ventana.statsTieneMarcoBasico = m.tieneMarcoBasico;
            ventana.statsXpTotal = m.xpTotal;
            ventana.statsVecesGanoSinShowdown = m.vecesGanoSinShowdown;
            ventana.statsRachaManosGanadas = m.rachaManosGanadas;
            ventana.statsRachaActual = m.rachaActual;
            ventana.statsRachaMaxima = m.rachaMaxima;
            ventana.statsMayorBote = m.mayorBote;
            ventana.statsMejorManoNombre = m.mejorManoNombre;
            ventana.statsMejorManoFecha = m.mejorManoFecha;
            ventana.statsVecesCartaAlta = m.vecesCartaAlta;
            ventana.statsVecesPareja = m.vecesPareja;
            ventana.statsVecesDoblePareja = m.vecesDoblePareja;
            ventana.statsVecesTrio = m.vecesTrio;
            ventana.statsVecesEscalera = m.vecesEscalera;
            ventana.statsVecesColor = m.vecesColor;
            ventana.statsVecesFullHouse = m.vecesFullHouse;
            ventana.statsVecesPoker = m.vecesPoker;
            ventana.statsVecesEscaleraColor = m.vecesEscaleraColor;
            ventana.statsVecesEscaleraReal = m.vecesEscaleraReal;
            ventana.statsTreboles = m.treboles;
            ventana.statsEsAdmin = m.esAdmin;
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
            // Mismo motivo que onAbandonaste/onFinDePartida/
            // onPartidaGuardada: sin esto, un showdown/voto que seguía
            // abierto cuando se cayó la conexión se quedaba tapando la
            // pantalla de Inicio para siempre (bug real reportado, parte
            // del softlock de reconexión) -- incluye el arranque en frío
            // (intentarRecuperarSesion) que puede caer aquí sin haber
            // tenido nunca noticia del estado real de la mano.
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

    // Versión instalada, discreta, en la esquina (pendiente 9 de CLAUDE.md,
    // 2026-09-10). Si hay una más nueva lo dice aquí mismo, además del banner.
    Text {
        visible: ventana.pantalla === "Inicio"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12 * Tema.escala
        textFormat: Text.StyledText
        text: "v" + versionChecker.versionActual
              + (versionChecker.hayVersionNueva
                 ? " · <font color=\"" + Tema.colorHex(Tema.colorAccent) + "\">hay una nueva: v"
                   + versionChecker.versionRemota + "</font>"
                 : "")
        color: Tema.colorTextoMuyTenue
        font.pixelSize: 10 * Tema.escala
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
                color: Tema.colorTexto
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
                color: ventana.comprobandoConexion ? Tema.colorTextoTenue
                       : (ventana.conectadoAlServidor ? Tema.colorAccent : Tema.colorPeligro)
            }
            Text {
                color: Tema.colorTextoTenue
                font.pixelSize: 11 * Tema.escala
                text: ventana.comprobandoConexion ? "Comprobando conexión…"
                      : (ventana.conectadoAlServidor ? "Conectado al servidor" : "Sin conexión con el servidor")
            }
        }
        // Ya no hay campo de nombre libre: la identidad viene de una
        // cuenta (login/registro) o de un nombre de invitado generado
        // aquí mismo, sin persistencia. Iniciar sesión/Crear cuenta en la
        // misma fila -- una pantalla landscape corta de alto no sobra
        // espacio para apilar tres botones más el de invitado y salir.
        // Inicio con TRES estados -- ver el comentario gemelo en el
        // Main.qml de escritorio (comprobando / conectado / sin conexión).
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10 * Tema.escala
            visible: ventana.conectadoAlServidor
            BotonRelleno {
                text: "Iniciar sesión"
                radioBorde: 999
                onClicked: {
                    ventana.mensajeErrorLogin = "";
                    ventana.pantalla = "Login";
                }
            }
            BotonContorno {
                text: "Crear cuenta"
                radioBorde: 999
                onClicked: {
                    ventana.mensajeErrorLogin = "";
                    ventana.pantalla = "Registro";
                }
            }
        }
        BotonContorno {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Entrar como invitado"
            radioBorde: 999
            visible: ventana.conectadoAlServidor
            onClicked: {
                // tokenSesion se limpia explícitamente aquí, no se asume
                // vacío: puede quedar relleno por una sesión guardada de
                // antes, o por una reautenticación silenciosa todavía en
                // vuelo (ver decisionInicioTomada más arriba) -- sin esto,
                // conectar()/crearSala()/etc. podían mandar un token real
                // aun "jugando de invitado".
                ventana.decisionInicioTomada = true;
                ventana.tokenSesion = "";
                ventana.nombreJugador = "Invitado" + Math.floor(Math.random() * 100000);
                ventana.mensajeErrorConexion = "";
                ventana.pantalla = "Salas";
                redcliente.refrescarSalas(ventana.servidorHost, ventana.servidorPuerto);
            }
        }

        // ── Sin conexión: jugar en local ──────────────────────────────────
        // Ver el comentario gemelo en el Main.qml de escritorio.
        BotonRelleno {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Jugar sin conexión"
            radioBorde: 999
            visible: !ventana.conectadoAlServidor && !ventana.comprobandoConexion
                     && modoJuego.hayIdentidadCacheada
            onClicked: ventana.entrarSinConexion(true)
        }
        BotonContorno {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Jugar como invitado"
            radioBorde: 999
            visible: !ventana.conectadoAlServidor && !ventana.comprobandoConexion
            onClicked: ventana.entrarSinConexion(false)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !ventana.conectadoAlServidor && !ventana.comprobandoConexion
                     && modoJuego.hayIdentidadCacheada
            color: Tema.colorTextoTenue
            font.pixelSize: 11 * Tema.escala
            text: "Como " + modoJuego.usernameCacheado + " · sin Tréboles ni Elo"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 260 * Tema.escala
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: !ventana.conectadoAlServidor && !ventana.comprobandoConexion
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

    // ── Pantalla Login ───────────────────────────────────────────────────
    BarraSuperior {
        id: barraLoginMovil
        visible: ventana.pantalla === "Login"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        textoCentro: "Iniciar sesión"
        onAbrirAjustes: ventana.ajustesAbiertos = !ventana.ajustesAbiertos
    }
    // Área bajo la barra -- el Column de campos se centra AQUÍ, no en toda
    // la ventana. Con anchors.centerIn: parent (versión anterior) el campo
    // Usuario quedaba tapado por la barra en pantallas reales de poca
    // altura (landscape de un móvil): el escritorio nunca lo mostraba
    // porque su ventana de prueba es mucho más alta que un teléfono real.
    Item {
        id: areaContenidoLogin
        visible: ventana.pantalla === "Login"
        anchors.top: barraLoginMovil.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }
    Column {
        visible: ventana.pantalla === "Login"
        anchors.centerIn: areaContenidoLogin
        spacing: 12 * Tema.escala
        width: Math.min(280 * Tema.escala, ventana.width - 60 * Tema.escala)

        // Campos "de mentira" -- mismo patrón que "Nombre de la sala" en
        // CrearSala, cada uno con su propio CampoEmergente embebido.
        MarcoHueco {
            id: cajaUsuarioLogin
            width: parent.width
            height: Math.max(Tema.tamanoMinTactil, 54 * Tema.escala)
            radius: 10 * Tema.escala
            activo: areaUsuarioLogin.pressed
            property string valor: ""
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10 * Tema.escala
                anchors.verticalCenter: parent.verticalCenter
                text: cajaUsuarioLogin.valor !== "" ? cajaUsuarioLogin.valor : "Usuario"
                color: cajaUsuarioLogin.valor !== "" ? Tema.colorTexto : Tema.colorTextoMuyTenue
                font.pixelSize: 14 * Tema.escala
            }
            MouseArea {
                id: areaUsuarioLogin
                anchors.fill: parent
                onClicked: campoUsuarioLogin.abrir(cajaUsuarioLogin.valor)
            }
            CampoEmergente {
                id: campoUsuarioLogin
                parent: Overlay.overlay
                etiqueta: "Usuario"
                onAceptado: (texto) => cajaUsuarioLogin.valor = texto
            }
        }
        MarcoHueco {
            id: cajaPasswordLogin
            width: parent.width
            height: Math.max(Tema.tamanoMinTactil, 54 * Tema.escala)
            radius: 10 * Tema.escala
            activo: areaPasswordLogin.pressed
            property string valor: ""
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10 * Tema.escala
                anchors.verticalCenter: parent.verticalCenter
                // Nunca el texto real ni su longitud real -- un número fijo
                // de puntos, solo para confirmar visualmente que hay algo
                // escrito (ver el mismo criterio en la sección Cuenta del
                // cajón de ajustes, más abajo).
                text: cajaPasswordLogin.valor !== "" ? "••••••••" : "Contraseña"
                color: cajaPasswordLogin.valor !== "" ? Tema.colorTexto : Tema.colorTextoMuyTenue
                font.pixelSize: 14 * Tema.escala
            }
            MouseArea {
                id: areaPasswordLogin
                anchors.fill: parent
                onClicked: campoPasswordLogin.abrir(cajaPasswordLogin.valor)
            }
            CampoEmergente {
                id: campoPasswordLogin
                parent: Overlay.overlay
                etiqueta: "Contraseña"
                esPassword: true
                onAceptado: (texto) => cajaPasswordLogin.valor = texto
            }
        }
        BotonRelleno {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Entrar"
            radioBorde: 999
            // Siempre pulsable -- un botón atenuado y mudo no distingue
            // "te falta algo" de "esto está roto" (ver el mismo criterio
            // en el Main.qml de escritorio).
            onClicked: {
                if (cajaUsuarioLogin.valor.length === 0) {
                    ventana.mensajeErrorLogin = "Escribe tu nombre de usuario.";
                    return;
                }
                if (cajaPasswordLogin.valor.length === 0) {
                    ventana.mensajeErrorLogin = "Escribe tu contraseña.";
                    return;
                }
                ventana.mensajeErrorLogin = "";
                redcliente.iniciarSesion(ventana.servidorHost, ventana.servidorPuerto,
                                         cajaUsuarioLogin.valor, cajaPasswordLogin.valor);
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "¿No tienes cuenta? Crear una"
            color: Tema.colorAccent
            font.pixelSize: 12 * Tema.escala
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    ventana.mensajeErrorLogin = "";
                    cajaPasswordLogin.valor = "";
                    ventana.pantalla = "Registro";
                }
            }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Tema.colorPeligro
            font.pixelSize: 11 * Tema.escala
            text: ventana.mensajeErrorLogin
            visible: ventana.mensajeErrorLogin !== ""
        }
        BotonContorno {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Volver"
            radioBorde: 999
            onClicked: {
                cajaPasswordLogin.valor = "";
                ventana.pantalla = "Inicio";
            }
        }
    }

    // ── Pantalla Registro ────────────────────────────────────────────────
    BarraSuperior {
        id: barraRegistroMovil
        visible: ventana.pantalla === "Registro"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        textoCentro: "Crear cuenta"
        onAbrirAjustes: ventana.ajustesAbiertos = !ventana.ajustesAbiertos
    }
    // Mismo motivo que areaContenidoLogin más arriba: Registro tiene aún
    // más campos, así que se solaparía incluso peor con centerIn: parent.
    Item {
        id: areaContenidoRegistro
        visible: ventana.pantalla === "Registro"
        anchors.top: barraRegistroMovil.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }
    Column {
        visible: ventana.pantalla === "Registro"
        anchors.centerIn: areaContenidoRegistro
        spacing: 12 * Tema.escala
        width: Math.min(280 * Tema.escala, ventana.width - 60 * Tema.escala)

        MarcoHueco {
            id: cajaUsuarioRegistro
            width: parent.width
            height: Math.max(Tema.tamanoMinTactil, 54 * Tema.escala)
            radius: 10 * Tema.escala
            activo: areaUsuarioRegistro.pressed
            property string valor: ""
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10 * Tema.escala
                anchors.verticalCenter: parent.verticalCenter
                text: cajaUsuarioRegistro.valor !== "" ? cajaUsuarioRegistro.valor : "Usuario (mín. 3 caracteres)"
                color: cajaUsuarioRegistro.valor !== "" ? Tema.colorTexto : Tema.colorTextoMuyTenue
                font.pixelSize: 13 * Tema.escala
                elide: Text.ElideRight
                width: parent.width - 20 * Tema.escala
            }
            MouseArea {
                id: areaUsuarioRegistro
                anchors.fill: parent
                onClicked: campoUsuarioRegistro.abrir(cajaUsuarioRegistro.valor)
            }
            CampoEmergente {
                id: campoUsuarioRegistro
                parent: Overlay.overlay
                etiqueta: "Usuario"
                onAceptado: (texto) => cajaUsuarioRegistro.valor = texto
            }
        }
        MarcoHueco {
            id: cajaPasswordRegistro
            width: parent.width
            height: Math.max(Tema.tamanoMinTactil, 54 * Tema.escala)
            radius: 10 * Tema.escala
            activo: areaPasswordRegistro.pressed
            property string valor: ""
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10 * Tema.escala
                anchors.verticalCenter: parent.verticalCenter
                text: cajaPasswordRegistro.valor !== "" ? "••••••••" : "Contraseña (8+ caracteres)"
                color: cajaPasswordRegistro.valor !== "" ? Tema.colorTexto : Tema.colorTextoMuyTenue
                font.pixelSize: 13 * Tema.escala
            }
            MouseArea {
                id: areaPasswordRegistro
                anchors.fill: parent
                onClicked: campoPasswordRegistro.abrir(cajaPasswordRegistro.valor)
            }
            CampoEmergente {
                id: campoPasswordRegistro
                parent: Overlay.overlay
                etiqueta: "Contraseña"
                esPassword: true
                onAceptado: (texto) => cajaPasswordRegistro.valor = texto
            }
        }
        MarcoHueco {
            id: cajaPasswordRegistroConfirmar
            width: parent.width
            height: Math.max(Tema.tamanoMinTactil, 54 * Tema.escala)
            radius: 10 * Tema.escala
            activo: areaPasswordRegistroConfirmar.pressed
            property string valor: ""
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10 * Tema.escala
                anchors.verticalCenter: parent.verticalCenter
                text: cajaPasswordRegistroConfirmar.valor !== "" ? "••••••••" : "Repite la contraseña"
                color: cajaPasswordRegistroConfirmar.valor !== "" ? Tema.colorTexto : Tema.colorTextoMuyTenue
                font.pixelSize: 13 * Tema.escala
            }
            MouseArea {
                id: areaPasswordRegistroConfirmar
                anchors.fill: parent
                onClicked: campoPasswordRegistroConfirmar.abrir(cajaPasswordRegistroConfirmar.valor)
            }
            CampoEmergente {
                id: campoPasswordRegistroConfirmar
                parent: Overlay.overlay
                etiqueta: "Repite la contraseña"
                esPassword: true
                onAceptado: (texto) => cajaPasswordRegistroConfirmar.valor = texto
            }
        }
        BotonRelleno {
            id: botonCrearCuentaMovil
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Crear cuenta"
            radioBorde: 999
            // Siempre pulsable -- las mismas reglas mínimas que ya exige
            // el servidor (username >= 3, password >= 8, ver
            // AccountManager, la única autoridad real) se repiten aquí
            // solo para dar el mensaje al instante, no para silenciar el
            // botón: uno atenuado y mudo no distingue "te falta algo" de
            // "esto está roto" (mismo criterio que en escritorio).
            onClicked: {
                if (cajaUsuarioRegistro.valor.length < 3) {
                    ventana.mensajeErrorLogin = "El nombre de usuario debe tener al menos 3 caracteres.";
                    return;
                }
                if (cajaPasswordRegistro.valor.length < 8) {
                    ventana.mensajeErrorLogin = "La contraseña debe tener al menos 8 caracteres.";
                    return;
                }
                if (cajaPasswordRegistro.valor !== cajaPasswordRegistroConfirmar.valor) {
                    ventana.mensajeErrorLogin = "Las contraseñas no coinciden.";
                    return;
                }
                ventana.mensajeErrorLogin = "";
                redcliente.registrar(ventana.servidorHost, ventana.servidorPuerto,
                                     cajaUsuarioRegistro.valor, cajaPasswordRegistro.valor);
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "¿Ya tienes cuenta? Iniciar sesión"
            color: Tema.colorAccent
            font.pixelSize: 12 * Tema.escala
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    ventana.mensajeErrorLogin = "";
                    ventana.pantalla = "Login";
                }
            }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Tema.colorPeligro
            font.pixelSize: 11 * Tema.escala
            text: ventana.mensajeErrorLogin
            visible: ventana.mensajeErrorLogin !== ""
        }
        BotonContorno {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Volver"
            radioBorde: 999
            onClicked: {
                cajaPasswordRegistro.valor = "";
                cajaPasswordRegistroConfirmar.valor = "";
                ventana.pantalla = "Inicio";
            }
        }
    }

    // ── Riel de navegación (Salas/Ranking/Torneos/Social) ──────────────────
    // Instancia única, visible solo en las 4 pantallas "hub" -- ver
    // RielNavegacion.qml. Las demás pantallas (Inicio/Login/Registro/
    // CrearSala/Lobby/Partida/Fin) no lo llevan.
    RielNavegacion {
        id: rielNavegacionMovil
        visible: ["Salas", "Ranking", "Torneos", "Social", "Tienda", "Cuenta"].indexOf(ventana.pantalla) !== -1
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        pantallaActual: ventana.pantalla
        modoOffline: ventana.sesionOffline
        onSeccionElegida: (nombre) => {
            ventana.pantalla = nombre;
            // Ver el comentario gemelo en qml/Main.qml.
            if (nombre === "Salas" && ventana.sesionOffline) {
                ventana.viendoGuardadas = true;
                ventana.viendoPrivada = false;
                redcliente.listarGuardadas(ventana.servidorHost, ventana.servidorPuerto);
            }
            if (nombre === "Ranking") {
                // Elo por defecto al entrar (Fase M3 del port a móvil,
                // 2026-09-01) -- mismo criterio que escritorio: mide
                // habilidad, no dedicación, así que es la que de verdad
                // importa, no la primera pestaña de la lista.
                ventana.ordenRankingActual = 2;
                redcliente.consultarRanking(ventana.servidorHost, ventana.servidorPuerto);
                // Bug real reportado 2026-09-02: al reentrar en Ranking
                // (tras haber bajado en la lista la vez anterior), el
                // ListView conservaba el scroll a medias -- el 4º puesto
                // quedaba pegado arriba y había que subir a mano para ver
                // el podio. El Item de la pantalla nunca se destruye
                // (solo cambia "visible"), así que contentY sobrevivía
                // entre visitas -- se reinicia a mano al entrar. El reset
                // real (el que importa, tras la respuesta del servidor)
                // vive en reordenarRanking() -- este de aquí solo cubre
                // el instante de reentrar con datos ya cargados de antes.
                // anclarArriba=true reactiva el "pin" de contentY=0 (ver
                // el comentario grande junto a listaRankingMovil) para
                // esta visita nueva a la pantalla.
                listaRankingMovil.anclarArriba = true;
                Qt.callLater(() => { listaRankingMovil.contentY = 0; });
            }
            if (nombre === "Social" && ventana.tokenSesion !== "") {
                ventana.pestanaSocialActual = 0;
                ventana.mensajeErrorSocial = "";
                redcliente.listarAmigos(ventana.servidorHost, ventana.servidorPuerto);
            }
            if (nombre === "Cuenta") {
                // Fase M1 del port de progresión a móvil (2026-09-01, ver
                // memoria qt_mobile_progression_port_plan) -- mismo
                // criterio de reset-al-reentrar que Social en escritorio:
                // siempre Perfil, no lo que se hubiera dejado a medias.
                ventana.pestanaCuentaActual = 0;
                ventana.mensajeErrorLogin = "";
                if (ventana.tokenSesion !== "") {
                    redcliente.consultarEstadisticas(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion);
                    redcliente.consultarTienda(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion);
                    redcliente.consultarLoadout(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion);
                    redcliente.consultarLogros(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion);
                }
            }
            if (nombre === "Tienda") {
                // Fase M2 del port de progresión a móvil (2026-09-01, ver
                // memoria qt_mobile_progression_port_plan) -- mismo
                // criterio de reset-al-reentrar, port directo del bloque
                // gemelo de escritorio.
                ventana.pestanaTiendaActual = 0;
                ventana.mensajeTienda = "";
                ventana.busquedaTienda = "";
                if (ventana.tokenSesion !== "") {
                    redcliente.consultarEstadisticas(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion);
                    redcliente.consultarTienda(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion);
                    redcliente.consultarLoadout(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion);
                }
            }
        }
    }

    // ── Pantalla Salas ───────────────────────────────────────────────────
    BarraSuperior {
        id: barraSalasMovil
        visible: ventana.pantalla === "Salas"
        anchors.top: parent.top
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        textoCentro: ventana.sesionOffline ? "Partida local" : "Salas disponibles"
        onAbrirAjustes: ventana.ajustesAbiertos = !ventana.ajustesAbiertos
    }

    // Antes vivía dentro de un Column envolvente y las dos Rectangle de
    // abajo (aviso de error / caja de salas) anclaban a "filaTabsSalasMovil.bottom"
    // desde FUERA de ese Column -- Qt Quick solo permite anclar a un padre o
    // a un hermano directo, nunca a un nieto de un hermano, así que ese
    // anclaje quedaba indefinido y las dos Rectangle colapsaban arriba del
    // todo, tapando la barra superior y esta misma fila (confirmado con una
    // captura real). Ahora esta fila es hermana directa de esas dos
    // Rectangle -- mismo padre, anclaje válido -- y ya no hace falta el
    // Column (un único hijo no necesitaba layout).
    Row {
        id: filaTabsSalasMovil
        visible: ventana.pantalla === "Salas"
        anchors.horizontalCenter: parent.horizontalCenter
        // El riel de navegación le come ancho por la izquierda -- sin
        // este desplazamiento, "centrado en parent" quedaría descentrado
        // respecto al hueco real disponible (mismo motivo que en el
        // Column de Salas de escritorio, ver Main.qml de qml/).
        anchors.horizontalCenterOffset: rielNavegacionMovil.width / 2
        anchors.top: barraSalasMovil.bottom
        anchors.topMargin: 22 * Tema.escala
        // Mismo ancho que la caja de salas/guardadas de debajo (ver
        // cajaSalasMovil más abajo) -- antes esta fila solo se centraba por
        // el ancho implícito de sus hijos (SelectorPildoras se ajustaba al
        // texto); SelectorSegmentado necesita un ancho explícito, ver el
        // comentario largo en Main.qml de qml/ (mismo cambio ahí).
        width: Math.min(560 * Tema.escala, ventana.width - 60 * Tema.escala)
        spacing: 10 * Tema.escala
        SelectorSegmentado {
            id: tabsSalas
            // Ver el comentario gemelo en qml/Main.qml: offline solo existe
            // "Partidas guardadas", así que el selector sobra.
            visible: !ventana.sesionOffline
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - botonCrearSalaMovil.width - parent.spacing
            opciones: ["Salas públicas", "Partidas guardadas", "Sala privada"]
            onElegido: (indice) => {
                seleccionado = indice;
                ventana.viendoGuardadas = indice === 1;
                ventana.viendoPrivada = indice === 2;
                if (ventana.viendoGuardadas)
                    redcliente.listarGuardadas(ventana.servidorHost, ventana.servidorPuerto);
            }
        }
        BotonContorno {
            id: botonCrearSalaMovil
            anchors.verticalCenter: parent.verticalCenter
            // "Crear sala nueva" se comía la barra en pantallas landscape
            // compactas (rediseño 2026-08-28, ver el mockup) -- acortado a
            // "+ Sala", el segmentado ya deja claro el contexto ("Salas").
            text: ventana.sesionOffline ? "+ Partida" : "+ Sala"
            onClicked: {
                ventana.mensajeErrorConexion = "";
                ventana.pantalla = "CrearSala";
            }
        }
    }

    // Aviso de error -- hermano directo de filaTabsSalasMovil (no anidado
    // en ella ni en ningún Column). La caja de salas de abajo ancla su
    // borde superior AQUÍ cuando está visible (en vez de a
    // filaTabsSalasMovil directamente) para que las dos nunca se solapen:
    // sin error, la caja sube a su sitio de siempre; con error, baja lo
    // justo para dejarle hueco. Antes flotaba encima de la caja (tapándola
    // un poco a propósito) -- el usuario prefiere que nunca se solapen.
    Rectangle {
        id: avisoErrorSalasMovil
        visible: ventana.mensajeErrorConexion !== "" && ventana.pantalla === "Salas"
        anchors.top: filaTabsSalasMovil.bottom
        anchors.topMargin: 10 * Tema.escala
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: rielNavegacionMovil.width / 2
        width: Math.min(560 * Tema.escala, ventana.width - 60 * Tema.escala)
        height: textoErrorSalasMovil.implicitHeight + 12 * Tema.escala
        radius: 6 * Tema.escala
        color: Qt.rgba(0, 0, 0, 0.6)
        border.width: 1
        border.color: Tema.colorPeligro

        Text {
            id: textoErrorSalasMovil
            anchors.centerIn: parent
            width: parent.width - 16 * Tema.escala
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Tema.colorPeligro
            font.pixelSize: 11 * Tema.escala
            text: ventana.mensajeErrorConexion
        }
    }

    // Caja de salas/guardadas -- hermana directa de filaTabsSalasMovil (no
    // anidada dentro de ella ni de ningún Column). Ancla su borde superior
    // al aviso de arriba SOLO si está visible -- ver el comentario largo
    // ahí para el porqué del anclaje condicional.
    Rectangle {
        visible: ventana.pantalla === "Salas"
        anchors.top: avisoErrorSalasMovil.visible ? avisoErrorSalasMovil.bottom : filaTabsSalasMovil.bottom
        anchors.topMargin: avisoErrorSalasMovil.visible ? 10 * Tema.escala : 12 * Tema.escala
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: rielNavegacionMovil.width / 2
        width: Math.min(560 * Tema.escala, ventana.width - 60 * Tema.escala)
        // Un poco más alta que antes (220 -> 248) -- las tarjetas nuevas
        // necesitan algo más de aire que las filas finas de antes, pero
        // sigue acotada: el alto es el recurso escaso en landscape corto
        // (ver el comentario del riel), así que 3+ salas que no quepan
        // hacen scroll dentro de la caja, no la agrandan sin límite.
        height: 248 * Tema.escala
        radius: 10 * Tema.escala
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.35)
        // LISO, sin degradado ni textura de tapete (2026-09-09, pedido
        // explícito). Es el caso de la regla general: esta caja es el
        // FONDO sobre el que van las tarjetas de sala, y esas sí llevan su
        // fieltro (ver tarjetaSalaMovilVisual). Fieltro sobre fieltro no
        // deja que las tarjetas destaquen.
        color: Tema.colorPanel

            Text {
                anchors.centerIn: parent
                width: parent.width - 40 * Tema.escala
                visible: !ventana.viendoGuardadas && !ventana.viendoPrivada && listaSalasMovil.count === 0
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

            // Tarjetas en filas de 3 (rediseño 2026-08-28, ver el mockup
            // aprobado), pero sobre un ListView de FILAS (cada delegate es
            // una fila con hasta 3 tarjetas dentro, vía Repeater), NO un
            // GridView -- GridView complicaba la rejilla sin necesidad real
            // (Row+Repeater ya da 3 por fila) y además impide el header
            // nativo del scroll -- ver el motivo real del bug de abajo
            // (no era cosa de GridView en sí, la misma rotura reapareció en
            // Guardadas -- que SIEMPRE fue ListView -- en cuanto llevaba el
            // mismo envoltorio). CabeceraPullRefrescar necesita ser el
            // header DIRECTO, sin envolver en un Column con nada más al
            // lado (ver el comentario largo junto al header de Guardadas):
            // su altura depende de contentY y da por hecho una altura de
            // reposo EXACTAMENTE 0 -- cualquier otro hijo con altura fija
            // en el mismo Column rompe esa invariante y el header se
            // realimenta con la propia reposición de contentY (bug real,
            // reportado dos veces: 2026-08-28). salasAgrupadasMovil se
            // reconstruye junto con salasDisponibles, ver onSalasActualizadas.
            ListView {
                id: listaSalasMovil
                visible: !ventana.viendoGuardadas && !ventana.viendoPrivada
                anchors.fill: parent
                anchors.margins: 10 * Tema.escala
                clip: true
                spacing: 8 * Tema.escala
                model: salasAgrupadasMovil
                header: CabeceraPullRefrescar {
                    vista: listaSalasMovil
                    refrescando: ventana.refrescandoSalas
                    onRefrescar: {
                        ventana.refrescandoSalas = true;
                        redcliente.refrescarSalas(ventana.servidorHost, ventana.servidorPuerto);
                    }
                }
                delegate: Row {
                    id: filaDeSalasMovil
                    required property var salas
                    width: ListView.view.width
                    spacing: 8 * Tema.escala
                    // Sin botón "Unirse" aparte -- la tarjeta entera es el
                    // objetivo táctil (de sobra por encima de
                    // Tema.tamanoMinTactil), atenuada y sin toque si la
                    // sala ya está llena.
                    Repeater {
                        model: filaDeSalasMovil.salas
                        delegate: Item {
                            id: tarjetaSalaMovil
                            required property var modelData
                            width: (filaDeSalasMovil.width - 2 * filaDeSalasMovil.spacing) / 3
                            height: 78 * Tema.escala
                            opacity: tarjetaSalaMovil.modelData.conectados < tarjetaSalaMovil.modelData.esperados ? 1.0 : 0.55

                            // "Ficha de casino" (2026-09-02, pedido
                            // explícito: "aplicar el mismo estilo a los
                            // amigos y salas") -- sombra desplazada
                            // barata, SIN escalar. Item envolvente nuevo
                            // (antes tarjetaSalaMovil era el Rectangle
                            // raíz) solo para poder meter esto detrás.
                            Rectangle {
                                anchors.fill: parent
                                anchors.topMargin: 3 * Tema.escala
                                radius: 8 * Tema.escala
                                color: "black"
                                opacity: 0.35
                            }

                            Rectangle {
                                id: tarjetaSalaMovilVisual
                                anchors.fill: parent
                                radius: 8 * Tema.escala
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
                                    fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
                                }
                                scale: areaUnirseSalaMovil.pressed ? 0.97 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                // Hilo dorado por dentro del bisel exterior
                                // -- el "doble bisel" de ficha de casino.
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2 * Tema.escala
                                    radius: parent.radius - 2 * Tema.escala
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.18)
                                }

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 8 * Tema.escala
                                spacing: 4 * Tema.escala
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: tarjetaSalaMovil.modelData.nombre !== "" ? tarjetaSalaMovil.modelData.nombre : tarjetaSalaMovil.modelData.id
                                    color: Tema.colorTexto
                                    font.bold: true
                                    font.pixelSize: 12 * Tema.escala
                                }
                                Row {
                                    width: parent.width
                                    spacing: 6 * Tema.escala
                                    Rectangle {
                                        id: pistaOcupacionMovil
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - textoOcupacionMovil.width - parent.spacing
                                        height: 4 * Tema.escala
                                        radius: height / 2
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                        Rectangle {
                                            width: pistaOcupacionMovil.width * (tarjetaSalaMovil.modelData.esperados > 0
                                                       ? Math.min(1.0, tarjetaSalaMovil.modelData.conectados / tarjetaSalaMovil.modelData.esperados) : 0)
                                            height: parent.height
                                            radius: height / 2
                                            color: Tema.colorAccent
                                        }
                                    }
                                    Text {
                                        id: textoOcupacionMovil
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tarjetaSalaMovil.modelData.conectados + "/" + tarjetaSalaMovil.modelData.esperados
                                        color: Tema.colorTextoTenue
                                        font.pixelSize: 9 * Tema.escala
                                    }
                                }
                            }
                            MouseArea {
                                id: areaUnirseSalaMovil
                                anchors.fill: parent
                                enabled: tarjetaSalaMovil.modelData.conectados < tarjetaSalaMovil.modelData.esperados
                                onClicked: ventana.unirse(tarjetaSalaMovil.modelData.id, "")
                            }
                            }
                        }
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
                // SIN envolver en un Column con una pista de texto al lado
                // -- eso le daba al header una altura de reposo != 0 (antes
                // era EXACTAMENTE 0 sin arrastrar), y esa invariante es de
                // lo que depende CabeceraPullRefrescar para no
                // realimentarse con la propia reposición de contentY al
                // animar su cierre -- mismo bug que en Salas, reportado de
                // nuevo aquí 2026-08-28 (la causa real nunca fue GridView
                // en sí, sino este envoltorio, que Salas ya perdió al
                // reestructurarse en filas).
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
                    // Manda el BOTÓN y la fila crece a su alrededor, no al
                    // revés: si la fila fijara el alto y el botón se metiera
                    // dentro, con Tema.escala > 1 el botón bajaría del suelo
                    // táctil de 44px. Los 16 de sobra son la holgura que
                    // impide que el canto del botón se confunda con el de la
                    // tarjeta (ver filaAccionesGuardadaMovil).
                    readonly property real altoBotonFila: Math.max(Tema.tamanoMinTactil,
                                                                   34 * Tema.escala)
                    height: altoBotonFila + 16 * Tema.escala
                    radius: 8 * Tema.escala
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
                        fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
                    }

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
                            color: Tema.colorTexto
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
                    // Los tres botones con alto EXPLÍCITO, metido respecto del
                    // de la fila (2026-09-09). Antes cogían su alto
                    // implícito, que con Tema.escala > 1 crecía hasta
                    // coincidir exactamente con el de la tarjeta: sus
                    // bordes de arriba y abajo caían justo sobre el canto
                    // de la tarjeta y el botón se leía como dos rayas
                    // verticales sueltas a los lados del texto (bug real
                    // reportado con capturas: "los botones en las filas de
                    // guardados se ven extraños").
                    Row {
                        id: filaAccionesGuardadaMovil
                        readonly property real altoBoton: filaGuardadaMovil.altoBotonFila
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 10 * Tema.escala
                        spacing: 6 * Tema.escala
                        BotonRelleno {
                            anchors.verticalCenter: parent.verticalCenter
                            height: filaAccionesGuardadaMovil.altoBoton
                            text: "Reanudar"
                            onClicked: ventana.reanudar(filaGuardadaMovil.archivo)
                        }
                        BotonContorno {
                            anchors.verticalCenter: parent.verticalCenter
                            height: filaAccionesGuardadaMovil.altoBoton
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
                            height: filaAccionesGuardadaMovil.altoBoton
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

            // Pestaña "Sala privada" -- campo "de mentira" que abre
            // CampoEmergente (mismo patrón que el nombre de sala en
            // CrearSala) más un botón "Unirse", en vez de la lista de
            // salas/guardadas. Vive en la misma caja para no tener que
            // duplicar tamaño/posición -- solo cambia qué contenido enseña.
            Column {
                anchors.centerIn: parent
                visible: ventana.viendoPrivada
                spacing: 14 * Tema.escala
                width: parent.width - 60 * Tema.escala

                MarcoHueco {
                    id: cajaCodigoPrivadoMovil
                    width: parent.width
                    height: Math.max(Tema.tamanoMinTactil, 54 * Tema.escala)
                    radius: 10 * Tema.escala
                    activo: areaCodigoPrivado.pressed
                    property string valor: ""
                    Text {
                        anchors.centerIn: parent
                        text: cajaCodigoPrivadoMovil.valor !== "" ? cajaCodigoPrivadoMovil.valor : "Código de sala privada"
                        color: cajaCodigoPrivadoMovil.valor !== "" ? Tema.colorTexto : Tema.colorTextoMuyTenue
                        font.pixelSize: 14 * Tema.escala
                    }
                    MouseArea {
                        id: areaCodigoPrivado
                        anchors.fill: parent
                        onClicked: campoCodigoPrivadoMovil.abrir(cajaCodigoPrivadoMovil.valor)
                    }
                    CampoEmergente {
                        id: campoCodigoPrivadoMovil
                        parent: Overlay.overlay
                        etiqueta: "Código de sala privada"
                        maxLongitud: 6
                        onAceptado: (texto) => cajaCodigoPrivadoMovil.valor = texto.toUpperCase()
                    }
                }
                BotonRelleno {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Unirse"
                    enabled: cajaCodigoPrivadoMovil.valor !== ""
                    opacity: enabled ? 1.0 : 0.5
                    onClicked: ventana.unirse("", cajaCodigoPrivadoMovil.valor)
                }
            }
        }

    // ── Pantalla Ranking: ranking global de verdad (ver AccountManager::
    // obtenerRanking() en el servidor -- solo cuentas con ≥10 partidas
    // jugadas). Torneos/Social sí siguen siendo placeholder, ver más abajo.
    BarraSuperior {
        id: barraRankingMovil
        visible: ventana.pantalla === "Ranking"
        anchors.top: parent.top
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        textoCentro: "Ranking global"
        onAbrirAjustes: ventana.ajustesAbiertos = !ventana.ajustesAbiertos
    }
    // Selector + botón de info FIJOS, fuera del área que scrollea --
    // mismo criterio que cabeceraCuenta/cabeceraTienda ("el selector de
    // pestaña arriba tiene que quedarse, el contenido baja"). Sin el
    // aviso textual de arriba (pedido explícito 2026-09-02: "quitar el
    // aviso textual de arriba y recolocar el boton de informacion, asi
    // subimos el slider y ganamos altura") -- el botón "i" vuelve a
    // vivir junto al propio selector, mismo sitio de antes de la Fase M3.
    Row {
        id: cabeceraRankingMovil
        visible: ventana.pantalla === "Ranking"
        anchors.top: barraRankingMovil.bottom
        anchors.topMargin: 12 * Tema.escala
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        spacing: 10 * Tema.escala

        SelectorSegmentado {
            id: tabsRankingMovil
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - iconoInfoRankingMovil.width - parent.spacing
            opciones: ["Más victorias", "Mejor ratio", "Elo"]
            seleccionado: ventana.ordenRankingActual
            onElegido: (indice) => {
                ventana.ordenRankingActual = indice;
                ventana.reordenarRanking();
            }
        }
        // Desplegable flotante: qué hace que una partida "cuente" no es
        // obvio a simple vista (umbral antifarm, ver popupInfoRankingMovil
        // más abajo) -- mismo motivo que en escritorio.
        Rectangle {
            id: iconoInfoRankingMovil
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(22 * Tema.escala, Tema.tamanoMinTactil * 0.5)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1.2
            border.color: Tema.colorTextoMuyTenue
            Text {
                anchors.centerIn: parent
                text: "i"
                font.italic: true
                font.bold: true
                font.pixelSize: 12 * Tema.escala
                color: Tema.colorTextoMuyTenue
            }
            MouseArea {
                anchors.fill: parent
                onClicked: popupInfoRankingMovil.open()
            }
        }
    }

    Popup {
        id: popupInfoRankingMovil
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(340 * Tema.escala, (parent ? parent.width : 340) - 40 * Tema.escala)
        padding: 18 * Tema.escala

        background: Rectangle {
            color: Tema.colorPanel
            radius: 12 * Tema.escala
            border.width: 1
            border.color: Tema.colorAccent
        }

        contentItem: Column {
            spacing: 10 * Tema.escala
            Text {
                width: parent.width
                text: "¿Cuándo cuenta una partida?"
                color: Tema.colorTexto
                font.family: Tema.fuenteElegante
                font.bold: true
                font.pixelSize: 14 * Tema.escala
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: "Para las estadísticas personales (manos y partidas jugadas/ganadas, racha, mayor bote) hacen falta al menos 2 cuentas reales en la mesa y al menos 5 manos jugadas. Jugar en solitario contra bots no cuenta nunca, sea cual sea la duración."
                color: Tema.colorTextoTenue
                font.pixelSize: 11 * Tema.escala
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: "Las combinaciones mostradas en un showdown (mejor mano, contador por tipo) sí cuentan siempre, sin ese requisito."
                color: Tema.colorTextoTenue
                font.pixelSize: 11 * Tema.escala
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: "Para aparecer en este ranking hace falta además al menos 5 partidas jugadas de las que sí cuentan."
                color: Tema.colorTextoTenue
                font.pixelSize: 11 * Tema.escala
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: "Elo (pestaña por defecto) mide habilidad, no dedicación: +10 al ganar una partida oficial, −3 al perderla, sin ajustar por el nivel del rival. \"Más victorias\" y \"ratio\" son históricos y nunca se resetean; Elo sí -- se reinicia con cada temporada nueva."
                color: Tema.colorTextoTenue
                font.pixelSize: 11 * Tema.escala
                wrapMode: Text.WordWrap
            }
        }
    }
    // Podio + lista, TODO scrolleable como un único conjunto -- mismo
    // criterio ya fijado en escritorio (2026-09-01, "que sea scrolleable
    // en su conjunto"). El panel no tiene altura fija, llena el resto de
    // la pantalla bajo cabeceraRankingMovil; el podio vive en
    // ListView.header, así que se desplaza junto con las filas.
    Rectangle {
        visible: ventana.pantalla === "Ranking"
        anchors.top: cabeceraRankingMovil.bottom
        anchors.topMargin: 8 * Tema.escala
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16 * Tema.escala
        radius: 8 * Tema.escala
        color: Tema.colorPanel
        border.width: 1
        border.color: Tema.colorBorde

        Text {
            anchors.centerIn: parent
            width: parent.width - 40 * Tema.escala
            visible: rankingModel.count === 0 && ventana.rankingPodio.length === 0
            text: "Todavía no hay cuentas con partidas suficientes para aparecer en el ranking."
            color: Tema.colorTextoTenue
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 12 * Tema.escala
        }

        ListView {
            id: listaRankingMovil
            // rankingPodio.length===3 en el OR -- con exactamente 3
            // cuentas en el ranking el header (podio) debe seguir
            // viéndose aunque rankingModel esté vacío.
            visible: rankingModel.count > 0 || ventana.rankingPodio.length === 3
            anchors.fill: parent
            anchors.margins: 12 * Tema.escala
            clip: true
            spacing: 6 * Tema.escala
            model: rankingModel
            // Bug real reportado 2026-09-02, CUARTO Y QUINTO intento --
            // mismo mecanismo que escritorio, ver el comentario grande
            // junto a listaRanking allí: los resets puntuales (sin
            // importar EN QUÉ MOMENTO se disparen) pueden perder la
            // carrera contra la compensación interna de Flickable cuando
            // el contenido crece por encima de lo visible (la cabecera-
            // podio pasando de invisible a visible de golpe). En vez de
            // adivinar el momento otra vez, esto FIJA contentY a 0 en
            // cada cambio real de contentHeight hasta que el usuario
            // mueva la lista de verdad.
            property bool anclarArriba: true
            onContentHeightChanged: if (anclarArriba) contentY = 0
            onMovementStarted: anclarArriba = false
            onFlickStarted: anclarArriba = false
            header: Column {
                id: cabeceraListaRankingMovil
                width: parent ? parent.width : 0
                spacing: 12 * Tema.escala
                // Bug real reportado 2026-09-02, TERCER intento -- los dos
                // anteriores adivinaban EN QUÉ MOMENTO del ciclo de JS
                // resetear el scroll (mismo tick, luego Qt.callLater) y
                // los dos fallaron -- estaban resolviendo el problema
                // equivocado. Esto SÍ ataca la causa real: el alto de esta
                // Column cambia de golpe cuando el podio aparece/
                // desaparece (Column excluye del layout a los hijos
                // invisibles), y ESE cambio de alto es lo que descoloca a
                // ListView -- no importa cuándo se rellene el modelo, lo
                // que importa es cuándo cambia el alto de la cabecera.
                // Reaccionar directamente a ESE evento, en vez de intentar
                // adivinar el momento adecuado en otro sitio.
                onHeightChanged: Qt.callLater(() => { listaRankingMovil.contentY = 0; })

                // ── Podio: top 3 de la pestaña activa -- mismo diseño ya
                // validado en escritorio (avatar grande + placa numérica,
                // sin insignia nueva -- ver memoria
                // qt_progression_review_2026_09_01). Avatares algo más
                // pequeños que escritorio (84/66 en vez de 96/76) para
                // caber con más margen en landscape móvil.
                Row {
                    visible: ventana.rankingPodio.length === 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 20 * Tema.escala
                    Repeater {
                        model: 3
                        delegate: Column {
                            id: columnaPodioMovil
                            required property int index
                            readonly property int idxFila: [1, 0, 2][columnaPodioMovil.index]
                            readonly property var fila: ventana.rankingPodio.length === 3
                                                         ? ventana.rankingPodio[columnaPodioMovil.idxFila] : null
                            readonly property bool esPrimero: columnaPodioMovil.idxFila === 0
                            readonly property real tamanoAvatar: (columnaPodioMovil.esPrimero ? 84 : 66) * Tema.escala
                            readonly property color colorPuesto: ventana.colorRareza(
                                !columnaPodioMovil.fila ? "" :
                                columnaPodioMovil.fila.posicion === 1 ? "oro" :
                                columnaPodioMovil.fila.posicion === 2 ? "plata" : "bronce")
                            spacing: 5 * Tema.escala

                            Item {
                                id: envolturaAvatarPodioMovil
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: columnaPodioMovil.tamanoAvatar * 2.1
                                height: width
                                Avatar {
                                    anchors.centerIn: parent
                                    letra: columnaPodioMovil.fila && columnaPodioMovil.fila.username.length > 0
                                           ? columnaPodioMovil.fila.username.charAt(0).toUpperCase() : "?"
                                    tamano: columnaPodioMovil.tamanoAvatar
                                    marco: columnaPodioMovil.fila
                                           ? Tema.marcoPorPartidasGanadas(columnaPodioMovil.fila.partidasGanadas,
                                                                           columnaPodioMovil.fila.tieneMarcoBasico)
                                           : "ninguno"
                                    textura: columnaPodioMovil.fila ? columnaPodioMovil.fila.textura : ""
                                    efecto: columnaPodioMovil.fila ? columnaPodioMovil.fila.efecto : ""
                                    decoracionLateral1: columnaPodioMovil.fila ? columnaPodioMovil.fila.decoracionLateral1 : ""
                                    decoracionLateral2: columnaPodioMovil.fila ? columnaPodioMovil.fila.decoracionLateral2 : ""
                                    decoracionSuperior: columnaPodioMovil.fila ? columnaPodioMovil.fila.decoracionSuperior : ""
                                    acabadoLateral1: columnaPodioMovil.fila ? columnaPodioMovil.fila.acabadoLateral1 : ""
                                    acabadoLateral2: columnaPodioMovil.fila ? columnaPodioMovil.fila.acabadoLateral2 : ""
                                    acabadoSuperior: columnaPodioMovil.fila ? columnaPodioMovil.fila.acabadoSuperior : ""
                                }
                                // Tocar el avatar abre el perfil público --
                                // pedido explícito 2026-09-02 ("importante"),
                                // el podio se había quedado sin esto aunque
                                // la lista normal de abajo ya lo tenía.
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: columnaPodioMovil.fila !== null
                                    onClicked: popupPerfilJugador.abrir(columnaPodioMovil.fila.accountId)
                                }
                                // Placa de puesto -- mismo lenguaje que el
                                // disco "D" de dealer en Asiento.qml,
                                // offset desde el CENTRO del envolvente
                                // (no la esquina del Item 2.1x de sobra).
                                Rectangle {
                                    width: 20 * Tema.escala
                                    height: width
                                    radius: width / 2
                                    x: envolturaAvatarPodioMovil.width / 2 + columnaPodioMovil.tamanoAvatar * 0.30 - width / 2
                                    y: envolturaAvatarPodioMovil.height / 2 + columnaPodioMovil.tamanoAvatar * 0.30 - height / 2
                                    color: columnaPodioMovil.colorPuesto
                                    border.width: 1.5
                                    border.color: Tema.colorFondo
                                    z: 10
                                    Text {
                                        anchors.centerIn: parent
                                        text: columnaPodioMovil.fila ? (columnaPodioMovil.fila.posicion + "") : ""
                                        font.bold: true
                                        font.family: Tema.fuenteElegante
                                        font.pixelSize: 10 * Tema.escala
                                        color: Tema.colorFondo
                                    }
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 110 * Tema.escala
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: columnaPodioMovil.fila ? columnaPodioMovil.fila.username : ""
                                font.bold: true
                                color: Tema.colorTexto
                                font.pixelSize: 12 * Tema.escala
                            }
                            CajaTitulo {
                                anchors.horizontalCenter: parent.horizontalCenter
                                readonly property var infoTitulo: columnaPodioMovil.fila
                                    ? ventana.objetoTiendaPorCodigo(columnaPodioMovil.fila.titulo || "") : null
                                nombre: infoTitulo ? infoTitulo.nombre : ""
                                colorTier: ventana.colorRareza(infoTitulo ? infoTitulo.rareza : "")
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: !columnaPodioMovil.fila ? ""
                                      : ventana.ordenRankingActual === 2 ? (columnaPodioMovil.fila.elo + " Elo")
                                      : ventana.ordenRankingActual === 1
                                        ? (Math.round(100 * columnaPodioMovil.fila.partidasGanadas / columnaPodioMovil.fila.partidasJugadas) + "% de ratio")
                                        : (columnaPodioMovil.fila.partidasGanadas + " victorias")
                                color: Tema.colorTextoTenue
                                font.pixelSize: 10 * Tema.escala
                            }
                        }
                    }
                }
                Rectangle {
                    visible: ventana.rankingPodio.length === 3
                    width: parent.width
                    height: 1
                    color: Qt.rgba(0, 0, 0, 0.25)
                }
                Row {
                    width: parent.width
                    height: 20 * Tema.escala
                    Text {
                        width: 28 * Tema.escala
                        text: "#"
                        color: Tema.colorTextoMuyTenue
                        font.pixelSize: 9 * Tema.escala
                    }
                    Text {
                        width: parent.width - 28 * Tema.escala - 160 * Tema.escala
                        text: "JUGADOR"
                        color: Tema.colorTextoMuyTenue
                        font.pixelSize: 9 * Tema.escala
                    }
                    Text {
                        width: 80 * Tema.escala
                        horizontalAlignment: Text.AlignRight
                        text: ventana.ordenRankingActual === 2 ? "ELO" : "GANADAS"
                        color: Tema.colorTextoMuyTenue
                        font.pixelSize: 9 * Tema.escala
                    }
                    Text {
                        width: 80 * Tema.escala
                        horizontalAlignment: Text.AlignRight
                        text: ventana.ordenRankingActual === 2 ? "PARTIDAS" : "RATIO"
                        color: Tema.colorTextoMuyTenue
                        font.pixelSize: 9 * Tema.escala
                    }
                }
            }
            delegate: Rectangle {
                id: filaRankingMovil
                required property int accountId
                required property string username
                required property int partidasJugadas
                required property int partidasGanadas
                required property int elo
                required property int posicion
                required property bool tieneMarcoBasico
                required property int index
                readonly property bool esUsuarioPropio:
                    username.toLowerCase() === ventana.nombreJugador.toLowerCase()
                width: ListView.view.width
                height: Math.max(Tema.tamanoMinTactil, 56 * Tema.escala)
                radius: 6 * Tema.escala
                color: esUsuarioPropio ? Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.1) : Tema.colorFondo
                border.width: esUsuarioPropio ? 1.5 : 1
                border.color: esUsuarioPropio ? Tema.colorAccent : Tema.colorBorde

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10 * Tema.escala
                    anchors.rightMargin: 10 * Tema.escala
                    Text {
                        width: 28 * Tema.escala
                        anchors.verticalCenter: parent.verticalCenter
                        // "posicion", no "index+1" -- el top 3 ya no vive
                        // en este modelo (ver el podio de arriba).
                        text: filaRankingMovil.posicion + ""
                        font.family: Tema.fuenteElegante
                        color: Tema.colorTextoTenue
                        font.pixelSize: 14 * Tema.escala
                    }
                    Row {
                        width: filaRankingMovil.width - 28 * Tema.escala - 160 * Tema.escala - 20 * Tema.escala
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8 * Tema.escala
                        Avatar {
                            anchors.verticalCenter: parent.verticalCenter
                            letra: filaRankingMovil.username.length > 0 ? filaRankingMovil.username.charAt(0).toUpperCase() : "?"
                            // Sin textura/efecto/decoraciones -- reservadas
                            // como "premio" exclusivo del podio de arriba,
                            // mismo criterio que escritorio.
                            tamano: 34 * Tema.escala
                            marco: Tema.marcoPorPartidasGanadas(filaRankingMovil.partidasGanadas, filaRankingMovil.tieneMarcoBasico)
                            colorBorde: filaRankingMovil.esUsuarioPropio ? Tema.colorAccent : Qt.rgba(1, 1, 1, 0.18)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: filaRankingMovil.username + (filaRankingMovil.esUsuarioPropio ? " (tú)" : "")
                            font.bold: filaRankingMovil.esUsuarioPropio
                            color: Tema.colorTexto
                            elide: Text.ElideRight
                            font.pixelSize: 12 * Tema.escala
                        }
                    }
                    Text {
                        width: 80 * Tema.escala
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: ventana.ordenRankingActual === 2 ? (filaRankingMovil.elo + "") : (filaRankingMovil.partidasGanadas + "")
                        color: Tema.colorTexto
                        font.pixelSize: 12 * Tema.escala
                    }
                    Text {
                        width: 80 * Tema.escala
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: ventana.ordenRankingActual === 2
                              ? (filaRankingMovil.partidasJugadas + "")
                              : (Math.round(100 * filaRankingMovil.partidasGanadas / filaRankingMovil.partidasJugadas) + "%")
                        color: Tema.colorTextoTenue
                        font.pixelSize: 12 * Tema.escala
                    }
                }
                // Fila completa abre el perfil público -- mismo criterio
                // que en escritorio.
                MouseArea {
                    anchors.fill: parent
                    onClicked: popupPerfilJugador.abrir(filaRankingMovil.accountId)
                }
            }
        }
    }

    BarraSuperior {
        id: barraTorneosMovil
        visible: ventana.pantalla === "Torneos"
        anchors.top: parent.top
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        textoCentro: "Torneos"
        onAbrirAjustes: ventana.ajustesAbiertos = !ventana.ajustesAbiertos
    }
    // Torneos bloqueado (los releases, ver POKER_TORNEOS en
    // cmake/ClientesQt.cmake): lo mismo que había antes de Solitario.
    Proximamente {
        visible: ventana.pantalla === "Torneos" && !torneosHabilitados
        anchors.top: barraTorneosMovil.bottom
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        titulo: "Torneos"
        descripcion: "Organiza partidas por eliminatorias para un grupo fijo de jugadores -- como crear una sala, pero con llave de torneo."
    }
    // Torneos Solitario (Fase 6, ver CLAUDE.md) -- mismo contenido que
    // qml/Main.qml (escritorio), ver el comentario largo ahí. "Multijugador"
    // sigue siendo un placeholder puro.
    Item {
        visible: ventana.pantalla === "Torneos" && torneosHabilitados
        anchors.top: barraTorneosMovil.bottom
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Column {
            anchors.centerIn: parent
            spacing: 20 * Tema.escala
            width: 300 * Tema.escala

            Text {
                text: "Torneos Solitario"
                color: Tema.colorTexto
                font.bold: true
                font.pixelSize: 18 * Tema.escala
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

            Rectangle {
                width: parent.width
                height: columnaRetoMovil.height + 28 * Tema.escala
                radius: 12 * Tema.escala
                color: Tema.colorPanel
                border.width: 1
                border.color: Tema.colorBorde
                // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                layer.enabled: true
                layer.effect: ShaderEffect {
                    property variant source
                    property real amplitud: 30.0
                    fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
                }

                Column {
                    id: columnaRetoMovil
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
                            modoJuego.activarModoLocal();
                            ventana.modoOfflineActivo = true;
                            redcliente.iniciarPartidaLocal(
                                nombreJugador, /*numBots=*/2, /*numManos=*/200,
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
        id: barraSocialMovil
        visible: ventana.pantalla === "Social"
        anchors.top: parent.top
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        textoCentro: "Social"
        onAbrirAjustes: ventana.ajustesAbiertos = !ventana.ajustesAbiertos
    }
    // ── Social: invitados ven un aviso + acceso a login/registro, mismo
    // criterio que la pestaña Cuenta del cajón lateral.
    Column {
        visible: ventana.pantalla === "Social" && ventana.tokenSesion === ""
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: rielNavegacionMovil.width / 2
        spacing: 12 * Tema.escala
        width: Math.min(340 * Tema.escala, ventana.width - rielNavegacionMovil.width - 60 * Tema.escala)

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
            onClicked: { ventana.mensajeErrorLogin = ""; ventana.pantalla = "Login"; }
        }
        BotonContorno {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Crear cuenta"
            onClicked: { ventana.mensajeErrorLogin = ""; ventana.pantalla = "Registro"; }
        }
    }

    // Etiquetas abreviadas respecto a escritorio -- landscape móvil deja
    // menos ancho por segmento que la ventana de escritorio, y
    // SelectorSegmentado no envuelve ni recorta el texto.
    SelectorSegmentado {
        id: tabsSocialMovil
        visible: ventana.pantalla === "Social" && ventana.tokenSesion !== ""
        anchors.top: barraSocialMovil.bottom
        anchors.topMargin: 12 * Tema.escala
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        opciones: ["Amigos", "Buscar", "Recientes", "Solicitudes"]
        seleccionado: ventana.pestanaSocialActual
        onElegido: (indice) => {
            ventana.pestanaSocialActual = indice;
            ventana.mensajeErrorSocial = "";
            // Amigos fusiona presencia + último mensaje en la misma fila
            // (ya no hay pestaña "Chats" aparte) -- pide las dos listas
            // juntas.
            if (indice === 0) {
                redcliente.listarAmigos(ventana.servidorHost, ventana.servidorPuerto);
                redcliente.listarResumenChats(ventana.servidorHost, ventana.servidorPuerto);
            }
            else if (indice === 2) redcliente.listarJugadoresRecientes(ventana.servidorHost, ventana.servidorPuerto);
            else if (indice === 3) redcliente.listarSolicitudesPendientes(ventana.servidorHost, ventana.servidorPuerto);
        }
    }

    // Timer de refresco de presencia -- mismo criterio que escritorio (ver
    // el comentario largo en Main.qml de qml/).
    Timer {
        interval: 15000
        repeat: true
        running: ventana.pantalla === "Social" && ventana.pestanaSocialActual === 0 && ventana.tokenSesion !== ""
        onTriggered: redcliente.listarAmigos(ventana.servidorHost, ventana.servidorPuerto)
    }

    // Slot de altura reactiva para el mensaje de error -- así el panel de
    // debajo no tiene que saber si hay mensaje visible o no para anclarse.
    Item {
        id: errorSocialMovilSlot
        visible: ventana.pantalla === "Social" && ventana.tokenSesion !== ""
        anchors.top: tabsSocialMovil.bottom
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        height: ventana.mensajeErrorSocial !== "" ? textoErrorSocialMovil.implicitHeight + 8 * Tema.escala : 0

        Text {
            id: textoErrorSocialMovil
            visible: ventana.mensajeErrorSocial !== ""
            anchors.top: parent.top
            anchors.topMargin: 6 * Tema.escala
            width: parent.width
            text: ventana.mensajeErrorSocial
            color: Tema.colorPeligro
            font.pixelSize: 11 * Tema.escala
            wrapMode: Text.WordWrap
        }
    }

    Rectangle {
        id: panelSocialMovil
        visible: ventana.pantalla === "Social" && ventana.tokenSesion !== ""
        anchors.top: errorSocialMovilSlot.bottom
        anchors.topMargin: 8 * Tema.escala
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16 * Tema.escala
        radius: 8 * Tema.escala
        // LISO a propósito, sin degradado ni textura de tapete
        // (2026-09-09, pedido explícito): "en los sitios que tengan fondo
        // tapete y encima tarjetas con textura tapete, el fondo sea sin
        // esa textura, resalta las tarjetas y se diferencia mejor". Este
        // panel es justo eso -- el fondo sobre el que van las tarjetas de
        // amigos / objetos / estadísticas, que sí llevan su fieltro.
        //
        // Antes de llegar aquí pasó por dos intentos que sobran, pero que
        // conviene no repetir: un degradado corto SIN dithering (bandeó, y
        // el escalón se veía como "una línea drástica de cambio de color"
        // cruzando la tarjeta) y luego uno con dithering en un hijo. El
        // segundo funcionaba; simplemente, liso queda mejor.
        color: Tema.colorPanel
        border.width: 1
        border.color: Tema.colorBorde

        // ── Amigos ────────────────────────────────────────────────────
        Text {
            anchors.centerIn: parent
            width: parent.width - 32 * Tema.escala
            visible: ventana.pestanaSocialActual === 0 && modeloAmigos.count === 0
            text: "Todavía no tienes amigos añadidos. Búscalos en \"Buscar\" o mira \"Recientes\"."
            color: Tema.colorTextoTenue
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 12 * Tema.escala
        }
        // Rejilla de tarjetas (rediseño 2026-08-28, mismo criterio que
        // Salas) -- ahora SÍ con Avatar (antes ninguna fila de Social en
        // móvil lo mostraba) y con el estado (punto + palabra) de vuelta,
        // pedido explícito tras ver el primer mockup sin él.
        GridView {
            id: gridAmigosMovil
            visible: ventana.pestanaSocialActual === 0 && modeloAmigos.count > 0
            // Llena TODO el ancho del panel (antes se topaba a 560*escala
            // y quedaba centrado, dejando margen muerto a los lados en
            // pantallas anchas de verdad -- bug real reportado
            // 2026-08-31: "queda bastante margen a ambos lados"). cellWidth
            // = ancho/3 EXACTO, no un umbral "quepan las que quepan" --
            // así siempre son 3 columnas, ni 2 ni 4, y las tarjetas crecen
            // para aprovechar el ancho en vez de dejarlo vacío.
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12 * Tema.escala
            clip: true
            cellWidth: Math.floor(width / 3)
            cellHeight: 78 * Tema.escala
            model: modeloAmigosConChat
            delegate: Item {
                id: celdaAmigoMovil
                required property int accountId
                required property string estado
                required property string username
                required property string ultimoTexto
                required property bool ultimoEsMio
                required property int noLeidos
                width: gridAmigosMovil.cellWidth
                height: gridAmigosMovil.cellHeight

                // "Ficha de casino" (2026-09-02, pedido explícito:
                // "aplicar el mismo estilo a los amigos y salas") --
                // sombra desplazada barata, SIN escalar con la tarjeta.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4 * Tema.escala
                    anchors.topMargin: 4 * Tema.escala + 3 * Tema.escala
                    radius: 8 * Tema.escala
                    color: "black"
                    opacity: 0.35
                }

                Rectangle {
                    id: tarjetaAmigoMovil
                    anchors.fill: parent
                    anchors.margins: 4 * Tema.escala
                    radius: 8 * Tema.escala
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
                        fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
                    }
                    // Mismo encogido reactivo que la Tienda al tocar.
                    scale: areaChatAmigoMovil.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    // Hilo dorado por dentro del bisel exterior -- el
                    // "doble bisel" de ficha de casino.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2 * Tema.escala
                        radius: parent.radius - 2 * Tema.escala
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.18)
                    }

                    // Avatar como hijo DIRECTO de la tarjeta (no anidado en
                    // el Row de abajo) a propósito: la MouseArea de perfil
                    // más abajo ancla "centerIn: avatarCeldaAmigoMovil", y
                    // QML solo permite anclar contra el propio padre o un
                    // hermano directo -- anidado dentro de un Row sería
                    // hermano DEL ROW, no del avatar (mismo bug ya
                    // encontrado y corregido en escritorio, 2026-08-27).
                    Avatar {
                        id: avatarCeldaAmigoMovil
                        anchors.left: parent.left
                        anchors.leftMargin: 8 * Tema.escala
                        anchors.verticalCenter: parent.verticalCenter
                        letra: celdaAmigoMovil.username.length > 0 ? celdaAmigoMovil.username.charAt(0).toUpperCase() : "?"
                        tamano: 28 * Tema.escala
                    }
                    Column {
                        anchors.left: avatarCeldaAmigoMovil.right
                        anchors.leftMargin: 7 * Tema.escala
                        anchors.right: badgeNoLeidosAmigoMovil.visible ? badgeNoLeidosAmigoMovil.left : parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 6 * Tema.escala
                        spacing: 2 * Tema.escala
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: celdaAmigoMovil.username
                            color: Tema.colorTexto
                            font.pixelSize: 11 * Tema.escala
                        }
                        Row {
                            width: parent.width
                            spacing: 4 * Tema.escala
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6 * Tema.escala
                                height: 6 * Tema.escala
                                radius: width / 2
                                color: celdaAmigoMovil.estado === "CONECTADO" ? "#7FAE7A"
                                       : celdaAmigoMovil.estado === "EN_PARTIDA" ? Tema.colorAccent
                                       : Tema.colorTextoMuyTenue
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 6 * Tema.escala - 4 * Tema.escala
                                elide: Text.ElideRight
                                // Estado + último mensaje en la misma
                                // línea, igual que antes del rediseño --
                                // si todavía no hay conversación,
                                // invitación explícita a chatear.
                                text: (celdaAmigoMovil.estado === "CONECTADO" ? "Conectado"
                                       : celdaAmigoMovil.estado === "EN_PARTIDA" ? "En partida"
                                       : "Desconectado") +
                                      " · " +
                                      (celdaAmigoMovil.ultimoTexto !== ""
                                           ? (celdaAmigoMovil.ultimoEsMio ? "Tú: " : "") + celdaAmigoMovil.ultimoTexto
                                           : "Toca para chatear")
                                color: Tema.colorTextoMuyTenue
                                font.pixelSize: 8.5 * Tema.escala
                            }
                        }
                    }
                    Rectangle {
                        id: badgeNoLeidosAmigoMovil
                        visible: celdaAmigoMovil.noLeidos > 0
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 5 * Tema.escala
                        width: 16 * Tema.escala
                        height: 16 * Tema.escala
                        radius: width / 2
                        color: Tema.colorAccent
                        Text {
                            anchors.centerIn: parent
                            text: celdaAmigoMovil.noLeidos > 9 ? "9+" : celdaAmigoMovil.noLeidos + ""
                            color: Tema.colorTextoSobreOscuro
                            font.pixelSize: 8.5 * Tema.escala
                            font.bold: true
                        }
                    }
                    // Hit-test dividido (pedido explícito 2026-08-28, mismo
                    // criterio que escritorio): el resto de la tarjeta abre
                    // el chat directo, un área de toque encima del avatar
                    // (MÁS grande que su bounding box de 28px, declarada
                    // DESPUÉS = prioridad de hit-test sobre la de abajo)
                    // abre el perfil público.
                    MouseArea {
                        id: areaChatAmigoMovil
                        anchors.fill: parent
                        onClicked: popupChatDirecto.abrir(celdaAmigoMovil.accountId, celdaAmigoMovil.username, celdaAmigoMovil.estado)
                    }
                    MouseArea {
                        width: Math.max(Tema.tamanoMinTactil, 40 * Tema.escala)
                        height: width
                        anchors.centerIn: avatarCeldaAmigoMovil
                        onClicked: popupPerfilJugador.abrir(celdaAmigoMovil.accountId)
                    }
                }
            }
        }

        // ── Buscar jugadores ──────────────────────────────────────────
        // Borde de acento PERMANENTE (no solo al pulsar, a diferencia de
        // cajaNombreSalaMovil) + icono de lupa -- sin esto se veía
        // idéntico a las filas de resultado de debajo (mismo
        // color/borde/altura), confuso dentro de una lista (reportado en
        // pruebas reales). El resto de "campos falsos" del programa viven
        // solos en un formulario, no encima de filas gemelas.
        // "Caja falsa" de búsqueda: parece un campo, pero al tocarla abre
        // el CampoEmergente de arriba (patrón táctil de toda la app
        // móvil). Sobre MarcoHueco desde 2026-09-09 -- era un relleno
        // plano con un filo dorado de 1.5px y, sobre un panel con textura
        // de fieltro, no se separaba del fondo ("es muy estrecha, no se
        // ve bien"). Un poco más alta también, que el rebaje necesita
        // alto para leerse como rebaje.
        MarcoHueco {
            id: cajaBusquedaSocialMovil
            visible: ventana.pestanaSocialActual === 1
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12 * Tema.escala
            height: Math.max(Tema.tamanoMinTactil, 48 * Tema.escala)
            radius: 10 * Tema.escala
            activo: areaBusquedaSocialMovil.pressed
            property string valor: ""

            IconoLupa {
                id: iconoLupaMovil
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12 * Tema.escala
                width: 16 * Tema.escala
                height: width
            }
            Text {
                anchors.left: iconoLupaMovil.right
                anchors.right: parent.right
                anchors.leftMargin: 8 * Tema.escala
                anchors.rightMargin: 10 * Tema.escala
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: cajaBusquedaSocialMovil.valor !== "" ? cajaBusquedaSocialMovil.valor : "Buscar por nombre de usuario"
                color: cajaBusquedaSocialMovil.valor !== "" ? Tema.colorTexto : Tema.colorTextoMuyTenue
                font.pixelSize: 13 * Tema.escala
            }
            MouseArea {
                id: areaBusquedaSocialMovil
                anchors.fill: parent
                onClicked: campoBusquedaSocialMovil.abrir(cajaBusquedaSocialMovil.valor)
            }
            CampoEmergente {
                id: campoBusquedaSocialMovil
                parent: Overlay.overlay
                etiqueta: "Buscar jugadores por nombre de usuario"
                onAceptado: (texto) => {
                    cajaBusquedaSocialMovil.valor = texto;
                    ventana.mensajeErrorSocial = "";
                    if (texto.length > 0) redcliente.buscarJugadores(ventana.servidorHost, ventana.servidorPuerto, texto);
                }
            }
        }
        Text {
            anchors.top: cajaBusquedaSocialMovil.bottom
            anchors.topMargin: 20 * Tema.escala
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 32 * Tema.escala
            visible: ventana.pestanaSocialActual === 1 && modeloBusqueda.count === 0
            text: "Busca por nombre de usuario para mandar una solicitud de amistad."
            color: Tema.colorTextoTenue
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 12 * Tema.escala
        }
        ListView {
            visible: ventana.pestanaSocialActual === 1 && modeloBusqueda.count > 0
            anchors.top: cajaBusquedaSocialMovil.bottom
            anchors.topMargin: 10 * Tema.escala
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 12 * Tema.escala
            clip: true
            spacing: 6 * Tema.escala
            model: modeloBusqueda
            delegate: Rectangle {
                id: filaBusquedaMovil
                required property int accountId
                required property int pendiente
                required property string username
                readonly property bool solicitudEnviada: filaBusquedaMovil.pendiente === 1
                width: ListView.view.width
                // + 12 -- mismo suelo que filaSalaMovil: el botón exige al
                // menos Tema.tamanoMinTactil él solo, sin margen la fila
                // quedaba justa (bordes del botón pegados a los de la
                // fila, reportado en pruebas reales).
                height: Tema.tactil + 12 * Tema.escala
                radius: 6 * Tema.escala
                color: Tema.colorFondo
                border.width: 1
                border.color: Tema.colorBorde

                Text {
                    anchors.left: parent.left
                    anchors.right: botonEnviarBusquedaMovil.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10 * Tema.escala
                    anchors.rightMargin: 8 * Tema.escala
                    elide: Text.ElideRight
                    text: filaBusquedaMovil.username
                    color: Tema.colorTexto
                    font.pixelSize: 12 * Tema.escala
                }
                // Fila completa abre el perfil público -- declarada ANTES
                // del botón para que este último tenga prioridad de
                // hit-test en su propia área (mismo criterio que escritorio).
                MouseArea {
                    anchors.fill: parent
                    onClicked: popupPerfilJugador.abrir(filaBusquedaMovil.accountId)
                }
                BotonContorno {
                    id: botonEnviarBusquedaMovil
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 8 * Tema.escala
                    enabled: !filaBusquedaMovil.solicitudEnviada
                    opacity: filaBusquedaMovil.solicitudEnviada ? 0.6 : 1.0
                    text: filaBusquedaMovil.solicitudEnviada ? "Enviada" : "Enviar solicitud"
                    onClicked: {
                        ventana.pendienteSolicitudUsername = filaBusquedaMovil.username;
                        redcliente.enviarSolicitudAmistad(ventana.servidorHost, ventana.servidorPuerto, filaBusquedaMovil.username);
                    }
                }
            }
        }

        // ── Jugadores Recientes ────────────────────────────────────────
        Text {
            anchors.centerIn: parent
            width: parent.width - 32 * Tema.escala
            visible: ventana.pestanaSocialActual === 2 && modeloRecientes.count === 0
            text: "Todavía no has compartido mesa con nadie en las últimas 24h."
            color: Tema.colorTextoTenue
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 12 * Tema.escala
        }
        ListView {
            visible: ventana.pestanaSocialActual === 2 && modeloRecientes.count > 0
            anchors.fill: parent
            anchors.margins: 12 * Tema.escala
            clip: true
            spacing: 6 * Tema.escala
            model: modeloRecientes
            delegate: Rectangle {
                id: filaRecienteMovil
                required property int accountId
                required property int pendiente
                required property string username
                readonly property bool solicitudEnviada: filaRecienteMovil.pendiente === 1
                width: ListView.view.width
                height: Tema.tactil + 12 * Tema.escala
                radius: 6 * Tema.escala
                color: Tema.colorFondo
                border.width: 1
                border.color: Tema.colorBorde

                Text {
                    anchors.left: parent.left
                    anchors.right: botonEnviarRecienteMovil.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10 * Tema.escala
                    anchors.rightMargin: 8 * Tema.escala
                    elide: Text.ElideRight
                    text: filaRecienteMovil.username
                    color: Tema.colorTexto
                    font.pixelSize: 12 * Tema.escala
                }
                // Fila completa abre el perfil público -- mismo criterio
                // que filaBusquedaMovil.
                MouseArea {
                    anchors.fill: parent
                    onClicked: popupPerfilJugador.abrir(filaRecienteMovil.accountId)
                }
                BotonContorno {
                    id: botonEnviarRecienteMovil
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 8 * Tema.escala
                    enabled: !filaRecienteMovil.solicitudEnviada
                    opacity: filaRecienteMovil.solicitudEnviada ? 0.6 : 1.0
                    text: filaRecienteMovil.solicitudEnviada ? "Enviada" : "Enviar solicitud"
                    onClicked: {
                        ventana.pendienteSolicitudUsername = filaRecienteMovil.username;
                        redcliente.enviarSolicitudAmistad(ventana.servidorHost, ventana.servidorPuerto, filaRecienteMovil.username);
                    }
                }
            }
        }

        // ── Solicitudes ────────────────────────────────────────────────
        Text {
            anchors.centerIn: parent
            width: parent.width - 32 * Tema.escala
            visible: ventana.pestanaSocialActual === 3 && modeloSolicitudes.count === 0
            text: "No tienes solicitudes de amistad pendientes."
            color: Tema.colorTextoTenue
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 12 * Tema.escala
        }
        ListView {
            visible: ventana.pestanaSocialActual === 3 && modeloSolicitudes.count > 0
            anchors.fill: parent
            anchors.margins: 12 * Tema.escala
            clip: true
            spacing: 6 * Tema.escala
            model: modeloSolicitudes
            delegate: Item {
                id: filaSolicitudMovil
                required property int solicitudId
                required property int fromAccountId
                required property int creadoEn
                required property string fromUsername
                width: ListView.view.width
                // Antes Tema.tamanoMinTactil + 12*escala -- quedaba
                // apretada, a ras de los propios botones (pedido
                // explícito 2026-09-02: "que sea un poco mas grande que
                // los botones, asi se ve apretado, funcional pero no
                // estetico").
                height: Tema.tactil + 24 * Tema.escala

                // "Ficha de casino" (mismo pedido: "adaptala tambien al
                // estilo del cajon") -- mismo recetario que Amigos/Salas:
                // sombra desplazada barata, degradado de 3 paradas con
                // brillo arriba, hilo dorado interior. Antes un
                // Rectangle plano (Tema.colorFondo liso), la única fila
                // "pobre" de todo Social -- Amigos/Buscar/Recientes ya
                // tenían al menos degradado o (Amigos) el estilo nuevo.
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 3 * Tema.escala
                    radius: 8 * Tema.escala
                    color: "black"
                    opacity: 0.35
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 8 * Tema.escala
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
                        fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2 * Tema.escala
                        radius: parent.radius - 2 * Tema.escala
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.18)
                    }

                    // Avatar -- mismo criterio que escritorio (que ya lo
                    // tenía) y que el resto de filas de Social con
                    // identidad de otro jugador (Amigos).
                    Avatar {
                        id: avatarSolicitudMovil
                        anchors.left: parent.left
                        anchors.leftMargin: 10 * Tema.escala
                        anchors.verticalCenter: parent.verticalCenter
                        letra: filaSolicitudMovil.fromUsername.length > 0 ? filaSolicitudMovil.fromUsername.charAt(0).toUpperCase() : "?"
                        tamano: 32 * Tema.escala
                    }
                    Text {
                        anchors.left: avatarSolicitudMovil.right
                        anchors.right: filaBotonesSolicitudMovil.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10 * Tema.escala
                        anchors.rightMargin: 8 * Tema.escala
                        elide: Text.ElideRight
                        text: filaSolicitudMovil.fromUsername
                        color: Tema.colorTexto
                        font.pixelSize: 13 * Tema.escala
                    }
                    Row {
                        id: filaBotonesSolicitudMovil
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 10 * Tema.escala
                        spacing: 6 * Tema.escala
                        BotonContorno {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Rechazar"
                            onClicked: redcliente.responderSolicitud(
                                ventana.servidorHost, ventana.servidorPuerto, filaSolicitudMovil.solicitudId, false)
                        }
                        BotonRelleno {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Aceptar"
                            onClicked: redcliente.responderSolicitud(
                                ventana.servidorHost, ventana.servidorPuerto, filaSolicitudMovil.solicitudId, true)
                        }
                    }
                }
            }
        }

    }

    // ── Pantalla Cuenta (Fase M1 del port de progresión a móvil,
    // 2026-09-01, ver memoria qt_mobile_progression_port_plan) -- antes
    // vivía como sub-pestaña del cajón de Ajustes, mudada aquí al riel
    // (pantalla propia), mismo criterio ya aprobado en escritorio
    // 2026-08-31. Perfil, con el contenido que ya existía (avatar/
    // stats/cambiar usuario-contraseña/cerrar sesión) más lo nuevo de
    // hoy (loadout real + CajaTitulo en el avatar), está TERMINADO.
    // Progreso/Logros/Personalizar quedan con un aviso "sin construir
    // todavía" -- necesitan portar piezas que no existen aún en móvil
    // (AnilloNivel.qml, el catálogo de Logros, la rejilla de
    // Personalizar) y se dejaron fuera de este primer tramo a propósito.
    BarraSuperior {
        id: barraCuentaMovil
        visible: ventana.pantalla === "Cuenta"
        anchors.top: parent.top
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        textoCentro: "Cuenta"
        onAbrirAjustes: ventana.ajustesAbiertos = !ventana.ajustesAbiertos
    }
    // ── Cuenta: invitados ven un aviso + acceso a login/registro, mismo
    // criterio que Social. ──────────────────────────────────────────────
    Column {
        visible: ventana.pantalla === "Cuenta" && !ventana.hayCuenta
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: rielNavegacionMovil.width / 2
        spacing: 12 * Tema.escala
        width: Math.min(340 * Tema.escala, ventana.width - rielNavegacionMovil.width - 60 * Tema.escala)

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Estás jugando como invitado. Inicia sesión o crea una cuenta para ver tu perfil, tu progreso y tus logros."
            color: Tema.colorTextoTenue
            font.pixelSize: 13 * Tema.escala
        }
        BotonRelleno {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Iniciar sesión"
            onClicked: { ventana.mensajeErrorLogin = ""; ventana.pantalla = "Login"; }
        }
        BotonContorno {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Crear cuenta"
            onClicked: { ventana.mensajeErrorLogin = ""; ventana.pantalla = "Registro"; }
        }
    }

    SelectorSegmentado {
        id: tabsCuentaMovil
        visible: ventana.pantalla === "Cuenta" && ventana.hayCuenta
        anchors.top: barraCuentaMovil.bottom
        anchors.topMargin: 12 * Tema.escala
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        opciones: ["Perfil", "Progreso", "Logros", "Personalizar"]
        seleccionado: ventana.pestanaCuentaActual
        onElegido: (indice) => ventana.pestanaCuentaActual = indice
    }

    // Panel con scroll (ScrollView, mismo criterio que scrollAjustesMovil)
    // bajo tabsCuentaMovil, que se queda fijo -- "el selector de pestaña
    // arriba tiene que quedarse, el contenido baja" (regla ya aplicada en
    // toda la app, ver qt_progression_review_2026_09_01).
    Rectangle {
        id: panelCuentaMovil
        visible: ventana.pantalla === "Cuenta" && ventana.hayCuenta
        anchors.top: tabsCuentaMovil.bottom
        anchors.topMargin: 8 * Tema.escala
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16 * Tema.escala
        radius: 8 * Tema.escala
        // LISO a propósito, sin degradado ni textura de tapete
        // (2026-09-09, pedido explícito): "en los sitios que tengan fondo
        // tapete y encima tarjetas con textura tapete, el fondo sea sin
        // esa textura, resalta las tarjetas y se diferencia mejor". Este
        // panel es justo eso -- el fondo sobre el que van las tarjetas de
        // amigos / objetos / estadísticas, que sí llevan su fieltro.
        //
        // Antes de llegar aquí pasó por dos intentos que sobran, pero que
        // conviene no repetir: un degradado corto SIN dithering (bandeó, y
        // el escalón se veía como "una línea drástica de cambio de color"
        // cruzando la tarjeta) y luego uno con dithering en un hijo. El
        // segundo funcionaba; simplemente, liso queda mejor.
        color: Tema.colorPanel
        border.width: 1
        border.color: Tema.colorBorde

        // Personalizar (pestaña 3) NO vive aquí dentro -- necesita su
        // propio layout con avatar fijo a la derecha (ver el Item
        // hermano más abajo, después de este ScrollView); las otras 3
        // pestañas siguen siendo contenido simple que scrollea entero.
        ScrollView {
            id: scrollCuentaMovil
            visible: ventana.pestanaCuentaActual !== 3
            anchors.fill: parent
            anchors.margins: 16 * Tema.escala
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: panelCuentaMovil.width - 32 * Tema.escala
                spacing: 8 * Tema.escala

                // ── Perfil ────────────────────────────────────────────────
                Column {
                    width: parent.width
                    visible: ventana.pestanaCuentaActual === 0
                    spacing: 12 * Tema.escala

                    // Ver el comentario gemelo en qml/Main.qml: sin conexión
                    // esto es la foto de la última sesión con servidor.
                    Text {
                        visible: ventana.sesionOffline
                        width: parent.width
                        wrapMode: Text.WordWrap
                        color: Tema.colorTextoTenue
                        font.pixelSize: 11 * Tema.escala
                        text: "Sin conexión · datos de tu última sesión con el servidor, solo lectura."
                    }

                    // Item envolvente de sobra (2.1x) -- el anillo y las
                    // decoraciones sobresalen de su propio tamano, mismo
                    // criterio que PopupPerfilJugador.qml/escritorio.
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 72 * Tema.escala * 2.1
                        height: width
                        Avatar {
                            anchors.centerIn: parent
                            letra: ventana.nombreJugador.length > 0 ? ventana.nombreJugador.charAt(0).toUpperCase() : "?"
                            tamano: 72 * Tema.escala
                            marco: Tema.marcoPorPartidasGanadas(ventana.statsPartidasGanadas, ventana.statsTieneMarcoBasico)
                            // Loadout real (Fase M0/M1, 2026-09-01) -- antes
                            // este avatar solo pintaba el marco, nunca
                            // textura/efecto/decoraciones (mismo hueco que
                            // tenía escritorio antes de arreglarlo el mismo
                            // día -- ver memoria qt_progression_review_2026_09_01).
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
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ventana.nombreJugador
                        color: Tema.colorTexto
                        font.family: Tema.fuenteElegante
                        font.bold: true
                        font.pixelSize: 16 * Tema.escala
                    }
                    CajaTitulo {
                        anchors.horizontalCenter: parent.horizontalCenter
                        readonly property var infoTitulo: ventana.objetoTiendaPorCodigo(redcliente.loadoutMarco.titulo || "")
                        nombre: infoTitulo ? infoTitulo.nombre : ""
                        colorTier: ventana.colorRareza(infoTitulo ? infoTitulo.rareza : "")
                    }

                    // ── Estadísticas propias -- ocultas hasta la primera
                    // partida contada.
                    Column {
                        width: parent.width
                        visible: ventana.statsPartidasJugadas > 0
                        spacing: 6 * Tema.escala
                        Repeater {
                            model: [
                                { etiqueta: "Partidas jugadas", valor: ventana.statsPartidasJugadas + "" },
                                { etiqueta: "Partidas ganadas", valor: ventana.statsPartidasGanadas + "" },
                                { etiqueta: "Ratio de victorias", valor: Math.round(100 * ventana.statsPartidasGanadas / ventana.statsPartidasJugadas) + "%" },
                                { etiqueta: "Racha actual", valor: ventana.statsRachaActual + "" },
                                { etiqueta: "Mejor racha", valor: ventana.statsRachaMaxima + "" },
                                { etiqueta: "Manos jugadas", valor: ventana.statsManosJugadas + "" },
                                { etiqueta: "Manos ganadas", valor: ventana.statsManosGanadas + "" },
                                { etiqueta: "Mayor bote ganado", valor: ventana.statsMayorBote + "", esDinero: true },
                                { etiqueta: "Mejor mano", valor: ventana.statsMejorManoFecha > 0
                                      ? ventana.statsMejorManoNombre + " (" + ventana.formatearFechaCorta(ventana.statsMejorManoFecha) + ")"
                                      : "—" }
                            ]
                            delegate: Row {
                                required property var modelData
                                width: parent.width
                                Text {
                                    width: parent.width - 150 * Tema.escala
                                    text: modelData.etiqueta
                                    color: Tema.colorTextoTenue
                                    font.pixelSize: 11 * Tema.escala
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
                                        font.pixelSize: 11 * Tema.escala
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        // Combinaciones mostradas alguna vez en un showdown.
                        // Lista de UNA columna y letra a 11 -- el mismo arreglo
                        // que ya tenía el cliente de escritorio, pedido para
                        // móvil el 2026-09-10 ("sin razón es más pequeña que el
                        // resto"). Antes era una rejilla de 2 columnas a 10 con
                        // la cabecera a 9, más pequeña que las estadísticas de
                        // justo encima (11), y subir la letra sin quitar la
                        // rejilla habría cortado "Escalera de color" en medio
                        // ancho. Va dentro del ScrollView de Cuenta, así que
                        // las filas de más no le quitan sitio a nada.
                        Text {
                            text: "COMBINACIONES MOSTRADAS"
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 10 * Tema.escala
                            font.letterSpacing: 1
                            topPadding: 6 * Tema.escala
                        }
                        Column {
                            width: parent.width
                            spacing: 4 * Tema.escala
                            Repeater {
                                model: [
                                    { etiqueta: "Carta alta", valor: ventana.statsVecesCartaAlta },
                                    { etiqueta: "Pareja", valor: ventana.statsVecesPareja },
                                    { etiqueta: "Doble pareja", valor: ventana.statsVecesDoblePareja },
                                    { etiqueta: "Trío", valor: ventana.statsVecesTrio },
                                    { etiqueta: "Escalera", valor: ventana.statsVecesEscalera },
                                    { etiqueta: "Color", valor: ventana.statsVecesColor },
                                    { etiqueta: "Full House", valor: ventana.statsVecesFullHouse },
                                    { etiqueta: "Póker", valor: ventana.statsVecesPoker },
                                    { etiqueta: "Escalera de color", valor: ventana.statsVecesEscaleraColor },
                                    { etiqueta: "Escalera real", valor: ventana.statsVecesEscaleraReal }
                                ]
                                delegate: Row {
                                    required property var modelData
                                    width: parent.width
                                    Text {
                                        width: parent.width - 44 * Tema.escala
                                        text: modelData.etiqueta
                                        color: modelData.valor > 0 ? Tema.colorTextoTenue : Tema.colorTextoMuyTenue
                                        font.pixelSize: 11 * Tema.escala
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        // 44 en vez de 26: con una sola columna
                                        // sobra sitio, y un recuento de manos de
                                        // cuatro o cinco cifras en negrita no
                                        // cabía en 26.
                                        width: 44 * Tema.escala
                                        text: modelData.valor + ""
                                        color: modelData.valor > 0 ? Tema.colorAccent : Tema.colorTextoMuyTenue
                                        font.bold: modelData.valor > 0
                                        font.pixelSize: 11 * Tema.escala
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }

                    MarcoHueco {
                        id: cajaNuevoUsernameMovil
                        width: parent.width
                        height: Math.max(Tema.tamanoMinTactil, 54 * Tema.escala)
                        radius: 10 * Tema.escala
                        activo: areaNuevoUsernameMovil.pressed
                        property string valor: ""
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10 * Tema.escala
                            anchors.verticalCenter: parent.verticalCenter
                            text: cajaNuevoUsernameMovil.valor !== "" ? cajaNuevoUsernameMovil.valor : "Nuevo nombre de usuario"
                            color: cajaNuevoUsernameMovil.valor !== "" ? Tema.colorTexto : Tema.colorTextoMuyTenue
                            font.pixelSize: 12 * Tema.escala
                            elide: Text.ElideRight
                            width: parent.width - 20 * Tema.escala
                        }
                        MouseArea {
                            id: areaNuevoUsernameMovil
                            anchors.fill: parent
                            onClicked: campoNuevoUsernameMovil.abrir(cajaNuevoUsernameMovil.valor)
                        }
                        CampoEmergente {
                            id: campoNuevoUsernameMovil
                            parent: Overlay.overlay
                            etiqueta: "Nuevo nombre de usuario"
                            onAceptado: (texto) => cajaNuevoUsernameMovil.valor = texto
                        }
                    }
                    BotonContorno {
                        text: "Cambiar nombre de usuario"
                        onClicked: {
                            if (cajaNuevoUsernameMovil.valor.length < 3) {
                                ventana.mensajeErrorLogin = "El nombre de usuario debe tener al menos 3 caracteres.";
                                return;
                            }
                            ventana.mensajeErrorLogin = "";
                            redcliente.cambiarNombreUsuario(ventana.servidorHost, ventana.servidorPuerto,
                                                            ventana.tokenSesion, cajaNuevoUsernameMovil.valor);
                        }
                    }

                    MarcoHueco {
                        id: cajaPasswordActualMovil
                        width: parent.width
                        height: Math.max(Tema.tamanoMinTactil, 54 * Tema.escala)
                        radius: 10 * Tema.escala
                        activo: areaPasswordActualMovil.pressed
                        property string valor: ""
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10 * Tema.escala
                            anchors.verticalCenter: parent.verticalCenter
                            text: cajaPasswordActualMovil.valor !== "" ? "••••••••" : "Contraseña actual"
                            color: cajaPasswordActualMovil.valor !== "" ? Tema.colorTexto : Tema.colorTextoMuyTenue
                            font.pixelSize: 12 * Tema.escala
                        }
                        MouseArea {
                            id: areaPasswordActualMovil
                            anchors.fill: parent
                            onClicked: campoPasswordActualMovil.abrir(cajaPasswordActualMovil.valor)
                        }
                        CampoEmergente {
                            id: campoPasswordActualMovil
                            parent: Overlay.overlay
                            etiqueta: "Contraseña actual"
                            esPassword: true
                            onAceptado: (texto) => cajaPasswordActualMovil.valor = texto
                        }
                    }
                    MarcoHueco {
                        id: cajaPasswordNuevaMovil
                        width: parent.width
                        height: Math.max(Tema.tamanoMinTactil, 54 * Tema.escala)
                        radius: 10 * Tema.escala
                        activo: areaPasswordNuevaMovil.pressed
                        property string valor: ""
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10 * Tema.escala
                            anchors.verticalCenter: parent.verticalCenter
                            text: cajaPasswordNuevaMovil.valor !== "" ? "••••••••" : "Contraseña nueva (8+ caracteres)"
                            color: cajaPasswordNuevaMovil.valor !== "" ? Tema.colorTexto : Tema.colorTextoMuyTenue
                            font.pixelSize: 12 * Tema.escala
                            elide: Text.ElideRight
                            width: parent.width - 20 * Tema.escala
                        }
                        MouseArea {
                            id: areaPasswordNuevaMovil
                            anchors.fill: parent
                            onClicked: campoPasswordNuevaMovil.abrir(cajaPasswordNuevaMovil.valor)
                        }
                        CampoEmergente {
                            id: campoPasswordNuevaMovil
                            parent: Overlay.overlay
                            etiqueta: "Contraseña nueva"
                            esPassword: true
                            onAceptado: (texto) => cajaPasswordNuevaMovil.valor = texto
                        }
                    }
                    BotonContorno {
                        text: "Cambiar contraseña"
                        onClicked: {
                            if (cajaPasswordActualMovil.valor.length === 0) {
                                ventana.mensajeErrorLogin = "Escribe tu contraseña actual.";
                                return;
                            }
                            if (cajaPasswordNuevaMovil.valor.length < 8) {
                                ventana.mensajeErrorLogin = "La contraseña nueva debe tener al menos 8 caracteres.";
                                return;
                            }
                            ventana.mensajeErrorLogin = "";
                            redcliente.cambiarPassword(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion,
                                                       cajaPasswordActualMovil.valor, cajaPasswordNuevaMovil.valor);
                        }
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        color: Tema.colorPeligro
                        font.pixelSize: 11 * Tema.escala
                        text: ventana.mensajeErrorLogin
                        visible: ventana.mensajeErrorLogin !== ""
                    }

                    BotonContorno {
                        text: "Cerrar sesión"
                        colorBorde: Tema.colorPeligro
                        // Gestionar la cuenta exige servidor -- ver el
                        // comentario gemelo en qml/Main.qml.
                        visible: !ventana.sesionOffline
                        onClicked: {
                            redcliente.cerrarSesion(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion);
                        }
                    }
                }

                // ── Progreso -- Fase M1, terminada 2026-09-01 (ver memoria
                // qt_mobile_progression_port_plan). Port directo del
                // Progreso de escritorio (Main.qml de qml/): XP/Nivel
                // arriba, marco actual + barra hacia el siguiente, roadmap
                // de todos los marcos abajo -- todo un solo bloque que
                // scrollea junto con el resto de la pestaña (sin scroll
                // anidado propio, mismo criterio ya revertido en
                // escritorio el mismo día: "una pagina con el progreso y
                // roadmap todo scrolleable como conjunto es mejor"). Sin
                // caso "invitado" -- ya lo cubre el aviso a nivel de toda
                // la pantalla Cuenta, más arriba.
                Column {
                    width: parent.width
                    visible: ventana.pestanaCuentaActual === 1
                    spacing: 20 * Tema.escala

                    Row {
                        width: parent.width
                        spacing: 16 * Tema.escala
                        AnilloNivel {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 64 * Tema.escala
                            height: width
                            nivel: ventana.progresoNivelActual.nivel
                            fraccion: ventana.progresoNivelActual.xpEnNivel / Math.max(1, ventana.progresoNivelActual.xpParaSiguiente)
                        }
                        Text {
                            width: parent.width - 64 * Tema.escala - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            wrapMode: Text.WordWrap
                            text: ventana.progresoNivelActual.xpEnNivel + " / " + ventana.progresoNivelActual.xpParaSiguiente + " XP para el siguiente nivel"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 11 * Tema.escala
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 10 * Tema.escala

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 72 * Tema.escala * 2.1
                            height: width
                            Avatar {
                                anchors.centerIn: parent
                                letra: ventana.nombreJugador.length > 0 ? ventana.nombreJugador.charAt(0).toUpperCase() : "?"
                                tamano: 72 * Tema.escala
                                marco: Tema.marcoPorPartidasGanadas(ventana.statsPartidasGanadas, ventana.statsTieneMarcoBasico)
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

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Marco actual: " + ventana.nombreMarco(Tema.marcoPorPartidasGanadas(ventana.statsPartidasGanadas, ventana.statsTieneMarcoBasico))
                            color: Tema.colorTexto
                            font.bold: true
                            font.pixelSize: 14 * Tema.escala
                        }

                        Column {
                            width: parent.width
                            visible: ventana.statsPartidasGanadas < 50
                            spacing: 6 * Tema.escala
                            Row {
                                width: parent.width
                                Text {
                                    width: parent.width - 140 * Tema.escala
                                    text: "Siguiente: " + ventana.nombreProximoMarco(ventana.statsPartidasGanadas, ventana.statsTieneMarcoBasico)
                                    color: Tema.colorTextoTenue
                                    font.pixelSize: 11 * Tema.escala
                                }
                                Text {
                                    width: 140 * Tema.escala
                                    horizontalAlignment: Text.AlignRight
                                    text: ventana.statsPartidasGanadas + " / " + ventana.proximoUmbralMarco(ventana.statsPartidasGanadas, ventana.statsTieneMarcoBasico) + " victorias"
                                    color: Tema.colorTexto
                                    font.bold: true
                                    font.pixelSize: 11 * Tema.escala
                                }
                            }
                            Rectangle {
                                id: pistaProgresoMarcoMovil
                                width: parent.width
                                height: 7 * Tema.escala
                                radius: height / 2
                                color: Qt.rgba(1, 1, 1, 0.08)
                                Rectangle {
                                    width: pistaProgresoMarcoMovil.width * Math.min(1.0,
                                        (ventana.statsPartidasGanadas - ventana.umbralAnteriorMarco(ventana.statsPartidasGanadas)) /
                                        Math.max(1, ventana.proximoUmbralMarco(ventana.statsPartidasGanadas, ventana.statsTieneMarcoBasico) - ventana.umbralAnteriorMarco(ventana.statsPartidasGanadas)))
                                    height: parent.height
                                    radius: parent.radius
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: Qt.lighter(Tema.colorAccent, 1.3) }
                                        GradientStop { position: 1.0; color: Tema.colorAccent }
                                    }
                                    // Sin dithering: cuando está activo esto es un
                                    // botón DORADO, y los dorados van limpios
                                    // (2026-09-09) -- ver BotonRelleno.qml.
                                }
                            }
                        }
                        Text {
                            width: parent.width
                            visible: ventana.statsPartidasGanadas >= 50
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: "Has desbloqueado el marco más alto: Platino."
                            color: Tema.colorAccent
                            font.bold: true
                            font.pixelSize: 12 * Tema.escala
                        }
                        Text {
                            width: parent.width
                            visible: ventana.statsPartidasJugadas === 0
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: "Gana partidas oficiales (con otras personas reales) para avanzar de marco."
                            color: Tema.colorTextoTenue
                            font.pixelSize: 11 * Tema.escala
                        }
                    }

                    // ── Roadmap de marcos: TODOS los tiers a la vez, mismo
                    // criterio que escritorio.
                    Column {
                        width: parent.width
                        spacing: 14 * Tema.escala

                        Text {
                            text: "Todos los marcos"
                            color: Tema.colorTexto
                            font.bold: true
                            font.pixelSize: 14 * Tema.escala
                        }

                        Column {
                            width: parent.width
                            spacing: 8 * Tema.escala

                            Repeater {
                                model: [
                                    { tier: "hierro",  etiqueta: "Hierro",  umbral: 1 },
                                    { tier: "bronce",  etiqueta: "Bronce",  umbral: 5 },
                                    { tier: "plata",   etiqueta: "Plata",   umbral: 15 },
                                    { tier: "oro",     etiqueta: "Oro",     umbral: 25 },
                                    { tier: "platino", etiqueta: "Platino", umbral: 50 }
                                ]
                                delegate: Item {
                                    id: filaMarcoRoadmapMovil
                                    required property var modelData
                                    width: parent.width
                                    height: 64 * Tema.escala
                                    readonly property bool conseguido: filaMarcoRoadmapMovil.modelData.tier === "hierro"
                                        ? (ventana.statsPartidasGanadas >= 1 || ventana.statsTieneMarcoBasico)
                                        : ventana.statsPartidasGanadas >= filaMarcoRoadmapMovil.modelData.umbral

                                    Row {
                                        // Margen izquierdo -- el anillo del
                                        // Avatar sangra un 16% más allá de
                                        // su propio tamano (ver Avatar.qml),
                                        // sin esto se recorta contra el
                                        // borde del ScrollView (mismo bug
                                        // ya arreglado en escritorio).
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10 * Tema.escala
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 12 * Tema.escala

                                        Avatar {
                                            anchors.verticalCenter: parent.verticalCenter
                                            letra: ventana.nombreJugador.length > 0 ? ventana.nombreJugador.charAt(0).toUpperCase() : "?"
                                            tamano: 46 * Tema.escala
                                            marco: filaMarcoRoadmapMovil.modelData.tier
                                        }
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 46 * Tema.escala - 76 * Tema.escala - 2 * parent.spacing
                                            spacing: 5 * Tema.escala
                                            Text {
                                                text: filaMarcoRoadmapMovil.modelData.etiqueta
                                                color: filaMarcoRoadmapMovil.conseguido ? Tema.colorTexto : Tema.colorTextoTenue
                                                font.bold: true
                                                font.pixelSize: 12 * Tema.escala
                                            }
                                            Rectangle {
                                                width: parent.width
                                                height: 6 * Tema.escala
                                                radius: height / 2
                                                color: Qt.rgba(1, 1, 1, 0.08)
                                                Rectangle {
                                                    width: parent.width * Math.min(1.0, ventana.statsPartidasGanadas / filaMarcoRoadmapMovil.modelData.umbral)
                                                    height: parent.height
                                                    radius: parent.radius
                                                    color: filaMarcoRoadmapMovil.conseguido ? Tema.colorAccent : Qt.lighter(Tema.colorAccent, 1.3)
                                                }
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 76 * Tema.escala
                                            horizontalAlignment: Text.AlignRight
                                            text: filaMarcoRoadmapMovil.conseguido ? "Conseguido" : (ventana.statsPartidasGanadas + " / " + filaMarcoRoadmapMovil.modelData.umbral)
                                            color: filaMarcoRoadmapMovil.conseguido ? Tema.colorAccent : Tema.colorTextoTenue
                                            font.pixelSize: 10 * Tema.escala
                                            font.bold: filaMarcoRoadmapMovil.conseguido
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Logros -- Fase M1, terminada 2026-09-01 (ver memoria
                // qt_mobile_progression_port_plan). Port directo del
                // catálogo de escritorio: se muestran TODOS, desbloqueados
                // o no (atenuados si no) -- la idea es que se vea qué se
                // puede conseguir y cómo, no solo lo ya logrado.
                Column {
                    width: parent.width
                    visible: ventana.pestanaCuentaActual === 2
                    spacing: 12 * Tema.escala

                    Text {
                        text: ventana.logrosDesbloqueados() + " / " + logrosModel.count + " desbloqueados"
                        color: Tema.colorTextoTenue
                        font.pixelSize: 11 * Tema.escala
                    }

                    Repeater {
                        model: logrosModel
                        delegate: Rectangle {
                            id: tarjetaLogroMovil
                            required property string codigo
                            required property string rareza
                            required property int xpRecompensa
                            required property int desbloqueado
                            required property int desbloqueadoEn
                            required property string nombre
                            required property string descripcion

                            width: parent ? parent.width : 0
                            height: filaLogroMovil.height + 20 * Tema.escala
                            radius: 8 * Tema.escala
                            opacity: desbloqueado ? 1.0 : 0.55
                            border.width: 1
                            border.color: desbloqueado ? ventana.colorRareza(rareza) : Qt.rgba(1, 1, 1, 0.12)
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
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
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 4 * Tema.escala
                                radius: 3 * Tema.escala
                                color: ventana.colorRareza(tarjetaLogroMovil.rareza)
                            }

                            Row {
                                id: filaLogroMovil
                                anchors.left: parent.left
                                anchors.leftMargin: 16 * Tema.escala
                                anchors.right: parent.right
                                anchors.rightMargin: 14 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12 * Tema.escala

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 34 * Tema.escala
                                    height: width
                                    radius: width / 2
                                    color: tarjetaLogroMovil.desbloqueado ? ventana.colorRareza(tarjetaLogroMovil.rareza) : "transparent"
                                    border.width: 1.5
                                    border.color: ventana.colorRareza(tarjetaLogroMovil.rareza)
                                    Text {
                                        anchors.centerIn: parent
                                        text: tarjetaLogroMovil.desbloqueado ? "✓" : tarjetaLogroMovil.rareza.charAt(0).toUpperCase()
                                        color: tarjetaLogroMovil.desbloqueado ? Tema.colorFondo : ventana.colorRareza(tarjetaLogroMovil.rareza)
                                        font.bold: true
                                        font.pixelSize: 14 * Tema.escala
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 34 * Tema.escala - 12 * Tema.escala - 60 * Tema.escala - 12 * Tema.escala
                                    spacing: 3 * Tema.escala

                                    Row {
                                        width: parent.width
                                        spacing: 6 * Tema.escala
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: tarjetaLogroMovil.nombre
                                            color: Tema.colorTexto
                                            font.bold: true
                                            font.pixelSize: 12 * Tema.escala
                                        }
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: etiquetaRarezaTextoMovil.width + 10 * Tema.escala
                                            height: 14 * Tema.escala
                                            radius: height / 2
                                            color: "transparent"
                                            border.width: 1
                                            border.color: ventana.colorRareza(tarjetaLogroMovil.rareza)
                                            Text {
                                                id: etiquetaRarezaTextoMovil
                                                anchors.centerIn: parent
                                                text: ventana.etiquetaRareza(tarjetaLogroMovil.rareza)
                                                color: ventana.colorRareza(tarjetaLogroMovil.rareza)
                                                font.pixelSize: 8 * Tema.escala
                                                font.bold: true
                                            }
                                        }
                                    }
                                    Text {
                                        width: parent.width
                                        text: tarjetaLogroMovil.descripcion
                                        color: Tema.colorTextoTenue
                                        font.pixelSize: 10 * Tema.escala
                                        wrapMode: Text.WordWrap
                                    }
                                    Text {
                                        visible: tarjetaLogroMovil.desbloqueado === 1
                                        text: "Desbloqueado el " +
                                              Qt.formatDate(new Date(tarjetaLogroMovil.desbloqueadoEn * 1000), "d MMM yyyy") +
                                              " · +" + tarjetaLogroMovil.xpRecompensa + " XP"
                                        color: ventana.colorRareza(tarjetaLogroMovil.rareza)
                                        font.pixelSize: 9 * Tema.escala
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 60 * Tema.escala
                                    horizontalAlignment: Text.AlignRight
                                    visible: tarjetaLogroMovil.desbloqueado !== 1
                                    text: ventana.progresoLogro(tarjetaLogroMovil.codigo)
                                    color: Tema.colorTextoTenue
                                    font.pixelSize: 10 * Tema.escala
                                }
                            }
                        }
                    }
                }

            }
        }

        // ── Personalizar (pestaña 3) -- layout propio, FUERA del
        // ScrollView de arriba (2026-09-02, pedido explícito: "mismo
        // principio que en PC, a la hora de... personalizar el avatar
        // tiene que ser visible... ponlo a la derecha, los elementos a
        // la izquierda y scrolleables" + "el segundo slider [Texturas/
        // Efectos/Decoraciones/Títulos]... hay que hacer un mini riel
        // para estas cosas en movil, para aprovechar la horizontal,
        // pero no comernos altura"). Antes todo apilado en una Column
        // (mini-selector horizontal + avatar arriba + rejilla debajo)
        // dentro del mismo ScrollView que Perfil/Progreso/Logros -- el
        // avatar se salía de la pantalla al bajar en la rejilla, y el
        // SelectorSegmentado de 4 opciones quedaba apretado incluso en
        // escritorio. Ahora: mini-riel vertical (categoría) + rejilla
        // (scrollea sola) a la izquierda, avatar fijo a la derecha --
        // ambos Items, no Column, para que la rejilla pueda anclarse al
        // alto disponible y scrollear de forma nativa.
        Item {
            id: panelPersonalizarMovil
            visible: ventana.pantalla === "Cuenta" && ventana.hayCuenta && ventana.pestanaCuentaActual === 3
            anchors.fill: parent
            anchors.margins: 16 * Tema.escala
            // Vertical a 8 en vez de 16 (2026-09-10): la columna del
            // mini-riel mide 208 en unidades de escala y en un móvil
            // apaisado le quedaban 212 de alto -- dos de holgura, y el
            // brillo del botón activo sale bastante más que eso. Con los
            // 16 de más, el riel respira. Los márgenes laterales se quedan
            // en 16, como en Tienda.
            anchors.topMargin: 8 * Tema.escala
            anchors.bottomMargin: 8 * Tema.escala

            // (Sin Text de mensajeTienda aquí -- bug real reportado
            // 2026-09-02: "el mensaje tambien aparece en la
            // personalizacion, ya que antes teniamos esa funcionalidad
            // implementada por error". Confirmado, mismo motivo que en
            // escritorio (ver el comentario ahí): resto de cuando
            // Personalizar compraba de verdad, antes de que Tienda saliera
            // a su propia pantalla -- Personalizar solo equipa, un error
            // de COMPRA no tiene nada que hacer aquí, y al compartir la
            // property con Tienda se quedaba pegado sin que nada de esta
            // pestaña lo limpiara.)
            Row {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 14 * Tema.escala

                // Mini-riel vertical de categoría -- mismo lenguaje visual
                // que rielNavegacionMovil (caja redondeada, realce de
                // acento cuando está activa) a tamaño reducido, en vez
                // del SelectorSegmentado horizontal de antes. Panel de
                // fondo NUEVO (2026-09-02, pedido explícito: "aun se ve
                // muy suelto, no se reconoce como una columna de
                // pestañas") -- antes los 4 botones flotaban sueltos
                // directo sobre el fondo de la pantalla; ahora viven
                // DENTRO de una caja propia (mismo degradado/borde que
                // rielNavegacionMovil, el riel principal) que los agrupa
                // visualmente en una sola tira, igual que ese riel agrupa
                // sus propios iconos.
                // Sin tarjeta propia (2026-09-10, pedido explícito: "quita las
                // tarjetas hermanas... deja que eso flote en la pestaña
                // principal", igual que en Tienda). Tuvo una hasta ese día, con
                // capa de dithering, y esa capa era la que cortaba los botones
                // "por arriba y por abajo": layer.enabled pinta a sus hijos en una
                // textura del tamaño del item, así que lo que sobresale se pierde,
                // y el brillo del botón activo sobresale de sobra. Ahora es un Item
                // sin capa y sin clip: nada lo recorta.
                Item {
                    id: minirielPersonalizarMovil
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: columnaMinirielMovil.width + 16 * Tema.escala

                    Column {
                        id: columnaMinirielMovil
                        anchors.centerIn: parent
                        width: 76 * Tema.escala
                        spacing: 8 * Tema.escala
                        Repeater {
                            model: ["Texturas", "Efectos", "Decoraciones", "Títulos"]
                            // "Ficha de casino" (2026-09-02, diseño A elegido por
                            // el usuario tras el artifact "Tarjetas de Mesa
                            // Real") -- activo usa EL MISMO degradado metálico
                            // de 3 paradas que BotonRelleno ("Iniciar sesión"),
                            // no un relleno plano nuevo. Envuelto en un Item
                            // (antes el Rectangle era la raíz del delegate) para
                            // poder meter la sombra desplazada detrás sin que
                            // escale junto con el botón.
                            delegate: Item {
                                id: envolturaMinirielMovil
                                required property string modelData
                                required property int index
                                readonly property bool activo: envolturaMinirielMovil.index === ventana.pestanaPersonalizarActual
                                width: columnaMinirielMovil.width
                                height: Math.max(Tema.tamanoMinTactil, 46 * Tema.escala)

                            // Sombra -- el inactivo queda a ras (sin
                            // sombra) para que el realce se note por
                            // contraste, no solo por color. El activo NO
                            // lleva esta sombra plana -- lleva el brillo
                            // dorado de verdad de abajo (MultiEffect).
                            Rectangle {
                                visible: !envolturaMinirielMovil.activo && areaMinirielMovil.pressed
                                anchors.fill: parent
                                anchors.topMargin: 3 * Tema.escala
                                radius: 10 * Tema.escala
                                color: "black"
                                opacity: 0.35
                            }

                            // Brillo dorado de verdad alrededor del botón
                            // activo (2026-09-02, pedido explícito tras ver
                            // el artifact: "en el riel hay bastante
                            // diferencia... se simula un brillo desde el
                            // boton"). autoPaddingEnabled reserva sitio de
                            // sobra para que el resplandor no se recorte
                            // contra el propio Item (46*escala de alto).
                            MultiEffect {
                                anchors.centerIn: botonMinirielMovil
                                width: botonMinirielMovil.width
                                height: botonMinirielMovil.height
                                source: botonMinirielMovil
                                autoPaddingEnabled: true
                                shadowEnabled: true
                                shadowColor: Tema.colorAccent
                                shadowOpacity: envolturaMinirielMovil.activo ? 0.65 : 0
                                shadowBlur: 0.7
                                shadowHorizontalOffset: 0
                                shadowVerticalOffset: 0
                                Behavior on shadowOpacity { NumberAnimation { duration: 120 } }
                            }

                            Rectangle {
                                id: botonMinirielMovil
                                anchors.fill: parent
                                radius: 10 * Tema.escala
                                color: "transparent"
                                scale: areaMinirielMovil.pressed ? 0.96 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }
                                // Degradado + dithering en un Rectangle HIJO, no
                                // aquí -- ver el comentario largo en
                                // SelectorSegmentado.qml. Resumen: el MultiEffect
                                // de arriba usa "source: botonMinirielMovil", y
                                // ponerle layer.effect al propio item que otro
                                // efecto captura hace que el MultiEffect pinte su
                                // propia copia encogida encima. Aquí se veía peor
                                // que en el selector porque el botón lleva texto
                                // dentro: salía DOS VECES, a dos tamaños (bug real
                                // reportado 2026-09-09 con capturas -- "Texturas",
                                // "Efectos", "Decoraciones" y "Títulos"
                                // duplicados).
                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0.0
                                            color: envolturaMinirielMovil.activo ? Qt.lighter(Tema.colorAccent, 1.35) : Qt.rgba(1, 1, 1, 0.045)
                                        }
                                        GradientStop {
                                            position: 0.5
                                            color: envolturaMinirielMovil.activo ? Tema.colorAccent : Qt.rgba(0, 0, 0, 0.1)
                                        }
                                        GradientStop {
                                            position: 1.0
                                            color: envolturaMinirielMovil.activo ? Qt.darker(Tema.colorAccent, 1.2) : Qt.rgba(0, 0, 0, 0.2)
                                        }
                                    }
                                    // El borde va AQUÍ, no en el padre: un
                                    // Rectangle pinta su borde antes que a
                                    // sus hijos, así que un hijo que lo
                                    // llena entero se lo comería.
                                    border.width: 1
                                    // Antes rgba(1,1,1,.35) -- blanco puro sobre
                                    // dorado se veía como un anillo grisáceo
                                    // (bug real reportado 2026-09-02). Un dorado
                                    // más claro que el propio relleno, no blanco.
                                    border.color: envolturaMinirielMovil.activo ? Qt.lighter(Tema.colorAccent, 1.6) : Tema.colorBorde
                                    // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                                    layer.enabled: true
                                    layer.effect: ShaderEffect {
                                        property variant source
                                        property real amplitud: 3.0
                                        fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - 8 * Tema.escala
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    text: envolturaMinirielMovil.modelData
                                    font.bold: envolturaMinirielMovil.activo
                                    color: envolturaMinirielMovil.activo ? Tema.colorPanel : Tema.colorTextoTenue
                                    font.pixelSize: 10 * Tema.escala
                                }
                                MouseArea {
                                    id: areaMinirielMovil
                                    anchors.fill: parent
                                    onClicked: ventana.pestanaPersonalizarActual = envolturaMinirielMovil.index
                                }
                            }
                        }
                    }
                } // fin de columnaMinirielMovil
                } // fin de minirielPersonalizarMovil

                // Catálogo de lo ya poseído -- llena el resto del alto
                // disponible y scrollea de forma nativa (GridView es un
                // Flickable), ya no comparte scroll con el avatar.
                Item {
                    id: columnaGridPersonalizarMovil
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width - minirielPersonalizarMovil.width - columnaPreviewPersonalizarMovil.width - parent.spacing * 2

                    Text {
                        anchors.top: parent.top
                        width: parent.width
                        visible: ventana.itemsPersonalizar.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "Todavía no tienes nada de esto -- consíguelo en la Tienda."
                        color: Tema.colorTextoTenue
                        font.pixelSize: 12 * Tema.escala
                    }
                    GridView {
                        id: gridPersonalizarMovil
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        visible: ventana.itemsPersonalizar.length > 0
                        clip: true
                        // TODAS las categorías usan ya la tarjeta compacta
                        // (2026-09-02, pedido explícito: "las decoraciones
                        // ya estan bien hechas... en todos los cosmeticos
                        // debe ser igual") -- antes solo Decoraciones,
                        // Texturas/Efectos/Títulos se habían quedado con
                        // la tarjeta grande de botón, "se ven feos".
                        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / (92 * Tema.escala))))
                        cellHeight: 92 * Tema.escala
                        model: ventana.itemsPersonalizar
                        delegate: Item {
                            id: celdaPersonalizarMovil
                            required property string codigo
                            required property string categoria
                            required property string nombre
                            required property string rareza
                            required property int equipado
                            width: gridPersonalizarMovil.cellWidth
                            height: gridPersonalizarMovil.cellHeight

                            // "Ficha de casino" (2026-09-02, diseño A
                            // elegido por el usuario tras el artifact
                            // "Tarjetas de Mesa Real") -- sombra desplazada
                            // barata (mismo criterio que BarraSuperior.qml),
                            // SIN escalar con la tarjeta.
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 5 * Tema.escala
                                anchors.topMargin: 5 * Tema.escala + 3 * Tema.escala
                                radius: 8 * Tema.escala
                                color: "black"
                                opacity: 0.35
                            }

                            Rectangle {
                                id: tarjetaPersonalizarMovil
                                anchors.fill: parent
                                anchors.margins: 5 * Tema.escala
                                radius: 8 * Tema.escala
                                // Tarjeta compacta, sin botones, se toca
                                // para equipar/desequipar -- pedido
                                // explícito 2026-09-02: "quita el boton...
                                // pulsando encima añade una animacion
                                // igual a la tienda... la diferencia de
                                // brillo... es lenguaje no textual
                                // suficiente... en todos los cosmeticos
                                // debe ser igual" (antes solo Decoraciones,
                                // ahora las 4 categorías por igual).
                                // Bug real reportado 2026-09-02: "la caja
                                // se queda igual, solo se desequipa" -- el
                                // borde de "no equipado" copiaba el de "no
                                // poseído" de la Tienda (negro
                                // semitransparente), que en tema oscuro se
                                // confunde con el fondo y parece que la
                                // tarjeta entera desaparece. Aquí TODO lo
                                // que se ve ya es tuyo (itemsPersonalizar
                                // solo lista poseído===1) -- el borde
                                // SIEMPRE debe notarse, solo cambia de
                                // intensidad según esté puesto o no.
                                border.width: celdaPersonalizarMovil.equipado ? 1.8 : 1.2
                                border.color: celdaPersonalizarMovil.equipado ? Tema.colorAccent : Qt.darker(Tema.colorAccent, 1.8)
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
                                    fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
                                }
                                // Mismo encogido reactivo que la Tienda al
                                // tocar.
                                scale: areaTogglePersonalizarMovil.pressed ? 0.97 : 1.0
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
                                                           celdaPersonalizarMovil.equipado ? 0.55 : 0.28)
                                }

                                // Toca la tarjeta entera para equipar/
                                // desequipar. Lateral no elige lado a
                                // mano: si ya está puesta (en cualquiera de
                                // los dos huecos) la quita; si no, va al
                                // primer hueco libre (o sobreescribe el
                                // izquierdo si los dos están ocupados) --
                                // mismo criterio de reparto que ya usa
                                // adminConcederItem(). El resto de
                                // categorías (un único hueco) alterna
                                // Equipar/Quitar sin más.
                                MouseArea {
                                    id: areaTogglePersonalizarMovil
                                    anchors.fill: parent
                                    onClicked: {
                                        if (celdaPersonalizarMovil.categoria === "decoracion_lateral") {
                                            var enIzq = redcliente.loadoutMarco.decoracionLateral1 === celdaPersonalizarMovil.codigo;
                                            var enDer = redcliente.loadoutMarco.decoracionLateral2 === celdaPersonalizarMovil.codigo;
                                            if (enIzq) {
                                                redcliente.equiparObjeto(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion,
                                                    "decoracion_lateral_1", "");
                                            } else if (enDer) {
                                                redcliente.equiparObjeto(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion,
                                                    "decoracion_lateral_2", "");
                                            } else {
                                                var libre1 = (redcliente.loadoutMarco.decoracionLateral1 || "") === "";
                                                var libre2 = (redcliente.loadoutMarco.decoracionLateral2 || "") === "";
                                                var slotDestino = libre1 ? "decoracion_lateral_1" : (libre2 ? "decoracion_lateral_2" : "decoracion_lateral_1");
                                                ventana.equiparConAcabado(slotDestino, celdaPersonalizarMovil.codigo);
                                            }
                                        } else {
                                            ventana.equiparConAcabado(celdaPersonalizarMovil.categoria,
                                                celdaPersonalizarMovil.equipado === 1 ? "" : celdaPersonalizarMovil.codigo);
                                        }
                                    }
                                }

                                // Icono + nombre corto, sin texto de estado
                                // ni botón -- el brillo del borde de arriba
                                // ya dice si está puesto. Títulos no tienen
                                // icono (rutaIconoObjetoTienda() nunca
                                // devuelve uno para "titulo") -- en su
                                // lugar el propio nombre se pinta con el
                                // mismo lenguaje "material" que CajaTitulo
                                // (color por rareza, cursiva), para que la
                                // tarjeta no se quede con un hueco vacío
                                // arriba.
                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - 10 * Tema.escala
                                    spacing: 4 * Tema.escala
                                    Image {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: source !== ""
                                        width: visible ? 38 * Tema.escala : 0
                                        height: width
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        // mipmap aunque sea pequeña: Qt comparte la textura de un
                                        // PNG entre todas las Image que lo cargan -- ver el
                                        // comentario gemelo en qml/Main.qml.
                                        mipmap: true
                                        source: ventana.rutaIconoObjetoTienda(celdaPersonalizarMovil.codigo, celdaPersonalizarMovil.categoria)
                                    }
                                    // Nombre normal (todo salvo títulos).
                                    Text {
                                        visible: celdaPersonalizarMovil.categoria !== "titulo"
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: celdaPersonalizarMovil.nombre
                                        color: Tema.colorTexto
                                        font.pixelSize: 10 * Tema.escala
                                    }
                                    // Títulos: mismo lenguaje "material" que
                                    // CajaTitulo (color por rareza, cursiva,
                                    // fuente elegante) -- sin esto se
                                    // quedaban con un nombre gris igual que
                                    // cualquier otro objeto, perdiendo la
                                    // identidad visual que ya tienen en el
                                    // resto de la app.
                                    Text {
                                        visible: celdaPersonalizarMovil.categoria === "titulo"
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: celdaPersonalizarMovil.nombre
                                        color: ventana.colorRareza(celdaPersonalizarMovil.rareza)
                                        font.italic: true
                                        font.family: Tema.fuenteElegante
                                        font.pixelSize: 11 * Tema.escala
                                    }
                                }
                            }
                        }
                    }
                }

                // Avatar fijo a la derecha, con el loadout REAL (sin
                // previsualización -- no hay "hover" táctil).
                Column {
                    id: columnaPreviewPersonalizarMovil
                    anchors.top: parent.top
                    width: 180 * Tema.escala
                    spacing: 12 * Tema.escala

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "TU AVATAR"
                        color: Tema.colorTextoMuyTenue
                        font.pixelSize: 10 * Tema.escala
                        font.letterSpacing: 1
                    }
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 80 * Tema.escala * 2.1
                        height: 80 * Tema.escala + 50 * Tema.escala
                        Avatar {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            letra: ventana.nombreJugador.length > 0 ? ventana.nombreJugador.charAt(0).toUpperCase() : "?"
                            tamano: 80 * Tema.escala
                            marco: Tema.marcoPorPartidasGanadas(ventana.statsPartidasGanadas, ventana.statsTieneMarcoBasico)
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
                    CajaTitulo {
                        anchors.horizontalCenter: parent.horizontalCenter
                        readonly property var infoTituloPropioMovil: ventana.objetoTiendaPorCodigo(redcliente.loadoutMarco.titulo || "")
                        nombre: infoTituloPropioMovil ? infoTituloPropioMovil.nombre : ""
                        colorTier: ventana.colorRareza(infoTituloPropioMovil ? infoTituloPropioMovil.rareza : "")
                    }
                }
            }
        }
    }

    // ── Pantalla Tienda (Fase M2 del port de progresión a móvil,
    // 2026-09-01, ver memoria qt_mobile_progression_port_plan) -- pantalla
    // propia en el riel, port directo de escritorio (catálogo con
    // búsqueda + selector de carta + comprar/equipar), mismo criterio
    // "cabecera fija, panel con scroll" que Cuenta. Diferencia deliberada
    // (mismo criterio ya fijado en Personalizar, Fase M1): SIN
    // previsualización al tocar una tarjeta -- no hay "hover" táctil, el
    // avatar de arriba pinta directo el loadout REAL, no lo que estés
    // mirando. Apilado (avatar arriba, catálogo debajo) en vez del Row
    // lateral de escritorio -- el panel es más estrecho en móvil, mismo
    // criterio que Personalizar.
    BarraSuperior {
        id: barraTiendaMovil
        visible: ventana.pantalla === "Tienda"
        anchors.top: parent.top
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        textoCentro: "Tienda"
        // Saldo de Tréboles en la barra superior, junto a Ajustes --
        // mejor sitio que dentro del catálogo (pedido explícito
        // 2026-09-02). -1 mientras no hay sesión (invitado no compra).
        treboles: ventana.tokenSesion !== "" ? ventana.statsTreboles : -1
        onAbrirAjustes: ventana.ajustesAbiertos = !ventana.ajustesAbiertos
    }
    // ── Tienda: invitados ven un aviso + acceso a login/registro, mismo
    // criterio que Cuenta/Social. ────────────────────────────────────────
    Column {
        visible: ventana.pantalla === "Tienda" && ventana.tokenSesion === ""
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: rielNavegacionMovil.width / 2
        spacing: 12 * Tema.escala
        width: Math.min(340 * Tema.escala, ventana.width - rielNavegacionMovil.width - 60 * Tema.escala)

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Inicia sesión para entrar en la tienda."
            color: Tema.colorTextoTenue
            font.pixelSize: 13 * Tema.escala
        }
        BotonRelleno {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Iniciar sesión"
            onClicked: { ventana.mensajeErrorLogin = ""; ventana.pantalla = "Login"; }
        }
        BotonContorno {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Crear cuenta"
            onClicked: { ventana.mensajeErrorLogin = ""; ventana.pantalla = "Registro"; }
        }
    }

    // Selector Marco/Perfil FIJO, fuera del ScrollView -- mismo criterio
    // que tabsCuentaMovil. Sin título "Tienda" (pedido explícito
    // 2026-09-02: "borra el titulo superior asi ganamos altura, el
    // titulo ya lo incluye la barra superior") -- barraTiendaMovil ya
    // dice "Tienda" en su textoCentro, era el mismo texto dos veces.
    // El buscador comparte fila con el selector Marco/Perfil en vez de
    // ocupar una suya dentro del panel (pedido explícito 2026-09-09: "el
    // móvil tiene poca altura, vamos a esconder la barra de búsqueda en un
    // botón para desplegar cuando se necesite"). Así el buscador pasa a
    // costar CERO alto: la fila ya existía.
    //
    // La lupa se pinta rellena cuando hay una búsqueda puesta -- sin la
    // caja a la vista, es lo único que delata que el catálogo está
    // filtrado, y "no encuentro un objeto que sé que tengo" por un filtro
    // olvidado sería un mal rato tonto. Pulsarla reabre el campo con el
    // texto dentro, así que vaciarlo y aceptar es cómo se quita.
    Row {
        id: cabeceraTiendaMovil
        visible: ventana.pantalla === "Tienda" && ventana.tokenSesion !== ""
        anchors.top: barraTiendaMovil.bottom
        anchors.topMargin: 10 * Tema.escala
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        spacing: 8 * Tema.escala

        SelectorSegmentado {
            width: parent.width - botonBusquedaTiendaMovil.width - parent.spacing
            opciones: ["Marco", "Perfil"]
            seleccionado: ventana.pestanaTiendaActual
            onElegido: (indice) => {
                ventana.pestanaTiendaActual = indice;
                // Mismo bug real que escritorio 2026-09-02 ("el mensaje no
                // desaparece"): un error de compra/equipar se quedaba
                // pegado al cambiar de Marco a Perfil (o viceversa).
                ventana.mensajeTienda = "";
                ventana.reordenarTienda();
            }
        }

        MarcoRelieve {
            id: botonBusquedaTiendaMovil
            readonly property bool filtrando: ventana.busquedaTienda !== ""
            width: Tema.tactil
            height: Tema.tactil
            radioMarco: 10 * Tema.escala
            pulsado: areaBusquedaTiendaMovil.pressed
            colorBase: botonBusquedaTiendaMovil.filtrando ? Tema.colorAccent : Tema.colorPanel

            IconoLupa {
                anchors.centerIn: parent
                width: 19 * Tema.escala
                height: width
                color: botonBusquedaTiendaMovil.filtrando ? Tema.colorPanel : Tema.colorAccent
            }
            MouseArea {
                id: areaBusquedaTiendaMovil
                anchors.fill: parent
                onClicked: campoBusquedaTiendaMovilPopup.abrir(ventana.busquedaTienda)
            }
            CampoEmergente {
                id: campoBusquedaTiendaMovilPopup
                parent: Overlay.overlay
                etiqueta: "Buscar en la tienda"
                onAceptado: (texto) => {
                    ventana.busquedaTienda = texto;
                    ventana.reordenarTienda();
                }
            }
        }
    }

    Rectangle {
        id: panelTiendaMovil
        visible: ventana.pantalla === "Tienda" && ventana.tokenSesion !== ""
        anchors.top: cabeceraTiendaMovil.bottom
        anchors.topMargin: 8 * Tema.escala
        anchors.left: rielNavegacionMovil.right
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16 * Tema.escala
        radius: 8 * Tema.escala
        // LISO a propósito, sin degradado ni textura de tapete
        // (2026-09-09, pedido explícito): "en los sitios que tengan fondo
        // tapete y encima tarjetas con textura tapete, el fondo sea sin
        // esa textura, resalta las tarjetas y se diferencia mejor". Este
        // panel es justo eso -- el fondo sobre el que van las tarjetas de
        // amigos / objetos / estadísticas, que sí llevan su fieltro.
        //
        // Antes de llegar aquí pasó por dos intentos que sobran, pero que
        // conviene no repetir: un degradado corto SIN dithering (bandeó, y
        // el escalón se veía como "una línea drástica de cambio de color"
        // cruzando la tarjeta) y luego uno con dithering en un hijo. El
        // segundo funcionaba; simplemente, liso queda mejor.
        color: Tema.colorPanel
        border.width: 1
        border.color: Tema.colorBorde

        // Avatar fijo a la DERECHA, catálogo a la izquierda y scrolleable
        // dentro de sí mismo -- mismo principio que escritorio (2026-09-02,
        // pedido explícito: "a la hora de comprar o personalizar el avatar
        // tiene que ser visible... ponlo a la derecha, los elementos a la
        // izquierda y scrolleables"). Antes todo apilado en una única
        // Column dentro de un ScrollView -- en landscape móvil, con menos
        // alto que una ventana de escritorio, el avatar se salía de la
        // pantalla en cuanto el catálogo crecía un poco.
        Item {
            anchors.fill: parent
            anchors.margins: 16 * Tema.escala

            Row {
                anchors.fill: parent
                spacing: 16 * Tema.escala

                Item {
                    id: columnaCatalogoTiendaMovil
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width - columnaPreviewTiendaMovil.width - parent.spacing

                    Column {
                        id: cabeceraCatalogoTiendaMovil
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 8 * Tema.escala

                        // La caja de búsqueda vivía AQUÍ y se comía una fila
                        // entera (suelo táctil de 44px + separación) encima
                        // del catálogo. Desde 2026-09-09 es un botón de lupa
                        // en cabeceraTiendaMovil, compartiendo fila con el
                        // selector Marco/Perfil -- ver allí el porqué. Esta
                        // Column se queda solo con el mensaje de error, que
                        // casi siempre está vacío y entonces no ocupa alto.

                        Text {
                            width: parent.width
                            visible: ventana.mensajeTienda !== ""
                            wrapMode: Text.WordWrap
                            color: Tema.colorPeligro
                            text: ventana.mensajeTienda
                            font.pixelSize: 11 * Tema.escala
                        }
                    }

                // Catálogo en tarjetas -- mismo lenguaje visual que
                // gridPersonalizarMovil, con precio/nivel y el botón
                // Comprar que Personalizar no necesita. Llena el resto del
                // alto disponible y scrollea de forma nativa (ya no
                // comparte scroll con el avatar de al lado).
                GridView {
                    id: gridTiendaMovil
                    anchors.top: cabeceraCatalogoTiendaMovil.bottom
                    anchors.topMargin: 10 * Tema.escala
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    clip: true
                    cellWidth: Math.floor(width / Math.max(1, Math.floor(width / (190 * Tema.escala))))
                    // 156 → 104*escala (2/3, pedido explícito 2026-09-02)
                    // -- solo hizo falta bajarla tanto porque el merge de
                    // nombre+precio/nivel en una línea (ver más abajo)
                    // libera una fila entera.
                    cellHeight: 104 * Tema.escala
                    model: tiendaModel
                    delegate: Item {
                        id: celdaTiendaMovil
                        required property string codigo
                        required property string categoria
                        required property int precioTreboles
                        required property int nivelMinimo
                        required property int esDeLogro
                        required property int poseido
                        required property int equipado
                        required property string nombre
                        required property string logroNombre
                        width: gridTiendaMovil.cellWidth
                        height: gridTiendaMovil.cellHeight

                        // "Ficha de casino" (2026-09-02, diseño A elegido
                        // por el usuario tras el artifact "Tarjetas de Mesa
                        // Real") -- sombra desplazada barata (mismo
                        // criterio que BarraSuperior.qml), SIN escalar con
                        // la tarjeta: al hundirse en el tap, la sombra se
                        // queda fija y asoma más, como si se hundiera de
                        // verdad en el fieltro.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 5 * Tema.escala
                            anchors.topMargin: 5 * Tema.escala + 3 * Tema.escala
                            radius: 8 * Tema.escala
                            color: "black"
                            opacity: 0.35
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 5 * Tema.escala
                            radius: 8 * Tema.escala
                            border.width: celdaTiendaMovil.equipado ? 1.8 : (celdaTiendaMovil.poseido ? 1.2 : 1)
                            border.color: celdaTiendaMovil.equipado ? Tema.colorAccent
                                          : (celdaTiendaMovil.poseido ? Qt.darker(Tema.colorAccent, 1.8) : Qt.rgba(0, 0, 0, 0.4))
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
                                fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
                            }
                            // Se encoge mientras se toca -- pedido explícito
                            // 2026-09-02, "el equivalente" al encogido de
                            // escritorio al pasar el ratón por encima
                            // (mismos números: 0.97, 100ms).
                            scale: zonaTapPreviewMovil.pressed ? 0.97 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            // Hilo dorado por dentro del bisel exterior --
                            // el "doble bisel" de ficha de casino.
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2 * Tema.escala
                                radius: parent.radius - 2 * Tema.escala
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b,
                                                       celdaTiendaMovil.equipado ? 0.6 : (celdaTiendaMovil.poseido ? 0.32 : 0.14))
                            }

                            // Previsualización en vivo al TOCAR la tarjeta
                            // (no el botón Comprar/Equipar) -- se limpia sola
                            // al soltar, mismo criterio "sin estado pegajoso"
                            // que escritorio (ver ventana.valorPreview()).
                            // Declarada ANTES que la Column de contenido para
                            // quedar POR DEBAJO en el z-order -- los botones
                            // de dentro (con su propia MouseArea) siguen
                            // recibiendo su toque sin que esto se lo coma.
                            MouseArea {
                                id: zonaTapPreviewMovil
                                anchors.fill: parent
                                onPressed: {
                                    if (celdaTiendaMovil.codigo === "_baraja") {
                                        if (ventana.cartaSeleccionada === "") return;
                                        ventana.fijarPreview("decoracion_lateral", ventana.cartaSeleccionada);
                                        return;
                                    }
                                    ventana.fijarPreview(celdaTiendaMovil.categoria, celdaTiendaMovil.codigo);
                                }
                                onReleased: {
                                    var codigoDePreview = celdaTiendaMovil.codigo === "_baraja" ? ventana.cartaSeleccionada : celdaTiendaMovil.codigo;
                                    if (ventana.previewCodigo === codigoDePreview) {
                                        ventana.previewCodigo = "";
                                        ventana.previewCategoria = "";
                                    }
                                }
                                onCanceled: {
                                    var codigoDePreview = celdaTiendaMovil.codigo === "_baraja" ? ventana.cartaSeleccionada : celdaTiendaMovil.codigo;
                                    if (ventana.previewCodigo === codigoDePreview) {
                                        ventana.previewCodigo = "";
                                        ventana.previewCategoria = "";
                                    }
                                }
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 10 * Tema.escala
                                spacing: 4 * Tema.escala

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
                                    spacing: 6 * Tema.escala
                                    Image {
                                        id: miniaturaTiendaMovil
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: source !== ""
                                        width: visible ? 18 * Tema.escala : 0
                                        height: width
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        // mipmap aunque sea pequeña: Qt comparte la textura de un
                                        // PNG entre todas las Image que lo cargan -- ver el
                                        // comentario gemelo en qml/Main.qml.
                                        mipmap: true
                                        source: ventana.rutaIconoObjetoTienda(celdaTiendaMovil.codigo, celdaTiendaMovil.categoria)
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - miniaturaTiendaMovil.width - (miniaturaTiendaMovil.visible ? parent.spacing : 0)
                                               - (sufijoPrecioTiendaMovil.visible ? sufijoPrecioTiendaMovil.width + parent.spacing : 0)
                                        elide: Text.ElideRight
                                        text: celdaTiendaMovil.nombre + (celdaTiendaMovil.equipado === 1 ? " · Equipado" : "")
                                        color: Tema.colorTexto
                                        font.bold: true
                                        font.pixelSize: 12 * Tema.escala
                                    }
                                    Row {
                                        id: sufijoPrecioTiendaMovil
                                        visible: celdaTiendaMovil.esDeLogro === 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 3 * Tema.escala
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "· " + celdaTiendaMovil.precioTreboles
                                            color: Tema.colorTextoTenue
                                            font.pixelSize: 10.5 * Tema.escala
                                        }
                                        IconoTrebol {
                                            width: 8 * Tema.escala
                                            height: width
                                            anchors.verticalCenter: parent.verticalCenter
                                            colorTrebol: Tema.colorTextoTenue
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "· nivel " + celdaTiendaMovil.nivelMinimo
                                            color: Tema.colorTextoTenue
                                            font.pixelSize: 10.5 * Tema.escala
                                        }
                                    }
                                }
                                // Con cuál -- pedido explícito 2026-09-02:
                                // "ya no solo pondrá que se consigue con
                                // un logro, sino con cual".
                                Text {
                                    visible: celdaTiendaMovil.esDeLogro === 1
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: celdaTiendaMovil.logroNombre !== ""
                                          ? "Logro: " + celdaTiendaMovil.logroNombre
                                          : "Se consigue con un logro"
                                    color: Tema.colorTextoMuyTenue
                                    font.pixelSize: 10.5 * Tema.escala
                                }
                                // Código real del objeto, solo admin -- mismo
                                // criterio que escritorio.
                                Text {
                                    visible: ventana.statsEsAdmin === true
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: celdaTiendaMovil.codigo
                                    color: Tema.colorTextoMuyTenue
                                    font.family: "monospace"
                                    font.pixelSize: 9 * Tema.escala
                                }

                                Row {
                                    visible: celdaTiendaMovil.codigo === "_baraja"
                                    spacing: 6 * Tema.escala
                                    BotonContorno {
                                        text: "+"
                                        onClicked: popupSeleccionCartaMovil.open()
                                    }
                                    BotonContorno {
                                        readonly property var info: ventana.infoCartaSeleccionada()
                                        visible: ventana.cartaSeleccionada !== "" && info !== null && info.poseido === 0
                                        text: "Comprar"
                                        onClicked: redcliente.comprarObjeto(ventana.servidorHost, ventana.servidorPuerto,
                                                                            ventana.tokenSesion, ventana.cartaSeleccionada)
                                    }
                                    Row {
                                        readonly property var info: ventana.infoCartaSeleccionada()
                                        visible: ventana.cartaSeleccionada !== "" && info !== null && info.poseido === 1
                                        spacing: 4 * Tema.escala
                                        BotonContorno {
                                            readonly property bool aqui: redcliente.loadoutMarco.decoracionLateral1 === ventana.cartaSeleccionada
                                            text: aqui ? "Quitar izq." : "A la izq."
                                            colorBorde: aqui ? Tema.colorPeligro : Tema.colorBorde
                                            onClicked: redcliente.equiparObjeto(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion,
                                                "decoracion_lateral_1", aqui ? "" : ventana.cartaSeleccionada)
                                        }
                                        BotonContorno {
                                            readonly property bool aqui: redcliente.loadoutMarco.decoracionLateral2 === ventana.cartaSeleccionada
                                            text: aqui ? "Quitar der." : "A la der."
                                            colorBorde: aqui ? Tema.colorPeligro : Tema.colorBorde
                                            onClicked: redcliente.equiparObjeto(ventana.servidorHost, ventana.servidorPuerto, ventana.tokenSesion,
                                                "decoracion_lateral_2", aqui ? "" : ventana.cartaSeleccionada)
                                        }
                                    }
                                }
                                // Ancho completo de la tarjeta -- pedido
                                // explícito 2026-09-02: "el boton de
                                // comprar o quitar... se ve raro [en la
                                // esquina]... quedaria mejor... extendido
                                // a lo ancho de la tarjeta".
                                BotonContorno {
                                    visible: celdaTiendaMovil.codigo !== "_baraja" &&
                                             celdaTiendaMovil.poseido === 0 && celdaTiendaMovil.esDeLogro === 0
                                    width: parent.width
                                    text: "Comprar"
                                    onClicked: redcliente.comprarObjeto(ventana.servidorHost, ventana.servidorPuerto,
                                                                        ventana.tokenSesion, celdaTiendaMovil.codigo)
                                }
                                // "Comprado" -- estado final, visiblemente
                                // inactivo (2026-09-02, mismo pedido que en
                                // escritorio: "quitar en la tienda sobra...
                                // un boton que no funcione visiblemente
                                // inactivo que ponga comprado" --
                                // equipar/desequipar vive solo en
                                // Personalizar). Sustituye tanto al viejo
                                // botón Equipar/Quitar como al par izq./der.
                                // de decoraciones laterales.
                                BotonContorno {
                                    visible: celdaTiendaMovil.codigo !== "_baraja" && celdaTiendaMovil.poseido === 1
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

                // Avatar fijo a la derecha, con el loadout REAL (sin
                // previsualización -- ver comentario de arriba). Sibling
                // de columnaCatalogoTiendaMovil dentro del mismo Row, así
                // que nunca se mueve aunque el catálogo scrollee.
                Column {
                    id: columnaPreviewTiendaMovil
                    anchors.top: parent.top
                    width: 180 * Tema.escala
                    spacing: 12 * Tema.escala

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "VISTA PREVIA"
                        color: Tema.colorTextoMuyTenue
                        font.pixelSize: 10 * Tema.escala
                        font.letterSpacing: 1
                    }
                    // Toca cualquier tarjeta del catálogo para ver cómo
                    // quedaría -- ventana.valorPreview() de siempre (tocar
                    // una tarjeta = se ve al momento aquí; soltar = vuelve
                    // a lo que ya llevas puesto de verdad). "_baraja" fuera
                    // -- previsualiza la carta ELEGIDA, no la tarjeta
                    // sintética en sí.
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 80 * Tema.escala * 2.1
                        height: 80 * Tema.escala + 50 * Tema.escala
                        Avatar {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            letra: ventana.nombreJugador.length > 0 ? ventana.nombreJugador.charAt(0).toUpperCase() : "?"
                            tamano: 80 * Tema.escala
                            marco: ventana.marcoPreview
                            textura: ventana.valorPreview("textura", redcliente.loadoutMarco.textura)
                            efecto: ventana.valorPreview("efecto", redcliente.loadoutMarco.efecto)
                            decoracionLateral1: ventana.valorPreview("decoracion_lateral", redcliente.loadoutMarco.decoracionLateral1)
                            decoracionLateral2: redcliente.loadoutMarco.decoracionLateral2 || ""
                            decoracionSuperior: ventana.valorPreview("decoracion_superior", redcliente.loadoutMarco.decoracionSuperior)
                            acabadoLateral1: ventana.acabadoPreview("decoracion_lateral", redcliente.loadoutMarco.decoracionLateral1, redcliente.loadoutMarco.acabadoLateral1)
                            acabadoLateral2: redcliente.loadoutMarco.acabadoLateral2 || ""
                            acabadoSuperior: ventana.acabadoPreview("decoracion_superior", redcliente.loadoutMarco.decoracionSuperior, redcliente.loadoutMarco.acabadoSuperior)
                        }
                    }
                    // Sin marco todavía: la vista previa usa Hierro (ver marcoPreview) y aquí
                    // se dice. Solo ocupa sitio si no tienes marco, y se enciende al
                    // previsualizar, así la columna no salta al pasar por los accesorios.
                    Text {
                        visible: ventana.sinMarcoPropio
                        opacity: ventana.previsualizandoConHierro ? 1 : 0
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "Así se verá con tu primer marco, Hierro. Gana una partida para desbloquear los accesorios."
                        color: Tema.colorTextoTenue
                        font.pixelSize: 10 * Tema.escala
                    }
                    CajaTitulo {
                        anchors.horizontalCenter: parent.horizontalCenter
                        readonly property var infoTituloVistaTiendaMovil: ventana.objetoTiendaPorCodigo(ventana.valorPreview("titulo", redcliente.loadoutMarco.titulo || ""))
                        nombre: infoTituloVistaTiendaMovil ? infoTituloVistaTiendaMovil.nombre : ""
                        colorTier: ventana.colorRareza(infoTituloVistaTiendaMovil ? infoTituloVistaTiendaMovil.rareza : "")
                    }
                }
            }
        }
    }
    PopupAcabado {
        id: popupAcabado
        onAcabadoElegido: (slot, codigo, acabado) =>
            redcliente.equiparObjeto(servidorHost, servidorPuerto, tokenSesion, slot, codigo, acabado)
    }
    PopupSeleccionCarta {
        id: popupSeleccionCartaMovil
        cartas: ventana.tiendaCrudo.filter(function(o) { return o.codigo.indexOf("carta_") === 0; })
        decoracionLateral1: redcliente.loadoutMarco.decoracionLateral1 || ""
        decoracionLateral2: redcliente.loadoutMarco.decoracionLateral2 || ""
        seleccionActual: ventana.cartaSeleccionada
        onCartaElegida: (codigo) => ventana.cartaSeleccionada = codigo
    }

    // ── Pantalla CrearSala ───────────────────────────────────────────────
    BarraSuperior {
        visible: ventana.pantalla === "CrearSala"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16 * Tema.escala
        textoCentro: ventana.sesionOffline ? "Nueva partida local" : "Crear sala"
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

                    // Ver el comentario gemelo en qml/Main.qml: offline se
                    // reutiliza el mismo formulario sin la sección de red,
                    // eligiendo contra cuántos bots jugar.
                    Column {
                        width: parent.width
                        spacing: 4 * Tema.escala
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
                        visible: ventana.sesionOffline
                        Text {
                            width: parent.width - selectorNumBotsMovil.width
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Número de bots (rivales)"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                            wrapMode: Text.WordWrap
                        }
                        SelectorNumerico {
                            id: selectorNumBotsMovil
                            anchors.verticalCenter: parent.verticalCenter
                            valor: 3
                            minimo: 1
                            maximo: 8
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4 * Tema.escala
                        visible: !ventana.sesionOffline
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
                    MarcoHueco {
                        id: cajaNombreSalaMovil
                        visible: !ventana.sesionOffline
                        width: parent.width
                        height: Math.max(Tema.tamanoMinTactil, 54 * Tema.escala)
                        radius: 10 * Tema.escala
                        activo: areaNombreSala.pressed
                        property string valor: ""
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10 * Tema.escala
                            anchors.verticalCenter: parent.verticalCenter
                            text: cajaNombreSalaMovil.valor !== "" ? cajaNombreSalaMovil.valor : "Nombre de la sala"
                            color: cajaNombreSalaMovil.valor !== "" ? Tema.colorTexto : Tema.colorTextoMuyTenue
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
                        visible: !ventana.sesionOffline
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
                        visible: !ventana.sesionOffline
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
                        visible: !ventana.sesionOffline
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
                        visible: !ventana.sesionOffline
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
                            onElegido: (indice) => seleccionado = indice
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
                            onElegido: (indice) => seleccionado = indice
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
                text: ventana.sesionOffline ? "Empezar partida" : "Crear sala"
                onClicked: {
                    if (ventana.nombreJugador === "") { campoNombre.abrir(""); return; }
                    // Ver el comentario gemelo en qml/Main.qml.
                    if (ventana.sesionOffline) {
                        ventana.modoOfflineActivo = true;
                        redcliente.iniciarPartidaLocal(
                            ventana.nombreJugador,
                            selectorNumBotsMovil.valor,
                            selectorNumManosMovil.valor,
                            selectorCiegaMovil.valor,
                            selectorSaldoMovil.valor,
                            selectorLimiteMovil.seleccionado,
                            interruptorMinRaiseMovil.activo,
                            selectorMonteFijoMovil.valor,
                            selectorDificultadMovil.seleccionado,
                            interruptorRecompraMovil.activo,
                            interruptorPreguntarExtensionMovil.activo);
                        return;
                    }
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
                color: Tema.colorTexto
                font.family: Tema.fuenteElegante
                font.bold: true
                font.pixelSize: 20 * Tema.escala
            }
            Text {
                text: ventana.textoListos
                color: Tema.colorTextoTenue
                font.pixelSize: 12 * Tema.escala
            }
            Row {
                visible: ventana.codigoSalaPropia !== ""
                spacing: 8 * Tema.escala
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Código para invitar: " + ventana.codigoSalaPropia
                    color: Tema.colorAccent
                    font.bold: true
                    font.pixelSize: 12 * Tema.escala
                }
                BotonContorno {
                    id: botonCopiarCodigoMovil
                    property bool copiado: false
                    anchors.verticalCenter: parent.verticalCenter
                    text: copiado ? "Copiado" : "Copiar"
                    onClicked: {
                        // Mismo truco que escritorio (ver qml/Main.qml) --
                        // sin API de portapapeles en QML puro, un TextEdit
                        // oculto: seleccionar todo y copiar hace lo mismo
                        // que el atajo de copiar en cualquier campo de texto.
                        portapapelesCodigoSalaMovil.text = ventana.codigoSalaPropia;
                        portapapelesCodigoSalaMovil.selectAll();
                        portapapelesCodigoSalaMovil.copy();
                        copiado = true;
                        temporizadorCopiadoMovil.restart();
                    }
                    Timer {
                        id: temporizadorCopiadoMovil
                        interval: 1500
                        onTriggered: botonCopiarCodigoMovil.copiado = false
                    }
                }
                TextEdit {
                    id: portapapelesCodigoSalaMovil
                    visible: false
                }
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

        // Con sesión iniciada únicamente -- un invitado no tiene amigos
        // que invitar. Funciona igual en sala pública o privada.
        BotonContorno {
            visible: ventana.tokenSesion !== "" && ventana.salaIdPropia !== ""
            text: "Invitar amigos"
            radioBorde: 999
            onClicked: popupInvitarAmigos.abrir()
        }

        BotonContorno {
            text: "Abandonar sala"
            radioBorde: 999
            onClicked: {
                // Mismo mecanismo que en el cliente de escritorio (ver
                // qml/Main.qml): abandonar() ya manda LEAVE y evita el
                // overlay de "reconectando" del lado C++, esto solo le
                // faltaba un botón.
                redcliente.abandonar();
                ventana.pantalla = "Salas";
            }
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
        onEnviar: (texto) => redcliente.enviarChat(texto, "sala")
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
            dealerNombre: ventana.dealerNombre
            sbNombre: ventana.sbNombre
            bbNombre: ventana.bbNombre
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
            confirmarAllIn: ventana.confirmarAllIn
            modeloHistorial: historialMovil
            modeloChat: mensajesChatPartida
            onAbrirAjustes: ventana.ajustesAbiertos = !ventana.ajustesAbiertos
            onAbrirChuleta: chuletaMovil.open()
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
                        color: Tema.colorTextoTenueSobreOscuro
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
                            // 5 = MIN_MANOS_PARA_STATS en NetworkObserver.cpp (servidor) -- si cambia ahí, cambiar aquí también.
                            contariaComoPerdida: ventana.tokenSesion !== "" && ventana.manoActual >= 5
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
                // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
                layer.enabled: true
                layer.effect: ShaderEffect {
                    property variant source
                    property real amplitud: 30.0
                    fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
                }

                Text {
                    id: textoPistaScrollShowdown
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6 * Tema.escala
                    text: "más abajo"
                    color: Tema.colorTextoTenueSobreOscuro
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

        // FASE 2: unanimidad conseguida -- el host elige cuántas manos
        // más, el resto solo ve el mensaje de espera (mismo bloque,
        // "soyYoQuienElige" decide qué contenido mostrar).
        Rectangle {
            visible: ventana.esperandoManosExtra
            anchors.centerIn: parent
            width: columnaManosExtraMovil.width + 32 * Tema.escala
            height: columnaManosExtraMovil.height + 24 * Tema.escala
            radius: 12 * Tema.escala
            color: Tema.colorPanel
            border.width: 1
            border.color: Tema.colorAccent

            Column {
                id: columnaManosExtraMovil
                anchors.centerIn: parent
                spacing: 10 * Tema.escala
                width: Math.min(280 * Tema.escala, ventana.width - 80 * Tema.escala)
                Text {
                    width: parent.width
                    text: ventana.manosExtraMensaje
                    color: Tema.colorAccent
                    font.bold: true
                    font.pixelSize: 13 * Tema.escala
                    wrapMode: Text.WordWrap
                }
                Row {
                    visible: ventana.soyYoQuienElige
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10 * Tema.escala
                    SelectorNumerico {
                        id: selectorManosExtraMovil
                        anchors.verticalCenter: parent.verticalCenter
                        valor: 10
                        minimo: 1
                        maximo: 500
                    }
                    BotonRelleno {
                        text: "Confirmar"
                        onClicked: {
                            redcliente.elegirManosExtra(selectorManosExtraMovil.valor);
                            ventana.esperandoManosExtra = false;
                            ventana.soyYoQuienElige = false;
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
            // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
            layer.enabled: true
            layer.effect: ShaderEffect {
                property variant source
                property real amplitud: 30.0
                fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
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
                    color: Tema.colorTexto
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
                                color: modelData.nombre === ventana.ganadorFinal ? Tema.colorAccent : Tema.colorTexto
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
                        ventana.salaIdPropia = "";
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
            id: scrollAjustesMovil
            anchors.fill: parent
            anchors.margins: 18 * Tema.escala
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: cajonAjustesMovil.width - 36 * Tema.escala
                spacing: 20 * Tema.escala

                // Título único otra vez -- "Cuenta" se mudó al riel
                // (pestaña propia, 2026-09-01, Fase M1 del port de
                // progresión a móvil), así que este cajón ya solo tiene
                // "cómo se ve/comporta el cliente", sin selector para
                // elegir entre dos secciones cuando ya solo queda una --
                // mismo criterio que escritorio.
                Text {
                    text: "AJUSTES"
                    color: Tema.colorTextoMuyTenue
                    font.pixelSize: 10 * Tema.escala
                    font.letterSpacing: 1
                }

                // ── Tema de color ────────────────────────────────────────
                Column {
                    width: parent.width
                    spacing: 8 * Tema.escala
                    visible: ventana.pestanaAjustesActual === 0
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
                                    color: Tema.temaActual === filaTemaMovil.index ? Tema.colorTexto : Tema.colorTextoTenue
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
                    visible: ventana.pestanaAjustesActual === 0 && ventana.pantalla === "Partida"
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
                                color: Tema.colorTexto
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
                    visible: ventana.pestanaAjustesActual === 0
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
                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - 46 * Tema.escala
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Confirmar antes de ALL-IN"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                            wrapMode: Text.WordWrap
                        }
                        Interruptor {
                            anchors.verticalCenter: parent.verticalCenter
                            activo: ventana.confirmarAllIn
                            onAlternado: ventana.confirmarAllIn = !ventana.confirmarAllIn
                        }
                    }
                }

                // ── Versión (pendiente 9 de CLAUDE.md, 2026-09-10) ──────────────────
                // Descarga DIRECTA del fichero de esta plataforma en la última release
                // pública -- ver VersionChecker::urlDescarga().
                Column {
                    width: parent.width
                    spacing: 12 * Tema.escala
                    visible: ventana.pestanaAjustesActual === 0
                    Text {
                        text: "VERSIÓN"
                        color: Tema.colorTextoMuyTenue
                        font.pixelSize: 10 * Tema.escala
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
                        text: "Ver la última versión en GitHub"
                        onClicked: Qt.openUrlExternally(versionChecker.urlDescarga)
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
        // z alto a propósito -- mismo criterio que el cliente de
        // escritorio (ver Main.qml de qml/): garantiza que este aviso
        // gane siempre encima de cualquier otro overlay (showdown, voto)
        // que pudiera seguir "abierto" cuando la conexión se cae.
        z: 100
        color: "#0A140F"
        opacity: 0.92
        Column {
            anchors.centerIn: parent
            spacing: 10 * Tema.escala
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Conexión perdida — reconectando..."
                color: Tema.colorTextoSobreOscuro
                font.pixelSize: 16 * Tema.escala
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ventana.segundosReconexion + "s restantes"
                color: Tema.colorTextoTenueSobreOscuro
                font.pixelSize: 12 * Tema.escala
            }
        }
    }

    // ── Cerrar Social v1: perfil público, invitar a sala, banner ──────────
    // Instancias únicas a nivel de ventana raíz -- mismo motivo que en
    // escritorio (ver Main.qml de qml/): el perfil se abre desde varias
    // pantallas (Social, Ranking), y el banner puede llegar en cualquier
    // pantalla de menú.
    PopupPerfilJugador {
        id: popupPerfilJugador
        servidorHost: ventana.servidorHost
        servidorPuerto: ventana.servidorPuerto
        tiendaCrudo: ventana.tiendaCrudo
    }
    // Overlay, no un panel embebido en una pestaña -- se abre desde
    // cualquier fila de Amigos, ver el comentario largo en
    // VistaChatDirecto.qml.
    VistaChatDirecto {
        id: popupChatDirecto
        miUsername: ventana.nombreJugador
        servidorHost: ventana.servidorHost
        servidorPuerto: ventana.servidorPuerto
    }
    PopupInvitarAmigos {
        id: popupInvitarAmigos
        servidorHost: ventana.servidorHost
        servidorPuerto: ventana.servidorPuerto
        salaId: ventana.salaIdPropia
        listaAmigos: modeloAmigos
    }
    BannerInvitacionSala {
        id: bannerInvitacionSala
        onUnirse: (salaId, codigo) => {
            redcliente.unirseASala(ventana.servidorHost, ventana.servidorPuerto,
                                    ventana.nombreJugador, salaId, codigo);
        }
    }
    BannerVersionNueva {
        id: bannerVersionNueva
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
