// PopupAcabado.qml — elegir el acabado (el metal) de una decoración al
// equiparla. Fase 2 del material (ver docs/plan-material-cosmeticos.md);
// pedido del usuario, 2026-09-10: "al equipar un cosmético que tiene color
// intercambiable, antes de equiparse salta una ventana flotante donde eliges
// el color, y luego sigue la asignación normal".
//
// Enseña la decoración en cada metal que ya has ganado, del hierro al de tu
// marco ("solo se puede bajar, nunca subir" -- el servidor lo vuelve a
// comprobar), con el de tu marco ya marcado. Ese se manda como "" = sigue al
// marco: si tu marco sube, la decoración sube con él. Uno más bajo se queda
// fijo. Main.qml::equiparConAcabado() decide si hace falta preguntar.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Popup {
    id: popup
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 24 * Tema.escala
    // Modo lateral: ventana ancha y fija (antes salía tan estrecha como la fila de
    // metales, y el selector de lado se desbordaba por los costados).
    width: popup.modoLateral ? Math.min(popup.parent.width - 40 * Tema.escala, 600 * Tema.escala) : implicitWidth

    signal acabadoElegido(string slot, string codigo, string acabado)
    // Quitar la decoración de un lado (solo en modo lateral).
    signal quitado(string slot)

    // ── Modo lateral (2026-09-20) ────────────────────────────────────────
    // Una decoración lateral puede ir a la izquierda, a la derecha o a AMBOS
    // lados (la misma en los dos, si quieres). Antes cada lado era un botón
    // suelto en la tarjeta -- y en el móvil se tocaba la tarjeta y se iba al
    // primer hueco libre, sin poder elegir. Ahora tocar una decoración lateral
    // abre esto: lado + material, y solo entonces se equipa.
    property bool modoLateral: false
    property string nombre: ""
    property bool enIzq: false
    property bool enDer: false
    property int ladoIndice: 0   // 0 izquierda, 1 derecha, 2 ambos
    // Hay de verdad un material que elegir (decoración de metal y más de un
    // metal desbloqueado).
    readonly property bool conMetal: Tema.decoracionesMetalicas[popup.codigo] === true && popup.metales.length >= 2

    property string slot: ""
    property string codigo: ""
    property string marco: ""
    property string elegido: ""
    readonly property var metales: Tema.metalesHasta(popup.marco)

    function abrirLateral(codigo, nombre, marco, enIzq, enDer) {
        popup.modoLateral = true;
        popup.slot = "";
        popup.codigo = codigo;
        popup.nombre = nombre;
        popup.marco = marco;
        popup.elegido = marco;
        popup.enIzq = enIzq;
        popup.enDer = enDer;
        popup.ladoIndice = enIzq ? 0 : (enDer ? 1 : 0);
        popup.open();
    }
    function abrir(slot, codigo, marco) {
        popup.modoLateral = false;
        popup.nombre = "";
        popup.slot = slot;
        popup.codigo = codigo;
        popup.marco = marco;
        popup.elegido = marco;
        popup.open();
    }
    // Mismos nombres de fichero que Avatar.qml::sufijoAcabado(): el oro es el
    // fichero base, que ya es dorado.
    function rutaIcono(metal) {
        return "qrc:/qt/qml/PokerQuick/assets/iconos/" + popup.codigo
               + (metal === "oro" ? "" : "_" + metal) + ".png";
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
            text: popup.modoLateral ? popup.nombre : Idioma.t("popup_acabado_titulo")
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.pixelSize: (popup.modoLateral ? 22 : 17) * Tema.escala
        }
        // Lado (solo decoraciones laterales).
        Column {
            visible: popup.modoLateral
            width: parent.width
            spacing: 6 * Tema.escala
            Text {
                text: Idioma.t("popup_deco_lado")
                color: Tema.colorTextoTenue
                font.pixelSize: 11 * Tema.escala
            }
            SelectorSegmentado {
                width: parent.width
                opciones: [Idioma.t("lado_izquierda"), Idioma.t("lado_derecha"), Idioma.t("lado_ambos")]
                seleccionado: popup.ladoIndice
                onElegido: (indice) => popup.ladoIndice = indice
            }
        }
        Text {
            visible: !popup.modoLateral || popup.conMetal
            width: filaMetales.width
            wrapMode: Text.WordWrap
            text: Idioma.t("popup_acabado_descripcion")
            color: Tema.colorTextoTenue
            font.pixelSize: 11 * Tema.escala
        }

        Row {
            id: filaMetales
            visible: !popup.modoLateral || popup.conMetal
            spacing: 10 * Tema.escala

            Repeater {
                model: popup.metales
                delegate: Rectangle {
                    id: celda
                    required property string modelData
                    readonly property bool marcado: popup.elegido === celda.modelData
                    width: 88 * Tema.escala
                    height: 116 * Tema.escala
                    radius: 10 * Tema.escala
                    color: celda.marcado
                           ? Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.14)
                           : (zona.containsMouse
                              ? Qt.rgba(Tema.colorTexto.r, Tema.colorTexto.g, Tema.colorTexto.b, 0.06)
                              : "transparent")
                    border.width: celda.marcado ? 2 : 1
                    border.color: celda.marcado ? Tema.colorAccent : Tema.colorBorde

                    Column {
                        anchors.centerIn: parent
                        spacing: 4 * Tema.escala

                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 56 * Tema.escala
                            height: width
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            source: popup.rutaIcono(celda.modelData)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Tema.nombresMetal[celda.modelData]
                            color: celda.marcado ? Tema.colorAccent : Tema.colorTexto
                            font.pixelSize: 12 * Tema.escala
                            font.bold: celda.marcado
                        }
                        // Opacidad y no "visible": así todas las celdas miden
                        // lo mismo y los iconos quedan a la misma altura.
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Idioma.t("etiqueta_tu_marco")
                            opacity: celda.modelData === popup.marco ? 1 : 0
                            color: Tema.colorTextoTenue
                            font.pixelSize: 10 * Tema.escala
                        }
                    }
                    MouseArea {
                        id: zona
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.elegido = celda.modelData
                    }
                }
            }
        }

        Row {
            x: parent.width - width
            spacing: 8 * Tema.escala

            BotonContorno {
                text: Idioma.t("boton_cancelar")
                colorBorde: Tema.colorBorde
                onClicked: popup.close()
            }
            // Quitarla de donde esté puesta (solo en modo lateral).
            BotonContorno {
                visible: popup.modoLateral && (popup.enIzq || popup.enDer)
                text: Idioma.t("boton_quitar")
                colorBorde: Tema.colorPeligro
                onClicked: {
                    if (popup.enIzq && popup.ladoIndice !== 1) popup.quitado("decoracion_lateral_1");
                    if (popup.enDer && popup.ladoIndice !== 0) popup.quitado("decoracion_lateral_2");
                    popup.close();
                }
            }
            BotonRelleno {
                text: Idioma.t("boton_equipar")
                onClicked: {
                    var ac = (!popup.modoLateral || popup.conMetal) && popup.elegido !== popup.marco ? popup.elegido : "";
                    if (popup.modoLateral) {
                        if (popup.ladoIndice !== 1) popup.acabadoElegido("decoracion_lateral_1", popup.codigo, ac);
                        if (popup.ladoIndice !== 0) popup.acabadoElegido("decoracion_lateral_2", popup.codigo, ac);
                    } else {
                        popup.acabadoElegido(popup.slot, popup.codigo, ac);
                    }
                    popup.close();
                }
            }
        }
    }
}
