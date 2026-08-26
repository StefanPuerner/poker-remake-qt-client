// SelectorPildoras.qml — selector de una opción entre varias, en forma de
// píldoras en fila. Extraído de Main.qml — se usa para dificultad de bots
// y tipo de límite en "Crear sala": son 2-3 opciones excluyentes, más
// claro que un ComboBox y no necesita re-tematizar el desplegable por
// defecto de Qt Quick Controls.
pragma ComponentBehavior: Bound
import QtQuick

Row {
    id: selector
    property var opciones: []
    property int seleccionado: 0
    // Ver el comentario largo en SelectorSegmentado.qml -- mismo motivo:
    // este componente nunca escribe su propia "seleccionado" para no
    // romper un binding declarativo externo.
    signal elegido(int indice)
    spacing: 6 * Tema.escala
    Repeater {
        model: selector.opciones
        delegate: Rectangle {
            id: pildora
            required property string modelData
            required property int index
            width: textoPildora.implicitWidth + 20 * Tema.escala
            height: 30 * Tema.escala
            radius: height / 2
            color: index === selector.seleccionado ? Tema.colorAccent : "transparent"
            border.width: 1
            border.color: Tema.colorBorde
            Text {
                id: textoPildora
                anchors.centerIn: parent
                text: pildora.modelData
                font.pixelSize: 12 * Tema.escala
                color: pildora.index === selector.seleccionado ? Tema.colorPanel : Tema.colorTextoTenue
            }
            MouseArea {
                anchors.fill: parent
                onClicked: selector.elegido(pildora.index)
            }
        }
    }
}
