// CajaTitulo.qml — placa con el nombre del título equipado. Diseñada
// 2026-09-01 (pedido explícito: "tenemos que diseñar la caja de
// titulo, deberias tener indicaciones acerca de ella") ANTES de la
// pantalla "Personalizar avatar" (Marco/Texturas/Efectos/Decoraciones/
// Títulos) que la va a necesitar -- primer uso real: pestaña Cuenta >
// Perfil, debajo de la identidad del jugador.
//
// Reutiliza DELIBERADAMENTE el mismo lenguaje visual que la etiqueta
// de rareza de un logro (ver Main.qml, tarjeta de Logros: píldora de
// borde fino, sin relleno sólido, texto del mismo color que el borde)
// en vez de inventar un tratamiento nuevo -- un título ES la
// recompensa de un logro (o, comprado, el pariente "sin rareza" de
// esa misma familia), así que debe sentirse parte del mismo conjunto,
// no una pieza suelta con su propio estilo. Mismos 3 colores de rareza
// que Main.qml::colorRareza() -- pasados desde fuera en vez de
// duplicar esa función aquí, un solo sitio con la tabla de colores.
//
// SIEMPRE visible, aunque no haya título (2026-09-01, corregido el
// mismo día -- primer diseño la ocultaba del todo con nombre==="",
// 0x0, mismo criterio que las decoraciones del Avatar; pero un título
// NUNCA se ve en el propio anillo como una decoración sí se vería --
// sin ningún rastro en pantalla, la caja entera pasaba desapercibida.
// Ahora, sin título, muestra un estado vacío discreto ("Sin título",
// borde atenuado en vez de por rareza) -- la caja EXISTE siempre como
// sitio reconocible, solo cambia lo que dice dentro. Confirmado por el
// usuario como correcto para una primera versión.
//
// A PROPÓSITO sin ningún "tamano"/parámetro de escala propio -- solo
// Tema.escala (el mismo global que usa toda la app), NUNCA proporcional
// al tamano del Avatar de al lado (pedido explícito 2026-09-01: "es
// importante que el titulo no escale igual para el avatar, cuando el
// avatar es pequeño si reducimos proporcionalmente el titulo, no se
// leera nada"). Así, el mismo texto legible vale tanto junto al avatar
// grande de Tienda/Personalizar (120*escala) como, el día que se use,
// junto a uno pequeño como el del asiento en mesa (56*escala) -- NO
// añadir un binding que ate el tamaño de fuente de aquí al de un
// Avatar concreto.
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: caja
    required property string nombre     // "" = sin título (la caja se ve igual, atenuada)
    required property color colorTier   // Main.qml::colorRareza(rareza) -- ignorado si nombre === ""

    readonly property bool tieneTitulo: caja.nombre !== ""
    readonly property string textoMostrado: caja.tieneTitulo ? caja.nombre : "Sin título"
    readonly property color colorMostrado: caja.tieneTitulo ? caja.colorTier : Tema.colorTextoMuyTenue

    width: textoTitulo.implicitWidth + 22 * Tema.escala
    height: textoTitulo.implicitHeight + 9 * Tema.escala

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: 1.2
        border.color: caja.colorMostrado
        opacity: caja.tieneTitulo ? 1.0 : 0.55
    }
    Text {
        id: textoTitulo
        anchors.centerIn: parent
        text: caja.textoMostrado
        color: caja.colorMostrado
        font.family: Tema.fuenteElegante
        font.italic: !caja.tieneTitulo
        font.pixelSize: 11 * Tema.escala
        font.letterSpacing: 0.4
    }
}
