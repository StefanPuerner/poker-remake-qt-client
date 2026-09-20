// Mesa.qml (móvil) — reparte los asientos en un óvalo, cartas comunitarias + bote en el centro, y
// dirige las animaciones de la mano (reparto, recogida, marcadores viajeros, showdown sobre la
// misma mesa, cintas de aviso). Espejo del de escritorio (ver ese fichero y
// docs/plan-animaciones-partida.md para el detalle largo) con lo propio del móvil: las cartas
// salen del DEALER (no cabe un mazo junto a las comunitarias), tus cartas viven en tu asiento y
// las zonas pulsables cumplen Tema.tactil.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Item {
    id: mesa
    // Temblor de la mesa en un all-in grande (ver temblar()).
    transform: Translate { id: temblor; x: 0 }
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
    // Reverso de cartas -- Fase 1 de "segunda ola de cosméticos"
    // (2026-09-17). "soloVsBots" viene de GAME_STATE (campo
    // "solo_vs_bots", ver NetworkObserver::emitirGameState()); a
    // diferencia de dealerNombre/sbNombre/bbNombre, el servidor NO manda
    // qué reverso mostrar directamente -- esa decisión ("el del dealer",
    // o "el propio si eres el único humano") es de este componente, ver
    // reversoActivo() más abajo.
    property bool soloVsBots: false
    property string miReversoSkin: ""
    // Tus cartas reales: se pintan en tu asiento (aquí no hay barra inferior).
    property string miCarta1: ""
    property string miCarta2: ""
    // Tapete a pintar ("" = el del tema) -- lo resuelve Main.qml.
    property string tapete: ""

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

    // Reverso de cartas activo -- el del dealer (a la vista de toda la
    // mesa), salvo cuando eres el único humano sentado, en cuyo caso
    // enseñas siempre el tuyo. Se usa tanto en el mazo comunitario (más
    // abajo) como en las mini-cartas de los rivales en Asiento.qml. NO
    // depende de "codigo" de ninguna carta -- es puramente "qué imagen de
    // dorso toca", así que funciona igual estén las cartas reveladas o no
    // (Carta.qml solo la pinta cuando además está boca abajo).
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
        return it ? it.asiento.centroAvatar(mesa) : null;
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
        var n = fichasPara(cantidad);
        if (fichas.lanzar(origen.x, origen.y, destino.x, destino.y, n, 0))
            fichasLanzadas(n, cantidad, fichas.duracionVuelo, fichas.escalonado * (n - 1));
    }

    // Cobro: del bote a cada ganador. ganadores = [{nombre, premio}].
    function cobrarBote(ganadores) {
        var origen = centroBote();
        var alguno = false;
        for (var i = 0; i < ganadores.length; i++) {
            var destino = centroAsiento(ganadores[i].nombre);
            if (!destino) continue;
            var nf = fichasPara(ganadores[i].premio);
            if (fichas.lanzar(origen.x, origen.y, destino.x, destino.y, nf, 0)) {
                alguno = true;
                cobroLanzado(nf, ganadores[i].premio, fichas.duracionVuelo, fichas.escalonado * (nf - 1));
            }
        }
        if (alguno) {
            cobrando = true;
            boteVisible = 0;
        }
    }

    // ── Reparto: mazo, cartas voladoras y comunitarias que salen del mazo ─────
    // Ver docs/plan-animaciones-partida.md (Fase A). Con "animar" a false (por
    // defecto) nada de esto se ve: todo es instantáneo como siempre. Main.qml lo
    // activa solo para eventos NUEVOS (no al entrar en una mano en curso ni al
    // reconectar). "velocidad" existe para el banco de pruebas (0.25 = cámara lenta).
    property bool animar: false
    property real velocidad: 1.0
    // Huecos de la mano propia fuera de la mesa (escritorio: barra inferior). En móvil siempre null:
    // las cartas propias van a las de la propia silla.
    property var slotsPropios: null
    property bool repartiendo: false
    // Tras recoger la mano las mini-cartas de los asientos ya no están (hasta el próximo reparto).
    property bool sinCartas: false
    // Quiénes recibieron cartas en el último reparto (los eliminados no). Vacío = no se sabe
    // (entrada en una mano en curso): se ven las mini-cartas de todos los asientos con fichas.
    property var conCartas: []
    // Dealer y ciegas TAL COMO SE VEN: siguen a dealerNombre/sbNombre/bbNombre, pero cuando
    // cambian con "animar" el marcador viaja de un asiento al otro (moverMarcador) y solo al
    // aterrizar aparece en el asiento nuevo.
    property string dealerMostrado: ""
    property string sbMostrado: ""
    property string bbMostrado: ""
    Component.onCompleted: {
        dealerMostrado = dealerNombre;
        sbMostrado = sbNombre;
        bbMostrado = bbNombre;
    }
    onDealerNombreChanged: moverMarcador("D", dealerNombre)
    onSbNombreChanged: moverMarcador("SB", sbNombre)
    onBbNombreChanged: moverMarcador("BB", bbNombre)
    property var repartidas: ({})      // nombre -> cartas ya aterrizadas
    property int longitudPrevia: 0     // cartasMesa.length ANTES del último cambio

    // Duración base del reparto de una mano y de cada vuelo, en ms a velocidad 1.
    readonly property int duracionReparto: 900
    readonly property int vueloCartaReparto: 320
    readonly property int vueloComunitaria: 300
    readonly property int escalonComunitarias: 110

    // Para los sonidos (Main.qml / banco): qué va a pasar y cuándo.
    signal repartoIniciado(int cartas, int duracionMs)
    signal repartoTerminado()
    signal cartaPropiaAterrizada(int indice)
    signal comunitariasRepartidas(int cuantas, int inicioMs, int duracionMs)
    signal fichasLanzadas(int fichas, int cantidad, int inicioMs, int duracionMs)
    signal cartasRecogidas(int cartas, int duracionMs)
    signal cobroLanzado(int fichas, int cantidad, int inicioMs, int duracionMs)

    function ms(base) { return base / Math.max(0.05, mesa.velocidad); }

    onCartasMesaChanged: {
        var nuevas = cartasMesa.length - longitudPrevia;
        if (animar && nuevas > 0 && cartasMesa.length <= 5) {
            mostrarPilaDealer(ms(vueloComunitaria + escalonComunitarias * nuevas) + 200);
            comunitariasRepartidas(nuevas, Math.round(ms(vueloComunitaria)),
                                   Math.round(ms(escalonComunitarias) * (nuevas - 1)));
        }
        // Los huecos leen longitudPrevia al recibir su carta nueva (en este mismo
        // cambio), así que se actualiza DESPUÉS.
        Qt.callLater(function() { mesa.longitudPrevia = mesa.cartasMesa.length; });
    }

    // De dónde salen las cartas: false = del mazo (junto a las comunitarias, escritorio);
    // true = del dealer (móvil, donde no cabe el mazo: las 5 comunitarias llenan la mesa).
    // Con true, junto al avatar del dealer aparece un mini-mazo solo mientras reparte.
    property bool origenEnDealer: true

    function centroMazo() {
        return mazo.mapToItem(mesa, mazo.width / 2, mazo.height / 2);
    }
    function centroOrigen() {
        if (mesa.origenEnDealer) {
            var p = centroAsiento(mesa.dealerMostrado !== "" ? mesa.dealerMostrado : mesa.dealerNombre);
            if (p) return { x: p.x + 32 * Tema.escala, y: p.y + 6 * Tema.escala };
        }
        return centroMazo();
    }
    function mostrarPilaDealer(msVisible) {
        if (!mesa.origenEnDealer) return;
        var o = centroOrigen();
        pilaDealer.x = o.x - pilaDealer.width / 2;
        pilaDealer.y = o.y - pilaDealer.height / 2;
        animPila.msVisible = msVisible;
        animPila.restart();
    }

    // ── Fase B (avisos): retirarse, all-in, ganar/perder, eliminado ───────────
    // Ver docs/plan-animaciones-partida.md. Las funciones dibujan y emiten la señal
    // para que quien las llame pida el sonido (mismo esquema que el reparto).
    property var allIns: []        // nombres marcados con el aro ALL-IN (esta mano)
    property var eliminados: []    // nombres apagados (sin fichas)
    signal foldLanzado(string nombre)
    signal allInAnunciado(string nombre, int cantidad, bool grande)
    signal ganadorAnunciado(string nombre, bool esPropio, int premio, bool participo)
    signal eliminadoAnunciado(string nombre, bool esPropio)

    function fijarMarcador(tipo, nombre) {
        if (tipo === "D") dealerMostrado = nombre;
        else if (tipo === "SB") sbMostrado = nombre;
        else bbMostrado = nombre;
    }
    // El marcador de dealer/ciega VIAJA del asiento viejo al nuevo (con un pequeño salto), en
    // vez de aparecer sin más. Mientras vuela, ningún asiento lo muestra.
    function moverMarcador(tipo, nuevo) {
        var viejo = tipo === "D" ? dealerMostrado : tipo === "SB" ? sbMostrado : bbMostrado;
        var iv = indiceDe(viejo), inu = indiceDe(nuevo);
        var itv = iv < 0 ? null : asientos.itemAt(iv);
        var itn = inu < 0 ? null : asientos.itemAt(inu);
        if (!animar || viejo === nuevo || !itv || !itn) {
            fijarMarcador(tipo, nuevo);
            return;
        }
        var o = itv.asiento.centroMarcador(tipo, mesa);
        var d = itn.asiento.centroMarcador(tipo, mesa);
        fijarMarcador(tipo, "");
        var m = moldeMarcador.createObject(mesa, { tipo: tipo, x0: o.x, y0: o.y, x1: d.x, y1: d.y,
                                                    duracion: ms(700) });
        m.aterrizo.connect(function() { mesa.fijarMarcador(tipo, nuevo); });
    }
    Component {
        id: moldeMarcador
        Item {
            id: mv
            property string tipo: "D"
            property real x0: 0
            property real y0: 0
            property real x1: 0
            property real y1: 0
            property real duracion: 700
            property real progreso: 0
            signal aterrizo()
            z: 14
            enabled: false
            readonly property real arco: Math.min(50 * Tema.escala, Math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)) * 0.18)
            width: tipo === "D" ? 20 * Tema.escala : textoMv.implicitWidth + 8 * Tema.escala
            height: tipo === "D" ? 20 * Tema.escala : 18 * Tema.escala
            x: x0 + (x1 - x0) * progreso - width / 2
            y: y0 + (y1 - y0) * progreso - Math.sin(Math.PI * progreso) * arco - height / 2
            scale: 1 + 0.45 * Math.sin(Math.PI * progreso)
            NumberAnimation on progreso {
                from: 0
                to: 1
                duration: mv.duracion
                easing.type: Easing.InOutCubic
                running: true
                onFinished: { mv.aterrizo(); mv.destroy(); }
            }
            Rectangle {
                anchors.fill: parent
                radius: mv.tipo === "D" ? width / 2 : height / 2
                color: mv.tipo === "D" ? Tema.colorAccent : Tema.colorPanel
                border.width: mv.tipo === "D" ? 1.5 : 1
                border.color: mv.tipo === "D" ? Tema.colorFondo : Tema.colorBorde
                Text {
                    id: textoMv
                    anchors.centerIn: parent
                    text: mv.tipo
                    font.bold: true
                    font.pixelSize: (mv.tipo === "D" ? 11 : 9) * Tema.escala
                    font.family: Tema.fuenteElegante
                    color: mv.tipo === "D" ? Tema.colorFondo : Tema.colorAccent
                }
            }
        }
    }

    // Las dos cartas del asiento vuelan al mazo (o al dealer) y desaparecen.
    function retirarse(nombre) {
        var i = indiceDe(nombre);
        var it = i < 0 ? null : asientos.itemAt(i);
        if (!it) return;
        var destino = centroOrigen();
        var tam = cartaComunTam();
        var propio = nombre === miNombreJugador && slotsPropios;
        for (var k = 0; k < 2; k++) {
            var slot = propio ? slotsPropios[k] : null;
            var o = slot ? { x: slot.x + slot.w / 2, y: slot.y + slot.h / 2 }
                         : it.asiento.centroMiniCarta(k, mesa);
            var w0 = slot ? slot.w : it.asiento.anchoMiniCarta;
            var h0 = slot ? slot.h : it.asiento.altoMiniCarta;
            var g0 = slot ? 0 : (k - 0.5) * it.asiento.giroMiniCarta;
            cartasReparto.lanzar(o.x, o.y, destino.x, destino.y, w0, h0, tam.w * 0.7, tam.h * 0.7,
                                 -g0 + 90 * (k - 0.5), k * ms(60), ms(300), reversoActivo(),
                                 "fold:" + nombre, k);
        }
        foldLanzado(nombre);
    }

    function marcarAllIn(nombre) {
        if (mesa.allIns.indexOf(nombre) >= 0) return;
        mesa.allIns = mesa.allIns.concat([nombre]);
    }
    function temblar() { animTemblor.restart(); }

    // Cinta no bloqueante: entra deslizando, se queda un momento y se apaga. Sale POR ENCIMA de las
    // comunitarias (no sobre tu asiento). Sus colores salen del tema: rojo con filo dorado para el
    // all-in, dorado para ganar, sobria para perder y rojo oscuro para eliminado.
    // tipo: "allin" | "ganar" | "perder" | "eliminado".
    function mostrarBanda(texto, tipo) {
        var acento = Tema.colorAccent;
        if (tipo === "allin") {
            banda.colorBase = Tema.colorPeligro;
            banda.colorFilo = acento;
            banda.colorHilo = Qt.lighter(acento, 1.35);
        } else if (tipo === "ganar") {
            banda.colorBase = acento;
            banda.colorFilo = Qt.darker(acento, 1.7);
            banda.colorHilo = Qt.lighter(acento, 1.6);
        } else if (tipo === "eliminado") {
            banda.colorBase = Qt.darker(Tema.colorPeligro, 1.7);
            banda.colorFilo = acento;
            banda.colorHilo = Qt.darker(acento, 1.25);
        } else {
            banda.colorBase = Tema.colorPanel;
            banda.colorFilo = Tema.colorBorde;
            banda.colorHilo = Tema.colorTextoTenue;
        }
        banda.texto = texto;
        // Cuánto se queda a la vista: quién gana (o pierde) se tiene que poder leer aunque te despistes.
        banda.retencionMs = (tipo === "ganar" || tipo === "perder") ? 4500 : tipo === "eliminado" ? 2600 : 1800;
        // Justo encima de la fila de comunitarias (o lo más arriba posible sin salirse de la mesa).
        var yCartas = filaComunitarias.mapToItem(mesa, 0, 0).y;
        banda.y = Math.max(4 * Tema.escala, yCartas - banda.height - 6 * Tema.escala);
        animBanda.restart();
    }

    // Un all-in: fichas al bote (todas las que da la escala), aro pulsante en el
    // asiento, banda y, si es grande (>= la mitad del bote o de la pila media), temblor.
    function anunciarAllIn(nombre, cantidad) {
        lanzarFichas(nombre, cantidad);
        avisarAllIn(nombre, cantidad, true);
    }
    // El aviso solo (aro, banda, temblor si es grande, señal para el sonido): en la partida real
    // las fichas ya salieron con la ACCION, y una ciega que deja a cero solo marca el aro
    // ("conBanda" false: no se anuncia un all-in que nadie ha elegido).
    function avisarAllIn(nombre, cantidad, conBanda) {
        var pila = fichasReferencia();
        var grande = cantidad >= 0.5 * Math.max(mesa.bote, pila);
        marcarAllIn(nombre);
        if (!conBanda) return;
        mostrarBanda(Idioma.tf("banda_allin", [nombre]), "allin");
        if (grande) temblar();
        allInAnunciado(nombre, cantidad, grande);
    }
    function fichasReferencia() {
        var suma = 0;
        var n = mesa.jugadores.count;
        for (var i = 0; i < n; i++) {
            var j = mesa.jugadores.get(i);
            suma += (parseInt(j.saldo) || 0) + (parseInt(j.apuesta) || 0);
        }
        return n > 0 ? suma / n : 0;
    }
    // Fin de mano: el ganador cobra. "participo" = el jugador propio seguía en la mano
    // (para decidir entre sonido de ganar y de perder).
    function anunciarGanador(nombre, premio, participo, combo) {
        var esPropio = nombre === mesa.miNombreJugador;
        cobrarBote([{ nombre: nombre, premio: premio }]);
        var extra = combo ? "   ·   " + combo : "";
        mostrarBanda((esPropio ? Idioma.tf("banda_ganas", [premio]) : Idioma.tf("banda_gana_otro", [nombre, premio])) + extra,
                     esPropio ? "ganar" : "perder");
        ganadorAnunciado(nombre, esPropio, premio, participo);
    }
    // ── Showdown sobre la misma mesa ─────────────────────────────────────────────
    // muestras: nombre -> {cartas: [c1, c2], combo: "Pareja", ganador: bool}. Quien está
    // aquí enseña su mano (avatar mínimo + cartas grandes + combinación). "mejoresGanadora"
    // son los códigos de las 5 cartas de la mano ganadora: en la mesa y en los asientos se
    // resaltan y el resto se atenúa.
    property var muestras: ({})
    property var mejoresGanadora: []
    // Botes del showdown, para las etiquetas compactas: [{numBote, cantidad,
    // participantes: [{nombre, aporte}], ganador, premio}]. Al pulsar una se ven los detalles.
    property var botesShowdown: []
    property int botePulsado: -1

    // Fase 1 del showdown (a la vez para todos los que muestran por obligación): el avatar se
    // encoge y las cartas crecen, aún boca abajo.
    function prepararShowdown(nombres) {
        var m = Object.assign({}, mesa.muestras);
        for (var i = 0; i < nombres.length; i++)
            if (!m[nombres[i]]) m[nombres[i]] = { cartas: [], combo: "", ganador: false, revelada: false };
        mesa.muestras = m;
    }
    // Fase 2: se revelan de uno en uno, en orden de apuesta (lo decide quien llama).
    function revelarMano(nombre, cartas, combo) {
        var m = Object.assign({}, mesa.muestras);
        m[nombre] = Object.assign({ ganador: false }, m[nombre] || {}, { cartas: cartas, combo: combo || "", revelada: true });
        mesa.muestras = m;
    }
    // Actualiza solo los nombres de combinación (p. ej. al salir el río en un runout).
    function actualizarCombos(combos) {
        var m = Object.assign({}, mesa.muestras);
        for (var k in combos) if (m[k]) m[k] = Object.assign({}, m[k], { combo: combos[k] });
        mesa.muestras = m;
    }
    // Quien enseña por decisión propia (retirado, ganador sin showdown): no influye en el
    // resultado, así que se prepara y se revela sin esperar al orden del showdown.
    function mostrarManos(lista) {
        var m = Object.assign({}, mesa.muestras);
        for (var i = 0; i < lista.length; i++) {
            var e = lista[i];
            m[e.nombre] = { cartas: e.cartas, combo: e.combo || "", ganador: !!e.ganador, revelada: true };
        }
        mesa.muestras = m;
    }
    function marcarGanador(nombre, mejores) {
        var m = Object.assign({}, mesa.muestras);
        for (var k in m) m[k] = Object.assign({}, m[k], { ganador: k === nombre });
        mesa.muestras = m;
        mesa.mejoresGanadora = mejores || [];
    }
    // Limpia el showdown y el estado de la mano SIN animar (mano nueva con las animaciones apagadas,
    // o tras reconectar/resincronizar): los asientos vuelven a su aspecto normal de golpe.
    function reiniciarSinAnimar() {
        mesa.muestras = ({});
        mesa.mejoresGanadora = [];
        mesa.botesShowdown = [];
        mesa.botePulsado = -1;
        mesa.allIns = [];
        mesa.sinCartas = false;
        mesa.conCartas = [];
        mesa.repartiendo = false;
        mesa.repartidas = ({});
        for (var h = 0; h < 5; h++) { var hc = huecosComunitarias.itemAt(h); if (hc) hc.vaciado = false; }
    }

    // Fin de mano: TODAS las cartas de los asientos (reveladas o no, y las propias) vuelven al
    // dealer (o al mazo) y los asientos vuelven a la normalidad. Las comunitarias se voltean y
    // vuelven solas cuando cartasMesa se vacía (ver los huecos). Después Main.qml/el banco rota los
    // marcadores (dealerNombre/sbNombre/bbNombre) y empieza la mano siguiente.
    function recogerCartas() {
        var destino = centroOrigen();
        var tam = cartaComunTam();
        var hubo = false;
        for (var i = 0; i < mesa.jugadores.count; i++) {
            var nombre = mesa.jugadores.get(i).nombre;
            var it = asientos.itemAt(i);
            if (!it) continue;
            var propio = nombre === miNombreJugador;
            var conMiniCartas = !propio && retirados.indexOf(nombre) < 0 && eliminados.indexOf(nombre) < 0;
            var conSlots = propio && slotsPropios;
            if (!mesa.muestras[nombre] && !conMiniCartas && !conSlots) continue;
            for (var k = 0; k < 2; k++) {
                var slot = conSlots && !mesa.muestras[nombre] ? slotsPropios[k] : null;
                var o = slot ? { x: slot.x + slot.w / 2, y: slot.y + slot.h / 2 }
                             : it.asiento.centroMiniCarta(k, mesa);
                var w0 = slot ? slot.w : it.asiento.anchoMiniCarta;
                var h0 = slot ? slot.h : it.asiento.altoMiniCarta;
                cartasReparto.lanzar(o.x, o.y, destino.x, destino.y, w0, h0, tam.w * 0.7, tam.h * 0.7,
                                     90 * (k - 0.5), k * ms(50), ms(340), reversoActivo(),
                                     "recoge:" + nombre, k);
                hubo = true;
            }
        }
        mesa.muestras = ({});
        mesa.mejoresGanadora = [];
        mesa.botesShowdown = [];
        mesa.botePulsado = -1;
        mesa.sinCartas = true;
        // Para el sonido: las de los asientos vuelan ya y las comunitarias (que primero se voltean)
        // un poco después; un solo evento que abarca las dos.
        var comunes = 0;
        for (var h = 0; h < 5; h++) { var hc = huecosComunitarias.itemAt(h); if (hc && hc.mostrado !== "") comunes++; }
        var total = (hubo ? 2 * Math.max(1, Math.round(mesa.jugadores.count / 2)) : 0) + comunes;
        if (hubo || comunes > 0) cartasRecogidas(Math.max(1, total), Math.round(ms(760)));
        return hubo;
    }

    function anunciarEliminado(nombre) {
        if (mesa.eliminados.indexOf(nombre) < 0) mesa.eliminados = mesa.eliminados.concat([nombre]);
        mostrarBanda(Idioma.tf("banda_eliminado", [nombre]), "eliminado");
        eliminadoAnunciado(nombre, nombre === mesa.miNombreJugador);
    }

    // Reparte la mano: "orden" son los nombres en el orden real (empezando por la
    // ciega pequeña), dos vueltas. Las mini-cartas de cada asiento se destapan según
    // aterriza cada carta voladora.
    function repartirMano(orden) {
        if (repartiendo) return false;
        // Sin reparto animado (no se sabe quién juega, o no hay animación), los asientos NO pueden
        // quedarse sin mini-cartas (sinCartas lo deja la recogida de la mano anterior): se ven todas.
        if (!animar || orden.length === 0) {
            sinCartas = false;
            conCartas = [];
            return false;
        }
        var total = orden.length * 2;
        var duracion = ms(duracionReparto);
        var vuelo = ms(vueloCartaReparto);
        var paso = total > 1 ? Math.max(0, (duracion - vuelo) / (total - 1)) : 0;
        var origen = centroOrigen();
        var tamComun = cartaComunTam();
        mostrarPilaDealer(duracion + vuelo);
        repartidas = ({});
        allIns = [];
        sinCartas = false;
        conCartas = orden.slice();
        for (var h = 0; h < 5; h++) { var hc = huecosComunitarias.itemAt(h); if (hc) hc.vaciado = true; }
        repartiendo = true;
        var lanzadas = 0;
        for (var ronda = 0; ronda < 2; ronda++) {
            for (var k = 0; k < orden.length; k++) {
                var nombre = orden[k];
                var i = indiceDe(nombre);
                var it = i < 0 ? null : asientos.itemAt(i);
                if (!it) continue;
                var slot = nombre === miNombreJugador && slotsPropios ? slotsPropios[ronda] : null;
                var propio = slot !== null;
                var destino = propio
                    ? { x: slot.x + slot.w / 2, y: slot.y + slot.h / 2 }
                    : it.asiento.centroMiniCarta(ronda, mesa);
                var w1 = propio ? slot.w : it.asiento.anchoMiniCarta;
                var h1 = propio ? slot.h : it.asiento.altoMiniCarta;
                var giro = propio ? 0 : (ronda - 0.5) * it.asiento.giroMiniCarta;
                if (cartasReparto.lanzar(origen.x, origen.y, destino.x, destino.y,
                                         tamComun.w, tamComun.h, w1, h1, giro,
                                         (ronda * orden.length + k) * paso, vuelo,
                                         reversoActivo(), nombre, ronda))
                    lanzadas++;
            }
        }
        if (lanzadas === 0) {
            repartiendo = false;
            sinCartas = false;
            conCartas = [];
            return false;
        }
        repartoIniciado(lanzadas, Math.round(duracion));
        // Red de seguridad: si por lo que sea alguna carta no aterriza, los asientos
        // NO se quedan sin mini-cartas.
        seguridadReparto.interval = Math.round(duracion + vuelo + 1200);
        seguridadReparto.restart();
        return true;
    }

    // Tamaño de una carta comunitaria (el de Carta.qml por defecto): una Carta
    // invisible que sirve de medida, para que el mazo y las voladoras midan igual.
    Carta { id: medidaCarta; visible: false }
    function huecoAt(i) { return huecosComunitarias.itemAt(i); }
    function cartaComunTam() {
        return { w: medidaCarta.width, h: medidaCarta.height };
    }

    function terminarReparto() {
        seguridadReparto.stop();
        repartiendo = false;
        repartoTerminado();
    }

    Timer {
        id: seguridadReparto
        onTriggered: if (mesa.repartiendo) mesa.terminarReparto()
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

    // El tapete: forma de "pastilla" -- ver Tapete.qml. "tapete" es el
    // código elegido (el del anfitrión o el propio, lo decide Main.qml);
    // vacío = el de siempre, que sigue al tema.
    Tapete {
        anchors.fill: parent
        preset: mesa.tapete
    }

    // Posición y tamaño del bloque central (comunitarias + bote + botes del showdown). Por defecto va
    // centrado a tamaño normal, pero en el showdown el asiento de arriba (con su mano y su combinación)
    // y el de abajo (con tus cartas y el aro de decoraciones del avatar, que sobresale por encima de su
    // recuadro) crecen y lo pisaban: la combinación del ganador quedaba tapada por las comunitarias y el
    // avatar se comía el "Bote". Se desplaza dentro de la banda libre entre esos asientos, dando
    // prioridad a que no tape al de arriba, y si aun así no cabe se reduce (hasta un 72 %).
    readonly property var geoCentro: {
        var n = asientos.count;   // dependencia: se recalcula al aparecer los asientos
        var h = columnaCentro.height;
        var x0 = (mesa.width - columnaCentro.width) / 2;
        var x1 = x0 + columnaCentro.width;
        var sup = 0;
        var inf = mesa.height;
        for (var i = 0; i < n; i++) {
            var it = asientos.itemAt(i);
            if (!it) continue;
            if (it.x + it.width <= x0 || it.x >= x1) continue;   // no coincide en horizontal con el bloque
            if (it.y + it.height / 2 < mesa.height / 2) sup = Math.max(sup, it.y + it.height);
            else inf = Math.min(inf, it.y);
        }
        var libreArriba = sup > 0 ? sup + 4 * Tema.escala : 0;
        // Hueco para las decoraciones del avatar de abajo (la corona de cartas sobresale ~16 px).
        var libreAbajo = inf < mesa.height ? inf - 16 * Tema.escala : mesa.height;
        var escala = h > 0 && h > libreAbajo - libreArriba ? Math.max(0.72, (libreAbajo - libreArriba) / h) : 1;
        var hEsc = h * escala;
        return { y: Math.max(libreArriba, Math.min((mesa.height - hEsc) / 2, libreAbajo - hEsc)), escala: escala };
    }

    // Centro de la mesa: cartas comunitarias arriba, bote (y botes del showdown) debajo.
    Column {
        id: columnaCentro
        anchors.horizontalCenter: parent.horizontalCenter
        y: mesa.geoCentro.y
        scale: mesa.geoCentro.escala
        transformOrigin: Item.Top
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }
        spacing: 8 * Tema.escala
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: filaComunitarias.width
            height: filaComunitarias.height
            // El mazo: siempre a la vista, a la izquierda de las comunitarias. De él
            // salen las cartas del reparto y las del flop/turn/river.
            Item {
                id: mazo
                visible: !mesa.origenEnDealer
                anchors.right: filaComunitarias.left
                anchors.rightMargin: 30 * Tema.escala
                anchors.verticalCenter: filaComunitarias.verticalCenter
                width: medidaCarta.width
                height: medidaCarta.height
                Repeater {
                    model: 3
                    delegate: Carta {
                        required property int index
                        width: mazo.width
                        height: mazo.height
                        x: index * 1.5 * Tema.escala
                        y: -index * 1.5 * Tema.escala
                        reversoSkin: mesa.reversoActivo()
                    }
                }
            }
        Row {
            id: filaComunitarias
            spacing: 6 * Tema.escala
            // Siempre 5 posiciones desde el preflop, no solo cuando ya
            // hay cartas reveladas — las que faltan se ven boca abajo
            // (Carta con codigo vacío) en vez de dejar el hueco vacío.
            //
            // Al pasar de "carta" a "vacío" (mano nueva) las cartas se dan la
            // vuelta: giran hasta el canto, se cambian por el dorso y
            // terminan de girar, escalonadas. Cualquier otro cambio (sale el
            // flop, etc.) es instantáneo, como siempre.
            Repeater {
                id: huecosComunitarias
                model: 5
                delegate: Item {
                    id: hueco
                    required property int index
                    readonly property string objetivo: index < mesa.cartasMesa.length ? mesa.cartasMesa[index] : ""
                    property string mostrado: ""
                    // La carta ya volvió al dealer/mazo: el hueco queda como un sitio vacío.
                    property bool vaciado: false
                    // El halo de una ganadora no debe quedar tapado por la carta vecina.
                    z: enGanadora ? 1 : 0
                    width: cartaHueco.width
                    height: cartaHueco.height
                    Component.onCompleted: mostrado = objetivo
                    onObjetivoChanged: {
                        if (objetivo === "" && mostrado !== "") {
                            llegada.stop();
                            volar.visible = false;
                            volteo.restart();
                        } else if (objetivo !== "" && mostrado === "" && mesa.animar) {
                            // Carta nueva: sale del origen, aterriza boca abajo y se voltea. El hueco
                            // sigue vacío (contorno) mientras la carta vuela: se rellena al aterrizar.
                            volteo.stop();
                            giro.angle = 0;
                            llegada.restart();
                        } else {
                            llegada.stop();
                            volar.visible = false;
                            volteo.stop();
                            giro.angle = 0;
                            if (objetivo !== "") vaciado = false;
                            mostrado = objetivo;
                        }
                    }
                    // Carta boca abajo que viaja del mazo a este hueco (hija del hueco:
                    // puede dibujarse fuera de él).
                    Carta {
                        id: volar
                        visible: false
                        z: 5
                        width: cartaHueco.width
                        height: cartaHueco.height
                        reversoSkin: mesa.reversoActivo()
                    }
                    SequentialAnimation {
                        id: llegada
                        // Orden dentro del reparto de esta calle: 0 para la primera nueva.
                        PauseAnimation { duration: Math.max(0, hueco.index - mesa.longitudPrevia) * mesa.ms(mesa.escalonComunitarias) }
                        ScriptAction {
                            script: {
                                var o = mesa.centroOrigen();
                                var p = hueco.mapFromItem(mesa, o.x, o.y);
                                volar.x = p.x - volar.width / 2;
                                volar.y = p.y - volar.height / 2;
                                volar.rotation = -14;
                                volar.visible = true;
                            }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: volar; property: "x"; to: 0; duration: mesa.ms(mesa.vueloComunitaria); easing.type: Easing.OutCubic }
                            NumberAnimation { target: volar; property: "y"; to: 0; duration: mesa.ms(mesa.vueloComunitaria); easing.type: Easing.OutCubic }
                            NumberAnimation { target: volar; property: "rotation"; to: 0; duration: mesa.ms(mesa.vueloComunitaria); easing.type: Easing.OutCubic }
                        }
                        ScriptAction { script: { volar.visible = false; hueco.vaciado = false; } }
                        // Se voltea para enseñar la cara.
                        NumberAnimation { target: giro; property: "angle"; to: 90; duration: mesa.ms(110); easing.type: Easing.InQuad }
                        ScriptAction { script: hueco.mostrado = hueco.objetivo }
                        NumberAnimation { target: giro; property: "angle"; to: 0; duration: mesa.ms(110); easing.type: Easing.OutQuad }
                    }
                    readonly property bool enGanadora: hueco.mostrado !== "" && mesa.mejoresGanadora.indexOf(hueco.mostrado) >= 0
                    // Sitio vacío (la carta volvió al origen): solo un contorno suave.
                    Rectangle {
                        anchors.fill: cartaHueco
                        radius: cartaHueco.radius
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.16)
                        visible: hueco.vaciado
                    }
                    function volverAlOrigen() {
                        if (!mesa.animar) return;
                        var c = hueco.mapToItem(mesa, hueco.width / 2, hueco.height / 2);
                        var o = mesa.centroOrigen();
                        var t = mesa.cartaComunTam();
                        cartasReparto.lanzar(c.x, c.y, o.x, o.y, t.w, t.h, t.w * 0.7, t.h * 0.7, 0,
                                             0, mesa.ms(340), mesa.reversoActivo(), "mesa:" + hueco.index, hueco.index);
                        hueco.vaciado = true;
                    }
                    Carta {
                        id: cartaHueco
                        visible: !hueco.vaciado
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
                    // Carta de la mano ganadora: filo dorado + halo que late (BrilloCarta.qml).
                    BrilloCarta {
                        anchors.fill: cartaHueco
                        radio: cartaHueco.radius
                        visible: hueco.enGanadora
                        animando: mesa.animar
                        velocidad: mesa.velocidad
                    }
                    SequentialAnimation {
                        id: volteo
                        PauseAnimation { duration: hueco.index * 70 }
                        NumberAnimation { target: giro; property: "angle"; to: 90; duration: 130; easing.type: Easing.InQuad }
                        ScriptAction { script: hueco.mostrado = "" }
                        NumberAnimation { target: giro; property: "angle"; to: 0; duration: 130; easing.type: Easing.OutQuad }
                        // Ya boca abajo: la carta vuelve al dealer (o al mazo).
                        ScriptAction { script: hueco.volverAlOrigen() }
                    }
                }
            }
        }
        }
        // Bote total y, al lado, las etiquetas de los botes del showdown (principal y side pots): una sola
        // fila. Las etiquetas no se muestran siempre: al pulsar una salen sus detalles (quién entró,
        // cuánto puso y quién ganó).
        Row {
            id: filaBoteYEtiquetas
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10 * Tema.escala
            Row {
                id: filaBote
                anchors.verticalCenter: parent.verticalCenter
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
            Row {
                id: filaEtiquetasBotes
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * Tema.escala
                visible: mesa.botesShowdown.length > 1
                height: visible ? implicitHeight : 0
                Repeater {
                    model: mesa.botesShowdown
                    delegate: Rectangle {
                        id: etiquetaBote
                        required property var modelData
                        required property int index
                        width: textoEtiqueta.implicitWidth + 14 * Tema.escala
                        height: 22 * Tema.escala
                        radius: height / 2
                        color: mesa.botePulsado === index ? Tema.colorAccent : Tema.colorPanel
                        border.width: 1
                        border.color: Tema.colorAccent
                        Text {
                            id: textoEtiqueta
                            anchors.centerIn: parent
                            text: etiquetaBote.modelData.numBote === 0
                                  ? Idioma.tf("bote_etiqueta_principal", [etiquetaBote.modelData.cantidad])
                                  : Idioma.tf("bote_etiqueta_side", [etiquetaBote.modelData.numBote, etiquetaBote.modelData.cantidad])
                            color: mesa.botePulsado === etiquetaBote.index ? Tema.colorFondo : Tema.colorAccent
                            font.pixelSize: 11 * Tema.escala
                            font.bold: true
                            font.family: Tema.fuenteElegante
                        }
                        // Zona pulsable de Tema.tactil como mínimo (la etiqueta se ve más pequeña).
                        MouseArea {
                            anchors.fill: parent
                            anchors.topMargin: -Math.max(0, (Tema.tactil - etiquetaBote.height) / 2)
                            anchors.bottomMargin: anchors.topMargin
                            anchors.leftMargin: -3 * Tema.escala
                            anchors.rightMargin: -3 * Tema.escala
                            onClicked: mesa.botePulsado = mesa.botePulsado === etiquetaBote.index ? -1 : etiquetaBote.index
                        }
                    }
                }
            }
        }
    }

    // Asientos: uno por jugador, repartidos a partes iguales alrededor
    // de una elipse (no números fijos como en el boceto, porque el
    // número de jugadores puede cambiar). Cada delegate es un Item
    // "posicionador" que calcula su propio x/y con trigonometría y
    // mete un Asiento normal dentro — así Asiento no necesita saber
    // nada de mesas ni de ángulos, sigue siendo reutilizable.
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
            // 46 * Tema.escala en vez del 40 fijo de escritorio: el asiento (avatar + placa) crece con
            // la escala, así que el margen que lo separa del borde de la elipse tiene que crecer con
            // él (a escala alta el asiento de arriba se recortaba contra el borde de la ventana).
            // Acotado al recuadro de la mesa: con tus cartas más grandes (o las enseñadas en el
            // showdown) el asiento es más alto y ancho, y el de abajo se salía por el borde.
            x: Math.max(2, Math.min(mesa.width - width - 2,
                   mesa.width / 2 + (mesa.width / 2 - 46 * Tema.escala) * Math.cos(angulo) - width / 2))
            y: Math.max(2, Math.min(mesa.height - height + 8 * Tema.escala,
                   mesa.height / 2 + (mesa.height / 2 - 46 * Tema.escala) * Math.sin(angulo) - height / 2))
            width: asientoReal.width
            height: asientoReal.height
            property alias asiento: asientoReal
            readonly property var muestra: mesa.muestras[nombre] !== undefined ? mesa.muestras[nombre] : null

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
                // Antes solo se animaba el aro en el propio asiento
                // (era la única aproximación posible sin timeout_ms real
                // para los demás). Ahora el servidor difunde el mismo
                // dato en cada turno (onTurnoIniciado), así que cualquier
                // asiento activo anima su cuenta atrás real.
                fraccionTiempo: posicionador.nombre === mesa.turnoNombre ? mesa.fraccionTiempo : 1.0
                retirado: mesa.retirados.indexOf(posicionador.nombre) !== -1
                esDealer: posicionador.nombre === mesa.dealerMostrado
                esSb: posicionador.nombre === mesa.sbMostrado
                esBb: posicionador.nombre === mesa.bbMostrado
                esPropio: posicionador.nombre === mesa.miNombreJugador
                reversoActivo: mesa.reversoActivo()
                miReversoSkin: mesa.miReversoSkin
                miCarta1: mesa.miCarta1
                miCarta2: mesa.miCarta2
                muestra: posicionador.muestra
                allIn: mesa.allIns.indexOf(posicionador.nombre) >= 0
                eliminado: mesa.eliminados.indexOf(posicionador.nombre) >= 0
                animando: mesa.animar
                resaltadas: mesa.mejoresGanadora
                velocidad: mesa.velocidad
                cartasVisibles: mesa.repartiendo ? (mesa.repartidas[posicionador.nombre] || 0)
                                : (mesa.sinCartas || mesa.eliminados.indexOf(posicionador.nombre) >= 0 ? 0
                                   : (mesa.conCartas.length === 0 || mesa.conCartas.indexOf(posicionador.nombre) >= 0 ? 2 : 0))
            }
        }
    }

    // Fichas en vuelo: la última hija, por encima de los asientos.
    // ── Capa de avisos (Fase B): mini-mazo del dealer, aros de all-in, eliminados y banda.
    // Ninguna acepta ratón ni tapa los botones; z entre los asientos y las cartas/fichas
    // en vuelo.
    Item {
        id: pilaDealer
        z: 9
        enabled: false
        opacity: 0
        visible: opacity > 0
        width: medidaCarta.width * 0.62
        height: medidaCarta.height * 0.62
        Repeater {
            model: 3
            delegate: Carta {
                required property int index
                width: pilaDealer.width
                height: pilaDealer.height
                x: index * 1.5 * Tema.escala
                y: -index * 1.5 * Tema.escala
                reversoSkin: mesa.reversoActivo()
            }
        }
        SequentialAnimation {
            id: animPila
            property real msVisible: 800
            NumberAnimation { target: pilaDealer; property: "opacity"; to: 1; duration: mesa.ms(120) }
            PauseAnimation { duration: animPila.msVisible }
            NumberAnimation { target: pilaDealer; property: "opacity"; to: 0; duration: mesa.ms(220) }
        }
    }

    // Detalle del bote pulsado: participantes, lo que puso cada uno y el ganador.
    Rectangle {
        id: detalleBote
        readonly property var bote: mesa.botePulsado >= 0 && mesa.botePulsado < mesa.botesShowdown.length
                                    ? mesa.botesShowdown[mesa.botePulsado] : null
        visible: bote !== null
        z: 16
        width: Math.min(250 * Tema.escala, mesa.width - 16 * Tema.escala)
        height: contenidoDetalle.implicitHeight + 20 * Tema.escala
        radius: 8 * Tema.escala
        color: Tema.colorPanel
        border.width: 1
        border.color: Tema.colorAccent
        // Centrado en la mesa (no bajo las etiquetas): así nunca se sale por el borde inferior. Si
        // alguna vez fuera más alto que la mesa, se ancla arriba para no perder el título.
        x: Math.max(4, (mesa.width - width) / 2)
        y: Math.max(4 * Tema.escala, (mesa.height - height) / 2)
        Column {
            id: contenidoDetalle
            anchors.centerIn: parent
            width: parent.width - 20 * Tema.escala
            spacing: 4 * Tema.escala
            Text {
                text: !detalleBote.bote ? ""
                      : detalleBote.bote.numBote === 0 ? Idioma.tf("bote_detalle_principal", [detalleBote.bote.cantidad])
                      : Idioma.tf("bote_detalle_side", [detalleBote.bote.numBote, detalleBote.bote.cantidad])
                color: Tema.colorAccent
                font.bold: true
                font.pixelSize: 13 * Tema.escala
                font.family: Tema.fuenteElegante
            }
            Repeater {
                model: detalleBote.bote ? detalleBote.bote.participantes : []
                delegate: Row {
                    id: filaPart
                    required property var modelData
                    width: contenidoDetalle.width
                    Text {
                        width: parent.width * 0.5
                        text: (filaPart.modelData.nombre === (detalleBote.bote ? detalleBote.bote.ganador : "") ? "★ " : "") + filaPart.modelData.nombre
                        color: filaPart.modelData.nombre === (detalleBote.bote ? detalleBote.bote.ganador : "") ? Tema.colorAccent : Tema.colorTexto
                        font.pixelSize: 12 * Tema.escala
                        font.family: Tema.fuenteElegante
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width * 0.5
                        horizontalAlignment: Text.AlignRight
                        text: Idioma.tf("bote_puso", [filaPart.modelData.aporte])
                        color: Tema.colorTextoTenue
                        font.pixelSize: 12 * Tema.escala
                        font.family: Tema.fuenteElegante
                    }
                }
            }
            Text {
                text: detalleBote.bote && detalleBote.bote.ganador !== "" ? Idioma.tf("bote_gana", [detalleBote.bote.ganador, detalleBote.bote.premio]) : ""
                color: Tema.colorAccent
                font.pixelSize: 12 * Tema.escala
                font.bold: true
                font.family: Tema.fuenteElegante
            }
        }
        MouseArea { anchors.fill: parent; onClicked: mesa.botePulsado = -1 }
    }

    // La cinta del aviso (ALL-IN, gana, pierde, eliminado), al estilo "ficha de casino" de la app:
    // sombra corta, metal de tres paradas, doble bisel (filo + hilo interior) y rombos en los extremos.
    Item {
        id: banda
        property string texto: ""
        property real retencionMs: 1800
        property color colorBase: Tema.colorAccent
        property color colorFilo: Tema.colorBorde
        property color colorHilo: Tema.colorAccent
        // Texto legible sobre el metal, sea claro u oscuro el tema.
        readonly property color colorTextoBanda: (0.299 * colorBase.r + 0.587 * colorBase.g + 0.114 * colorBase.b) > 0.55
                                                 ? "#1B1408" : "#FFFFFF"
        z: 20
        enabled: false
        opacity: 0
        visible: opacity > 0
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(mesa.width * 0.9, textoBanda.implicitWidth + 80 * Tema.escala)
        height: 38 * Tema.escala
        transform: Translate { id: deslizaBanda; x: 0 }

        Rectangle {   // sombra
            anchors.fill: parent
            anchors.topMargin: 3 * Tema.escala
            anchors.leftMargin: 2 * Tema.escala
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.38)
        }
        Rectangle {   // cuerpo metálico + filo exterior
            id: cuerpoBanda
            anchors.fill: parent
            radius: height / 2
            border.width: 2
            border.color: banda.colorFilo
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.lighter(banda.colorBase, 1.3) }
                GradientStop { position: 0.55; color: banda.colorBase }
                GradientStop { position: 1.0; color: Qt.darker(banda.colorBase, 1.25) }
            }
        }
        Rectangle {   // hilo interior
            anchors.fill: parent
            anchors.margins: 4 * Tema.escala
            radius: height / 2
            color: "transparent"
            border.width: 1
            border.color: banda.colorHilo
            opacity: 0.85
        }
        // Rombos ornamentales a los lados (dibujados, sin depender de ningún glifo).
        Repeater {
            model: 2
            delegate: Rectangle {
                required property int index
                width: 8 * Tema.escala
                height: width
                rotation: 45
                color: banda.colorHilo
                anchors.verticalCenter: parent.verticalCenter
                x: index === 0 ? 16 * Tema.escala : parent.width - 16 * Tema.escala - width
            }
        }
        Text {
            id: textoBanda
            anchors.centerIn: parent
            text: banda.texto
            color: banda.colorTextoBanda
            font.bold: true
            font.pixelSize: 15 * Tema.escala
            font.letterSpacing: 1.2
            font.family: Tema.fuenteElegante
        }
        SequentialAnimation {
            id: animBanda
            ScriptAction { script: { banda.opacity = 0; deslizaBanda.x = -90 * Tema.escala; } }
            ParallelAnimation {
                NumberAnimation { target: banda; property: "opacity"; to: 1; duration: mesa.ms(150) }
                NumberAnimation { target: deslizaBanda; property: "x"; to: 0; duration: mesa.ms(240); easing.type: Easing.OutBack }
            }
            PauseAnimation { duration: mesa.ms(banda.retencionMs) }
            NumberAnimation { target: banda; property: "opacity"; to: 0; duration: mesa.ms(400) }
        }
    }

    SequentialAnimation {
        id: animTemblor
        NumberAnimation { target: temblor; property: "x"; to: 5 * Tema.escala; duration: mesa.ms(35) }
        NumberAnimation { target: temblor; property: "x"; to: -5 * Tema.escala; duration: mesa.ms(50) }
        NumberAnimation { target: temblor; property: "x"; to: 3 * Tema.escala; duration: mesa.ms(45) }
        NumberAnimation { target: temblor; property: "x"; to: -2 * Tema.escala; duration: mesa.ms(40) }
        NumberAnimation { target: temblor; property: "x"; to: 0; duration: mesa.ms(40) }
    }

    RepartoVolando {
        id: cartasReparto
        anchors.fill: parent
        z: 10
        onAterrizo: function(nombre, indice) {
            var r = Object.assign({}, mesa.repartidas);
            r[nombre] = (r[nombre] || 0) + 1;
            mesa.repartidas = r;
            if (nombre === mesa.miNombreJugador) mesa.cartaPropiaAterrizada(indice);
        }
        onTodasAterrizaron: if (mesa.repartiendo) mesa.terminarReparto()
    }

    FichasVolando {
        id: fichas
        anchors.fill: parent
        z: 10
        duracionVuelo: Math.round(mesa.ms(460))
        escalonado: Math.round(mesa.ms(50))
        onAterrizaron: {
            if (!mesa.cobrando) mesa.boteVisible = mesa.bote;
        }
    }
}
