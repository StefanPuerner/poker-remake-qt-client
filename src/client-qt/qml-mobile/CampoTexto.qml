// CampoTexto.qml — el TextField de la app, ya con su hueco (ver
// MarcoHueco.qml). Antes cada campo se pintaba su propio "background:
// Rectangle" a mano, casi siempre transparente con una raya de 1px
// debajo -- 13 copias solo en el Main.qml de escritorio. Eso era, con
// las palabras del usuario, "solo un borde barato" sobre un panel que ya
// tiene textura de fieltro.
//
// Ahora la chapa está en un sitio: cambiar el aspecto de los campos es
// tocar MarcoHueco.qml, y un campo nuevo lo hereda sin acordarse de
// nada.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import PokerQuickMobile

TextField {
    id: campo
    color: Tema.colorTexto
    placeholderTextColor: Tema.colorTextoMuyTenue
    font.pixelSize: 15 * Tema.escala
    // Sitio suficiente para que el texto no roce el aro dorado. Con
    // padding lateral de verdad, además, un campo centrado y otro
    // alineado a la izquierda se ven igual de holgados.
    leftPadding: 12 * Tema.escala
    rightPadding: 12 * Tema.escala
    topPadding: 15 * Tema.escala
    bottomPadding: 15 * Tema.escala
    // El hueco necesita alto para leerse como tal: un campo que le queda
    // pegado al texto se ve sucio, no hundido. Reportado dos veces
    // (2026-09-09): "la barra de búsqueda es muy estrecha" y, tras un
    // primer intento con 44, "los campos para escribir siguen igual, son
    // muy estrechos".
    //
    // El 44 de aquel primer intento no daba casi nada: medido con una
    // prueba de verdad (un TextField suelto en `qml`), el alto por
    // DEFECTO de Qt ya es 40, así que aquello eran 4px de más. Con 54 de
    // suelo el campo queda por encima de los ~38 de un BotonContorno del
    // mismo tamaño de fuente, que es lo que hace que se lea como un
    // sitio donde escribir y no como una raya.
    implicitHeight: Math.max(54 * Tema.escala,
                             contentHeight + topPadding + bottomPadding)
    background: MarcoHueco {
        activo: campo.activeFocus
    }
}
