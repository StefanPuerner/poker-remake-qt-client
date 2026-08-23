// Avatar.qml — círculo + inicial (como siempre) con un "marco" opcional
// alrededor, desbloqueable por logros. El círculo interior NUNCA cambia
// (el día que haya foto de perfil, sustituye solo a la inicial, sin tocar
// nada de aquí) -- toda la personalización vive en el marco. Ver el
// lienzo de diseño aprobado (marcos de avatar) para el porqué de cada
// estilo.
//
// "marco" -- valores válidos:
//   "ninguno"          -- sin marco, el círculo de siempre (Asiento hoy).
//   "bronce"/"plata"/"oro"/"platino" -- nivel permanente por partidas
//        ganadas, anillo metálico de 3 paradas, estático. Platino además
//        lleva un brillo giratorio propio (lento, sin halo ni insignia)
//        para que no se confunda con plata a simple vista.
//   "campeonVictorias"/"campeonRatio" -- PODIO, puesto 1 del ranking
//        global (por victorias o por ratio) -- tratamiento completo:
//        halo que respira + anillo degradado + barrido cónico + insignia
//        (destello de 8 puntas con brillo, no un icono recortado a mano).
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

    readonly property bool esTierMetalico: marco === "bronce" || marco === "plata" ||
                                            marco === "oro" || marco === "platino"
    readonly property bool esPlatino: marco === "platino"

    readonly property var coloresTier: ({
        "bronce":  ["#c98f5f", "#e0a874", "#b5794c", "#4a2f1a"],
        "plata":   ["#9aa4ab", "#c9d0d4", "#aeb6bb", "#4d545a"],
        "oro":     [Tema.colorAccent, "#e3bb82", "#e3bb82", "#7d5a26"],
        "platino": ["#eef3ff", "#ffffff", "#dce6ff", "#8d9ad1"]
    })
    // [colorLetra, gradClaro, gradMedio, gradOscuro] -- oro reutiliza
    // Tema.colorAccent tal cual para la letra, igual que el círculo sin
    // marco de toda la vida. Plata en gris medio (no casi-blanco) para
    // que platino, con su brillo, se note claramente por encima.
    readonly property var tierActual: coloresTier[marco] || ["", "", "", ""]

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

    width: avatar.tamano
    height: avatar.tamano

    // ── Marco metálico (niveles permanentes) ────────────────────────────
    Rectangle {
        visible: avatar.esTierMetalico
        anchors.centerIn: parent
        width: avatar.tamano * 1.16
        height: avatar.tamano * 1.16
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: avatar.tierActual[1] }
            GradientStop { position: 0.45; color: avatar.tierActual[2] }
            GradientStop { position: 1.0; color: avatar.tierActual[3] }
        }
        // Cuatro marcas cardinales -- mismo detalle "ornamentado" del
        // lienzo aprobado, ahora más grandes y con borde propio para que
        // se noten incluso al tamaño de Asiento (56px).
        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                width: Math.max(3, avatar.tamano * 0.09)
                height: width
                radius: 1
                color: "#fff8ec"
                border.width: Math.max(1, avatar.tamano * 0.014)
                border.color: avatar.tierActual[3]
                rotation: 45
                anchors.horizontalCenter: index % 2 === 0 ? parent.horizontalCenter : undefined
                anchors.verticalCenter: index % 2 === 1 ? parent.verticalCenter : undefined
                anchors.top: index === 0 ? parent.top : undefined
                anchors.bottom: index === 2 ? parent.bottom : undefined
                anchors.left: index === 3 ? parent.left : undefined
                anchors.right: index === 1 ? parent.right : undefined
                anchors.margins: avatar.tamano * 0.02
            }
        }
    }

    // ── Brillo exclusivo de Platino -- lo distingue de Plata a simple
    // vista sin necesitar la parafernalia de campeón (sin halo, sin
    // insignia): un barrido lento y sutil sobre el propio anillo.
    Item {
        visible: avatar.esPlatino
        anchors.centerIn: parent
        width: avatar.tamano * 1.16
        height: avatar.tamano * 1.16
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
    }
    // Barrido cónico -- por encima del anillo, solo el puesto 1 lo lleva
    // ("sin rotación" para el 2 y el 3, tal como se acordó).
    Item {
        visible: avatar.esCampeon && avatar.posicionPodio === 1
        anchors.centerIn: parent
        width: avatar.tamano * 1.16
        height: avatar.tamano * 1.16
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
        }
    }

    // ── Círculo base -- SIEMPRE igual, con o sin marco ──────────────────
    Rectangle {
        id: nucleo
        anchors.centerIn: parent
        width: avatar.tamano
        height: avatar.tamano
        radius: width / 2
        border.width: 2
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
        Text {
            anchors.centerIn: parent
            text: avatar.letra
            color: avatar.esCampeon ? avatar.colorCampeon
                   : avatar.esTierMetalico ? avatar.tierActual[0]
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
}
