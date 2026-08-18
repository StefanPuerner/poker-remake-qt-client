// Interruptor.qml — toggle on/off. Extraído de Main.qml.
pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: interruptor
    property bool activo: false
    signal alternado()
    width: 36 * Tema.escala
    height: 20 * Tema.escala
    radius: height / 2
    color: Tema.colorFondo
    border.width: 1
    border.color: interruptor.activo ? Tema.colorAccent : Tema.colorBorde
    Behavior on border.color {
        ColorAnimation {
            duration: 120
        }
    }
    Rectangle {
        width: 14 * Tema.escala
        height: 14 * Tema.escala
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: interruptor.activo ? parent.width - width - 3 * Tema.escala : 3 * Tema.escala
        color: interruptor.activo ? Tema.colorAccent : Tema.colorTextoTenue
        Behavior on x {
            NumberAnimation {
                duration: 120
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: {
            interruptor.activo = !interruptor.activo;
            interruptor.alternado();
        }
    }
}
