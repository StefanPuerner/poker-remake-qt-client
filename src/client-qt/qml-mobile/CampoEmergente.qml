// CampoEmergente.qml — Popup de entrada de texto anclado ARRIBA de la
// pantalla: el teclado de Android crece desde abajo, así que aquí nunca
// tapa nada. Punto 2 del plan de diseño móvil (Parte 7). Cualquier campo
// puntual/poco frecuente (nombre de jugador, nombre de sala, código de
// sala, "toca el número para un valor exacto" de SelectorNumerico) abre
// esto en vez de un TextField inline.
//
// Modo "soloNumerico": el campo pasa a readOnly (el teclado del sistema
// de Android NI SIQUIERA se activa) y en su lugar aparece TecladoNumerico
// — más compacto y consistente que el teclado numérico del sistema, que
// varía de tamaño entre fabricantes. Pensado sobre todo para el importe
// de subida, el numérico más usado de toda una partida.
//
// Es un Popup normal de Qt Quick Controls: "opened"/"close()" ya vienen
// gratis, así que encaja directo en manejarAtras() (punto 3 del plan) sin
// código especial — el gestor de atrás solo necesita llamar a close() y
// esto ya cuenta como "cancelado", pase lo que pase (back, tocar fuera,
// o el botón Cancelar).
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile
import QtQuick.Controls

Popup {
    id: campoEmergente
    property string etiqueta: ""
    property bool soloNumerico: false
    property bool esPassword: false
    property int maxLongitud: 32
    signal aceptado(string texto)
    signal cancelado()

    // Distingue un close() por "Aceptar" (ya emitió aceptado(), no hace
    // falta emitir también cancelado()) de cualquier otro cierre (back,
    // tocar fuera, botón Cancelar) — esos SÍ cuentan como cancelar.
    property bool _confirmando: false

    // Botón de ojo (mostrar/ocultar) -- pedido real de usuarios que lo
    // echaban en falta, sobre todo en móvil (2026-09-14). Siempre arranca
    // oculta cada vez que se abre el popup, aunque la última vez se
    // hubiera dejado visible -- no hay motivo para recordar ese estado
    // entre una contraseña y la siguiente.
    property bool mostrarPassword: false

    function abrir(valorInicial) {
        campoTexto.text = valorInicial !== undefined ? valorInicial : "";
        mostrarPassword = false;
        _confirmando = false;
        open();
    }

    function confirmar() {
        _confirmando = true;
        // Confirma lo que el teclado aún tiene "a medio escribir" (región de
        // composición del IME): TextField.text NO incluye ese texto, así que
        // una contraseña de 8 caracteres con los últimos sin confirmar se leía
        // de 7 y se rechazaba por corta (reportado 2026-09-20 con una
        // contraseña de letras y números).
        Qt.inputMethod.commit();
        aceptado(campoTexto.text);
        close();
    }

    modal: true
    focus: true
    x: (parent.width - width) / 2
    // "y" y "padding" recortados: en modo soloNumerico (con TecladoNumerico
    // visible) el conjunto entero superaba la altura de la pantalla en un
    // móvil de landscape corto -- visto en real, se salía por abajo.
    y: 12 * Tema.escala
    width: Math.min(parent.width - 48 * Tema.escala, 480 * Tema.escala)
    padding: 14 * Tema.escala
    // Tocar fuera SÍ cierra (cancela) — coherente con que el gesto de
    // atrás también cancela. Solo Escape además, por probarlo en escritorio.
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    onOpened: {
        if (!soloNumerico) campoTexto.forceActiveFocus();
        EstadoOverlays.popupActivo = campoEmergente;
    }
    onClosed: {
        if (!_confirmando) cancelado();
        _confirmando = false;
        if (EstadoOverlays.popupActivo === campoEmergente) EstadoOverlays.popupActivo = null;
    }

    background: Rectangle {
        color: Tema.colorPanel
        radius: 12 * Tema.escala
        border.width: 1
        border.color: Tema.colorBorde
    }

    contentItem: Column {
        spacing: 14 * Tema.escala

        Text {
            visible: campoEmergente.etiqueta !== ""
            width: parent.width
            text: campoEmergente.etiqueta
            color: Tema.colorTextoTenue
            font.pixelSize: 13 * Tema.escala
        }

        Rectangle {
            width: parent.width
            height: 48 * Tema.escala
            radius: 8 * Tema.escala
            color: Tema.colorFondo
            border.width: 1
            border.color: Tema.colorBorde

            TextField {
                id: campoTexto
                anchors.fill: parent
                anchors.margins: 4 * Tema.escala
                anchors.rightMargin: campoEmergente.esPassword ? Tema.tactil : 4 * Tema.escala
                readOnly: campoEmergente.soloNumerico
                // esPassword: contraseñas (login/registro/cambiar contraseña)
                // -- nunca en claro por defecto, ni siquiera en un popup
                // modal propio, salvo que el jugador pulse el ojo de abajo
                // para revisar lo que tecleó.
                echoMode: (campoEmergente.esPassword && !campoEmergente.mostrarPassword) ? TextInput.Password : TextInput.Normal
                // ImhNoPredictiveText: sin esto, el IME de Android mantiene
                // una "región de composición" (texto subrayado a medio
                // escribir) que se desincroniza del cursor real de QML --
                // visto en real: "borrar" solo retrocedía visualmente sin
                // borrar de verdad, y la letra siguiente sobreescribía en
                // vez de insertarse. Desactivar el predictivo hace que el
                // IME confirme cada carácter al momento, sin ese estado
                // intermedio que se puede desincronizar.
                inputMethodHints: (campoEmergente.soloNumerico ? Qt.ImhDigitsOnly : Qt.ImhNone) | Qt.ImhNoPredictiveText
                maximumLength: campoEmergente.maxLongitud
                // El IME de Android puede dejar los últimos caracteres "en composición" (texto sin
                // confirmar): el campo solo dibuja lo confirmado, y en una contraseña se veían 6-7
                // puntos aunque se hubieran tecleado más de 10 (reportado 2026-09-20; el login sí
                // funcionaba porque confirmar() los confirma al aceptar). Se confirma cada carácter
                // en cuanto aparece en la composición.
                onPreeditTextChanged: if (preeditText.length > 0) Qt.callLater(Qt.inputMethod.commit)
                font.pixelSize: 20 * Tema.escala
                color: Tema.colorTexto
                background: null
                onAccepted: campoEmergente.confirmar()
            }

            IconoOjo {
                visible: campoEmergente.esPassword
                oculto: !campoEmergente.mostrarPassword
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                onToggled: campoEmergente.mostrarPassword = !campoEmergente.mostrarPassword
            }
        }

        TecladoNumerico {
            width: parent.width
            visible: campoEmergente.soloNumerico
            onDigito: (valor) => {
                if (campoTexto.text.length < campoEmergente.maxLongitud)
                    campoTexto.text += valor;
            }
            onBorrar: campoTexto.text = campoTexto.text.slice(0, -1)
        }

        Row {
            width: parent.width
            spacing: 12 * Tema.escala
            BotonContorno {
                width: (parent.width - parent.spacing) / 2
                text: "Cancelar"
                colorBorde: Tema.colorPeligro
                onClicked: campoEmergente.close()
            }
            BotonRelleno {
                width: (parent.width - parent.spacing) / 2
                text: "Aceptar"
                onClicked: campoEmergente.confirmar()
            }
        }
    }
}
