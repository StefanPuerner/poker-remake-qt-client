// SelectorSegmentado.qml — selector de dos (o más) secciones en forma de
// interruptor segmentado: una única pista con un realce que se DESLIZA de
// un lado al otro, en vez de píldoras sueltas (ver SelectorPildoras.qml).
// Pensado para donde cambiar de opción cambia el CONTENIDO entero de un
// panel (p. ej. Ajustes/Cuenta del cajón lateral) -- el deslizamiento en
// sí mismo comunica "esto ha cambiado" mucho mejor que un simple color de
// fondo distinto, y el tamaño mayor lo deja aparte de los botones
// normales de la interfaz. Misma familia visual que Interruptor.qml
// (pista + realce que se anima con la misma duración de 120ms).
pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: selector
    property var opciones: []
    property int seleccionado: 0
    // Emitida al pulsar un segmento -- el LLAMADOR decide el valor real de
    // "seleccionado" (normalmente reasignándolo desde aquí mismo). Este
    // componente NUNCA escribe su propia "seleccionado" -- si lo hiciera,
    // cualquier binding declarativo del tipo "seleccionado: miPropiedad"
    // quedaría roto para siempre en cuanto el usuario pulsara una vez (QML
    // corta el binding en la primera asignación directa), así que un reset
    // externo posterior de "miPropiedad" (p. ej. al reentrar en una
    // pantalla) ya no se reflejaría aquí -- bug real en producción: Social
    // se acordaba visualmente de la última pestaña pulsada aunque el
    // código pusiera pestanaSocialActual a 0 al reentrar (2026-08-28).
    signal elegido(int indice)

    width: parent.width
    height: 44 * Tema.escala
    radius: 10 * Tema.escala
    color: Tema.colorFondo
    border.width: 1
    border.color: Tema.colorBorde

    readonly property real margenPista: 4 * Tema.escala
    // Sin restar el margen aquí -- este es el mismo ancho de segmento que
    // usa la Row de etiquetas de abajo (que sí ocupa el ancho completo).
    // Si se restara el margen en este cálculo, el realce y las etiquetas
    // dividirían el ancho total de forma distinta y quedarían
    // desalineados (más cuanto más segmentos hubiera).
    readonly property real anchoSegmento: selector.width / Math.max(1, selector.opciones.length)

    Rectangle {
        id: realce
        y: selector.margenPista
        width: selector.anchoSegmento - selector.margenPista * 2
        height: selector.height - selector.margenPista * 2
        radius: 8 * Tema.escala
        x: selector.anchoSegmento * selector.seleccionado + selector.margenPista
        Behavior on x {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(Tema.colorAccent, 1.15) }
            GradientStop { position: 1.0; color: Tema.colorAccent }
        }
    }

    Row {
        anchors.fill: parent
        Repeater {
            model: selector.opciones
            delegate: Item {
                id: segmento
                required property string modelData
                required property int index
                width: selector.anchoSegmento
                height: selector.height

                Text {
                    anchors.centerIn: parent
                    text: segmento.modelData
                    font.pixelSize: 14 * Tema.escala
                    font.bold: segmento.index === selector.seleccionado
                    color: segmento.index === selector.seleccionado ? Tema.colorPanel : Tema.colorTextoTenue
                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: selector.elegido(segmento.index)
                }
            }
        }
    }
}
