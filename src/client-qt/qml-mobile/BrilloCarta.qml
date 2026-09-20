// BrilloCarta.qml (móvil, igual que el de escritorio) — realce de una carta de la mano ganadora: filo dorado y, por fuera, un halo de tres
// anillos concéntricos que late suavemente. Es el mismo lenguaje que el aro de turno del avatar
// (Asiento.qml: anillos rgba concéntricos, sin blur real), para que se note sin costar GPU.
// Se coloca con anchors.fill sobre la carta; el halo se dibuja POR FUERA de ella.
import QtQuick
import PokerQuickMobile

Item {
    id: brillo
    // Radio de esquina de la carta y tamaño del halo (1 = carta grande; <1 para las pequeñas de los asientos).
    property real radio: 6
    property real escalaHalo: 1.0
    property real filo: 3
    // Con las animaciones apagadas el halo se queda fijo (sin latido).
    property bool animando: true
    property real velocidad: 1.0
    // Tres anillos que se apagan hacia fuera (aproxima un resplandor sin blur real) en un dorado más
    // claro que el acento: con el acento puro, sobre un fondo oscuro el halo salía como una banda marrón.
    readonly property color luz: Qt.lighter(Tema.colorAccent, 1.3)
    readonly property var anillos: [
        { g: 10 * Tema.escala * escalaHalo, a: 0.10 },
        { g: 6.5 * Tema.escala * escalaHalo, a: 0.22 },
        { g: 3 * Tema.escala * escalaHalo, a: 0.50 }
    ]

    Item {
        id: halos
        anchors.fill: parent
        Repeater {
            model: brillo.anillos
            delegate: Rectangle {
                required property var modelData
                anchors.centerIn: halos
                width: halos.width + 2 * modelData.g
                height: halos.height + 2 * modelData.g
                radius: brillo.radio + modelData.g
                color: "transparent"
                border.width: modelData.g
                border.color: Qt.rgba(brillo.luz.r, brillo.luz.g, brillo.luz.b, modelData.a)
            }
        }
        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: brillo.visible && brillo.animando
            NumberAnimation { to: 0.4; duration: 750 / Math.max(0.05, brillo.velocidad); easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 750 / Math.max(0.05, brillo.velocidad); easing.type: Easing.InOutSine }
        }
    }
    Rectangle {   // filo dorado sobre el borde de la carta
        anchors.fill: parent
        radius: brillo.radio
        color: "transparent"
        border.width: brillo.filo
        border.color: Tema.colorAccent
    }
}
