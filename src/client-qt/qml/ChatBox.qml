// ChatBox.qml — chat con burbujas: las tuyas a la derecha (con un tinte
// dorado), las de los demás a la izquierda — como cualquier chat de
// mensajería. Extraído de Main.qml. Usado tal cual en el Lobby (no hay
// historial que mostrar todavía, solo chat) — en Partida, PanelLateral
// tiene su propia caja con pestañas historial/chat en vez de reusar esto.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Rectangle {
    id: cajaChat
    property var modelo
    property string miNombre
    // Antes "ventana.chatActive" — un id como "ventana" solo es visible
    // dentro de su propio fichero, así que quien instancie esto ahora
    // pasa el valor explícitamente.
    required property bool activo
    visible: activo
    width: 340 * Tema.escala
    height: 460 * Tema.escala
    radius: 8 * Tema.escala
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.3)
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
        GradientStop { position: 1.0; color: Tema.colorPanel }
    }

    ListView {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: filaEntrada.top
        anchors.margins: 10 * Tema.escala
        anchors.bottomMargin: 8 * Tema.escala
        // "BottomToTop" parecía la opción obvia para un chat, pero con
        // append() (mensaje nuevo = índice más alto) hace justo lo
        // contrario de lo que parece: apila los índices crecientes
        // hacia ARRIBA, así que el mensaje más nuevo acababa en lo alto
        // de la lista. El orden normal (de arriba abajo) + moverse al
        // final es lo que de verdad da "los nuevos entran por abajo".
        spacing: 8 * Tema.escala
        clip: true
        model: cajaChat.modelo
        // Sin esto, un mensaje nuevo se añade al modelo pero la vista se
        // queda mirando donde estaba — hay que decirle explícitamente
        // que se mueva al final cada vez que cambia el número de
        // elementos. "Qt.callLater" en vez de llamarlo directo: en el
        // mismo instante en que cambia "count" el elemento nuevo
        // todavía no ha terminado de crearse/medirse, así que
        // posicionar ya mismo deja fuera justo el último — hay que
        // esperar un "tick" a que termine el ciclo actual.
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
                // Burbuja propia pegada a la derecha, ajena a la
                // izquierda — un Item normal sí admite esto (no es hijo
                // directo de un Row/Column con reglas de posicionador).
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
            height: 44 * Tema.escala
            color: Tema.colorTexto
            font.pixelSize: 13 * Tema.escala
            // El estilo Material anima el placeholder hacia una
            // "etiqueta flotante" arriba del campo al enfocar/escribir
            // — con nuestro borde dibujado a mano se solapa en vez de
            // apartarse. Más simple que perseguir esa animación:
            // ocultar el placeholder en cuanto hay foco o texto.
            placeholderText: (activeFocus || text.length > 0) ? "" : "Escribe un mensaje..."
            placeholderTextColor: Tema.colorTextoTenue
            background: Rectangle {
                color: Tema.colorFondo
                radius: 8 * Tema.escala
                border.width: 1
                border.color: textoChat.activeFocus ? Tema.colorAccent : Tema.colorBorde
            }
            // Antes había que Tab + Espacio hasta "Enviar" tras escribir
            // — Enter manda el mensaje directamente, igual que en móvil.
            onAccepted: botonEnviar.clicked()
        }
        BotonRelleno {
            id: botonEnviar
            height: 44 * Tema.escala
            text: "Enviar"
            onClicked: {
                // Con Enter ahora enviando directamente (ver arriba), un
                // Enter en el campo vacío ya no debe mandar un mensaje en
                // blanco -- antes esto no hacía falta porque llegar hasta
                // aquí exigía Tab + Espacio a propósito.
                if (textoChat.text.length === 0) return;
                redcliente.enviarChat(textoChat.text, "sala");
                cajaChat.modelo.append({
                    autor: cajaChat.miNombre,
                    mensaje: textoChat.text,
                    hora: Qt.formatTime(new Date(), "hh:mm")
                });  // eco local
                textoChat.text = "";
            }
        }
    }
}
