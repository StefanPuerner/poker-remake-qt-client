// CabeceraPullRefrescar.qml — "desliza hacia abajo para refrescar", el
// gesto habitual en listas móviles, en vez de un botón de refrescar
// aparte. Se engancha como ListView.header: la altura sigue el arrastre
// 1:1 mientras el dedo sigue en pantalla (contentY se vuelve negativo al
// arrastrar más allá del principio de la lista — el mismo mecanismo que
// ya usa Flickable para el rebote de goma, sin nada que inventar), y solo
// se anima el cierre/apertura automáticos (al soltar), no el arrastre en
// sí, para que seguir al dedo se sienta inmediato.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Item {
    id: cabecera
    // Flickable (no ListView) -- así funciona igual de header de un
    // GridView (rediseño de tarjetas, 2026-08-28): solo se usan
    // width/contentY/dragging, los tres viven en Flickable, el ancestro
    // común de ListView y GridView -- ListView seguía sirviendo antes por
    // casualidad de tipos, no porque hiciera falta nada específico de él.
    required property Flickable vista
    property bool refrescando: false
    signal refrescar()

    readonly property real umbral: 60 * Tema.escala
    property bool listo: false

    width: vista.width
    height: refrescando ? 40 * Tema.escala : Math.max(0, -vista.contentY)
    Behavior on height {
        enabled: !vista.dragging
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }

    Connections {
        target: vista
        function onContentYChanged() {
            if (cabecera.refrescando) return;
            cabecera.listo = vista.contentY < -cabecera.umbral;
        }
        function onDraggingChanged() {
            if (!vista.dragging && cabecera.listo && !cabecera.refrescando) {
                cabecera.listo = false;
                cabecera.refrescar();
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 8 * Tema.escala
        visible: cabecera.height > 4
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: cabecera.refrescando ? "..." : (cabecera.listo ? "v" : "^")
            color: Tema.colorAccent
            font.bold: true
            font.pixelSize: 13 * Tema.escala
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: cabecera.refrescando ? "Actualizando"
                                        : (cabecera.listo ? "Suelta para actualizar" : "Desliza para actualizar")
            color: Tema.colorTextoTenue
            font.pixelSize: 11 * Tema.escala
        }
    }
}
