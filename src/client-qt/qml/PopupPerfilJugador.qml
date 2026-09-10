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
    // 360 → 420 (2026-09-01, pedido explícito: "aumenta el tamaño del
    // avatar, hay espacio") -- un poco más de aire para el avatar más
    // grande de abajo, sin que la tarjeta deje de sentirse compacta.
    width: Math.min(420 * Tema.escala, (parent ? parent.width : 420) - 60 * Tema.escala)
    padding: 20 * Tema.escala

    property string servidorHost
    property int servidorPuerto
    property int accountId: -1
    // Catálogo de la tienda -- SOLO para resolver nombre/rareza del
    // título ajeno (ver CajaTitulo más abajo). Pasado desde Main.qml en
    // vez de leer "ventana.tiendaCrudo" directo: ese id no es alcanzable
    // desde aquí (fichero separado, pragma ComponentBehavior: Bound).
    // Duplicado a propósito el pequeño lookup/color -- mismo criterio que
    // el resto de este fichero (ver el comentario de cabecera).
    property var tiendaCrudo: []
    function objetoTiendaPorCodigo(codigo) {
        if (codigo === "") return null;
        for (var i = 0; i < popup.tiendaCrudo.length; i++) {
            if (popup.tiendaCrudo[i].codigo === codigo) return popup.tiendaCrudo[i];
        }
        return null;
    }
    function colorRareza(r) {
        return r === "oro" ? "#e3bb82" : r === "plata" ? "#9aa4ab" : r === "bronce" ? "#c98f5f" : "#7d848f";
    }

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

            // Visibilidad a otros jugadores (2026-09-01) -- ya no es solo
            // el marco por tier, el Avatar de OTRO jugador ahora pinta su
            // loadout completo de verdad (textura/efecto/decoraciones),
            // igual que el propio en Cuenta→Progreso. Item envolvente de
            // sobra (2.1x, mismo criterio que el resto de la app) porque
            // el anillo y las decoraciones sobresalen de su propio tamano.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                // 64 → 96 (2026-09-01, pedido explícito: "aumenta el
                // tamaño del avatar, hay espacio, y así se ve todo mucho
                // mejor") -- a 64px el loadout completo (textura/efecto/
                // decoraciones) apenas se distinguía, justo el problema
                // que motivó hablar del podio de Ranking en el mismo turno.
                width: 96 * Tema.escala * 2.1
                height: width
                Avatar {
                    anchors.centerIn: parent
                    letra: (popup.perfil.username || "").length > 0 ? popup.perfil.username.charAt(0).toUpperCase() : "?"
                    tamano: 96 * Tema.escala
                    marco: Tema.marcoPorPartidasGanadas(popup.perfil.partidasGanadas || 0, popup.perfil.tieneMarcoBasico === true)
                    textura: popup.perfil.textura || ""
                    efecto: popup.perfil.efecto || ""
                    decoracionLateral1: popup.perfil.decoracionLateral1 || ""
                    decoracionLateral2: popup.perfil.decoracionLateral2 || ""
                    decoracionSuperior: popup.perfil.decoracionSuperior || ""
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: popup.perfil.username || ""
                color: Tema.colorTexto
                font.family: Tema.fuenteElegante
                font.bold: true
                font.pixelSize: 18 * Tema.escala
            }
            CajaTitulo {
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property var infoTitulo: popup.objetoTiendaPorCodigo(popup.perfil.titulo || "")
                nombre: infoTitulo ? infoTitulo.nombre : ""
                colorTier: popup.colorRareza(infoTitulo ? infoTitulo.rareza : "")
            }
            // % de logros -- pedido explícito 2026-09-01 ("un porcentaje
            // visible en el perfil público que indique la cantidad y
            // proporción de los logros que tienes").
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: (popup.perfil.logrosTotal || 0) > 0
                text: (popup.perfil.logrosDesbloqueados || 0) + " / " + (popup.perfil.logrosTotal || 0) + " logros (" +
                      Math.round(100 * (popup.perfil.logrosDesbloqueados || 0) / Math.max(1, popup.perfil.logrosTotal || 1)) + "%)"
                color: Tema.colorTextoTenue
                font.pixelSize: 12 * Tema.escala
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
                        { etiqueta: "Mayor bote ganado", valor: (popup.perfil.mayorBote || 0) + "", esDinero: true },
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
                        Row {
                            width: 140 * Tema.escala
                            layoutDirection: Qt.RightToLeft
                            spacing: 3 * Tema.escala
                            IconoFicha {
                                visible: modelData.esDinero === true
                                width: 10 * Tema.escala
                                height: width
                                anchors.verticalCenter: parent.verticalCenter
                                colorFicha: Tema.colorTexto
                            }
                            Text {
                                text: modelData.valor
                                color: Tema.colorTexto
                                font.pixelSize: 12 * Tema.escala
                                font.bold: true
                                elide: Text.ElideRight
                            }
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
