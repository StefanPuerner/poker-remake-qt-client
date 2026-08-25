// IconoChuleta.qml — icono flotante gemelo de IconoAjustes.qml (mismo
// tamaño/estilo, glifo distinto) para abrir la chuleta de manos con un
// solo toque desde CajonPartida.qml -- antes enterrada dentro del cajón
// de ajustes, pedido explícito del usuario.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Rectangle {
    id: icono
    signal abrirChuleta()
    width: Tema.tamanoMinTactil
    height: Tema.tamanoMinTactil
    radius: width / 2
    color: area.pressed ? Tema.colorAccent : Qt.rgba(0, 0, 0, 0.35)
    border.width: 1
    border.color: area.pressed ? Tema.colorAccent : Qt.rgba(1, 1, 1, 0.15)

    Text {
        anchors.centerIn: parent
        text: "?"
        font.bold: true
        font.pixelSize: 16 * Tema.escala
        color: area.pressed ? Tema.colorPanel : "white"
    }

    MouseArea {
        id: area
        anchors.fill: parent
        onClicked: icono.abrirChuleta()
    }
}
