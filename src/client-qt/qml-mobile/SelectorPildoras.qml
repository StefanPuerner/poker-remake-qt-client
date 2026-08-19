// SelectorPildoras.qml (móvil) — mismo selector de una opción entre varias
// del cliente de escritorio (ya era solo onClicked, sin hover) — el único
// cambio es el alto de cada píldora, subido al suelo táctil en vez de los
// 30px de diseño de escritorio. Ver Parte 7 del plan de diseño móvil.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Row {
    id: selector
    property var opciones: []
    property int seleccionado: 0
    spacing: 8 * Tema.escala
    Repeater {
        model: selector.opciones
        delegate: Rectangle {
            id: pildora
            required property string modelData
            required property int index
            width: Math.max(textoPildora.implicitWidth + 24 * Tema.escala, Tema.tamanoMinTactil)
            height: Tema.tamanoMinTactil
            radius: height / 2
            color: index === selector.seleccionado ? Tema.colorAccent : "transparent"
            border.width: 1
            border.color: Tema.colorBorde
            Text {
                id: textoPildora
                anchors.centerIn: parent
                text: pildora.modelData
                font.pixelSize: 13 * Tema.escala
                color: pildora.index === selector.seleccionado ? Tema.colorPanel : Tema.colorTextoTenue
            }
            MouseArea {
                anchors.fill: parent
                onClicked: selector.seleccionado = pildora.index
            }
        }
    }
}
