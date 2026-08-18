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
