// TecladoNumerico.qml — teclado numérico propio (0-9 + borrar) en vez de
// depender del teclado del sistema. El teclado numérico de Android varía
// de tamaño/diseño entre fabricantes y sigue ocupando bastante — uno
// propio se hace del tamaño exacto que hace falta, con el mismo lenguaje
// visual del resto de la app. Pensado sobre todo para el importe de
// subida (el campo numérico más usado de toda una partida), reutilizado
// por CampoEmergente.qml en modo "soloNumerico". Ver Parte 7 del plan de
// diseño móvil.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Grid {
    id: teclado
    columns: 3
    // Antes 8*escala con teclas a 52*escala (mínimo 1.1x tamanoMinTactil):
    // en un móvil de landscape corto (h359dp reales, escala~0.9) el
    // conjunto entero + el resto del popup superaba la altura de la
    // pantalla por abajo (visto en real). Recortado a lo justo mientras
    // cada tecla siga respetando Tema.tamanoMinTactil.
    spacing: 5 * Tema.escala
    signal digito(string valor)
    signal borrar()

    // "" = hueco vacío, mantiene el 0 centrado y el borrar a la derecha
    // en la última fila, como cualquier teclado numérico de verdad.
    // "<-" en vez de "⌫": el glifo de borrado no está en EBGaramond NI en
    // el font de sistema que usa este build de Android (visto en real: se
    // mostraba un cuadrado/tofu) -- ASCII puro es lo único garantizado.
    readonly property var teclas: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "<-"]

    Repeater {
        model: teclado.teclas
        delegate: Rectangle {
            id: tecla
            required property string modelData
            width: (teclado.width - 2 * teclado.spacing) / 3
            height: Math.max(Tema.tamanoMinTactil, 40 * Tema.escala)
            radius: 6 * Tema.escala
            visible: modelData !== ""
            color: area.pressed ? Tema.colorAccent : Tema.colorFondo
            border.width: 1
            border.color: Tema.colorBorde
            Behavior on color { ColorAnimation { duration: 80 } }

            Text {
                anchors.centerIn: parent
                text: tecla.modelData
                color: area.pressed ? Tema.colorPanel : "white"
                font.pixelSize: 17 * Tema.escala
            }

            MouseArea {
                id: area
                anchors.fill: parent
                enabled: tecla.visible
                onClicked: tecla.modelData === "<-" ? teclado.borrar() : teclado.digito(tecla.modelData)
            }
        }
    }
}
