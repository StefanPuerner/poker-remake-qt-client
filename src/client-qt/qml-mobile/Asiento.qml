// Asiento.qml (móvil) — idéntico al de escritorio: sin MouseArea/hover,
// no necesita ningún cambio para tacto. Puesto al día 2026-09-01 (Fase
// M0 del port de progresión a móvil, ver memoria
// qt_mobile_progression_port_plan) con la "parte B" de visibilidad a
// otros jugadores (loadout completo por asiento, no solo el tier de
// marco) y el arreglo del anillo de resplandor de turno, los dos ya
// hechos en escritorio el mismo día -- ver Asiento.qml de escritorio
// para el detalle largo de cada uno.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Column {
    id: asiento
    property string saldo
    property string nombre
    // Para el marco de avatar permanente (ver Tema.marcoPorPartidasGanadas
    // y Avatar.qml) -- viene de GAME_STATE, así que funciona para
    // CUALQUIER jugador sentado, no solo el propio.
    property int partidasGanadas: 0
    // Visibilidad a otros jugadores, parte B (2026-09-01 -- ver memoria
    // qt_progression_review_2026_09_01, portado el mismo día a móvil):
    // loadout REAL de quien esté sentado aquí, no solo el tier de marco.
    // "" = nada equipado en ese slot, igual que en todo el resto de la
    // app.
    property bool tieneMarcoBasico: false
    property string textura: ""
    property string efecto: ""
    property string decoracionLateral1: ""
    property string decoracionLateral2: ""
    property string decoracionSuperior: ""
    property string acabadoLateral1: ""
    property string acabadoLateral2: ""
    property string acabadoSuperior: ""
    property bool activo: false
    property real fraccionTiempo: 1.0
    property bool retirado: false
    // Dealer/ciegas de la mano actual (servidor, ver GAME_STATE). Un mismo
    // asiento puede ser dealer Y small blind a la vez (heads-up: el dealer
    // paga la ciega pequeña) -- por eso son propiedades independientes, no
    // un enum "posicion" de un solo valor.
    property bool esDealer: false
    property bool esSb: false
    property bool esBb: false
    // Mini-cartas de mesa -- Fase 1 de "segunda ola de cosméticos"
    // (2026-09-17). A diferencia de escritorio, en móvil TODAS las
    // sillas llevan mini-cartas, incluida la propia (pedido explícito:
    // "en móvil no se ven tan directamente como en escritorio") -- la
    // propia sale boca ARRIBA con las cartas reales (miCarta1/miCarta2,
    // ya las conoces), las de los rivales boca abajo con el reverso ya
    // resuelto por Mesa.qml (reversoActivo, el mismo valor para todos:
    // el del dealer, o el propio si eres el único humano).
    property string reversoActivo: ""
    property bool esPropio: false
    property string miCarta1: ""
    property string miCarta2: ""
    opacity: retirado ? 0.45 : 1.0
    onActivoChanged: anillo.requestPaint()
    onFraccionTiempoChanged: if (activo)
        anillo.requestPaint()
    spacing: 8 * Tema.escala

    Item {
        x: (parent.width - width) / 2
        // Math.round(46*Tema.escala) -- MISMO valor que Avatar.qml
        // calcula internamente para su propio "width". Bug real
        // arreglado aquí también (2026-09-01, mismo día que en
        // escritorio): antes este contenedor no redondeaba, así que su
        // ancho fraccionario no coincidía en resto con el ancho YA
        // redondeado del Avatar centrado dentro -- el halo de "es tu
        // turno" quedaba centrado en el contenedor pero no en el avatar
        // que de verdad se ve, dando un anillo visualmente descentrado.
        width: Math.round(46 * Tema.escala) + 10
        height: width

        Rectangle {
            visible: activo
            anchors.centerIn: parent
            width: parent.width + 16
            height: parent.height + 16
            radius: width / 2
            color: "transparent"
            border.width: 7 * Tema.escala
            border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.12)
        }
        Rectangle {
            visible: activo
            anchors.centerIn: parent
            // "+6", no "+5" -- mismo motivo que el redondeo de arriba:
            // con un contenedor ya entero, un margen IMPAR deja una
            // diferencia impar entre este anillo y su padre, dando otra
            // vez medio píxel de desfase, esta vez en el propio anillo
            // interior.
            width: parent.width + 6
            height: parent.height + 6
            radius: width / 2
            color: "transparent"
            border.width: 3 * Tema.escala
            border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.3)
        }

        Canvas {
            id: anillo
            anchors.fill: parent
            visible: activo
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var cx = width / 2;
                var cy = height / 2;
                var r = width / 2 - 2;
                ctx.strokeStyle = fraccionTiempo < 0.2 ? Tema.colorPeligro : Tema.colorAccent;
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + fraccionTiempo * 2 * Math.PI);
                ctx.stroke();
            }
        }

        Avatar {
            anchors.centerIn: parent
            letra: nombre.charAt(0)
            tamano: 46 * Tema.escala
            // tieneMarcoBasico como 2º argumento -- bug real ya
            // encontrado varias veces en sitios distintos, ver memoria
            // qt_marco_seat_ring_contrast_bug: sin él, un jugador con
            // Hierro por victoria contra bots (sin partidasGanadas "de
            // verdad") se vería sin marco en la mesa.
            marco: Tema.marcoPorPartidasGanadas(partidasGanadas, tieneMarcoBasico)
            textura: asiento.textura
            efecto: asiento.efecto
            decoracionLateral1: asiento.decoracionLateral1
            decoracionLateral2: asiento.decoracionLateral2
            decoracionSuperior: asiento.decoracionSuperior
            acabadoLateral1: asiento.acabadoLateral1
            acabadoLateral2: asiento.acabadoLateral2
            acabadoSuperior: asiento.acabadoSuperior
            colorBorde: activo ? Tema.colorAccent : Tema.colorBorde
        }

        // Marcadores de dealer/ciegas -- mismo diseño que escritorio (ver
        // el comentario largo ahí): disco dorado para el dealer, píldora
        // discreta para SB/BB, en un Row para que quepan los dos a la vez
        // en heads-up.
        Row {
            visible: esDealer || esSb || esBb
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -2 * Tema.escala
            anchors.topMargin: -2 * Tema.escala
            spacing: 2 * Tema.escala
            z: 10

            Rectangle {
                visible: esDealer
                width: 20 * Tema.escala
                height: 20 * Tema.escala
                radius: width / 2
                color: Tema.colorAccent
                border.width: 1.5
                border.color: Tema.colorFondo
                Text {
                    anchors.centerIn: parent
                    text: "D"
                    font.bold: true
                    font.pixelSize: 11 * Tema.escala
                    font.family: Tema.fuenteElegante
                    color: Tema.colorFondo
                }
            }
            Rectangle {
                visible: esSb || esBb
                width: textoCiega.implicitWidth + 8 * Tema.escala
                height: 18 * Tema.escala
                radius: height / 2
                color: Tema.colorPanel
                border.width: 1
                border.color: Tema.colorBorde
                Text {
                    id: textoCiega
                    anchors.centerIn: parent
                    text: esSb ? "SB" : "BB"
                    font.bold: true
                    font.pixelSize: 9 * Tema.escala
                    font.family: Tema.fuenteElegante
                    color: Tema.colorAccent
                }
            }
        }
    }
    // Placa de nombre/saldo + mini-cartas de mesa, YA JUNTAS al lado del
    // nombre (rediseño 2026-09-17, pedido explícito: "colocalas a un lado
    // del nombre del avatar" -- antes iban en una fila propia debajo de
    // toda la silla). Un Item con anchors a mano en vez de un Row: dentro
    // de un positioner (Row/Column) los hijos no admiten anchors propios,
    // y aquí la placa y las cartas necesitan alinearse por su centro
    // vertical, no solo colocarse uno detrás del otro.
    Item {
        id: filaNombreYCartas
        x: (parent.width - width) / 2
        readonly property real espacioCartas: 4 * Tema.escala
        readonly property bool mostrarCartas: !retirado
        readonly property real anchoCartas: esPropio ? propias.width : abanico.width
        readonly property real altoCartas: esPropio ? propias.height : abanico.height
        width: placaNombre.width + (mostrarCartas ? espacioCartas + anchoCartas : 0)
        height: Math.max(placaNombre.height, mostrarCartas ? altoCartas : 0)

        Rectangle {
            id: placaNombre
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: Tema.colorPanel
            opacity: 0.70
            border.width: 2
            border.color: Tema.colorBorde
            width: infoAsiento.width * 1.2
            height: infoAsiento.height * 1.
            radius: width / 10
            Column {
                id: infoAsiento
                anchors.centerIn: parent
                Text {
                    text: nombre
                    color: Tema.colorTexto
                    font.pixelSize: 13 * Tema.escala
                    font.family: Tema.fuenteElegante
                }
                Row {
                    spacing: 3 * Tema.escala
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: saldo
                        color: Tema.colorAccent
                        font.bold: true
                        font.pixelSize: 13 * Tema.escala
                        font.family: Tema.fuenteElegante
                    }
                    IconoFicha {
                        width: 10 * Tema.escala
                        height: width
                        anchors.verticalCenter: parent.verticalCenter
                        colorFicha: Tema.colorAccent
                    }
                }
            }
        }

        // Abanico de mini-cartas boca abajo -- rivales. Reutiliza la
        // técnica de "coronaDeCartas" en Avatar.qml (marco de escalera
        // real/póker de ases): cada carta gira sobre su propia base
        // (transformOrigin: Item.Bottom) con un ángulo centrado por
        // índice -- misma fórmula "(index - (N-1)/2) * pasoAngulo", aquí
        // con N=2 fijo. A diferencia de la corona (que reparte las
        // cartas en un arco alrededor del marco), aquí no hay círculo --
        // las dos comparten el mismo punto de apoyo abajo y solo se
        // desplazan un poco en horizontal, dando el aspecto de "abanico
        // de mano" solapado e inclinado que pidió el usuario en vez de
        // las dos cartas rectas de antes.
        Item {
            id: abanico
            visible: filaNombreYCartas.mostrarCartas && !esPropio
            anchors.left: placaNombre.right
            anchors.leftMargin: filaNombreYCartas.espacioCartas
            anchors.verticalCenter: placaNombre.verticalCenter
            readonly property real anchoCarta: 24 * Tema.escala
            readonly property real altoCarta: 32 * Tema.escala
            readonly property real pasoAngulo: 24
            readonly property real solapeX: 10 * Tema.escala
            width: anchoCarta + solapeX
            height: altoCarta * 1.15

            Repeater {
                model: 2
                delegate: Carta {
                    id: cartaAbanico
                    required property int index
                    width: abanico.anchoCarta
                    height: abanico.altoCarta
                    reversoSkin: asiento.reversoActivo
                    transformOrigin: Item.Bottom
                    rotation: (index - 0.5) * abanico.pasoAngulo
                    x: abanico.width / 2 - width / 2 + (index - 0.5) * abanico.solapeX
                    y: abanico.height - height
                    z: index
                }
            }
        }

        // Mini-cartas propias -- rectas y lado a lado "como ahora"
        // (pedido explícito, a diferencia del abanico de rivales), pero
        // ligeramente más grandes: en móvil esta es la ÚNICA vista de la
        // propia mano (no hay barra inferior como en escritorio), así
        // que tienen que leerse "sin problema".
        Row {
            id: propias
            visible: filaNombreYCartas.mostrarCartas && esPropio
            anchors.left: placaNombre.right
            anchors.leftMargin: filaNombreYCartas.espacioCartas
            anchors.verticalCenter: placaNombre.verticalCenter
            spacing: 4 * Tema.escala
            Carta {
                width: 30 * Tema.escala; height: 40 * Tema.escala
                codigo: asiento.miCarta1
                propia: true
            }
            Carta {
                width: 30 * Tema.escala; height: 40 * Tema.escala
                codigo: asiento.miCarta2
                propia: true
            }
        }
    }
}
