// CajaTitulo.qml (móvil) — mismo rol y diseño que el de escritorio (ver
// src/client-qt/qml/CajaTitulo.qml), del que este fichero es un PORT
// mecánico 2026-09-01 (Fase M0 del port de progresión a móvil, ver
// memoria qt_mobile_progression_port_plan) -- no existía aquí todavía.
// Sin diferencias de contenido con el de escritorio (no depende de
// ningún qrc ni de otro tipo del módulo) -- si tocas el diseño, revisa
// también el de escritorio.
//
// Reutiliza DELIBERADAMENTE el mismo lenguaje visual que la etiqueta de
// rareza de un logro (píldora de borde fino, sin relleno sólido, texto
// del mismo color que el borde) en vez de inventar un tratamiento nuevo
// -- un título ES la recompensa de un logro (o, comprado, el pariente
// "sin rareza" de esa misma familia). Mismos 3 colores de rareza que
// Main.qml::colorRareza() -- pasados desde fuera en vez de duplicar esa
// función aquí, un solo sitio con la tabla de colores.
//
// SIEMPRE visible, aunque no haya título -- sin título, muestra un
// estado vacío discreto ("Sin título", borde atenuado en vez de por
// rareza) en vez de ocultarse del todo, para que la caja EXISTA siempre
// como sitio reconocible.
//
// A PROPÓSITO sin ningún "tamano"/parámetro de escala propio -- solo
// Tema.escala (el mismo global de toda la app), NUNCA proporcional al
// tamano del Avatar de al lado: si el título escalara con un avatar
// pequeño (p. ej. el del asiento en mesa), dejaría de leerse. NO añadir
// un binding que ate el tamaño de fuente de aquí al de un Avatar
// concreto.
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: caja
    required property string nombre     // "" = sin título (la caja se ve igual, atenuada)
    required property color colorTier   // Main.qml::colorRareza(rareza) -- ignorado si nombre === ""

    readonly property bool tieneTitulo: caja.nombre !== ""
    readonly property string textoMostrado: caja.tieneTitulo ? caja.nombre : "Sin título"
    readonly property color colorMostrado: caja.tieneTitulo ? caja.colorTier : Tema.colorTextoMuyTenue

    width: textoTitulo.implicitWidth + 22 * Tema.escala
    height: textoTitulo.implicitHeight + 9 * Tema.escala

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: 1.2
        border.color: caja.colorMostrado
        opacity: caja.tieneTitulo ? 1.0 : 0.55
    }
    Text {
        id: textoTitulo
        anchors.centerIn: parent
        text: caja.textoMostrado
        color: caja.colorMostrado
        font.family: Tema.fuenteElegante
        font.italic: !caja.tieneTitulo
        font.pixelSize: 11 * Tema.escala
        font.letterSpacing: 0.4
    }
}
