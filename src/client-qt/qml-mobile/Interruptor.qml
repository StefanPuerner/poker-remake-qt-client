// Interruptor.qml (móvil) — mismo toggle on/off del cliente de escritorio,
// pero la zona pulsable ya no es del tamaño del propio dibujo (36×20, muy
// por debajo del mínimo táctil) — la raíz pasa a ser un Item del tamaño de
// Tema.tamanoMinTactil, con el interruptor dibujado centrado dentro y algo
// más grande para que se lea bien. Ver Parte 7 del plan de diseño móvil.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Item {
    id: zonaTactil
    property bool activo: false
    signal alternado()
    width: Tema.tamanoMinTactil
    height: Tema.tamanoMinTactil

    Rectangle {
        id: interruptor
        anchors.centerIn: parent
        width: 40 * Tema.escala
        height: 22 * Tema.escala
        radius: height / 2
        color: Tema.colorFondo
        border.width: 1
        border.color: zonaTactil.activo ? Tema.colorAccent : Tema.colorBorde
        Behavior on border.color {
            ColorAnimation {
                duration: 120
            }
        }
        Rectangle {
            width: 16 * Tema.escala
            height: 16 * Tema.escala
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: zonaTactil.activo ? parent.width - width - 3 * Tema.escala : 3 * Tema.escala
            color: zonaTactil.activo ? Tema.colorAccent : Tema.colorTextoTenue
            Behavior on x {
                NumberAnimation {
                    duration: 120
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            zonaTactil.activo = !zonaTactil.activo;
            zonaTactil.alternado();
        }
    }
}
