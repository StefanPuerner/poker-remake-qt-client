// Asiento.qml (móvil) — idéntico al de escritorio: sin MouseArea/hover,
// no necesita ningún cambio para tacto.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Column {
    property string saldo
    property string nombre
    property bool activo: false
    property real fraccionTiempo: 1.0
    property bool retirado: false
    opacity: retirado ? 0.45 : 1.0
    onActivoChanged: anillo.requestPaint()
    onFraccionTiempoChanged: if (activo)
        anillo.requestPaint()
    spacing: 8 * Tema.escala

    Item {
        x: (parent.width - width) / 2
        width: 46 * Tema.escala + 10
        height: 46 * Tema.escala + 10

        Rectangle {
            visible: activo
            anchors.centerIn: parent
            width: parent.width + 16
            height: parent.height + 16
            radius: width / 2
            color: "transparent"
            border.width: 7 * Tema.escala
            border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.12)
        }
        Rectangle {
            visible: activo
            anchors.centerIn: parent
            width: parent.width + 5
            height: parent.height + 5
            radius: width / 2
            color: "transparent"
            border.width: 3 * Tema.escala
            border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.3)
        }

        Canvas {
            id: anillo
            anchors.fill: parent
            visible: activo
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var cx = width / 2;
                var cy = height / 2;
                var r = width / 2 - 2;
                ctx.strokeStyle = fraccionTiempo < 0.2 ? Tema.colorPeligro : Tema.colorAccent;
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + fraccionTiempo * 2 * Math.PI);
                ctx.stroke();
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 46 * Tema.escala
            height: 46 * Tema.escala
            radius: width / 2
            border.width: 2
            border.color: activo ? Tema.colorAccent : Tema.colorBorde
            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.6) }
                GradientStop { position: 1.0; color: Tema.colorPanel }
            }
            Text {
                anchors.centerIn: parent
                text: nombre.charAt(0)
                color: Tema.colorAccent
                font.pixelSize: 20 * Tema.escala
                font.family: Tema.fuenteElegante
            }
        }
    }
    Rectangle {
        x: (parent.width - width) / 2
        color: "black"
        opacity: 0.70
        border.width: 2
        width: infoAsiento.width * 1.2
        height: infoAsiento.height * 1.
        radius: width / 10
        Column {
            id: infoAsiento
            anchors.centerIn: parent
            Text {
                text: nombre
                color: "white"
                font.pixelSize: 13 * Tema.escala
                font.family: Tema.fuenteElegante
            }
            Text {
                text: saldo
                color: Tema.colorAccent
                font.bold: true
                font.pixelSize: 13 * Tema.escala
                font.family: Tema.fuenteElegante
            }
        }
    }
}
