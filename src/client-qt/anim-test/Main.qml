// Main.qml (AnimTest) -- banco de audición de sonidos.
//
// Cada EVENTO del juego (repartir, all-in...) tiene dos CAPAS (A y B). Una capa
// es un lote de sonidos más cómo se dispara: cuántos golpes (n), cada cuántos ms
// (separación), cuánto azar en el momento (jitter), retraso respecto a la otra
// capa y volumen. Los golpes se solapan, y la capa B con retraso da el efecto de
// "dos sonidos casi a la vez" (fichas + impacto). "Probar" reproduce el evento
// exactamente como lo reproducirá el juego (BancoSonidos.programar).
//
// ▶ escucha un candidato suelto; ★ lo añade a la capa activa del evento activo.
// "Guardar" escribe seleccion.json junto a los candidatos (y se recarga solo la
// próxima vez), con todos los parámetros: el juego lo usará tal cual.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

ApplicationWindow {
    id: ventana
    visible: true
    width: 1300
    height: 1010
    title: "Banco de pruebas — sonidos y animaciones de mesa"
    color: Tema.colorFondo

    property var candidatos: []
    property string dirSonidos: ""
    property int temaInicial: 0
    property bool autoprueba: false
    property bool demo: false
    property bool autopruebaShowdown: false
    property string demoEvento: ""
    property bool origenDealerInicial: false
    property int pestanaInicial: 0
    property real velocidadInicial: 1.0

    readonly property var eventos: [
        { id: "reparto",     texto: "Repartir cartas",   n: 8, gap: 85 },
        { id: "comunitaria", texto: "Carta comunitaria", n: 1, gap: 0 },
        { id: "flop",        texto: "Flop (abanico)",    n: 3, gap: 110 },
        { id: "fold",        texto: "Retirarse (fold)",  n: 2, gap: 60 },
        { id: "fichas",      texto: "Fichas al bote",    n: 4, gap: 60 },
        { id: "allin",       texto: "All-in",            n: 1, gap: 0 },
        { id: "cobro",       texto: "Cobrar bote",       n: 5, gap: 55 },
        { id: "ganar",       texto: "Ganar",             n: 1, gap: 0 },
        { id: "perder",      texto: "Perder",            n: 1, gap: 0 },
        { id: "eliminado",   texto: "Eliminado",         n: 1, gap: 0 },
        { id: "recogida",    texto: "Recoger cartas",    n: 8, gap: 55 },
        { id: "barajar",     texto: "Barajar",           n: 1, gap: 0 }
    ]
    readonly property var grupos: ["cartas", "fichas", "impactos", "jingles"]
    property string grupoActual: "cartas"
    property string eventoActivo: "reparto"
    property string capaActiva: "A"
    // { evento: { A: capa, B: capa } }
    property var config: ({})
    property string mensaje: ""

    function capaNueva(ev, letra) {
        var e = ventana.eventos.filter(function(x) { return x.id === ev; })[0];
        return { sonidos: [], retraso: letra === "B" ? 80 : 0, n: letra === "A" ? e.n : 1,
                 gap: e.gap, jit: 20, vol: 100, volJit: 15 };
    }
    function capa(ev, letra) {
        var c = ventana.config[ev];
        return (c && c[letra]) ? c[letra] : ventana.capaNueva(ev, letra);
    }
    function poner(ev, letra, cambios) {
        var todo = Object.assign({}, ventana.config);
        var par = Object.assign({}, todo[ev] || {});
        par[letra] = Object.assign({}, ventana.capa(ev, letra), cambios);
        todo[ev] = par;
        ventana.config = todo;
    }
    function alternar(nombre) {
        var l = ventana.capa(ventana.eventoActivo, ventana.capaActiva).sonidos.slice();
        var i = l.indexOf(nombre);
        if (i >= 0) l.splice(i, 1); else l.push(nombre);
        ventana.poner(ventana.eventoActivo, ventana.capaActiva, { sonidos: l });
    }
    function enCapa(nombre) {
        return ventana.capa(ventana.eventoActivo, ventana.capaActiva).sonidos.indexOf(nombre) >= 0;
    }
    // Todos los sonidos usados en algún evento -> el banco solo precarga esos.
    readonly property var rutasUsadas: {
        var r = {};
        for (var ev in ventana.config)
            for (var l in ventana.config[ev])
                ventana.config[ev][l].sonidos.forEach(function(n) {
                    for (var i = 0; i < ventana.candidatos.length; i++)
                        if (ventana.candidatos[i].nombre === n) r[n] = "file://" + ventana.candidatos[i].ruta;
                });
        return r;
    }
    function probar(ev) {
        banco.programar(ventana.config[ev]);
    }
    // La autoprueba usa su propio fichero: nunca debe pisar la selección real.
    readonly property string ficheroSeleccion: ventana.dirSonidos + (ventana.autoprueba ? "/seleccion-autoprueba.json" : "/seleccion.json")
    function guardar() {
        var ok = Disco.escribir(ventana.ficheroSeleccion, JSON.stringify(ventana.config, null, 1));
        ventana.mensaje = ok ? "Guardado en " + ventana.ficheroSeleccion
                             : "ERROR: no se pudo escribir en " + ventana.dirSonidos;
    }
    Component.onCompleted: {
        Tema.temaActual = ventana.temaInicial;
        var previo = ventana.autoprueba ? "" : Disco.leer(ventana.ficheroSeleccion);
        if (previo !== "") {
            try {
                ventana.config = JSON.parse(previo);
                ventana.mensaje = "Cargada la selección anterior.";
            } catch (e) { ventana.mensaje = "seleccion.json ilegible, se ignora."; }
        }
        escenaMesa.velocidad = ventana.velocidadInicial;
        escenaMesa.origenEnDealer = ventana.origenDealerInicial;
        if (ventana.autoprueba) ventana.correrAutoprueba();
        if (ventana.autopruebaShowdown) ventana.correrAutopruebaShowdown();
        if (!ventana.autoprueba && (ventana.demo || (ventana.demoEvento !== "" && ventana.demoEvento.indexOf("sec") !== 0))) Qt.callLater(escenaMesa.nuevaMano);
        if (ventana.demoEvento.indexOf("sec") === 0) {
            Qt.callLater(function() { escenaMesa.correrSecuencia(parseInt(ventana.demoEvento.slice(3, 4))); });
            // "sec2bote": además, abre el detalle del side pot 1 (para capturarlo)
            if (ventana.demoEvento.slice(-4) === "bote") pulsarBote.start();
            // "secNciclo": al llegar a la decisión, pulsa "Seguir jugando" (para capturar el ciclo)
            if (ventana.demoEvento.slice(-5) === "ciclo") esperaDecision.start();
        }
        else if (ventana.demoEvento !== "") demoTimer.start();
    }

    // --autoprueba: humo sin intervención. Monta una selección, la guarda, dispara
    // los eventos (con solapes y capas) y comprueba que el fichero se escribió y
    // que el banco programó y vació su cola. Sale con 0 si todo fue bien.
    Timer {
        id: verificador
        interval: 19500
        onTriggered: {
            var e = escenaMesa;
            var leido = Disco.leer(ventana.ficheroSeleccion);
            var problemas = [];
            if (leido === "" || JSON.parse(leido).reparto.A.sonidos.length !== 2) problemas.push("guardado");
            if (banco.pendientes() !== 0) problemas.push("cola de sonido sin vaciar");
            // que los golpes lleguen de verdad a las voces, sin errores de carga
            if (banco.reproducidos < 40) problemas.push("golpes " + banco.reproducidos);
            if (banco.errores !== 0 || banco.listos === 0) problemas.push("carga de voces");
            // la escena de la mesa: cada animación empezó, y el reparto ACABÓ (no se queda a medias)
            if (e.nRepartos !== 1) problemas.push("repartos " + e.nRepartos);
            if (e.nRepartosTerminados !== 1) problemas.push("reparto sin terminar");
            if (e.nComunitarias !== 3) problemas.push("comunitarias " + e.nComunitarias);
            if (e.nFichas !== 2) problemas.push("fichas " + e.nFichas);
            if (e.nCobros < 1) problemas.push("cobros " + e.nCobros);
            if (e.nFolds !== 1) problemas.push("folds " + e.nFolds);
            if (e.nAllIns !== 1) problemas.push("all-ins " + e.nAllIns);
            if (e.nGanadores !== 2) problemas.push("ganadores " + e.nGanadores);
            if (e.nEliminados !== 1) problemas.push("eliminados " + e.nEliminados);
            if (escenaMesaMesa().repartiendo) problemas.push("mesa repartiendo aún");
            // console.log no imprime en el build de release: el veredicto va a un fichero.
            Disco.escribir(ventana.dirSonidos + "/autoprueba.txt",
                           problemas.length === 0 ? "OK" : "FALLA: " + problemas.join("; "));
            Qt.exit(problemas.length === 0 ? 0 : 1);
        }
    }
    Timer {
        id: esperaDecision
        interval: 100
        repeat: true
        onTriggered: if (escenaMesa.estadoBarra === "decision") { esperaDecision.stop(); escenaMesa.seguirJugando(); }
    }
    Timer { id: pulsarBote; interval: 6500; onTriggered: escenaMesa.mesaInterna.botePulsado = 1 }
    // --evento: tras el reparto, dispara un evento suelto (para capturas).
    Timer {
        id: demoTimer
        interval: 1500
        onTriggered: {
            var e = escenaMesa;
            e.flop();
            e.quienApuesta = 2;
            var ev = ventana.demoEvento;
            if (ev.indexOf("sec") === 0) return;
            if (ev === "fold") e.retirar();
            else if (ev === "allin") e.allIn();
            else if (ev === "ganar") e.gana(true);
            else if (ev === "perder") e.gana(false);
            else if (ev === "eliminado") e.eliminar();
        }
    }
    // --autoprueba-showdown: recorre las tres secuencias enteras a cuádruple velocidad y
    // comprueba, en cada una, que llega a la fase de decisión, que las manos reveladas son las
    // esperadas y que al "seguir jugando" la mesa vuelve limpia. Usa la selección de sonidos real
    // (solo lectura) y exige que los golpes lleguen a las voces sin errores.
    property var _problemasSd: []
    property int _pasoSd: 0
    function correrAutopruebaShowdown() {
        pestanas.currentIndex = 1;
        escenaMesa.velocidad = 4.0;
        pasoSd.start();
    }
    function _revisarSd(nombre, cond, detalle) { if (!cond) ventana._problemasSd.push(nombre + ": " + detalle); }
    Timer {
        id: pasoSd
        interval: 400
        repeat: true
        onTriggered: {
            var e = escenaMesa, m = e.mesaInterna;
            var v = ventana;
            // Cada secuencia: 0/1/2 = arrancar; 10/11/12 = esperar a la decisión y comprobar.
            if (v._pasoSd === 0) { e.correrSecuencia(1); v._pasoSd = 10; return; }
            if (v._pasoSd === 1) { e.correrSecuencia(2); v._pasoSd = 11; return; }
            if (v._pasoSd === 2) { e.correrSecuencia(3); v._pasoSd = 12; return; }
            if (v._pasoSd >= 10 && v._pasoSd <= 12) {
                if (e.secuenciaEnCurso || e.estadoBarra !== "decision") return;
                var n = v._pasoSd - 9;
                if (n === 1) {
                    v._revisarSd("sec1", Object.keys(m.muestras).length === 5, "manos reveladas " + Object.keys(m.muestras).length + " (esperadas 5: 4 obligatorias + Ana)");
                    v._revisarSd("sec1", m.mejoresGanadora.length === 5, "mano ganadora resaltada " + m.mejoresGanadora.length);
                } else if (n === 2) {
                    v._revisarSd("sec2", Object.keys(m.muestras).length === 4, "manos reveladas " + Object.keys(m.muestras).length);
                    v._revisarSd("sec2", m.botesShowdown.length === 3 && m.botesShowdown[2].ganador === "Bot2", "botes/ganadores");
                    v._revisarSd("sec2", m.eliminados.length === 2, "eliminados " + m.eliminados.length);
                } else {
                    v._revisarSd("sec3", e.puedeMostrar, "no ofrece 'Mostrar cartas'");
                    e.mostrarMisCartas();
                    v._revisarSd("sec3", true, "");
                }
                e.seguirJugando();
                v._pasoSd = 20 + n;   // esperar a que la mesa quede limpia
                return;
            }
            if (v._pasoSd >= 21 && v._pasoSd <= 23) {
                if (e.estadoBarra !== "turno") return;
                v._revisarSd("limpia" + (v._pasoSd - 20), Object.keys(m.muestras).length === 0 && m.botesShowdown.length === 0, "quedan restos de showdown en la mesa");
                // el ciclo llegó hasta el reparto siguiente: marcadores rotados y aterrizados, cartas repartidas
                v._revisarSd("rotacion" + (v._pasoSd - 20), m.dealerMostrado === m.dealerNombre && m.sbMostrado === m.sbNombre && m.bbMostrado === m.bbNombre, "marcadores sin aterrizar");
                // Asignaciones esperadas: (1) 6 jugadores: cada marcador avanza un asiento;
                // (2) quedan dos (Ana y Bot4 eliminados): dealer = SB = Bot2, BB = Tú (heads-up);
                // (3) 6 jugadores: dealer Ana -> Bot2.
                var esperado = [null, ["Ana", "Bot2", "Bot3"], ["Bot2", "Bot2", "Tú"], ["Ana", "Bot2", "Bot3"]][v._pasoSd - 20];
                v._revisarSd("botones" + (v._pasoSd - 20), esperado !== null && esperado[0] === m.dealerNombre && esperado[1] === m.sbNombre && esperado[2] === m.bbNombre,
                             "D/SB/BB = " + m.dealerNombre + "/" + m.sbNombre + "/" + m.bbNombre);
                v._revisarSd("reparto" + (v._pasoSd - 20), e.nRepartos === (v._pasoSd - 20) && !m.repartiendo && !m.sinCartas, "reparto siguiente " + e.nRepartos);
                v._pasoSd = v._pasoSd - 20;   // siguiente secuencia (1 -> paso 1, 2 -> paso 2, 3 -> fin)
                if (v._pasoSd === 3) v._pasoSd = 99;
                return;
            }
            if (v._pasoSd === 99) {
                pasoSd.stop();
                v._revisarSd("sonido", banco.reproducidos > 20 && banco.errores === 0, "golpes " + banco.reproducidos + " errores " + banco.errores);
                v._revisarSd("eventos", e.nGanadores === 5 && e.nEliminados === 2, "ganadores " + e.nGanadores + " eliminados " + e.nEliminados);
                Disco.escribir(ventana.dirSonidos + "/autoprueba-showdown.txt",
                               v._problemasSd.length === 0 ? "OK" : "FALLA: " + v._problemasSd.join("; "));
                Qt.exit(v._problemasSd.length === 0 ? 0 : 1);
            }
        }
    }
    function escenaMesaMesa() { return escenaMesa.mesaInterna; }
    // Guion de la autoprueba: guarda una selección, dispara los eventos de sonido
    // sueltos y recorre la escena de la mesa (reparto, flop, turn, river, apuesta, cobro).
    function correrAutoprueba() {
        var a = ventana.candidatos.filter(function(c) { return c.grupo === "cartas"; }).slice(0, 2);
        var b = ventana.candidatos.filter(function(c) { return c.grupo === "impactos"; }).slice(0, 1);
        var f = ventana.candidatos.filter(function(c) { return c.grupo === "fichas"; }).slice(0, 2);
        var nombres = function(l) { return l.map(function(c) { return c.nombre; }); };
        ventana.poner("reparto", "A", { sonidos: nombres(a), n: 12, gap: 40 });
        ventana.poner("flop", "A", { sonidos: nombres(a), n: 3, gap: 100 });
        ventana.poner("comunitaria", "A", { sonidos: nombres(a) });
        ventana.poner("fichas", "A", { sonidos: nombres(f), n: 12, gap: 50 });
        ventana.poner("cobro", "A", { sonidos: nombres(f), n: 12, gap: 50 });
        ventana.poner("fold", "A", { sonidos: nombres(a) });
        ventana.poner("ganar", "A", { sonidos: nombres(b) });
        ventana.poner("perder", "A", { sonidos: nombres(b) });
        ventana.poner("eliminado", "A", { sonidos: nombres(b) });
        ventana.poner("allin", "A", { sonidos: nombres(a) });
        ventana.poner("allin", "B", { sonidos: nombres(b), retraso: 90 });
        ventana.guardar();
        ventana.probar("allin");
        // Adaptado a una escena real: 5 cartas en 400 ms -> 5 golpes más.
        banco.programar(ventana.config.reparto, { n: 5, duracion: 400 });
        pestanas.currentIndex = 1;
        escenaMesa.velocidad = 2.0;   // acelerada: la prueba no debe tardar
        secuencia.start();
        verificador.start();
    }
    Timer {
        id: secuencia
        property int paso: 0
        interval: 1500
        repeat: true
        onTriggered: {
            var e = escenaMesa;
            [function() { e.nuevaMano(); }, function() { e.flop(); }, function() { e.turn(); },
             function() { e.river(); }, function() { e.apostar(); }, function() { e.cobrar(); },
             function() { e.quienApuesta = 2; e.retirar(); }, function() { e.quienApuesta = 3; e.allIn(); },
             function() { e.gana(true); }, function() { e.gana(false); },
             function() { e.quienApuesta = 4; e.eliminar(); }][paso]();
            paso++;
            if (paso >= 11) secuencia.stop();
        }
    }

    BancoSonidos {
        id: banco
        rutas: ventana.rutasUsadas
    }
    // Para escuchar un candidato suelto (una sola voz).
    SoundEffect { id: suelto }
    Connections {
        target: Qt.application
        function onAboutToQuit() {
            banco.liberar();
            suelto.stop();
            suelto.source = "";
            ventana.grupoActual = "";
        }
    }

    component Ajuste: RowLayout {
        id: aj
        property string texto
        property alias desde: sl.from
        property alias hasta: sl.to
        property real valor: 0
        property string unidad: ""
        signal cambiado(real v)
        Layout.fillWidth: true
        spacing: 8
        Label { text: aj.texto; color: Tema.colorTexto; font.pixelSize: 13; Layout.preferredWidth: 110 }
        Slider {
            id: sl
            Layout.fillWidth: true
            stepSize: 1
            value: aj.valor
            onMoved: aj.cambiado(value)
        }
        Label { text: Math.round(aj.valor) + aj.unidad; color: Tema.colorTextoTenue; font.pixelSize: 12; Layout.preferredWidth: 58 }
    }

    header: TabBar {
        id: pestanas
        currentIndex: ventana.pestanaInicial
        TabButton { text: "Sonidos (audición y mezcla)" }
        TabButton { text: "Mesa (animación + sonido)" }
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: pestanas.currentIndex

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 16

        // ── Izquierda: eventos y parámetros de la capa ───────────────────
        ColumnLayout {
            Layout.preferredWidth: 470
            Layout.fillHeight: true
            spacing: 5
            Repeater {
                model: ventana.eventos
                delegate: Rectangle {
                    id: filaEv
                    required property var modelData
                    readonly property bool activo: ventana.eventoActivo === modelData.id
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 6
                    color: activo ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04)
                    border.width: activo ? 2 : 1
                    border.color: activo ? Tema.colorAccent : Qt.rgba(1, 1, 1, 0.15)
                    MouseArea {
                        anchors.fill: parent
                        onClicked: ventana.eventoActivo = filaEv.modelData.id
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8
                        Label {
                            text: filaEv.modelData.texto
                            color: Tema.colorTexto
                            font.pixelSize: 14
                            font.bold: filaEv.activo
                            Layout.preferredWidth: 140
                        }
                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            color: Tema.colorTextoTenue
                            font.pixelSize: 11
                            text: "A:" + ventana.capa(filaEv.modelData.id, "A").sonidos.length
                                  + "  B:" + ventana.capa(filaEv.modelData.id, "B").sonidos.length
                        }
                        Button {
                            text: "Probar"
                            onClicked: ventana.probar(filaEv.modelData.id)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1, 1, 1, 0.2)
            }
            RowLayout {
                spacing: 8
                Label { text: "Capa (la ★ añade aquí):"; color: Tema.colorTextoTenue; font.pixelSize: 13 }
                Repeater {
                    model: ["A", "B"]
                    delegate: Button {
                        required property string modelData
                        text: "Capa " + modelData
                        highlighted: ventana.capaActiva === modelData
                        onClicked: ventana.capaActiva = modelData
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Tema.colorTexto
                font.pixelSize: 12
                text: ventana.capa(ventana.eventoActivo, ventana.capaActiva).sonidos.join(", ") || "(vacía)"
            }
            Ajuste {
                texto: "Golpes"; desde: 1; hasta: 16
                valor: ventana.capa(ventana.eventoActivo, ventana.capaActiva).n
                onCambiado: function(v) { ventana.poner(ventana.eventoActivo, ventana.capaActiva, { n: Math.round(v) }); }
            }
            Ajuste {
                texto: "Separación"; desde: 0; hasta: 300; unidad: " ms"
                valor: ventana.capa(ventana.eventoActivo, ventana.capaActiva).gap
                onCambiado: function(v) { ventana.poner(ventana.eventoActivo, ventana.capaActiva, { gap: Math.round(v) }); }
            }
            Ajuste {
                texto: "Azar (tiempo)"; desde: 0; hasta: 120; unidad: " ms"
                valor: ventana.capa(ventana.eventoActivo, ventana.capaActiva).jit
                onCambiado: function(v) { ventana.poner(ventana.eventoActivo, ventana.capaActiva, { jit: Math.round(v) }); }
            }
            Ajuste {
                texto: "Retraso capa"; desde: 0; hasta: 600; unidad: " ms"
                valor: ventana.capa(ventana.eventoActivo, ventana.capaActiva).retraso
                onCambiado: function(v) { ventana.poner(ventana.eventoActivo, ventana.capaActiva, { retraso: Math.round(v) }); }
            }
            Ajuste {
                texto: "Volumen"; desde: 0; hasta: 100; unidad: " %"
                valor: ventana.capa(ventana.eventoActivo, ventana.capaActiva).vol
                onCambiado: function(v) { ventana.poner(ventana.eventoActivo, ventana.capaActiva, { vol: Math.round(v) }); }
            }
            Ajuste {
                texto: "Azar (volumen)"; desde: 0; hasta: 60; unidad: " %"
                valor: ventana.capa(ventana.eventoActivo, ventana.capaActiva).volJit
                onCambiado: function(v) { ventana.poner(ventana.eventoActivo, ventana.capaActiva, { volJit: Math.round(v) }); }
            }
            Button {
                text: "Probar este evento"
                Layout.fillWidth: true
                onClicked: ventana.probar(ventana.eventoActivo)
            }
            Item { Layout.fillHeight: true }
            Button {
                text: "Guardar selección"
                Layout.fillWidth: true
                onClicked: ventana.guardar()
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: ventana.mensaje + "  [voces: " + banco.listos + " listas, " + banco.errores + " con error; golpes: " + banco.reproducidos + "]"
                color: ventana.mensaje.indexOf("ERROR") === 0 ? Tema.colorPeligro : Tema.colorTextoTenue
                font.pixelSize: 11
            }
        }

        // ── Derecha: candidatos por grupo ────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            Row {
                spacing: 8
                Repeater {
                    model: ventana.grupos
                    delegate: Button {
                        required property string modelData
                        text: modelData
                        highlighted: ventana.grupoActual === modelData
                        onClicked: ventana.grupoActual = modelData
                    }
                }
            }
            ListView {
                id: lista
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: ventana.candidatos.filter(function(c) { return c.grupo === ventana.grupoActual; })
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    id: filaCand
                    required property var modelData
                    width: lista.width - 12
                    height: 34
                    radius: 4
                    color: ventana.enCapa(modelData.nombre) ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.04)
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10
                        Button {
                            text: "▶"
                            Layout.preferredWidth: 44
                            onClicked: {
                                suelto.source = "file://" + filaCand.modelData.ruta;
                                suelto.play();
                            }
                        }
                        Label {
                            text: filaCand.modelData.nombre
                            color: Tema.colorTexto
                            Layout.fillWidth: true
                            font.pixelSize: 14
                        }
                        Label {
                            text: filaCand.modelData.dur.toFixed(2) + " s"
                            color: Tema.colorTextoTenue
                            font.pixelSize: 12
                        }
                        Button {
                            text: ventana.enCapa(filaCand.modelData.nombre) ? "★" : "☆"
                            Layout.preferredWidth: 44
                            onClicked: ventana.alternar(filaCand.modelData.nombre)
                        }
                    }
                }
            }
        }
    }

    EscenaMesa {
        id: escenaMesa
        Layout.fillWidth: true
        Layout.fillHeight: true
        banco: banco
        config: ventana.config
    }
    }
}
