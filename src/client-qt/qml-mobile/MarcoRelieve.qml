// MarcoRelieve.qml — el contrario de MarcoHueco: una superficie que
// SOBRESALE del tapete, para botones de icono y pastillas pequeñas.
// Mismo motivo (2026-09-09, ver MarcoHueco.qml): sobre un panel con
// textura, un contorno de 1px no separa nada -- "solo es un borde
// barato", con las palabras del usuario.
//
// Las tres señales de que algo está elevado, y aquí están las tres:
// sombra debajo, degradado de claro arriba a oscuro abajo, y filo
// iluminado en el canto de arriba. Todo derivado del color base con
// transparencias o Qt.lighter/darker, así que no hay ningún valor por
// tema que mantener.
//
// Al pulsar NO se mueve nada de sitio: se apaga la sombra y se invierte
// el degradado. Mover el contenido 2px abajo era la otra opción, pero en
// un botón redondo eso cambia el alto y con él el radio, y se ve dar un
// salto.
//
// ⚠️ ESTRUCTURA, no tocar a la ligera: el degradado y su capa de
// dithering viven en un Rectangle propio ("relleno") que NO tiene
// contenido dentro, y lo que el llamante mete va en "cara", ENCIMA y
// fuera de esa capa. La primera versión ponía layer.effect directamente
// en la cara, con lo que el contenido del botón (los tres puntos de
// Ajustes, la lupa de la Tienda) se renderizaba dentro de la capa y
// salía mal -- reportado con capturas el 2026-09-09. Es la misma regla
// que ya costó una rotura en SelectorSegmentado.qml: una capa con
// contenido dentro da problemas; una capa que solo tiene un degradado,
// no.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Item {
    id: relieve
    property bool pulsado: false
    property real radioMarco: 12 * Tema.escala
    /// Tinte del relleno -- por defecto el panel del tema. Ponerlo a
    /// Tema.colorAccent lo convierte en el botón "de acento".
    property color colorBase: Tema.colorPanel
    default property alias contenido: cara.data

    // Sombra: MISMO tamaño que la cara pero desplazada hacia abajo, así
    // que asoma por debajo. En tres pasadas escalonadas, que a ojo es un
    // desenfoque y no cuesta ningún efecto.
    Repeater {
        // Corta y suave: con desplazamientos grandes, en una forma
        // redonda la sombra asoma como una media luna oscura y se lee
        // como suciedad, no como relieve.
        model: [{ d: 1, o: 0.16 }, { d: 2, o: 0.12 }, { d: 4, o: 0.07 }]
        delegate: Rectangle {
            required property var modelData
            x: 0
            y: modelData.d * Tema.escala
            width: relieve.width
            height: relieve.height
            radius: relieve.radioMarco
            color: "black"
            opacity: relieve.pulsado ? 0 : modelData.o
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }
    }

    Rectangle {
        id: relleno
        anchors.fill: parent
        radius: relieve.radioMarco
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.45)
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: relieve.pulsado ? Qt.darker(relieve.colorBase, 1.22)
                                       : Qt.lighter(relieve.colorBase, 1.32)
            }
            GradientStop { position: 0.55; color: relieve.colorBase }
            GradientStop {
                position: 1.0
                color: relieve.pulsado ? Qt.lighter(relieve.colorBase, 1.12)
                                       : Qt.darker(relieve.colorBase, 1.18)
            }
        }
        // Sin capa de dithering a propósito (2026-09-09, pedido explícito:
        // "los botones dorados en cualquier sitio no deberían tenerla").
        // El ruido se puso para matar el bandeo de los degradados, pero
        // sobre un dorado pequeño se percibe como la textura de tapete de
        // los paneles y le quita el aspecto de metal limpio -- que es justo
        // lo que tiene que distinguir a un botón del paño sobre el que se
        // apoya. Aquí no hace falta: la rampa es corta y el elemento
        // pequeño, así que no llega a bandear.
    }

    // Aquí había un filo claro de 1px en el canto de arriba. Fuera desde
    // 2026-09-09, mismo motivo que en MarcoHueco.qml: una raya recta
    // dentro de una forma redondeada (y este marco llega a ser un CÍRCULO
    // completo, en el botón de Ajustes) no sigue la curva, y sus extremos
    // se ven como rayas blancas sueltas. El volumen lo dan la sombra y el
    // degradado, que sí siguen la forma.

    // Lo que meta el llamante: encima de todo y FUERA de cualquier capa.
    Item {
        id: cara
        anchors.fill: parent
    }
}
