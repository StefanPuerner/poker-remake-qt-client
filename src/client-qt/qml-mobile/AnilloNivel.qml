// AnilloNivel.qml (móvil) — mismo rol y contenido que el de escritorio
// (ver src/client-qt/qml/AnilloNivel.qml), del que este fichero es un
// PORT directo 2026-09-01 (Fase M1 del port de progresión a móvil, ver
// memoria qt_mobile_progression_port_plan) -- no existía aquí todavía.
// Sin diferencias de contenido (no depende de ningún qrc ni de otro
// tipo del módulo) -- si tocas el diseño, revisa también el de
// escritorio.
//
// Anillo circular de progreso de nivel (XP), dibujado a mano con
// Canvas (arco relleno según fraccion), mismo criterio que
// IconoFicha.qml/PaloIcono.qml: sin depender de ningún componente de
// gráficos externo. "Nivel N" se superpone como Text normal encima del
// Canvas -- así usa EB Garamond como el resto de la app en vez de
// tener que dibujar texto a mano.
pragma ComponentBehavior: Bound
import QtQuick

Canvas {
    id: anillo
    property int nivel: 1
    property real fraccion: 0  // 0..1, progreso hacia el siguiente nivel
    property real grosor: Math.max(4, width * 0.11)

    onFraccionChanged: requestPaint()
    onNivelChanged: requestPaint()
    onGrosorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = anillo.getContext("2d");
        ctx.reset();
        var w = anillo.width;
        var h = anillo.height;
        if (w <= 0 || h <= 0) return;

        var cx = w / 2;
        var cy = h / 2;
        var r = Math.min(w, h) / 2 - anillo.grosor / 2;
        var inicio = -Math.PI / 2;  // arranca arriba, como las 12 en punto.

        // Pista de fondo -- círculo completo, tenue.
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.lineWidth = anillo.grosor;
        ctx.strokeStyle = "rgba(255,255,255,0.08)";
        ctx.stroke();

        // Relleno -- arco proporcional a la fracción, sentido horario.
        var frac = Math.max(0, Math.min(1, anillo.fraccion));
        if (frac > 0.002) {
            ctx.beginPath();
            ctx.arc(cx, cy, r, inicio, inicio + Math.PI * 2 * frac);
            ctx.lineWidth = anillo.grosor;
            ctx.lineCap = "round";
            ctx.strokeStyle = Tema.colorAccent;
            ctx.stroke();
        }
    }

    Text {
        anchors.centerIn: parent
        text: "Nivel " + anillo.nivel
        color: Tema.colorTexto
        font.bold: true
        font.family: Tema.fuenteElegante
        font.pixelSize: Math.max(9, parent.width * 0.15)
    }
}
