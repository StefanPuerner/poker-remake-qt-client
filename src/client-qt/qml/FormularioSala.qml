// FormularioSala.qml -- "Crear sala" en escritorio (rediseño 2026-10-04). Cuatro
// tarjetas tipo ficha de casino en dos columnas. Es dinámico: sin bots no
// aparecen dificultad ni motor; con partida local no aparece la sala. Los
// ajustes con explicación llevan un botón "i" que la despliega.
//
// No conecta por sí mismo: Main.qml escucha confirmar() y lee las propiedades
// de aquí para llamar a crearSala() o a iniciarPartidaLocal().
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

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

    // Duraciones rápidas: manos y saldo. "A medida" deja los valores como están.
    readonly property var presets: [
        { manos: 10, saldo: 500 },
        { manos: 20, saldo: 1000 },
        { manos: 40, saldo: 2000 }
    ]
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
        setManos(presets[indice].manos);
        setSaldo(presets[indice].saldo);
    }
    function setManos(v) {
        manos = v;
        campoManos.text = String(v);
    }
    function setSaldo(v) {
        saldo = v;
        campoSaldo.text = String(v);
    }
    function acotar(v, minimo, maximo, porDefecto) {
        var n = parseInt(v);
        if (isNaN(n)) n = porDefecto;
        return Math.max(minimo, Math.min(maximo, n));
    }

    // Tres columnas que caben en la ventana sin scroll: Sala, Partida y, a la
    // derecha, Bots con Más opciones debajo. Si la ventana es muy baja, el
    // conjunto se reduce entero para que siga sin hacer falta desplazarse.
    readonly property real anchoRejilla: Math.min(1040 * Tema.escala, formulario.width - 60 * Tema.escala)
    readonly property real anchoMitad: (anchoRejilla - 16 * Tema.escala) / 2
    readonly property real ajuste: Math.min(1, (formulario.height - 40 * Tema.escala) / Math.max(1, contenido.implicitHeight))

    Column {
        id: contenido
        anchors.top: parent.top
        anchors.topMargin: 20 * Tema.escala
        anchors.horizontalCenter: parent.horizontalCenter
        width: formulario.anchoRejilla
        spacing: 16 * Tema.escala
        scale: formulario.ajuste
        transformOrigin: Item.Top

        // Mosaico 2x2: las tarjetas de cada fila comparten altura.
        Row {
            id: filaSuperior
            width: parent.width
            spacing: 16 * Tema.escala
            readonly property real altoFila: Math.max(tarjetaSala.implicitHeight, tarjetaPartida.implicitHeight)
            TarjetaCasino {
                            id: tarjetaSala
                            width: formulario.anchoMitad
                height: parent.altoFila

                                visible: !formulario.sesionOffline
                                    titulo: Idioma.t("form_sala_titulo")
    
                                Column {
                                    width: parent.width
                                    spacing: 6 * Tema.escala
                                    Text {
                                        text: Idioma.t("form_nombre")
                                        color: Tema.colorTextoTenue
                                        font.pixelSize: 13 * Tema.escala
                                    }
                                    TextField {
                                        id: campoNombreSala
                                        width: parent.width
                                        placeholderText: Idioma.t("placeholder_nombre_sala")
                                        color: Tema.colorTexto
                                        font.pixelSize: 14 * Tema.escala
                                        maximumLength: 32
                                        onTextChanged: formulario.nombreSala = text
                                        background: MarcoHueco {
                                            radius: 6 * Tema.escala
                                            activo: campoNombreSala.activeFocus
                                        }
                                    }
                                }
                                Column {
                                    width: parent.width
                                    spacing: 6 * Tema.escala
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
                                    spacing: 6 * Tema.escala
                                    Text {
                                        text: Idioma.t("form_jugadores")
                                        color: Tema.colorTextoTenue
                                        font.pixelSize: 13 * Tema.escala
                                    }
                                    SelectorSegmentado {
                                        width: parent.width
                                        opciones: ["2", "3", "4", "5", "6", "7", "8", "9"]
                                        seleccionado: formulario.tamano - 2
                                        onElegido: (indice) => formulario.tamano = indice + 2
                                    }
                                }
                            }
            TarjetaCasino {
                            id: tarjetaPartida
                            width: formulario.anchoMitad
                height: parent.altoFila

                                    titulo: Idioma.t("form_partida_titulo")
    
                                Column {
                                    width: parent.width
                                    spacing: 6 * Tema.escala
                                    Text {
                                        text: Idioma.t("form_duracion")
                                        color: Tema.colorTextoTenue
                                        font.pixelSize: 13 * Tema.escala
                                    }
                                    SelectorSegmentado {
                                        width: parent.width
                                        opciones: [Idioma.t("form_preset_rapida"), Idioma.t("form_preset_mediana"),
                                                   Idioma.t("form_preset_larga"), Idioma.t("form_preset_propia")]
                                        seleccionado: formulario.presetActual
                                        onElegido: (indice) => formulario.aplicarPreset(indice)
                                    }
                                }
                                Row {
                                    width: parent.width
                                    spacing: 10 * Tema.escala
                                    Column {
                                        width: (parent.width - 2 * parent.spacing) / 3
                                        spacing: 6 * Tema.escala
                                        Text {
                                            text: Idioma.t("form_manos")
                                            color: Tema.colorTextoTenue
                                            font.pixelSize: 13 * Tema.escala
                                        }
                                        TextField {
                                            id: campoManos
                                            width: parent.width
                                            text: "20"
                                            color: Tema.colorTexto
                                            font.pixelSize: 14 * Tema.escala
                                            horizontalAlignment: Text.AlignHCenter
                                            validator: IntValidator { bottom: 1; top: 200 }
                                            onEditingFinished: formulario.setManos(formulario.acotar(text, 1, 200, 20))
                                            background: MarcoHueco {
                                                radius: 6 * Tema.escala
                                                activo: campoManos.activeFocus
                                            }
                                        }
                                    }
                                    Column {
                                        width: (parent.width - 2 * parent.spacing) / 3
                                        spacing: 6 * Tema.escala
                                        Text {
                                            text: Idioma.t("etiqueta_saldo_inicial")
                                            color: Tema.colorTextoTenue
                                            font.pixelSize: 13 * Tema.escala
                                        }
                                        TextField {
                                            id: campoSaldo
                                            width: parent.width
                                            text: "1000"
                                            color: Tema.colorTexto
                                            font.pixelSize: 14 * Tema.escala
                                            horizontalAlignment: Text.AlignHCenter
                                            validator: IntValidator { bottom: 100; top: 100000 }
                                            onEditingFinished: formulario.setSaldo(formulario.acotar(text, 100, 100000, 1000))
                                            background: MarcoHueco {
                                                radius: 6 * Tema.escala
                                                activo: campoSaldo.activeFocus
                                            }
                                        }
                                    }
                                    Column {
                                        width: (parent.width - 2 * parent.spacing) / 3
                                        spacing: 6 * Tema.escala
                                        Text {
                                            text: Idioma.t("etiqueta_ciega_grande")
                                            color: Tema.colorTextoTenue
                                            font.pixelSize: 13 * Tema.escala
                                        }
                                        TextField {
                                            id: campoCiega
                                            width: parent.width
                                            text: "20"
                                            color: Tema.colorTexto
                                            font.pixelSize: 14 * Tema.escala
                                            horizontalAlignment: Text.AlignHCenter
                                            validator: IntValidator { bottom: 2; top: 1000 }
                                            onEditingFinished: formulario.ciega = formulario.acotar(text, 2, 1000, 20)
                                            background: MarcoHueco {
                                                radius: 6 * Tema.escala
                                                activo: campoCiega.activeFocus
                                            }
                                        }
                                    }
                                }
                                Column {
                                    width: parent.width
                                    spacing: 6 * Tema.escala
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
                                    visible: formulario.limite === 2
                                    width: parent.width
                                    spacing: 10 * Tema.escala
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Idioma.t("etiqueta_monte_fijo")
                                        color: Tema.colorTextoTenue
                                        font.pixelSize: 13 * Tema.escala
                                    }
                                    TextField {
                                        id: campoMonte
                                        width: 100 * Tema.escala
                                        text: "40"
                                        color: Tema.colorTexto
                                        font.pixelSize: 14 * Tema.escala
                                        horizontalAlignment: Text.AlignHCenter
                                        validator: IntValidator { bottom: 1; top: 10000 }
                                        onEditingFinished: formulario.monteFijo = formulario.acotar(text, 1, 10000, 40)
                                        background: MarcoHueco {
                                            radius: 6 * Tema.escala
                                            activo: campoMonte.activeFocus
                                        }
                                    }
                                }
                                Row {
                                    visible: !formulario.sesionOffline
                                    width: parent.width
                                    Column {
                                        width: parent.width - interruptorAbierta.width
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
                                    width: parent.width
                                    Column {
                                        width: parent.width - interruptorMinRaise.width
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
                                        width: parent.width - interruptorRecompra.width
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
                            }
        }
        Row {
            id: filaInferior
            width: parent.width
            spacing: 16 * Tema.escala
            readonly property real altoFila: Math.max(tarjetaBots.implicitHeight, tarjetaMas.implicitHeight)
            TarjetaCasino {
                            id: tarjetaBots
                            width: formulario.anchoMitad
                height: parent.altoFila

                                    titulo: Idioma.t("titulo_seccion_bots_formulario")
    
                                Row {
                                    visible: !formulario.sesionOffline
                                    width: parent.width
                                    Column {
                                        width: parent.width - interruptorRellenar.width
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
                                    TextField {
                                        id: campoBots
                                        width: 80 * Tema.escala
                                        text: "3"
                                        color: Tema.colorTexto
                                        font.pixelSize: 14 * Tema.escala
                                        horizontalAlignment: Text.AlignHCenter
                                        validator: IntValidator { bottom: 1; top: 8 }
                                        onEditingFinished: formulario.numBots = formulario.acotar(text, 1, 8, 3)
                                        background: MarcoHueco {
                                            radius: 6 * Tema.escala
                                            activo: campoBots.activeFocus
                                        }
                                    }
                                }
    
                                // Dificultad y motor: solo si hay bots que los usen.
                                Column {
                                    visible: formulario.sesionOffline || formulario.rellenar
                                    width: parent.width
                                    spacing: 6 * Tema.escala
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
                                    spacing: 6 * Tema.escala
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
                                        font.pixelSize: 12 * Tema.escala
                                    }
                                }
                            }
            TarjetaCasino {
                            id: tarjetaMas
                            width: formulario.anchoMitad
                height: parent.altoFila

                                    titulo: Idioma.t("form_mas_opciones")
    
                                Row {
                                    width: parent.width
                                    Column {
                                        width: parent.width - interruptorExtension.width
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
                                        width: parent.width - interruptorTemporizador.width
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
                
                            }
        }

        // Acciones: a la derecha, como en el diseño.
        Row {
            id: acciones
            anchors.right: parent.right
            spacing: 12 * Tema.escala
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: formulario.mensajeError !== ""
                text: formulario.mensajeError
                color: Tema.colorPeligro
                font.pixelSize: 12 * Tema.escala
            }
            BotonContorno {
                text: Idioma.t("boton_cancelar")
                colorBorde: Tema.colorPeligro
                onClicked: formulario.cancelar()
            }
            BotonRelleno {
                text: formulario.sesionOffline ? Idioma.t("boton_empezar_partida") : Idioma.t("boton_crear_sala")
                onClicked: formulario.confirmar()
            }
        }
    }
}
