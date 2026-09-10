// MarcoHueco.qml — el "hueco" en el que se apoya cualquier campo de texto
// o caja de búsqueda. Existe desde 2026-09-09, a raíz de un diagnóstico
// del usuario que vale para toda la app:
//
//   "Es importante que los elementos que tengan textura tapete y tienen
//    un fondo de textura tapete tengan un borde u otros mecanismos para
//    resaltarlos tridimensionalmente, si no, solo es un borde barato."
//
// Justo lo que pasaba: los campos eran un relleno plano con un filo
// dorado fino (o, en escritorio, solo una raya inferior). Sobre un panel
// que ya tiene su propia textura de fieltro, un contorno de 1px no separa
// nada -- el campo parecía una pegatina, no un sitio donde escribir.
//
// ⚠️ TRES COSAS QUE COSTARON UNA RONDA CADA UNA, no deshacerlas sin leer:
//
//  1. La sombra es CORTA y va arriba, no un degradado que cruce el campo
//     entero. Las dos primeras versiones sí lo cruzaban y las dos se
//     vieron como una raya atravesando el campo: la primera por bandeo
//     puro (faltaba la capa de dithering) y la segunda, ya con dithering,
//     porque un degradado de varias paradas tiene QUIEBROS DE PENDIENTE y
//     el ojo los lee como un canto aunque el color sea continuo (bandas
//     de Mach). Una sombra corta pegada al borde no tiene ese problema, y
//     encima es lo que hace un rebaje de verdad: la proyecta el labio
//     superior, no el fondo entero.
//
//  2. La sombra ocupa TODO el campo y se apaga por porcentaje, en vez de
//     ser una banda de 12px anclada arriba. Una banda así no tiene radio
//     y sus esquinas se salen por las esquinas redondeadas del campo: se
//     veía "el fondo negro sobresaliendo" en las cuatro puntas (reportado
//     2026-09-09). Llenando el campo con el MISMO radio, no hay nada que
//     asome.
//
//  3. SIN capa de dithering, a propósito (pedido explícito: "quítales la
//     textura tapete, destacarán más sin ella"). El campo tiene que
//     leerse liso frente al paño, que sí la lleva. Puede permitírselo
//     porque la rampa dura unos 12px: en tan poco no le da tiempo a
//     bandear.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Rectangle {
    id: marco
    /// Enciende el aro dorado -- normalmente atado al activeFocus del campo.
    property bool activo: false

    radius: 10 * Tema.escala
    color: Tema.colorFondo
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.55)

    Rectangle {
        id: sombraHueco
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, parent.radius - 1)
        // Dónde termina la sombra, en tanto por uno del alto: los ~12px de
        // siempre, pero expresados así para que el Rectangle pueda llenar
        // el campo y compartir su radio (ver la nota 2 de arriba).
        readonly property real finSombra: Math.min(0.9, (12 * Tema.escala) / Math.max(1, height))
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.45) }
            GradientStop { position: sombraHueco.finSombra; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Math.max(0, parent.radius - 2)
        color: "transparent"
        border.width: 1.2
        border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b,
                              marco.activo ? 1.0 : 0.5)
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    // Aquí había un filo claro de 1px en el canto de abajo. Fuera desde
    // 2026-09-09: una raya recta dentro de una caja redondeada no sigue la
    // curva de las esquinas, así que sus dos extremos se leen como rayas
    // blancas sueltas ("se ve el fondo negro sobresaliendo o líneas
    // blancas, lo quiero limpio"). El rebaje ya se entiende con el borde
    // oscuro, la sombra de arriba y el aro dorado; el filo no aportaba
    // tanto como para pagar eso.
}
