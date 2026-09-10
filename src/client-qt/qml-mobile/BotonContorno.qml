// BotonContorno.qml (móvil) — mismo botón "de contorno" del cliente de
// escritorio (fondo transparente, borde de color temático), pero con
// feedback táctil: "pressed" en vez de "hovered" (no existe hover sin
// ratón), y un suelo de alto (Tema.tamanoMinTactil) para que el botón
// nunca quede por debajo del tamaño mínimo accesible al tacto, aunque la
// escala calculada para ese dispositivo diera un número menor. Ver Parte 7
// del plan de diseño móvil, punto 1.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile
import QtQuick.Controls

Button {
    id: botonContorno
    property color colorBorde: Tema.colorAccent
    property real radioBorde: 6 * Tema.escala
    padding: 10 * Tema.escala
    implicitHeight: Math.max(Tema.tamanoMinTactil,
                              contentItem.implicitHeight + topPadding + bottomPadding)
    // En reposo ya NO es transparente del todo (2026-09-09). Sobre un
    // panel con textura de fieltro, un contorno de 1px sin nada detrás no
    // separa el botón del fondo -- "solo es un borde barato", con las
    // palabras del usuario. El caso que lo destapó: los botones de las
    // filas de partidas guardadas, donde además el borde de arriba y el
    // de abajo se confundían con el canto de la propia tarjeta y el botón
    // se leía como dos rayas verticales sueltas.
    //
    // El relleno es un blanco a un 5%: no tiñe (funciona igual en los
    // cinco temas) pero basta para que la superficie exista. El filo
    // claro de arriba y el oscuro de abajo hacen el resto.
    background: Rectangle {
        color: botonContorno.pressed ? botonContorno.colorBorde : Qt.rgba(1, 1, 1, 0.05)
        radius: botonContorno.radioBorde
        border.width: 1
        border.color: botonContorno.colorBorde
        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }
        // Aquí había dos filos de 1px (claro arriba, oscuro abajo). Fuera
        // desde 2026-09-09: ver MarcoHueco.qml -- una raya recta en una
        // caja redondeada deja sus extremos a la vista como rayas sueltas.
        // El relleno tenue de arriba ya hace el trabajo de separar el
        // botón del paño, que era el problema original.
    }
    contentItem: Text {
        text: botonContorno.text
        color: botonContorno.pressed ? Tema.colorPanel : botonContorno.colorBorde
        font.pixelSize: 14 * Tema.escala
        font.family: Tema.fuenteElegante
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
