// Mesa.qml — reparte los asientos en un óvalo, cartas comunitarias + bote
// en el centro. La parte de trigonometría (Math.cos/Math.sin para
// repartir N asientos en un óvalo) no es "QML puro" en el sentido de que
// no es un patrón exclusivo de QML — es JavaScript normal dentro de un
// property binding. Extraído de Main.qml.
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: mesa
    // jugadores: se le pasa el ListModel jugadoresPartida tal cual
    // (con roles nombre/saldo). cartasMesa: array de códigos ("QH", "2C"...).
    property var jugadores
    property var cartasMesa: []
    property int bote: 0
    // Para resaltar el asiento activo , solo en el caso del propio
    // jugador (del resto no conocemos su tiempo real), animar la cuenta
    // atrás en su anillo.
    property string turnoNombre: ""
    property string miNombreJugador: ""
    property real fraccionTiempo: 1.0
    property var retirados: []
    // Dealer/ciegas de la mano actual (servidor, campos "dealer"/"sb"/"bb"
    // de GAME_STATE) -- ver Asiento.qml para el porqué de tres bool
    // independientes en vez de un enum (heads-up: dealer y SB coinciden).
    property string dealerNombre: ""
    property string sbNombre: ""
    property string bbNombre: ""

    // Índice del propio jugador dentro de "jugadores" — se usa para
    // rotar todos los asientos de forma que el propio siempre caiga
    // abajo (index 0 en la fórmula del ángulo), sin importar en qué
    // posición del modelo venga desde el servidor. Se recalcula solo
    // cuando cambia "count" (el modelo se reconstruye entero en cada
    // GAME_STATE, clear()+append(), así que basta con eso).
    property int miIndice: {
        for (var i = 0; i < jugadores.count; i++) {
            if (jugadores.get(i).nombre === miNombreJugador) return i;
        }
        return 0;
    }

    // Doble borde: un segundo anillo, más grande y sin relleno, alrededor
    // del tapete — mismo truco que el aro dorado de las cartas propias
    // (un Rectangle no recorta ni molesta a los que están fuera de él).
    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 14
        height: parent.height + 14
        radius: height / 2
        color: "transparent"
        border.color: Tema.colorBorde
        border.width: 1
    }

    // El tapete: forma de "pastilla" (extremos redondos, centro
    // plano) — igual que en el boceto, no una elipse continua.
    // "radius: height/2" con un ancho mayor que el alto da justo eso.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        border.color: Tema.colorBorde
        border.width: 3
        // Degradado en vez de color plano — más claro arriba, como si
        // cayera luz cenital sobre el tapete (ver "Sistema visual",
        // sección 14). Una radial de verdad pediría QtQuick.Shapes o
        // Qt5Compat.GraphicalEffects — este lineal ya da la sensación
        // de profundidad sin añadir ningún import nuevo.
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(Tema.colorTapete, 1.22) }
            GradientStop { position: 1.0; color: Tema.colorTapete }
        }
    }

    // Centro de la mesa: cartas comunitarias arriba, bote debajo.
    Column {
        anchors.centerIn: parent
        spacing: 10 * Tema.escala
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6 * Tema.escala
            // Siempre 5 posiciones desde el preflop, no solo cuando ya
            // hay cartas reveladas — las que faltan se ven boca abajo
            // (Carta con codigo vacío) en vez de dejar el hueco vacío.
            Repeater {
                model: 5
                delegate: Carta {
                    required property int index
                    codigo: index < mesa.cartasMesa.length ? mesa.cartasMesa[index] : ""
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Bote: " + mesa.bote
            color: Tema.colorAccent
            font.bold: true
            font.pixelSize: 14 * Tema.escala
            font.family: Tema.fuenteElegante
        }
    }

    // Asientos: uno por jugador, repartidos a partes iguales alrededor
    // de una elipse (no números fijos como en el boceto, porque el
    // número de jugadores puede cambiar). Cada delegate es un Item
    // "posicionador" que calcula su propio x/y con trigonometría y
    // mete un Asiento normal dentro — así Asiento no necesita saber
    // nada de mesas ni de ángulos, sigue siendo reutilizable.
    Repeater {
        model: mesa.jugadores
        delegate: Item {
            id: posicionador
            required property string nombre
            required property string saldo
            required property int index

            // Ángulo de este asiento en radianes. 2*PI repartido entre
            // el número total de jugadores da un hueco igual a cada
            // uno; Math.PI/2 de partida para que el asiento de índice
            // relativo 0 caiga abajo del todo, no a la derecha.
            //
            // "índice relativo" (no el índice crudo del modelo): se
            // resta mesa.miIndice para que el propio jugador siempre
            // caiga en la posición 0 (abajo), sea cual sea su índice
            // real en la lista que manda el servidor — el resto de
            // asientos rota junto con él, conservando su orden relativo.
            property int indiceRelativo: (index - mesa.miIndice + mesa.jugadores.count) % mesa.jugadores.count
            property real angulo: Math.PI / 2 + (2 * Math.PI * indiceRelativo) / mesa.jugadores.count

            // Centro de la mesa + radio*coseno/seno del ángulo = punto
            // sobre la elipse. Restar width/height/2 porque x/y en QML
            // posicionan la esquina superior-izquierda, no el centro.
            x: mesa.width / 2 + (mesa.width / 2 - 40) * Math.cos(angulo) - width / 2
            y: mesa.height / 2 + (mesa.height / 2 - 40) * Math.sin(angulo) - height / 2
            width: asientoReal.width
            height: asientoReal.height

            Asiento {
                id: asientoReal
                nombre: posicionador.nombre
                saldo: posicionador.saldo
                activo: posicionador.nombre === mesa.turnoNombre
                // Antes solo se animaba el aro en el propio asiento
                // (era la única aproximación posible sin timeout_ms real
                // para los demás). Ahora el servidor difunde el mismo
                // dato en cada turno (onTurnoIniciado), así que cualquier
                // asiento activo anima su cuenta atrás real.
                fraccionTiempo: posicionador.nombre === mesa.turnoNombre ? mesa.fraccionTiempo : 1.0
                retirado: mesa.retirados.indexOf(posicionador.nombre) !== -1
                esDealer: posicionador.nombre === mesa.dealerNombre
                esSb: posicionador.nombre === mesa.sbNombre
                esBb: posicionador.nombre === mesa.bbNombre
            }
        }
    }
}
