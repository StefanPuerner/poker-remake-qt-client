// SelectorSegmentado.qml (móvil) — mismo rol que el de escritorio (ver
// src/client-qt/qml/SelectorSegmentado.qml): interruptor segmentado con
// realce deslizante, para donde cambiar de opción cambia el contenido
// entero de un panel (Ajustes/Cuenta del cajón), no un simple filtro.
// Altura mayor que Tema.tamanoMinTactil de sobra -- no hace falta el
// Math.max de los componentes táctiles normales.
pragma ComponentBehavior: Bound
import QtQuick
// SOLO para el brillo del realce activo (2026-09-02, "ficha de casino" --
// mismo criterio ya usado en el mini-riel de Personalizar). Nativo de
// Qt 6.5+, viene con el propio módulo Quick, no hace falta enlazar nada
// nuevo en CMake -- un único realce por instancia, barato de sobra.
import QtQuick.Effects

Rectangle {
    id: selector
    property var opciones: []
    property int seleccionado: 0
    // Ver el comentario largo en la versión de escritorio de este mismo
    // fichero -- este componente nunca escribe su propia "seleccionado"
    // para no romper un binding declarativo externo (bug real:
    // 2026-08-28).
    signal elegido(int indice)

    width: parent.width
    height: 44 * Tema.escala
    radius: 10 * Tema.escala
    color: Tema.colorFondo
    border.width: 1
    border.color: Tema.colorBorde

    readonly property real margenPista: 4 * Tema.escala
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
        // Degradado + dithering en un Rectangle HIJO, no en "realce" mismo
        // -- MISMO arreglo que la versión de escritorio, que ya lo traía
        // desde el día que se añadió el dithering; al móvil se le quedó
        // sin trasladar y por eso rompió (bug real reportado 2026-09-09,
        // con capturas: el realce de "Amigos" salía con un rectángulo
        // interior metido dentro).
        //
        // Por qué rompe: el MultiEffect de arriba usa "source: realce". Un
        // item solo es fuente de textura válida si tiene layer activada;
        // sin dithering, "realce" no la tenía, el MultiEffect no pintaba
        // nada y el brillo simplemente no existía (sin dar la cara). Al
        // ponerle layer.effect para el dithering, el MultiEffect empezó a
        // recibir textura de verdad y a pintar SU PROPIA COPIA del realce
        // -- y con autoPaddingEnabled la dibuja encogida dentro del hueco
        // que reserva para el desenfoque. De ahí la copia interior. Con el
        // degradado en un hijo, "realce" sigue siendo fuente limpia para
        // el MultiEffect y el dithering no compite por la misma capa.
        Rectangle {
            id: degradado
            anchors.fill: parent
            radius: parent.radius
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
