// Asiento.qml — un jugador sentado a la mesa: avatar circular con anillo de
// turno/tiempo, placa de nombre/saldo. Extraído de Main.qml.
pragma ComponentBehavior: Bound
import QtQuick

Column {
    property string saldo
    property string nombre
    // Para el marco de avatar permanente (ver Tema.marcoPorPartidasGanadas
    // y Avatar.qml) -- viene de GAME_STATE, así que funciona para
    // CUALQUIER jugador sentado, no solo el propio.
    property int partidasGanadas: 0
    // "activo": este asiento tiene el turno ahora mismo (lo sabe
    // cualquiera, viene de GAME_STATE). "fraccionTiempo": 1.0 = tiempo
    // completo, 0.0 = agotado — el servidor difunde el mismo timeout_ms
    // en cada turno (onTurnoIniciado), así que se anima igual para
    // cualquier asiento activo, no solo el del propio jugador.
    property bool activo: false
    property real fraccionTiempo: 1.0
    // Inferido del lado del cliente (ver "retirados" en la ventana) —
    // el asiento entero se atenúa, sigue en la mesa pero el ojo ya no
    // se detiene ahí.
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
        // Column no centra los hijos de distinto ancho — cada uno se
        // queda pegado a la izquierda por defecto. Centramos a mano con
        // "x", que Column no toca (solo gestiona la posición vertical).
        x: (parent.width - width) / 2
        width: 56 * Tema.escala + 10
        height: 56 * Tema.escala + 10

        // Halo del asiento activo: dos anillos concéntricos con
        // opacidad decreciente en vez de blur de verdad (ver "Sistema
        // visual", sección 15) — con hasta 9 asientos en mesa, un glow
        // real en cada uno sí se notaría en hardware modesto.
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
            width: parent.width + 5
            height: parent.height + 5
            radius: width / 2
            color: "transparent"
            border.width: 3 * Tema.escala
            border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.3)
        }

        // Anillo del temporizador: QML no tiene el "conic-gradient" de
        // CSS (un color que rellena según un porcentaje angular), así
        // que se dibuja a mano con Canvas — un arco que empieza arriba
        // (-90°) y recorre "fraccionTiempo" de la vuelta completa en
        // sentido horario. Solo visible en el asiento con turno; pasa a
        // rojo cuando queda poco tiempo.
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
            tamano: 56 * Tema.escala
            marco: Tema.marcoPorPartidasGanadas(partidasGanadas)
            // Dorado solo cuando de verdad es tu turno — antes era
            // dorado siempre, así que "activo" no se distinguía de un
            // asiento cualquiera más que por el aro del tiempo.
            colorBorde: activo ? Tema.colorAccent : Tema.colorBorde
        }

        // Marcadores de dealer/ciegas -- esquina superior derecha del
        // avatar, un poco montados sobre el borde (mismo sitio que usa
        // cualquier app de póker para el botón de dealer). En un Row para
        // que quepan los dos a la vez en heads-up (dealer = SB). El disco
        // de dealer reutiliza colorAccent (mismo "esto importa" que ya usan
        // el aro de turno y los botones); la píldora de ciega es
        // deliberadamente más discreta -- SB/BB es información de apoyo,
        // no debe competir visualmente con de quién es el turno.
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
                    // colorAccent, no colorTextoTenue -- el tenue se leía
                    // mal sobre el fondo oscuro de la píldora (confirmado
                    // con una captura real). El tamaño/forma ya la
                    // distingue del disco de dealer sin necesidad de
                    // sacrificar legibilidad con un color de bajo contraste.
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
            Text {
                text: saldo
                color: Tema.colorAccent
                font.bold: true
                font.pixelSize: 13 * Tema.escala
                font.family: Tema.fuenteElegante
            }
        }
    }
}
