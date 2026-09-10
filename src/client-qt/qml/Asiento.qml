// Asiento.qml — un jugador sentado a la mesa: avatar circular con anillo de
// turno/tiempo, placa de nombre/saldo. Extraído de Main.qml.
pragma ComponentBehavior: Bound
import QtQuick

Column {
    id: asiento
    property string saldo
    property string nombre
    // Para el marco de avatar permanente (ver Tema.marcoPorPartidasGanadas
    // y Avatar.qml) -- viene de GAME_STATE, así que funciona para
    // CUALQUIER jugador sentado, no solo el propio.
    property int partidasGanadas: 0
    // Visibilidad a otros jugadores, parte B (2026-09-01 -- ver memoria
    // qt_progression_review_2026_09_01): loadout REAL de quien esté
    // sentado aquí, no solo el tier de marco -- mismos campos que ya
    // pinta PopupPerfilJugador.qml para un perfil público, ahora también
    // en la mesa. "" = nada equipado en ese slot, igual que en todo el
    // resto de la app.
    property bool tieneMarcoBasico: false
    property string textura: ""
    property string efecto: ""
    property string decoracionLateral1: ""
    property string decoracionLateral2: ""
    property string decoracionSuperior: ""
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
        // Math.round(56*Tema.escala) -- MISMO valor que Avatar.qml calcula
        // internamente para su propio "width" (avatar.tamano ahí abajo es
        // este mismo "56 * Tema.escala"). Bug real corregido aquí
        // (2026-09-01): antes este contenedor NO redondeaba, así que su
        // ancho fraccionario no coincidía en resto con el ancho YA
        // redondeado del Avatar centrado dentro -- el mismo desfase de
        // subpíxel que "Sistema visual" ya documentó para marcoMetalico/
        // nucleo en Avatar.qml, aquí aplicado al aro de resplandor del
        // turno (los dos Rectangle "activo" de abajo, centrados en ESTE
        // Item): al no compartir resto fraccionario con el Avatar de
        // dentro, el halo quedaba centrado en el contenedor pero no en el
        // avatar que realmente se ve, dando un anillo visualmente
        // descentrado. Con los dos como enteros, la diferencia (10) es
        // exacta, sin resto.
        width: Math.round(56 * Tema.escala) + 10
        height: width

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
            // "+6", no "+5" -- mismo motivo que el redondeo de arriba:
            // con un contenedor ya entero, un margen IMPAR deja una
            // diferencia impar entre este anillo y su padre, y
            // anchors.centerIn calcula su posición como esa diferencia
            // entre 2 -- con 5 (impar) da .5, medio píxel de desfase
            // otra vez, esta vez en el propio anillo interior. Con 6
            // (par) la diferencia entre 2 siempre cae en un entero.
            width: parent.width + 6
            height: parent.height + 6
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
            // tieneMarcoBasico como 2º argumento -- bug real encontrado
            // aquí también (2026-09-01, tercera vez en un sitio distinto,
            // ver memoria qt_marco_seat_ring_contrast_bug): sin él, un
            // jugador con Hierro por victoria contra bots (sin
            // partidasGanadas "de verdad") se veía sin marco en la mesa.
            marco: Tema.marcoPorPartidasGanadas(partidasGanadas, tieneMarcoBasico)
            textura: asiento.textura
            efecto: asiento.efecto
            decoracionLateral1: asiento.decoracionLateral1
            decoracionLateral2: asiento.decoracionLateral2
            decoracionSuperior: asiento.decoracionSuperior
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
