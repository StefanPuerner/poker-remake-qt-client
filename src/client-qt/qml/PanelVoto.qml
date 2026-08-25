// PanelVoto.qml — los tres botones del voto de fin de mano. Se usa DOS
// veces (la fila de acciones normal, y dentro del overlay de showdown)
// para que se pueda votar sin dejar de ver las cartas reveladas; de ahí
// que esté sacado a un componente en vez de repetido a mano.
//
// "redcliente" es una context property de C++ (registrada en main.cpp),
// visible en cualquier fichero QML del módulo sin import — se llama
// directo desde aquí igual que se hacía antes. "votoAbierto"/"mensajeVoto"
// SÍ son estado propio de la pantalla que instancia esto, así que en vez
// de asumir que existen (como cuando este componente vivía dentro del
// mismo fichero), se avisa con señales y quien lo instancie decide qué
// hacer con su propio estado.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Row {
    id: panelVoto
    required property bool soyHost
    // Aproximación local a si ESTA partida ya cruzó el umbral antifarm del
    // servidor (ver MIN_CUENTAS_REALES_PARA_STATS/MIN_MANOS_PARA_STATS en
    // NetworkObserver.cpp) -- el cliente no sabe cuántas cuentas reales hay
    // en la mesa (nunca se le manda), así que quien instancia esto solo
    // comprueba lo que sí tiene a mano: si el propio jugador es invitado
    // (nunca cuenta, sea lo que sea el resto) y cuántas manos van jugadas.
    // Puede sobrar el aviso alguna vez (jugando solo contra bots con ≥5
    // manos, donde el servidor SÍ lo descartaría por no haber 2 cuentas
    // reales) pero nunca al revés -- jamás deja pasar un abandono que sí
    // vaya a contar sin avisar.
    required property bool contariaComoPerdida
    signal abandonar()
    signal guardarYSalir()

    spacing: 8 * Tema.escala
    BotonRelleno {
        text: "Continuar a la siguiente mano"
        // Ya NO cierra el panel al pulsar (antes emitía "continuar()" al
        // instante, optimista) -- quien instancie esto cierra su propio
        // "votoAbierto" solo al recibir el ack real del servidor
        // (NetworkClient::votoConfirmado(), evento VOTO_RECIBIDO). Si el
        // voto se escribía en un socket ya muerto sin detectar aún la
        // caída, el panel se cerraba igual y el usuario se quedaba con el
        // overlay de showdown abierto sin nada dentro (softlock real
        // reportado) -- ahora el panel se queda visible hasta confirmar.
        onClicked: redcliente.votar();
    }
    BotonContorno {
        text: "Abandonar partida"
        colorBorde: Tema.colorPeligro
        onClicked: {
            if (panelVoto.contariaComoPerdida) {
                confirmarAbandono.open();
            } else {
                redcliente.abandonar();
                panelVoto.abandonar();
            }
        }
    }
    BotonContorno {
        visible: soyHost
        text: "Guardar y salir"
        onClicked: {
            redcliente.guardarYSalir();
            guardarYSalir();
        }
    }

    // Ventana flotante de confirmación -- pedida explícitamente (2026-08-24)
    // tras añadir que abandonar cuenta como derrota en las estadísticas
    // (ver registrarDerrotaPorAbandono() en NetworkObserver.cpp): sin
    // avisar, "Abandonar partida" era un botón mudo que además ahora tiene
    // una consecuencia real que antes no tenía.
    Popup {
        id: confirmarAbandono
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(420 * Tema.escala, (parent ? parent.width : 420) - 60 * Tema.escala)
        padding: 20 * Tema.escala

        background: Rectangle {
            color: Tema.colorPanel
            radius: 12 * Tema.escala
            border.width: 1
            border.color: Tema.colorPeligro
        }

        contentItem: Column {
            spacing: 16 * Tema.escala
            Text {
                width: parent.width
                text: "¿Abandonar la partida?"
                color: Tema.colorTexto
                font.family: Tema.fuenteElegante
                font.bold: true
                font.pixelSize: 18 * Tema.escala
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: "Se contará como partida perdida en tus estadísticas si la partida ya lleva manos suficientes jugadas. Tus fichas se reparten entre el resto."
                color: Tema.colorTextoTenue
                font.pixelSize: 13 * Tema.escala
                wrapMode: Text.WordWrap
            }
            Row {
                width: parent.width
                spacing: 12 * Tema.escala
                BotonContorno {
                    width: (parent.width - parent.spacing) / 2
                    text: "Cancelar"
                    onClicked: confirmarAbandono.close()
                }
                BotonRelleno {
                    width: (parent.width - parent.spacing) / 2
                    text: "Abandonar"
                    colorBorde: Tema.colorPeligro
                    onClicked: {
                        redcliente.abandonar();
                        panelVoto.abandonar();
                        confirmarAbandono.close();
                    }
                }
            }
        }
    }
}
