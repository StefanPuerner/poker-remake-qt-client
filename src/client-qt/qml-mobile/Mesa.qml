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

    // ── Animaciones: fichas al bote, cobro y volteo de comunitarias ─────
    // Ver docs/plan-animaciones-mesa.md. "boteVisible" es lo que enseña el
    // texto: va con retraso respecto a "bote" para que el número no suba
    // antes de que las fichas lleguen (la ACCION llega antes que el
    // GAME_STATE que sube el bote). "cobrando": el bote se acaba de cobrar y
    // el texto se queda a 0 hasta que el servidor lo reinicie con la mano
    // nueva -- si no, al aterrizar las fichas volvería al número viejo.
    property int boteVisible: bote
    property bool cobrando: false
    onBoteChanged: {
        if (cobrando) {
            cobrando = false;
            boteVisible = bote;
        } else if (fichas.enVuelo > 0 && bote > boteVisible) {
            return;   // lo iguala aterrizaron()
        } else {
            boteVisible = bote;
        }
    }

    // Alto del bloque del avatar dentro del asiento (el resto del asiento,
    // placa de nombre, cuelga debajo): el punto de salida/llegada de las
    // fichas es el avatar, no el centro del asiento entero.
    readonly property real altoAvatar: Math.round(46 * Tema.escala) + 10

    function indiceDe(nombre) {
        for (var i = 0; i < mesa.jugadores.count; i++) {
            if (mesa.jugadores.get(i).nombre === nombre) return i;
        }
        return -1;
    }

    // Centro del avatar de "nombre", en coordenadas de la mesa. null si no
    // está sentado (o el modelo se está reconstruyendo).
    function centroAsiento(nombre) {
        var i = indiceDe(nombre);
        var it = i < 0 ? null : asientos.itemAt(i);
        return it ? it.mapToItem(mesa, it.width / 2, mesa.altoAvatar / 2) : null;
    }

    function centroBote() {
        return filaBote.mapToItem(mesa, filaBote.width / 2, filaBote.height / 2);
    }

    // Nº de fichas para una cantidad: RELATIVO al tamaño de las pilas de la
    // mesa (media de saldo + apuesta de cada jugador), sin umbrales fijos --
    // 1000 de pila: 20 -> 1, 100 -> 3, 500 -> 5, todo -> 7. Entre 1 y 8.
    function fichasPara(cantidad) {
        var suma = 0;
        var n = mesa.jugadores.count;
        for (var i = 0; i < n; i++) {
            var j = mesa.jugadores.get(i);
            suma += (parseInt(j.saldo) || 0) + (parseInt(j.apuesta) || 0);
        }
        var referencia = n > 0 ? suma / n : 0;
        if (referencia <= 0 || cantidad <= 0) return 1;
        return Math.max(1, Math.min(8, Math.ceil(7 * Math.sqrt(cantidad / referencia))));
    }

    // Apuesta: fichas del avatar de "nombre" al bote.
    function lanzarFichas(nombre, cantidad) {
        var origen = centroAsiento(nombre);
        if (!origen) return;
        var destino = centroBote();
        fichas.lanzar(origen.x, origen.y, destino.x, destino.y, fichasPara(cantidad), 0);
    }

    // Cobro: del bote a cada ganador. ganadores = [{nombre, premio}].
    function cobrarBote(ganadores) {
        var origen = centroBote();
        var alguno = false;
        for (var i = 0; i < ganadores.length; i++) {
            var destino = centroAsiento(ganadores[i].nombre);
            if (!destino) continue;
            if (fichas.lanzar(origen.x, origen.y, destino.x, destino.y,
                              fichasPara(ganadores[i].premio), 0))
                alguno = true;
        }
        if (alguno) {
            cobrando = true;
            boteVisible = 0;
        }
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
            //
            // Al pasar de "carta" a "vacío" (mano nueva) las cartas se dan la
            // vuelta: giran hasta el canto, se cambian por el dorso y
            // terminan de girar, escalonadas. Cualquier otro cambio (sale el
            // flop, etc.) es instantáneo, como siempre.
            Repeater {
                model: 5
                delegate: Item {
                    id: hueco
                    required property int index
                    readonly property string objetivo: index < mesa.cartasMesa.length ? mesa.cartasMesa[index] : ""
                    property string mostrado: ""
                    width: cartaHueco.width
                    height: cartaHueco.height
                    Component.onCompleted: mostrado = objetivo
                    onObjetivoChanged: {
                        if (objetivo === "" && mostrado !== "") {
                            volteo.restart();
                        } else {
                            volteo.stop();
                            giro.angle = 0;
                            mostrado = objetivo;
                        }
                    }
                    Carta {
                        id: cartaHueco
                        codigo: hueco.mostrado
                        reversoSkin: mesa.reversoActivo()
                        transform: Rotation {
                            id: giro
                            origin.x: cartaHueco.width / 2
                            origin.y: cartaHueco.height / 2
                            axis { x: 0; y: 1; z: 0 }
                            angle: 0
                        }
                    }
                    SequentialAnimation {
                        id: volteo
                        PauseAnimation { duration: hueco.index * 70 }
                        NumberAnimation { target: giro; property: "angle"; to: 90; duration: 130; easing.type: Easing.InQuad }
                        ScriptAction { script: hueco.mostrado = "" }
                        NumberAnimation { target: giro; property: "angle"; to: 0; duration: 130; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
        Row {
            id: filaBote
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4 * Tema.escala
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Idioma.tf("etiqueta_bote_total", [mesa.boteVisible])
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
        id: asientos
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

    // Fichas en vuelo: la última hija, por encima de los asientos.
    FichasVolando {
        id: fichas
        anchors.fill: parent
        z: 10
        onAterrizaron: {
            if (!mesa.cobrando) mesa.boteVisible = mesa.bote;
        }
    }
}
