// FormularioSala.qml (móvil) -- "Crear sala" a pantalla completa, en pasos.
// Misma estructura que el diseño aprobado en el artefacto (movil-1..3):
// laterales con Atrás y Continuar, indicador de paso y título arriba, y en el
// centro el contenido de cada paso sobre una ficha de casino. Sala → Partida →
// Bots en red; Partida → Bots con partida local. "Más opciones" es un botón
// grande que despliega lo secundario. Sin barra superior ni riel.
//
// No conecta por sí mismo: Main.qml escucha confirmar() y lee las propiedades.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import PokerQuickMobile

Item {
    id: formulario

    property bool sesionOffline: false
    property string mensajeError: ""
    signal confirmar()
    signal cancelar()

    // ── Valores (Main.qml los lee al confirmar) ────────────────────────────
    property string nombreSala: ""
    property bool publica: true
    property int tamano: 6
    property int manos: 20
    property int ciega: 20
    property int saldo: 1000
    property int limite: 0
    property bool minRaise: false
    property int monteFijo: 40
    property bool recompra: false
    property int dificultad: 0
    property bool rellenar: true
    property bool abierta: false
    property bool botsIA: false
    property bool preguntarExtension: true
    property bool temporizador: true
    property int numBots: 3

    // ── Pasos ─────────────────────────────────────────────────────────────
    property int paso: 0
    readonly property int totalPasos: sesionOffline ? 2 : 3
    readonly property string claveDePaso: sesionOffline
        ? (paso === 0 ? "partida" : "bots")
        : (paso === 0 ? "sala" : (paso === 1 ? "partida" : "bots"))
    readonly property string tituloDePaso: claveDePaso === "sala" ? Idioma.t("form_sala_titulo")
        : (claveDePaso === "partida" ? Idioma.t("form_partida_titulo") : Idioma.t("titulo_seccion_bots_formulario"))

    // Vuelve a los valores de fábrica y al primer paso: se llama al abrir la
    // pantalla, así una sala creada o cancelada no deja el formulario a medias.
    function reiniciar() {
        paso = 0;
        personalizada = false;
        nombreSala = "";
        publica = true;
        tamano = 6;
        manos = 20;
        ciega = 20;
        saldo = 1000;
        limite = 0;
        minRaise = false;
        monteFijo = 40;
        recompra = false;
        dificultad = 0;
        rellenar = true;
        abierta = false;
        botsIA = false;
        preguntarExtension = true;
        temporizador = true;
        numBots = 3;
        selManos.fijar(20);
        selSaldo.fijar(1000);
        selCiega.fijar(20);
        selMonte.fijar(40);
        selBots.fijar(3);
    }
    onVisibleChanged: if (visible) reiniciar()

    function avanzar() {
        if (paso < totalPasos - 1) paso++;
        else confirmar();
    }
    function retroceder() {
        if (paso > 0) paso--;
        else cancelar();
    }

    // ── Duraciones rápidas: manos y saldo. "A medida" deja los valores tal cual ──
    readonly property var presets: [
        { manos: 10, saldo: 500 },
        { manos: 20, saldo: 1000 },
        { manos: 40, saldo: 2000 }
    ]
    readonly property var nombresPresets: [Idioma.t("form_preset_rapida"), Idioma.t("form_preset_mediana"),
                                           Idioma.t("form_preset_larga"), Idioma.t("form_preset_propia")]
    property bool personalizada: false
    readonly property int presetActual: {
        if (personalizada) return 3;
        for (var i = 0; i < presets.length; i++) {
            if (presets[i].manos === manos && presets[i].saldo === saldo) return i;
        }
        return 3;
    }
    function aplicarPreset(indice) {
        if (indice >= presets.length) {
            personalizada = true;
            return;
        }
        personalizada = false;
        selManos.fijar(presets[indice].manos);
        selSaldo.fijar(presets[indice].saldo);
    }

    // Nombre: se escribe en el campo emergente, igual que el nombre de jugador.
    CampoEmergente {
        id: campoNombre
        etiqueta: Idioma.t("form_nombre")
        onAceptado: (texto) => formulario.nombreSala = texto
    }

    // ── Lateral izquierdo: Cancelar en el primer paso, Atrás después ──────
    Item {
        id: railIzquierdo
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 116 * Tema.escala
        BotonContorno {
            anchors.fill: parent
            anchors.margins: 10 * Tema.escala
            text: formulario.paso === 0 ? Idioma.t("boton_cancelar") : Idioma.t("form_atras")
            colorBorde: formulario.paso === 0 ? Tema.colorPeligro : Tema.colorAccent
            onClicked: formulario.retroceder()
        }
    }

    // ── Lateral derecho: Continuar, y en el último paso Crear / Empezar ──
    Item {
        id: railDerecho
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 128 * Tema.escala
        BotonRelleno {
            anchors.fill: parent
            anchors.margins: 10 * Tema.escala
            text: formulario.paso === formulario.totalPasos - 1
                  ? (formulario.sesionOffline ? Idioma.t("boton_empezar_partida") : Idioma.t("boton_crear_sala"))
                  : Idioma.t("form_continuar")
            onClicked: formulario.avanzar()
        }
    }

    // ── Centro: indicador de paso, título, contenido y error ──────────────
    Item {
        id: centro
        anchors.left: railIzquierdo.right
        anchors.right: railDerecho.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 6 * Tema.escala
        anchors.rightMargin: 6 * Tema.escala
        anchors.topMargin: 12 * Tema.escala
        anchors.bottomMargin: 12 * Tema.escala

        Row {
            id: indicador
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6 * Tema.escala
            Repeater {
                model: formulario.totalPasos
                delegate: Rectangle {
                    required property int index
                    width: 34 * Tema.escala
                    height: 4 * Tema.escala
                    radius: height / 2
                    color: index <= formulario.paso ? Tema.colorAccent : Tema.colorBorde
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 6 * Tema.escala
                text: Idioma.tf("form_paso_de", [formulario.paso + 1, formulario.totalPasos])
                color: Tema.colorTextoTenue
                font.pixelSize: 12 * Tema.escala
            }
        }

        Text {
            id: tituloPaso
            anchors.top: indicador.bottom
            anchors.topMargin: 6 * Tema.escala
            anchors.horizontalCenter: parent.horizontalCenter
            text: formulario.tituloDePaso
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.bold: true
            font.pixelSize: 22 * Tema.escala
        }

        Text {
            id: textoError
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            visible: formulario.mensajeError !== ""
            text: formulario.mensajeError
            color: Tema.colorPeligro
            font.pixelSize: 12 * Tema.escala
        }

        Item {
            id: contenidoPaso
            anchors.top: tituloPaso.bottom
            anchors.topMargin: 10 * Tema.escala
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: textoError.visible ? textoError.top : parent.bottom
            anchors.bottomMargin: 8 * Tema.escala

            // Ficha de casino detrás del contenido de cada paso.
            TarjetaCasino {
                anchors.fill: parent
            }

            // Espacio interior: el contenido de cada paso no toca los bordes de la ficha.
            Item {
                id: interior
                anchors.fill: parent
                anchors.leftMargin: 22 * Tema.escala
                anchors.rightMargin: 22 * Tema.escala
                anchors.topMargin: 10 * Tema.escala
                anchors.bottomMargin: 10 * Tema.escala

            // ── Paso SALA (solo en red) ───────────────────────────────────
            Column {
                visible: formulario.claveDePaso === "sala"
                width: parent.width
                spacing: 12 * Tema.escala
                anchors.verticalCenter: parent.verticalCenter

                Column {
                    width: parent.width
                    spacing: 4 * Tema.escala
                    Text {
                        text: Idioma.t("form_nombre")
                        color: Tema.colorTextoTenue
                        font.pixelSize: 13 * Tema.escala
                    }
                    Item {
                        width: parent.width
                        height: 40 * Tema.escala
                        MarcoHueco {
                            anchors.fill: parent
                            radius: 8 * Tema.escala
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 12 * Tema.escala
                            anchors.right: parent.right
                            anchors.rightMargin: 12 * Tema.escala
                            elide: Text.ElideRight
                            text: formulario.nombreSala !== "" ? formulario.nombreSala : Idioma.t("placeholder_nombre_sala")
                            color: formulario.nombreSala !== "" ? Tema.colorTexto : Tema.colorTextoMuyTenue
                            font.pixelSize: 15 * Tema.escala
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: campoNombre.abrir(formulario.nombreSala)
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4 * Tema.escala
                    EtiquetaInfo {
                        width: parent.width
                        etiqueta: Idioma.t("form_visibilidad")
                        detalle: Idioma.t("form_info_visibilidad")
                    }
                    SelectorSegmentado {
                        width: parent.width
                        opciones: [Idioma.t("etiqueta_sala_publica"), Idioma.t("form_privada")]
                        seleccionado: formulario.publica ? 0 : 1
                        onElegido: (indice) => formulario.publica = indice === 0
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4 * Tema.escala
                    EtiquetaInfo {
                        width: parent.width
                        etiqueta: Idioma.t("form_jugadores")
                        detalle: Idioma.t("form_info_asientos")
                    }
                    SelectorSegmentado {
                        width: parent.width
                        opciones: ["2", "3", "4", "5", "6", "7", "8", "9"]
                        seleccionado: formulario.tamano - 2
                        onElegido: (indice) => formulario.tamano = indice + 2
                    }
                }
            }

            // ── Paso PARTIDA: misma disposición que el artefacto ─────────────
            Column {
                visible: formulario.claveDePaso === "partida"
                width: parent.width
                spacing: 12 * Tema.escala
                anchors.verticalCenter: parent.verticalCenter

                Column {
                    width: parent.width
                    spacing: 4 * Tema.escala
                    Text {
                        text: Idioma.t("form_duracion")
                        color: Tema.colorTextoTenue
                        font.pixelSize: 13 * Tema.escala
                    }
                    Row {
                        id: filaPresets
                        width: parent.width
                        spacing: 6 * Tema.escala
                        Repeater {
                            model: formulario.nombresPresets
                            delegate: Rectangle {
                                id: chip
                                required property string modelData
                                required property int index
                                width: (filaPresets.width - 3 * filaPresets.spacing) / 4
                                height: 34 * Tema.escala
                                radius: height / 2
                                readonly property bool marcado: formulario.presetActual === chip.index
                                color: chip.marcado ? Tema.colorAccent : "transparent"
                                border.width: 1
                                border.color: chip.marcado ? Tema.colorAccent : Tema.colorBorde
                                Text {
                                    anchors.centerIn: parent
                                    text: chip.modelData
                                    font.pixelSize: 13 * Tema.escala
                                    font.bold: chip.marcado
                                    color: chip.marcado ? Tema.colorPanel : Tema.colorTextoTenue
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: formulario.aplicarPreset(chip.index)
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8 * Tema.escala
                    Column {
                        width: (parent.width - 2 * parent.spacing) / 3
                        spacing: 4 * Tema.escala
                        Text {
                            text: Idioma.t("form_manos")
                            color: Tema.colorTextoTenue
                            font.pixelSize: 12 * Tema.escala
                        }
                        SelectorNumerico {
                            id: selManos
                            compacto: true
                            valor: formulario.manos
                            minimo: 1
                            maximo: 200
                            onCambiado: (v) => formulario.manos = v
                        }
                    }
                    Column {
                        width: (parent.width - 2 * parent.spacing) / 3
                        spacing: 4 * Tema.escala
                        Text {
                            text: Idioma.t("etiqueta_saldo_inicial")
                            color: Tema.colorTextoTenue
                            font.pixelSize: 12 * Tema.escala
                        }
                        SelectorNumerico {
                            id: selSaldo
                            compacto: true
                            valor: formulario.saldo
                            minimo: 100
                            maximo: 100000
                            paso: 100
                            onCambiado: (v) => formulario.saldo = v
                        }
                    }
                    Column {
                        width: (parent.width - 2 * parent.spacing) / 3
                        spacing: 4 * Tema.escala
                        Text {
                            text: Idioma.t("etiqueta_ciega_grande")
                            color: Tema.colorTextoTenue
                            font.pixelSize: 12 * Tema.escala
                        }
                        SelectorNumerico {
                            id: selCiega
                            compacto: true
                            valor: formulario.ciega
                            minimo: 2
                            maximo: 1000
                            paso: 2
                            onCambiado: (v) => formulario.ciega = v
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4 * Tema.escala
                    EtiquetaInfo {
                        width: parent.width
                        etiqueta: Idioma.t("ajustes_tipo_limite")
                        detalle: Idioma.t("form_info_limite")
                    }
                    SelectorSegmentado {
                        width: parent.width
                        opciones: [Idioma.t("limite_sin_limite"), Idioma.t("limite_limite_bote"), Idioma.t("limite_limite_fijo")]
                        seleccionado: formulario.limite
                        onElegido: (indice) => formulario.limite = indice
                    }
                }
                Row {
                    visible: !formulario.sesionOffline
                    width: parent.width
                    Column {
                        width: parent.width - interruptorAbierta.width - 24 * Tema.escala
                        anchors.verticalCenter: parent.verticalCenter
                        EtiquetaInfo {
                            width: parent.width
                            etiqueta: Idioma.t("etiqueta_abierta_tras_iniciar")
                            detalle: Idioma.t("texto_ayuda_abierta_tras_iniciar")
                        }
                    }
                    Interruptor {
                        id: interruptorAbierta
                        activo: formulario.abierta
                        onAlternado: formulario.abierta = !formulario.abierta
                    }
                }
                Row {
                    visible: formulario.limite === 2
                    width: parent.width
                    spacing: 10 * Tema.escala
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Idioma.t("etiqueta_monte_fijo")
                        color: Tema.colorTextoTenue
                        font.pixelSize: 13 * Tema.escala
                    }
                    SelectorNumerico {
                        id: selMonte
                        compacto: true
                        valor: formulario.monteFijo
                        minimo: 1
                        maximo: 10000
                        onCambiado: (v) => formulario.monteFijo = v
                    }
                }
            }

            // ── Paso BOTS (desplazable si "Más opciones" está abierto) ───────
            Flickable {
                id: flickBots
                visible: formulario.claveDePaso === "bots"
                anchors.fill: parent
                contentHeight: columnaBots.implicitHeight
                clip: true

                Column {
                    id: columnaBots
                    width: flickBots.width
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6 * Tema.escala

                    Row {
                        visible: !formulario.sesionOffline
                        width: parent.width
                        Column {
                            width: parent.width - interruptorRellenar.width - 24 * Tema.escala
                            anchors.verticalCenter: parent.verticalCenter
                            EtiquetaInfo {
                                width: parent.width
                                etiqueta: Idioma.t("etiqueta_rellenar_bots")
                                detalle: Idioma.t("texto_ayuda_rellenar_bots")
                            }
                        }
                        Interruptor {
                            id: interruptorRellenar
                            activo: formulario.rellenar
                            onAlternado: formulario.rellenar = !formulario.rellenar
                        }
                    }

                    Row {
                        visible: formulario.sesionOffline
                        width: parent.width
                        spacing: 10 * Tema.escala
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Idioma.t("etiqueta_numero_bots")
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                        }
                        SelectorNumerico {
                            id: selBots
                            compacto: true
                            valor: formulario.numBots
                            minimo: 1
                            maximo: 8
                            onCambiado: (v) => formulario.numBots = v
                        }
                    }

                    Column {
                        visible: formulario.sesionOffline || formulario.rellenar
                        width: parent.width
                        spacing: 2 * Tema.escala
                        Text {
                            text: Idioma.t("etiqueta_dificultad_bots")
                            color: Tema.colorTextoTenue
                            font.pixelSize: 13 * Tema.escala
                        }
                        SelectorSegmentado {
                            width: parent.width
                            opciones: [Idioma.t("dificultad_facil"), Idioma.t("dificultad_normal"), Idioma.t("dificultad_experto")]
                            seleccionado: formulario.dificultad
                            onElegido: (indice) => formulario.dificultad = indice
                        }
                    }

                    Column {
                        visible: !formulario.sesionOffline && formulario.rellenar
                        width: parent.width
                        spacing: 2 * Tema.escala
                        EtiquetaInfo {
                            width: parent.width
                            etiqueta: Idioma.t("form_motor")
                            detalle: Idioma.t("texto_ayuda_bots_ia")
                        }
                        SelectorSegmentado {
                            width: parent.width
                            opciones: [Idioma.t("form_motor_local"), Idioma.t("form_motor_ia")]
                            seleccionado: formulario.botsIA ? 1 : 0
                            onElegido: (indice) => formulario.botsIA = indice === 1
                        }
                        Text {
                            text: Idioma.t("form_mezcla_proximamente")
                            color: Tema.colorTextoMuyTenue
                            font.pixelSize: 11 * Tema.escala
                        }
                    }

                    // "Más opciones": botón grande y visible, con todo lo secundario dentro.
                    // "Más opciones": botón grande; abre un popup con lo secundario.
                    BotonRelleno {
                        width: parent.width
                        height: Tema.tactil * 1.0
                        text: Idioma.t("form_mas_opciones")
                        onClicked: popupMasOpciones.open()
                        // Chevron dibujado: la fuente no trae las flechas ▾/▴.
                        Item {
                            anchors.right: parent.right
                            anchors.rightMargin: 16 * Tema.escala
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14 * Tema.escala
                            height: 8 * Tema.escala
                            Rectangle {
                                x: 0
                                y: 0
                                width: 10 * Tema.escala
                                height: 2 * Tema.escala
                                rotation: 40
                                transformOrigin: Item.TopLeft
                                color: Tema.colorPanel
                            }
                            Rectangle {
                                x: 4 * Tema.escala
                                y: 0
                                width: 10 * Tema.escala
                                height: 2 * Tema.escala
                                rotation: -40
                                transformOrigin: Item.TopRight
                                color: Tema.colorPanel
                            }
                        }
                    }


                }
            }
                  }
  }
    }

    // Opciones secundarias del paso Bots, en un popup (2026-10-04): el paso
    // no se amplía ni necesita scroll.
    Popup {
        id: popupMasOpciones
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(340 * Tema.escala, (parent ? parent.width : 340) - 40 * Tema.escala)
        padding: 16 * Tema.escala
        background: Rectangle {
            color: Tema.colorPanel
            radius: 12 * Tema.escala
            border.width: 1
            border.color: Tema.colorAccent
        }
        contentItem: Column {
            width: popupMasOpciones.availableWidth
            spacing: 12 * Tema.escala
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Idioma.t("form_mas_opciones")
                color: Tema.colorTexto
                font.family: Tema.fuenteElegante
                font.bold: true
                font.pixelSize: 17 * Tema.escala
            }
                        Row {
                            width: parent.width
                            Column {
                                width: parent.width - interruptorMinRaise.width - 24 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                EtiquetaInfo {
                                    width: parent.width
                                    etiqueta: Idioma.t("etiqueta_min_raise_obligatorio")
                                    detalle: Idioma.t("form_info_min_raise")
                                }
                            }
                            Interruptor {
                                id: interruptorMinRaise
                                activo: formulario.minRaise
                                onAlternado: formulario.minRaise = !formulario.minRaise
                            }
                        }
                        Row {
                            width: parent.width
                            Column {
                                width: parent.width - interruptorRecompra.width - 24 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                EtiquetaInfo {
                                    width: parent.width
                                    etiqueta: Idioma.t("etiqueta_permitir_recompra")
                                    detalle: Idioma.t("form_info_recompra")
                                }
                            }
                            Interruptor {
                                id: interruptorRecompra
                                activo: formulario.recompra
                                onAlternado: formulario.recompra = !formulario.recompra
                            }
                        }
                        Row {
                            width: parent.width
                            Column {
                                width: parent.width - interruptorExtension.width - 24 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                EtiquetaInfo {
                                    width: parent.width
                                    etiqueta: Idioma.t("etiqueta_preguntar_extension")
                                }
                            }
                            Interruptor {
                                id: interruptorExtension
                                activo: formulario.preguntarExtension
                                onAlternado: formulario.preguntarExtension = !formulario.preguntarExtension
                            }
                        }
                        Row {
                            visible: !formulario.sesionOffline
                            width: parent.width
                            Column {
                                width: parent.width - interruptorTemporizador.width - 24 * Tema.escala
                                anchors.verticalCenter: parent.verticalCenter
                                EtiquetaInfo {
                                    width: parent.width
                                    etiqueta: Idioma.t("form_temporizador")
                                    detalle: Idioma.t("etiqueta_temporizador_voto")
                                }
                            }
                            Interruptor {
                                id: interruptorTemporizador
                                activo: formulario.temporizador
                                onAlternado: formulario.temporizador = !formulario.temporizador
                            }
                        }
            BotonRelleno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Idioma.t("boton_aceptar")
                onClicked: popupMasOpciones.close()
            }
        }
    }
}
