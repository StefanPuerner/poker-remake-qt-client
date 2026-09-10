// Main.qml (AvatarTest) — banco de pruebas de los marcos de avatar. Cada
// fila muestra los 7 marcos posibles al mismo tamaño, en tres tamaños
// distintos: uno grande "de detalle" y los dos tamaños reales que se
// verán en la app de verdad (Asiento y fila de Ranking).
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: ventana
    visible: true
    width: 1500
    height: ventana.soloCosmeticos ? 1260 : 950
    title: "Banco de pruebas — marcos y cosméticos de avatar"
    color: Tema.colorFondo

    // OJO al capturar sin pantalla (QT_QPA_PLATFORM=offscreen): el aro y
    // el círculo interior llevan un ShaderEffect (el dithering de los
    // degradados) que ahí NO se dibuja, así que salen vacíos y solo se ven
    // las texturas y decoraciones "flotando". Sirve para revisar la
    // geometría, no el resultado final -- para eso, abrir el banco en el
    // escritorio de verdad.
    //
    // Las pone main.cpp desde la línea de órdenes (ver allí). Con
    // "--solo-cosmeticos" el banco enseña ÚNICAMENTE la parte de Fase 5,
    // que así cabe entera en la ventana y se puede capturar de un tirón
    // con "--captura"; sin eso, hay que hacer scroll y una captura solo
    // pilla el trozo visible.
    property bool soloCosmeticos: false
    property int temaInicial: 0
    Component.onCompleted: Tema.temaActual = ventana.temaInicial

    // Todo lo comprable de Fase 5, en un sitio. La lista está a mano (no
    // sale de la base de datos) a propósito: el banco no habla con el
    // servidor, y así también se ve lo que TODAVÍA no está sembrado.
    readonly property var texturas: ["", "trenzado", "grabado", "facetado", "canto_ficha"]
    readonly property var decoracionesLaterales: [
        "gema_roja", "gema_azul", "punto_de_luz", "pila_fichas", "cinta_ondulada",
        "carta_ace_picas", "carta_queen_corazones"
    ]
    readonly property var decoracionesSuperiores: [
        "corona_inicial", "corona_laurel", "corona_real", "constelacion",
        "palos_en_fila", "ojo_vigilante", "colmillo",
        "mano_real", "escalera_diamantes", "cuatro_ases"
    ]

    readonly property var marcos: [
        { valor: "ninguno", etiqueta: "Sin marco" },
        { valor: "bronce", etiqueta: "Bronce" },
        { valor: "plata", etiqueta: "Plata" },
        { valor: "oro", etiqueta: "Oro" },
        { valor: "platino", etiqueta: "Platino" },
        { valor: "campeonVictorias", etiqueta: "Podio 1º · victorias" },
        { valor: "campeonVictorias2", etiqueta: "Podio 2º · victorias" },
        { valor: "campeonVictorias3", etiqueta: "Podio 3º · victorias" },
        { valor: "campeonRatio", etiqueta: "Podio 1º · ratio" },
        { valor: "campeonRatio2", etiqueta: "Podio 2º · ratio" },
        { valor: "campeonRatio3", etiqueta: "Podio 3º · ratio" }
    ]

    ScrollView {
        anchors.fill: parent
        anchors.margins: 32
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Column {
            width: ventana.width - 64
            spacing: 40

            Text {
                text: "Marcos de avatar — banco de pruebas"
                color: "white"
                font.family: Tema.fuenteElegante
                font.pixelSize: 26
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Mismo Avatar.qml/Tema.qml que usará el cliente real -- colores, fuente y proporciones exactas. Los dos últimos (campeón) están animados de verdad."
                color: Tema.colorTextoTenue
                font.pixelSize: 13
            }

            // Cambiar de tema aquí importa más de lo que parece: los
            // iconos que se veían bien sobre el verde clásico
            // DESAPARECÍAN sobre "Porcelana dorada" (bug real reportado
            // 2026-09-09, constelación era blanco puro). Revisar un
            // cosmético nuevo en los dos extremos, siempre.
            Row {
                spacing: 8
                Repeater {
                    model: Tema.temas
                    delegate: Button {
                        required property var modelData
                        required property int index
                        text: modelData.nombre
                        checkable: true
                        checked: Tema.temaActual === index
                        onClicked: Tema.temaActual = index
                    }
                }
            }

            // ── Acabado por material (fase 1, 2026-09-10) ────────────────
            // La misma decoración sobre los cinco marcos: cada una debería
            // salir en el metal de su marco (el oro, en el dorado de
            // siempre). Primera sección a propósito, para que entre en una
            // captura sin hacer scroll.
            Column {
                width: parent.width
                spacing: 14
                Text {
                    text: "ACABADO POR MATERIAL (laurel arriba, cinta a los lados, 120px)"
                    color: Tema.colorAccent
                    font.pixelSize: 12
                    font.letterSpacing: 1
                }
                Flow {
                    width: parent.width
                    spacing: 26
                    Repeater {
                        model: ["hierro", "bronce", "plata", "oro", "platino"]
                        delegate: Column {
                            required property string modelData
                            spacing: 6
                            Item {
                                width: 210
                                height: 200
                                Avatar {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    letra: "S"; marco: modelData; tamano: 120
                                    decoracionSuperior: "corona_laurel"
                                    decoracionLateral1: "cinta_ondulada"
                                    decoracionLateral2: "cinta_ondulada"
                                }
                            }
                            Text {
                                width: 210
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: Tema.colorTextoTenue
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }

            // ── Fase 5: texturas ─────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 14
                Text {
                    text: "TEXTURAS (sobre marco de oro, 140px y 56px)"
                    color: Tema.colorAccent
                    font.pixelSize: 12
                    font.letterSpacing: 1
                }
                Flow {
                    width: parent.width
                    spacing: 30
                    Repeater {
                        model: ventana.texturas
                        delegate: Column {
                            required property string modelData
                            spacing: 8
                            Row {
                                spacing: 12
                                Avatar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    letra: "S"; marco: "oro"; tamano: 140
                                    textura: modelData
                                }
                                Avatar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    letra: "S"; marco: "oro"; tamano: 56
                                    textura: modelData
                                }
                            }
                            Text {
                                text: modelData === "" ? "pulido (sin textura)" : modelData
                                color: Tema.colorTextoTenue
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }

            // ── Fase 5: decoraciones laterales ───────────────────────────
            Column {
                width: parent.width
                spacing: 14
                Text {
                    text: "DECORACIONES LATERALES (las dos a la vez, 120px)"
                    color: Tema.colorAccent
                    font.pixelSize: 12
                    font.letterSpacing: 1
                }
                Flow {
                    width: parent.width
                    spacing: 26
                    Repeater {
                        model: ventana.decoracionesLaterales
                        delegate: Column {
                            required property string modelData
                            spacing: 6
                            Item {
                                // Hueco fijo y ancho: las decoraciones
                                // laterales sobresalen por los dos lados
                                // del anillo (139px a 120 de tamaño), así
                                // que sin esto se pisan entre celdas.
                                width: 210
                                height: 140
                                Avatar {
                                    anchors.centerIn: parent
                                    letra: "S"; marco: "oro"; tamano: 120
                                    decoracionLateral1: modelData
                                    decoracionLateral2: modelData
                                }
                            }
                            Text {
                                width: 210
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: Tema.colorTextoTenue
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            // ── Fase 5: decoraciones superiores ──────────────────────────
            Column {
                width: parent.width
                spacing: 14
                Text {
                    text: "DECORACIONES SUPERIORES (120px)"
                    color: Tema.colorAccent
                    font.pixelSize: 12
                    font.letterSpacing: 1
                }
                Flow {
                    width: parent.width
                    spacing: 26
                    Repeater {
                        model: ventana.decoracionesSuperiores
                        delegate: Column {
                            required property string modelData
                            spacing: 6
                            Item {
                                // Hueco fijo: las coronas de cartas se
                                // salen bastante por arriba y por los
                                // lados del avatar, y sin esto descuadran
                                // la fila entera.
                                width: 200
                                height: 200
                                Avatar {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    letra: "S"; marco: "oro"; tamano: 120
                                    decoracionSuperior: modelData
                                }
                            }
                            Text {
                                width: 200
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: Tema.colorTextoTenue
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            // ── Tamaño de detalle ────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 14
                // Un Column salta a sus hijos invisibles, así que con esto
                // basta para dejar la ventana con solo la parte de Fase 5.
                visible: !ventana.soloCosmeticos
                Text {
                    text: "TAMAÑO DE DETALLE (140px)"
                    color: Tema.colorAccent
                    font.pixelSize: 12
                    font.letterSpacing: 1
                }
                Flow {
                    width: parent.width
                    spacing: 36
                    Repeater {
                        model: ventana.marcos
                        delegate: Column {
                            required property var modelData
                            spacing: 10
                            Avatar {
                                anchors.horizontalCenter: parent.horizontalCenter
                                letra: "S"
                                marco: modelData.valor
                                tamano: 140
                            }
                            Text {
                                width: 140
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.etiqueta
                                color: Tema.colorTextoTenue
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            // ── Tamaño real: Asiento (mesa) ──────────────────────────────
            Column {
                width: parent.width
                spacing: 14
                // Un Column salta a sus hijos invisibles, así que con esto
                // basta para dejar la ventana con solo la parte de Fase 5.
                visible: !ventana.soloCosmeticos
                Text {
                    text: "TAMAÑO REAL — ASIENTO (56px)"
                    color: Tema.colorAccent
                    font.pixelSize: 12
                    font.letterSpacing: 1
                }
                Rectangle {
                    width: parent.width
                    height: flowAsiento.implicitHeight + 28
                    radius: 8
                    color: Tema.colorTapete
                    Flow {
                        id: flowAsiento
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 14
                        spacing: 24
                        Repeater {
                            model: ventana.marcos
                            delegate: Column {
                                required property var modelData
                                spacing: 6
                                Avatar {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    letra: "S"
                                    marco: modelData.valor
                                    tamano: 56
                                }
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: "black"
                                    opacity: 0.7
                                    radius: 6
                                    width: nombreAsiento.width + 12
                                    height: nombreAsiento.height + 6
                                    Text {
                                        id: nombreAsiento
                                        anchors.centerIn: parent
                                        text: "Stefan"
                                        color: "white"
                                        font.pixelSize: 11
                                        font.family: Tema.fuenteElegante
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Tamaño real: fila de Ranking ─────────────────────────────
            Column {
                width: parent.width
                spacing: 14
                // Un Column salta a sus hijos invisibles, así que con esto
                // basta para dejar la ventana con solo la parte de Fase 5.
                visible: !ventana.soloCosmeticos
                Text {
                    text: "TAMAÑO REAL — FILA DE RANKING (30px)"
                    color: Tema.colorAccent
                    font.pixelSize: 12
                    font.letterSpacing: 1
                }
                Column {
                    width: Math.min(560, parent.width)
                    spacing: 6
                    Repeater {
                        model: ventana.marcos
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: parent.width
                            height: 46
                            radius: 8
                            color: "#1a3a2a"
                            border.width: 1
                            border.color: Qt.rgba(0, 0, 0, 0.3)
                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12
                                Text {
                                    width: 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (index + 1) + ""
                                    color: Tema.colorAccent
                                    font.family: Tema.fuenteElegante
                                    font.pixelSize: 14
                                }
                                Avatar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    letra: "S"
                                    marco: modelData.valor
                                    tamano: 30
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Stefan — " + modelData.etiqueta
                                    color: "white"
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
