// PaloIcono.qml — símbolo de palo de la baraja (♥♦♣♠) dibujado a mano con
// Canvas, NO como glifo de texto Unicode. EB Garamond (la única fuente que
// empaqueta el proyecto, ver assets/fonts/) no incluye esos caracteres, y
// depender de que el sistema operativo tenga OTRA fuente con esos glifos
// resultó no ser fiable entre plataformas (confirmado en real: varios
// usuarios sin ningún símbolo visible en las cartas). Dibujar la forma
// directamente garantiza que se vea igual en cualquier dispositivo, sin
// depender de ningún font instalado.
pragma ComponentBehavior: Bound
import QtQuick

Canvas {
    id: icono
    // Letra cruda del palo, igual que manda el servidor: H/D/C/S.
    property string letraPalo: "S"
    property color colorPalo: "black"

    onLetraPaloChanged: requestPaint()
    onColorPaloChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = icono.getContext("2d");
        ctx.reset();
        ctx.fillStyle = icono.colorPalo;
        var w = icono.width;
        var h = icono.height;
        if (w <= 0 || h <= 0) return;

        if (icono.letraPalo === "D") {
            // Diamante: rombo con lados ligeramente curvados hacia fuera
            // (en vez de rectos) para que se vea más como una gema pulida
            // que como un cuadrado girado.
            ctx.beginPath();
            ctx.moveTo(w * 0.5, 0);
            ctx.quadraticCurveTo(w * 0.62, h * 0.32, w * 0.86, h * 0.5);
            ctx.quadraticCurveTo(w * 0.62, h * 0.68, w * 0.5, h);
            ctx.quadraticCurveTo(w * 0.38, h * 0.68, w * 0.14, h * 0.5);
            ctx.quadraticCurveTo(w * 0.38, h * 0.32, w * 0.5, 0);
            ctx.closePath();
            ctx.fill();
        } else if (icono.letraPalo === "H") {
            // Corazón: dos lóbulos redondeados arriba, punta abajo.
            ctx.beginPath();
            ctx.moveTo(w * 0.5, h);
            ctx.bezierCurveTo(w * 0.15, h * 0.75, 0, h * 0.5, 0, h * 0.3);
            ctx.bezierCurveTo(0, h * 0.05, w * 0.3, -h * 0.05, w * 0.5, h * 0.2);
            ctx.bezierCurveTo(w * 0.7, -h * 0.05, w, h * 0.05, w, h * 0.3);
            ctx.bezierCurveTo(w, h * 0.5, w * 0.85, h * 0.75, w * 0.5, h);
            ctx.closePath();
            ctx.fill();
        } else if (icono.letraPalo === "S") {
            // Pica: parecido al corazón pero con las puntas de las alas
            // más marcadas, y un tallo triangular en la base.
            ctx.beginPath();
            ctx.moveTo(w * 0.5, 0);
            ctx.bezierCurveTo(w * 0.85, h * 0.35, w, h * 0.5, w, h * 0.68);
            ctx.bezierCurveTo(w, h * 0.9, w * 0.75, h * 0.95, w * 0.58, h * 0.8);
            ctx.bezierCurveTo(w * 0.62, h * 0.92, w * 0.68, h, w * 0.78, h);
            ctx.lineTo(w * 0.22, h);
            ctx.bezierCurveTo(w * 0.32, h, w * 0.38, h * 0.92, w * 0.42, h * 0.8);
            ctx.bezierCurveTo(w * 0.25, h * 0.95, 0, h * 0.9, 0, h * 0.68);
            ctx.bezierCurveTo(0, h * 0.5, w * 0.15, h * 0.35, w * 0.5, 0);
            ctx.closePath();
            ctx.fill();
        } else if (icono.letraPalo === "C") {
            // Trébol: tres círculos superpuestos + el mismo tallo de la
            // pica -- fill() con la regla de relleno por defecto (nonzero)
            // une los cuatro subtrazados en una sola forma sólida.
            var r = w * 0.22;
            ctx.beginPath();
            ctx.arc(w * 0.5, h * 0.28, r, 0, Math.PI * 2);
            ctx.arc(w * 0.26, h * 0.55, r, 0, Math.PI * 2);
            ctx.arc(w * 0.74, h * 0.55, r, 0, Math.PI * 2);
            ctx.moveTo(w * 0.58, h * 0.75);
            ctx.bezierCurveTo(w * 0.62, h * 0.88, w * 0.68, h * 0.97, w * 0.78, h);
            ctx.lineTo(w * 0.22, h);
            ctx.bezierCurveTo(w * 0.32, h * 0.97, w * 0.38, h * 0.88, w * 0.42, h * 0.75);
            ctx.closePath();
            ctx.fill();
        }
        // Cualquier otro valor (no debería pasar nunca en operación normal,
        // el servidor solo manda H/D/C/S): canvas en blanco a propósito, en
        // vez de dibujar un palo cualquiera que sugeriría un dato válido
        // que no lo es.
    }
}
