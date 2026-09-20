// PopupTemas.qml — ventana flotante para elegir el tema de color.
// Antes los seis temas eran una lista fija dentro de Ajustes y ocupaban media
// barra lateral; ahora Ajustes solo tiene un botón que abre esto. Cada tema se
// enseña con sus colores reales (fondo, panel, tapete y acento) y se aplica al
// pulsar, sin cerrar la ventana: se ve el cambio en la propia ventana y se
// puede probar uno tras otro.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Popup {
    id: popup
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 20 * Tema.escala

    function abrir() { popup.open(); }

    background: Rectangle {
        color: Tema.colorPanel
        radius: 12 * Tema.escala
        border.width: 1
        border.color: Tema.colorAccent
    }

    contentItem: Column {
        spacing: 16 * Tema.escala

        Text {
            text: Idioma.t("titulo_tema_color")
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.pixelSize: 17 * Tema.escala
        }

        Grid {
            columns: Math.max(1, Math.min(3, Math.floor((popup.parent.width - 2 * popup.padding - 24 * Tema.escala) / (144 * Tema.escala))))
            spacing: 12 * Tema.escala

            Repeater {
                model: Tema.temas
                delegate: Rectangle {
                    id: tarjeta
                    required property var modelData
                    required property int index
                    readonly property bool marcado: Tema.temaActual === tarjeta.index
                    width: 132 * Tema.escala
                    height: 96 * Tema.escala
                    radius: 10 * Tema.escala
                    color: tarjeta.marcado
                           ? Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.14)
                           : "transparent"
                    border.width: tarjeta.marcado ? 2 : 1
                    border.color: tarjeta.marcado ? tarjeta.modelData.accent : Tema.colorBorde

                    Column {
                        anchors.centerIn: parent
                        spacing: 8 * Tema.escala

                        // Muestra del tema: su fondo, con el panel y el tapete encima
                        // y una gota del color de acento.
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 100 * Tema.escala
                            height: 44 * Tema.escala
                            radius: 6 * Tema.escala
                            color: tarjeta.modelData.fondo
                            border.width: 1
                            border.color: tarjeta.modelData.borde

                            Rectangle {
                                x: 6 * Tema.escala; y: 6 * Tema.escala
                                width: 30 * Tema.escala; height: 32 * Tema.escala
                                radius: 4 * Tema.escala
                                color: tarjeta.modelData.panel
                            }
                            Rectangle {
                                x: 42 * Tema.escala; y: 6 * Tema.escala
                                width: 52 * Tema.escala; height: 32 * Tema.escala
                                radius: 16 * Tema.escala
                                color: tarjeta.modelData.tapete
                                border.width: 1
                                border.color: tarjeta.modelData.accent
                            }
                            Rectangle {
                                x: 64 * Tema.escala; y: 17 * Tema.escala
                                width: 8 * Tema.escala; height: width
                                radius: width / 2
                                color: tarjeta.modelData.accent
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            // El nombre vive en Tema.qml (que también usa AvatarTest, sin
                            // Idioma.qml): la traducción se hace aquí, por índice.
                            text: Idioma.t(["tema_verde_clasico", "tema_azul_medianoche", "tema_burdeos",
                                            "tema_grafito", "tema_porcelana_dorada", "tema_taberna_real"][tarjeta.index])
                            color: tarjeta.marcado ? Tema.colorTexto : Tema.colorTextoTenue
                            font.bold: tarjeta.marcado
                            font.pixelSize: 12 * Tema.escala
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Tema.temaActual = tarjeta.index
                    }
                }
            }
        }

        BotonRelleno {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Idioma.t("boton_cerrar")
            onClicked: popup.close()
        }
    }
}
