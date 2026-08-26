// SelectorSegmentado.qml (móvil) — mismo rol que el de escritorio (ver
// src/client-qt/qml/SelectorSegmentado.qml): interruptor segmentado con
// realce deslizante, para donde cambiar de opción cambia el contenido
// entero de un panel (Ajustes/Cuenta del cajón), no un simple filtro.
// Altura mayor que Tema.tamanoMinTactil de sobra -- no hace falta el
// Math.max de los componentes táctiles normales.
pragma ComponentBehavior: Bound
import QtQuick

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
