// Tema.qml — singleton de tema visual: paleta de color activa, escala
// responsiva y fuente empaquetada. Antes vivía como propiedades sueltas de
// "ventana" (la ApplicationWindow raíz) y cada componente las leía como
// "ventana.colorX"/"ventana.escala" — ahora que los componentes están
// repartidos en varios ficheros, un singleton evita tener que pasar cada
// una de esas propiedades a mano por cada componente (required property por
// cada color en cada fichero sería un csv de props enorme para algo que es
// verdaderamente global a toda la interfaz).
//
// "escala" y "fuenteElegante" no son valores fijos aquí — Main.qml los
// mantiene sincronizados con Binding{} (escala depende del tamaño real de
// la ventana; fuenteElegante depende de que el FontLoader term ine de
// resolver el fichero .ttf empaquetado).
pragma Singleton
import QtQuick

QtObject {
    // ── Paletas disponibles ──────────────────────────────────────────────
    // colorPeligro se queda FUERA de la paleta a propósito: es un color con
    // significado (retirarse/abandonar/peligro), no una cuestión estética —
    // que signifique lo mismo pase lo que pase con el tema importa más que
    // que combine perfecto con cada paño.
    readonly property var temas: [
        {
            nombre: "Verde clásico",
            fondo: "#0B1A14", tapete: "#1B4332", panel: "#0F2419", borde: "#2A5A44",
            accent: "#C08F3E", textoTenue: "#9AA79D", textoMuyTenue: "#6B8577", nombreAjeno: "#7FBFA8"
        },
        {
            nombre: "Azul medianoche",
            fondo: "#0A141F", tapete: "#173250", panel: "#0D1B29", borde: "#2A4A63",
            accent: "#B8C4CE", textoTenue: "#9AACB8", textoMuyTenue: "#5E7A8C", nombreAjeno: "#7C93A8"
        },
        {
            nombre: "Burdeos",
            fondo: "#1A0B0E", tapete: "#4D1B26", panel: "#240F14", borde: "#632A38",
            accent: "#D4A24E", textoTenue: "#B89AA0", textoMuyTenue: "#8C6B70", nombreAjeno: "#BF7F8F"
        },
        {
            nombre: "Grafito",
            fondo: "#101214", tapete: "#2B2E33", panel: "#17191C", borde: "#44484E",
            accent: "#C77B4E", textoTenue: "#A3A8AE", textoMuyTenue: "#6E7378", nombreAjeno: "#8FA3AE"
        }
    ]
    property int temaActual: 0

    readonly property color colorFondo: temas[temaActual].fondo // fondo general de la ventana, el más oscuro de los tres
    readonly property color colorTapete: temas[temaActual].tapete // paño de la mesa, el más claro/saturado
    readonly property color colorPanel: temas[temaActual].panel // paneles (chat/historial, avatares, cartas comunitarias de fondo)
    readonly property color colorBorde: temas[temaActual].borde // línea sutil entre paños/paneles
    readonly property color colorAccent: temas[temaActual].accent // color "temático" de la paleta activa
    readonly property color colorPeligro: "#C0524A" // rojo — retirarse/abandonar/all-in/tiempo agotándose (constante, ver arriba)
    readonly property color colorTextoTenue: temas[temaActual].textoTenue // texto secundario sobre fondo oscuro
    readonly property color colorTextoMuyTenue: temas[temaActual].textoMuyTenue // texto terciario (horas, etiquetas pequeñas)
    readonly property color colorNombreAjeno: temas[temaActual].nombreAjeno // nombre de OTRO jugador en el historial (el propio va en colorAccent)

    // color.toString() en QML devuelve "#AARRGGBB" (con canal alfa) o
    // "#RRGGBB" según la versión — ninguno de los dos es fiable a pelo
    // dentro de un <font color=...>: el de 8 dígitos lo ignora en
    // silencio. Los últimos 6 caracteres son siempre "RRGGBB" en los dos
    // casos, así que esto da un hex limpio pase lo que pase.
    function colorHex(c) {
        return "#" + c.toString().slice(-6);
    }

    // Umbrales de partidas_ganadas para el marco de avatar permanente (ver
    // Avatar.qml) -- provisionales, sin datos de uso real todavía que los
    // calibren. Un único sitio para los dos: Asiento (cualquier jugador
    // sentado, vía GAME_STATE) y la fila de Ranking (vía CONSULTAR_RANKING).
    function marcoPorPartidasGanadas(n) {
        if (n >= 100) return "platino";
        if (n >= 50) return "oro";
        if (n >= 25) return "plata";
        if (n >= 10) return "bronce";
        return "ninguno";
    }

    // ── Escala responsiva ─────────────────────────────────────────────────
    // Asignada desde Main.qml (Binding ligado a width/height de la ventana
    // Y a "zoomManual" de aquí abajo) — se queda con un valor por defecto
    // razonable mientras tanto para que qmllint/la vista previa de Qt
    // Creator no se quejen.
    property real escala: 1.0

    // Zoom manual del usuario (Ctrl+ / Ctrl- / Ctrl+0, ver Main.qml) — la
    // detección automática de densidad de pantalla (DPI) no es fiable
    // entre distintos entornos de escritorio de Linux (mismo Hyprland vs
    // GNOME, mismo portátil, se veía distinto), así que en vez de intentar
    // adivinarlo, se deja como ajuste manual directo. Multiplica a
    // "escala" en el Binding de Main.qml, no se usa solo — nadie fuera de
    // ahí necesita leer "zoomManual" en crudo.
    property real zoomManual: 1.0
    readonly property real zoomMinimo: 0.7
    readonly property real zoomMaximo: 1.6
    readonly property real zoomPaso: 0.1
    // En memoria por ahora, sin persistencia entre sesiones — mismo
    // criterio que el resto de ajustes de "Cliente" (sonido, confirmar
    // all-in...), a la espera de QSettings.
    function subirZoom() { zoomManual = Math.min(zoomMaximo, +(zoomManual + zoomPaso).toFixed(2)); }
    function bajarZoom() { zoomManual = Math.max(zoomMinimo, +(zoomManual - zoomPaso).toFixed(2)); }
    function reiniciarZoom() { zoomManual = 1.0; }

    // ── Fuente empaquetada ───────────────────────────────────────────────
    // Asignada desde Main.qml (Binding ligado al FontLoader) — nombre real
    // de la fuente una vez resuelta; vacío ("") hasta entonces, que Qt
    // interpreta como "usa la fuente por defecto del sistema".
    property string fuenteElegante: ""
}
