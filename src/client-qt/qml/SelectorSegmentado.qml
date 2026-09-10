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
// SOLO para el brillo del realce activo (2026-09-02, "ficha de casino" --
// ver mismo criterio en Main.qml, mini-riel de Personalizar/móvil). Nativo
// de Qt 6.5+, viene con el propio módulo Quick, no hace falta enlazar nada
// nuevo en CMake -- un único realce por instancia, barato de sobra.
import QtQuick.Effects

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

    // Brillo dorado de verdad alrededor del realce -- "ficha de casino"
    // (2026-09-02, pedido explícito: "aplicar esta misma apariencia al
    // boton de los sliders"). Declarado ANTES que "realce" para quedar
    // detrás; sigue su posición/tamaño en vivo (mismo x/y con Behavior)
    // porque toma sus valores directamente de él, no una copia.
    MultiEffect {
        x: realce.x
        y: realce.y
        width: realce.width
        height: realce.height
        source: realce
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowColor: Tema.colorAccent
        shadowOpacity: 0.65
        shadowBlur: 0.7
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }

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
        // Degradado + dithering en un Rectangle HIJO, no en "realce" mismo:
        // el MultiEffect de arriba usa "source: realce" para el brillo, y
        // poner layer.effect directamente en el propio item que otro efecto
        // captura como fuente rompía el cálculo de padding del MultiEffect
        // (recorte/borde raro visto en pruebas). Anidado así, MultiEffect
        // sigue capturando "realce" tal cual (ya incluye este hijo
        // compuesto) sin competir por la misma capa.
        Rectangle {
            id: degradado
            anchors.fill: parent
            radius: parent.radius
            // Degradado metálico de 3 paradas -- mismo que BotonRelleno.qml
            // ("Iniciar sesión") y el mini-riel de Personalizar/móvil, no el
            // relleno plano de 2 paradas de antes.
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(Tema.colorAccent, 1.35) }
                GradientStop { position: 0.5; color: Tema.colorAccent }
                GradientStop { position: 1.0; color: Qt.darker(Tema.colorAccent, 1.2) }
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
