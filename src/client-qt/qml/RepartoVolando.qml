// RepartoVolando.qml — capa transparente sobre la mesa por la que vuelan cartas
// boca abajo desde el mazo hasta cada asiento (reparto de la mano). Hermana de
// FichasVolando.qml; diseño en docs/plan-animaciones-partida.md (Fase A).
//
// Uso: lanzar(x0, y0, x1, y1, w0, h0, w1, h1, rotFinal, retrasoMs, vueloMs, reverso,
//             nombre, indice)
// Las coordenadas son las de esta capa (Mesa.qml la estira sobre toda la mesa). La
// carta sale con el tamaño de una comunitaria (w0 x h0), se encoge hasta el de la
// mini-carta del asiento (w1 x h1) y termina girada "rotFinal" grados, como el
// abanico. Al aterrizar emite aterrizo(nombre, indice) y se destruye; cuando ya no
// queda ninguna en el aire, todasAterrizaron().
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: capa

    // Tope de seguridad: 9 jugadores x 2 cartas = 18. Por encima no se anima.
    readonly property int maximoEnVuelo: 24
    property int enVuelo: 0

    signal aterrizo(string nombre, int indice)
    signal todasAterrizaron()

    enabled: false   // no captura ratón

    function lanzar(x0, y0, x1, y1, w0, h0, w1, h1, rotFinal, retrasoMs, vueloMs, reverso, nombre, indice) {
        if (enVuelo >= maximoEnVuelo) return false;
        molde.createObject(capa, {
            "x0": x0, "y0": y0, "x1": x1, "y1": y1, "w0": w0, "h0": h0, "w1": w1, "h1": h1,
            "rotFinal": rotFinal, "retraso": retrasoMs, "vuelo": vueloMs, "reverso": reverso,
            "nombre": nombre, "indice": indice
        });
        enVuelo++;
        return true;
    }

    function cartaAterrizada(nombre, indice) {
        enVuelo = Math.max(0, enVuelo - 1);
        aterrizo(nombre, indice);
        if (enVuelo === 0) todasAterrizaron();
    }

    Component {
        id: molde
        Item {
            id: vuela
            property real x0: 0
            property real y0: 0
            property real x1: 0
            property real y1: 0
            property real w0: 0
            property real h0: 0
            property real w1: 0
            property real h1: 0
            property real rotFinal: 0
            property int retraso: 0
            property int vuelo: 300
            property string reverso: ""
            property string nombre: ""
            property int indice: 0
            // 0 = en el mazo, 1 = en el asiento.
            property real progreso: 0
            visible: progreso > 0 || animando.running && retraso === 0
            // Curva suave con un pequeño arco (las cartas "se lanzan", no se arrastran).
            readonly property real arco: Math.min(30 * Tema.escala,
                Math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)) * 0.10)

            width: w0 + (w1 - w0) * progreso
            height: h0 + (h1 - h0) * progreso
            x: x0 + (x1 - x0) * progreso - width / 2
            y: y0 + (y1 - y0) * progreso - Math.sin(Math.PI * progreso) * arco - height / 2
            rotation: rotFinal * progreso
            opacity: Math.min(1, progreso / 0.08)

            SequentialAnimation {
                id: animando
                running: true
                PauseAnimation { duration: vuela.retraso }
                NumberAnimation {
                    target: vuela
                    property: "progreso"
                    from: 0
                    to: 1
                    duration: vuela.vuelo
                    easing.type: Easing.OutCubic
                }
                ScriptAction {
                    script: {
                        capa.cartaAterrizada(vuela.nombre, vuela.indice);
                        vuela.destroy();
                    }
                }
            }

            // Sombra corta + la carta (dorso con el reverso equipado, si lo hay).
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 2
                anchors.leftMargin: 1
                radius: 4 * Tema.escala
                color: Qt.rgba(0, 0, 0, 0.30)
            }
            Carta {
                anchors.fill: parent
                reversoSkin: vuela.reverso
            }
        }
    }
}
