// PopupPerfilJugador.qml (móvil) — mismo rol que el de escritorio (ver
// src/client-qt/qml/PopupPerfilJugador.qml): perfil público de OTRO
// jugador, con el mismo bloque de estadísticas que la pestaña Cuenta del
// cajón lateral. DUPLICADO a propósito, no extraído a un componente
// compartido -- ver el comentario largo en la versión de escritorio.
//
// Puesto al día 2026-09-01 (Fase M0 del port de progresión a móvil, ver
// memoria qt_mobile_progression_port_plan) con la "parte A" de
// visibilidad a otros jugadores (loadout completo + CajaTitulo + % de
// logros) y el avatar más grande, los dos ya hechos en escritorio el
// mismo día. Avatar 56→80px (no 96 como escritorio, a propósito -- este
// popup es más estrecho en móvil) y el propio popup 320→360px.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Popup {
    id: popup
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(360 * Tema.escala, (parent ? parent.width : 360) - 40 * Tema.escala)
    padding: 18 * Tema.escala

    property string servidorHost
    property int servidorPuerto
    property int accountId: -1
    // Catálogo de la tienda -- SOLO para resolver nombre/rareza del
    // título ajeno (ver CajaTitulo más abajo). Pasado desde Main.qml en
    // vez de leer un id de la ventana raíz directo -- no es alcanzable
    // desde aquí (fichero separado, pragma ComponentBehavior: Bound).
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
    // Nombre de combinación de póker (mejor mano) -- mismo mapa/motivo que
    // el gemelo comboLocalizado() de Main.qml (fichero separado, sin acceso
    // a sus funciones -- ver el comentario de cabecera de este fichero).
    function comboLocalizado(comboEs) {
        var mapa = {
            "Carta Alta": "combo_carta_alta",
            "Pareja": "combo_pareja",
            "Doble Pareja": "combo_doble_pareja",
            "Trio": "combo_trio",
            "Escalera": "combo_escalera",
            "Color": "combo_color",
            "Full House": "combo_full_house",
            "Poker": "combo_poker",
            "Escalera Color": "combo_escalera_color",
            "Escalera Real": "combo_escalera_real"
        };
        var clave = mapa[comboEs];
        if (!clave) return comboEs;
        var t = Idioma.t(clave);
        return t === clave ? comboEs : t;
    }

    readonly property var perfil: redcliente.perfilJugador
    readonly property bool datosListos: perfil.accountId === popup.accountId

    function abrir(id) {
        popup.accountId = id;
        redcliente.consultarPerfilJugador(popup.servidorHost, popup.servidorPuerto, id);
        popup.open();
    }

    background: Rectangle {
        color: Tema.colorPanel
        radius: 10 * Tema.escala
        border.width: 1
        border.color: Tema.colorAccent
    }

    contentItem: Flickable {
        implicitHeight: Math.min(contenidoPerfil.height, 480 * Tema.escala)
        contentWidth: width
        contentHeight: contenidoPerfil.height
        clip: true

        Column {
            id: contenidoPerfil
            width: parent.width
            spacing: 12 * Tema.escala

            Text {
                visible: !popup.datosListos
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Idioma.t("texto_cargando_perfil")
                color: Tema.colorTextoTenue
                font.pixelSize: 12 * Tema.escala
            }

            Text {
                visible: popup.datosListos && popup.perfil.existe !== true
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: Idioma.t("texto_jugador_no_existe")
                color: Tema.colorTextoTenue
                font.pixelSize: 12 * Tema.escala
            }

            Column {
                visible: popup.datosListos && popup.perfil.existe === true
                width: parent.width
                spacing: 12 * Tema.escala

                // Item envolvente de sobra (2.1x) -- el anillo y las
                // decoraciones sobresalen de su propio tamano.
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 80 * Tema.escala * 2.1
                    height: width
                    Avatar {
                        anchors.centerIn: parent
                        letra: (popup.perfil.username || "").length > 0 ? popup.perfil.username.charAt(0).toUpperCase() : "?"
                        tamano: 80 * Tema.escala
                        marco: Tema.marcoPorPartidasGanadas(popup.perfil.partidasGanadas || 0, popup.perfil.tieneMarcoBasico === true)
                        textura: popup.perfil.textura || ""
                        efecto: popup.perfil.efecto || ""
                        decoracionLateral1: popup.perfil.decoracionLateral1 || ""
                        decoracionLateral2: popup.perfil.decoracionLateral2 || ""
                        decoracionSuperior: popup.perfil.decoracionSuperior || ""
                        acabadoLateral1: popup.perfil.acabadoLateral1 || ""
                        acabadoLateral2: popup.perfil.acabadoLateral2 || ""
                        acabadoSuperior: popup.perfil.acabadoSuperior || ""
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: popup.perfil.username || ""
                    color: Tema.colorTexto
                    font.family: Tema.fuenteElegante
                    font.bold: true
                    font.pixelSize: 16 * Tema.escala
                }
                CajaTitulo {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property var infoTitulo: popup.objetoTiendaPorCodigo(popup.perfil.titulo || "")
                    nombre: infoTitulo ? infoTitulo.nombre : ""
                    colorTier: popup.colorRareza(infoTitulo ? infoTitulo.rareza : "")
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: (popup.perfil.logrosTotal || 0) > 0
                    text: Idioma.tf("etiqueta_logros_porcentaje",
                              [(popup.perfil.logrosDesbloqueados || 0), (popup.perfil.logrosTotal || 0),
                               Math.round(100 * (popup.perfil.logrosDesbloqueados || 0) / Math.max(1, popup.perfil.logrosTotal || 1))])
                    color: Tema.colorTextoTenue
                    font.pixelSize: 11 * Tema.escala
                }

                Column {
                    width: parent.width
                    visible: (popup.perfil.partidasJugadas || 0) > 0
                    spacing: 6 * Tema.escala
                    Repeater {
                        model: [
                            { etiqueta: Idioma.t("stat_partidas_jugadas"), valor: (popup.perfil.partidasJugadas || 0) + "" },
                            { etiqueta: Idioma.t("stat_partidas_ganadas"), valor: (popup.perfil.partidasGanadas || 0) + "" },
                            { etiqueta: Idioma.t("stat_ratio_victorias"), valor: Math.round(100 * (popup.perfil.partidasGanadas || 0) / (popup.perfil.partidasJugadas || 1)) + "%" },
                            { etiqueta: Idioma.t("stat_racha_actual"), valor: (popup.perfil.rachaActual || 0) + "" },
                            { etiqueta: Idioma.t("stat_mejor_racha"), valor: (popup.perfil.rachaMaxima || 0) + "" },
                            { etiqueta: Idioma.t("stat_manos_jugadas"), valor: (popup.perfil.manosJugadas || 0) + "" },
                            { etiqueta: Idioma.t("stat_manos_ganadas"), valor: (popup.perfil.manosGanadas || 0) + "" },
                            { etiqueta: Idioma.t("stat_mayor_bote_ganado"), valor: (popup.perfil.mayorBote || 0) + "", esDinero: true },
                            { etiqueta: Idioma.t("stat_mejor_mano"), valor: (popup.perfil.mejorManoFecha || 0) > 0
                                  ? popup.comboLocalizado(popup.perfil.mejorManoNombre) + " (" + new Date(popup.perfil.mejorManoFecha * 1000).toLocaleDateString() + ")"
                                  : "—" }
                        ]
                        delegate: Row {
                            required property var modelData
                            width: parent.width
                            Text {
                                width: parent.width - 130 * Tema.escala
                                text: modelData.etiqueta
                                color: Tema.colorTextoTenue
                                font.pixelSize: 11 * Tema.escala
                            }
                            Row {
                                width: 130 * Tema.escala
                                layoutDirection: Qt.RightToLeft
                                spacing: 3 * Tema.escala
                                IconoFicha {
                                    visible: modelData.esDinero === true
                                    width: 9 * Tema.escala
                                    height: width
                                    anchors.verticalCenter: parent.verticalCenter
                                    colorFicha: Tema.colorTexto
                                }
                                Text {
                                    text: modelData.valor
                                    color: Tema.colorTexto
                                    font.pixelSize: 11 * Tema.escala
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Text {
                        text: Idioma.t("titulo_combinaciones_mostradas")
                        color: Tema.colorTextoMuyTenue
                        font.pixelSize: 9 * Tema.escala
                        font.letterSpacing: 1
                        topPadding: 6 * Tema.escala
                    }
                    Grid {
                        width: parent.width
                        columns: 2
                        columnSpacing: 10 * Tema.escala
                        rowSpacing: 4 * Tema.escala
                        Repeater {
                            model: [
                                { etiqueta: Idioma.t("combo_carta_alta"), valor: popup.perfil.vecesCartaAlta || 0 },
                                { etiqueta: Idioma.t("combo_pareja"), valor: popup.perfil.vecesPareja || 0 },
                                { etiqueta: Idioma.t("combo_doble_pareja"), valor: popup.perfil.vecesDoblePareja || 0 },
                                { etiqueta: Idioma.t("combo_trio"), valor: popup.perfil.vecesTrio || 0 },
                                { etiqueta: Idioma.t("combo_escalera"), valor: popup.perfil.vecesEscalera || 0 },
                                { etiqueta: Idioma.t("combo_color"), valor: popup.perfil.vecesColor || 0 },
                                { etiqueta: Idioma.t("combo_full_house"), valor: popup.perfil.vecesFullHouse || 0 },
                                { etiqueta: Idioma.t("combo_poker"), valor: popup.perfil.vecesPoker || 0 },
                                { etiqueta: Idioma.t("combo_escalera_color"), valor: popup.perfil.vecesEscaleraColor || 0 },
                                { etiqueta: Idioma.t("combo_escalera_real"), valor: popup.perfil.vecesEscaleraReal || 0 }
                            ]
                            delegate: Row {
                                required property var modelData
                                width: (parent.width - 10 * Tema.escala) / 2
                                Text {
                                    width: parent.width - 26 * Tema.escala
                                    text: modelData.etiqueta
                                    color: modelData.valor > 0 ? Tema.colorTextoTenue : Tema.colorTextoMuyTenue
                                    font.pixelSize: 10 * Tema.escala
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: 26 * Tema.escala
                                    text: modelData.valor + ""
                                    color: modelData.valor > 0 ? Tema.colorAccent : Tema.colorTextoMuyTenue
                                    font.bold: modelData.valor > 0
                                    font.pixelSize: 10 * Tema.escala
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
                    text: Idioma.t("texto_sin_estadisticas_ajenas")
                    color: Tema.colorTextoTenue
                    font.pixelSize: 11 * Tema.escala
                }
            }
        }
    }
}
