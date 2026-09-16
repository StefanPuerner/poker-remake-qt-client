// IconoXP.qml — icono de la Experiencia (XP) dibujado a mano con Canvas,
// mismo criterio que IconoTrebol.qml: silueta monocroma recoloreable
// contra el tema activo (colorXP), sin depender de ningún glifo de
// fuente. Un rayo, símbolo habitual de "energía"/progreso -- distingue
// de un vistazo la XP de los Tréboles (moneda) en cualquier lista de
// recompensas (Torneos > Solitario, y donde haga falta en el futuro).
//
// Geometría en fracciones de [0,1] -- igual que IconoTrebol.qml, ningún
// punto cae fuera del lienzo a ningún tamaño de render.
pragma ComponentBehavior: Bound
import QtQuick

Canvas {
    id: icono
    property color colorXP: "black"

    onColorXPChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = icono.getContext("2d");
        ctx.reset();
        var w = icono.width;
        var h = icono.height;
        if (w <= 0 || h <= 0) return;

        ctx.fillStyle = icono.colorXP;

        // Rayo de seis puntos, mismo lenguaje visual que cualquier icono
        // de "energía" -- trazado a mano, coordenadas verificadas dentro
        // de [0,1] en ambos ejes.
        ctx.beginPath();
        ctx.moveTo(w * 0.62, h * 0.00);
        ctx.lineTo(w * 0.22, h * 0.52);
        ctx.lineTo(w * 0.45, h * 0.52);
        ctx.lineTo(w * 0.38, h * 1.00);
        ctx.lineTo(w * 0.80, h * 0.42);
        ctx.lineTo(w * 0.55, h * 0.42);
        ctx.closePath();
        ctx.fill();
    }
}
