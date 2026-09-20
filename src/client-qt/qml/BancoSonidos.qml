// BancoSonidos.qml -- reproductor de efectos de la mesa, polifónico y con capas.
//
// Un efecto suena "cutre" cuando es siempre el mismo clip y termina antes de que
// empiece el siguiente. Aquí un EVENTO son varias CAPAS, y cada capa dispara N
// golpes escalonados (gap) con un poco de azar en el momento (jit) y en el volumen
// (volJit), eligiendo cada vez una variante distinta del lote. Los golpes se
// SOLAPAN: cada sonido tiene 4 voces precargadas que se turnan.
//
//   programar({ A: { sonidos: ["card-slide-1", ...], retraso: 0, n: 8, gap: 90,
//                    jit: 25, vol: 100, volJit: 20 },
//               B: { ... } })
//
// Reutilizable tal cual en el cliente (es solo QML + QtMultimedia). Recuerda
// llamar a liberar() en onAboutToQuit (crash de PipeWire al cerrar, ver Main.qml).
pragma ComponentBehavior: Bound
import QtQuick
import QtMultimedia

Item {
    id: banco

    /// nombre -> URL del WAV. Solo se precargan los que figuren aquí.
    property var rutas: ({})
    /// Volumen general 0..1 (y "activo" a false = mudo total).
    property real volumen: 1.0
    property bool activo: true
    property bool liberado: false
    readonly property int voces: 4
    /// Pistas de audio que pueden sonar a la vez. Android limita las simultáneas y, pasado el límite,
    /// los sonidos nuevos se pierden en silencio: en el móvil las ráfagas de fichas y cartas se comían
    /// los jingles (retirada, ganar, perder, all-in). Por encima del límite se descartan los golpes
    /// sueltos de ráfaga -- imperceptible -- y nunca los prioritarios. En escritorio no hay límite real.
    property int maxSimultaneos: 32
    /// Pistas que se reservan para los sonidos prioritarios (jingles) dentro de maxSimultaneos.
    property int reservaPrioritarios: 4
    /// Cuántas voces suenan ahora mismo.
    property int activos: 0
    /// Golpes descartados por falta de pista o de voz libre (diagnóstico).
    property int descartados: 0
    function _prioritario(nombre) { return nombre.indexOf("jingles_") === 0; }

    /// Voces cargadas / con error (diagnóstico: si `listos` es 0 no puede sonar nada).
    property int listos: 0
    property int errores: 0
    /// Golpes que han llegado a una voz de verdad (las pruebas exigen > 0).
    property int reproducidos: 0
    property var _nombres: []
    property string _clave: ""
    // Solo se reconstruyen las voces si cambia el CONJUNTO de sonidos (no en cada
    // ajuste de la selección): recrearlas obliga a recargar los WAV y un "probar"
    // inmediato caería en silencio.
    onRutasChanged: {
        var k = Object.keys(banco.rutas).sort().join("|");
        if (k === banco._clave) return;
        banco._clave = k;
        banco._nombres = Object.keys(banco.rutas);
    }
    property var _tocadores: ({})
    property var _cola: []
    property string _ultimo: ""

    function sonar(nombre, vol) {
        if (!banco.activo || banco.liberado) return;
        var t = banco._tocadores[nombre];
        if (!t) return;
        var prio = banco._prioritario(nombre);
        var tope = prio ? banco.maxSimultaneos : banco.maxSimultaneos - banco.reservaPrioritarios;
        if (banco.activos >= tope) { banco.descartados++; return; }
        t.tocar(Math.max(0, Math.min(1, vol * banco.volumen)), prio);
    }

    function _elegir(lista) {
        if (lista.length === 1) return lista[0];
        var n;
        do { n = lista[Math.floor(Math.random() * lista.length)]; } while (n === banco._ultimo);
        banco._ultimo = n;
        return n;
    }

    // opciones (todas opcionales) para adaptar el evento a la escena real:
    //   n         nº de golpes de las capas "en ráfaga" (n > 1), p. ej. las cartas
    //             que se reparten de verdad (12 con 6 jugadores)
    //   factor    0..1: escala el nº de golpes de cada capa (n = round(n * factor),
    //             mínimo 1). Para "cuántas fichas": una apuesta pequeña suena a pocas
    //             fichas y un all-in a muchas. Si se da "n", manda "n".
    //   duracion  ms en que debe caber esa ráfaga; recalcula la separación. La
    //             animación manda: el sonido se estira o se comprime para acompañarla.
    //   inicio    ms de espera antes del primer golpe (p. ej. lo que tarda en llegar
    //             la ficha), sumados al retraso propio de cada capa.
    //   vol       multiplicador de volumen 0..1 (una apuesta grande suena más fuerte).
    function programar(cfg, opciones) {
        if (!cfg || !banco.activo || banco.liberado) return;
        var ahora = Date.now();
        var op = opciones || {};
        var capas = Array.isArray(cfg) ? cfg : Object.keys(cfg).map(function(k) { return cfg[k]; });
        var cola = banco._cola.slice();
        capas.forEach(function(c) {
            if (!c || !c.sonidos || c.sonidos.length === 0) return;
            var n = c.n || 1;
            var gap = c.gap || 0;
            if (n > 1) {
                if (op.n) n = op.n;
                else if (op.factor !== undefined) n = Math.max(1, Math.round(n * op.factor));
                if (op.duracion && n > 1) gap = op.duracion / (n - 1);
            }
            for (var i = 0; i < n; i++) {
                var t = ahora + (op.inicio || 0) + (c.retraso || 0) + i * gap + (Math.random() * 2 - 1) * (c.jit || 0);
                var v = ((c.vol === undefined ? 100 : c.vol) / 100) * (1 - Math.random() * (c.volJit || 0) / 100)
                        * (op.vol === undefined ? 1 : op.vol);
                cola.push({ t: Math.max(ahora, t), nombre: banco._elegir(c.sonidos), vol: v });
            }
        });
        cola.sort(function(a, b) { return a.t - b.t; });
        banco._cola = cola;
        reloj.running = cola.length > 0;
    }

    /// Golpes programados que aún no han sonado (para las pruebas).
    function pendientes() { return banco._cola.length; }

    function parar() {
        banco._cola = [];
        reloj.running = false;
    }

    /// Antes de cerrar la app: suelta los streams de audio con el bucle vivo.
    function liberar() {
        banco.parar();
        banco.liberado = true;
    }

    Timer {
        id: reloj
        interval: 8
        repeat: true
        onTriggered: {
            var ahora = Date.now();
            var cola = banco._cola;
            while (cola.length > 0 && cola[0].t <= ahora) {
                var g = cola.shift();
                banco.sonar(g.nombre, g.vol);
            }
            banco._cola = cola;
            if (cola.length === 0) reloj.running = false;
        }
    }

    Repeater {
        model: banco.liberado ? [] : banco._nombres
        delegate: Item {
            id: tocador
            required property string modelData
            property int sig: 0
            // Elige una voz LIBRE (que no esté sonando): reutilizar una que suena la corta en seco
            // (era el "se cortan abruptamente" de las ráfagas densas). Sin voz libre, un golpe suelto
            // se descarta y uno prioritario roba la más antigua.
            function tocar(vol, prio) {
                var ahora = Date.now();
                var v = null;
                for (var k = 0; k < banco.voces; k++) {
                    var c = voz.itemAt((tocador.sig + k) % banco.voces);
                    // "playing" tarda un instante en subir tras play(): también se mira cuándo se usó.
                    if (c && !c.efecto.playing && ahora - c.usadoEn > 40) {
                        v = c;
                        tocador.sig = (tocador.sig + k + 1) % banco.voces;
                        break;
                    }
                }
                if (!v) {
                    if (!prio) { banco.descartados++; return; }
                    v = voz.itemAt(tocador.sig);
                    tocador.sig = (tocador.sig + 1) % banco.voces;
                    if (!v) return;
                }
                v.usadoEn = ahora;
                v.efecto.volume = vol;
                v.efecto.play();
                banco.reproducidos++;
            }
            Component.onCompleted: banco._tocadores[tocador.modelData] = tocador
            Component.onDestruction: delete banco._tocadores[tocador.modelData]
            Repeater {
                id: voz
                model: banco.voces
                // Envuelto en un Item: Repeater.itemAt() solo devuelve Items, y con un
                // SoundEffect pelado devolvía null y no sonaba nada.
                delegate: Item {
                    property alias efecto: se
                    property double usadoEn: 0
                    SoundEffect {
                        id: se
                        source: banco.rutas[tocador.modelData] || ""
                        onPlayingChanged: banco.activos = Math.max(0, banco.activos + (playing ? 1 : -1))
                        onStatusChanged: {
                            if (status === SoundEffect.Ready) banco.listos++;
                            else if (status === SoundEffect.Error) banco.errores++;
                        }
                    }
                }
            }
        }
    }
}
