// BancoMezclas.qml -- sonidos de la mesa para el MÓVIL: una pista por evento, ya mezclada.
//
// El banco del escritorio (BancoSonidos.qml) lanza cada golpe de un evento como un SoundEffect
// aparte (92 objetos, una pista de audio nueva por golpe). En Android eso agota las pistas de audio
// del proceso (los sonidos más tardíos no suenan), bloquea el hilo de la interfaz a ráfagas
// (tirones) y corta golpes. Aquí cada evento ya viene mezclado en UN wav por
// scripts/generar_mezclas_sonido.py (mismas capas, golpes y azar que el banco): un solo play() por
// evento y ~15 objetos en total. mezclas.json dice qué mezcla usar según el evento y su tamaño
// (nº de cartas, nº de fichas...).
//
//   configurar(json)                   carga mezclas.json y crea las voces
//   reproducir("fichas", { fichas: 4, inicio: 460, vol: 0.8 })
//
// Recuerda llamar a liberar() en onAboutToQuit (crash de PipeWire al cerrar, ver Main.qml).
pragma ComponentBehavior: Bound
import QtQuick
import QtMultimedia

Item {
    id: banco

    /// URL base de las mezclas (termina en "/").
    property string carpeta: ""
    /// Contenido de mezclas.json.
    property var config: ({})
    /// Volumen general 0..1 (y "activo" a false = mudo total).
    property real volumen: 1.0
    property bool activo: true
    property bool liberado: false

    /// Diagnóstico (Ajustes lo enseña): voces cargadas, con error, golpes reproducidos y perdidos.
    property int listos: 0
    property int errores: 0
    property int reproducidos: 0
    property int descartados: 0

    property var _nombres: []
    property var _voces: ({})
    property var _cola: []

    function configurar(cfg) {
        banco.config = cfg;
        banco._nombres = Object.keys(cfg.mezclas || {});
    }

    // Qué mezcla suena para un evento y unas opciones: la primera variante cuyo "hasta" cubre el
    // valor (n golpes, o fichas = factor * 8); sin valor, la última (la más grande).
    function elegirMezcla(evento, op) {
        var def = banco.config.eventos ? banco.config.eventos[evento] : null;
        if (!def || !def.variantes || def.variantes.length === 0) return "";
        var valor;
        if (def.clave === "n") valor = op.n;
        else if (def.clave === "fichas") valor = op.factor !== undefined ? Math.round(op.factor * 8) : undefined;
        if (valor === undefined) return def.variantes[def.variantes.length - 1].mezcla;
        for (var i = 0; i < def.variantes.length; i++)
            if (valor <= def.variantes[i].hasta) return def.variantes[i].mezcla;
        return def.variantes[def.variantes.length - 1].mezcla;
    }

    // op (todas opcionales): n / factor (tamaño del evento), inicio (ms de espera, p. ej. lo que tarda
    // en llegar la ficha), vol (multiplicador 0..1). "duracion" ya no hace falta: viene mezclada.
    function reproducir(evento, opciones) {
        if (!banco.activo || banco.liberado) return;
        var op = opciones || {};
        var mezcla = banco.elegirMezcla(evento, op);
        if (mezcla === "") return;
        var cola = banco._cola.slice();
        cola.push({ t: Date.now() + (op.inicio || 0), mezcla: mezcla, vol: op.vol === undefined ? 1 : op.vol });
        cola.sort(function(a, b) { return a.t - b.t; });
        banco._cola = cola;
        reloj.running = true;
    }

    function sonarAhora(mezcla, vol) {
        var v = banco._voces[mezcla];
        if (!v) { banco.descartados++; return; }
        v.volume = Math.max(0, Math.min(1, vol * banco.volumen));
        v.play();
        banco.reproducidos++;
    }

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
        interval: 15
        repeat: true
        onTriggered: {
            var ahora = Date.now();
            var cola = banco._cola;
            while (cola.length > 0 && cola[0].t <= ahora) {
                var g = cola.shift();
                banco.sonarAhora(g.mezcla, g.vol);
            }
            banco._cola = cola;
            if (cola.length === 0) reloj.running = false;
        }
    }

    Repeater {
        model: banco.liberado ? [] : banco._nombres
        delegate: Item {
            id: voz
            required property string modelData
            SoundEffect {
                id: efecto
                source: banco.carpeta + voz.modelData + ".wav"
                onStatusChanged: {
                    if (status === SoundEffect.Ready) banco.listos++;
                    else if (status === SoundEffect.Error) banco.errores++;
                }
            }
            Component.onCompleted: banco._voces[voz.modelData] = efecto
            Component.onDestruction: delete banco._voces[voz.modelData]
        }
    }
}
