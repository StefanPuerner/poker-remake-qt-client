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
    // Reverso de cartas -- ver el comentario gemelo en
    // src/client-qt/qml/Mesa.qml (escritorio).
    property bool soloVsBots: false
    property string miReversoSkin: ""
    // Tapete a pintar ("" = el del tema) -- lo resuelve Main.qml.
    property string tapete: ""
    // Cartas propias reales -- SOLO móvil las necesita (mini-cartas en
    // la propia silla también, ver Asiento.qml de este árbol).
    property string miCarta1: ""
    property string miCarta2: ""

    property int miIndice: {
        for (var i = 0; i < jugadores.count; i++) {
            if (jugadores.get(i).nombre === miNombreJugador) return i;
        }
        return 0;
    }

    function reversoActivo() {
        if (mesa.soloVsBots) return mesa.miReversoSkin;
        for (var i = 0; i < mesa.jugadores.count; i++) {
            var j = mesa.jugadores.get(i);
            if (j.nombre === mesa.dealerNombre) return j.reversoCarta || "";
        }
        return "";
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

    // El tapete: ver Tapete.qml. "tapete" = código elegido (el del
    // anfitrión o el propio, lo decide Main.qml); vacío = el del tema.
    Tapete {
        anchors.fill: parent
        preset: mesa.tapete
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
                    reversoSkin: mesa.reversoActivo()
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4 * Tema.escala
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Idioma.tf("etiqueta_bote_total", [mesa.bote])
                color: Tema.colorAccent
                font.bold: true
                font.pixelSize: 14 * Tema.escala
                font.family: Tema.fuenteElegante
            }
            IconoFicha {
                width: 12 * Tema.escala
                height: width
                anchors.verticalCenter: parent.verticalCenter
                colorFicha: Tema.colorAccent
            }
        }
    }

    Repeater {
        model: mesa.jugadores
        delegate: Item {
            id: posicionador
            required property string nombre
            required property string saldo
            required property int partidasGanadas
            // Visibilidad a otros jugadores, parte B (2026-09-01) -- ver
            // Asiento.qml para cómo se usan.
            required property bool tieneMarcoBasico
            required property string textura
            required property string efecto
            required property string decoracionLateral1
            required property string decoracionLateral2
            required property string decoracionSuperior
            required property string acabadoLateral1
            required property string acabadoLateral2
            required property string acabadoSuperior
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
                tieneMarcoBasico: posicionador.tieneMarcoBasico
                textura: posicionador.textura
                efecto: posicionador.efecto
                decoracionLateral1: posicionador.decoracionLateral1
                decoracionLateral2: posicionador.decoracionLateral2
                decoracionSuperior: posicionador.decoracionSuperior
                acabadoLateral1: posicionador.acabadoLateral1
                acabadoLateral2: posicionador.acabadoLateral2
                acabadoSuperior: posicionador.acabadoSuperior
                activo: posicionador.nombre === mesa.turnoNombre
                fraccionTiempo: posicionador.nombre === mesa.turnoNombre ? mesa.fraccionTiempo : 1.0
                retirado: mesa.retirados.indexOf(posicionador.nombre) !== -1
                esDealer: posicionador.nombre === mesa.dealerNombre
                esSb: posicionador.nombre === mesa.sbNombre
                esBb: posicionador.nombre === mesa.bbNombre
                esPropio: posicionador.nombre === mesa.miNombreJugador
                reversoActivo: mesa.reversoActivo()
                miCarta1: mesa.miCarta1
                miCarta2: mesa.miCarta2
            }
        }
    }
}
