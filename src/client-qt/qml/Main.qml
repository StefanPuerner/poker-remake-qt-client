// Main.qml — ventana raíz de PokerClientQt (andamiaje inicial)
//
// Punto de partida deliberadamente vacío: aquí empieza a construirse la
// interfaz real (mesa, panel de turno, chat, perfiles de rivales) siguiendo
// el documento de diseño de la rama variante-Qt. De momento solo confirma
// que Qt Quick compila, carga el módulo QML y se conecta con C++.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Window

ApplicationWindow {
    id: ventana
    Material.accent: colorAccent

    // ── Tema de color ──────────────────────────────────────────────────────
    // Centralizado aquí en vez de repetir códigos de color sueltos por todo
    // el fichero. "temas" es la lista de paletas disponibles; "temaActual"
    // (índice) decide cuál está activa — todo el resto del archivo sigue
    // usando "ventana.colorX" tal cual, sin enterarse de que ahora hay más
    // de un tema: cambiar temaActual repinta toda la interfaz sola, porque
    // cada colorX de abajo es un binding que lee de la paleta activa.
    //
    // colorPeligro se queda FUERA de la paleta a propósito: es un color con
    // significado (retirarse/abandonar/peligro), no una cuestión estética —
    // que signifique lo mismo pase lo que pase con el tema importa más que
    // que combine perfecto con cada paño.
    readonly property var temas: [
        {
            nombre: "Verde clásico",
            fondo: "#0B1A14", tapete: "#1B4332", panel: "#0F2419", borde: "#2A5A44",
            accent: "#C08F3E", textoTenue: "#9AA79D", textoMuyTenue: "#6B8577", nombreAjeno: "#7FBFA8"
        },
        {
            nombre: "Azul medianoche",
            fondo: "#0A141F", tapete: "#173250", panel: "#0D1B29", borde: "#2A4A63",
            accent: "#B8C4CE", textoTenue: "#9AACB8", textoMuyTenue: "#5E7A8C", nombreAjeno: "#7C93A8"
        },
        {
            nombre: "Burdeos",
            fondo: "#1A0B0E", tapete: "#4D1B26", panel: "#240F14", borde: "#632A38",
            accent: "#D4A24E", textoTenue: "#B89AA0", textoMuyTenue: "#8C6B70", nombreAjeno: "#BF7F8F"
        },
        {
            nombre: "Grafito",
            fondo: "#101214", tapete: "#2B2E33", panel: "#17191C", borde: "#44484E",
            accent: "#C77B4E", textoTenue: "#A3A8AE", textoMuyTenue: "#6E7378", nombreAjeno: "#8FA3AE"
        }
    ]
    property int temaActual: 0

    readonly property color colorFondo: temas[temaActual].fondo // fondo general de la ventana, el más oscuro de los tres
    readonly property color colorTapete: temas[temaActual].tapete // paño de la mesa, el más claro/saturado
    readonly property color colorPanel: temas[temaActual].panel // paneles (chat/historial, avatares, cartas comunitarias de fondo)
    readonly property color colorBorde: temas[temaActual].borde // línea sutil entre paños/paneles
    readonly property color colorAccent: temas[temaActual].accent // color "temático" de la paleta activa
    readonly property color colorPeligro: "#C0524A" // rojo — retirarse/abandonar/all-in/tiempo agotándose (constante, ver arriba)
    readonly property color colorTextoTenue: temas[temaActual].textoTenue // texto secundario sobre fondo oscuro
    readonly property color colorTextoMuyTenue: temas[temaActual].textoMuyTenue // texto terciario (horas, etiquetas pequeñas)
    readonly property color colorNombreAjeno: temas[temaActual].nombreAjeno // nombre de OTRO jugador en el historial (el propio va en colorAccent)

    // color.toString() en QML devuelve "#AARRGGBB" (con canal alfa) o
    // "#RRGGBB" según la versión — ninguno de los dos es fiable a pelo
    // dentro de un <font color=...>: el de 8 dígitos lo ignora en
    // silencio. Los últimos 6 caracteres son siempre "RRGGBB" en los dos
    // casos, así que esto da un hex limpio pase lo que pase.
    function colorHex(c) {
        return "#" + c.toString().slice(-6);
    }

    // El historial usa Text.RichText para colorear el punto y el nombre
    // del jugador dentro de la misma línea — escapar por si un nombre de
    // jugador (no viene sanitizado contra HTML, solo contra el protocolo)
    // contuviera "<", ">" o "&".
    function escapeHtml(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // ── Fuente empaquetada (fuera de QML puro) ────────────────────────────
    // Los nombres de fuente de sistema del boceto ("Iowan Old Style",
    // "Georgia"...) no existen en Linux ni están garantizados en Android, así
    // que en vez de referenciar una fuente por nombre y confiar en que el
    // sistema la tenga, se empaqueta el fichero real como recurso Qt
    // (ver CMakeLists.txt, RESOURCES de qt_add_qml_module) y se carga aquí.
    // Así el resultado es idéntico en cualquier plataforma, sin depender de
    // qué tenga instalado quien lo ejecute.
    // EB Garamond — SIL Open Font License 1.1, ver assets/fonts/OFL.txt.
    FontLoader {
        id: cargadorFuenteElegante
        source: "qrc:/qt/qml/PokerQuick/assets/fonts/EBGaramond.ttf"
    }
    // Un id (como "cargadorFuenteElegante") no se puede leer desde fuera como
    // si fuera una property del objeto que lo contiene — por eso se expone
    // aquí como property de verdad, para que "Carta" (un componente aparte)
    // pueda usarla cualificada como "ventana.fuenteElegante".
    property string fuenteElegante: cargadorFuenteElegante.name

    component Asiento: Column {
        property string saldo
        property string nombre
        // "activo": este asiento tiene el turno ahora mismo (lo sabe
        // cualquiera, viene de GAME_STATE). "fraccionTiempo": 1.0 = tiempo
        // completo, 0.0 = agotado — el servidor difunde el mismo timeout_ms
        // en cada turno (onTurnoIniciado), así que se anima igual para
        // cualquier asiento activo, no solo el del propio jugador.
        property bool activo: false
        property real fraccionTiempo: 1.0
        // Inferido del lado del cliente (ver "retirados" en la ventana) —
        // el asiento entero se atenúa, sigue en la mesa pero el ojo ya no
        // se detiene ahí.
        property bool retirado: false
        opacity: retirado ? 0.45 : 1.0
        onActivoChanged: anillo.requestPaint()
        onFraccionTiempoChanged: if (activo)
            anillo.requestPaint()
        spacing: 8

        Item {
            // Column no centra los hijos de distinto ancho — cada uno se
            // queda pegado a la izquierda por defecto. Centramos a mano con
            // "x", que Column no toca (solo gestiona la posición vertical).
            x: (parent.width - width) / 2
            width: 56 * ventana.escala + 10
            height: 56 * ventana.escala + 10

            // Halo del asiento activo: dos anillos concéntricos con
            // opacidad decreciente en vez de blur de verdad (ver "Sistema
            // visual", sección 15) — con hasta 9 asientos en mesa, un glow
            // real en cada uno sí se notaría en hardware modesto.
            Rectangle {
                visible: activo
                anchors.centerIn: parent
                width: parent.width + 16
                height: parent.height + 16
                radius: width / 2
                color: "transparent"
                border.width: 7
                border.color: Qt.rgba(ventana.colorAccent.r, ventana.colorAccent.g, ventana.colorAccent.b, 0.12)
            }
            Rectangle {
                visible: activo
                anchors.centerIn: parent
                width: parent.width + 5
                height: parent.height + 5
                radius: width / 2
                color: "transparent"
                border.width: 3
                border.color: Qt.rgba(ventana.colorAccent.r, ventana.colorAccent.g, ventana.colorAccent.b, 0.3)
            }

            // Anillo del temporizador: QML no tiene el "conic-gradient" de
            // CSS (un color que rellena según un porcentaje angular), así
            // que se dibuja a mano con Canvas — un arco que empieza arriba
            // (-90°) y recorre "fraccionTiempo" de la vuelta completa en
            // sentido horario. Solo visible en el asiento con turno; pasa a
            // rojo cuando queda poco tiempo.
            Canvas {
                id: anillo
                anchors.fill: parent
                visible: activo
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var cx = width / 2;
                    var cy = height / 2;
                    var r = width / 2 - 2;
                    ctx.strokeStyle = fraccionTiempo < 0.2 ? ventana.colorPeligro : ventana.colorAccent;
                    ctx.lineWidth = 3;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + fraccionTiempo * 2 * Math.PI);
                    ctx.stroke();
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 56 * ventana.escala
                height: 56 * ventana.escala
                radius: width / 2
                border.width: 2
                // Dorado solo cuando de verdad es tu turno — antes era
                // dorado siempre, así que "activo" no se distinguía de un
                // asiento cualquiera más que por el aro del tiempo.
                border.color: activo ? ventana.colorAccent : ventana.colorBorde
                Behavior on border.color {
                    ColorAnimation { duration: 150 }
                }
                // Degradado en vez de color plano — mismo derivado de
                // colorPanel que la barra superior y los botones, así el
                // asiento se distingue del tapete detrás sin inventar un
                // color nuevo por tema.
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(ventana.colorPanel, 1.6) }
                    GradientStop { position: 1.0; color: ventana.colorPanel }
                }
                Text {
                    anchors.centerIn: parent
                    text: nombre.charAt(0)
                    color: ventana.colorAccent
                    font.family: ventana.fuenteElegante
                }
            }
        }
        Rectangle {
            x: (parent.width - width) / 2
            color: "black"
            opacity: 0.70
            border.width: 2
            width: infoAsiento.width * 1.2
            height: infoAsiento.height * 1.
            radius: width / 10
            Column {
                id: infoAsiento
                anchors.centerIn: parent
                Text {
                    text: nombre
                    color: "white"
                    font.family: ventana.fuenteElegante
                }
                Text {
                    text: saldo
                    color: ventana.colorAccent
                    font.bold: true
                    font.family: ventana.fuenteElegante
                }
            }
        }
    }

    // ── Asiento en miniatura, para la lista de conectados del lobby — no
    // es "Asiento" reducido, es más simple a propósito (sin placa, sin
    // saldo, sin anillo de turno): en el lobby no se juega todavía.
    component AsientoMini: Column {
        property string nombre
        spacing: 8
        Rectangle {
            x: (parent.width - width) / 2
            width: 48 * ventana.escala
            height: 48 * ventana.escala
            radius: width / 2
            color: ventana.colorPanel
            border.width: 2
            border.color: ventana.colorBorde
            Text {
                anchors.centerIn: parent
                text: nombre.charAt(0)
                color: ventana.colorAccent
                font.family: ventana.fuenteElegante
            }
        }
        Text {
            x: (parent.width - width) / 2
            text: nombre
            color: ventana.colorTextoTenue
            font.pixelSize: 11
        }
    }

    // ── Mesa: reparte los asientos en un óvalo, cartas comunitarias + bote
    // en el centro. La parte de trigonometría (Math.cos/Math.sin para
    // repartir N asientos en un óvalo) no es "QML puro" en el sentido de que
    // no es un patrón exclusivo de QML — es JavaScript normal dentro de un
    // property binding, pero como es la primera vez que aparece en el
    // proyecto lo dejo yo, comentado paso a paso.
    component Mesa: Item {
        id: mesa
        // jugadores: se le pasa el ListModel jugadoresPartida tal cual
        // (con roles nombre/saldo). cartasMesa: array de códigos ("QH", "2C"...).
        property var jugadores
        property var cartasMesa: []
        property int bote: 0
        // Para resaltar el asiento activo , solo en el caso del propio
        // jugador (del resto no conocemos su tiempo real), animar la cuenta
        // atrás en su anillo.
        property string turnoNombre: ""
        property string miNombreJugador: ""
        property real fraccionTiempo: 1.0
        property var retirados: []

        // Índice del propio jugador dentro de "jugadores" — se usa para
        // rotar todos los asientos de forma que el propio siempre caiga
        // abajo (index 0 en la fórmula del ángulo), sin importar en qué
        // posición del modelo venga desde el servidor. Se recalcula solo
        // cuando cambia "count" (el modelo se reconstruye entero en cada
        // GAME_STATE, clear()+append(), así que basta con eso).
        property int miIndice: {
            for (var i = 0; i < jugadores.count; i++) {
                if (jugadores.get(i).nombre === miNombreJugador) return i;
            }
            return 0;
        }

        // Doble borde: un segundo anillo, más grande y sin relleno, alrededor
        // del tapete — mismo truco que el aro dorado de las cartas propias
        // (un Rectangle no recorta ni molesta a los que están fuera de él).
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 14
            height: parent.height + 14
            radius: height / 2
            color: "transparent"
            border.color: ventana.colorBorde
            border.width: 1
        }

        // El tapete: forma de "pastilla" (extremos redondos, centro
        // plano) — igual que en el boceto, no una elipse continua.
        // "radius: height/2" con un ancho mayor que el alto da justo eso.
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            border.color: ventana.colorBorde
            border.width: 3
            // Degradado en vez de color plano — más claro arriba, como si
            // cayera luz cenital sobre el tapete (ver "Sistema visual",
            // sección 14). Una radial de verdad pediría QtQuick.Shapes o
            // Qt5Compat.GraphicalEffects — este lineal ya da la sensación
            // de profundidad sin añadir ningún import nuevo.
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(ventana.colorTapete, 1.22) }
                GradientStop { position: 1.0; color: ventana.colorTapete }
            }
        }

        // Centro de la mesa: cartas comunitarias arriba, bote debajo.
        Column {
            anchors.centerIn: parent
            spacing: 10
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                // Siempre 5 posiciones desde el preflop, no solo cuando ya
                // hay cartas reveladas — las que faltan se ven boca abajo
                // (Carta con codigo vacío) en vez de dejar el hueco vacío.
                Repeater {
                    model: 5
                    delegate: Carta {
                        required property int index
                        codigo: index < mesa.cartasMesa.length ? mesa.cartasMesa[index] : ""
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Bote: " + mesa.bote
                color: ventana.colorAccent
                font.bold: true
                font.family: ventana.fuenteElegante
            }
        }

        // Asientos: uno por jugador, repartidos a partes iguales alrededor
        // de una elipse (no números fijos como en el boceto, porque el
        // número de jugadores puede cambiar). Cada delegate es un Item
        // "posicionador" que calcula su propio x/y con trigonometría y
        // mete un Asiento normal dentro — así Asiento no necesita saber
        // nada de mesas ni de ángulos, sigue siendo reutilizable.
        Repeater {
            model: mesa.jugadores
            delegate: Item {
                id: posicionador
                required property string nombre
                required property string saldo
                required property int index

                // Ángulo de este asiento en radianes. 2*PI repartido entre
                // el número total de jugadores da un hueco igual a cada
                // uno; Math.PI/2 de partida para que el asiento de índice
                // relativo 0 caiga abajo del todo, no a la derecha.
                //
                // "índice relativo" (no el índice crudo del modelo): se
                // resta mesa.miIndice para que el propio jugador siempre
                // caiga en la posición 0 (abajo), sea cual sea su índice
                // real en la lista que manda el servidor — el resto de
                // asientos rota junto con él, conservando su orden relativo.
                property int indiceRelativo: (index - mesa.miIndice + mesa.jugadores.count) % mesa.jugadores.count
                property real angulo: Math.PI / 2 + (2 * Math.PI * indiceRelativo) / mesa.jugadores.count

                // Centro de la mesa + radio*coseno/seno del ángulo = punto
                // sobre la elipse. Restar width/height/2 porque x/y en QML
                // posicionan la esquina superior-izquierda, no el centro.
                x: mesa.width / 2 + (mesa.width / 2 - 40) * Math.cos(angulo) - width / 2
                y: mesa.height / 2 + (mesa.height / 2 - 40) * Math.sin(angulo) - height / 2
                width: asientoReal.width
                height: asientoReal.height

                Asiento {
                    id: asientoReal
                    nombre: posicionador.nombre
                    saldo: posicionador.saldo
                    activo: posicionador.nombre === mesa.turnoNombre
                    // Antes solo se animaba el aro en el propio asiento
                    // (era la única aproximación posible sin timeout_ms real
                    // para los demás). Ahora el servidor difunde el mismo
                    // dato en cada turno (onTurnoIniciado), así que cualquier
                    // asiento activo anima su cuenta atrás real.
                    fraccionTiempo: posicionador.nombre === mesa.turnoNombre ? mesa.fraccionTiempo : 1.0
                    retirado: mesa.retirados.indexOf(posicionador.nombre) !== -1
                }
            }
        }
    }

    component Carta: Rectangle {
        // "bocaAbajo" o codigo vacío: dorso de carta (comunitaria todavía
        // no revelada). Con codigo real, siempre se ve la cara — así que
        // basta con no pasar "codigo" (o pasar "") para pedir un dorso.
        readonly property bool bocaAbajo: codigo.length === 0
        property string codigo
        property string rango: codigo.slice(0, codigo.length - 1)
        // El servidor manda la letra cruda del palo (H/D/C/S); "palo" es el
        // símbolo que se muestra, derivado de esa letra.
        property string letraPalo: codigo.slice(-1)
        readonly property string palo: letraPalo === "H" ? "♥" : letraPalo === "D" ? "♦" : letraPalo === "C" ? "♣" : letraPalo === "S" ? "♠" : "?"
        property bool propia: false
        readonly property bool esRojo: letraPalo === "H" || letraPalo === "D"
        // Proporcional al propio tamaño de la carta, no un número fijo — así
        // si el ancho cambia (otra pantalla, otro contexto), el texto escala con él.
        readonly property int tamanoFuente: Math.round(width * 0.20)
        // Margen entre el índice de esquina y el borde de la carta, también
        // proporcional — para que no quede pegado si el tamaño cambia.
        readonly property int margen: Math.round(width * 0.12)
        // Separación entre el borde real de la carta y el aro dorado — QML no
        // tiene el "outline-offset" de CSS (un borde que flota fuera del
        // elemento, con hueco), así que se imita con un Rectangle aparte, sin
        // relleno, más grande que la carta y centrado sobre ella.
        readonly property int separacionAro: Math.round(width * 0.08)
        color: bocaAbajo ? ventana.colorTapete : "#efe6d3"
        radius: 6
        border.width: bocaAbajo ? 2 : 0
        border.color: ventana.colorAccent
        width: (propia ? 80 : 60) * ventana.escala // medidas quasi aleatorias, habra que ver lo que sea ideal
        height: (propia ? 112 : 80) * ventana.escala

        Rectangle {
            visible: propia && !bocaAbajo
            anchors.centerIn: parent
            width: parent.width + separacionAro
            height: parent.height + separacionAro
            radius: parent.radius + separacionAro / 2
            color: "transparent"
            border.width: 2
            border.color: ventana.colorAccent
        }

        // Dorso: marco interior a juego con el borde exterior + emblema
        // centrado, en vez de un patrón importado (barato de mantener,
        // reescala con la carta sin necesitar ninguna imagen).
        Rectangle {
            visible: bocaAbajo
            anchors.fill: parent
            anchors.margins: Math.round(parent.width * 0.14)
            radius: 4
            color: "transparent"
            border.width: 1
            border.color: ventana.colorAccent
            opacity: 0.7
        }
        Text {
            visible: bocaAbajo
            anchors.centerIn: parent
            text: "♣"
            color: ventana.colorAccent
            font.pixelSize: Math.round(parent.width * 0.4)
            font.family: ventana.fuenteElegante
            opacity: 0.8
        }

        Column {
            visible: !bocaAbajo
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: margen
            Text {
                text: rango
                color: esRojo ? "#c96a5c" : "#182019"
                font.pixelSize: tamanoFuente
                font.family: ventana.fuenteElegante
                font.bold: true
            }
            Text {
                text: palo
                color: esRojo ? "#c96a5c" : "#182019"
                font.pixelSize: tamanoFuente
                font.family: ventana.fuenteElegante
                font.bold: true
            }
        }
        Column {
            visible: !bocaAbajo
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: margen
            Text {
                text: rango
                color: esRojo ? "#c96a5c" : "#182019"
                font.pixelSize: tamanoFuente
                font.family: ventana.fuenteElegante
                font.bold: true
            }
            Text {
                text: palo
                color: esRojo ? "#c96a5c" : "#182019"
                font.pixelSize: tamanoFuente
                font.family: ventana.fuenteElegante
                font.bold: true
            }
        }
    }

    // Botón "de contorno": fondo transparente, borde de un color temático —
    // como en el boceto, en vez del botón gris sólido de Material por
    // defecto. Qt Quick Controls deja sustituir "background" y
    // "contentItem" de cualquier control; aquí se rehacen los dos con un
    // Rectangle y un Text a medida.
    component BotonContorno: Button {
        id: botonContorno
        property color colorBorde: ventana.colorAccent
        // 6 = esquinas redondeadas normales; 999 (o cualquier valor mayor
        // que medio alto) da forma de píldora, como el botón de "Entrar a
        // la mesa" en Inicio.
        property real radioBorde: 6
        // "hovered" ya existe en cualquier Button de Qt Quick Controls —
        // solo hay que activar "hoverEnabled" para que se actualice de
        // verdad al pasar el ratón por encima (por defecto no siempre está
        // activo). "Behavior on color" anima la transición en vez de un
        // cambio brusco.
        hoverEnabled: true
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
            color: botonContorno.hovered ? ventana.colorPanel : botonContorno.colorBorde
            font.family: ventana.fuenteElegante
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    // El contrario de BotonContorno: relleno por defecto, se vacía al
    // pasar el ratón por encima — para la acción principal de cada
    // pantalla, así destaca sobre las secundarias (que usan BotonContorno).
    component BotonRelleno: Button {
        id: botonRelleno
        property color colorBorde: ventana.colorAccent
        property real radioBorde: 6
        hoverEnabled: true
        background: Rectangle {
            color: botonRelleno.hovered ? "transparent" : botonRelleno.colorBorde
            radius: botonRelleno.radioBorde
            border.width: 1
            border.color: botonRelleno.colorBorde
            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            // Brillo metálico: capa de degradado de 3 paradas por encima
            // del relleno plano de arriba, que se desvanece junto con él
            // al pasar el ratón — ver "Sistema visual", sección 14/16.
            // Deriva siempre de "colorBorde" (Qt.lighter/darker), así que
            // funciona igual en los cuatro temas sin valores por tema.
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                opacity: botonRelleno.hovered ? 0 : 1
                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(botonRelleno.colorBorde, 1.35) }
                    GradientStop { position: 0.5; color: botonRelleno.colorBorde }
                    GradientStop { position: 1.0; color: Qt.darker(botonRelleno.colorBorde, 1.2) }
                }
            }
        }
        contentItem: Text {
            text: botonRelleno.text
            color: botonRelleno.hovered ? botonRelleno.colorBorde : ventana.colorPanel
            font.family: ventana.fuenteElegante
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    // Interruptor on/off a medida (checkboxes de Qt Quick Controls traen su
    // propio look gris que desentona con el resto de controles hechos a
    // mano en este archivo) — usado en "Crear sala" para pública/privada,
    // min-raise y permitir recompra.
    component Interruptor: Rectangle {
        id: interruptor
        property bool activo: false
        signal alternado()
        width: 36
        height: 20
        radius: height / 2
        color: ventana.colorFondo
        border.width: 1
        border.color: interruptor.activo ? ventana.colorAccent : ventana.colorBorde
        Behavior on border.color {
            ColorAnimation {
                duration: 120
            }
        }
        Rectangle {
            width: 14
            height: 14
            radius: 7
            anchors.verticalCenter: parent.verticalCenter
            x: interruptor.activo ? parent.width - width - 3 : 3
            color: interruptor.activo ? ventana.colorAccent : ventana.colorTextoTenue
            Behavior on x {
                NumberAnimation {
                    duration: 120
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                interruptor.activo = !interruptor.activo;
                interruptor.alternado();
            }
        }
    }

    // Selector de una opción entre varias, en forma de píldoras en fila —
    // mismo lenguaje visual que las pestañas "Historial/Chat" del panel
    // lateral. Se usa para dificultad de bots y tipo de límite en "Crear
    // sala": son 2-3 opciones excluyentes, más claro que un ComboBox y no
    // necesita re-tematizar el desplegable por defecto de Qt Quick Controls.
    component SelectorPildoras: Row {
        id: selector
        property var opciones: []
        property int seleccionado: 0
        spacing: 6
        Repeater {
            model: selector.opciones
            delegate: Rectangle {
                id: pildora
                required property string modelData
                required property int index
                width: textoPildora.implicitWidth + 20
                height: 30
                radius: height / 2
                color: index === selector.seleccionado ? ventana.colorAccent : "transparent"
                border.width: 1
                border.color: ventana.colorBorde
                Text {
                    id: textoPildora
                    anchors.centerIn: parent
                    text: pildora.modelData
                    font.pixelSize: 12
                    color: pildora.index === selector.seleccionado ? ventana.colorPanel : ventana.colorTextoTenue
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: selector.seleccionado = pildora.index
                }
            }
        }
    }

    // Los tres botones del voto de fin de mano — se usa DOS veces (la fila
    // de acciones normal, y dentro del overlay de showdown) para que se
    // pueda votar sin dejar de ver las cartas reveladas; de ahí que esté
    // sacado a un componente en vez de repetido a mano.
    component PanelVoto: Row {
        spacing: 8
        BotonRelleno {
            text: "Continuar a la siguiente mano"
            onClicked: {
                redcliente.votar();
                votoAbierto = false;
                mensajeVoto = "";
            }
        }
        BotonContorno {
            text: "Abandonar partida"
            colorBorde: ventana.colorPeligro
            onClicked: {
                redcliente.abandonar();
                votoAbierto = false;
            }
        }
        BotonContorno {
            visible: soyHost
            text: "Guardar y salir"
            onClicked: {
                redcliente.guardarYSalir();
                votoAbierto = false;
            }
        }
    }

    // Barra superior compartida por todas las pantallas salvo Inicio (ahí
    // no hay nada de sala/conexión que mostrar todavía) — mismo lenguaje
    // visual en todo el programa: logo a la izquierda, algo de contexto en
    // el centro (opcional, cada pantalla decide qué), y a la derecha el
    // estado de conexión + saldo (solo en Partida) + el botón de ajustes.
    component BarraSuperior: Item {
        id: barra
        property string textoCentro: ""
        property bool mostrarSaldo: false
        height: 50 * ventana.escala
        // Flota en vez de ir pegada al borde — margen a los tres lados
        // puesto aquí (no en cada sitio donde se usa) para que las cinco
        // pantallas queden iguales sin repetirlo cinco veces.
        anchors.margins: 16 * ventana.escala

        // Sombra barata: un rectángulo semitransparente desplazado, sin
        // blur de verdad — ver el catálogo "Sistema visual", sección 15.
        // Al ser un único elemento por pantalla (no 17 cartas a la vez),
        // el coste es irrelevante; aun así se usa la receta barata por
        // coherencia con el resto del programa.
        Rectangle {
            anchors.left: fondoBarra.left
            anchors.right: fondoBarra.right
            anchors.top: fondoBarra.top
            anchors.topMargin: 4
            height: fondoBarra.height
            radius: fondoBarra.radius
            color: "black"
            opacity: 0.28
        }

        Rectangle {
            id: fondoBarra
            anchors.fill: parent
            radius: 14
            // Antes un contorno de 1px del mismo color en los cuatro
            // lados — se veía plano, "de maqueta". En vez de eso: borde
            // casi invisible (solo define el canto contra el fondo) y un
            // filo claro SOLO arriba, como si la luz rozara el borde
            // superior de una superficie ligeramente elevada — el resto
            // del volumen ya lo dan el degradado y la sombra de debajo.
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.3)
            // Degradado sutil en vez de color plano — deriva de
            // colorPanel con Qt.lighter() para que funcione igual en los
            // cuatro temas sin tener que definir un valor por tema.
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(ventana.colorPanel, 1.55) }
                GradientStop { position: 1.0; color: ventana.colorPanel }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                height: 1
                color: Qt.rgba(1, 1, 1, 0.12)
            }

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 16
                spacing: 8
                Text {
                    text: "♣"
                    color: ventana.colorAccent
                    font.pixelSize: 20
                }
                Text {
                    text: "PokerRemake"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 16
                    font.family: ventana.fuenteElegante
                    // Row no centra verticalmente hijos de distinto tamaño (el
                    // trébol es más grande) — se baja a mano.
                    y: 4
                }
            }

            Text {
                visible: barra.textoCentro !== ""
                anchors.centerIn: parent
                color: ventana.colorTextoTenue
                text: barra.textoCentro
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 16
                spacing: 16

                Text {
                    visible: barra.mostrarSaldo
                    anchors.verticalCenter: parent.verticalCenter
                    text: miSaldoActual + " fichas"
                    color: ventana.colorAccent
                    font.bold: true
                }

                // Estado de conexión: Lobby/Partida/Fin solo se llega a ellas
                // tras una conexión persistente ya establecida (onConectado/
                // onPartidaIniciada/onFinDePartida) — Salas/CrearSala usan
                // sockets efímeros por petición (refrescarSalas), así que ahí
                // no hay "conectado" de verdad todavía, solo el destino.
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: 3.5
                        color: reconectandoAhora ? ventana.colorPeligro
                               : (pantalla === "Lobby" || pantalla === "Partida" || pantalla === "Fin") ? "#7FAE7A"
                               : ventana.colorTextoMuyTenue
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (reconectandoAhora ? "Reconectando… · " : "") + servidorHost + ":" + servidorPuerto
                        color: ventana.colorTextoMuyTenue
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    id: botonAjustesBarra
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30 * ventana.escala
                    height: 30 * ventana.escala
                    radius: width / 2
                    border.width: 1
                    border.color: botonAjustesBarraArea.containsMouse ? ventana.colorAccent : ventana.colorBorde
                    // Metálico al pasar el ratón — mismo degradado de 3
                    // paradas que el resto de botones "de acento" (ver
                    // BotonRelleno), en vez de un color plano de hover. Una
                    // sola parada no puede ser "condicional" en QML (no se
                    // puede asignar un Gradient entero con "? :"), así que
                    // cada GradientStop se vuelve transparente cuando no
                    // hay hover — el efecto es el mismo que no pintar nada.
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: botonAjustesBarraArea.containsMouse ? Qt.lighter(ventana.colorAccent, 1.3) : "transparent"
                        }
                        GradientStop {
                            position: 0.5
                            color: botonAjustesBarraArea.containsMouse ? ventana.colorAccent : "transparent"
                        }
                        GradientStop {
                            position: 1.0
                            color: botonAjustesBarraArea.containsMouse ? Qt.darker(ventana.colorAccent, 1.25) : "transparent"
                        }
                    }
                    // Tres puntos de verdad (Rectangle redondos) en vez del
                    // carácter "⋮" — el glifo depende de la fuente y ni
                    // queda perfectamente centrado ni perfectamente redondo.
                    Column {
                        anchors.centerIn: parent
                        spacing: 3 * ventana.escala
                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                width: 4 * ventana.escala
                                height: 4 * ventana.escala
                                radius: width / 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: botonAjustesBarraArea.containsMouse ? ventana.colorPanel : ventana.colorTextoTenue
                            }
                        }
                    }
                    MouseArea {
                        id: botonAjustesBarraArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: ajustesAbiertos = !ajustesAbiertos
                    }
                }
            }
        }
    }

    // Chat con burbujas: las tuyas a la derecha (con un tinte dorado), las
    // de los demás a la izquierda — como cualquier chat de mensajería.
    component ChatBox: Rectangle {
        id: cajaChat
        property var modelo
        property string miNombre
        visible: ventana.chatActive
        width: 340 * ventana.escala
        height: 460 * ventana.escala
        radius: 8
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.3)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(ventana.colorPanel, 1.4) }
            GradientStop { position: 1.0; color: ventana.colorPanel }
        }

        ListView {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: filaEntrada.top
            anchors.margins: 10
            anchors.bottomMargin: 8
            // "BottomToTop" parecía la opción obvia para un chat, pero con
            // append() (mensaje nuevo = índice más alto) hace justo lo
            // contrario de lo que parece: apila los índices crecientes
            // hacia ARRIBA, así que el mensaje más nuevo acababa en lo alto
            // de la lista. El orden normal (de arriba abajo) + moverse al
            // final es lo que de verdad da "los nuevos entran por abajo".
            spacing: 8
            clip: true
            model: cajaChat.modelo
            // Sin esto, un mensaje nuevo se añade al modelo pero la vista se
            // queda mirando donde estaba — hay que decirle explícitamente
            // que se mueva al final cada vez que cambia el número de
            // elementos. "Qt.callLater" en vez de llamarlo directo: en el
            // mismo instante en que cambia "count" el elemento nuevo
            // todavía no ha terminado de crearse/medirse, así que
            // posicionar ya mismo deja fuera justo el último — hay que
            // esperar un "tick" a que termine el ciclo actual.
            onCountChanged: Qt.callLater(positionViewAtEnd)
            delegate: Item {
                required property string autor
                required property string mensaje
                property bool esPropio: autor === cajaChat.miNombre
                width: ListView.view.width
                height: columnaBurbuja.height

                Column {
                    id: columnaBurbuja
                    // Burbuja propia pegada a la derecha, ajena a la
                    // izquierda — un Item normal sí admite esto (no es hijo
                    // directo de un Row/Column con reglas de posicionador).
                    x: esPropio ? parent.width - width : 0
                    width: Math.min(textoBurbuja.implicitWidth + 24, parent.width * 0.8)
                    spacing: 2

                    Text {
                        text: esPropio ? "Tú" : autor
                        color: ventana.colorTextoMuyTenue
                        font.pixelSize: 10
                    }
                    Rectangle {
                        width: parent.width
                        height: textoBurbuja.implicitHeight + 16
                        radius: 12
                        color: esPropio ? Qt.rgba(0.75, 0.56, 0.24, 0.18) : ventana.colorTapete
                        border.width: esPropio ? 1 : 0
                        border.color: ventana.colorAccent
                        Text {
                            id: textoBurbuja
                            anchors.fill: parent
                            anchors.margins: 8
                            text: mensaje
                            color: "white"
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        Row {
            id: filaEntrada
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            spacing: 8

            TextField {
                id: textoChat
                width: parent.width - botonEnviar.width - parent.spacing
                height: 44
                color: "white"
                // El estilo Material anima el placeholder hacia una
                // "etiqueta flotante" arriba del campo al enfocar/escribir
                // — con nuestro borde dibujado a mano se solapa en vez de
                // apartarse. Más simple que perseguir esa animación:
                // ocultar el placeholder en cuanto hay foco o texto.
                placeholderText: (activeFocus || text.length > 0) ? "" : "Escribe un mensaje..."
                placeholderTextColor: ventana.colorTextoTenue
                background: Rectangle {
                    color: ventana.colorFondo
                    radius: 8
                    border.width: 1
                    border.color: textoChat.activeFocus ? ventana.colorAccent : ventana.colorBorde
                }
            }
            BotonRelleno {
                id: botonEnviar
                height: 44
                text: "Enviar"
                onClicked: {
                    redcliente.enviarChat(textoChat.text);
                    cajaChat.modelo.append({
                        autor: cajaChat.miNombre,
                        mensaje: textoChat.text,
                        hora: Qt.formatTime(new Date(), "hh:mm")
                    });  // eco local
                    textoChat.text = "";
                }
            }
        }
    }

    // ── Panel lateral de la partida: historial + chat en una sola caja,
    // con pestanas integradas arriba (en vez del botón suelto + dos cajas
    // separadas que había antes) — como en el boceto.
    component PanelLateral: Rectangle {
        id: panelLateral
        property var modeloHistorial
        property var modeloChat
        property string miNombre
        property bool mostrandoChat: false
        radius: 6
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.3)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(ventana.colorPanel, 1.4) }
            GradientStop { position: 1.0; color: ventana.colorPanel }
        }

        // Color del punto de cada entrada del historial, según la
        // categoría que manda NetworkClient::eventoJuego() (ver su
        // comentario para la lista completa) — así se distinguen de un
        // vistazo los folds, subidas, showdown, avisos del sistema, etc.
        // Devuelve hex limpio (ventana.colorHex) porque esto se usa dentro
        // de un <font color=...>, no como property color directa.
        function colorTipoHistorial(tipo) {
            switch (tipo) {
                case "fold": return ventana.colorHex(ventana.colorPeligro);
                case "agresion": return ventana.colorHex(ventana.colorAccent);
                case "showdown": return ventana.colorHex(ventana.colorAccent);
                case "error": return ventana.colorHex(ventana.colorPeligro);
                case "separador": return ventana.colorHex(ventana.colorTextoMuyTenue);
                case "sistema": return ventana.colorHex(ventana.colorTextoTenue);
                default: return ventana.colorHex(ventana.colorTextoTenue); // "accion" (check/call) y cualquier otro
            }
        }

        // Color del nombre de jugador dentro de una línea: dorado si eres
        // tú, otro tono si es cualquier otro — así los nombres se
        // distinguen del resto del texto de un vistazo.
        function colorNombreHistorial(jugador) {
            return ventana.colorHex(jugador === miNombre ? ventana.colorAccent : ventana.colorNombreAjeno);
        }

        Row {
            id: pestanas
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 10
            spacing: 8

            Rectangle {
                width: textoTabHistorial.implicitWidth + 24
                height: 30
                radius: height / 2
                color: !panelLateral.mostrandoChat ? ventana.colorAccent : "transparent"
                Text {
                    id: textoTabHistorial
                    anchors.centerIn: parent
                    text: "Historial"
                    color: !panelLateral.mostrandoChat ? ventana.colorPanel : ventana.colorTextoTenue
                    font.bold: !panelLateral.mostrandoChat
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: panelLateral.mostrandoChat = false
                }
            }
            Rectangle {
                width: textoTabChat.implicitWidth + 24
                height: 30
                radius: height / 2
                color: panelLateral.mostrandoChat ? ventana.colorAccent : "transparent"
                Text {
                    id: textoTabChat
                    anchors.centerIn: parent
                    text: "Chat"
                    color: panelLateral.mostrandoChat ? ventana.colorPanel : ventana.colorTextoTenue
                    font.bold: panelLateral.mostrandoChat
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: panelLateral.mostrandoChat = true
                }
            }
        }

        ListView {
            visible: !panelLateral.mostrandoChat
            anchors.top: pestanas.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            anchors.topMargin: 12
            clip: true
            model: panelLateral.modeloHistorial
            onCountChanged: Qt.callLater(positionViewAtEnd)
            delegate: Item {
                required property string linea
                required property string hora
                required property string tipo
                required property string jugador
                width: ListView.view.width
                height: Math.max(textoLinea.height, 16)
                Text {
                    id: textoLinea
                    anchors.left: parent.left
                    anchors.right: textoHoraHistorial.left
                    anchors.rightMargin: 8
                    // El punto lleva color por categoría (colorTipoHistorial)
                    // y, si la línea tiene un protagonista, su nombre
                    // también lleva color aparte (colorNombreHistorial:
                    // dorado si eres tú, otro tono si es cualquier otro) —
                    // así los nombres destacan del resto del texto, que
                    // sigue en blanco normal.
                    textFormat: Text.RichText
                    text: "<font color=\"" + panelLateral.colorTipoHistorial(tipo) + "\">●</font> " +
                          (jugador.length > 0
                               ? "<font color=\"" + panelLateral.colorNombreHistorial(jugador) +
                                     "\"><b>" + ventana.escapeHtml(jugador) + "</b></font>"
                               : "") +
                          ventana.escapeHtml(linea)
                    color: "white"
                    wrapMode: Text.WordWrap
                }
                Text {
                    id: textoHoraHistorial
                    anchors.right: parent.right
                    anchors.verticalCenter: textoLinea.verticalCenter
                    text: hora
                    color: ventana.colorTextoMuyTenue
                    font.pixelSize: 10
                }
            }
        }

        Column {
            visible: panelLateral.mostrandoChat
            anchors.top: pestanas.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            anchors.topMargin: 12
            spacing: 8

            ListView {
                id: listaChat
                width: parent.width
                height: parent.height - filaEntradaChat.height - parent.spacing
                // Ver el comentario largo en el ListView de ChatBox: con
                // append(), "BottomToTop" mete los mensajes nuevos arriba,
                // no abajo — el orden normal + ir al final es lo correcto.
                clip: true
                model: panelLateral.modeloChat
                onCountChanged: Qt.callLater(positionViewAtEnd)
                // Mismo estilo de burbujas que ChatBox (chat de la sala):
                // las propias a la derecha con tinte dorado, las ajenas a
                // la izquierda en verde tapete — antes esto era una lista
                // plana "autor: mensaje" sin distinguir quién escribió qué.
                delegate: Item {
                    required property string autor
                    required property string mensaje
                    required property string hora
                    property bool esPropio: autor === panelLateral.miNombre
                    width: ListView.view.width
                    height: columnaBurbujaPartida.height

                    Column {
                        id: columnaBurbujaPartida
                        x: esPropio ? parent.width - width : 0
                        width: Math.min(textoBurbujaPartida.implicitWidth + 24, parent.width * 0.8)
                        spacing: 2

                        Text {
                            text: (esPropio ? "Tú" : autor) + " · " + hora
                            color: ventana.colorTextoMuyTenue
                            font.pixelSize: 10
                        }
                        Rectangle {
                            width: parent.width
                            height: textoBurbujaPartida.implicitHeight + 16
                            radius: 12
                            color: esPropio ? Qt.rgba(0.75, 0.56, 0.24, 0.18) : ventana.colorTapete
                            border.width: esPropio ? 1 : 0
                            border.color: ventana.colorAccent
                            Text {
                                id: textoBurbujaPartida
                                anchors.fill: parent
                                anchors.margins: 8
                                text: mensaje
                                color: "white"
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            Row {
                id: filaEntradaChat
                width: parent.width
                spacing: 8
                TextField {
                    id: campoChatPanel
                    width: parent.width - botonEnviarPanel.width - parent.spacing
                    height: 44
                    color: "white"
                    // Ver el comentario largo en "textoChat" (ChatBox):
                    // el placeholder de Material flota hacia arriba al
                    // enfocar y se solapa con nuestro borde dibujado a
                    // mano — más simple ocultarlo directamente.
                    placeholderText: (activeFocus || text.length > 0) ? "" : "Escribe un mensaje..."
                    placeholderTextColor: ventana.colorTextoTenue
                    // Antes sin "background": salía con el estilo por
                    // defecto de Qt Quick Controls (gris claro), fuera de
                    // sitio en este tema oscuro — mismo fondo que ChatBox.
                    background: Rectangle {
                        color: ventana.colorFondo
                        radius: 8
                        border.width: 1
                        border.color: campoChatPanel.activeFocus ? ventana.colorAccent : ventana.colorBorde
                    }
                }
                BotonRelleno {
                    id: botonEnviarPanel
                    height: 44
                    text: "Enviar"
                    onClicked: {
                        redcliente.enviarChat(campoChatPanel.text);
                        panelLateral.modeloChat.append({
                            autor: panelLateral.miNombre,
                            mensaje: campoChatPanel.text,
                            hora: Qt.formatTime(new Date(), "hh:mm")
                        });  // eco local
                        campoChatPanel.text = "";
                    }
                }
            }
        }
    }

    property string pantalla: "Inicio"
    property bool ajustesAbiertos: false
    // Ajustes de cliente (sección "Cliente" del cajón) — en memoria por
    // ahora, sin persistencia entre sesiones (no hay QSettings todavía).
    property bool sonidoActivado: true
    property bool confirmarAllIn: false
    property bool chuletaAbierta: false
    // Centralizados para que la barra superior pueda mostrarlos, y para no
    // repetir el mismo literal en cada llamada a conectar/crearSala/
    // unirseASala/refrescarSalas. Valores por defecto desde ServerConfig.hpp
    // (inyectados por main.cpp) — mismo punto único de configuración que
    // usa el cliente ncurses, no un campo editable en la interfaz.
    property string servidorHost: SERVER_HOST_DEFAULT
    property int servidorPuerto: SERVER_PORT_DEFAULT
    // Mensaje de error de conexión/sala compartido entre Inicio, Salas y
    // CrearSala — las tres pueden iniciar una conexión (conectar/crearSala/
    // unirseASala) y un fallo puede llegar estando en cualquiera de ellas,
    // no solo en la que lo originó.
    property string mensajeErrorConexion: ""
    // Código de la sala recién creada (pantalla "Crear sala") — solo tiene
    // valor si se creó como privada; se muestra en el Lobby para que el
    // host pueda compartirlo. Se limpia al volver a Inicio.
    property string codigoSalaPropia: ""
    ListModel {
        id: salasDisponibles
    }
    ListModel {
        id: guardadasDisponibles
    }
    // Toggle de la pantalla "Salas": públicas en curso vs. partidas
    // guardadas que se pueden reanudar como sala nueva.
    property bool viendoGuardadas: false
    // Nombres humanos esperados de la partida reanudada (separados por
    // coma), si la sala actual viene de CARGAR_PARTIDA — vacío en una sala
    // nueva normal. Se muestra en el Lobby para que quien entra sepa con
    // qué nombre unirse aunque no lo recuerde.
    property string nombresEsperadosLobby: ""
    property bool tuTurno: false
    property bool votoAbierto: false
    // Antes vivía solo como el texto de un id ("votoTexto.text = ...") —
    // ahora es una property porque el mismo mensaje se muestra en DOS
    // sitios a la vez: la fila de acciones normal Y dentro del overlay de
    // showdown (ver más abajo, el usuario quiere poder votar sin dejar de
    // ver las cartas reveladas).
    property string mensajeVoto: ""
    // Te quedaste sin fichas y la sala permite recompra (AVISO_RECOMPRA con
    // puede_recomprar=1) — se apaga solo en cuanto onEstadoMesaActualizado
    // vea que tu propio saldo ya es > 0 (no hay un evento dedicado de
    // "recompra confirmada", así que se detecta por esa vía).
    property bool puedoRecomprar: false
    property bool recompraSolicitada: false
    // Showdown: se abre con el evento SHOWDOWN, se va llenando con cada
    // MUESTRA_CARTAS/GANADOR_BOTE, y se cierra al llegar el turno de votar
    // (o una mano nueva, por si acaso) — ver la pantalla superpuesta al
    // final del archivo. Cada entrada: {nombre, cartas:[c1,c2], combo,
    // esGanador, premio}.
    property bool showdownAbierto: false
    property var revealsShowdown: []
    property bool votoExtensionAbierto: false
    property bool chatActive: false
    property string ganadorFinal: ""
    property int saldoFinal: 0
    property bool finPorLimite: false
    property bool partidaGuardada: false
    property string archivoGuardado: ""
    property bool reconectandoAhora: false
    property int segundosReconexion: 0
    property string hostActual: ""
    property bool soyHost: hostActual !== "" && hostActual === nombreUsuario.text
    property int igualarActual: 0
    property int miApuestaActual: 0
    property int miSaldoActual: 0
    property int aPagarParaIgualar: Math.max(0, igualarActual - miApuestaActual)
    // Rango real de subida (min/max "extra" sobre aPagarParaIgualar) que
    // manda el servidor en cada TU_TURNO — antes el slider solo aproximaba
    // el máximo con el saldo, sin límite mínimo ni respetar pot-limit/fixed-limit.
    property int minSubidaActual: 0
    property int maxSubidaActual: 0
    property string miCarta1: ""
    property string miCarta2: ""
    property var cartasMesa: []
    property int manoActual: 0
    property int ciegaActual: 0
    // Reglas de la sala actual, para la sección "Mesa actual" del cajón
    // de ajustes — llegan una vez, al empezar la partida (fijas toda la
    // sesión, ver onPartidaIniciada).
    property int objetivoManos: 0
    property int tipoLimiteActual: 0
    property bool permitirRecompraActual: false
    property bool rellenarConBotsActual: false
    property string turnoNombre: ""
    property string rondaActual: ""
    // Jugadores retirados en la mano actual — el servidor no manda esto
    // como estado (GAME_STATE solo da nombre/saldo/apuesta), así que se
    // infiere del lado del cliente viendo pasar los FOLD en el historial de
    // acciones, y se vacía en cada mano nueva (INICIO_MANO).
    property var retirados: []
    property string comboActual: ""
    property string comboProbable: ""
    property string comboMaxima: ""
    property int timeoutMsActual: 30000
    property int boteActual: 0

    // ── Cuenta atrás del turno (para el anillo del avatar) ────────────────
    // El servidor ahora manda "timeout_ms" en cada turno (onTurnoIniciado),
    // no solo al humano en TU_TURNO — por eso el Timer corre para CUALQUIER
    // turno activo (turnoNombre no vacío), y Mesa aplica la fracción al
    // asiento que corresponda cada vez, no solo al propio. "inicioTurnoMs"
    // guarda cuándo empezó (Date.now(), fuera de QML puro pero JavaScript
    // normal) y este Timer recalcula la fracción restante 10 veces/segundo.
    property real inicioTurnoMs: 0
    property real fraccionTiempoRestante: 1.0
    Timer {
        interval: 100
        running: turnoNombre !== ""
        repeat: true
        onTriggered: {
            var transcurrido = Date.now() - inicioTurnoMs;
            fraccionTiempoRestante = Math.max(0, 1 - transcurrido / timeoutMsActual);
        }
    }
    // Tamaño inicial: un porcentaje generoso de la pantalla disponible
    // ("Screen" es un attached property de QtQuick.Window, disponible en
    // cualquier Item/Window; "desktopAvailableWidth/Height" ya descuenta
    // barras de tareas del sistema). Ni fijo ni "lo más grande posible" —
    // así aprovecha pantallas grandes (FHD y más) sin llegar a taparse con
    // el propio sistema operativo, y se adapta sola si la pantalla es más
    // pequeña.
    width: Screen.desktopAvailableWidth * 0.75
    height: Screen.desktopAvailableHeight * 0.85
    // Unidad de escala: 1040x780 es el tamaño "de diseño", con el que se
    // pensaron las medidas de Mesa/Carta/Asiento. "escala" da el factor por
    // el que hay que multiplicar cada tamaño para que todo crezca o encoja
    // junto según el tamaño real de la ventana, en vez de quedarse en
    // píxeles fijos que no se adaptan a la pantalla. Se usa como
    // "ventana.escala" desde los componentes aparte (Carta, Asiento...),
    // igual que "ventana.chatActive".
    readonly property real escala: Math.min(width / 1040, height / 780)
    // Por debajo de este factor, el contenido ya no cabe de forma legible
    // — mejor avisar con un mensaje que dejar botones inaccesibles o texto
    // solapado.
    readonly property real escalaMinima: 0.55
    visible: true
    title: "PokerClient (Qt Quick) — en construcción"

    Rectangle {
        anchors.fill: parent
        color: ventana.colorFondo

        // ── Pantalla 1: conectar ──────────────────────────
        Column {
            visible: pantalla === "Inicio"
            anchors.centerIn: parent
            spacing: 22

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Text {
                    text: "♣"
                    color: ventana.colorAccent
                    font.pixelSize: 30
                }
                Text {
                    text: "PokerRemake"
                    color: "white"
                    font.family: ventana.fuenteElegante
                    font.pixelSize: 32
                    // Mismo ajuste que en la barra superior: el trébol y el
                    // texto no comparten línea base por defecto en un Row.
                    y: 4
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "MESA PRIVADA · TEXAS HOLD'EM"
                color: ventana.colorTextoTenue
                font.pixelSize: 11
                font.letterSpacing: 2
            }
            // Campo "subrayado", sin caja — se sustituye el fondo entero de
            // Qt Quick Controls por una única línea inferior, que se
            // ilumina en dorado con el foco (igual que el TextField de
            // subir en la mesa).
            TextField {
                id: nombreUsuario
                anchors.horizontalCenter: parent.horizontalCenter
                width: 260 * ventana.escala
                horizontalAlignment: Text.AlignHCenter
                color: "white"
                // Ver el comentario largo en "textoChat" (ChatBox): el
                // placeholder de Material flota hacia arriba al enfocar y
                // se solapa con el texto ya escrito — más simple ocultarlo.
                placeholderText: (activeFocus || text.length > 0) ? "" : "Tu nombre"
                placeholderTextColor: ventana.colorTextoMuyTenue
                background: Rectangle {
                    color: "transparent"
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: nombreUsuario.activeFocus ? ventana.colorAccent : ventana.colorBorde
                    }
                }
            }
            // "Entrar a la mesa" (conexión directa a la sala legacy) ya no
            // hace falta — "Salas disponibles" es el único camino de
            // entrada ahora, así que pasa a ser el botón principal. En su
            // sitio, salir del programa — Inicio sigue teniendo dos
            // botones, solo que ahora son "entrar" y "salir" de verdad.
            BotonRelleno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Salas disponibles"
                radioBorde: 999
                onClicked: {
                    pantalla = "Salas";
                    redcliente.refrescarSalas(servidorHost, servidorPuerto);
                }
            }
            BotonContorno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Salir"
                colorBorde: ventana.colorPeligro
                radioBorde: 999
                onClicked: Qt.quit()
            }
            Text {
                id: estadoTexto
                anchors.horizontalCenter: parent.horizontalCenter
                color: ventana.colorPeligro
                font.pixelSize: 11
                text: mensajeErrorConexion
            }
        }

        // ── Pantalla Salas: lista de salas públicas disponibles ───────────
        BarraSuperior {
            visible: pantalla === "Salas"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            textoCentro: "Salas disponibles"
        }
        Column {
            visible: pantalla === "Salas"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 25 * ventana.escala
            spacing: 16
            // Antes 420 — con archivo + fecha + 3 botones en cada fila de
            // guardadas, se quedaba corta y el texto se solapaba con los
            // botones. Más ancha, y con tope según el ancho de ventana
            // (mismo patrón que CrearSala) para pantallas pequeñas.
            width: Math.min(680 * ventana.escala, ventana.width - 60 * ventana.escala)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: viendoGuardadas ? "Partidas guardadas" : "Salas disponibles"
                color: "white"
                font.family: ventana.fuenteElegante
                font.pixelSize: 22
            }

            // Mismo patrón de pestañas que Historial/Chat en PanelLateral.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Rectangle {
                    width: textoTabSalasPub.implicitWidth + 24
                    height: 30
                    radius: height / 2
                    color: !viendoGuardadas ? ventana.colorAccent : "transparent"
                    Text {
                        id: textoTabSalasPub
                        anchors.centerIn: parent
                        text: "Salas públicas"
                        color: !viendoGuardadas ? ventana.colorPanel : ventana.colorTextoTenue
                        font.bold: !viendoGuardadas
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: viendoGuardadas = false
                    }
                }
                Rectangle {
                    width: textoTabGuardadas.implicitWidth + 24
                    height: 30
                    radius: height / 2
                    color: viendoGuardadas ? ventana.colorAccent : "transparent"
                    Text {
                        id: textoTabGuardadas
                        anchors.centerIn: parent
                        text: "Partidas guardadas"
                        color: viendoGuardadas ? ventana.colorPanel : ventana.colorTextoTenue
                        font.bold: viendoGuardadas
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            viendoGuardadas = true;
                            redcliente.listarGuardadas(servidorHost, servidorPuerto);
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 340 * ventana.escala
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.3)
                radius: 8
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(ventana.colorPanel, 1.4) }
                    GradientStop { position: 1.0; color: ventana.colorPanel }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    visible: !viendoGuardadas && listaSalas.count === 0
                    text: "No hay salas públicas disponibles ahora mismo."
                    color: ventana.colorTextoTenue
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    visible: viendoGuardadas && listaGuardadas.count === 0
                    text: "No hay partidas guardadas en el servidor."
                    color: ventana.colorTextoTenue
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                ListView {
                    id: listaSalas
                    visible: !viendoGuardadas
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    spacing: 8
                    model: salasDisponibles
                    delegate: Rectangle {
                        id: filaSala
                        required property string id
                        required property string nombre
                        required property int conectados
                        required property int esperados
                        width: ListView.view.width
                        height: 44
                        radius: 6
                        color: ventana.colorFondo
                        border.width: 1
                        border.color: ventana.colorBorde

                        Column {
                            anchors.left: parent.left
                            anchors.right: botonUnirse.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: filaSala.nombre !== "" ? filaSala.nombre : filaSala.id
                                color: "white"
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: filaSala.conectados + " / " + filaSala.esperados + " jugadores"
                                color: ventana.colorTextoTenue
                                font.pixelSize: 11
                            }
                        }
                        BotonRelleno {
                            id: botonUnirse
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 10
                            text: "Unirse"
                            onClicked: redcliente.unirseASala(servidorHost, servidorPuerto, nombreUsuario.text, filaSala.id, "")
                        }
                    }
                }

                ListView {
                    id: listaGuardadas
                    visible: viendoGuardadas
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    spacing: 8
                    model: guardadasDisponibles
                    delegate: Rectangle {
                        id: filaGuardada
                        required property string archivo
                        required property string fecha
                        required property int humanos
                        required property int bots
                        property bool renombrando: false
                        property bool confirmandoBorrado: false
                        width: ListView.view.width
                        height: 44
                        radius: 6
                        color: ventana.colorFondo
                        border.width: 1
                        border.color: ventana.colorBorde

                        Column {
                            visible: !filaGuardada.renombrando
                            anchors.left: parent.left
                            anchors.right: filaAcciones.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: filaGuardada.archivo
                                color: "white"
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: filaGuardada.fecha + " · " + filaGuardada.humanos +
                                      " humano(s), " + filaGuardada.bots + " bot(s)"
                                color: ventana.colorTextoTenue
                                font.pixelSize: 11
                            }
                        }

                        // Modo renombrar: sustituye la columna de arriba por
                        // un campo de texto + confirmar, en vez de una
                        // pantalla/diálogo aparte.
                        Row {
                            visible: filaGuardada.renombrando
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            spacing: 6
                            TextField {
                                id: campoRenombrar
                                anchors.verticalCenter: parent.verticalCenter
                                width: 160 * ventana.escala
                                text: filaGuardada.archivo.replace(/\.pok$/, "")
                                color: "white"
                                background: Rectangle {
                                    color: ventana.colorPanel
                                    radius: 6
                                    border.width: 1
                                    border.color: ventana.colorAccent
                                }
                                Keys.onReturnPressed: {
                                    redcliente.renombrarGuardada(servidorHost, servidorPuerto,
                                                                 filaGuardada.archivo, text);
                                    filaGuardada.renombrando = false;
                                }
                            }
                            BotonContorno {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "OK"
                                onClicked: {
                                    redcliente.renombrarGuardada(servidorHost, servidorPuerto,
                                                                 filaGuardada.archivo, campoRenombrar.text);
                                    filaGuardada.renombrando = false;
                                }
                            }
                        }

                        Row {
                            id: filaAcciones
                            visible: !filaGuardada.renombrando
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 10
                            spacing: 6
                            BotonRelleno {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Reanudar"
                                onClicked: redcliente.cargarPartidaGuardada(
                                    servidorHost, servidorPuerto, nombreUsuario.text,
                                    filaGuardada.archivo, filaGuardada.archivo, true)
                            }
                            BotonContorno {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "✎"
                                onClicked: filaGuardada.renombrando = true
                            }
                            BotonContorno {
                                anchors.verticalCenter: parent.verticalCenter
                                text: filaGuardada.confirmandoBorrado ? "¿Seguro?" : "🗑"
                                colorBorde: ventana.colorPeligro
                                onClicked: {
                                    if (filaGuardada.confirmandoBorrado) {
                                        redcliente.borrarGuardada(servidorHost, servidorPuerto,
                                                                  filaGuardada.archivo);
                                    } else {
                                        filaGuardada.confirmandoBorrado = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                BotonContorno {
                    text: "Refrescar"
                    onClicked: viendoGuardadas ? redcliente.listarGuardadas(servidorHost, servidorPuerto)
                                                : redcliente.refrescarSalas(servidorHost, servidorPuerto)
                }
                BotonRelleno {
                    visible: !viendoGuardadas
                    text: "Crear sala nueva"
                    onClicked: pantalla = "CrearSala"
                }
            }

            Row {
                visible: !viendoGuardadas
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                // Row no centra verticalmente hijos de distinta altura por
                // defecto (el TextField y el botón no miden lo mismo) — se
                // centra cada uno a mano, mismo motivo que en los campos de
                // chat.
                TextField {
                    id: campoCodigoUnion
                    anchors.verticalCenter: parent.verticalCenter
                    width: 160 * ventana.escala
                    placeholderText: (activeFocus || text.length > 0) ? "" : "Código de sala privada"
                    color: "white"
                    placeholderTextColor: ventana.colorTextoMuyTenue
                    background: Rectangle {
                        color: ventana.colorPanel
                        radius: 6
                        border.width: 1
                        border.color: campoCodigoUnion.activeFocus ? ventana.colorAccent : ventana.colorBorde
                    }
                }
                BotonContorno {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Unirse por código"
                    onClicked: redcliente.unirseASala(servidorHost, servidorPuerto, nombreUsuario.text, "", campoCodigoUnion.text)
                }
            }

            Text {
                id: estadoTextoSalas
                anchors.horizontalCenter: parent.horizontalCenter
                color: ventana.colorPeligro
                font.pixelSize: 11
                text: mensajeErrorConexion
            }

            BotonContorno {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Salir"
                colorBorde: ventana.colorPeligro
                onClicked: pantalla = "Inicio"
            }
        }

        // ── Pantalla CrearSala: formulario de nueva sala ──────────────────
        // Mismos campos que menuNuevaPartida() en el servidor ncurses
        // (server/main.cpp) — un formulario, no una fila de prompts, pero
        // exactamente las mismas opciones y los mismos valores por defecto.
        //
        // El título y los botones quedan FIJOS (fuera del scroll); solo los
        // campos del medio se desplazan — así "Crear sala"/"Cancelar" están
        // siempre a la vista sin importar cuántos campos haya ni lo pequeña
        // que sea la ventana.
        BarraSuperior {
            id: barraCrearSala
            visible: pantalla === "CrearSala"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            textoCentro: "Crear sala"
        }
        Column {
            visible: pantalla === "CrearSala"
            anchors.top: barraCrearSala.bottom
            anchors.topMargin: 24 * ventana.escala
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 30 * ventana.escala
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16
            // Más ancha que antes (era 700) — las filas con interruptor +
            // etiqueta larga ("Permitir recompra al quedarse sin fichas")
            // iban muy justas de espacio.
            width: Math.min(820 * ventana.escala, ventana.width - 60 * ventana.escala)

            Text {
                id: tituloCrearSala
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Crear sala"
                color: "white"
                font.family: ventana.fuenteElegante
                font.pixelSize: 22
            }

            Rectangle {
                width: parent.width
                // Ocupa todo el hueco vertical que sobra entre el título y
                // los botones/mensaje de error de abajo — nunca más de eso,
                // para que los botones no se salgan de la ventana.
                height: parent.height - tituloCrearSala.height - filaBotonesCrearSala.height -
                        textoErrorCrearSala.height - parent.spacing * 3
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.3)
                radius: 8
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(ventana.colorPanel, 1.4) }
                    GradientStop { position: 1.0; color: ventana.colorPanel }
                }

                ScrollView {
                    id: scrollCrearSala
                    anchors.fill: parent
                    anchors.margins: 18
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    Column {
                        width: scrollCrearSala.availableWidth
                        spacing: 14

                        // Antes era una lista plana de filas — con tantas
                        // opciones, agruparlas por tema (igual que las
                        // secciones de menuNuevaPartida() en el servidor
                        // ncurses: JUGADORES / REGLAS DE APUESTA / PARTIDA)
                        // ayuda a leerlo de un vistazo.
                        Column {
                            width: parent.width
                            spacing: 6
                            Text {
                                text: "SALA"
                                color: ventana.colorTextoMuyTenue
                                font.pixelSize: 11
                                font.letterSpacing: 1
                            }
                            Rectangle { width: parent.width; height: 1; color: ventana.colorBorde }
                        }

                        TextField {
                            id: campoNombreSala
                            width: parent.width
                            placeholderText: (activeFocus || text.length > 0) ? "" : "Nombre de la sala"
                            color: "white"
                            placeholderTextColor: ventana.colorTextoMuyTenue
                            background: Rectangle {
                                color: ventana.colorFondo
                                radius: 6
                                border.width: 1
                                border.color: campoNombreSala.activeFocus ? ventana.colorAccent : ventana.colorBorde
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 12
                            Text {
                                width: 330 * ventana.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Sala pública"
                                color: ventana.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            Interruptor {
                                id: interruptorPublica
                                activo: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12
                            Text {
                                width: 330 * ventana.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Tamaño de sala (asientos totales, máx. 9)"
                                color: ventana.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            TextField {
                                id: campoTamanoSala
                                width: 60 * ventana.escala
                                text: "6"
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 2; top: 9 }
                                background: Rectangle {
                                    color: ventana.colorPanel
                                    radius: 6
                                    border.width: 1
                                    border.color: campoTamanoSala.activeFocus ? ventana.colorAccent : ventana.colorBorde
                                }
                            }
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12
                            Text {
                                width: 330 * ventana.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Rellenar con bots los asientos vacíos"
                                color: ventana.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            Interruptor {
                                id: interruptorRellenar
                                activo: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Text {
                            width: parent.width
                            text: "Si faltan humanos al arrancar (o alguien se va con fichas), un bot ocupa el asiento en vez de perderlo o repartir sus fichas."
                            color: ventana.colorTextoMuyTenue
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12
                            Text {
                                width: 330 * ventana.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Abierta tras iniciar"
                                color: ventana.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            Interruptor {
                                id: interruptorAbierta
                                activo: false
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Text {
                            width: parent.width
                            text: "Con esto activo, cualquier asiento ocupado por un bot se puede sustituir por un jugador nuevo en cualquier momento de la partida."
                            color: ventana.colorTextoMuyTenue
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                        }
            
                        Column {
                            width: parent.width
                            spacing: 6
                            Text {
                                text: "REGLAS DE APUESTA"
                                color: ventana.colorTextoMuyTenue
                                font.pixelSize: 11
                                font.letterSpacing: 1
                            }
                            Rectangle { width: parent.width; height: 1; color: ventana.colorBorde }
                        }

                        Row {
                            width: parent.width
                            spacing: 12
                            Text {
                                width: 330 * ventana.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Dificultad de bots"
                                color: ventana.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            SelectorPildoras {
                                id: selectorDificultad
                                opciones: ["Fácil", "Normal", "Experto"]
                                seleccionado: 0
                            }
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12
                            Text {
                                width: 330 * ventana.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Tipo de límite"
                                color: ventana.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            SelectorPildoras {
                                id: selectorLimite
                                opciones: ["Sin límite", "Límite bote", "Límite fijo"]
                                seleccionado: 0
                            }
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12
                            visible: selectorLimite.seleccionado === 2
                            Text {
                                width: 330 * ventana.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Cantidad fija por raise"
                                color: ventana.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            TextField {
                                id: campoMonteFijo
                                width: 80 * ventana.escala
                                text: "40"
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 1; top: 10000 }
                                background: Rectangle {
                                    color: ventana.colorPanel
                                    radius: 6
                                    border.width: 1
                                    border.color: campoMonteFijo.activeFocus ? ventana.colorAccent : ventana.colorBorde
                                }
                            }
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12
                            Text {
                                width: 330 * ventana.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Min-raise obligatorio"
                                color: ventana.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            Interruptor {
                                id: interruptorMinRaise
                                activo: false
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12
                            Text {
                                width: 330 * ventana.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Permitir recompra al quedarse sin fichas"
                                color: ventana.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            Interruptor {
                                id: interruptorRecompra
                                activo: false
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
            
                        Column {
                            width: parent.width
                            spacing: 6
                            Text {
                                text: "PARTIDA"
                                color: ventana.colorTextoMuyTenue
                                font.pixelSize: 11
                                font.letterSpacing: 1
                            }
                            Rectangle { width: parent.width; height: 1; color: ventana.colorBorde }
                        }

                        Row {
                            width: parent.width
                            spacing: 12
                            Text {
                                width: 330 * ventana.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Número de manos"
                                color: ventana.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            TextField {
                                id: campoNumManos
                                width: 80 * ventana.escala
                                text: "20"
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 1; top: 200 }
                                background: Rectangle {
                                    color: ventana.colorPanel
                                    radius: 6
                                    border.width: 1
                                    border.color: campoNumManos.activeFocus ? ventana.colorAccent : ventana.colorBorde
                                }
                            }
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12
                            Text {
                                width: 330 * ventana.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Ciega grande"
                                color: ventana.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            TextField {
                                id: campoCiegaGrande
                                width: 80 * ventana.escala
                                text: "20"
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 2; top: 1000 }
                                background: Rectangle {
                                    color: ventana.colorPanel
                                    radius: 6
                                    border.width: 1
                                    border.color: campoCiegaGrande.activeFocus ? ventana.colorAccent : ventana.colorBorde
                                }
                            }
                        }
            
                        Row {
                            width: parent.width
                            spacing: 12
                            Text {
                                width: 330 * ventana.escala
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Saldo inicial"
                                color: ventana.colorTextoTenue
                                wrapMode: Text.WordWrap
                            }
                            TextField {
                                id: campoSaldoInicial
                                width: 80 * ventana.escala
                                text: "1000"
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                validator: IntValidator { bottom: 100; top: 100000 }
                                background: Rectangle {
                                    color: ventana.colorPanel
                                    radius: 6
                                    border.width: 1
                                    border.color: campoSaldoInicial.activeFocus ? ventana.colorAccent : ventana.colorBorde
                                }
                            }
                        }
                    }
                    // fin de la Column interior del ScrollView
                }
                // fin del ScrollView
            }
            // fin del Rectangle-tarjeta

            Text {
                id: textoErrorCrearSala
                anchors.horizontalCenter: parent.horizontalCenter
                color: ventana.colorPeligro
                font.pixelSize: 11
                text: mensajeErrorConexion
            }

            Row {
                id: filaBotonesCrearSala
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                BotonContorno {
                    text: "Cancelar"
                    colorBorde: ventana.colorPeligro
                    onClicked: pantalla = "Salas"
                }
                BotonRelleno {
                    text: "Crear sala"
                    onClicked: {
                        redcliente.crearSala(
                            servidorHost, servidorPuerto, nombreUsuario.text,
                            campoNombreSala.text,
                            interruptorPublica.activo,
                            parseInt(campoTamanoSala.text) || 6,
                            parseInt(campoNumManos.text) || 20,
                            parseInt(campoCiegaGrande.text) || 20,
                            parseInt(campoSaldoInicial.text) || 1000,
                            selectorLimite.seleccionado,
                            interruptorMinRaise.activo,
                            parseInt(campoMonteFijo.text) || 40,
                            selectorDificultad.seleccionado,
                            interruptorRecompra.activo,
                            interruptorRellenar.activo,
                            interruptorAbierta.activo
                        );
                    }
                }
            }
        }

        // ── Pantalla Fin: resultado de la partida ─────────────────────
        // Antes era texto suelto flotando en medio de la pantalla — ahora
        // una tarjeta como el resto de paneles (mismo lenguaje que el
        // showdown/entre-manos), con el ganador como protagonista.
        Item {
            visible: pantalla === "Fin"
            anchors.fill: parent

            BarraSuperior {
                id: barraFin
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 25 * ventana.escala
                width: contenidoFin.width + 64 * ventana.escala
                height: contenidoFin.height + 48 * ventana.escala
                border.width: 1
                border.color: ventana.colorAccent
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(ventana.colorPanel, 1.4) }
                    GradientStop { position: 1.0; color: ventana.colorPanel }
                }

                Column {
                    id: contenidoFin
                    anchors.centerIn: parent
                    width: 300 * ventana.escala
                    spacing: 14 * ventana.escala

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: partidaGuardada ? "PARTIDA GUARDADA" : "PARTIDA FINALIZADA"
                        color: ventana.colorAccent
                        font.letterSpacing: 2
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Text {
                        visible: !partidaGuardada
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Ganador"
                        color: ventana.colorTextoTenue
                        font.pixelSize: 11
                    }
                    Text {
                        visible: !partidaGuardada
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ganadorFinal
                        color: "white"
                        font.family: ventana.fuenteElegante
                        font.pixelSize: 26
                        font.bold: true
                    }
                    Text {
                        visible: !partidaGuardada
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: saldoFinal + " fichas"
                        color: ventana.colorAccent
                        font.pixelSize: 15
                    }
                    Text {
                        visible: !partidaGuardada
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: finPorLimite ? "Se alcanzó el límite de manos." : "El resto de jugadores ha quedado eliminado."
                        color: ventana.colorTextoTenue
                        font.pixelSize: 12
                    }
                    Text {
                        visible: partidaGuardada
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "El Host puede continuar la partida desde sus partidas guardadas."
                        color: ventana.colorTextoTenue
                    }
                    BotonRelleno {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Volver a salas"
                        radioBorde: 999
                        onClicked: {
                            codigoSalaPropia = "";
                            pantalla = "Salas";
                            redcliente.refrescarSalas(servidorHost, servidorPuerto);
                        }
                    }
                }
            }
        }

        // ── Pantalla 2: sala de espera ─────────────────────────────────
        BarraSuperior {
            id: barraLobby
            visible: pantalla === "Lobby"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            textoCentro: hostActual !== "" ? "Sala de " + hostActual : ""
        }

        // Item, no Row: mismo motivo que en la mesa — un Row no centra
        // verticalmente hijos de distinta altura, así que cada bloque se
        // centra por su cuenta con su propio "anchors.verticalCenter".
        Item {
            visible: pantalla === "Lobby"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 25 * ventana.escala
            width: columnaSala.width + 40 + chatLobby.width
            height: Math.max(columnaSala.height, chatLobby.height)

            Column {
                id: columnaSala
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 22

                Column {
                    spacing: 2
                    Text {
                        text: "Sala de " + (hostActual !== "" ? hostActual : "espera")
                        color: "white"
                        font.family: ventana.fuenteElegante
                        font.pixelSize: 22
                        font.bold: true
                    }
                    Text {
                        id: contadorListos
                        color: ventana.colorTextoTenue
                        font.pixelSize: 12
                    }
                    Text {
                        visible: codigoSalaPropia !== ""
                        text: "Código para invitar: " + codigoSalaPropia
                        color: ventana.colorAccent
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Text {
                        // Solo relevante si esta sala viene de reanudar una
                        // partida guardada (CARGAR_PARTIDA) — para que quien
                        // se una sepa con qué nombre entrar aunque no lo
                        // recuerde.
                        visible: nombresEsperadosLobby !== ""
                        text: "Nombres esperados: " + nombresEsperadosLobby
                        color: ventana.colorTextoTenue
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        width: 260 * ventana.escala
                    }
                }

                Row {
                    spacing: 18
                    Repeater {
                        model: jugadoresConectados
                        // Item posicionador con la property "required" (así
                        // lo exige el modo Bound para leer el modelo), que
                        // mete dentro un AsientoMini normal — igual patrón
                        // que los asientos de la mesa real.
                        delegate: Item {
                            id: posicionadorMini
                            required property string nombre
                            width: asientoMiniReal.width
                            height: asientoMiniReal.height
                            AsientoMini {
                                id: asientoMiniReal
                                nombre: posicionadorMini.nombre
                            }
                        }
                    }
                }

                BotonRelleno {
                    visible: soyHost
                    text: "Empezar ahora"
                    radioBorde: 999
                    onClicked: redcliente.empezarPartida()
                }
            }

            // No hay historial en el lobby — solo chat, directamente, sin
            // pestañas que elegir (ChatBox ya es chat-only).
            ChatBox {
                id: chatLobby
                anchors.left: columnaSala.right
                anchors.leftMargin: 40
                anchors.verticalCenter: parent.verticalCenter
                modelo: mensajesChat
                miNombre: nombreUsuario.text
            }
        }
        // ------------------- PARTIDA --------------------------------
        Item {
            visible: pantalla === "Partida"
            anchors.fill: parent

            // ── Barra superior: identidad + estado de la mano + tu saldo ──
            BarraSuperior {
                id: barraSuperior
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                mostrarSaldo: true
                // Binding declarativo — nunca le asignes texto a mano en
                // otro sitio (p. ej. en un handler de C++), porque eso
                // rompe este binding para siempre. Cualquier dato nuevo que
                // quiera mostrarse aquí debe pasar por una property (como
                // "rondaActual") y entrar en esta misma expresión.
                textoCentro: rondaActual + " · Mano " + manoActual + " · Ciega " + Math.round(ciegaActual / 2) + "/" + ciegaActual + " · Turno de " + turnoNombre
            }

            // ── Centro: la mesa, pieza principal, con el panel de
            // historial/chat al lado — un Item normal, no un Row, porque un
            // Row no centra verticalmente hijos de distinta altura (cada
            // uno se queda pegado arriba); así cada pieza se centra sola
            // con su propio "anchors.verticalCenter".
            Item {
                id: zonaCentral
                anchors.top: barraSuperior.bottom
                anchors.bottom: barraInferior.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 12 * ventana.escala
                anchors.bottomMargin: 12 * ventana.escala
                width: mesaJuego.width + 20 + panelLateralJuego.width

                Mesa {
                    id: mesaJuego
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 820 * ventana.escala
                    height: 460 * ventana.escala
                    jugadores: jugadoresPartida
                    cartasMesa: ventana.cartasMesa
                    bote: boteActual
                    turnoNombre: ventana.turnoNombre
                    miNombreJugador: nombreUsuario.text
                    fraccionTiempo: ventana.fraccionTiempoRestante
                    retirados: ventana.retirados
                }

                PanelLateral {
                    id: panelLateralJuego
                    anchors.left: mesaJuego.right
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    width: 340 * ventana.escala
                    height: mesaJuego.height
                    modeloHistorial: historial
                    modeloChat: mensajesChat
                    miNombre: nombreUsuario.text
                }
            }

            // ── Barra inferior: tu mano + estimación a la izquierda,
            // acciones (o el voto de fin de mano) a la derecha ───────────
            Rectangle {
                id: barraInferior
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 90 * ventana.escala
                color: ventana.colorPanel
                border.color: ventana.colorBorde
                border.width: 1

                // Tus cartas asoman por encima del borde de la barra — el
                // Rectangle no recorta a sus hijos por defecto, así que
                // basta con centrar verticalmente este Row sobre el propio
                // borde superior de la barra ("parent.top", no
                // "parent.verticalCenter") en vez de dejarlo dentro del
                // todo.
                Row {
                    id: filaCartasPropias
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.top
                    spacing: 6
                    Carta {
                        codigo: miCarta1
                        propia: true
                    }
                    Carta {
                        codigo: miCarta2
                        propia: true
                    }
                }

                Row {
                    anchors.left: filaCartasPropias.right
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16

                    Column {
                        spacing: 2
                        Text {
                            text: "ACTUAL"
                            color: ventana.colorTextoTenue
                            font.pixelSize: 10
                        }
                        Text {
                            text: comboActual
                            color: "white"
                            font.bold: true
                            font.family: ventana.fuenteElegante
                        }
                    }
                    Column {
                        spacing: 2
                        Text {
                            text: "PROBABLE"
                            color: ventana.colorTextoTenue
                            font.pixelSize: 10
                        }
                        Text {
                            text: comboProbable
                            color: "#C7CFC9"
                            font.family: ventana.fuenteElegante
                        }
                    }
                    Column {
                        spacing: 2
                        Text {
                            text: "MÁXIMA"
                            color: ventana.colorTextoTenue
                            font.pixelSize: 10
                        }
                        Text {
                            text: comboMaxima
                            color: ventana.colorAccent
                            font.bold: true
                            font.family: ventana.fuenteElegante
                        }
                    }
                }

                // Acciones del turno: retirarse / igualar-pasar / subir (con
                // slider) / all-in, todo en una sola franja — como en el
                // boceto, sin un modo "subir" aparte que tape lo demás.
                Row {
                    visible: tuTurno
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 16
                    spacing: 10

                    BotonContorno {
                        text: "Retirarse"
                        colorBorde: ventana.colorPeligro
                        onClicked: {
                            redcliente.enviarAccion("FOLD", 0);
                            tuTurno = false;
                            // Parar el anillo/cuenta atrás ya mismo, sin
                            // esperar al próximo GAME_STATE del servidor —
                            // si no, sigue drenándose con el turnoNombre
                            // viejo durante el hueco de red hasta que
                            // llegue el turno real del siguiente jugador.
                            turnoNombre = "";
                        }
                    }
                    BotonContorno {
                        text: aPagarParaIgualar > 0 ? "Igualar · " + aPagarParaIgualar : "Pasar"
                        onClicked: {
                            redcliente.enviarAccion(aPagarParaIgualar > 0 ? "CALL" : "CHECK", Math.min(aPagarParaIgualar, miSaldoActual));
                            tuTurno = false;
                            // Parar el anillo/cuenta atrás ya mismo, sin
                            // esperar al próximo GAME_STATE del servidor —
                            // si no, sigue drenándose con el turnoNombre
                            // viejo durante el hueco de red hasta que
                            // llegue el turno real del siguiente jugador.
                            turnoNombre = "";
                        }
                    }
                    Slider {
                        id: sliderSubida
                        width: 220 * ventana.escala
                        // Antes 0..saldo, una aproximación sin mínimo ni
                        // tope real de pot-limit/fixed-limit. Ahora el rango
                        // exacto que manda el servidor en cada TU_TURNO.
                        from: minSubidaActual
                        to: maxSubidaActual
                        value: minSubidaActual
                        // Arrastrar el slider escribe directamente en su
                        // propia "value" — eso rompe el binding de arriba
                        // para siempre (comportamiento normal de QML con
                        // cualquier control interactivo). Sin este
                        // onMoved, el campo de texto dejaba de seguir al
                        // slider en cuanto lo arrastrabas una vez.
                        onMoved: campoSubida.text = String(Math.round(value))
                    }
                    // El slider solo no basta en escritorio (ratón/touchpad
                    // es incómodo para precisión) — un SpinBox ocupaba mucho
                    // sitio para lo poco que aportaba (seguía siendo tan
                    // lento llegar al número deseado). Un campo de texto
                    // simple es más directo: "text" sigue al slider, y al
                    // terminar de escribir (Enter o perder el foco) empuja
                    // el valor de vuelta, igual que hacía el SpinBox.
                    TextField {
                        id: campoSubida
                        width: 90 * ventana.escala
                        // Mismo motivo que el wordmark de arriba: Row no
                        // centra hijos de distinta altura entre sí (botones,
                        // slider y campo de texto no miden lo mismo por
                        // defecto) — se baja a mano. Ajusta este número si
                        // no queda perfecto a simple vista.
                        y: 6
                        color: "white"
                        selectionColor: ventana.colorAccent
                        horizontalAlignment: Text.AlignHCenter
                        // Fondo/borde a mano — por defecto un TextField de
                        // Qt Quick Controls sale gris claro/blanco, fuera de
                        // sitio en esta paleta. El borde se ilumina con el
                        // color de acento solo cuando tiene el foco.
                        background: Rectangle {
                            color: ventana.colorPanel
                            radius: 6
                            border.width: 1
                            border.color: campoSubida.activeFocus ? ventana.colorAccent : ventana.colorBorde
                        }
                        // bottom/top NO se atan a minSubidaActual/maxSubidaActual:
                        // IntValidator rechaza cada pulsación cuyo resultado
                        // parcial exceda "top", así que con un máximo bajo
                        // era imposible teclear un número más largo (se
                        // quedaba pegado en 1 dígito). El rango real ya se
                        // aplica al terminar de escribir (onEditingFinished).
                        validator: IntValidator {
                            bottom: 0
                            top: 2147483647
                        }
                        text: Math.round(sliderSubida.value)
                        // Igual que onMoved del slider: escribir aquí rompe
                        // el binding de "text" de arriba para siempre, así
                        // que hay que fijar el valor final a mano en los dos
                        // sitios (slider Y el propio texto, por si lo
                        // tecleado se salía de rango y quedó sin recortar).
                        onEditingFinished: {
                            var v = Math.max(minSubidaActual, Math.min(parseInt(text) || 0, sliderSubida.to));
                            sliderSubida.value = v;
                            text = String(v);
                        }
                    }
                    BotonRelleno {
                        text: "Subir"
                        enabled: maxSubidaActual > 0
                        onClicked: {
                            var total = Math.min(aPagarParaIgualar + Math.round(sliderSubida.value), miSaldoActual);
                            redcliente.enviarAccion("RAISE", total);
                            tuTurno = false;
                            // Parar el anillo/cuenta atrás ya mismo, sin
                            // esperar al próximo GAME_STATE del servidor —
                            // si no, sigue drenándose con el turnoNombre
                            // viejo durante el hueco de red hasta que
                            // llegue el turno real del siguiente jugador.
                            turnoNombre = "";
                        }
                    }
                    BotonContorno {
                        id: botonAllIn
                        property bool confirmando: false
                        text: confirmando ? "¿Seguro?" : "ALL"
                        colorBorde: ventana.colorPeligro
                        onClicked: {
                            // Ver "Cliente" en el cajón de ajustes — con el
                            // interruptor activo, hace falta un segundo
                            // clic para evitar un ALL-IN por error.
                            if (confirmarAllIn && !confirmando) {
                                confirmando = true;
                                return;
                            }
                            confirmando = false;
                            redcliente.enviarAccion("ALL_IN", miSaldoActual);
                            tuTurno = false;
                            // Parar el anillo/cuenta atrás ya mismo, sin
                            // esperar al próximo GAME_STATE del servidor —
                            // si no, sigue drenándose con el turnoNombre
                            // viejo durante el hueco de red hasta que
                            // llegue el turno real del siguiente jugador.
                            turnoNombre = "";
                        }
                    }
                }

                // ------ RECOMPRA (te quedaste sin fichas, la sala lo permite) ------
                Row {
                    visible: puedoRecomprar
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 16
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Te has quedado sin fichas"
                        color: ventana.colorTextoTenue
                    }
                    BotonRelleno {
                        text: recompraSolicitada ? "Recompra enviada…" : "Recomprar"
                        enabled: !recompraSolicitada
                        onClicked: {
                            redcliente.pedirRecompra();
                            recompraSolicitada = true;
                        }
                    }
                }

                // El voto de fin de mano (continuar/abandonar/guardar) ya NO
                // vive aquí — se movió dentro del overlay de showdown (ver
                // más abajo, PanelVoto) para poder votar mientras se ven las
                // cartas reveladas, en vez de un menú aparte que tapaba la
                // mesa de golpe. onGanadorSinShowdown() abre ese mismo
                // overlay (sin cartas que mostrar) para que el voto siga
                // teniendo un único sitio también cuando la mano termina
                // sin showdown real (todos se retiran menos uno).

                // ------ VOTACION (extender la partida) -------------------
                Column {
                    visible: votoExtensionAbierto
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 16
                    spacing: 6

                    Text {
                        id: votoExtensionTexto
                        color: ventana.colorAccent
                        font.bold: true
                        wrapMode: Text.WordWrap
                        width: 260 * ventana.escala
                    }
                    Row {
                        spacing: 8
                        BotonRelleno {
                            text: "Sí, extender"
                            onClicked: {
                                redcliente.votarExtension(true);
                                votoExtensionAbierto = false;
                            }
                        }
                        BotonContorno {
                            text: "No, terminar aquí"
                            colorBorde: ventana.colorPeligro
                            onClicked: {
                                redcliente.votarExtension(false);
                                votoExtensionAbierto = false;
                            }
                        }
                    }
                }
            }
        }

        Connections {
            target: redcliente
            function onConectado() {
                pantalla = "Lobby";
                chatActive = true;
            }
            function onError(mensaje) {
                // Sin pantalla propia: puede llegar estando en Inicio, Salas
                // o CrearSala (las tres inician una conexión) — el mensaje
                // vive en una property compartida que las tres muestran.
                mensajeErrorConexion = "Error: " + mensaje;
            }
            function onNombreRechazado(mensaje) {
                // onConectado ya nos había pasado a "Lobby" (llega antes de
                // saber si el servidor acepta el nombre) — deshacemos ese
                // salto y dejamos el mensaje donde el usuario puede verlo.
                pantalla = "Inicio";
                mensajeErrorConexion = mensaje;
            }
            function onSalasActualizadas(salasCsv) {
                salasDisponibles.clear();
                if (salasCsv.length === 0) return;
                var salas = salasCsv.split(";");
                for (var i = 0; i < salas.length; i++) {
                    var campos = salas[i].split(":");
                    // "nombre" es el resto tras los 3 primeros campos, no
                    // campos[3] a secas — es texto libre del host y podría
                    // traer sus propios ':'.
                    salasDisponibles.append({
                        id: campos[0],
                        conectados: parseInt(campos[1]),
                        esperados: parseInt(campos[2]),
                        nombre: campos.slice(3).join(":")
                    });
                }
            }
            function onSalaCreada(salaId, codigo) {
                codigoSalaPropia = codigo;
            }
            function onGuardadasActualizadas(guardadasCsv) {
                guardadasDisponibles.clear();
                if (guardadasCsv.length === 0) return;
                var guardadas = guardadasCsv.split(";");
                for (var i = 0; i < guardadas.length; i++) {
                    var campos = guardadas[i].split(":");
                    // "fecha" es el resto tras los 3 primeros campos, no
                    // campos[3] a secas — trae su propio ':' (hora) que
                    // split(":") ya partió por su cuenta.
                    guardadasDisponibles.append({
                        archivo: campos[0],
                        humanos: parseInt(campos[1]),
                        bots: parseInt(campos[2]),
                        fecha: campos.slice(3).join(":")
                    });
                }
            }
            function onGuardadaRenombrada(mensaje) {
                // mensaje vacío = fue bien; en los dos casos se refresca
                // para ver el resultado (nombre nuevo, o simplemente que no
                // cambió nada si falló).
                if (mensaje.length > 0) mensajeErrorConexion = mensaje;
                redcliente.listarGuardadas(servidorHost, servidorPuerto);
            }
            function onGuardadaBorrada(mensaje) {
                if (mensaje.length > 0) mensajeErrorConexion = mensaje;
                redcliente.listarGuardadas(servidorHost, servidorPuerto);
            }
            function onNombreAsignado(nombre) {
                // Corrige nombreUsuario.text si el servidor usó un nombre
                // distinto del escrito (vacío o sanitizado) — de lo
                // contrario "soyHost" y el resaltado del propio nombre en
                // el historial se comparan contra un valor que ya no coincide.
                nombreUsuario.text = nombre;
            }
            function onAvisoRecompra(puedeRecomprar) {
                puedoRecomprar = puedeRecomprar;
                recompraSolicitada = false;
            }
            function onErrorSala(mensaje) {
                // Mismo motivo que onNombreRechazado: onConectado ya nos
                // había mandado a "Lobby" antes de saber si el servidor
                // aceptaba la unión — se deshace el salto.
                pantalla = "Salas";
                mensajeErrorConexion = mensaje;
            }
            function onLobbyActualizado(jugadoresCsv, listos, esperados, host, esperadosNombresCsv) {
                jugadoresConectados.clear();
                var nombres = jugadoresCsv.split(",");
                for (var i = 0; i < nombres.length; i++) {
                    jugadoresConectados.append({
                        nombre: nombres[i]
                    });
                }
                contadorListos.text = listos + " / " + esperados + " listos";
                hostActual = host;
                nombresEsperadosLobby = esperadosNombresCsv;
            }
            function onChatRecibido(de, texto) {
                mensajesChat.append({
                    autor: de,
                    mensaje: texto,
                    hora: Qt.formatTime(new Date(), "hh:mm")
                });
            }
            function onPartidaIniciada(manos, tipoLimite, permitirRecompra, rellenarConBots) {
                pantalla = "Partida";
                chatActive = false;
                objetivoManos = manos;
                tipoLimiteActual = tipoLimite;
                permitirRecompraActual = permitirRecompra;
                rellenarConBotsActual = rellenarConBots;
            }
            function onEstadoMesaActualizado(ronda, bote, turno, jugadoresStr, timeoutMs) {
                rondaActual = ronda;
                boteActual = bote;
                turnoNombre = turno;
                // Si el servidor ya dice que el turno es de otro (o de
                // nadie), asegurar que la fila de acciones se oculte aunque
                // nunca se haya pulsado un botón — pasa cuando el turno
                // termina por timeout del servidor en vez de por clic, y
                // antes se quedaba con tuTurno=true para siempre (los
                // botones seguían ahí incluso con la mano ya terminada).
                if (turno !== nombreUsuario.text) tuTurno = false;
                // timeoutMs > 0: este GAME_STATE viene de onTurnoIniciado (un
                // turno de verdad empezando, de cualquier jugador) — arranca
                // la cuenta atrás del anillo para quien tenga el turno ahora.
                // El GAME_STATE "viejo" (justo antes de onPreTurnoHumano) no
                // manda timeout_ms (llega como 0) y no debe reiniciar nada.
                if (timeoutMs > 0) {
                    timeoutMsActual = timeoutMs;
                    inicioTurnoMs = Date.now();
                    fraccionTiempoRestante = 1.0;
                }

                jugadoresPartida.clear();
                var jugadores = jugadoresStr.split(";");
                for (var i = 0; i < jugadores.length; i++) {
                    var campos = jugadores[i].split(":");
                    jugadoresPartida.append({
                        nombre: campos[0],
                        saldo: campos[1],
                        apuesta: campos[2]
                    });
                    // No hay un evento dedicado de "recompra confirmada" —
                    // se detecta viendo que el propio saldo ya no es 0.
                    if (campos[0] === nombreUsuario.text && parseInt(campos[1]) > 0) {
                        puedoRecomprar = false;
                        recompraSolicitada = false;
                    }
                }
            }
            function onEventoJuego(evento, tipo, jugador) {
                historial.append({
                    linea: evento,
                    tipo: tipo,
                    jugador: jugador,
                    hora: Qt.formatTime(new Date(), "hh:mm")
                });
            }
            function onNuevaMano(mano, ciega) {
                manoActual = mano;
                ciegaActual = ciega;
                retirados = [];
                // Sin esto, el preflop de la mano nueva sigue mostrando las
                // 5 cartas comunitarias de la mano anterior hasta que llega
                // el primer MESA_UPDATE (flop) — onMesaActualizada() es lo
                // único que las toca, y solo se dispara al revelar cartas.
                cartasMesa = [];
                // Mismo motivo con la propia mano: sin esto se verían las
                // cartas de la mano anterior hasta que llegue TUS_CARTAS.
                miCarta1 = "";
                miCarta2 = "";
                // Red de seguridad: si por lo que sea no llegó ESPERAR_VOTO
                // (p. ej. nadie tenía que votar), que el showdown no se
                // quede abierto para siempre tapando la mesa de la mano nueva.
                showdownAbierto = false;
            }
            function onShowdownIniciado(cartasCsv) {
                cartasMesa = cartasCsv.length > 0 ? cartasCsv.split(",") : [];
                revealsShowdown = [];
                showdownAbierto = true;
            }
            function onCartasMostradas(jugador, cartasCsv, combo) {
                revealsShowdown = revealsShowdown.concat([{
                    nombre: jugador,
                    cartas: cartasCsv.split(","),
                    combo: combo,
                    esGanador: false,
                    premio: 0
                }]);
            }
            function onBoteGanado(jugador, premio, combo) {
                revealsShowdown = revealsShowdown.map(function(r) {
                    if (r.nombre !== jugador) return r;
                    return {
                        nombre: r.nombre,
                        cartas: r.cartas,
                        combo: r.combo,
                        esGanador: true,
                        premio: r.premio + premio
                    };
                });
            }
            function onGanadorSinShowdown(jugador, bote) {
                // Todos se retiraron menos uno — no hay MUESTRA_CARTAS que
                // narre nada, pero el voto de fin de mano (ver PanelVoto)
                // solo vive dentro de este overlay, así que se abre igual,
                // con una única tarjeta sin cartas que enseñar.
                cartasMesa = [];
                revealsShowdown = [{
                    nombre: jugador,
                    cartas: [],
                    combo: "Se llevó el bote sin mostrar cartas",
                    esGanador: true,
                    premio: bote
                }];
                showdownAbierto = true;
            }
            function onMisCartasRepartidas(c1, c2) {
                // Llega justo al repartir, antes de cualquier turno — sin
                // esto, la propia mano se mostraba como "?" hasta el primer
                // turno propio (TU_TURNO es lo único que las traía antes).
                miCarta1 = c1;
                miCarta2 = c2;
            }
            function onAccionRealizada(jugador, accion) {
                if (accion === "FOLD") {
                    retirados = retirados.concat([jugador]);
                }
            }
            function onEsMiTurno(bote, igualar, miSaldo, miApuesta, timeoutMs, minSubida, maxSubida, c1, c2, comboA, comboP, comboM) {
                miCarta1 = c1;
                miCarta2 = c2;
                tuTurno = true;
                igualarActual = igualar;
                miApuestaActual = miApuesta;
                miSaldoActual = miSaldo;
                minSubidaActual = minSubida;
                maxSubidaActual = maxSubida;
                timeoutMsActual = timeoutMs;
                inicioTurnoMs = Date.now();
                fraccionTiempoRestante = 1.0;
                comboActual = comboA;
                comboProbable = comboP;
                comboMaxima = comboM;
                // Nuevo turno: si el anterior quedó a medio confirmar
                // (tocaste "ALL" pero no llegaste a confirmar), no debe
                // arrastrarse al turno siguiente.
                botonAllIn.confirmando = false;

                // Reset explícito, no un binding: en cuanto el usuario toca
                // el slider o escribe en el campo una vez, QML rompe para
                // siempre el binding declarativo de esa propiedad — sin
                // esto, a partir de la segunda vez que interactúas, el
                // slider/campo dejaban de volver al mínimo en el turno
                // siguiente y podían quedarse desincronizados entre sí.
                sliderSubida.value = minSubida;
                campoSubida.text = String(minSubida);

                for (var j = 0; j < jugadoresPartida.count; j++) {
                    if (jugadoresPartida.get(j).nombre === nombreUsuario.text) {
                        jugadoresPartida.setProperty(j, "saldo", miSaldo);
                        break;
                    }
                }
            }
            function onEsperandoVoto(mensaje) {
                mensajeVoto = mensaje;
                votoAbierto = true;
                // Cierra la fila de acciones pase lo que pase: si tu último
                // turno de la mano fue el ÚLTIMO turno de toda la mano (p.
                // ej. quedaste tú solo por actuar antes del showdown), no
                // vuelve a haber ningún GAME_STATE con "turno" de otro
                // jugador que dispare el reset de onEstadoMesaActualizado —
                // turno se queda con tu nombre durante todo el showdown, y
                // los botones se quedan visibles hasta que alguien haga
                // clic. Aquí no hace falta ninguna condición: si se abre el
                // menú de voto, por definición ya no es el turno de nadie.
                tuTurno = false;
                // Mismo problema con el aro de tiempo: si tu turno (o el de
                // un bot) fue el último de la mano, turnoNombre se queda
                // apuntando a ese jugador durante todo el showdown — nadie
                // más vuelve a tener turno, así que el Timer sigue
                // girándole el aro hasta agotar la cuenta sola, aunque la
                // decisión ya esté tomada hace rato. Vaciarlo para el resto
                // de la ronda de fin de mano.
                turnoNombre = "";
                // El showdown YA NO se cierra aquí a propósito: el usuario
                // quiere seguir viendo las cartas reveladas mientras se
                // vota la siguiente mano (el botón de votar vive también
                // dentro del overlay de showdown, ver más abajo). Se cierra
                // solo con la mano nueva (onNuevaMano).
            }
            function onEsperandoVotoExtension(mensaje, manos) {
                votoExtensionTexto.text = mensaje;
                votoExtensionAbierto = true;
                // Mismo motivo que onEsperandoVoto: por definición ya no es
                // el turno de nadie si se está votando la extensión.
                tuTurno = false;
                turnoNombre = "";
            }
            function onMesaActualizada(cartasCsv) {
                cartasMesa = cartasCsv.length > 0 ? cartasCsv.split(",") : [];
            }
            function onFinDePartida(ganador, saldo, porLimite) {
                ganadorFinal = ganador;
                saldoFinal = saldo;
                finPorLimite = porLimite;
                partidaGuardada = false;
                // Mismo motivo que onEsperandoVoto: la partida terminó, ya
                // no hay ningún turno de acción pendiente que mostrar.
                tuTurno = false;
                turnoNombre = "";
                // Sin esto, el showdown/voto de la última mano se quedaba
                // abierto tapando la pantalla de Fin de fondo.
                showdownAbierto = false;
                votoAbierto = false;
                votoExtensionAbierto = false;
                pantalla = "Fin";
            }
            function onAbandonaste(mensaje) {
                mensajeErrorConexion = mensaje;
                // Mismo motivo que onFinDePartida: si abandonas desde dentro
                // del overlay de showdown, no debe quedarse tapando la
                // pantalla de Salas de fondo.
                showdownAbierto = false;
                votoAbierto = false;
                pantalla = "Salas";
                redcliente.refrescarSalas(servidorHost, servidorPuerto);
            }
            function onSaldosActualizados(jugadoresStr) {
                var jugadores = jugadoresStr.split(";");
                for (var i = 0; i < jugadores.length; i++) {
                    var campos = jugadores[i].split(":");
                    for (var j = 0; j < jugadoresPartida.count; j++) {
                        if (jugadoresPartida.get(j).nombre === campos[0]) {
                            jugadoresPartida.setProperty(j, "saldo", campos[1]);
                            break;
                        }
                    }
                }
            }
            function onPartidaGuardada(archivo) {
                partidaGuardada = true;
                // Sin esto, "Guardar y salir" desde el overlay de showdown
                // se quedaba con el showdown encima de la pantalla de Fin
                // para siempre (showdownAbierto nunca se cerraba con este
                // evento) — igual que votoAbierto/votoExtensionAbierto,
                // que tampoco tenían por qué seguir abiertos.
                showdownAbierto = false;
                votoAbierto = false;
                votoExtensionAbierto = false;
                pantalla = "Fin";
            }
            function onReconectando(segundosRestantes) {
                reconectandoAhora = true;
                segundosReconexion = segundosRestantes;
            }
            function onReconectado() {
                reconectandoAhora = false;
            }
            function onReconexionFallida() {
                reconectandoAhora = false;
                pantalla = "Inicio";
                mensajeErrorConexion = "Se perdió la conexión con el servidor.";
            }
        }

        ListModel {
            id: mensajesChat
        }
        ListModel {
            id: jugadoresConectados
        }
        ListModel {
            id: jugadoresPartida
        }
        ListModel {
            id: historial
        }
    }

    // Aviso de tamaño mínimo: por debajo de "escalaMinima" el contenido ya
    // no cabría de forma legible (botones inaccesibles, texto solapado) —
    // mejor un aviso claro que una interfaz rota. Se declara como hermano
    // de la pantalla principal (no dentro), para quedar siempre por encima
    // de todo, sea cual sea el valor de "pantalla" en ese momento.
    Rectangle {
        anchors.fill: parent
        visible: escala < escalaMinima
        color: "#0A140F"

        Text {
            anchors.centerIn: parent
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "La ventana es demasiado pequeña para mostrar la partida correctamente.\nAgrándala para continuar."
            color: "white"
            font.pixelSize: 16
        }
    }

    // Mismo patrón que el aviso de tamaño mínimo de arriba: hermano de la
    // pantalla principal para quedar siempre encima, sea cual sea "pantalla".
    // Se ve mientras NetworkClient reintenta la conexión (mismo mecanismo de
    // reconexión de 60s que ya tiene el servidor/cliente ncurses).
    Rectangle {
        anchors.fill: parent
        visible: reconectandoAhora
        color: "#0A140F"
        opacity: 0.92

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Conexión perdida — reconectando..."
                color: "white"
                font.pixelSize: 18
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: segundosReconexion + "s restantes"
                color: ventana.colorTextoTenue
            }
        }
    }

    // Mismo patrón que los overlays de arriba: hermano de la pantalla
    // principal para quedar siempre encima. Se abre con SHOWDOWN y se
    // cierra al llegar el turno de votar (o una mano nueva) — ver
    // onShowdownIniciado/onEsperandoVoto/onNuevaMano más arriba.
    Rectangle {
        anchors.fill: parent
        visible: showdownAbierto
        color: "#0A140F"
        opacity: 0.94

        Column {
            anchors.centerIn: parent
            // Nunca más ancho que la ventana menos aire a los lados — con
            // hasta 9 jugadores en el showdown, la fila de abajo (Flow) ya
            // se encarga de partir en varias líneas si no caben en una.
            width: Math.min(parent.width - 80 * ventana.escala, 900 * ventana.escala)
            spacing: 18 * ventana.escala

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "SHOWDOWN"
                color: ventana.colorAccent
                font.letterSpacing: 3
                font.pixelSize: 13
                font.bold: true
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Repeater {
                    model: cartasMesa
                    delegate: Carta {
                        required property string modelData
                        codigo: modelData
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Bote: " + boteActual
                color: ventana.colorTextoTenue
                font.family: ventana.fuenteElegante
            }

            // Una tarjeta por jugador que llegó al showdown — los que se
            // retiraron antes ni aparecen aquí (nunca llega su
            // MUESTRA_CARTAS). "Flow" en vez de "Row" para que con mesas
            // grandes (hasta 9 jugadores) pase a una segunda línea en vez
            // de salirse de la pantalla.
            Flow {
                id: filaReveals
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16 * ventana.escala
                // "width: parent.width" dejaba el Flow pegado a la izquierda
                // con hueco vacío a la derecha en cuanto había menos
                // jugadores de los que caben en una línea (el caso normal:
                // 2-6). En vez de eso, el ancho es justo el que ocupa el
                // contenido — así el "anchors.horizontalCenter" de arriba sí
                // centra la fila entera — salvo que no quepa, en cuyo caso
                // se usa el ancho completo para que siga partiendo en varias
                // líneas con 9 jugadores.
                readonly property real anchoItem: 130 * ventana.escala
                readonly property real anchoContenido: revealsShowdown.length * anchoItem +
                        Math.max(0, revealsShowdown.length - 1) * spacing
                width: Math.min(parent.width, anchoContenido)

                Repeater {
                    model: revealsShowdown
                    delegate: Rectangle {
                        id: tarjetaReveal
                        required property var modelData
                        width: 130 * ventana.escala
                        // Altura según el contenido, no fija — con
                        // "cartas: []" (ganó sin showdown real, ver
                        // repartirBotes()) la fila de cartas desaparece,
                        // y una altura fija de sobra dejaba un hueco vacío
                        // enorme en medio de la tarjeta.
                        height: columnaTarjetaReveal.height + 28 * ventana.escala
                        radius: 12
                        color: modelData.esGanador ? Qt.rgba(0.75, 0.56, 0.24, 0.10) : "transparent"
                        border.width: modelData.esGanador ? 2 : 1
                        border.color: modelData.esGanador ? ventana.colorAccent : ventana.colorBorde

                        Column {
                            id: columnaTarjetaReveal
                            anchors.centerIn: parent
                            spacing: 8 * ventana.escala

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tarjetaReveal.modelData.nombre
                                color: tarjetaReveal.modelData.esGanador ? ventana.colorAccent : "white"
                                font.bold: tarjetaReveal.modelData.esGanador
                                font.family: ventana.fuenteElegante
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4
                                Repeater {
                                    model: tarjetaReveal.modelData.cartas
                                    delegate: Carta {
                                        required property string modelData
                                        codigo: modelData
                                    }
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tarjetaReveal.modelData.combo
                                color: ventana.colorTextoTenue
                                font.pixelSize: 11
                            }
                            Rectangle {
                                visible: tarjetaReveal.modelData.esGanador
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: textoGanancia.implicitWidth + 16
                                height: 20
                                radius: 10
                                color: ventana.colorAccent
                                clip: true

                                // Brillo animado — el único sitio "hero" del
                                // programa donde se justifica (ver "Sistema
                                // visual", sección 16): una franja clara que
                                // cruza en diagonal cada pocos segundos.
                                // Nunca en botones normales — ahí competiría
                                // con lo que de verdad hay que mirar.
                                Rectangle {
                                    width: 10
                                    height: parent.height * 2.4
                                    rotation: 22
                                    anchors.verticalCenter: parent.verticalCenter
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "transparent" }
                                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.55) }
                                        GradientStop { position: 1.0; color: "transparent" }
                                    }
                                    SequentialAnimation on x {
                                        running: tarjetaReveal.modelData.esGanador
                                        loops: Animation.Infinite
                                        NumberAnimation {
                                            from: -20; to: textoGanancia.implicitWidth + 30
                                            duration: 1400; easing.type: Easing.InOutQuad
                                        }
                                        PauseAnimation { duration: 1800 }
                                    }
                                }

                                Text {
                                    id: textoGanancia
                                    anchors.centerIn: parent
                                    text: "+" + tarjetaReveal.modelData.premio
                                    color: ventana.colorPanel
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }

            // El voto de fin de mano vive TAMBIÉN aquí (mismo mensaje y
            // mismos botones que la fila de acciones normal, ver
            // PanelVoto) — así se puede votar sin dejar de ver las cartas
            // reveladas, en vez de que el showdown se cierre de golpe en
            // cuanto empieza a poder votarse.
            Column {
                visible: votoAbierto
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: mensajeVoto
                    color: ventana.colorAccent
                    font.bold: true
                }
                PanelVoto {
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    // ── Cajón lateral de ajustes ───────────────────────────────────────────
    // El botón que lo abre ya no flota aparte — vive dentro de la
    // BarraSuperior de cada pantalla (ver el componente más arriba), así
    // que aquí solo queda el propio cajón + su fondo oscurecido.
    // Fondo oscurecido — clic fuera del cajón para cerrarlo.
    Rectangle {
        anchors.fill: parent
        visible: ajustesAbiertos
        color: "black"
        opacity: 0.35
        z: 58
        MouseArea {
            anchors.fill: parent
            onClicked: ajustesAbiertos = false
        }
    }

    Rectangle {
        id: cajonAjustes
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 300 * ventana.escala
        // Se desliza desde fuera de la ventana en vez de aparecer/desaparecer
        // de golpe — "x" en vez de "anchors.right" porque necesita animarse.
        x: ajustesAbiertos ? parent.width - width : parent.width
        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.3)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(ventana.colorPanel, 1.4) }
            GradientStop { position: 1.0; color: ventana.colorPanel }
        }
        z: 62

        // ScrollView en vez de Column a secas: con "Mesa actual" + "Cliente"
        // + la chuleta de manos, el contenido ya no cabe siempre en una
        // ventana pequeña — mismo patrón que el formulario de Crear sala.
        ScrollView {
            id: scrollAjustes
            anchors.fill: parent
            anchors.margins: 22 * ventana.escala
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Column {
            width: scrollAjustes.availableWidth
            spacing: 20 * ventana.escala

            Text {
                text: "Ajustes"
                color: "white"
                font.family: ventana.fuenteElegante
                font.pixelSize: 20
            }

            Column {
                width: parent.width
                spacing: 10 * ventana.escala

                Text {
                    text: "TEMA DE COLOR"
                    color: ventana.colorTextoMuyTenue
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }

                Repeater {
                    model: ventana.temas
                    delegate: Rectangle {
                        id: filaTema
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: 52 * ventana.escala
                        radius: 8
                        color: ventana.temaActual === filaTema.index ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                        border.width: ventana.temaActual === filaTema.index ? 2 : 1
                        border.color: ventana.temaActual === filaTema.index ? filaTema.modelData.accent : ventana.colorBorde

                        Row {
                            anchors.fill: parent
                            anchors.margins: 10 * ventana.escala
                            spacing: 12 * ventana.escala

                            Rectangle {
                                width: 30 * ventana.escala
                                height: 30 * ventana.escala
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: filaTema.modelData.tapete
                                border.width: 2
                                border.color: filaTema.modelData.accent
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: filaTema.modelData.nombre
                                color: ventana.temaActual === filaTema.index ? "white" : ventana.colorTextoTenue
                                font.bold: ventana.temaActual === filaTema.index
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: ventana.temaActual = filaTema.index
                        }
                    }
                }
            }

            // ── Mesa actual (solo lectura, solo tiene sentido en Partida) ──
            Column {
                width: parent.width
                visible: pantalla === "Partida"
                spacing: 10 * ventana.escala

                Text {
                    text: "MESA ACTUAL"
                    color: ventana.colorTextoMuyTenue
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }

                Repeater {
                    model: [
                        { etiqueta: "Ciega actual", valor: Math.round(ciegaActual / 2) + " / " + ciegaActual },
                        { etiqueta: "Mano", valor: manoActual + " / " + objetivoManos },
                        { etiqueta: "Tipo de límite", valor: ["Sin límite", "Límite bote", "Límite fijo"][tipoLimiteActual] || "—" },
                        { etiqueta: "Permite recompra", valor: permitirRecompraActual ? "Sí" : "No" },
                        { etiqueta: "Rellena con bots", valor: rellenarConBotsActual ? "Sí" : "No" }
                    ]
                    delegate: Row {
                        required property var modelData
                        width: parent.width
                        Text {
                            width: parent.width - 80 * ventana.escala
                            text: modelData.etiqueta
                            color: ventana.colorTextoTenue
                            font.pixelSize: 12
                        }
                        Text {
                            text: modelData.valor
                            color: "white"
                            font.pixelSize: 12
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            // ── Cliente ────────────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 10 * ventana.escala

                Text {
                    text: "CLIENTE"
                    color: ventana.colorTextoMuyTenue
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }

                Row {
                    width: parent.width
                    Text {
                        width: parent.width - 46
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Sonido de notificaciones"
                        color: ventana.colorTextoTenue
                        wrapMode: Text.WordWrap
                    }
                    Interruptor {
                        anchors.verticalCenter: parent.verticalCenter
                        activo: sonidoActivado
                        onAlternado: sonidoActivado = !sonidoActivado
                    }
                }
                Row {
                    width: parent.width
                    Text {
                        width: parent.width - 46
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Confirmar antes de ALL-IN"
                        color: ventana.colorTextoTenue
                        wrapMode: Text.WordWrap
                    }
                    Interruptor {
                        anchors.verticalCenter: parent.verticalCenter
                        activo: confirmarAllIn
                        onAlternado: confirmarAllIn = !confirmarAllIn
                    }
                }

                // Chuleta de manos — acordeón simple, plegado por defecto.
                // Pensado para amigos con distinto nivel de experiencia
                // jugando en la misma mesa.
                Column {
                    width: parent.width
                    spacing: 8 * ventana.escala
                    Item {
                        // Antes el MouseArea era hijo del Row de arriba —
                        // un Row coloca a sus hijos EN FILA, así que el
                        // MouseArea quedaba puesto a la derecha del texto
                        // en vez de encima suyo, y el clic no tocaba nada.
                        // Con un Item como contenedor y el MouseArea
                        // anclado a rellenarlo entero, sí cubre el texto.
                        width: parent.width
                        height: textoRanking.height
                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Text {
                                id: textoRanking
                                text: "Ranking de manos"
                                color: ventana.colorTextoTenue
                            }
                            Text {
                                text: chuletaAbierta ? "▲" : "▼"
                                color: ventana.colorTextoMuyTenue
                                font.pixelSize: 10
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: chuletaAbierta = !chuletaAbierta
                        }
                    }
                    // Chuleta "de verdad": una fila de 5 cartas por cada
                    // combinación, como la que viene con una baraja física
                    // — mucho más rápida de leer que una lista de nombres.
                    Column {
                        width: parent.width
                        visible: chuletaAbierta
                        spacing: 10 * ventana.escala
                        Repeater {
                            model: [
                                { nombre: "1. Escalera Real", cartas: ["AS", "KS", "QS", "JS", "TS"] },
                                { nombre: "2. Escalera Color", cartas: ["9H", "8H", "7H", "6H", "5H"] },
                                { nombre: "3. Póker", cartas: ["KS", "KH", "KD", "KC", "5S"] },
                                { nombre: "4. Full House", cartas: ["JS", "JH", "JD", "4C", "4S"] },
                                { nombre: "5. Color", cartas: ["AC", "JC", "8C", "6C", "2C"] },
                                { nombre: "6. Escalera", cartas: ["TS", "9H", "8D", "7C", "6S"] },
                                { nombre: "7. Trío", cartas: ["7S", "7H", "7D", "KC", "2S"] },
                                { nombre: "8. Doble Pareja", cartas: ["QS", "QH", "9D", "9C", "4S"] },
                                { nombre: "9. Pareja", cartas: ["TS", "TH", "KD", "6C", "2S"] },
                                { nombre: "10. Carta Alta", cartas: ["AS", "JH", "8D", "6C", "3S"] }
                            ]
                            delegate: Column {
                                required property var modelData
                                required property int index
                                width: parent.width
                                spacing: 4 * ventana.escala
                                Text {
                                    text: modelData.nombre
                                    color: index < 3 ? ventana.colorAccent : ventana.colorTextoTenue
                                    font.bold: index < 3
                                    font.pixelSize: 12
                                }
                                Row {
                                    spacing: 3 * ventana.escala
                                    Repeater {
                                        model: modelData.cartas
                                        delegate: Carta {
                                            required property string modelData
                                            codigo: modelData
                                            // Mismo componente Carta de la mesa, solo
                                            // más pequeño — el tamaño de fuente interno
                                            // ya es proporcional a "width". Lo más grande
                                            // que cabe sin desbordar el cajón (300 de
                                            // ancho, 22 de margen a cada lado): 5 cartas
                                            // + 4 huecos de separación ≤ 256.
                                            width: 46 * ventana.escala
                                            height: 64 * ventana.escala
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        }
    }
}
