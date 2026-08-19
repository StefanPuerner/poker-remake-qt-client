// PanelVoto.qml (móvil) — idéntico al de escritorio: sin MouseArea/hover,
// no necesita ningún cambio para tacto.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Row {
    required property bool soyHost
    signal continuar()
    signal abandonar()
    signal guardarYSalir()

    spacing: 8 * Tema.escala
    BotonRelleno {
        text: "Continuar a la siguiente mano"
        onClicked: {
            redcliente.votar();
            continuar();
        }
    }
    BotonContorno {
        text: "Abandonar partida"
        colorBorde: Tema.colorPeligro
        onClicked: {
            redcliente.abandonar();
            abandonar();
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
}
