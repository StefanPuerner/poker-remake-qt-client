// Mesa.qml (móvil) — idéntica a la de escritorio: reparte los asientos en
// un óvalo con trigonometría normal, sin MouseArea/hover, no necesita
// ningún cambio para tacto — solo se instancia más grande (punto 5 del
// plan de diseño móvil: la mesa ocupa proporcionalmente más pantalla).
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Item {
    id: mesa
    property var jugadores
    property var cartasMesa: []
    property int bote: 0
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

    property int miIndice: {
        for (var i = 0; i < jugadores.count; i++) {
            if (jugadores.get(i).nombre === miNombreJugador) return i;
        }
        return 0;
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 14
        height: parent.height + 14
        radius: height / 2
        color: "transparent"
        border.color: Tema.colorBorde
        border.width: 1
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        border.color: Tema.colorBorde
        border.width: 3
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(Tema.colorTapete, 1.22) }
            GradientStop { position: 1.0; color: Tema.colorTapete }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 10 * Tema.escala
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6 * Tema.escala
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

    Repeater {
        model: mesa.jugadores
        delegate: Item {
            id: posicionador
            required property string nombre
            required property string saldo
            required property int partidasGanadas
            required property int index

            property int indiceRelativo: (index - mesa.miIndice + mesa.jugadores.count) % mesa.jugadores.count
            property real angulo: Math.PI / 2 + (2 * Math.PI * indiceRelativo) / mesa.jugadores.count

            // "46 * Tema.escala" en vez del "40" fijo de escritorio: el
            // asiento (avatar + placa) crece con la escala, así que el
            // margen que lo separa del borde de la elipse tiene que
            // crecer con él — si no, a escala alta el asiento queda casi
            // pegado al borde exacto y su propia mitad de tamaño
            // sobresale por fuera de la mesa (bug real, visto en una
            // ventana grande: el asiento de arriba se recortaba contra
            // el borde de la ventana).
            x: mesa.width / 2 + (mesa.width / 2 - 46 * Tema.escala) * Math.cos(angulo) - width / 2
            y: mesa.height / 2 + (mesa.height / 2 - 46 * Tema.escala) * Math.sin(angulo) - height / 2
            width: asientoReal.width
            height: asientoReal.height

            Asiento {
                id: asientoReal
                nombre: posicionador.nombre
                saldo: posicionador.saldo
                partidasGanadas: posicionador.partidasGanadas
                activo: posicionador.nombre === mesa.turnoNombre
                fraccionTiempo: posicionador.nombre === mesa.turnoNombre ? mesa.fraccionTiempo : 1.0
                retirado: mesa.retirados.indexOf(posicionador.nombre) !== -1
                esDealer: posicionador.nombre === mesa.dealerNombre
                esSb: posicionador.nombre === mesa.sbNombre
                esBb: posicionador.nombre === mesa.bbNombre
            }
        }
    }
}
