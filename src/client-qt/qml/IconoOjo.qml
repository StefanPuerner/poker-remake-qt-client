// IconoOjo.qml — botón de "mostrar/ocultar contraseña" (ojo dibujado a
// mano -- óvalo + pupila, con una raya diagonal encima cuando está
// oculta -- en vez de un glifo "👁"/"🙈", que se ve distinto según la
// fuente y no siempre está disponible). Pedido real de usuarios que
// echaban en falta poder revisar lo que tecleaban, sobre todo en móvil
// (ver el gemelo de este fichero en qml-mobile/), pero también en
// escritorio (2026-09-14).
//
// Autocontenido -- ya trae su propia zona pulsable (algo más grande que
// el dibujo, cómoda con ratón sin necesitar el tamaño táctil de móvil),
// así que cada campo de contraseña solo tiene que ponerlo y escuchar
// toggled().
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: boton
    /// true = contraseña oculta ahora mismo (se dibuja el ojo tachado).
    property bool oculto: true
    property color color: Tema.colorTextoTenue
    signal toggled()

    implicitWidth: 28 * Tema.escala
    implicitHeight: 28 * Tema.escala

    Rectangle {
        id: contorno
        anchors.centerIn: parent
        width: parent.width * 0.75
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
    // oculta. Mismo truco que el mango de una lupa dibujada a mano: un
    // Rectangle rotado, no un glifo.
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
        anchors.margins: -6 * Tema.escala
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: boton.toggled()
    }
}
