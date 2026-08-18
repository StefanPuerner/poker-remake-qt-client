// BotonContorno.qml — botón "de contorno": fondo transparente, borde de un
// color temático — como en el boceto, en vez del botón gris sólido de
// Material por defecto. Qt Quick Controls deja sustituir "background" y
// "contentItem" de cualquier control; aquí se rehacen los dos con un
// Rectangle y un Text a medida. Extraído de Main.qml.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Button {
    id: botonContorno
    property color colorBorde: Tema.colorAccent
    // 6 = esquinas redondeadas normales; 999 (o cualquier valor mayor
    // que medio alto) da forma de píldora, como el botón de "Entrar a
    // la mesa" en Inicio.
    property real radioBorde: 6 * Tema.escala
    // "hovered" ya existe en cualquier Button de Qt Quick Controls —
    // solo hay que activar "hoverEnabled" para que se actualice de
    // verdad al pasar el ratón por encima (por defecto no siempre está
    // activo). "Behavior on color" anima la transición en vez de un
    // cambio brusco.
    hoverEnabled: true
    // Sin font.pixelSize/padding explícitos, el tamaño del botón entero
    // (ancho Y alto, vía el sizing implícito de Button) dependía del
    // tamaño de fuente por defecto de Qt Quick Controls — que nunca
    // cambia con Tema.escala. Resultado real visto en pruebas: CADA
    // botón de contorno del programa se quedaba fijo mientras el resto
    // de la interfaz crecía/encogía con el zoom. Al escalar el font y el
    // padding, el ancho/alto implícitos escalan juntos y proporcionales.
    padding: 10 * Tema.escala
    background: Rectangle {
        color: botonContorno.hovered ? botonContorno.colorBorde : "transparent"
        radius: botonContorno.radioBorde
        border.width: 1
        border.color: botonContorno.colorBorde
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }
    contentItem: Text {
        text: botonContorno.text
        color: botonContorno.hovered ? Tema.colorPanel : botonContorno.colorBorde
        font.pixelSize: 14 * Tema.escala
        font.family: Tema.fuenteElegante
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
