// PopupPerfilJugador.qml — perfil público de OTRO jugador: cabecera
// (avatar + marco + username) y el mismo bloque de estadísticas que el
// panel Cuenta (Main.qml, cajón de ajustes). DUPLICADO a propósito, no
// extraído a un componente compartido -- solo hay 2 usos y tocar el panel
// Cuenta (pantalla muy usada, ya probada) por una abstracción cosmética no
// compensa el riesgo (ver el plan "Cerrar Social v1"). Si tocas el layout
// de estadísticas aquí, revisa también el panel Cuenta en Main.qml.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Popup {
    id: popup
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(360 * Tema.escala, (parent ? parent.width : 360) - 60 * Tema.escala)
    padding: 20 * Tema.escala

    property string servidorHost
    property int servidorPuerto
    property int accountId: -1

    readonly property var perfil: redcliente.perfilJugador
    // Evita mostrar el perfil de la última cuenta consultada durante el
    // instante en que ya se pidió un accountId nuevo pero la respuesta
    // todavía no ha llegado.
    readonly property bool datosListos: perfil.accountId === popup.accountId

    /// Abre el popup y pide el perfil de @p id -- público, sin exigir
    /// sesión iniciada (mismo criterio que Ranking).
    function abrir(id) {
        popup.accountId = id;
        redcliente.consultarPerfilJugador(popup.servidorHost, popup.servidorPuerto, id);
        popup.open();
    }

    background: Rectangle {
        color: Tema.colorPanel
        radius: 12 * Tema.escala
        border.width: 1
        border.color: Tema.colorAccent
    }

    contentItem: Column {
        spacing: 14 * Tema.escala

        Text {
            visible: !popup.datosListos
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Cargando perfil..."
            color: Tema.colorTextoTenue
            font.pixelSize: 13 * Tema.escala
        }

        Text {
            visible: popup.datosListos && popup.perfil.existe !== true
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Ese jugador ya no existe."
            color: Tema.colorTextoTenue
            font.pixelSize: 13 * Tema.escala
        }

        Column {
            visible: popup.datosListos && popup.perfil.existe === true
            width: parent.width
            spacing: 14 * Tema.escala

            Avatar {
                anchors.horizontalCenter: parent.horizontalCenter
                letra: (popup.perfil.username || "").length > 0 ? popup.perfil.username.charAt(0).toUpperCase() : "?"
                tamano: 64 * Tema.escala
                marco: Tema.marcoPorPartidasGanadas(popup.perfil.partidasGanadas || 0)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: popup.perfil.username || ""
                color: Tema.colorTexto
                font.family: Tema.fuenteElegante
                font.bold: true
                font.pixelSize: 18 * Tema.escala
            }

            // ── Estadísticas -- duplicado del panel Cuenta, ver el
            // comentario de arriba. Mismos umbrales/ocultación que ahí.
            Column {
                width: parent.width
                visible: (popup.perfil.partidasJugadas || 0) > 0
                spacing: 6 * Tema.escala
                Repeater {
                    model: [
                        { etiqueta: "Partidas jugadas", valor: (popup.perfil.partidasJugadas || 0) + "" },
                        { etiqueta: "Partidas ganadas", valor: (popup.perfil.partidasGanadas || 0) + "" },
                        { etiqueta: "Ratio de victorias", valor: Math.round(100 * (popup.perfil.partidasGanadas || 0) / (popup.perfil.partidasJugadas || 1)) + "%" },
                        { etiqueta: "Racha actual", valor: (popup.perfil.rachaActual || 0) + "" },
                        { etiqueta: "Mejor racha", valor: (popup.perfil.rachaMaxima || 0) + "" },
                        { etiqueta: "Manos jugadas", valor: (popup.perfil.manosJugadas || 0) + "" },
                        { etiqueta: "Manos ganadas", valor: (popup.perfil.manosGanadas || 0) + "" },
                        { etiqueta: "Mayor bote ganado", valor: (popup.perfil.mayorBote || 0) + "" },
                        { etiqueta: "Mejor mano", valor: (popup.perfil.mejorManoFecha || 0) > 0
                              ? popup.perfil.mejorManoNombre + " (" + new Date(popup.perfil.mejorManoFecha * 1000).toLocaleDateString() + ")"
                              : "—" }
                    ]
                    delegate: Row {
                        required property var modelData
                        width: parent.width
                        Text {
                            width: parent.width - 140 * Tema.escala
                            text: modelData.etiqueta
                            color: Tema.colorTextoTenue
                            font.pixelSize: 12 * Tema.escala
                        }
                        Text {
                            width: 140 * Tema.escala
                            text: modelData.valor
                            color: Tema.colorTexto
                            font.pixelSize: 12 * Tema.escala
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    text: "COMBINACIONES MOSTRADAS"
                    color: Tema.colorTextoMuyTenue
                    font.pixelSize: 10 * Tema.escala
                    font.letterSpacing: 1
                    topPadding: 6 * Tema.escala
                }
                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 12 * Tema.escala
                    rowSpacing: 4 * Tema.escala
                    Repeater {
                        model: [
                            { etiqueta: "Carta alta", valor: popup.perfil.vecesCartaAlta || 0 },
                            { etiqueta: "Pareja", valor: popup.perfil.vecesPareja || 0 },
                            { etiqueta: "Doble pareja", valor: popup.perfil.vecesDoblePareja || 0 },
                            { etiqueta: "Trío", valor: popup.perfil.vecesTrio || 0 },
                            { etiqueta: "Escalera", valor: popup.perfil.vecesEscalera || 0 },
                            { etiqueta: "Color", valor: popup.perfil.vecesColor || 0 },
                            { etiqueta: "Full House", valor: popup.perfil.vecesFullHouse || 0 },
                            { etiqueta: "Póker", valor: popup.perfil.vecesPoker || 0 },
                            { etiqueta: "Escalera de color", valor: popup.perfil.vecesEscaleraColor || 0 },
                            { etiqueta: "Escalera real", valor: popup.perfil.vecesEscaleraReal || 0 }
                        ]
                        delegate: Row {
                            required property var modelData
                            width: (parent.width - 12 * Tema.escala) / 2
                            Text {
                                width: parent.width - 30 * Tema.escala
                                text: modelData.etiqueta
                                color: modelData.valor > 0 ? Tema.colorTextoTenue : Tema.colorTextoMuyTenue
                                font.pixelSize: 11 * Tema.escala
                                elide: Text.ElideRight
                            }
                            Text {
                                width: 30 * Tema.escala
                                text: modelData.valor + ""
                                color: modelData.valor > 0 ? Tema.colorAccent : Tema.colorTextoMuyTenue
                                font.bold: modelData.valor > 0
                                font.pixelSize: 11 * Tema.escala
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }

            Text {
                visible: (popup.perfil.partidasJugadas || 0) === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Todavía no tiene estadísticas registradas."
                color: Tema.colorTextoTenue
                font.pixelSize: 12 * Tema.escala
            }
        }
    }
}
