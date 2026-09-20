// CartaFlip.qml — una carta PROPIA (hueco de la barra inferior) que se voltea al recibir su valor.
//
// Muestra siempre algo: el dorso (con el reverso equipado) mientras no hay carta, y la cara cuando
// llega. "objetivo" es la carta que le toca ("" = ninguna). "retener" la mantiene boca abajo aunque
// ya tenga objetivo (durante el reparto, hasta que la carta voladora aterriza): al soltarse, se
// voltea (giro sobre el eje Y). Sin "animar", el cambio es instantáneo. "presente" false la oculta
// (la carta ya volvió al dealer/mazo al acabar la mano).
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: hueco
    property string objetivo: ""
    property bool retener: false
    property bool animar: true
    property bool presente: true
    property string reversoSkin: ""
    property real velocidad: 1.0
    property string mostrado: ""

    width: carta.width
    height: carta.height
    opacity: presente ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 250 } }

    readonly property string deseado: retener ? "" : objetivo
    onDeseadoChanged: {
        if (deseado === mostrado) return;
        if (deseado !== "" && mostrado === "" && animar) {
            volteo.restart();
        } else {
            volteo.stop();
            giro.angle = 0;
            mostrado = deseado;
        }
    }
    Component.onCompleted: mostrado = deseado

    Carta {
        id: carta
        codigo: hueco.mostrado
        propia: true
        reversoSkin: hueco.reversoSkin
        transform: Rotation {
            id: giro
            origin.x: carta.width / 2
            origin.y: carta.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: 0
        }
    }
    SequentialAnimation {
        id: volteo
        NumberAnimation { target: giro; property: "angle"; to: 90; duration: 110 / Math.max(0.05, hueco.velocidad); easing.type: Easing.InQuad }
        ScriptAction { script: hueco.mostrado = hueco.deseado }
        NumberAnimation { target: giro; property: "angle"; to: 0; duration: 110 / Math.max(0.05, hueco.velocidad); easing.type: Easing.OutQuad }
    }
}
