// Avatar.qml (móvil) — mismo rol que el de escritorio (ver
// src/client-qt/qml/Avatar.qml), del que este fichero es un PORT
// mecánico 2026-09-01 (Fase M0 del port de progresión a móvil, ver
// memoria qt_mobile_progression_port_plan): la versión que había aquí
// era una foto antigua, de antes de Hierro/Fase 5/podio -- este
// reemplazo trae ese fichero al día entero. Única diferencia real con
// el de escritorio: la ruta qrc de los iconos usa el URI de módulo de
// este cliente (PokerQuickMobile, no PokerQuick -- ver cmake/ClientesQt.cmake).
// Si tocas el de escritorio, revisa también este.
//
// "marco" -- valores válidos:
//   "ninguno"          -- sin marco, el círculo de siempre.
//   "hierro"           -- marco básico, desde tu primera partida ganada
//        (también contra bots).
//   "bronce"/"plata"/"oro"/"platino" -- nivel permanente por partidas
//        ganadas, anillo metálico de 3 paradas, estático. Platino además
//        lleva un brillo giratorio propio (lento, sin halo ni insignia)
//        para que no se confunda con plata a simple vista.
//   "campeonVictorias"/"campeonRatio" -- PODIO, puesto 1 del ranking
//        global (por victorias o por ratio) -- tratamiento completo:
//        halo que respira + anillo degradado + barrido cónico + insignia
//        (destello de 8 puntas con brillo, no un icono recortado a mano).
//        Sin conectar a datos reales todavía (ver Avatar.qml de
//        escritorio y memoria qt_nav_redesign_and_stats_plan) -- el
//        código se queda listo, igual que en escritorio.
//   "campeonVictorias2"/"campeonRatio2" -- puesto 2 -- mismo anillo pero
//        halo más calmo (más lento, menos amplitud) y SIN barrido cónico;
//        insignia algo más pequeña.
//   "campeonVictorias3"/"campeonRatio3" -- puesto 3 -- sin halo ni
//        barrido, anillo más fino y atenuado (el "tinte estático"); la
//        insignia se achica y se atenúa más, pero sigue siendo el mismo
//        destello -- ningún puesto es un downgrade visual del anterior.
//   Los tres puestos son transitorios -- se pierden si alguien te supera.
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: avatar
    required property string letra
    property string marco: "ninguno"
    property real tamano: 56 * Tema.escala
    // Halo de turno de Asiento.qml -- independiente del marco de logro,
    // los dos pueden coexistir (el aro dorado de turno ya vivía fuera de
    // este componente y sigue así).
    property color colorBorde: Tema.colorBorde

    // ── Fase 5 del sistema de progresión: Textura/Efecto/Decoraciones ──
    // Capas NUEVAS, independientes del Material (marco de arriba, que
    // NUNCA se compra). "" = nada equipado ahí. Los códigos válidos son
    // los mismos "codigo" de shop_items (ver la semilla en
    // AccountManager.cpp) -- dibujarDecoracion() más abajo es quien
    // conoce la lista completa.
    property string textura: ""              // "" | "trenzado" | "grabado" | "facetado"
    property string efecto: ""                // "" | "pulso" (brillo_giratorio de Platino es aparte, automático)
    property string decoracionLateral1: ""
    property string decoracionLateral2: ""
    property string decoracionSuperior: ""
    // Acabado de cada decoración (fase 2 del material): "hierro"..
    // "platino", o "" = sigue al marco. Ver sufijoAcabado().
    property string acabadoLateral1: ""
    property string acabadoLateral2: ""
    property string acabadoSuperior: ""

    // "hierro" -- marco básico, desde tu primera partida GANADA.
    readonly property bool esTierMetalico: marco === "hierro" || marco === "bronce" ||
                                            marco === "plata" || marco === "oro" || marco === "platino"
    readonly property bool esPlatino: marco === "platino"
    // Textura/Efecto/Decoraciones (Fase 5) SOLO se pueden comprar/equipar
    // si ya tienes marco de material -- así que en la práctica esto es
    // siempre lo mismo que esTierMetalico. Sin marco de verdad, no se
    // pinta ningún anillo, punto.
    readonly property bool tieneAlgoDeMarco: avatar.esTierMetalico

    readonly property var coloresTier: ({
        "hierro":  ["#6e7580", "#7d848f", "#6a7079", "#3a3f46"],
        "bronce":  ["#c98f5f", "#e0a874", "#b5794c", "#4a2f1a"],
        "plata":   ["#9aa4ab", "#c9d0d4", "#aeb6bb", "#4d545a"],
        "oro":     [Tema.colorAccent, "#e3bb82", "#e3bb82", "#7d5a26"],
        "platino": ["#eef3ff", "#ffffff", "#dce6ff", "#8d9ad1"]
    })
    // [colorLetra, gradClaro, gradMedio, gradOscuro] -- oro reutiliza
    // Tema.colorAccent tal cual para la letra, igual que el círculo sin
    // marco de toda la vida. Plata en gris medio (no casi-blanco) para
    // que platino, con su brillo, se note claramente por encima. Hierro en
    // grafito mate a propósito -- el escalón más bajo, nada de brillo.
    readonly property var tierActual: coloresTier[marco] || ["", "", "", ""]
    // Alias -- se queda solo por compatibilidad con el resto del fichero
    // (gradiente/marcas cardinales/capaTextura ya usan este nombre).
    readonly property var tierActualColores: avatar.tierActual
    // Contorno del aro en tema claro -- ver marcoMetalico.
    readonly property real grosorContorno: Math.max(1, avatar.tamano * 0.016)
    // Solo el platino: el resto de metales se separa bien del fondo claro
    // (confirmado por el usuario, 2026-09-10).
    readonly property bool conContornoClaro: Tema.esTemaClaro && avatar.esPlatino
    readonly property color colorContorno: avatar.esTierMetalico
                                           ? Qt.darker(avatar.tierActualColores[3], 1.1) : "transparent"
    // La letra del núcleo va en el color del marco, salvo el platino en tema
    // claro: su casi-blanco (#eef3ff) desaparecía sobre un núcleo también
    // claro. Ahí, el tono oscuro del propio platino.
    readonly property color colorLetraTier: !avatar.esTierMetalico ? Tema.colorAccent
                                            : (Tema.esTemaClaro && avatar.esPlatino)
                                              ? Qt.darker(avatar.tierActualColores[3], 1.35)
                                              : avatar.tierActual[0]

    // ── Podio (campeón) -- puesto 1/2/3, dos categorías ─────────────────
    readonly property int posicionPodio: {
        if (marco === "campeonVictorias" || marco === "campeonRatio") return 1;
        if (marco === "campeonVictorias2" || marco === "campeonRatio2") return 2;
        if (marco === "campeonVictorias3" || marco === "campeonRatio3") return 3;
        return 0;
    }
    readonly property bool esCampeon: avatar.posicionPodio > 0
    readonly property bool esCategoriaRatio: avatar.marco.indexOf("Ratio") >= 0
    readonly property color colorCampeon: avatar.esCategoriaRatio ? "#8fc7d9" : "#e3bb82"

    // Redondeado a entero -- nucleo (el círculo interior) y marcoMetalico
    // (el anillo) son dos Rectangle SEPARADOS con anchors.centerIn sobre
    // este Item; sin redondear, restos fraccionarios distintos entre los
    // dos (tamano vs. tamano*1.16) hacen que el renderer los ajuste a
    // píxel de pantalla de forma distinta, dando un anillo más grueso de
    // un lado que del otro (más notorio a tamaños pequeños). Redondear
    // aquí Y en marcoMetalico/nucleo deja a los tres con resto cero.
    width: Math.round(avatar.tamano)
    height: Math.round(avatar.tamano)

    // ── Marco metálico (niveles permanentes) -- también sirve de "lienzo"
    // para Textura/Efecto/Decoraciones (Fase 5) cuando todavía no hay
    // Material propio (tieneAlgoDeMarco), con el gris neutro de arriba.
    Rectangle {
        id: marcoMetalico
        visible: avatar.tieneAlgoDeMarco
        anchors.centerIn: parent
        width: Math.round(avatar.tamano * 1.16)
        height: width
        radius: width / 2
        // Tema claro (pendiente 8 de CLAUDE.md, 2026-09-10): el platino es
        // casi blanco arriba y se perdía contra el fondo y contra el núcleo,
        // los dos claros. Contorno por fuera (este borde) y por dentro (el
        // Rectangle de antes de las marcas cardinales) en el tono oscuro del
        // propio metal -- el mismo recurso que ya salvó a los iconos. En los
        // temas oscuros no se pinta: allí el aro se separa solo, y es lo que
        // se aprobó. Y solo en el platino: los demás metales se separan bien
        // del fondo claro (confirmado por el usuario, 2026-09-10).
        border.width: avatar.conContornoClaro ? avatar.grosorContorno : 0
        border.color: avatar.colorContorno
        gradient: Gradient {
            GradientStop { position: 0.0; color: avatar.tierActualColores[1] }
            GradientStop { position: 0.45; color: avatar.tierActualColores[2] }
            GradientStop { position: 1.0; color: avatar.tierActualColores[3] }
        }
        // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
        layer.enabled: true
        layer.effect: ShaderEffect {
            property variant source
            property real amplitud: 3.0
            fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
        }
        // Contorno interior en tema claro -- ver el borde de marcoMetalico.
        // Justo por fuera del núcleo, que lo tapa por dentro: se ve como una
        // línea fina entre el aro y el núcleo.
        Rectangle {
            visible: avatar.conContornoClaro
            anchors.centerIn: parent
            width: Math.round(avatar.tamano) + 2 * avatar.grosorContorno
            height: width
            radius: width / 2
            color: "transparent"
            border.width: avatar.grosorContorno
            border.color: avatar.colorContorno
        }
        // Cuatro marcas cardinales -- ocultas si hay una Textura puesta
        // (los 4 rombos y el patrón grabado/trenzado/facetado compiten
        // por el mismo espacio y quedan amontonados) Y TAMBIÉN oculta la
        // del lado que ya ocupa una decoración de verdad. index:
        // 0=arriba, 1=derecha, 2=abajo, 3=izquierda -- abajo no tiene
        // decoración propia todavía, así que esa se queda siempre
        // visible salvo con textura.
        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                visible: avatar.textura === "" && !(
                    (index === 0 && avatar.decoracionSuperior !== "") ||
                    (index === 1 && avatar.decoracionLateral2 !== "") ||
                    (index === 3 && avatar.decoracionLateral1 !== ""))
                width: Math.max(3, avatar.tamano * 0.09)
                height: width
                // Proporcional (no fijo a 1px) -- mismo aspecto a
                // cualquier tamaño.
                radius: width * 0.08
                color: "#fff8ec"
                border.width: Math.max(1, avatar.tamano * 0.014)
                border.color: avatar.tierActualColores[3]
                rotation: 45
                // Referencia explícita a marcoMetalico (por id) en vez de
                // "parent" -- un Repeater no garantiza que sus delegates
                // tengan ya un parent válido en el instante en que se
                // evalúan estos bindings de anchors por primera vez.
                anchors.horizontalCenter: index % 2 === 0 ? marcoMetalico.horizontalCenter : undefined
                anchors.verticalCenter: index % 2 === 1 ? marcoMetalico.verticalCenter : undefined
                anchors.top: index === 0 ? marcoMetalico.top : undefined
                anchors.bottom: index === 2 ? marcoMetalico.bottom : undefined
                anchors.left: index === 3 ? marcoMetalico.left : undefined
                anchors.right: index === 1 ? marcoMetalico.right : undefined
                anchors.margins: avatar.tamano * 0.02
            }
        }
    }

    // ── Fase 5 del sistema de progresión: Textura -- un patrón grabado
    // SOBRE el anillo, no lo sustituye. "Pulido" (textura === "") es el
    // liso de siempre, sin Canvas encima -- cero coste para el 99% de
    // avatares que hoy no equipan ninguna.
    Canvas {
        id: capaTextura
        visible: avatar.tieneAlgoDeMarco && avatar.textura !== ""
        anchors.fill: marcoMetalico
        // Canvas no repinta solo porque una property que onPaint lee haya
        // cambiado (a diferencia de un binding normal) -- sin esto,
        // cambiar de textura (en la Tienda, o al equipar una de verdad)
        // dejaba el dibujo congelado en lo que hubiera al crearse el
        // Canvas. Mismo patrón que decoLateralIzq/Der/Superior más abajo.
        property string texturaPintada: avatar.textura
        onTexturaPintadaChanged: requestPaint()
        property var colorPintado: avatar.tierActualColores
        onColorPintadoChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var w = width, h = height;
            if (w <= 0 || h <= 0) return;
            var cx = w / 2, cy = h / 2, r = Math.min(w, h) / 2;
            var colorLinea = Tema.colorHex(Qt.darker(avatar.tierActualColores[3], 1.15));
            ctx.strokeStyle = colorLinea;
            if (avatar.textura === "trenzado") {
                ctx.lineWidth = Math.max(1, w * 0.018);
                var n = 20;
                for (var i = 0; i < n; i++) {
                    var ang = (Math.PI * 2 / n) * i;
                    var dir = i % 2 === 0 ? 1 : -1;
                    ctx.beginPath();
                    ctx.moveTo(cx + r * 0.86 * Math.cos(ang), cy + r * 0.86 * Math.sin(ang));
                    ctx.lineTo(cx + r * 0.98 * Math.cos(ang + dir * 0.14),
                               cy + r * 0.98 * Math.sin(ang + dir * 0.14));
                    ctx.stroke();
                }
            } else if (avatar.textura === "grabado") {
                ctx.lineWidth = Math.max(1, w * 0.012);
                ctx.beginPath();
                ctx.arc(cx, cy, r * 0.90, 0, Math.PI * 2);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(cx, cy, r * 0.96, 0, Math.PI * 2);
                ctx.stroke();
            } else if (avatar.textura === "facetado") {
                ctx.lineWidth = Math.max(1, w * 0.014);
                var m = 14;
                for (var j = 0; j < m; j++) {
                    var a1 = (Math.PI * 2 / m) * j;
                    var a2 = (Math.PI * 2 / m) * (j + 1);
                    var am = (a1 + a2) / 2;
                    ctx.beginPath();
                    ctx.moveTo(cx + r * 0.86 * Math.cos(a1), cy + r * 0.86 * Math.sin(a1));
                    ctx.lineTo(cx + r * 0.99 * Math.cos(am), cy + r * 0.99 * Math.sin(am));
                    ctx.lineTo(cx + r * 0.86 * Math.cos(a2), cy + r * 0.86 * Math.sin(a2));
                    ctx.stroke();
                }
            } else if (avatar.textura === "canto_ficha") {
                // Muescas alternas alrededor del aro, como el canto
                // rayado de una ficha de póker de verdad. Los tramos
                // "claros" son el propio degradado de marcoMetalico ya
                // pintado debajo (no hace falta dibujarlos); encima solo
                // van la sombra de cada muesca y su filo iluminado.
                //
                // Cada muesca es un SECTOR DE CORONA CIRCULAR (arco
                // exterior + arco interior), no un rectángulo rotado:
                // antes las esquinas rectas se salían del aro por fuera y
                // dejaban escalón por dentro, y a tamaño grande eso se
                // leía como "rectángulos pegados encima" (bug real
                // reportado 2026-09-09). Las dos pasadas sombra/brillo
                // son lo que lo hace parecer metal fresado.
                var segmentos = 18;
                var paso = (Math.PI * 2) / segmentos;
                var rInt = r * 0.885;
                var rExt = r * 0.995;
                var holgura = paso * 0.16;
                var muesca = function(desde, color, alfa) {
                    ctx.fillStyle = color;
                    ctx.globalAlpha = alfa;
                    for (var k = 0; k < segmentos; k += 2) {
                        var a0 = (k + desde) * paso + holgura;
                        var a1 = (k + desde + 1) * paso - holgura;
                        ctx.beginPath();
                        ctx.arc(cx, cy, rExt, a0, a1, false);
                        ctx.arc(cx, cy, rInt, a1, a0, true);
                        ctx.closePath();
                        ctx.fill();
                    }
                };
                muesca(0, "#000000", 0.34);
                muesca(1, "#ffffff", 0.13);
                ctx.globalAlpha = 1.0;
            }
        }
    }

    // ── Fase 5: Efecto "Pulso" -- resplandor que sube y baja, distinto
    // del barrido rotatorio de Platino (ese es automático, este se
    // compra). Los dos pueden coexistir sin pisarse -- uno gira, el otro
    // solo cambia de opacidad.
    Rectangle {
        visible: avatar.efecto === "pulso"
        anchors.centerIn: parent
        width: avatar.tamano * 1.24
        height: width
        radius: width / 2
        color: "transparent"
        border.width: Math.max(2, avatar.tamano * 0.05)
        border.color: avatar.tierActualColores[1]
        SequentialAnimation on opacity {
            running: avatar.efecto === "pulso"
            loops: Animation.Infinite
            NumberAnimation { from: 0.15; to: 0.55; duration: 1400; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.55; to: 0.15; duration: 1400; easing.type: Easing.InOutSine }
        }
    }

    // ── Brillo exclusivo de Platino -- lo distingue de Plata a simple
    // vista sin necesitar la parafernalia de campeón (sin halo, sin
    // insignia): un barrido lento y sutil sobre el propio anillo.
    Item {
        visible: avatar.esPlatino
        anchors.centerIn: parent
        width: Math.round(avatar.tamano * 1.16)
        height: width
        RotationAnimation on rotation {
            running: avatar.esPlatino
            loops: Animation.Infinite
            from: 0; to: 360
            duration: 7000
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            rotation: parent.rotation
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.85; color: "transparent" }
                GradientStop { position: 0.93; color: "#ffffff" }
                GradientStop { position: 1.0; color: "transparent" }
            }
            // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
            layer.enabled: true
            layer.effect: ShaderEffect {
                property variant source
                property real amplitud: 3.0
                fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
            }
        }
    }

    // ── Marco de campeón (transitorio, animado) -- halo que respira.
    // Puesto 3 no lo lleva (tinte estático, sin animación).
    Rectangle {
        visible: avatar.esCampeon && avatar.posicionPodio <= 2
        anchors.centerIn: parent
        width: avatar.tamano * 1.28
        height: avatar.tamano * 1.28
        radius: width / 2
        color: "transparent"
        border.width: Math.max(2, avatar.tamano * 0.09)
        border.color: Qt.rgba(avatar.colorCampeon.r, avatar.colorCampeon.g, avatar.colorCampeon.b, 0.16)
        SequentialAnimation on opacity {
            running: avatar.esCampeon && avatar.posicionPodio <= 2
            loops: Animation.Infinite
            NumberAnimation {
                from: avatar.posicionPodio === 1 ? 0.5 : 0.55
                to: avatar.posicionPodio === 1 ? 1.0 : 0.8
                duration: avatar.posicionPodio === 1 ? 1500 : 2400
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                from: avatar.posicionPodio === 1 ? 1.0 : 0.8
                to: avatar.posicionPodio === 1 ? 0.5 : 0.55
                duration: avatar.posicionPodio === 1 ? 1500 : 2400
                easing.type: Easing.InOutSine
            }
        }
    }
    // Anillo -- degradado de tres paradas, mismo lenguaje visual que los
    // niveles permanentes (no un borde plano) para que el podio se note
    // por encima, no por debajo. El puesto 3 lo lleva más fino y
    // atenuado -- su "tinte estático".
    Rectangle {
        visible: avatar.esCampeon
        anchors.centerIn: parent
        width: avatar.tamano * (avatar.posicionPodio === 3 ? 1.1 : 1.16)
        height: width
        radius: width / 2
        opacity: avatar.posicionPodio === 3 ? 0.6 : 1.0
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(avatar.colorCampeon, 1.4) }
            GradientStop { position: 0.45; color: avatar.colorCampeon }
            GradientStop { position: 1.0; color: Qt.darker(avatar.colorCampeon, 1.7) }
        }
        // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
        layer.enabled: true
        layer.effect: ShaderEffect {
            property variant source
            property real amplitud: 3.0
            fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
        }
    }
    // Barrido cónico -- por encima del anillo, solo el puesto 1 lo lleva
    // ("sin rotación" para el 2 y el 3, tal como se acordó).
    Item {
        visible: avatar.esCampeon && avatar.posicionPodio === 1
        anchors.centerIn: parent
        width: Math.round(avatar.tamano * 1.16)
        height: width
        RotationAnimation on rotation {
            running: avatar.esCampeon && avatar.posicionPodio === 1
            loops: Animation.Infinite
            from: 0; to: 360
            duration: 5000
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            rotation: parent.rotation
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.82; color: "transparent" }
                GradientStop { position: 0.9; color: Qt.lighter(avatar.colorCampeon, 1.5) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
            layer.enabled: true
            layer.effect: ShaderEffect {
                property variant source
                property real amplitud: 3.0
                fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
            }
        }
    }

    // ── Círculo base -- SIEMPRE igual, con o sin marco ──────────────────
    Rectangle {
        id: nucleo
        anchors.centerIn: parent
        width: Math.round(avatar.tamano)
        height: width
        radius: width / 2
        // Con marco de metal, el borde NEUTRO sobra: el aro ya hace de borde,
        // y estos 2px -- del color de las líneas entre paños, casi el del
        // tapete, y con el mismo dithering de fieltro que el núcleo -- se
        // leían como un hueco que dejaba ver la mesa entre el aro y el núcleo
        // (visto en el móvil con Burdeos, 2026-09-10: borde #632A38 contra
        // tapete #4D1B26, y el grano de 2px del móvil lo remataba). Un borde
        // con SEÑAL (turno, eliminado, "tú" en Ranking) se queda: esos van
        // siempre opacos, y los neutros son Tema.colorBorde o un blanco muy
        // tenue (filas de Ranking).
        readonly property bool bordeNeutro: Qt.colorEqual(avatar.colorBorde, Tema.colorBorde)
                                            || avatar.colorBorde.a < 0.5
        border.width: avatar.tieneAlgoDeMarco && bordeNeutro ? 0 : 2
        // Overridable -- Asiento.qml lo pone a Tema.colorAccent cuando es
        // el turno de este jugador, la fila de Ranking cuando es "tú". El
        // resto del componente no sabe nada de turnos ni de "soy yo".
        border.color: avatar.colorBorde
        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.6) }
            GradientStop { position: 1.0; color: Tema.colorPanel }
        }
        // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
        layer.enabled: true
        layer.effect: ShaderEffect {
            property variant source
            property real amplitud: 30.0
            fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
        }
        Text {
            anchors.centerIn: parent
            text: avatar.letra
            color: avatar.esCampeon ? avatar.colorCampeon
                   : avatar.esTierMetalico ? avatar.colorLetraTier
                   : Tema.colorAccent
            font.pixelSize: avatar.tamano * 0.36
            font.family: Tema.fuenteElegante
        }
    }

    // Dibuja UNA corona clásica (banda + tres picos rectos + orbe en cada
    // punta -- nada de curvas redondeadas "infantiles") o una estrella de
    // 5 puntas, en el Canvas dado. Compartida por las N repeticiones de
    // abajo -- todas idénticas, SIEMPRE al mismo tamaño y nitidez.
    function dibujarInsignia(ctx, w, h) {
        ctx.reset();
        ctx.fillStyle = Tema.colorHex(avatar.colorCampeon);
        ctx.strokeStyle = Tema.colorHex(Qt.darker(avatar.colorCampeon, 1.6));
        ctx.lineWidth = Math.max(1, w * 0.05);
        if (!avatar.esCategoriaRatio) {
            var bandTop = h * 0.60, bandBottom = h * 0.88;
            var bandLeft = w * 0.06, bandRight = w * 0.94;
            // Banda inferior.
            ctx.beginPath();
            ctx.moveTo(bandLeft, bandBottom);
            ctx.lineTo(bandLeft, bandTop);
            ctx.lineTo(bandRight, bandTop);
            ctx.lineTo(bandRight, bandBottom);
            ctx.closePath();
            ctx.fill(); ctx.stroke();
            // Tres picos triangulares rectos -- el central, más alto.
            var picos = [
                { cx: w * 0.24, tipY: h * 0.40, mitadBase: w * 0.11 },
                { cx: w * 0.50, tipY: h * 0.18, mitadBase: w * 0.13 },
                { cx: w * 0.76, tipY: h * 0.40, mitadBase: w * 0.11 }
            ];
            for (var i = 0; i < picos.length; i++) {
                var p = picos[i];
                ctx.beginPath();
                ctx.moveTo(p.cx - p.mitadBase, bandTop + 1);
                ctx.lineTo(p.cx, p.tipY);
                ctx.lineTo(p.cx + p.mitadBase, bandTop + 1);
                ctx.closePath();
                ctx.fill(); ctx.stroke();
            }
            // Orbe en cada punta -- detalle clásico de corona real.
            var rOrbe = w * 0.075;
            for (i = 0; i < picos.length; i++) {
                p = picos[i];
                ctx.beginPath();
                ctx.arc(p.cx, p.tipY - rOrbe * 0.35, rOrbe, 0, Math.PI * 2);
                ctx.closePath();
                ctx.fill(); ctx.stroke();
            }
            // Tres gemas pequeñas engastadas en la banda.
            var rGema = w * 0.04;
            for (i = 0; i < picos.length; i++) {
                p = picos[i];
                ctx.beginPath();
                ctx.arc(p.cx, (bandTop + bandBottom) / 2, rGema, 0, Math.PI * 2);
                ctx.closePath();
                ctx.fill(); ctx.stroke();
            }
        } else {
            // Estrella de 5 puntas -- proporción simétrica real, sin
            // achatado vertical.
            var cx = w / 2, cy = h / 2;
            var rOut = Math.min(w, h) * 0.52, rIn = rOut * 0.44;
            ctx.beginPath();
            for (var j = 0; j < 10; j++) {
                var r = j % 2 === 0 ? rOut : rIn;
                var ang = -Math.PI / 2 + j * Math.PI / 5;
                var x = cx + r * Math.cos(ang);
                var y = cy + r * Math.sin(ang);
                if (j === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
            }
            ctx.closePath();
            ctx.fill(); ctx.stroke();
        }
    }

    // ── Insignia de campeón -- corona (victorias) o estrella (ratio),
    // repetida tantas veces como indica el puesto (1º=3, 2º=2, 3º=1).
    // El puesto se nota por CANTIDAD, no por un icono más pequeño o peor
    // logrado -- ningún puesto es una versión reducida de otro. Cuando
    // son 3, van escalonadas en abanico (la del centro más alta, las de
    // los lados más bajas y giradas hacia afuera) en vez de en fila recta.
    Item {
        id: insigniaFila
        visible: avatar.esCampeon
        readonly property int cuenta: 4 - avatar.posicionPodio
        readonly property real anchoIcono: avatar.tamano * 0.34
        readonly property real altoIcono: avatar.tamano * 0.28
        readonly property real pasoX: insigniaFila.cuenta === 3
                                       ? insigniaFila.anchoIcono * 0.8
                                       : insigniaFila.anchoIcono + avatar.tamano * 0.03
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: -avatar.tamano * 0.24
        width: insigniaFila.pasoX * (insigniaFila.cuenta - 1) + insigniaFila.anchoIcono
        height: insigniaFila.altoIcono * 1.35

        Repeater {
            model: insigniaFila.cuenta
            delegate: Canvas {
                id: iconoInsignia
                required property int index
                readonly property bool esCentro: index === 1
                width: insigniaFila.anchoIcono
                height: insigniaFila.altoIcono
                x: index * insigniaFila.pasoX
                y: insigniaFila.cuenta === 3 && !iconoInsignia.esCentro
                   ? insigniaFila.altoIcono * 0.34 : 0
                rotation: insigniaFila.cuenta === 3
                          ? (index === 0 ? -12 : index === 2 ? 12 : 0)
                          : 0
                transformOrigin: Item.Bottom
                z: iconoInsignia.esCentro ? 1 : 0
                onPaint: avatar.dibujarInsignia(getContext("2d"), width, height)
            }
        }
    }

    // ── Fase 5 del sistema de progresión: Decoraciones -- dos slots
    // laterales (misma forma, "cualquier decoración cabe en cualquiera de
    // los dos") + uno superior, más ancho. Se dibujan ALREDEDOR de la
    // marca cardinal correspondiente (que se oculta en cuanto el lado se
    // ocupa, ver el Repeater de marcoMetalico más arriba), no encajados
    // dentro de ella.
    //
    // Iconos reales de game-icons.net (CC BY 3.0). Recoloreados al estilo
    // de la app (assets/iconos/, ver el comentario de cmake/ClientesQt.cmake).
    // Crédito por icono (autor/nombre original en game-icons.net):
    //   gema_roja/azul  -- lorc/cut-diamond (gema tallada de verdad, no
    //                      la insignia plana "badges/diamond" original)
    //   punto_de_luz    -- delapouite/sparkles
    //   carta_poker     -- aussiesim/card-ace-spades
    //   pila_fichas     -- badges/coins
    //   colmillo        -- skoll/fangs
    //   ojo_vigilante   -- delapouite/eye-target
    //   corona_laurel   -- lorc/laurel-crown
    //   cinta_ondulada  -- lorc/ribbon
    //   constelacion    -- delapouite/star-formation
    //   corona_inicial  -- lorc/crown
    //   mano_real       -- abanico de 5 cartas, ver más abajo (autor
    //                      "aussiesim", cards 10/J/Q/K/A de picas)
    //   corona_real     -- delapouite/imperial-crown
    //   palos_en_fila   -- badges/{club,diamond,heart,spade} sobre una
    //                      placa de marfil, compuesto al generar el PNG
    // Los PNG se regeneran con scripts/generar_iconos.sh: llevan contorno
    // oscuro + degradado, no un color plano. El color plano hacía
    // desaparecer los iconos claros sobre el tema claro (constelación era
    // blanco puro) y los dejaba sin volumen.
    function rutaIconoDecoracion(codigo, acabado) {
        var base = "qrc:/qt/qml/PokerQuickMobile/assets/iconos/";
        // Regla: "el nombre del fichero es el propio código" -- solo
        // hacen falta casos especiales para lo que NO sigue esa regla:
        // nada equipado, o un código que se compone aparte con varias
        // piezas (las cartas de la baraja llevan su propio respaldo de
        // color -- ver esCarta/colorPaloCarta -- y cualquier corona de
        // cartas de composicionesCartas se pinta en coronaDeCartas más
        // abajo, no como una sola Image). "palos_en_fila" ERA otro caso
        // especial: desde 2026-09-09 la placa con los cuatro palos se
        // compone al generar el PNG, así que vuelve a cumplir la regla.
        if (codigo === "" || avatar.esComposicionDeCartas(codigo)) {
            return "";
        }
        return base + codigo + avatar.sufijoAcabado(codigo, acabado || "") + ".png";
    }
    // ── Acabado por material (fase 1 del plan, 2026-09-10) ────────────────
    // Las decoraciones METÁLICAS se pintan en el metal del marco que lleva el
    // jugador: un laurel dorado sobre un marco de hierro parecía de otro
    // juego, y le comía al marco -- lo único del avatar que se GANA y no se
    // compra -- su papel de señal de progresión. Aprobado por el usuario
    // sobre una maqueta de los cinco metales. Las que NO son de metal
    // (naipes, palos, gemas, colmillo, fichas, punto de luz) conservan su
    // color: un naipe es rojo y negro, una gema es su piedra. Razonado en
    // docs/plan-material-cosmeticos.md.
    //
    // Cada variante es un PNG propio (<icono>_<metal>.png, generado por
    // scripts/generar_iconos.sh), no un tinte por shader: así se ve
    // EXACTAMENTE lo que se aprobó, y aquí no cuesta más que cambiar la ruta
    // de una Image -- un shader obligaría a meter una capa en cada decoración
    // de cada avatar de la app. ⚠️ La lista está en
    // Tema.qml (decoracionesMetalicas) y tiene que coincidir con METALICOS del
    // script y con ICONOS_METALICOS de cmake/ClientesQt.cmake.
    function sufijoAcabado(codigo, acabado) {
        // Solo las decoraciones de metal cambian de fichero. Manda el acabado
        // elegido; sin él ("" = sigue al marco), el metal del marco. El oro
        // usa el fichero base, que ya es dorado, y sin ningún metal (campeón,
        // o sin marco) también: es como se veía siempre.
        if (!Tema.decoracionesMetalicas[codigo]) return "";
        var metal = acabado !== "" ? acabado : (avatar.esTierMetalico ? avatar.marco : "");
        return (metal === "" || metal === "oro") ? "" : "_" + metal;
    }
    // Gemas -- engaste de metal en forma de rombo (como la propia gema)
    // detrás del icono, del color del marco.
    function esGema(codigo) {
        return codigo === "gema_roja" || codigo === "gema_azul";
    }
    // Cualquier carta suelta -- "carta_poker" hoy, más las 52 de la
    // baraja completa, todas con el mismo prefijo. El icono real
    // (aussiesim) es un recorte: el número/letra y el palo son AGUJEROS
    // transparentes en el propio path, no un color de relleno -- el
    // respaldo de abajo resuelve que se vean bien en cualquier tema (los
    // agujeros muestran ESE respaldo, no el fondo de la app) y da
    // contorno visible.
    function esCarta(codigo) {
        return codigo.indexOf("carta_") === 0;
    }
    // Rojo para corazones/diamantes, negro para tréboles/picas -- como
    // una carta de verdad. El respaldo de abajo (ver decoLateralIzq/Der
    // y coronaDeCartas) es lo que da color al número/palo (agujeros
    // transparentes en el icono real), así que este color es el que de
    // verdad se ve.
    function colorPaloCarta(codigo) {
        return (codigo.indexOf("_corazones") >= 0 || codigo.indexOf("_diamantes") >= 0)
               ? "#8a2c22" : "#1c1c1c";
    }
    // Proporción ancho:alto real de los iconos de carta (aussiesim,
    // medida tras recortar el margen transparente). El respaldo de color
    // (ver esCarta más arriba) mide a partir de la MISMA proporción,
    // para que siempre coincidan con el tamaño real de la imagen.
    readonly property real aspectoCarta: 0.756
    // Y cuánto del PNG es margen transparente: el naipe mide 218x288 en
    // un lienzo de 320x320. Sin esta cuenta la Image se ponía "del tamaño
    // del hueco" y, con un lienzo cuadrado dentro de un hueco que no lo
    // es, PreserveAspectFit dejaba el naipe más pequeño que su propio
    // respaldo de color (bug real reportado 2026-09-09: "el borde de
    // fondo de color es demasiado predominante").
    readonly property real escalaLienzoCarta: 320 / 218

    Item {
        id: decoLateralIzq
        property string codigo: avatar.decoracionLateral1
        property string acabado: avatar.acabadoLateral1
        visible: codigo !== ""
        width: avatar.tamano * 0.46
        height: width
        // Alto del naipe dentro del hueco -- subido de 0.68 a 0.86
        // (pedido explícito 2026-09-09).
        readonly property real altoCarta: height * 0.86
        readonly property real anchoCarta: altoCarta * avatar.aspectoCarta
        // -0.50 -- con la mitad del hueco solapando el anillo, el centro
        // de la decoración cae justo en el borde, igual que las marcas
        // cardinales a las que sustituye.
        anchors.right: marcoMetalico.left
        anchors.rightMargin: -width * 0.50
        anchors.verticalCenter: marcoMetalico.verticalCenter

        Rectangle {
            anchors.centerIn: parent
            visible: avatar.esGema(decoLateralIzq.codigo)
            width: parent.width * 0.68
            height: width
            rotation: 45
            radius: width * 0.08
            border.width: Math.max(1.5, avatar.tamano * 0.025)
            border.color: avatar.tierActualColores[3]
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(avatar.tierActualColores[2], 1.2) }
                GradientStop { position: 1.0; color: avatar.tierActualColores[3] }
            }
            // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
            layer.enabled: true
            layer.effect: ShaderEffect {
                property variant source
                property real amplitud: 3.0
                fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
            }
        }
        Rectangle {
            anchors.centerIn: parent
            visible: avatar.esCarta(decoLateralIzq.codigo)
            // Se dimensiona A PARTIR del naipe (altoCarta/anchoCarta)
            // más un margen fino, no al revés.
            height: decoLateralIzq.altoCarta * 1.05
            width: decoLateralIzq.anchoCarta * 1.07
            radius: width * 0.13
            color: avatar.colorPaloCarta(decoLateralIzq.codigo)
            border.width: Math.max(1, avatar.tamano * 0.012)
            border.color: avatar.tierActualColores[3]
        }
        Image {
            anchors.centerIn: parent
            // Para una carta la Image es CUADRADA (como el lienzo del
            // PNG) y más grande que el naipe, para que el naipe acabe
            // midiendo anchoCarta x altoCarta.
            width: avatar.esGema(decoLateralIzq.codigo) ? parent.width * 0.52
                 : avatar.esCarta(decoLateralIzq.codigo) ? decoLateralIzq.anchoCarta * avatar.escalaLienzoCarta
                 : parent.width
            height: avatar.esGema(decoLateralIzq.codigo) ? parent.height * 0.52
                  : avatar.esCarta(decoLateralIzq.codigo) ? width
                  : parent.height
            fillMode: Image.PreserveAspectFit
            smooth: true
            // Sin mipmap, encoger el PNG hasta los ~40 px de una
            // decoración deja bordes dentados: ESO, y no la resolución
            // del fichero, es lo que se veía "pixelado".
            mipmap: true
            source: avatar.rutaIconoDecoracion(decoLateralIzq.codigo, decoLateralIzq.acabado)
        }
    }
    Item {
        id: decoLateralDer
        property string codigo: avatar.decoracionLateral2
        property string acabado: avatar.acabadoLateral2
        visible: codigo !== ""
        width: avatar.tamano * 0.46
        height: width
        // Alto del naipe dentro del hueco -- subido de 0.68 a 0.86
        // (pedido explícito 2026-09-09).
        readonly property real altoCarta: height * 0.86
        readonly property real anchoCarta: altoCarta * avatar.aspectoCarta
        anchors.left: marcoMetalico.right
        anchors.leftMargin: -width * 0.50
        anchors.verticalCenter: marcoMetalico.verticalCenter

        Rectangle {
            anchors.centerIn: parent
            visible: avatar.esGema(decoLateralDer.codigo)
            width: parent.width * 0.68
            height: width
            rotation: 45
            radius: width * 0.08
            border.width: Math.max(1.5, avatar.tamano * 0.025)
            border.color: avatar.tierActualColores[3]
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(avatar.tierActualColores[2], 1.2) }
                GradientStop { position: 1.0; color: avatar.tierActualColores[3] }
            }
            // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
            layer.enabled: true
            layer.effect: ShaderEffect {
                property variant source
                property real amplitud: 3.0
                fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
            }
        }
        Rectangle {
            anchors.centerIn: parent
            visible: avatar.esCarta(decoLateralDer.codigo)
            height: decoLateralDer.altoCarta * 1.05
            width: decoLateralDer.anchoCarta * 1.07
            radius: width * 0.13
            color: avatar.colorPaloCarta(decoLateralDer.codigo)
            border.width: Math.max(1, avatar.tamano * 0.012)
            border.color: avatar.tierActualColores[3]
        }
        Image {
            anchors.centerIn: parent
            // Para una carta la Image es CUADRADA (como el lienzo del
            // PNG) y más grande que el naipe, para que el naipe acabe
            // midiendo anchoCarta x altoCarta.
            width: avatar.esGema(decoLateralDer.codigo) ? parent.width * 0.52
                 : avatar.esCarta(decoLateralDer.codigo) ? decoLateralDer.anchoCarta * avatar.escalaLienzoCarta
                 : parent.width
            height: avatar.esGema(decoLateralDer.codigo) ? parent.height * 0.52
                  : avatar.esCarta(decoLateralDer.codigo) ? width
                  : parent.height
            fillMode: Image.PreserveAspectFit
            smooth: true
            // Sin mipmap, encoger el PNG hasta los ~40 px de una
            // decoración deja bordes dentados: ESO, y no la resolución
            // del fichero, es lo que se veía "pixelado".
            mipmap: true
            source: avatar.rutaIconoDecoracion(decoLateralDer.codigo, decoLateralDer.acabado)
        }
    }
    // Toda decoración superior que sea UNA imagen se pinta aquí; las
    // "coronas de cartas" viven fuera, ancladas a marcoMetalico -- ver
    // coronaDeCartas.
    //
    // "palos_en_fila" tenía aquí su propio Row de cuatro suit_*.png hasta
    // 2026-09-09. Los palos salían en crema y deben ser NEGROS (picas y
    // tréboles), pero pintarlos de negro sin más habría recreado el mismo
    // bug en espejo: invisibles sobre el tema oscuro. Ahora los cuatro
    // van sobre una placa de marfil compuesta al generar el PNG, que se
    // lee igual en los dos temas -- y esto vuelve a ser una Image normal.
    Item {
        id: decoSuperior
        property string codigo: avatar.decoracionSuperior
        property string acabado: avatar.acabadoSuperior
        visible: codigo !== "" && !avatar.esComposicionDeCartas(codigo)
        width: avatar.tamano * 0.85
        height: avatar.tamano * 0.42
        anchors.bottom: marcoMetalico.top
        anchors.bottomMargin: -height * 0.38
        anchors.horizontalCenter: marcoMetalico.horizontalCenter

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            source: avatar.rutaIconoDecoracion(decoSuperior.codigo, decoSuperior.acabado)
        }
    }

    // "Corona de cartas" -- GENÉRICA, corona de N cartas reales
    // repartidas en arco sobre el borde superior del anillo, cada una
    // girada según su propio ángulo y solapándose con la siguiente. UNA
    // tabla (composicionesCartas) más este único bloque -- un logro
    // nuevo con este tipo de recompensa es una fila nueva en la tabla,
    // sin tocar nada de aquí abajo. Reutiliza los mismos 52 PNG de la
    // baraja (carta_<rango>_<palo>.png) -- ningún icono nuevo hace falta
    // para una decoración de este tipo.
    readonly property var composicionesCartas: ({
        "mano_real": [
            {r: "10", s: "picas"}, {r: "jack", s: "picas"}, {r: "queen", s: "picas"},
            {r: "king", s: "picas"}, {r: "ace", s: "picas"}
        ],
        "escalera_diamantes": [
            {r: "3", s: "diamantes"}, {r: "4", s: "diamantes"}, {r: "5", s: "diamantes"},
            {r: "6", s: "diamantes"}, {r: "7", s: "diamantes"}
        ],
        "cuatro_ases": [
            {r: "ace", s: "treboles"}, {r: "ace", s: "diamantes"},
            {r: "ace", s: "corazones"}, {r: "ace", s: "picas"}
        ]
    })
    function esComposicionDeCartas(codigo) {
        return avatar.composicionesCartas[codigo] !== undefined;
    }

    Item {
        id: coronaDeCartas
        readonly property var composicion: avatar.composicionesCartas[avatar.decoracionSuperior] || []
        visible: composicion.length > 0
        anchors.centerIn: marcoMetalico
        width: 0
        height: 0
        Repeater {
            model: coronaDeCartas.composicion
            delegate: Item {
                id: cartaCorona
                required property var modelData
                required property int index
                readonly property real radio: marcoMetalico.width / 2 * 0.98
                // 26° entre cartas contiguas -- para 5 cartas da
                // exactamente ±52°/±26°/0°; para cualquier otro N reparte
                // igual de ancho por carta.
                readonly property real angulo: (index - (coronaDeCartas.composicion.length - 1) / 2) * 26
                readonly property real anguloRad: angulo * Math.PI / 180
                readonly property string codigoCarta: "carta_" + modelData.r + "_" + modelData.s
                // Este Item ES el naipe: el respaldo de color se sale un
                // poco de él (margen NEGATIVO) y la Image se pone más
                // grande para compensar el margen transparente del PNG.
                // Antes era al revés y el naipe quedaba mucho más pequeño
                // que su respaldo. Subido de 0.27 a 0.30 (2026-09-09).
                width: avatar.tamano * 0.30
                height: width / avatar.aspectoCarta
                x: radio * Math.sin(anguloRad) - width / 2
                y: -radio * Math.cos(anguloRad) - height
                transformOrigin: Item.Bottom
                rotation: angulo
                z: index

                // Mismo respaldo de color por palo que decoLateralIzq/Der
                // -- el icono real recorta el número/palo como agujero
                // transparente, sin esto se ve vacío/invisible en tema
                // claro. Importante para "cuatro_ases", que mezcla los 4
                // palos en la misma corona.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -parent.width * 0.05
                    radius: width * 0.12
                    color: avatar.colorPaloCarta(cartaCorona.codigoCarta)
                    border.width: Math.max(1, avatar.tamano * 0.01)
                    border.color: avatar.tierActualColores[3]
                }
                Image {
                    anchors.centerIn: parent
                    width: parent.width * avatar.escalaLienzoCarta
                    height: width
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    source: "qrc:/qt/qml/PokerQuickMobile/assets/iconos/" + cartaCorona.codigoCarta + ".png"
                }
            }
        }
    }
}
