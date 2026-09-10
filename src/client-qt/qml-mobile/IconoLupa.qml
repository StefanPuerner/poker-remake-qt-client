// IconoLupa.qml (móvil) — la lupa de los campos de búsqueda, dibujada a
// mano (un círculo y un mango) en vez de con un glifo: "🔍" no está ni en
// EBGaramond ni en el font de sistema de este build de Android, y el
// carácter "⌕" queda descentrado y distinto en cada tipografía.
//
// Extraída a componente el 2026-09-09. Antes se copiaba y pegaba en cada
// sitio, y las dos copias tenían el mismo defecto: el cristal se anclaba
// a la esquina superior izquierda y el mango a la inferior derecha del
// hueco, así que el dibujo no llenaba su caja y, al centrar la caja, la
// lupa salía descentrada respecto del botón (reportado con captura: "el
// símbolo de búsqueda está mal colocado con su botón").
//
// Ahora el mango cuelga del CRISTAL, no del hueco, así que la figura
// entera ocupa su caja de verdad y centrar la caja centra la lupa.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Item {
    id: lupa
    property color color: Tema.colorAccent
    /// Grosor del trazo; por defecto proporcional al tamaño.
    property real grosor: Math.max(1.4, lupa.width * 0.105)

    implicitWidth: 18 * Tema.escala
    implicitHeight: 18 * Tema.escala

    // Los números están elegidos para que el dibujo ocupe su caja EXACTA,
    // de (0,0) a (ancho,alto): el cristal llega hasta 0.76 y el mango
    // arranca en 0.84 de eso (0.64) y avanza 0.5 en diagonal, o sea
    // 0.5/raíz(2) = 0.354 por eje, hasta 0.99. Si el dibujo no llena su
    // caja, centrar la caja NO centra la lupa -- que es justo lo que
    // pasaba antes (reportado dos veces: "el símbolo de búsqueda está mal
    // colocado con su botón").
    Rectangle {
        id: cristal
        width: lupa.width * 0.76
        height: width
        radius: width / 2
        color: "transparent"
        border.width: lupa.grosor
        border.color: lupa.color
    }

    Rectangle {
        x: cristal.width * 0.84
        y: cristal.height * 0.84
        width: lupa.width * 0.5
        height: lupa.grosor
        radius: height / 2
        rotation: 45
        transformOrigin: Item.TopLeft
        color: lupa.color
    }
}
