// RielNavegacion.qml (móvil) — mismo rol que el de escritorio (ver
// src/client-qt/qml/RielNavegacion.qml): riel vertical entre las 4
// pantallas "hub" (Salas/Ranking/Torneos/Social), separado del cajón de
// ajustes. Diferencia deliberada respecto a escritorio (decisión tomada
// en el propio lienzo de diseño): solo icono, sin etiqueta debajo -- en
// landscape corto el alto es el recurso escaso, no el ancho.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Rectangle {
    id: riel
    required property string pantallaActual
    signal seccionElegida(string nombre)

    // "Cuenta" añadida 2026-09-01 (Fase M1 del port de progresión a
    // móvil, ver memoria qt_mobile_progression_port_plan) -- mismo
    // criterio ya aprobado en escritorio: pantalla propia en el riel,
    // no escondida en el cajón de Ajustes (ver qt_account_drawer_ui_backlog).
    // "Tienda" añadida el mismo día (Fase M2) -- mismo orden que
    // escritorio (justo antes de Cuenta, las dos giran alrededor de la
    // misma cuenta/identidad).
    readonly property var secciones: ["Salas", "Ranking", "Torneos", "Social", "Tienda", "Cuenta"]
    // Sesión sin conexión (Fase 7) -- mismo criterio que el riel de
    // escritorio, pero aquí el modelo es de strings planos (no objetos),
    // así que la marca de "esto sí funciona offline" va en una lista
    // aparte en vez de un campo por sección. Ranking/Social/Tienda
    // dependen 100% del servidor; "Salas" sí, pero solo para montar una
    // partida local (no lista salas ajenas).
    property bool modoOffline: false
    readonly property var seccionesOffline: ["Salas", "Torneos", "Cuenta"]
    // Mismo criterio que el resto de componentes táctiles (ver Tema.qml,
    // móvil): nunca por debajo del suelo de accesibilidad, aunque la
    // escala calculada para el dispositivo diera menos.
    readonly property real tamanoIcono: Math.max(Tema.tamanoMinTactil, 44 * Tema.escala)

    width: riel.tamanoIcono + 20 * Tema.escala
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.35)
    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.4) }
        GradientStop { position: 1.0; color: Tema.colorPanel }
    }
    // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
    layer.enabled: true
    layer.effect: ShaderEffect {
        property variant source
        property real amplitud: 30.0
        fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
    }

    // Sin el "♣" + separador de arriba (2026-09-02, pedido explícito: "el
    // alto no da para alojar todo el riel actual... quita la parte
    // superior del trebol") -- con 6 secciones ya no cabía todo el riel
    // en landscape corto. El trébol de marca sigue en BarraSuperior.qml
    // (con brillo dorado nuevo, mismo turno), este era el segundo.
    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 10 * Tema.escala
        spacing: 12 * Tema.escala

        Repeater {
            model: riel.secciones
            delegate: Rectangle {
                id: cajaIcono
                required property string modelData
                required property int index
                readonly property bool activo: cajaIcono.modelData === riel.pantallaActual
                // Un Column omite del layout a los hijos invisibles.
                visible: !riel.modoOffline
                         || riel.seccionesOffline.indexOf(cajaIcono.modelData) !== -1
                anchors.horizontalCenter: parent.horizontalCenter
                width: riel.tamanoIcono
                height: riel.tamanoIcono
                radius: 14 * Tema.escala
                color: cajaIcono.activo ? Qt.rgba(1, 1, 1, 0.10) : (areaRiel.pressed ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                border.width: cajaIcono.activo ? 1 : 0
                border.color: Tema.colorAccent

                // Mismos cuatro glifos geométricos que en escritorio (ver
                // RielNavegacion.qml de qml/) -- sin depender de un
                // fichero compartido: ambos árboles QML ya son
                // independientes por diseño en todo el proyecto.
                Item {
                    id: glifo
                    anchors.centerIn: parent
                    width: 22 * Tema.escala
                    height: 22 * Tema.escala
                    readonly property color colorIcono: cajaIcono.activo ? Tema.colorAccent : Tema.colorTextoTenue

                    // Salas (0): dos barras horizontales.
                    Rectangle {
                        visible: cajaIcono.index === 0
                        x: 0; y: 3 * Tema.escala
                        width: glifo.width; height: 6 * Tema.escala
                        radius: 2 * Tema.escala
                        color: "transparent"
                        border.width: 1.6
                        border.color: glifo.colorIcono
                    }
                    Rectangle {
                        visible: cajaIcono.index === 0
                        x: 0; y: 13 * Tema.escala
                        width: glifo.width; height: 6 * Tema.escala
                        radius: 2 * Tema.escala
                        color: "transparent"
                        border.width: 1.6
                        border.color: glifo.colorIcono
                    }

                    // Ranking (1): tres barras a modo de podio.
                    Rectangle {
                        visible: cajaIcono.index === 1
                        x: 0; y: 9 * Tema.escala
                        width: 5 * Tema.escala; height: 13 * Tema.escala
                        color: glifo.colorIcono
                    }
                    Rectangle {
                        visible: cajaIcono.index === 1
                        x: 8.5 * Tema.escala; y: 3 * Tema.escala
                        width: 5 * Tema.escala; height: 19 * Tema.escala
                        color: glifo.colorIcono
                    }
                    Rectangle {
                        visible: cajaIcono.index === 1
                        x: 17 * Tema.escala; y: 12 * Tema.escala
                        width: 5 * Tema.escala; height: 10 * Tema.escala
                        color: glifo.colorIcono
                    }

                    // Torneos (2): llave de eliminatorias.
                    Rectangle {
                        visible: cajaIcono.index === 2
                        x: 0; y: 4 * Tema.escala
                        width: 9 * Tema.escala; height: 2 * Tema.escala
                        color: glifo.colorIcono
                    }
                    Rectangle {
                        visible: cajaIcono.index === 2
                        x: 0; y: 16 * Tema.escala
                        width: 9 * Tema.escala; height: 2 * Tema.escala
                        color: glifo.colorIcono
                    }
                    Rectangle {
                        visible: cajaIcono.index === 2
                        x: 9 * Tema.escala; y: 4 * Tema.escala
                        width: 2 * Tema.escala; height: 14 * Tema.escala
                        color: glifo.colorIcono
                    }
                    Rectangle {
                        visible: cajaIcono.index === 2
                        x: 9 * Tema.escala; y: 10 * Tema.escala
                        width: 13 * Tema.escala; height: 2 * Tema.escala
                        color: glifo.colorIcono
                    }

                    // Social (3): dos círculos superpuestos.
                    Rectangle {
                        visible: cajaIcono.index === 3
                        x: 1 * Tema.escala; y: 5 * Tema.escala
                        width: 12 * Tema.escala; height: 12 * Tema.escala
                        radius: width / 2
                        color: "transparent"
                        border.width: 1.6
                        border.color: glifo.colorIcono
                    }
                    Rectangle {
                        visible: cajaIcono.index === 3
                        x: 9 * Tema.escala; y: 5 * Tema.escala
                        width: 12 * Tema.escala; height: 12 * Tema.escala
                        radius: width / 2
                        color: "transparent"
                        border.width: 1.6
                        border.color: glifo.colorIcono
                    }

                    // Tienda (4): diamante hueco -- gema, mismo glifo
                    // exacto que escritorio (mismas coordenadas, el
                    // "glifo" mide 22*escala en los dos árboles).
                    Rectangle {
                        visible: cajaIcono.index === 4
                        x: 5 * Tema.escala; y: 5 * Tema.escala
                        width: 12 * Tema.escala; height: 12 * Tema.escala
                        rotation: 45
                        color: "transparent"
                        border.width: 1.6
                        border.color: glifo.colorIcono
                    }

                    // Cuenta (5): silueta de persona -- cabeza (círculo) +
                    // hombros (rectángulo redondeado), ambos huecos --
                    // mismo glifo exacto que escritorio (el "glifo" mide
                    // 22*escala en los dos árboles, así que las mismas
                    // coordenadas valen tal cual).
                    Rectangle {
                        visible: cajaIcono.index === 5
                        x: 7 * Tema.escala; y: 1 * Tema.escala
                        width: 8 * Tema.escala; height: 8 * Tema.escala
                        radius: width / 2
                        color: "transparent"
                        border.width: 1.6
                        border.color: glifo.colorIcono
                    }
                    Rectangle {
                        visible: cajaIcono.index === 5
                        x: 2 * Tema.escala; y: 11 * Tema.escala
                        width: 18 * Tema.escala; height: 11 * Tema.escala
                        radius: 8 * Tema.escala
                        color: "transparent"
                        border.width: 1.6
                        border.color: glifo.colorIcono
                    }
                }

                MouseArea {
                    id: areaRiel
                    anchors.fill: parent
                    onClicked: riel.seccionElegida(cajaIcono.modelData)
                }
            }
        }
    }
}
