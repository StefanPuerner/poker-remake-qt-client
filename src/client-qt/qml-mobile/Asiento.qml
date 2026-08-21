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
    // Dealer/ciegas de la mano actual (servidor, ver GAME_STATE). Un mismo
    // asiento puede ser dealer Y small blind a la vez (heads-up: el dealer
    // paga la ciega pequeña) -- por eso son propiedades independientes, no
    // un enum "posicion" de un solo valor.
    property bool esDealer: false
    property bool esSb: false
    property bool esBb: false
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

        // Marcadores de dealer/ciegas -- mismo diseño que escritorio (ver
        // el comentario largo ahí): disco dorado para el dealer, píldora
        // discreta para SB/BB, en un Row para que quepan los dos a la vez
        // en heads-up.
        Row {
            visible: esDealer || esSb || esBb
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -2 * Tema.escala
            anchors.topMargin: -2 * Tema.escala
            spacing: 2 * Tema.escala
            z: 10

            Rectangle {
                visible: esDealer
                width: 20 * Tema.escala
                height: 20 * Tema.escala
                radius: width / 2
                color: Tema.colorAccent
                border.width: 1.5
                border.color: Tema.colorFondo
                Text {
                    anchors.centerIn: parent
                    text: "D"
                    font.bold: true
                    font.pixelSize: 11 * Tema.escala
                    font.family: Tema.fuenteElegante
                    color: Tema.colorFondo
                }
            }
            Rectangle {
                visible: esSb || esBb
                width: textoCiega.implicitWidth + 8 * Tema.escala
                height: 18 * Tema.escala
                radius: height / 2
                color: Tema.colorPanel
                border.width: 1
                border.color: Tema.colorBorde
                Text {
                    id: textoCiega
                    anchors.centerIn: parent
                    text: esSb ? "SB" : "BB"
                    font.bold: true
                    font.pixelSize: 9 * Tema.escala
                    font.family: Tema.fuenteElegante
                    color: Tema.colorAccent
                }
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
