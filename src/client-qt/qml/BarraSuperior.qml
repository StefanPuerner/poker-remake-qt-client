// BarraSuperior.qml — compartida por todas las pantallas salvo Inicio (ahí
// no hay nada de sala/conexión que mostrar todavía) — mismo lenguaje
// visual en todo el programa: logo a la izquierda, algo de contexto en el
// centro (opcional, cada pantalla decide qué vía "textoCentro"), y a la
// derecha el estado de conexión + saldo (solo en Partida) + el botón de
// ajustes. Extraída de Main.qml — los datos de sesión (pantalla actual,
// saldo, conexión...) que antes leía sin cualificar ahora llegan como
// "required property" desde cada sitio donde se instancia (son 5).
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: barra
    property string textoCentro: ""
    property bool mostrarSaldo: false
    // Solo tiene sentido en Partida (chuleta de combinaciones) — igual
    // criterio que mostrarSaldo, en vez de mostrar el botón siempre y
    // que quien lo pulse en Lobby/Salas no tenga nada que ver.
    property bool mostrarChuleta: false
    // "Refrescar"/"Salir" -- antes vivían como dos píldoras sueltas al
    // final de la pantalla Salas, descolgadas del resto del rediseño
    // (rejilla de tarjetas + barra de pestañas arriba, ver Main.qml).
    // Mismo criterio que mostrarChuleta: solo Salas los activa hoy, pero
    // cualquier pantalla futura con sentido de "refrescar"/"salir" puede
    // reutilizarlos sin más.
    property bool mostrarRefrescar: false
    property bool mostrarSalir: false
    required property string pantalla
    required property int miSaldoActual
    required property bool reconectandoAhora
    required property string servidorHost
    required property int servidorPuerto
    // El botón de ajustes solo TOGGLEA "ajustesAbiertos" — nunca necesita
    // leer su valor actual para mostrar nada aquí — así que basta con una
    // señal en vez de pasarlo también como required property.
    signal abrirAjustes()
    signal abrirChuleta()
    signal refrescar()
    signal salir()
    height: 50 * Tema.escala
    // Flota en vez de ir pegada al borde — margen a los tres lados
    // puesto aquí (no en cada sitio donde se usa) para que las cinco
    // pantallas queden iguales sin repetirlo cinco veces.
    anchors.margins: 16 * Tema.escala

    // Sombra barata: un rectángulo semitransparente desplazado, sin
    // blur de verdad — ver el catálogo "Sistema visual", sección 15.
    // Al ser un único elemento por pantalla (no 17 cartas a la vez),
    // el coste es irrelevante; aun así se usa la receta barata por
    // coherencia con el resto del programa.
    Rectangle {
        anchors.left: fondoBarra.left
        anchors.right: fondoBarra.right
        anchors.top: fondoBarra.top
        anchors.topMargin: 4
        height: fondoBarra.height
        radius: fondoBarra.radius
        color: "black"
        opacity: 0.28
    }

    Rectangle {
        id: fondoBarra
        anchors.fill: parent
        radius: 14 * Tema.escala
        // Antes un contorno de 1px del mismo color en los cuatro
        // lados — se veía plano, "de maqueta". En vez de eso: borde
        // casi invisible (solo define el canto contra el fondo) y un
        // filo claro SOLO arriba, como si la luz rozara el borde
        // superior de una superficie ligeramente elevada — el resto
        // del volumen ya lo dan el degradado y la sombra de debajo.
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.3)
        // Degradado sutil en vez de color plano — deriva de
        // colorPanel con Qt.lighter() para que funcione igual en los
        // cuatro temas sin tener que definir un valor por tema.
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(Tema.colorPanel, 1.55) }
            GradientStop { position: 1.0; color: Tema.colorPanel }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            height: 1
            color: Qt.rgba(1, 1, 1, 0.12)
        }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            spacing: 8 * Tema.escala
            Text {
                text: "♣"
                color: Tema.colorAccent
                font.pixelSize: 20 * Tema.escala
            }
            Text {
                text: "PokerRemake"
                color: Tema.colorTexto
                font.bold: true
                font.pixelSize: 16 * Tema.escala
                font.family: Tema.fuenteElegante
                // Row no centra verticalmente hijos de distinto tamaño (el
                // trébol es más grande) — se baja a mano.
                y: 4 * Tema.escala
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
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 16
            spacing: 16 * Tema.escala

            Text {
                visible: barra.mostrarSaldo
                anchors.verticalCenter: parent.verticalCenter
                text: barra.miSaldoActual + " fichas"
                color: Tema.colorAccent
                font.bold: true
                font.pixelSize: 13 * Tema.escala
            }

            // Estado de conexión: Lobby/Partida/Fin solo se llega a ellas
            // tras una conexión persistente ya establecida (onConectado/
            // onPartidaIniciada/onFinDePartida) — Salas/CrearSala usan
            // sockets efímeros por petición (refrescarSalas), así que ahí
            // no hay "conectado" de verdad todavía, solo el destino.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * Tema.escala
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7 * Tema.escala
                    height: 7 * Tema.escala
                    radius: width / 2
                    color: barra.reconectandoAhora ? Tema.colorPeligro
                           : (barra.pantalla === "Lobby" || barra.pantalla === "Partida" || barra.pantalla === "Fin") ? "#7FAE7A"
                           : Tema.colorTextoMuyTenue
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (barra.reconectandoAhora ? "Reconectando… · " : "") + barra.servidorHost + ":" + barra.servidorPuerto
                    color: Tema.colorTextoMuyTenue
                    font.pixelSize: 11 * Tema.escala
                }
            }

            Rectangle {
                id: botonChuletaBarra
                visible: barra.mostrarChuleta
                anchors.verticalCenter: parent.verticalCenter
                width: 30 * Tema.escala
                height: 30 * Tema.escala
                radius: width / 2
                border.width: 1
                border.color: botonChuletaBarraArea.containsMouse ? Tema.colorAccent : Tema.colorBorde
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: botonChuletaBarraArea.containsMouse ? Qt.lighter(Tema.colorAccent, 1.3) : "transparent"
                    }
                    GradientStop {
                        position: 0.5
                        color: botonChuletaBarraArea.containsMouse ? Tema.colorAccent : "transparent"
                    }
                    GradientStop {
                        position: 1.0
                        color: botonChuletaBarraArea.containsMouse ? Qt.darker(Tema.colorAccent, 1.25) : "transparent"
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: "?"
                    font.bold: true
                    font.pixelSize: 14 * Tema.escala
                    color: botonChuletaBarraArea.containsMouse ? Tema.colorPanel : Tema.colorTextoTenue
                }
                MouseArea {
                    id: botonChuletaBarraArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: barra.abrirChuleta()
                }
            }

            Rectangle {
                id: botonRefrescarBarra
                visible: barra.mostrarRefrescar
                anchors.verticalCenter: parent.verticalCenter
                width: 30 * Tema.escala
                height: 30 * Tema.escala
                radius: width / 2
                border.width: 1
                border.color: botonRefrescarBarraArea.containsMouse ? Tema.colorAccent : Tema.colorBorde
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: botonRefrescarBarraArea.containsMouse ? Qt.lighter(Tema.colorAccent, 1.3) : "transparent"
                    }
                    GradientStop {
                        position: 0.5
                        color: botonRefrescarBarraArea.containsMouse ? Tema.colorAccent : "transparent"
                    }
                    GradientStop {
                        position: 1.0
                        color: botonRefrescarBarraArea.containsMouse ? Qt.darker(Tema.colorAccent, 1.25) : "transparent"
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: "↻"
                    font.bold: true
                    font.pixelSize: 17 * Tema.escala
                    color: botonRefrescarBarraArea.containsMouse ? Tema.colorPanel : Tema.colorTextoTenue
                }
                MouseArea {
                    id: botonRefrescarBarraArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: barra.refrescar()
                }
            }

            // Píldora de texto (no un icono circular como el resto) --
            // "salir" es una acción con más peso (desconecta de verdad),
            // el color de peligro solo es inequívoco acompañado de la
            // palabra.
            Rectangle {
                id: botonSalirBarra
                visible: barra.mostrarSalir
                anchors.verticalCenter: parent.verticalCenter
                height: 26 * Tema.escala
                width: textoSalirBarra.implicitWidth + 20 * Tema.escala
                radius: height / 2
                border.width: 1
                border.color: Tema.colorPeligro
                color: botonSalirBarraArea.containsMouse ? Tema.colorPeligro : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    id: textoSalirBarra
                    anchors.centerIn: parent
                    text: "Salir"
                    font.pixelSize: 12 * Tema.escala
                    color: botonSalirBarraArea.containsMouse ? Tema.colorPanel : Tema.colorPeligro
                }
                MouseArea {
                    id: botonSalirBarraArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: barra.salir()
                }
            }

            Rectangle {
                id: botonAjustesBarra
                anchors.verticalCenter: parent.verticalCenter
                width: 30 * Tema.escala
                height: 30 * Tema.escala
                radius: width / 2
                border.width: 1
                border.color: botonAjustesBarraArea.containsMouse ? Tema.colorAccent : Tema.colorBorde
                // Metálico al pasar el ratón — mismo degradado de 3
                // paradas que el resto de botones "de acento" (ver
                // BotonRelleno), en vez de un color plano de hover. Una
                // sola parada no puede ser "condicional" en QML (no se
                // puede asignar un Gradient entero con "? :"), así que
                // cada GradientStop se vuelve transparente cuando no
                // hay hover — el efecto es el mismo que no pintar nada.
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: botonAjustesBarraArea.containsMouse ? Qt.lighter(Tema.colorAccent, 1.3) : "transparent"
                    }
                    GradientStop {
                        position: 0.5
                        color: botonAjustesBarraArea.containsMouse ? Tema.colorAccent : "transparent"
                    }
                    GradientStop {
                        position: 1.0
                        color: botonAjustesBarraArea.containsMouse ? Qt.darker(Tema.colorAccent, 1.25) : "transparent"
                    }
                }
                // Tres puntos de verdad (Rectangle redondos) en vez del
                // carácter "⋮" — el glifo depende de la fuente y ni
                // queda perfectamente centrado ni perfectamente redondo.
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
                            color: botonAjustesBarraArea.containsMouse ? Tema.colorPanel : Tema.colorTextoTenue
                        }
                    }
                }
                MouseArea {
                    id: botonAjustesBarraArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: barra.abrirAjustes()
                }
            }
        }
    }
}
