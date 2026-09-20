// EscenaMesa.qml (AnimTest) -- la mesa REAL (Mesa.qml) con jugadores de mentira,
// para ver y OÍR el reparto, las comunitarias desde el mazo y las apuestas/cobros
// con el sonido de BancoSonidos sincronizado. Los sonidos se adaptan a la escena:
// n de golpes = cartas repartidas; fichas y volumen = cuánto se apuesta.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: escena
    // Los pone Main.qml del banco.
    property var banco
    property var config: ({})
    property bool conSonido: true
    // Cuenta de eventos (para la autoprueba y para ver que llegan las señales).
    property int nRepartos: 0
    property int nRepartosTerminados: 0
    property int nComunitarias: 0
    property int nFichas: 0
    property int nFolds: 0
    property int nAllIns: 0
    property int nGanadores: 0
    property int nEliminados: 0
    property int nCobros: 0
    property string ultimo: ""
    readonly property alias mesaInterna: mesa

    readonly property var nombres: ["Tú", "Ana", "Bot2", "Bot3", "Bot4", "Bot5", "Bot6", "Bot7", "Bot8"]
    readonly property var manoPropia: ["AS", "KH"]
    readonly property var mesaFinal: ["QD", "7C", "2S", "JH", "9D"]
    property int nJugadores: 6
    property real velocidad: 1.0
    property string reverso: ""
    property int cantidad: 200
    property int quienApuesta: 1
    property int quienEsDealer: 0
    property bool origenEnDealer: false
    property var retirados: []

    ListModel { id: jugadores }

    function armarMesa(n) {
        jugadores.clear();
        for (var i = 0; i < n; i++) {
            jugadores.append({
                nombre: escena.nombres[i], saldo: "1000", apuesta: "0", partidasGanadas: 0,
                tieneMarcoBasico: false, textura: "", efecto: "", decoracionLateral1: "",
                decoracionLateral2: "", decoracionSuperior: "", acabadoLateral1: "",
                acabadoLateral2: "", acabadoSuperior: "", reversoCarta: escena.reverso
            });
        }
        mesa.cartasMesa = [];
        mesa.bote = 0;
        mesa.allIns = [];
        mesa.eliminados = [];
        escena.retirados = [];
        mano0.ocultar();
        mano1.ocultar();
    }
    Component.onCompleted: armarMesa(escena.nJugadores)
    onNJugadoresChanged: armarMesa(nJugadores)

    function vivo(nombre) { return mesa.eliminados.indexOf(nombre) < 0; }
    // Siguiente asiento con fichas, a partir de "desde" (como Partida::rotarDealer()).
    function siguienteVivo(desde) {
        for (var i = 1; i <= jugadores.count; i++) {
            var idx = (desde + i) % jugadores.count;
            if (escena.vivo(escena.nombres[idx])) return idx;
        }
        return desde;
    }
    function vivos() {
        var n = 0;
        for (var i = 0; i < jugadores.count; i++) if (escena.vivo(escena.nombres[i])) n++;
        return n;
    }
    // Ciegas para un dealer dado: SB = el siguiente con fichas; BB = el siguiente al SB. Con solo
    // DOS jugadores (heads-up) el dealer es el SB y el otro el BB, como en el póker real.
    function ciegasDe(d) {
        if (escena.vivos() === 2) return { sb: d, bb: escena.siguienteVivo(d) };
        var sb = escena.siguienteVivo(d);
        return { sb: sb, bb: escena.siguienteVivo(sb) };
    }
    // Orden real de reparto: empieza la ciega pequeña y sigue por los asientos con fichas.
    function ordenReparto() {
        var r = [];
        var sb = escena.ciegasDe(escena.quienEsDealer).sb;
        for (var i = 0; i < jugadores.count; i++) {
            var idx = (sb + i) % jugadores.count;
            if (escena.vivo(escena.nombres[idx])) r.push(escena.nombres[idx]);
        }
        return r;
    }
    function slotsEnMesa() {
        var r = [];
        [mano0, mano1].forEach(function(m) {
            var p = mesa.mapFromItem(m, 0, 0);
            r.push({ x: p.x, y: p.y, w: m.width, h: m.height });
        });
        return r;
    }

    function nuevaMano() {
        mesa.cartasMesa = [];
        escena.retirados = [];
        mano0.ocultar();
        mano1.ocultar();
        mesa.slotsPropios = escena.slotsEnMesa();
        mesa.repartirMano(escena.ordenReparto());
    }
    function flop() { mesa.cartasMesa = escena.mesaFinal.slice(0, 3); }
    function turn() { mesa.cartasMesa = escena.mesaFinal.slice(0, 4); }
    function river() { mesa.cartasMesa = escena.mesaFinal.slice(0, 5); }
    function apostar() {
        var nombre = escena.nombres[escena.quienApuesta % jugadores.count];
        mesa.lanzarFichas(nombre, escena.cantidad);
        mesa.bote += escena.cantidad;
    }
    function jugadorElegido() { return escena.nombres[escena.quienApuesta % jugadores.count]; }
    function retirar() {
        var n = escena.jugadorElegido();
        mesa.retirarse(n);
        escena.retirados = escena.retirados.concat([n]);
    }
    function allIn() {
        var n = escena.jugadorElegido();
        mesa.anunciarAllIn(n, 1000);
        mesa.bote += 1000;
    }
    function gana(yo) {
        mesa.anunciarGanador(yo ? "Tú" : escena.jugadorElegido() === "Tú" ? "Ana" : escena.jugadorElegido(),
                             mesa.bote > 0 ? mesa.bote : 600, true);
    }
    function eliminar() { mesa.anunciarEliminado(escena.jugadorElegido()); }
    function cobrar() {
        var nombre = escena.nombres[escena.quienApuesta % jugadores.count];
        mesa.cobrarBote([{ nombre: nombre, premio: mesa.bote }]);
    }

    // ── Showdown sobre la misma mesa: secuencias de prueba ─────────────────────
    // Datos de mentira; la lógica real (quién muestra, botes, ganadores) vendrá del servidor.
    // estadoBarra: "turno" (botones de jugar), "decision" (seguir/guardar...) o "espera".
    property string estadoBarra: "turno"
    property bool puedeMostrar: false     // botón "Mostrar cartas" (retirado / ganador sin showdown)
    property bool yaMostre: false
    property bool secuenciaEnCurso: false

    function fijarSaldo(nombre, saldo) {
        for (var i = 0; i < jugadores.count; i++)
            if (jugadores.get(i).nombre === nombre) jugadores.setProperty(i, "saldo", String(saldo));
    }
    function saldoDe(nombre) {
        for (var i = 0; i < jugadores.count; i++)
            if (jugadores.get(i).nombre === nombre) return parseInt(jugadores.get(i).saldo) || 0;
        return 0;
    }
    function sumarSaldo(nombre, cuanto) { fijarSaldo(nombre, saldoDe(nombre) + cuanto); }

    // Cada mano el botón pasa al siguiente jugador CON FICHAS (los eliminados se saltan) y las ciegas
    // se recalculan desde él (ciegasDe). Así cada marcador avanza un paso entre jugadores vivos, y
    // en heads-up el dealer coincide con el SB. Los marcadores viajan de un asiento al otro
    // (Mesa.moverMarcador); el que no cambia de asiento no se mueve.
    function rotarBotones() {
        var d = escena.siguienteVivo(escena.quienEsDealer);
        escena.quienEsDealer = d;
        var c = escena.ciegasDe(d);
        mesa.sbNombre = escena.nombres[c.sb];
        mesa.bbNombre = escena.nombres[c.bb];
    }

    // Deja la mesa "a punto" para una secuencia: sin animaciones de por medio.
    function preparar(n, cartasMesa, retirados, bote, mano) {
        mesa.animar = false;
        escena.nJugadores = n;
        escena.armarMesa(n);
        escena.quienEsDealer = 0;
        mesa.sbNombre = escena.nombres[1];
        mesa.bbNombre = escena.nombres[2 % n];
        mesa.cartasMesa = cartasMesa;
        mesa.sinCartas = false;
        // Los huecos sin carta son contornos vacíos (las comunitarias llegan al vuelo).
        for (var h = 0; h < 5; h++) mesa.huecoAt(h).vaciado = h >= cartasMesa.length;
        mesa.animar = true;
        escena.retirados = retirados;
        mesa.bote = bote;
        mesa.boteVisible = bote;
        mano0.fijar(mano[0]);
        mano1.fijar(mano[1]);
        escena.estadoBarra = "espera";
        escena.puedeMostrar = false;
        escena.yaMostre = false;
    }

    // Botones de la barra inferior en fase de decisión: arranca el ciclo hacia la mano siguiente
    // (recogida -> rotación de botones -> ciegas -> reparto). Ver cicloApertura.
    function seguirJugando() {
        escena.puedeMostrar = false;
        escena.estadoBarra = "espera";
        cicloApertura.restart();
    }
    function mostrarMisCartas() {
        escena.yaMostre = true;
        // Sin las 5 comunitarias no hay combinación que nombrar: solo se ven las cartas.
        mesa.mostrarManos([{ nombre: "Tú", cartas: escena.manoPropia, combo: mesa.cartasMesa.length >= 5 ? "Carta Alta" : "" }]);
    }
    function correrSecuencia(n) { [null, secuencia1, secuencia2, secuencia3][n].restart(); }
    // Del final de una mano al reparto de la siguiente, a velocidad normal:
    //  1) TODAS las cartas vuelven al dealer/mazo: las de los asientos (a la vez que los avatares
    //     recuperan su tamaño), la mía y las comunitarias, que primero se voltean;
    //  2) los marcadores D/SB/BB viajan a sus asientos nuevos;
    //  3) las ciegas van al bote; 4) empieza el reparto (la "secuencia de apertura").
    SequentialAnimation {
        id: cicloApertura
        ScriptAction { script: {
            escena.secuenciaEnCurso = true;
            mano0.presente = false;
            mano1.presente = false;
            mesa.recogerCartas();
            mesa.cartasMesa = [];
            mesa.bote = 0;
        } }
        PauseAnimation { duration: mesa.ms(1500) }
        ScriptAction { script: { escena.sonar("barajar", {}); escena.rotarBotones(); } }
        PauseAnimation { duration: mesa.ms(1000) }
        ScriptAction { script: {
            escena.retirados = [];
            mesa.lanzarFichas(mesa.sbNombre, 10);
            mesa.lanzarFichas(mesa.bbNombre, 20);
            mesa.bote = 30;
        } }
        PauseAnimation { duration: mesa.ms(1100) }
        ScriptAction { script: {
            mano0.ocultar();
            mano1.ocultar();
            mesa.slotsPropios = escena.slotsEnMesa();
            mesa.repartirMano(escena.ordenReparto());
        } }
        onFinished: escena.secuenciaEnCurso = false
    }

    // Secuencia 1: showdown normal. Cuatro jugadores llegan al final: primero TODOS se preparan
    // a la vez (avatar pequeño, cartas grandes boca abajo) y luego se revelan de uno en uno, en
    // orden de apuesta (empieza quien apostó último: Bot3). Ana, retirada, enseña por su cuenta
    // mientras tanto (asíncrono: no influye en el resultado).
    SequentialAnimation {
        id: secuencia1
        ScriptAction { script: {
            escena.secuenciaEnCurso = true;
            escena.preparar(6, ["QD", "7C", "2S", "JH", "9D"], ["Ana", "Bot2"], 600, ["AH", "AS"]);
            ["Tú", "Bot3", "Bot4", "Bot5"].forEach(function(n) { escena.fijarSaldo(n, 850); });
        } }
        PauseAnimation { duration: mesa.ms(900) }
        ScriptAction { script: mesa.prepararShowdown(["Tú", "Bot3", "Bot4", "Bot5"]) }
        PauseAnimation { duration: mesa.ms(1000) }
        ScriptAction { script: mesa.revelarMano("Bot3", ["QH", "JC"], "Doble Pareja") }
        PauseAnimation { duration: mesa.ms(1500) }
        ScriptAction { script: mesa.revelarMano("Bot4", ["7D", "7H"], "Trío") }
        PauseAnimation { duration: mesa.ms(700) }
        ScriptAction { script: mesa.mostrarManos([{ nombre: "Ana", cartas: ["AC", "2D"], combo: "" }]) }
        PauseAnimation { duration: mesa.ms(800) }
        ScriptAction { script: mesa.revelarMano("Bot5", ["KC", "3H"], "Carta Alta") }
        PauseAnimation { duration: mesa.ms(1500) }
        ScriptAction { script: mesa.revelarMano("Tú", ["AH", "AS"], "Pareja") }
        PauseAnimation { duration: mesa.ms(1600) }
        ScriptAction { script: mesa.marcarGanador("Bot4", ["7C", "7D", "7H", "QD", "JH"]) }
        PauseAnimation { duration: mesa.ms(900) }
        ScriptAction { script: {
            mesa.anunciarGanador("Bot4", 600, true, "Trío");
            escena.sumarSaldo("Bot4", 600);
        } }
        PauseAnimation { duration: mesa.ms(2600) }
        ScriptAction { script: escena.estadoBarra = "decision" }
        onFinished: escena.secuenciaEnCurso = false
    }

    // Secuencia 2: runout con side pots. Todos all-in con pilas distintas: se preparan a la vez,
    // se revelan uno a uno, salen las calles que faltan y se reparten tres botes.
    SequentialAnimation {
        id: secuencia2
        ScriptAction { script: {
            escena.secuenciaEnCurso = true;
            escena.preparar(4, [], [], 2700, ["KH", "KS"]);
            ["Tú", "Ana", "Bot2", "Bot3"].forEach(function(n) { escena.fijarSaldo(n, 0); mesa.marcarAllIn(n); });
            mesa.botesShowdown = [
                { numBote: 0, cantidad: 800, ganador: "", premio: 0, participantes: [
                    { nombre: "Tú", aporte: 200 }, { nombre: "Ana", aporte: 200 },
                    { nombre: "Bot2", aporte: 200 }, { nombre: "Bot3", aporte: 200 }] },
                { numBote: 1, cantidad: 900, ganador: "", premio: 0, participantes: [
                    { nombre: "Ana", aporte: 300 }, { nombre: "Bot2", aporte: 300 }, { nombre: "Bot3", aporte: 300 }] },
                { numBote: 2, cantidad: 1000, ganador: "", premio: 0, participantes: [
                    { nombre: "Bot2", aporte: 500 }, { nombre: "Bot3", aporte: 500 }] }];
        } }
        PauseAnimation { duration: mesa.ms(900) }
        // Solo quedan jugadores all-in: se preparan todos a la vez...
        ScriptAction { script: mesa.prepararShowdown(["Tú", "Ana", "Bot2", "Bot3"]) }
        PauseAnimation { duration: mesa.ms(1000) }
        // ...y se enseñan de uno en uno.
        ScriptAction { script: mesa.revelarMano("Bot3", ["5D", "5C"], "") }
        PauseAnimation { duration: mesa.ms(1300) }
        ScriptAction { script: mesa.revelarMano("Bot2", ["JH", "JC"], "") }
        PauseAnimation { duration: mesa.ms(1300) }
        ScriptAction { script: mesa.revelarMano("Ana", ["AS", "AD"], "") }
        PauseAnimation { duration: mesa.ms(1300) }
        ScriptAction { script: mesa.revelarMano("Tú", ["KH", "KS"], "") }
        PauseAnimation { duration: mesa.ms(1600) }
        // Y ahora se destapan las comunitarias que faltan.
        ScriptAction { script: mesa.cartasMesa = ["KD", "8C", "3S"] }
        PauseAnimation { duration: mesa.ms(1900) }
        ScriptAction { script: mesa.cartasMesa = ["KD", "8C", "3S", "5H"] }
        PauseAnimation { duration: mesa.ms(2100) }
        ScriptAction { script: mesa.cartasMesa = ["KD", "8C", "3S", "5H", "JD"] }
        PauseAnimation { duration: mesa.ms(1500) }
        ScriptAction { script: mesa.actualizarCombos({ "Tú": "Trío", "Ana": "Pareja", "Bot2": "Trío", "Bot3": "Trío" }) }
        PauseAnimation { duration: mesa.ms(1400) }
        // Bote principal: gana Tú.
        ScriptAction { script: {
            mesa.marcarGanador("Tú", ["KD", "KH", "KS", "JD", "8C"]);
            var b = mesa.botesShowdown.slice(); b[0] = Object.assign({}, b[0], { ganador: "Tú", premio: 800 });
            mesa.botesShowdown = b;
            mesa.anunciarGanador("Tú", 800, true, "Bote principal · Trío");
            escena.sumarSaldo("Tú", 800);
        } }
        PauseAnimation { duration: mesa.ms(2600) }
        // Side pot 1: gana Bot2 (Tú no participa: no suena "perder").
        ScriptAction { script: {
            mesa.marcarGanador("Bot2", ["JH", "JC", "JD", "KD", "8C"]);
            var b = mesa.botesShowdown.slice(); b[1] = Object.assign({}, b[1], { ganador: "Bot2", premio: 900 });
            mesa.botesShowdown = b;
            mesa.anunciarGanador("Bot2", 900, false, "Side pot 1 · Trío");
            escena.sumarSaldo("Bot2", 900);
        } }
        PauseAnimation { duration: mesa.ms(2600) }
        ScriptAction { script: {
            var b = mesa.botesShowdown.slice(); b[2] = Object.assign({}, b[2], { ganador: "Bot2", premio: 1000 });
            mesa.botesShowdown = b;
            mesa.anunciarGanador("Bot2", 1000, false, "Side pot 2 · Trío");
            escena.sumarSaldo("Bot2", 1000);
        } }
        PauseAnimation { duration: mesa.ms(2600) }
        // Ana y Bot3 se quedan sin fichas.
        ScriptAction { script: mesa.anunciarEliminado("Ana") }
        PauseAnimation { duration: mesa.ms(1500) }
        ScriptAction { script: mesa.anunciarEliminado("Bot3") }
        PauseAnimation { duration: mesa.ms(1600) }
        ScriptAction { script: escena.estadoBarra = "decision" }
        onFinished: escena.secuenciaEnCurso = false
    }

    // Secuencia 3: todos se retiran menos Tú. Ves la mesa, cobras y puedes elegir si
    // enseñar tus cartas (igual que cualquier retirado).
    SequentialAnimation {
        id: secuencia3
        ScriptAction { script: {
            escena.secuenciaEnCurso = true;
            escena.preparar(6, ["QD", "7C", "2S", "JH"], ["Ana", "Bot2", "Bot3", "Bot4", "Bot5"], 240, ["AS", "KH"]);
            escena.fijarSaldo("Tú", 880);
        } }
        PauseAnimation { duration: mesa.ms(700) }
        ScriptAction { script: {
            mesa.anunciarGanador("Tú", 240, true, "");
            escena.sumarSaldo("Tú", 240);
        } }
        PauseAnimation { duration: mesa.ms(1800) }
        ScriptAction { script: { escena.puedeMostrar = true; escena.estadoBarra = "decision"; } }
        onFinished: escena.secuenciaEnCurso = false
    }

    function sonar(evento, opciones) {
        if (!escena.conSonido || !escena.banco) return;
        escena.banco.programar(escena.config[evento], opciones);
    }

    // Todo esto es lo que hará Main.qml en la partida real: escuchar las señales de
    // Mesa y pedir el sonido, adaptado a lo que de verdad ocurre en la escena.
    Mesa {
        id: mesa
        anchors.horizontalCenter: parent.horizontalCenter
        y: 232
        width: 900
        height: 400
        jugadores: jugadores
        miNombreJugador: "Tú"
        // (con la lista vacía mientras se reconstruye, no hay dealer)
        dealerNombre: jugadores.count > 0 ? escena.nombres[escena.quienEsDealer % jugadores.count] : ""
        origenEnDealer: escena.origenEnDealer
        retirados: escena.retirados
        soloVsBots: true
        miReversoSkin: escena.reverso
        animar: true
        velocidad: escena.velocidad
        onRepartoIniciado: function(cartas, duracionMs) {
            escena.nRepartos++;
            escena.ultimo = "reparto: " + cartas + " cartas en " + duracionMs + " ms";
            escena.sonar("reparto", { n: cartas, duracion: duracionMs });
        }
        onRepartoTerminado: {
            escena.nRepartosTerminados++;
            if (escena.estadoBarra === "espera") escena.estadoBarra = "turno";
        }
        onCartaPropiaAterrizada: function(indice) {
            (indice === 0 ? mano0 : mano1).revelar(escena.manoPropia[indice]);
        }
        onComunitariasRepartidas: function(cuantas, inicioMs, duracionMs) {
            escena.nComunitarias++;
            escena.ultimo = (cuantas === 3 ? "flop" : "comunitaria") + ": " + cuantas + " carta(s)";
            escena.sonar(cuantas === 3 ? "flop" : "comunitaria",
                         { n: cuantas > 1 ? cuantas : undefined, duracion: duracionMs, inicio: inicioMs });
        }
        onFichasLanzadas: function(fichas, cantidad, inicioMs, duracionMs) {
            escena.nFichas++;
            escena.ultimo = "apuesta " + cantidad + ": " + fichas + " fichas";
            // Nº de golpes proporcional a las fichas que vuelan (máx. 8) y una apuesta
            // grande suena más fuerte que una pequeña.
            escena.sonar("fichas", { factor: fichas / 8, duracion: duracionMs, inicio: inicioMs,
                                     vol: 0.55 + 0.45 * fichas / 8 });
        }
        onCartasRecogidas: function(cartas, duracionMs) {
            escena.ultimo = "recogida: " + cartas + " cartas";
            escena.sonar("recogida", { n: cartas, duracion: duracionMs });
        }
        onFoldLanzado: function(nombre) {
            escena.nFolds++;
            escena.ultimo = nombre + " se retira";
            escena.sonar("fold", {});
        }
        onAllInAnunciado: function(nombre, cantidad, grande) {
            escena.nAllIns++;
            escena.ultimo = "all-in de " + nombre + (grande ? " (grande)" : " (pequeño)");
            // Un all-in grande suena a tope; uno pequeño, más contenido.
            escena.sonar("allin", grande ? { vol: 1.0 } : { factor: 0.5, vol: 0.7 });
        }
        onGanadorAnunciado: function(nombre, esPropio, premio, participo) {
            escena.nGanadores++;
            escena.ultimo = (esPropio ? "ganas " : nombre + " gana ") + premio;
            if (esPropio) escena.sonar("ganar", {});
            else if (participo) escena.sonar("perder", {});
        }
        onEliminadoAnunciado: function(nombre, esPropio) {
            escena.nEliminados++;
            escena.ultimo = nombre + " eliminado";
            escena.sonar("eliminado", esPropio ? {} : { vol: 0.6 });
        }
        onCobroLanzado: function(fichas, cantidad, inicioMs, duracionMs) {
            escena.nCobros++;
            escena.ultimo = "cobro " + cantidad + ": " + fichas + " fichas";
            escena.sonar("cobro", { factor: fichas / 8, duracion: duracionMs, inicio: inicioMs,
                                    vol: 0.55 + 0.45 * fichas / 8 });
        }
    }

    // Tu mano, donde vive en escritorio (barra inferior de Main.qml): boca abajo con
    // el reverso equipado; al aterrizar cada carta voladora, se voltea.
    component SlotMano: Item {
        id: slot
        width: 80 * Tema.escala
        height: 112 * Tema.escala
        property string mostrado: ""
        // false cuando las cartas "vuelven al dealer" al acabar la mano.
        property bool presente: true
        opacity: presente ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        function fijar(codigo) {
            girar.stop();
            giro.angle = 0;
            slot.mostrado = codigo;
            slot.presente = true;
        }
        function revelar(codigo) {
            girar.stop();
            girar.codigoNuevo = codigo;
            girar.restart();
        }
        function ocultar() {
            girar.stop();
            giro.angle = 0;
            slot.mostrado = "";
            slot.presente = true;
        }
        Carta {
            id: cartaSlot
            anchors.fill: parent
            propia: true
            codigo: slot.mostrado
            reversoSkin: escena.reverso
            transform: Rotation {
                id: giro
                origin.x: cartaSlot.width / 2
                origin.y: cartaSlot.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: 0
            }
        }
        SequentialAnimation {
            id: girar
            property string codigoNuevo: ""
            NumberAnimation { target: giro; property: "angle"; to: 90; duration: mesa.ms(110); easing.type: Easing.InQuad }
            ScriptAction { script: slot.mostrado = girar.codigoNuevo }
            NumberAnimation { target: giro; property: "angle"; to: 0; duration: mesa.ms(110); easing.type: Easing.OutQuad }
        }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: mesa.y + mesa.height + 40
        spacing: 12
        SlotMano { id: mano0 }
        SlotMano { id: mano1 }
    }
    Label {
        x: 14
        y: mesa.y + mesa.height + 66
        text: "Tu mano\n(barra inferior)"
        color: Tema.colorTextoTenue
        font.pixelSize: 12
    }

    // ── Controles ─────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 6
        RowLayout {
            spacing: 10
            Label { text: "Jugadores"; color: Tema.colorTexto }
            SpinBox {
                from: 2; to: 9
                value: escena.nJugadores
                onValueModified: escena.nJugadores = value
            }
            Label { text: "Velocidad"; color: Tema.colorTexto }
            Repeater {
                model: [1.0, 0.5, 0.25]
                delegate: Button {
                    required property real modelData
                    text: modelData + "x"
                    highlighted: escena.velocidad === modelData
                    onClicked: escena.velocidad = modelData
                }
            }
            Label { text: "Reverso"; color: Tema.colorTexto }
            ComboBox {
                model: ["", "reverso_azul_real", "reverso_esmeralda", "reverso_carmesi", "reverso_obsidiana", "reverso_taberna"]
                displayText: currentText === "" ? "(genérico)" : currentText
                onActivated: {
                    escena.reverso = currentText;
                    escena.armarMesa(escena.nJugadores);
                }
            }
            Label { text: "Dealer"; color: Tema.colorTexto }
            ComboBox {
                model: escena.nombres.slice(0, escena.nJugadores)
                currentIndex: escena.quienEsDealer
                onActivated: escena.quienEsDealer = currentIndex
            }
            Label { text: "Origen"; color: Tema.colorTexto }
            ComboBox {
                model: ["Mazo (PC)", "Dealer (móvil)"]
                currentIndex: escena.origenEnDealer ? 1 : 0
                onActivated: escena.origenEnDealer = currentIndex === 1
            }
            Switch { text: "Sonido"; checked: escena.conSonido; onToggled: escena.conSonido = checked }
            Item { Layout.fillWidth: true }
        }
        RowLayout {
            spacing: 8
            Button { text: "Nueva mano"; onClicked: escena.nuevaMano() }
            Button { text: "Flop"; onClicked: escena.flop() }
            Button { text: "Turn"; onClicked: escena.turn() }
            Button { text: "River"; onClicked: escena.river() }
            Button { text: "Limpiar"; onClicked: escena.armarMesa(escena.nJugadores) }
            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 24; color: Qt.rgba(1, 1, 1, 0.3) }
            Label { text: "Apuesta"; color: Tema.colorTexto }
            Slider {
                Layout.preferredWidth: 180
                from: 10; to: 1000; stepSize: 10
                value: escena.cantidad
                onMoved: escena.cantidad = Math.round(value)
            }
            Label { text: escena.cantidad; color: Tema.colorAccent; Layout.preferredWidth: 40 }
            Label { text: "de"; color: Tema.colorTexto }
            ComboBox {
                model: escena.nombres.slice(0, escena.nJugadores)
                currentIndex: escena.quienApuesta
                onActivated: escena.quienApuesta = currentIndex
            }
            Button { text: "Apostar"; onClicked: escena.apostar() }
            Button { text: "Cobrar bote"; onClicked: escena.cobrar() }
        }
        RowLayout {
            spacing: 8
            Label { text: "Eventos (jugador de arriba):"; color: Tema.colorTextoTenue }
            Button { text: "Retirarse (fold)"; onClicked: escena.retirar() }
            Button { text: "All-in"; onClicked: escena.allIn() }
            Button { text: "Ganas tú"; onClicked: escena.gana(true) }
            Button { text: "Pierdes (gana otro)"; onClicked: escena.gana(false) }
            Button { text: "Eliminado"; onClicked: escena.eliminar() }
        }
        RowLayout {
            spacing: 8
            Label { text: "Showdown en la mesa:"; color: Tema.colorAccent; font.bold: true }
            Button { text: "▶ 1: showdown normal"; enabled: !escena.secuenciaEnCurso; onClicked: secuencia1.restart() }
            Button { text: "▶ 2: runout all-in + side pots"; enabled: !escena.secuenciaEnCurso; onClicked: secuencia2.restart() }
            Button { text: "▶ 3: ganas sin showdown"; enabled: !escena.secuenciaEnCurso; onClicked: secuencia3.restart() }
        }
    }
    // La barra inferior de Main.qml: botones de turno, y en el showdown las decisiones.
    Rectangle {
        id: barra
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 34
        width: 620
        height: 50
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.15)
        Label {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.top: parent.top
            anchors.topMargin: 2
            text: escena.estadoBarra === "turno" ? "barra de turno" : escena.estadoBarra === "decision" ? "decisiones (en el hueco de los botones de turno)" : "esperando..."
            color: Tema.colorTextoTenue
            font.pixelSize: 10
        }
        Row {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 6
            spacing: 10
            visible: escena.estadoBarra === "turno"
            Button { text: "Retirarse"; enabled: false }
            Button { text: "Igualar"; enabled: false }
            Button { text: "Subir"; enabled: false }
            Button { text: "All-in"; enabled: false }
        }
        Row {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 6
            spacing: 10
            visible: escena.estadoBarra === "decision"
            Button {
                text: "Mostrar cartas"
                visible: escena.puedeMostrar
                enabled: !escena.yaMostre
                onClicked: escena.mostrarMisCartas()
            }
            Button { text: "Seguir jugando"; highlighted: true; onClicked: escena.seguirJugando() }
            Button { text: "Guardar y salir"; onClicked: escena.seguirJugando() }
        }
    }

    Label {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 8
        color: Tema.colorTextoTenue
        font.pixelSize: 12
        text: "Último evento: " + escena.ultimo
    }
}
