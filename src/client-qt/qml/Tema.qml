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
            accent: "#C08F3E", texto: "#FFFFFF", textoTenue: "#9AA79D", textoMuyTenue: "#6B8577", nombreAjeno: "#7FBFA8"
        },
        {
            nombre: "Azul medianoche",
            // Acento dorado desde 2026-09-10 (antes plateado, #B8C4CE): el
            // azul marino con oro se ve mucho mejor (idea del usuario). Es el
            // mismo dorado que Burdeos, más cálido que el del verde -- sobre
            // azul, casi complementario, resalta más.
            fondo: "#0A141F", tapete: "#173250", panel: "#0D1B29", borde: "#2A4A63",
            accent: "#D4A24E", texto: "#FFFFFF", textoTenue: "#9AACB8", textoMuyTenue: "#5E7A8C", nombreAjeno: "#7C93A8"
        },
        {
            nombre: "Burdeos",
            fondo: "#1A0B0E", tapete: "#4D1B26", panel: "#240F14", borde: "#632A38",
            accent: "#D4A24E", texto: "#FFFFFF", textoTenue: "#B89AA0", textoMuyTenue: "#8C6B70", nombreAjeno: "#BF7F8F"
        },
        {
            nombre: "Grafito",
            fondo: "#101214", tapete: "#2B2E33", panel: "#17191C", borde: "#44484E",
            accent: "#C77B4E", texto: "#FFFFFF", textoTenue: "#A3A8AE", textoMuyTenue: "#6E7378", nombreAjeno: "#8FA3AE"
        },
        {
            nombre: "Porcelana dorada",
            fondo: "#FAF5EC", tapete: "#CBA968", panel: "#FFFDF9", borde: "#D9C69C",
            accent: "#AD7F2E", texto: "#2A2419", textoTenue: "#7A6E5A", textoMuyTenue: "#9C907A", nombreAjeno: "#7C8CA0"
        }
    ]
    property int temaActual: 0

    readonly property color colorFondo: temas[temaActual].fondo // fondo general de la ventana
    readonly property color colorTapete: temas[temaActual].tapete // paño de la mesa, el más saturado de los tres
    readonly property color colorPanel: temas[temaActual].panel // paneles (chat/historial, avatares, cartas comunitarias de fondo)
    readonly property color colorBorde: temas[temaActual].borde // línea sutil entre paños/paneles
    readonly property color colorAccent: temas[temaActual].accent // color "temático" de la paleta activa
    readonly property color colorPeligro: "#C0524A" // rojo — retirarse/abandonar/all-in/tiempo agotándose (constante, ver arriba)
    // Los overlays de pantalla completa (showdown, reconectando, ventana
    // demasiado pequeña) van siempre sobre "#0A140F" fijo, no sobre
    // Tema.colorFondo -- son un "apagón" deliberado por encima de toda la
    // interfaz, no un panel más del tema (ver Main.qml, los tres
    // Rectangle "anchors.fill: parent" con ese color literal). El texto
    // de ahí dentro necesita su propio par constante en vez de
    // colorTexto/colorTextoTenue: con Porcelana dorada esos dos son
    // oscuros (pensados para fondo claro) y se leerían negro sobre negro.
    readonly property color colorTextoSobreOscuro: "#FFFFFF"
    readonly property color colorTextoTenueSobreOscuro: "#A8AFAB"
    readonly property color colorTexto: temas[temaActual].texto // texto principal — "white" a fuego en todo el cliente antes de que existiera un tema claro (Porcelana dorada)
    readonly property color colorTextoTenue: temas[temaActual].textoTenue // texto secundario
    readonly property color colorTextoMuyTenue: temas[temaActual].textoMuyTenue // texto terciario (horas, etiquetas pequeñas)
    readonly property color colorNombreAjeno: temas[temaActual].nombreAjeno // nombre de OTRO jugador en el historial (el propio va en colorAccent)

    // color.toString() en QML devuelve "#AARRGGBB" (con canal alfa) o
    // "#RRGGBB" según la versión — ninguno de los dos es fiable a pelo
    // dentro de un <font color=...>: el de 8 dígitos lo ignora en
    // silencio. Los últimos 6 caracteres son siempre "RRGGBB" en los dos
    // casos, así que esto da un hex limpio pase lo que pase.
    function colorHex(c) {
        // Guarda añadida (2026-09-03): "c" puede llegar null en el primer
        // frame de un binding que todavía no resolvió su color real (visto
        // en real: "TypeError: Cannot read property 'toString' of null",
        // repetido en consola en cuanto se abre cualquier pantalla que
        // llame a esto antes de que su color de origen esté listo).
        if (!c) return "#000000";
        return "#" + c.toString().slice(-6);
    }

    // Umbrales de partidas_ganadas para el marco de avatar permanente (ver
    // Avatar.qml) -- provisionales, sin datos de uso real todavía que los
    // calibren. Un único sitio para los dos: Asiento (cualquier jugador
    // sentado, vía GAME_STATE) y la fila de Ranking (vía CONSULTAR_RANKING).
    // Umbrales bajados de 10/25/50/100 a 5/15/25/50 (pedido explícito
    // 2026-08-31): con pocos jugadores reales, 10 partidas GANADAS ya era
    // excesivo para el primer marco -- nadie del grupo de amigos del
    // usuario lo había alcanzado todavía. El salto final (25→50, +25) se
    // deja más grande que los anteriores (+10, +10) a propósito: Platino
    // sigue siendo el hito de verdad, no un escalón más.
    // tieneMarcoBasico: bug real 2026-08-31 -- este segundo parámetro se
    // pasaba desde TODOS los sitios que llaman a esta función pero la
    // función en sí lo ignoraba por completo (firma solo con "n"), así
    // que Hierro nunca se activaba salvo con partidas_ganadas real
    // (n >= 1, el contador CON el antifarm) -- exactamente lo que este
    // parámetro existe para evitar. Corregido: ahora sí se mira.
    // ── Acabado de las decoraciones (fase 2 del material, ver
    // docs/plan-material-cosmeticos.md) ─────────────────────────────────
    // Metales de marco de menos a más: el orden de los umbrales de
    // marcoPorPartidasGanadas(), justo debajo, y el de rangoMetal() en el
    // servidor (AccountManager.cpp).
    readonly property var metalesMarco: ["hierro", "bronce", "plata", "oro", "platino"]
    readonly property var nombresMetal: ({
        "hierro": "Hierro", "bronce": "Bronce", "plata": "Plata", "oro": "Oro", "platino": "Platino"
    })
    // Las decoraciones de METAL, las únicas con acabado: el resto conserva su
    // color (un naipe es rojo y negro, una gema es su piedra). Vive aquí y no
    // en Avatar.qml porque Main.qml también la consulta, para saber si al
    // equipar hay que preguntar el acabado. ⚠️ Tiene que coincidir con
    // METALICOS de scripts/generar_iconos.sh y con ICONOS_METALICOS de
    // cmake/ClientesQt.cmake (hay un PNG por metal).
    readonly property var decoracionesMetalicas: ({
        "corona_inicial": true, "corona_laurel": true, "corona_real": true,
        "cinta_ondulada": true, "constelacion": true, "ojo_vigilante": true
    })
    // Los acabados que puede elegir quien lleva el marco @p marco: del hierro
    // al suyo, "solo se puede bajar, nunca subir" (el servidor lo vuelve a
    // comprobar). Vacío si @p marco no es de metal.
    function metalesHasta(marco) {
        var i = metalesMarco.indexOf(marco);
        return i < 0 ? [] : metalesMarco.slice(0, i + 1);
    }

    function marcoPorPartidasGanadas(n, tieneMarcoBasico) {
        if (n >= 50) return "platino";
        if (n >= 25) return "oro";
        if (n >= 15) return "plata";
        if (n >= 5) return "bronce";
        // Hierro -- marco básico, se gana con CUALQUIER partida ganada,
        // también contra bots (pedido explícito 2026-08-31: antes de esto
        // no había NINGÚN marco, y la Tienda mostraba un gris "sin
        // material" al previsualizar Textura/Efecto/Decoraciones sin
        // haber ganado nunca -- una vista previa que no reflejaba nada
        // real. Ahora comprar/equipar esos accesorios exige tener ya
        // Hierro, ver AccountManager::comprarObjeto()/equiparObjeto()).
        if (n >= 1 || tieneMarcoBasico) return "hierro";
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
