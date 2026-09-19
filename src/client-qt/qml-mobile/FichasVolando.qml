// FichasVolando.qml — capa transparente sobre la mesa por la que vuelan fichas
// doradas de un punto a otro (apuestas: asiento -> bote; cobro: bote ->
// ganador). Diseño y decisiones en docs/plan-animaciones-mesa.md.
//
// Uso: lanzar(x0, y0, x1, y1, cantidadFichas, retrasoMs). Las coordenadas son
// las de esta capa (que Mesa.qml estira sobre toda la mesa). Cada ficha es un
// Item que se crea al lanzar y se destruye al llegar; "aterrizaron" se emite
// cuando ya no queda ninguna en el aire.
//
// La ficha se dibuja con Rectangle (no con IconoFicha): IconoFicha es un
// Canvas y pinta de forma asíncrona, así que cada ficha nueva saldría un
// frame en blanco.
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: capa

    // Tope de fichas a la vez: con bots rápidos o modo offline pueden llegar
    // muchas apuestas casi juntas. Por encima se omite la animación (el bote
    // se actualiza igual) -- nunca debe frenar el juego ni la GPU.
    readonly property int maximoEnVuelo: 24
    readonly property real tamanoFicha: 16 * Tema.escala
    property int enVuelo: 0
    // Duración de un vuelo, en ms (con el escalonado, ~0.9 s para 8 fichas).
    property int duracionVuelo: 460
    property int escalonado: 50

    signal aterrizaron()

    enabled: false   // no captura ratón
    function lanzar(x0, y0, x1, y1, cantidad, retrasoMs) {
        if (cantidad <= 0 || enVuelo + cantidad > maximoEnVuelo) return false;
        for (var i = 0; i < cantidad; i++) {
            // Cada ficha con un pequeño desvío lateral para que no vayan en fila india.
            var desvio = ((i % 3) - 1) * 4 * Tema.escala;
            molde.createObject(capa, {
                "x0": x0 + desvio, "y0": y0,
                "x1": x1 - desvio, "y1": y1,
                "retraso": (retrasoMs || 0) + i * escalonado
            });
            enVuelo++;
        }
        return true;
    }

    function fichaAterrizada() {
        enVuelo = Math.max(0, enVuelo - 1);
        if (enVuelo === 0) aterrizaron();
    }

    Component {
        id: molde
        Item {
            id: ficha
            property real x0: 0
            property real y0: 0
            property real x1: 0
            property real y1: 0
            property int retraso: 0
            // 0 = en el origen, 1 = en el destino.
            property real progreso: 0
            // Arco: sube en el punto medio, proporcional a la distancia.
            readonly property real arco: Math.min(60 * Tema.escala,
                Math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)) * 0.18)

            width: capa.tamanoFicha
            height: width
            x: x0 + (x1 - x0) * progreso - width / 2
            y: y0 + (y1 - y0) * progreso - Math.sin(Math.PI * progreso) * arco - height / 2
            // Aparece y se apaga suavemente: en el origen y el destino no
            // hay "salto" visible.
            opacity: Math.min(1, progreso / 0.12) * Math.min(1, (1 - progreso) / 0.15)
            scale: 0.6 + 0.4 * Math.min(1, progreso / 0.2)

            SequentialAnimation on progreso {
                running: true
                PauseAnimation { duration: ficha.retraso }
                NumberAnimation {
                    from: 0
                    to: 1
                    duration: capa.duracionVuelo
                    easing.type: Easing.InOutQuad
                }
                ScriptAction {
                    script: {
                        capa.fichaAterrizada();
                        ficha.destroy();
                    }
                }
            }

            // Sombra corta, disco dorado con canto más oscuro y aro interior.
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 2
                radius: width / 2
                color: Qt.rgba(0, 0, 0, 0.35)
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                border.width: 1.5
                border.color: Qt.darker(Tema.colorAccent, 1.6)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(Tema.colorAccent, 1.3) }
                    GradientStop { position: 1.0; color: Qt.darker(Tema.colorAccent, 1.15) }
                }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: parent.width * 0.22
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.55)
            }
        }
    }
}
