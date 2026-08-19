// ChuletaFlotante.qml — ranking de manos de póker, en un Popup flotante
// (a diferencia del acordeón inline de escritorio) — pedido explícito: en
// una pantalla más pequeña, un acordeón dentro del propio cajón de
// ajustes competiría por el mismo espacio ya justo. Mismo patrón que
// CampoEmergente: Popup normal de Qt Quick Controls, se registra en
// EstadoOverlays para que el gesto de atrás la cierre sin código especial.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile
import QtQuick.Controls

Popup {
    id: chuletaFlotante

    modal: true
    focus: true
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: Math.min(parent.width - 48 * Tema.escala, 420 * Tema.escala)
    height: Math.min(parent.height - 48 * Tema.escala, 520 * Tema.escala)
    padding: 18 * Tema.escala
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    onOpened: EstadoOverlays.popupActivo = chuletaFlotante
    onClosed: if (EstadoOverlays.popupActivo === chuletaFlotante) EstadoOverlays.popupActivo = null

    background: Rectangle {
        color: Tema.colorPanel
        radius: 12 * Tema.escala
        border.width: 1
        border.color: Tema.colorBorde
    }

    contentItem: Column {
        spacing: 12 * Tema.escala

        Row {
            width: parent.width
            Text {
                width: parent.width - botonCerrarChuleta.width
                text: "Ranking de manos"
                color: "white"
                font.family: Tema.fuenteElegante
                font.pixelSize: 16 * Tema.escala
            }
            BotonContorno {
                id: botonCerrarChuleta
                text: "✕"
                onClicked: chuletaFlotante.close()
            }
        }

        ScrollView {
            width: parent.width
            height: parent.height - 40 * Tema.escala
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: chuletaFlotante.contentItem.width
                spacing: 12 * Tema.escala
                Repeater {
                    model: [
                        { nombre: "1. Escalera Real", cartas: ["AS", "KS", "QS", "JS", "TS"] },
                        { nombre: "2. Escalera Color", cartas: ["9H", "8H", "7H", "6H", "5H"] },
                        { nombre: "3. Póker", cartas: ["KS", "KH", "KD", "KC", "5S"] },
                        { nombre: "4. Full House", cartas: ["JS", "JH", "JD", "4C", "4S"] },
                        { nombre: "5. Color", cartas: ["AC", "JC", "8C", "6C", "2C"] },
                        { nombre: "6. Escalera", cartas: ["TS", "9H", "8D", "7C", "6S"] },
                        { nombre: "7. Trío", cartas: ["7S", "7H", "7D", "KC", "2S"] },
                        { nombre: "8. Doble Pareja", cartas: ["QS", "QH", "9D", "9C", "4S"] },
                        { nombre: "9. Pareja", cartas: ["TS", "TH", "KD", "6C", "2S"] },
                        { nombre: "10. Carta Alta", cartas: ["AS", "JH", "8D", "6C", "3S"] }
                    ]
                    delegate: Column {
                        required property var modelData
                        required property int index
                        width: parent.width
                        spacing: 4 * Tema.escala
                        Text {
                            text: modelData.nombre
                            color: index < 3 ? Tema.colorAccent : Tema.colorTextoTenue
                            font.bold: index < 3
                            font.pixelSize: 12 * Tema.escala
                        }
                        Row {
                            spacing: 3 * Tema.escala
                            Repeater {
                                model: modelData.cartas
                                delegate: Carta {
                                    required property string modelData
                                    codigo: modelData
                                    width: 42 * Tema.escala
                                    height: 58 * Tema.escala
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
