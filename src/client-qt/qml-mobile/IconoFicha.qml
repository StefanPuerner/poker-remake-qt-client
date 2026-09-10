// IconoFicha.qml — icono de ficha de póker dibujado a mano con Canvas,
// mismo criterio que PaloIcono.qml: silueta monocroma recoloreable contra
// el tema activo (colorFicha), sin depender de ningún glifo de fuente. Se
// coloca DETRÁS de cualquier cifra de dinero en la UI (bote, saldo/stack,
// "mayor bote ganado"...), sustituyendo a palabras como "fichas" ("200
// [ficha]" en vez de "Bote: 200").
//
// Disco relleno + anillo interior hueco + muescas rectangulares recortadas
// en el canto (el patrón clásico de canto de ficha de casino). Las marcas
// se RECORTAN (destination-out) en vez de pintarse con un segundo color —
// así el icono sigue siendo monocromo de verdad, recoloreable con una sola
// propiedad igual que PaloIcono, en vez de necesitar un color fijo que no
// encajaría con las 5 paletas de Tema.
pragma ComponentBehavior: Bound
import QtQuick

Canvas {
    id: icono
    property color colorFicha: "black"

    onColorFichaChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = icono.getContext("2d");
        ctx.reset();
        var w = icono.width;
        var h = icono.height;
        if (w <= 0 || h <= 0) return;

        var cx = w / 2;
        var cy = h / 2;
        var r = Math.min(w, h) / 2;

        // Disco base.
        ctx.fillStyle = icono.colorFicha;
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.fill();

        // A partir de aquí se recorta en vez de pintar encima.
        ctx.globalCompositeOperation = "destination-out";

        // Anillo interior hueco, cerca del borde (contorno decorativo
        // grabado, look de ficha real).
        ctx.lineWidth = r * 0.14;
        ctx.beginPath();
        ctx.arc(cx, cy, r * 0.7, 0, Math.PI * 2);
        ctx.stroke();

        // Muescas de canto: 8 marcas rectangulares equidistantes, cada
        // una a caballo del borde exterior.
        var muescas = 8;
        var anchoMuesca = r * 0.32;
        var altoMuesca = r * 0.34;
        for (var i = 0; i < muescas; i++) {
            ctx.save();
            ctx.translate(cx, cy);
            ctx.rotate((Math.PI * 2 / muescas) * i);
            ctx.fillRect(r - altoMuesca * 0.55, -anchoMuesca / 2, altoMuesca, anchoMuesca);
            ctx.restore();
        }

        ctx.globalCompositeOperation = "source-over";
    }
}
