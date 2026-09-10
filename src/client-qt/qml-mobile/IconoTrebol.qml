// IconoTrebol.qml — icono de la moneda "Tréboles" dibujado a mano con
// Canvas, mismo criterio que IconoFicha.qml/PaloIcono.qml: silueta
// monocroma recoloreable contra el tema activo (colorTrebol), sin
// depender de ningún glifo de fuente. Se coloca DETRÁS de cualquier cifra
// de Tréboles en la UI (precio en Tienda, contador de BarraSuperior...).
//
// Antes se reutilizaba por error IconoFicha.qml (el disco de ficha de
// póker) para esto -- confunde dos monedas distintas del juego: fichas
// (saldo/bote DENTRO de una mano, siempre representado con IconoFicha) y
// Tréboles (moneda premium de la tienda, fuera de cualquier mano). Este
// icono es su propio símbolo: tres lóbulos (hojas) + un tallo corto,
// silueta de trébol de toda la vida -- inconfundible con una ficha.
pragma ComponentBehavior: Bound
import QtQuick

Canvas {
    id: icono
    property color colorTrebol: "black"

    onColorTrebolChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = icono.getContext("2d");
        ctx.reset();
        var w = icono.width;
        var h = icono.height;
        if (w <= 0 || h <= 0) return;

        ctx.fillStyle = icono.colorTrebol;

        var cx = w / 2;
        // El tallo ocupa la parte de abajo -- las hojas se centran algo
        // por encima del centro geométrico para dejarle sitio.
        //
        // Geometría verificada a mano para que NADA se salga del lienzo
        // (bug real: con cyHojas=0.42h/rHoja=0.28w/dist=rHoja*0.85, el
        // borde superior de la hoja de arriba caía en y=-0.098h -- fuera
        // del Canvas, así que se recortaba en seco. Canvas no hace clip
        // "suave", cualquier trazo con coordenada negativa simplemente no
        // se pinta esa parte). Con estos valores el punto más ajustado
        // (borde superior de la hoja de arriba) queda en 0.07h — margen
        // de sobra a cualquier tamaño de render.
        var cyHojas = h * 0.44;
        var rHoja = w * 0.20;

        // Tres lóbulos superpuestos (arriba, abajo-izq, abajo-der),
        // dispuestos en triángulo -- la silueta clásica del trébol de 3
        // hojas. Se pintan como un único path (los tres arcos) para que
        // las zonas de solape no dupliquen alfa al rellenar de una vez.
        var dist = rHoja * 0.85;
        ctx.beginPath();
        ctx.arc(cx, cyHojas - dist, rHoja, 0, Math.PI * 2);
        ctx.arc(cx - dist * 0.87, cyHojas + dist * 0.5, rHoja, 0, Math.PI * 2);
        ctx.arc(cx + dist * 0.87, cyHojas + dist * 0.5, rHoja, 0, Math.PI * 2);
        ctx.fill();

        // Tallo: trapecio corto que baja desde el centro de las hojas
        // hasta la base del icono.
        var anchoTalloArriba = w * 0.16;
        var anchoTalloAbajo = w * 0.1;
        var yTalloArriba = cyHojas + rHoja * 0.35;
        var yTalloAbajo = h * 0.90;
        ctx.beginPath();
        ctx.moveTo(cx - anchoTalloArriba / 2, yTalloArriba);
        ctx.lineTo(cx + anchoTalloArriba / 2, yTalloArriba);
        ctx.lineTo(cx + anchoTalloAbajo / 2, yTalloAbajo);
        ctx.lineTo(cx - anchoTalloAbajo / 2, yTalloAbajo);
        ctx.closePath();
        ctx.fill();
    }
}
