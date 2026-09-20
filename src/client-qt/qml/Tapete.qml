// Tapete.qml — el paño de la mesa: la "pastilla" sobre la que se juega.
// Extraído de Mesa.qml para poder revisar cada tapete aislado en AvatarTest
// (--solo-tapetes) y para que Mesa.qml solo decida CUÁL toca, igual que con
// Carta.reversoSkin.
//
// "preset" = código del tapete equipado ("" = el de siempre, que sale del
// tema activo). Son presets curados, no un selector libre de color: un
// color a gusto casi garantiza mesas feas (decisión ya tomada, ver
// docs/plan-tienda-v2.md §1.2).
//
// ESCALA: ni la madera ni los dibujos se estiran para llenar la mesa (se veía
// "creado a escala pequeña" en una mesa grande). La madera se pinta a tamaño
// casi real y se recorta a la pastilla; los dibujos son teselas que se
// repiten con un tamaño de celda acotado. Resultado: una mesa más grande
// tiene MÁS veta y MÁS dibujo, con la misma densidad por píxel.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

Item {
    id: tapete

    property string preset: ""
    // Miniatura (rejilla de Tienda/Personalizar): sin dibujo ni pespunte --
    // a 40px no se distinguirían, y cada capa de más es un efecto por tarjeta.
    property bool miniatura: false

    // "preset" = "tipo" o "tipo:variante" (p. ej. "tapete_rombos:granate",
    // "tapete_madera:nogal"). El TIPO es lo que se compra (la textura); el color
    // del paño o la madera se elige al equiparlo. Sin variante, la de por defecto
    // (verde / roble). ⚠️ Los colores y maderas tienen que coincidir con
    // varianteTapeteValida() de AccountManager.cpp.
    readonly property var tipos: ({
        "tapete_rombos": { patron: "rombos", patronOpacidad: 0.16 },
        "tapete_palos":  { patron: "palos",  patronOpacidad: 0.11 },
        "tapete_puntos": { patron: "puntos", patronOpacidad: 0.15 },
        "tapete_lino":   { patron: "lino",   patronOpacidad: 0.10 },
        "tapete_rayas":  { patron: "rayas",  patronOpacidad: 0.09 },
        // El paño de "casino" es el del tema activo: lo que cambia es el
        // marco de madera, así que combina con cualquier paleta.
        "tapete_casino": { riel: true },
        "tapete_madera": { madera: true }
    })
    readonly property var colores: ({
        "verde":     { claro: "#2F6B51", oscuro: "#1B4332", borde: "#2A5A44", pespunte: "#D4A24E" },
        "granate":   { claro: "#7A2C3D", oscuro: "#4D1B26", borde: "#632A38", pespunte: "#D4A24E" },
        "azul":      { claro: "#2B5582", oscuro: "#173250", borde: "#2A4A63", pespunte: "#D4A24E" },
        "grafito":   { claro: "#454A52", oscuro: "#2B2E33", borde: "#44484E", pespunte: "#C9CED6" },
        "taberna":   { claro: "#8A5A34", oscuro: "#5A3520", borde: "#8F5A30", pespunte: "#D9A566" },
        // Crema y oro (el único claro): su dibujo va oscurecido y más marcado.
        "porcelana": { claro: "#EBD8AA", oscuro: "#CFAE6C", borde: "#A67C2E", pespunte: "#8A6423",
                       patronColor: "#6E4E1A", opacidadMult: 1.8 },
        "violeta":   { claro: "#6A4C93", oscuro: "#3E2A5C", borde: "#4F3A75", pespunte: "#D4A24E" },
        "petroleo":  { claro: "#2A7F86", oscuro: "#154B50", borde: "#1F6167", pespunte: "#D4A24E" }
    })
    // La madera se tiñe desde una sola imagen (brillo/saturación/tinte encima).
    readonly property var maderas: ({
        "roble":         { brillo: 0.0,   saturacion: 0.0,   tinte: "",        tinteFuerza: 0.0 },
        "roble_oscuro":  { brillo: -0.36, saturacion: 0.05,  tinte: "",        tinteFuerza: 0.0 },
        "nogal":         { brillo: -0.46, saturacion: -0.05, tinte: "#5B3A4A", tinteFuerza: 0.30 }
    })
    // Códigos de antes de que hubiera tipo + color (un servidor o un anfitrión
    // anteriores los siguen mandando): se traducen al equivalente.
    readonly property var codigosAntiguos: ({
        "tapete_clasico": "tapete_rombos:verde", "tapete_granate": "tapete_palos:granate",
        "tapete_azul": "tapete_puntos:azul", "tapete_grafito": "tapete_rombos:grafito",
        "tapete_taberna": "tapete_rombos:taberna", "tapete_porcelana": "tapete_palos:porcelana"
    })
    readonly property string presetEfectivo: codigosAntiguos[preset] || preset
    readonly property string tipoId: presetEfectivo.indexOf(":") >= 0 ? presetEfectivo.split(":")[0] : presetEfectivo
    readonly property string variante: presetEfectivo.indexOf(":") >= 0 ? presetEfectivo.split(":")[1] : ""
    readonly property var estilo: {
        var t = tipos[tipoId];
        if (!t) return null;
        var e = {};
        for (var k in t) e[k] = t[k];
        if (t.madera || t.riel) {
            var m = maderas[variante] || maderas["roble"];
            for (var km in m) e[km] = m[km];
        } else {
            var c = colores[variante] || colores["verde"];
            for (var kc in c) e[kc] = c[kc];
            e.patronOpacidad = t.patronOpacidad * (c.opacidadMult || 1.0);
        }
        return e;
    }

    readonly property bool esMadera: estilo !== null && estilo.madera === true
    readonly property bool conRiel: estilo !== null && estilo.riel === true
    readonly property bool usaMadera: esMadera || conRiel
    readonly property string patron: !miniatura && estilo && estilo.patron ? estilo.patron : ""
    readonly property color colorPespunte: estilo && estilo.pespunte ? estilo.pespunte : Tema.colorAccent

    readonly property color colorClaro: estilo && estilo.claro ? estilo.claro
                                        : Qt.lighter(Tema.colorTapete, 1.22)
    readonly property color colorOscuro: estilo && estilo.oscuro ? estilo.oscuro
                                         : Tema.colorTapete
    readonly property color colorBorde: estilo && estilo.borde ? estilo.borde : Tema.colorBorde

    // Aro exterior oscuro: casi de grosor FIJO en píxeles. Tapa el borde de la
    // máscara (que sale con dientes de sierra) y da el canto de la mesa; si
    // creciera con la mesa (como antes, un % de la altura) se convertía en
    // una banda enorme en pantalla grande.
    readonly property real grosorBorde: Math.min(7, Math.max(2, height * 0.03))
    readonly property real grosorRiel: conRiel ? Math.min(height * 0.11, 64) : 0
    readonly property color maderaOscura: "#2A1508"

    // Densidad: la madera (2600x1300) se muestra entre 0.12x y 0.75x -- en una
    // mesa de pantalla completa va a 0.75x, sin ampliar, así que la veta no se
    // ensancha; si aun así la mesa es mayor que la imagen, se amplía lo justo
    // para cubrirla. Las celdas de los dibujos (px lógicos a densidad plena)
    // solo se achican en mesas pequeñas (factor 0.35-1, hasta unos 490px de
    // ancho: en la vista previa del móvil, con la mesa diminuta, un par de
    // rombos y una veta gigante no se leían como tapete), nunca crecen.
    readonly property real escalaMadera: Math.max(0.12, Math.min(0.75, width / 1500))
    readonly property real factorDensidad: Math.max(0.35, Math.min(1, width / 1400))
    readonly property var periodoBase: ({ rombos: 44, palos: 84, puntos: 18, lino: 18, rayas: 16 })
    readonly property real periodoPatron: patron === "" ? 1
                                          : Math.max(6, Math.round(periodoBase[patron] * factorDensidad))

    // ── Madera (pastilla entera o aro del riel) ──────────────────────────
    Item {
        anchors.fill: parent
        visible: tapete.usaMadera

        // La imagen va dentro de un Item con layer: es lo que se recorta.
        Item {
            id: capaMadera
            anchors.fill: parent
            visible: false
            clip: true
            layer.enabled: true
            Image {
                id: imagenMadera
                readonly property real cubrir: Math.max(capaMadera.width / 2600, capaMadera.height / 1300)
                readonly property real factor: Math.max(tapete.escalaMadera, cubrir)
                anchors.centerIn: parent
                width: 2600 * factor
                height: 1300 * factor
                source: "qrc:/qt/qml/PokerQuick/assets/tapetes/madera.png"
                mipmap: true
            }
        }
        // La máscara queda 1px por dentro de la pastilla: su borde nunca
        // asoma por fuera del aro oscuro de abajo.
        Item {
            id: mascaraMadera
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: height / 2
                color: "black"
            }
        }
        MultiEffect {
            anchors.fill: parent
            source: capaMadera
            maskEnabled: true
            maskSource: mascaraMadera
            // Variante de madera (roble / roble oscuro / nogal): la misma imagen,
            // más oscura o teñida.
            brightness: tapete.estilo && tapete.estilo.brillo ? tapete.estilo.brillo : 0.0
            saturation: tapete.estilo && tapete.estilo.saturacion ? tapete.estilo.saturacion : 0.0
            colorization: tapete.estilo && tapete.estilo.tinteFuerza ? tapete.estilo.tinteFuerza : 0.0
            colorizationColor: tapete.estilo && tapete.estilo.tinte ? tapete.estilo.tinte : "white"
        }
        // Volumen: luz arriba, sombra abajo -- sin esto la veta se ve plana.
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.30) }
            }
        }
        // Canto exterior oscuro + filo de luz justo dentro (bisel).
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.color: tapete.maderaOscura
            border.width: tapete.grosorBorde
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: tapete.grosorBorde
            radius: height / 2
            color: "transparent"
            border.color: Qt.rgba(1, 0.82, 0.55, 0.30)
            border.width: 1
        }
        // Filo de luz en el mismo canto: sobre un fondo tan oscuro como el
        // del tema Taberna, el aro de madera oscura se fundía con él.
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.color: Qt.rgba(1, 0.82, 0.55, 0.28)
            border.width: 1
        }
    }

    // ── Paño (con o sin aro de madera) ───────────────────────────────────
    Item {
        id: pano
        visible: !tapete.esMadera
        anchors.fill: parent
        anchors.margins: tapete.grosorRiel

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            border.color: tapete.conRiel ? Qt.darker(tapete.colorOscuro, 1.5) : tapete.colorBorde
            border.width: 3
            gradient: Gradient {
                GradientStop { position: 0.0; color: tapete.colorClaro }
                GradientStop { position: 1.0; color: tapete.colorOscuro }
            }
            // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
            layer.enabled: true
            layer.effect: ShaderEffect {
                property variant source
                property real amplitud: 30.0
                fragmentShader: "qrc:/qt/qml/PokerQuick/assets/shaders/dither.frag.qsb"
            }
        }

        // Dibujo encima del paño: una tesela pequeña REPETIDA (no estirada),
        // recortada a la pastilla.
        Item {
            anchors.fill: parent
            visible: tapete.patron !== ""
            Item {
                id: capaPatron
                anchors.fill: parent
                visible: false
                clip: true
                layer.enabled: true
                Image {
                    anchors.fill: parent
                    source: tapete.patron === "" ? ""
                            : "qrc:/qt/qml/PokerQuick/assets/tapetes/tesela_" + tapete.patron + ".png"
                    fillMode: Image.Tile
                    sourceSize.width: tapete.periodoPatron
                    sourceSize.height: tapete.periodoPatron
                    smooth: true
                }
            }
            Item {
                id: mascaraPano
                anchors.fill: parent
                visible: false
                layer.enabled: true
                layer.smooth: true
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: height / 2
                    color: "black"
                }
            }
            MultiEffect {
                anchors.fill: parent
                source: capaPatron
                maskEnabled: true
                maskSource: mascaraPano
                colorization: tapete.estilo && tapete.estilo.patronColor ? 1.0 : 0.0
                colorizationColor: tapete.estilo && tapete.estilo.patronColor ? tapete.estilo.patronColor : "white"
                opacity: tapete.estilo && tapete.estilo.patronOpacidad ? tapete.estilo.patronOpacidad : 0
            }
        }

        // Pespunte: línea fina inscrita, como la costura de un tapete de casino.
        Rectangle {
            visible: !tapete.miniatura && (tapete.estilo !== null && !!tapete.estilo.pespunte || tapete.conRiel)
            anchors.fill: parent
            anchors.margins: Math.min(parent.height * 0.055, 26)
            radius: height / 2
            color: "transparent"
            border.color: tapete.colorPespunte
            border.width: 1.5
            opacity: 0.6
        }
    }
}
