// IconoOjo.qml — botón de "mostrar/ocultar contraseña" (ojo dibujado a
// mano -- óvalo + pupila, con una raya diagonal encima cuando está
// oculta -- en vez de un glifo "👁"/"🙈": mismo motivo que
// IconoLupa.qml, ningún glifo así es fiable entre fuentes ni en este
// build de Android). Pedido real de usuarios que echaban en falta poder
// revisar lo que tecleaban, sobre todo en el teclado táctil (2026-09-14).
//
// Autocontenido -- ya trae su propia zona pulsable de Tema.tactil (igual
// que IconoAjustes.qml), así que cada campo de contraseña solo tiene que
// ponerlo y escuchar toggled(), sin repetir un MouseArea en cada sitio.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Item {
    id: boton
    /// true = contraseña oculta ahora mismo (se dibuja el ojo tachado).
    property bool oculto: true
    property color color: Tema.colorTextoTenue
    signal toggled()

    implicitWidth: Tema.tactil
    implicitHeight: Tema.tactil

    Rectangle {
        id: contorno
        anchors.centerIn: parent
        width: parent.width * 0.42
        height: width * 0.6
        radius: height / 2
        color: "transparent"
        border.width: Math.max(1.4, width * 0.09)
        border.color: boton.color
    }

    Rectangle {
        anchors.centerIn: contorno
        width: contorno.height * 0.46
        height: width
        radius: width / 2
        color: boton.color
    }

    // Raya diagonal -- "ojo tachado" -- solo mientras la contraseña sigue
    // oculta. Mismo truco que el mango de IconoLupa.qml: un Rectangle
    // rotado, no un glifo.
    Rectangle {
        visible: boton.oculto
        anchors.centerIn: parent
        width: contorno.width * 1.15
        height: Math.max(1.4, contorno.width * 0.09)
        radius: height / 2
        rotation: -40
        color: boton.color
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: boton.toggled()
    }
}
