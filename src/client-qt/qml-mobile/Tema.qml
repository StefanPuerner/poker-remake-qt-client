// Tema.qml (móvil) — mismo rol que el singleton del cliente de escritorio,
// pero pensado para pantalla táctil fija en vez de ventana redimensionable.
//
// La PALETA de color se reutiliza tal cual del cliente de escritorio (ver
// src/client-qt/qml/Tema.qml) — es la identidad visual de la app, no algo
// que deba cambiar entre plataformas. Lo que sí cambia de raíz:
//   - "escala" ya no depende de arrastrar la ventana (el usuario no
//     redimensiona un móvil) — se deriva UNA VEZ del tamaño real de
//     pantalla que reporte el dispositivo, contra una resolución de
//     diseño base en horizontal.
//   - Sin zoom manual (Ctrl+/Ctrl-): no hay teclado físico ni atajos en un
//     móvil — la escala se calcula sola y ya está.
//   - Nuevo: "tamanoMinTactil", un suelo absoluto en píxeles lógicos para
//     cualquier elemento pulsable — un botón nunca debe encogerse por
//     debajo del tamaño mínimo accesible al tacto, aunque la escala
//     calculada para ESE dispositivo diera un número menor (pantallas muy
//     compactas). Los componentes táctiles (BotonRelleno/BotonContorno
//     aquí en qml-mobile/) deben usar Math.max(Tema.tamanoMinTactil, ...)
//     al calcular su alto, nunca multiplicar sin más como hace escritorio.
pragma Singleton
import QtQuick

QtObject {
    // ── Paletas — copiadas literalmente del Tema.qml de escritorio ────────
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

    readonly property color colorFondo: temas[temaActual].fondo
    readonly property color colorTapete: temas[temaActual].tapete
    readonly property color colorPanel: temas[temaActual].panel
    readonly property color colorBorde: temas[temaActual].borde
    readonly property color colorAccent: temas[temaActual].accent
    readonly property color colorPeligro: "#C0524A"
    // Ver el comentario largo en el Tema.qml de escritorio: los overlays de
    // pantalla completa (showdown, reconectando) van siempre sobre
    // "#0A140F" fijo, no sobre Tema.colorFondo, así que su texto necesita
    // este par constante en vez de colorTexto/colorTextoTenue.
    readonly property color colorTextoSobreOscuro: "#FFFFFF"
    readonly property color colorTextoTenueSobreOscuro: "#A8AFAB"
    readonly property color colorTexto: temas[temaActual].texto // texto principal — "white" a fuego en todo el cliente antes de que existiera un tema claro (Porcelana dorada)
    readonly property color colorTextoTenue: temas[temaActual].textoTenue
    readonly property color colorTextoMuyTenue: temas[temaActual].textoMuyTenue
    readonly property color colorNombreAjeno: temas[temaActual].nombreAjeno

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
    // Umbrales bajados de 10/25/50/100 a 5/15/25/50 -- mismo cambio y
    // mismo motivo que en escritorio (ver Tema.qml de qml/), 2026-08-31.
    //
    // Fase M0 del port a móvil (2026-09-01, ver memoria
    // qt_mobile_progression_port_plan): puesta al día con la versión de
    // escritorio, que llevaba dos correcciones más que esta nunca recibió
    // -- "tieneMarcoBasico" como 2º parámetro real (antes la firma solo
    // tenía "n", así que Hierro NUNCA se activaba salvo con
    // partidas_ganadas real, aunque todos los llamadores ya lo pasaban) y
    // el propio tier "hierro" (marco básico, se gana con CUALQUIER
    // partida ganada, también contra bots -- antes de esto no existía
    // ningún marco por debajo de Bronce en móvil).
    function marcoPorPartidasGanadas(n, tieneMarcoBasico) {
        if (n >= 50) return "platino";
        if (n >= 25) return "oro";
        if (n >= 15) return "plata";
        if (n >= 5) return "bronce";
        if (n >= 1 || tieneMarcoBasico) return "hierro";
        return "ninguno";
    }

    // ── Fuente empaquetada ───────────────────────────────────────────────
    // Mismo patrón que escritorio: Main.qml la fija vía Binding una vez el
    // FontLoader resuelve el .ttf; vacío mientras tanto = fuente de sistema.
    property string fuenteElegante: ""

    // ── Escala táctil ────────────────────────────────────────────────────
    // Resolución de diseño base: un landscape "compacto" típico (móvil de
    // gama media, ~6"). Asignada desde Main.qml (móvil) con un Binding
    // ligado a Screen.width/height, igual que escritorio liga "escala" al
    // tamaño de ventana — aquí el valor por defecto de 1.0 solo importa
    // para qmllint/la vista previa, nunca se usa en ejecución real.
    readonly property real anchoBase: 800
    readonly property real altoBase: 400
    property real escala: 1.0

    // Suelo absoluto para cualquier objetivo pulsable, en píxeles lógicos —
    // no se multiplica por "escala", es una cota mínima aparte (ver
    // cabecera del fichero). 44 es la recomendación estándar de
    // accesibilidad táctil (Android/iOS coinciden en ese entorno de valor).
    readonly property real tamanoMinTactil: 44

    // El tamaño que de verdad debe tener un objetivo pulsable: el de
    // diseño, ESCALADO, pero sin bajar nunca del suelo de arriba.
    //
    // Existe desde 2026-09-09 porque 21 sitios usaban "tamanoMinTactil"
    // como si fuera el tamaño, no el suelo. Con escala > 1 (que es lo
    // normal: la escala sale de la pantalla real contra 800x400 de
    // diseño) eso dejaba botones, campos e interruptores clavados en 44px
    // mientras su propio contenido -- texto, iconos, puntos -- crecía con
    // la escala. Se veían diminutos y con el contenido saliéndose, y fue
    // la causa REAL de tres rondas de "los campos de texto son muy
    // estrechos" (2026-09-09): se buscó en el estilo lo que era un
    // problema de escala.
    //
    // Regla: para el tamaño de algo pulsable, "Tema.tactil". Para un
    // suelo dentro de otra cuenta (un botón que crece con su texto),
    // "Math.max(Tema.tamanoMinTactil, ...)" sigue siendo lo correcto.
    readonly property real tactil: Math.max(tamanoMinTactil, 44 * escala)
}
