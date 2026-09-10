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
    Rectangle {
        x: (parent.width - width) / 2
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
}
