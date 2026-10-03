// TarjetaCasino.qml (móvil) -- la "ficha de casino" del juego (ver Main.qml,
// tarjetas de Salas y Tienda): sombra desplazada, degradado de tres paradas con
// dithering, canto oscuro y un hilo dorado por dentro -- el doble bisel. Lo que
// se pone dentro va al cuerpo, debajo del título. Mismo diseño que el de
// escritorio (src/client-qt/qml/TarjetaCasino.qml), con el dithering de móvil.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Item {
    id: tarjeta
    property string titulo: ""
    property real margen: 18 * Tema.escala
    default property alias contenido: cuerpo.data

    implicitHeight: cuerpo.implicitHeight + 2 * tarjeta.margen + 6 * Tema.escala

    Rectangle {
        anchors.fill: cara
        anchors.topMargin: 3 * Tema.escala
        radius: cara.radius
        color: "black"
        opacity: 0.35
    }

    Rectangle {
        id: cara
        anchors.fill: parent
        anchors.margins: 3 * Tema.escala
        radius: 10 * Tema.escala
        border.width: 1.2
        border.color: Qt.rgba(0, 0, 0, 0.4)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.65) }
            GradientStop { position: 0.18; color: Qt.lighter(Tema.colorPanel, 1.4) }
            GradientStop { position: 1.0; color: Tema.colorPanel }
        }
        layer.enabled: true
        layer.effect: ShaderEffect {
            property variant source
            property real amplitud: 30.0
            fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
        }
    }

    Rectangle {
        anchors.fill: cara
        anchors.margins: 2 * Tema.escala
        radius: cara.radius - 2 * Tema.escala
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.22)
    }

    Column {
        id: cuerpo
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: tarjeta.margen
        spacing: 8 * Tema.escala

        Text {
            visible: tarjeta.titulo !== ""
            text: tarjeta.titulo.toUpperCase()
            color: Tema.colorAccent
            font.bold: true
            font.letterSpacing: 1.2
            font.pixelSize: 11 * Tema.escala
            font.family: Tema.fuenteElegante
        }
    }
}
