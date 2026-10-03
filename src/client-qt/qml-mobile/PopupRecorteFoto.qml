// PopupRecorteFoto.qml (móvil) -- ajuste de una foto antes de subirla. Mismo
// rol y lógica que el de escritorio (ver src/client-qt/qml/PopupRecorteFoto.qml),
// solo cambian las medidas para pantalla táctil. Dos formas
// (2026-10-03):
//  - "circulo" (avatar): cuadrado 1:1, el avatar lo pinta circular después.
//  - "pastilla" (tapete de mesa): la proporción de la pastilla donde se ve la
//    foto en la mesa. El visor tiene esa forma y el recorte sale con esa
//    relación, así lo que se ajusta aquí es exactamente lo que se verá allí.
// La foto se arrastra por detrás del visor y se amplía con el deslizador. Al
// confirmar se emite el rectángulo exacto elegido en píxeles de la imagen
// ORIGINAL (cropX/cropY/cropW/cropH); FotoAvatarHelper lo recorta y reduce al
// tamaño de salida que pide quien abre el popup. Sin ajustes = el recorte
// centrado (zoom 1 = el rectángulo más grande que cabe en el visor).
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Popup {
    id: popup
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(320 * Tema.escala, (parent ? parent.width : 320) - 40 * Tema.escala)
    padding: 20 * Tema.escala

    property url archivo
    // "circulo" (avatar) o "pastilla" (tapete de mesa) -- ver la cabecera.
    property string forma: "circulo"
    readonly property real relacion: forma === "pastilla" ? 2.0 : 1.0
    // Tamaño del visor en píxeles de pantalla. Su relación de aspecto es la
    // del recorte; el alto sale de la relación, no se fija aparte.
    // Tamaño del visor según la altura de la pantalla (2026-10-04): en un móvil
    // horizontal el popup tiene que caber entero, con los botones visibles.
    readonly property real visorLado: Math.max(120 * Tema.escala,
        Math.min(240 * Tema.escala, (parent ? parent.height : 400) - 200 * Tema.escala))
    readonly property real visorW: forma === "pastilla"
        ? Math.min(280 * Tema.escala, visorLado * 1.4) : visorLado
    readonly property real visorH: visorW / relacion
    property real zoom: 1.0
    property real despX: 0
    property real despY: 0
    readonly property real natW: imagen.implicitWidth
    readonly property real natH: imagen.implicitHeight
    // Escala a zoom 1: lo mínimo para que la imagen cubra el visor entero.
    readonly property real escalaBase: natW > 0 && natH > 0
                                       ? Math.max(visorW / natW, visorH / natH) : 1
    readonly property real escalaVisor: natW > 0 ? imagen.width / natW : 1

    signal confirmado(real cropX, real cropY, real cropW, real cropH)

    // Vuelve a centrar la foto (al abrir, al cambiar de zoom, al cambiar de
    // archivo) -- más simple que conservar el desplazamiento al hacer zoom.
    function recentrar() {
        popup.despX = (popup.visorW - imagen.width) / 2;
        popup.despY = (popup.visorH - imagen.height) / 2;
    }

    function acotar(valor, minimo, maximo) {
        return Math.max(minimo, Math.min(maximo, valor));
    }

    // Abre el ajuste para una forma concreta. Por defecto, el avatar.
    function abrirCon(url, formaElegida) {
        popup.forma = formaElegida || "circulo";
        popup.archivo = url;
        popup.zoom = 1.0;
        popup.recentrar();
        popup.open();
    }

    background: Rectangle {
        color: Tema.colorPanel
        radius: 12 * Tema.escala
        border.width: 1
        border.color: Tema.colorAccent
    }

    contentItem: Column {
        width: popup.availableWidth
        spacing: 12 * Tema.escala

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Idioma.t("titulo_ajustar_foto")
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.bold: true
            font.pixelSize: 16 * Tema.escala
        }


        // Visor: la foto va por detrás, recortada a la forma (círculo o
        // pastilla) con una máscara -- la misma técnica que el paño de la
        // mesa. Lo que queda fuera de la forma no se recorta, pero tampoco
        // se ve en la mesa.
        Item {
            id: visor
            anchors.horizontalCenter: parent.horizontalCenter
            width: popup.visorW
            height: popup.visorH

            Item {
                id: fuenteVisor
                anchors.fill: parent
                visible: false
                clip: true
                layer.enabled: true
                Rectangle {
                    anchors.fill: parent
                    color: "#111111"
                }
                Image {
                    id: imagen
                    x: popup.despX
                    y: popup.despY
                    source: popup.archivo
                    width: implicitWidth * popup.escalaBase * popup.zoom
                    height: implicitHeight * popup.escalaBase * popup.zoom
                    onStatusChanged: if (status === Image.Ready) popup.recentrar()
                }
            }

            Item {
                id: mascaraVisor
                anchors.fill: parent
                visible: false
                layer.enabled: true
                layer.smooth: true
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: "black"
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: fuenteVisor
                maskEnabled: true
                maskSource: mascaraVisor
            }

            MouseArea {
                id: arrastre
                anchors.fill: parent
                cursorShape: Qt.OpenHandCursor
                property real ultimoX: 0
                property real ultimoY: 0
                onPressed: (raton) => { ultimoX = raton.x; ultimoY = raton.y; }
                onPositionChanged: (raton) => {
                    popup.despX = popup.acotar(popup.despX + raton.x - ultimoX,
                                               popup.visorW - imagen.width, 0);
                    popup.despY = popup.acotar(popup.despY + raton.y - ultimoY,
                                               popup.visorH - imagen.height, 0);
                    ultimoX = raton.x;
                    ultimoY = raton.y;
                }
            }

            // Contorno de la forma: solo guía visual, el recorte real es el
            // rectángulo del visor (el render en la mesa o en el avatar hace
            // el resto).
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: height / 2
                border.width: 2
                border.color: Tema.colorAccent
                antialiasing: true
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10 * Tema.escala

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Idioma.t("texto_zoom_foto")
                color: Tema.colorTextoTenue
                font.pixelSize: 12 * Tema.escala
            }
            Slider {
                id: zoomSlider
                anchors.verticalCenter: parent.verticalCenter
                width: popup.visorW - 90 * Tema.escala
                from: 1.0
                to: 3.0
                value: popup.zoom
                onMoved: {
                    popup.zoom = value;
                    popup.recentrar();
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12 * Tema.escala

            BotonContorno {
                text: Idioma.t("boton_cancelar")
                onClicked: popup.close()
            }
            BotonRelleno {
                text: Idioma.t("boton_aceptar")
                onClicked: {
                    // Rectángulo visible en el visor, pasado a píxeles de la
                    // imagen original.
                    const cropW = popup.visorW / popup.escalaVisor;
                    const cropH = popup.visorH / popup.escalaVisor;
                    const cropX = -popup.despX / popup.escalaVisor;
                    const cropY = -popup.despY / popup.escalaVisor;
                    popup.confirmado(cropX, cropY, cropW, cropH);
                    popup.close();
                }
            }
        }
    }
}
