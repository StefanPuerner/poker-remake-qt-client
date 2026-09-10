// BarraSuperior.qml (móvil) — versión reducida de la barra de escritorio,
// usada SOLO en Inicio/Salas/CrearSala (antes de sentarse a jugar). En
// Lobby/Partida/Fin la sustituye IconoAjustes.qml, no esto — ver Parte 7
// del plan de diseño móvil, punto 6. Sin estado de conexión ni
// host:puerto: en escritorio ocupan sitio siempre; aquí no aportan tanto a
// un jugador casual y cuestan una franja horizontal entera en una pantalla
// ya corta de alto — cuando exista el cajón de ajustes móvil, esa info
// vive ahí en vez de aquí. El botón de ajustes usa "pressed" en vez de
// "containsMouse" (no hay hover táctil) y respeta Tema.tamanoMinTactil.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile
// SOLO para el brillo dorado del trébol de marca (2026-09-02, pedido
// explícito: "pon el efecto dorado y brillo al trebol del logo en la
// barra superior") -- mismo criterio ya usado en el mini-riel/
// SelectorSegmentado, nativo de Qt 6.5+, sin coste de import nuevo en
// CMake.
import QtQuick.Effects

Item {
    id: barra
    property string textoCentro: ""
    // Saldo de Tréboles (Tienda) -- pedido explícito 2026-09-02: "hay
    // que encontrar mejor sitio para indicar cuantos treboles tienes...
    // en movil se coloca en la barra superior al lado del boton de
    // ajustes". -1 = no mostrar (resto de pantallas no lo necesitan).
    property int treboles: -1
    signal abrirAjustes()
    height: Math.max(Tema.tamanoMinTactil + 16 * Tema.escala, 56 * Tema.escala)

    // Sombra plana desplazada hacia abajo -- port del bloque gemelo de
    // escritorio, que al móvil no se le trasladó en su día (2026-09-09).
    // Un rectángulo negro a media opacidad, no un desenfoque de verdad:
    // sale gratis y a este tamaño de desplazamiento no se distingue.
    // Declarado ANTES que fondoBarra para quedar detrás.
    // Sombra en TRES pasadas, cada una un poco más abajo y más
    // tenue. Un solo rectángulo negro desplazado se veía "muy
    // sencillo" (reportado 2026-09-09) porque tiene el canto tan
    // duro como la propia barra: parece otra barra detrás, no una
    // sombra. Escalonarlas imita un desenfoque a ojo, y sale
    // gratis -- ningún efecto, ninguna capa, tres Rectangle.
    Repeater {
        model: [{ d: 2, o: 0.22 }, { d: 5, o: 0.16 }, { d: 9, o: 0.10 }]
        delegate: Rectangle {
            required property var modelData
            anchors.left: fondoBarra.left
            anchors.right: fondoBarra.right
            anchors.top: fondoBarra.top
            anchors.topMargin: modelData.d * Tema.escala
            height: fondoBarra.height
            radius: fondoBarra.radius
            color: "black"
            opacity: modelData.o
        }
    }

    Rectangle {
        id: fondoBarra
        anchors.fill: parent
        radius: 14 * Tema.escala
        // Borde casi invisible (solo define el canto contra el fondo) y
        // un filo claro SOLO arriba -- el volumen lo dan el degradado y
        // la sombra de debajo, no un contorno de 1px en los cuatro lados,
        // que se veía plano "de maqueta".
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.3)
        // Cuatro paradas en vez de dos: claro arriba, un corte a media
        // altura (el reflejo que cruza una pieza de metal) y algo más
        // oscuro abajo. Va aquí dentro, y no en una capa de brillo
        // aparte, porque este degradado ya pasa por el dithering de
        // abajo -- una capa suelta habría bandeado igual que bandeó el
        // primer MarcoHueco.
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.9) }
            GradientStop { position: 0.46; color: Qt.lighter(Tema.colorPanel, 1.3) }
            GradientStop { position: 0.54; color: Tema.colorPanel }
            GradientStop { position: 1.0; color: Qt.darker(Tema.colorPanel, 1.14) }
        }
        // Dithering (Interleaved Gradient Noise) -- ver assets/shaders/dither.frag.
        layer.enabled: true
        layer.effect: ShaderEffect {
            property variant source
            property real amplitud: 30.0
            fragmentShader: "qrc:/qt/qml/PokerQuickMobile/assets/shaders/dither_movil.frag.qsb"
        }

        // Filo iluminado del borde de arriba, como si la luz rozara una
        // superficie ligeramente elevada. Metido a 14px por cada lado
        // para que muera antes de las esquinas redondeadas.
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14 * Tema.escala
            anchors.rightMargin: 14 * Tema.escala
            height: 1
            color: Qt.rgba(1, 1, 1, 0.22)
        }

        // Canto oscuro de abajo -- cierra el volumen por el otro lado.
        // Sin él, la barra tiene luz arriba y nada abajo, y se lee plana.
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14 * Tema.escala
            anchors.rightMargin: 14 * Tema.escala
            anchors.bottomMargin: 1
            height: 1
            color: Qt.rgba(0, 0, 0, 0.45)
        }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16 * Tema.escala
            spacing: 8 * Tema.escala
            // Envuelto en un Item -- dentro de un Row (positioner) un hijo
            // no puede anclarse a otro hijo ("Cannot anchor to an item
            // that isn't a parent or sibling" si se intenta directo desde
            // fuera de un Item propio, y el propio Row ya se encarga de
            // la "x" de cada hijo, con lo que un MultiEffect suelto como
            // hijo del Row competiría con eso). El wrapper mide igual que
            // el trébol, así que no le come sitio de más a "PokerRemake".
            Item {
                width: treboLogoMovil.width
                height: treboLogoMovil.height
                Text {
                    id: treboLogoMovil
                    text: "♣"
                    color: Qt.darker(Tema.colorAccent, 1.15)
                    font.pixelSize: 20 * Tema.escala
                }
                // Reflejo/brillo -- pedido explícito 2026-09-02: "no solo
                // quiero el resplandor... sino tambien el reflejo/brillo
                // que tenian los botones" (el degradado metálico de 3
                // paradas del mini-riel/SelectorSegmentado). Un Text no
                // admite degradado de relleno -- mismo truco "barato" que
                // el resto del proyecto (aproximar con capas en vez de un
                // shader): una segunda copia del glifo en un tono más
                // claro, recortada a solo el tercio de arriba, imita el
                // brillo superior del degradado sin dibujar nada a mano.
                Item {
                    anchors.fill: treboLogoMovil
                    height: treboLogoMovil.height * 0.42
                    clip: true
                    Text {
                        text: "♣"
                        color: Qt.lighter(Tema.colorAccent, 1.5)
                        font.pixelSize: treboLogoMovil.font.pixelSize
                    }
                }
                // Brillo dorado real detrás del trébol de marca -- mismo
                // criterio que el mini-riel/SelectorSegmentado.
                MultiEffect {
                    anchors.fill: treboLogoMovil
                    source: treboLogoMovil
                    autoPaddingEnabled: true
                    shadowEnabled: true
                    shadowColor: Tema.colorAccent
                    shadowOpacity: 0.6
                    shadowBlur: 0.7
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                    z: -1
                }
            }
            Text {
                text: "PokerRemake"
                color: Tema.colorTexto
                font.bold: true
                font.pixelSize: 16 * Tema.escala
                font.family: Tema.fuenteElegante
            }
        }

        Text {
            visible: barra.textoCentro !== ""
            anchors.centerIn: parent
            color: Tema.colorTextoTenue
            text: barra.textoCentro
            font.pixelSize: 13 * Tema.escala
        }

        Row {
            visible: barra.treboles >= 0
            anchors.right: botonAjustesBarra.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 14 * Tema.escala
            spacing: 4 * Tema.escala
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: barra.treboles + ""
                color: Tema.colorAccent
                font.bold: true
                font.pixelSize: 13 * Tema.escala
            }
            IconoTrebol {
                width: 11 * Tema.escala
                height: width
                anchors.verticalCenter: parent.verticalCenter
                colorTrebol: Tema.colorAccent
            }
        }

        // Botón de ajustes en relieve (2026-09-09). Antes era un círculo
        // transparente con un contorno de 1px: sobre la barra, que ya
        // tiene su degradado y su textura, no se separaba de ella -- el
        // usuario lo señaló junto con los campos de texto. Ahora
        // sobresale de verdad (sombra + degradado + filo), y al pulsar se
        // hunde y se tiñe de dorado.
        MarcoRelieve {
            id: botonAjustesBarra
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 12 * Tema.escala
            width: Tema.tactil
            height: Tema.tactil
            radioMarco: width / 2
            pulsado: areaAjustes.pressed
            colorBase: areaAjustes.pressed ? Tema.colorAccent : Tema.colorPanel

            Column {
                anchors.centerIn: parent
                spacing: 3 * Tema.escala
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        width: 4 * Tema.escala
                        height: 4 * Tema.escala
                        radius: width / 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: areaAjustes.pressed ? Tema.colorPanel : Tema.colorTextoTenue
                    }
                }
            }
            MouseArea {
                id: areaAjustes
                anchors.fill: parent
                onClicked: barra.abrirAjustes()
            }
        }
    }
}
