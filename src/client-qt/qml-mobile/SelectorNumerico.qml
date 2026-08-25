// SelectorNumerico.qml — stepper "[−] valor [+]" para campos numéricos de
// rango acotado (tamaño de mesa, ciega grande, saldo inicial, núm. manos,
// monte fijo...). Cubre el ajuste rápido común sin abrir teclado; tocar el
// número abre CampoEmergente en modo numérico para un valor exacto que no
// caiga en un paso redondo — un único componente nuevo cubre los 5 campos
// numéricos de Crear sala. Hermano de SelectorPildoras.qml (esa es para
// opciones categóricas, esta para rangos). Ver Parte 7 del plan de diseño
// móvil, punto 4.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile
import QtQuick.Controls

Row {
    id: selectorNumerico
    property int valor: 0
    property int minimo: 0
    property int maximo: 999999
    property int paso: 1
    signal cambiado(int nuevoValor)

    spacing: 10 * Tema.escala

    function fijar(v) {
        var acotado = Math.max(minimo, Math.min(maximo, v));
        if (acotado !== valor) {
            valor = acotado;
            cambiado(acotado);
        }
    }

    Rectangle {
        width: Tema.tamanoMinTactil
        height: Tema.tamanoMinTactil
        radius: 8 * Tema.escala
        color: areaMenos.pressed ? Tema.colorAccent : "transparent"
        border.width: 1
        border.color: Tema.colorBorde
        Text {
            anchors.centerIn: parent
            text: "−"
            font.pixelSize: 18 * Tema.escala
            color: areaMenos.pressed ? Tema.colorPanel : Tema.colorTextoTenue
        }
        MouseArea {
            id: areaMenos
            anchors.fill: parent
            onClicked: selectorNumerico.fijar(selectorNumerico.valor - selectorNumerico.paso)
        }
    }

    Rectangle {
        width: Math.max(textoValor.implicitWidth + 24 * Tema.escala, 70 * Tema.escala)
        height: Tema.tamanoMinTactil
        radius: 8 * Tema.escala
        color: Tema.colorFondo
        border.width: 1
        border.color: Tema.colorBorde
        Text {
            id: textoValor
            anchors.centerIn: parent
            text: selectorNumerico.valor.toString()
            font.pixelSize: 15 * Tema.escala
            color: Tema.colorTexto
        }
        MouseArea {
            anchors.fill: parent
            onClicked: campoExacto.abrir(selectorNumerico.valor.toString())
        }
    }

    Rectangle {
        width: Tema.tamanoMinTactil
        height: Tema.tamanoMinTactil
        radius: 8 * Tema.escala
        color: areaMas.pressed ? Tema.colorAccent : "transparent"
        border.width: 1
        border.color: Tema.colorBorde
        Text {
            anchors.centerIn: parent
            text: "+"
            font.pixelSize: 18 * Tema.escala
            color: areaMas.pressed ? Tema.colorPanel : Tema.colorTextoTenue
        }
        MouseArea {
            id: areaMas
            anchors.fill: parent
            onClicked: selectorNumerico.fijar(selectorNumerico.valor + selectorNumerico.paso)
        }
    }

    // Reparentado al overlay del Window: este componente vive anidado
    // dentro de formularios (Crear sala...), pero el popup tiene que
    // posicionarse relativo a la PANTALLA completa, no al pequeño Row del
    // stepper — Overlay.overlay es justo el item que Qt Quick Controls
    // reserva para esto.
    CampoEmergente {
        id: campoExacto
        parent: Overlay.overlay
        etiqueta: "Valor exacto"
        soloNumerico: true
        onAceptado: (texto) => {
            var n = parseInt(texto, 10);
            if (!isNaN(n)) selectorNumerico.fijar(n);
        }
    }
}
