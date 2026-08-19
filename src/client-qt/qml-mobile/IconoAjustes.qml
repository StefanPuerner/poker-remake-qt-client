// IconoAjustes.qml — sustituye a BarraSuperior.qml en Lobby/Partida/Fin:
// un único icono flotante (pensado para la esquina superior derecha) en
// vez de una franja horizontal completa — reclama espacio vertical justo
// donde más falta (Partida es la pantalla donde se pasa la mayor parte
// del tiempo). El saldo propio no se repite aquí: ya se ve en el propio
// asiento del jugador en la mesa. Ver Parte 7 del plan de diseño móvil,
// punto 6.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Rectangle {
    id: icono
    signal abrirAjustes()
    width: Tema.tamanoMinTactil
    height: Tema.tamanoMinTactil
    radius: width / 2
    color: area.pressed ? Tema.colorAccent : Qt.rgba(0, 0, 0, 0.35)
    border.width: 1
    border.color: area.pressed ? Tema.colorAccent : Qt.rgba(1, 1, 1, 0.15)

    Column {
        anchors.centerIn: parent
        spacing: 3 * Tema.escala
        Repeater {
            model: 3
            delegate: Rectangle {
                width: 4 * Tema.escala
                height: 4 * Tema.escala
                radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                color: area.pressed ? Tema.colorPanel : "white"
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        onClicked: icono.abrirAjustes()
    }
}
