// ChatBox.qml (móvil) — mismo chat de burbujas del cliente de escritorio.
// Caso "frecuente" del punto 2 del plan de diseño móvil: NO usa
// CampoEmergente (sería un popup por cada mensaje, muy incómodo) — en su
// lugar se traslada a sí mismo hacia arriba cuando el teclado del sistema
// aparece, atado a Qt.inputMethod.keyboardRectangle, para que el campo de
// entrada y los últimos mensajes queden siempre por encima. El botón
// Enviar ya usa BotonRelleno (tacto: pressed) y el campo respeta
// Tema.tamanoMinTactil.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile
import QtQuick.Controls

Rectangle {
    id: cajaChat
    property var modelo
    property string miNombre
    required property bool activo
    // Quien instancia esto decide A DÓNDE va el mensaje (chat de sala vía
    // redcliente.enviarChat(), o un chat directo vía
    // redcliente.enviarMensajeDirecto() -- ver VistaChatDirecto.qml) --
    // mismo cambio que en escritorio (ver ChatBox.qml de qml/).
    signal enviar(string texto)
    visible: activo
    width: 300 * Tema.escala
    height: 320 * Tema.escala
    radius: 8 * Tema.escala
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.3)
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
        GradientStop { position: 1.0; color: Tema.colorPanel }
    }

    // Ver cabecera: sube la caja entera cuando el teclado tapa el campo de
    // entrada. Sin verificar todavía contra un teclado de Android real
    // (keyboardRectangle solo se puede probar de verdad en el dispositivo,
    // ver Parte 7 del plan — verificación).
    // qmllint disable missing-property
    // Qt.inputMethod es la API real de Qt (QInputMethod), pero qmllint no
    // conoce su tipo estático — "missing-property" aquí es un falso
    // positivo conocido, no un error real.
    property real ocultoPorTeclado: (textoChat.activeFocus && Qt.inputMethod.keyboardRectangle.height > 0)
                                     ? Qt.inputMethod.keyboardRectangle.height : 0
    // qmllint enable missing-property
    Behavior on ocultoPorTeclado { NumberAnimation { duration: 150 } }
    transform: Translate { y: -cajaChat.ocultoPorTeclado }

    ListView {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: filaEntrada.top
        anchors.margins: 10 * Tema.escala
        anchors.bottomMargin: 8 * Tema.escala
        spacing: 8 * Tema.escala
        clip: true
        model: cajaChat.modelo
        onCountChanged: Qt.callLater(positionViewAtEnd)
        delegate: Item {
            required property string autor
            required property string mensaje
            property bool esPropio: autor === cajaChat.miNombre
            width: ListView.view.width
            height: columnaBurbuja.height

            // Medidor invisible, sin wrap ni restricción de ancho -- ver
            // columnaBurbuja.width. Da el ancho de una sola línea de
            // verdad, sin la dependencia circular de antes (el ancho de
            // la burbuja salía de textoBurbuja.implicitWidth, pero el
            // propio textoBurbuja tomaba su ancho DE la burbuja vía
            // anchors.fill -- con wrap activo eso es un bucle que Qt no
            // siempre resuelve bien, y el texto se salía por fuera en
            // mensajes largos/multilínea).
            Text {
                id: medidor
                visible: false
                text: mensaje
                font.pixelSize: 13 * Tema.escala
            }

            Column {
                id: columnaBurbuja
                x: esPropio ? parent.width - width : 0
                width: Math.min(medidor.implicitWidth + 24 * Tema.escala, parent.width * 0.8)
                spacing: 2 * Tema.escala

                Text {
                    text: esPropio ? "Tú" : autor
                    color: Tema.colorTextoMuyTenue
                    font.pixelSize: 10 * Tema.escala
                }
                Rectangle {
                    width: parent.width
                    height: textoBurbuja.implicitHeight + 16 * Tema.escala
                    radius: 12 * Tema.escala
                    color: esPropio ? Qt.rgba(0.75, 0.56, 0.24, 0.18) : Tema.colorTapete
                    border.width: esPropio ? 1 : 0
                    border.color: Tema.colorAccent
                    Text {
                        id: textoBurbuja
                        anchors.fill: parent
                        anchors.margins: 8 * Tema.escala
                        text: mensaje
                        color: Tema.colorTexto
                        font.pixelSize: 13 * Tema.escala
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    Row {
        id: filaEntrada
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10 * Tema.escala
        spacing: 8 * Tema.escala

        TextField {
            id: textoChat
            width: parent.width - botonEnviar.width - parent.spacing
            height: Tema.tamanoMinTactil
            color: Tema.colorTexto
            font.pixelSize: 13 * Tema.escala
            // Ver CampoEmergente.qml: sin esto, borrar una letra solo
            // retrocedía el cursor sin borrarla de verdad.
            inputMethodHints: Qt.ImhNoPredictiveText
            placeholderText: (activeFocus || text.length > 0) ? "" : "Escribe un mensaje..."
            placeholderTextColor: Tema.colorTextoTenue
            background: Rectangle {
                color: Tema.colorFondo
                radius: 8 * Tema.escala
                border.width: 1
                border.color: textoChat.activeFocus ? Tema.colorAccent : Tema.colorBorde
            }
            onAccepted: botonEnviar.clicked()
        }
        BotonRelleno {
            id: botonEnviar
            height: Tema.tamanoMinTactil
            text: "Enviar"
            onClicked: {
                if (textoChat.text.length === 0) return;
                cajaChat.enviar(textoChat.text);
                cajaChat.modelo.append({
                    autor: cajaChat.miNombre,
                    mensaje: textoChat.text,
                    hora: Qt.formatTime(new Date(), "hh:mm")
                });
                textoChat.text = "";
            }
        }
    }
}
