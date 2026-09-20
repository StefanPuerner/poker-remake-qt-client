// Asiento.qml (móvil) — un jugador sentado a la mesa: avatar circular con anillo de turno/tiempo,
// placa de nombre/saldo, mini-cartas y, en el showdown, la mano enseñada. Espejo del de escritorio
// (ver ese fichero para el detalle largo de cada pieza) con lo propio del móvil: avatar de 46 px
// (34 en el showdown) y TUS cartas dentro de tu asiento (más grandes que las mini-cartas de los
// rivales, con volteo al aterrizar y sin irse al retirarte), porque aquí no hay barra inferior.
pragma ComponentBehavior: Bound
import QtQuick
import PokerQuickMobile

Column {
    id: asiento
    property string saldo
    property string nombre
    // Para el marco de avatar permanente (ver Tema.marcoPorPartidasGanadas
    // y Avatar.qml) -- viene de GAME_STATE, así que funciona para
    // CUALQUIER jugador sentado, no solo el propio.
    property int partidasGanadas: 0
    // Visibilidad a otros jugadores, parte B (2026-09-01 -- ver memoria
    // qt_progression_review_2026_09_01): loadout REAL de quien esté
    // sentado aquí, no solo el tier de marco -- mismos campos que ya
    // pinta PopupPerfilJugador.qml para un perfil público, ahora también
    // en la mesa. "" = nada equipado en ese slot, igual que en todo el
    // resto de la app.
    property bool tieneMarcoBasico: false
    property string textura: ""
    property string efecto: ""
    property string decoracionLateral1: ""
    property string decoracionLateral2: ""
    property string decoracionSuperior: ""
    property string acabadoLateral1: ""
    property string acabadoLateral2: ""
    property string acabadoSuperior: ""
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
    // Dealer/ciegas de la mano actual (servidor, ver GAME_STATE). Un mismo
    // asiento puede ser dealer Y small blind a la vez (heads-up: el dealer
    // paga la ciega pequeña) -- por eso son propiedades independientes, no
    // un enum "posicion" de un solo valor.
    property bool esDealer: false
    property bool esSb: false
    property bool esBb: false
    // Mini-cartas de mesa -- Fase 1 de "segunda ola de cosméticos"
    // (2026-09-17). "reversoActivo" llega YA RESUELTO desde Mesa.qml
    // (el mismo valor para todos los asientos rivales -- Mesa.reversoActivo()
    // decide de una vez el reverso del dealer, o el propio si eres el
    // único humano; Asiento no vuelve a decidir nada, solo pinta lo que
    // le llega). "esPropio" distingue tu propia silla, que en escritorio
    // NO lleva mini-cartas (tu mano ya se ve grande en la barra inferior)
    // -- ver el bloque de abajo.
    property string reversoActivo: ""
    // Tu propio reverso equipado: es el que ven tus cartas mientras se reparten (el "activo" de
    // arriba es el del dealer, para las de los rivales y la mesa).
    property string miReversoSkin: ""
    property bool esPropio: false
    property string miCarta1: ""
    property string miCarta2: ""
    // Cuántas mini-cartas del abanico se ven (0-2). 2 = siempre; Mesa.qml lo baja a 0
    // durante el reparto y las va destapando según aterrizan las cartas voladoras.
    property int cartasVisibles: 2
    // Posición aproximada (coordenadas de "destino") del marcador de dealer ("D") o de ciega
    // ("SB"/"BB") de este asiento, con el avatar en tamaño normal: origen y destino del marcador
    // viajero que dibuja Mesa.qml cuando los botones rotan.
    function centroMarcador(tipo, destino) {
        var w = bloqueAvatar.width;
        return bloqueAvatar.mapToItem(destino, tipo === "D" ? w - 8 * Tema.escala : w - 12 * Tema.escala,
                                      8 * Tema.escala);
    }
    // ── Showdown sobre la misma mesa (ver docs/plan-animaciones-partida.md) ────────
    // "muestra" = null: asiento normal. Con datos {cartas: ["AS","KH"], combo: "Pareja",
    // ganador: bool}: este jugador enseña su mano -- el avatar se reduce al mínimo (solo
    // para saber de quién son las cartas), las cartas crecen, se voltean y debajo va el
    // nombre de la combinación. "resaltadas" son las cartas de la mano ganadora: las demás
    // se atenúan. Lo rellena Mesa.qml.
    property var muestra: null
    // All-in: aro dorado pulsando en el avatar hasta el fin de la mano. Eliminado: avatar
    // apagado. Van AQUÍ (no en Mesa) para seguir al avatar cuando se encoge en el showdown.
    property bool allIn: false
    property bool eliminado: false
    property bool animando: false
    property real velocidad: 1.0
    property var resaltadas: []
    readonly property bool modoMuestra: muestra !== null && muestra !== undefined
    // En el showdown primero TODOS los que muestran se preparan a la vez (avatar pequeño, cartas
    // grandes boca abajo) y luego se revelan uno por uno, en orden de apuesta. Quien enseña
    // por decisión propia (retirado, ganador sin showdown) se revela nada más prepararse.
    readonly property bool reveladaMuestra: modoMuestra && muestra.revelada === true
    readonly property real medidaAvatar: modoMuestra ? Math.round(34 * Tema.escala) : Math.round(46 * Tema.escala) + 10
    // Centro del avatar (aunque esté reducido), en las coordenadas de "destino": de ahí
    // salen/llegan las fichas del bote.
    function centroAvatar(destino) {
        return bloqueAvatar.mapToItem(destino, bloqueAvatar.width / 2, bloqueAvatar.height / 2);
    }
    // Centro de la mini-carta "i" (0 o 1) en las coordenadas de "destino" (para que
    // Mesa.qml sepa adónde mandar cada carta del reparto).
    // En tu asiento, fuera del showdown, las cartas son las propias (rectas y más grandes); en el
    // resto de casos, el abanico.
    readonly property bool usaPropias: esPropio && !modoMuestra
    function centroMiniCarta(i, destino) {
        if (usaPropias)
            return propias.mapToItem(destino, i * (propias.anchoCarta + propias.separacion) + propias.anchoCarta / 2,
                                     propias.altoCarta / 2);
        return abanico.mapToItem(destino, abanico.width / 2 + (i - 0.5) * abanico.solapeX,
                                 abanico.height - abanico.altoCarta / 2);
    }
    readonly property real anchoMiniCarta: usaPropias ? propias.anchoCarta : abanico.anchoCarta
    readonly property real altoMiniCarta: usaPropias ? propias.altoCarta : abanico.altoCarta
    readonly property real giroMiniCarta: usaPropias ? 0 : abanico.pasoAngulo
    // Retirado: el asiento se apaga, salvo tus cartas (las sigues consultando: la estimación de
    // combinaciones continúa) -- en el tuyo solo se apagan el avatar y la placa.
    opacity: retirado && !modoMuestra && !esPropio ? 0.45 : 1.0
    readonly property real atenuacionPropia: retirado && !modoMuestra && esPropio ? 0.45 : 1.0
    onActivoChanged: anillo.requestPaint()
    onFraccionTiempoChanged: if (activo)
        anillo.requestPaint()
    spacing: 8 * Tema.escala

    Item {
        id: bloqueAvatar
        // Column no centra los hijos de distinto ancho — cada uno se
        // queda pegado a la izquierda por defecto. Centramos a mano con
        // "x", que Column no toca (solo gestiona la posición vertical).
        x: (parent.width - width) / 2
        // Math.round(46*Tema.escala) -- MISMO valor que Avatar.qml calcula
        // internamente para su propio "width" (avatar.tamano ahí abajo es
        // este mismo "46 * Tema.escala"). Bug real corregido aquí
        // (2026-09-01): antes este contenedor NO redondeaba, así que su
        // ancho fraccionario no coincidía en resto con el ancho YA
        // redondeado del Avatar centrado dentro -- el mismo desfase de
        // subpíxel que "Sistema visual" ya documentó para marcoMetalico/
        // nucleo en Avatar.qml, aquí aplicado al aro de resplandor del
        // turno (los dos Rectangle "activo" de abajo, centrados en ESTE
        // Item): al no compartir resto fraccionario con el Avatar de
        // dentro, el halo quedaba centrado en el contenedor pero no en el
        // avatar que realmente se ve, dando un anillo visualmente
        // descentrado. Con los dos como enteros, la diferencia (10) es
        // exacta, sin resto.
        width: asiento.medidaAvatar
        height: width
        opacity: asiento.atenuacionPropia
        Behavior on width { NumberAnimation { duration: 450 / Math.max(0.05, asiento.velocidad); easing.type: Easing.InOutCubic } }

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
            border.width: 7 * Tema.escala
            border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.12)
        }
        Rectangle {
            visible: activo
            anchors.centerIn: parent
            // "+6", no "+5" -- mismo motivo que el redondeo de arriba:
            // con un contenedor ya entero, un margen IMPAR deja una
            // diferencia impar entre este anillo y su padre, y
            // anchors.centerIn calcula su posición como esa diferencia
            // entre 2 -- con 5 (impar) da .5, medio píxel de desfase
            // otra vez, esta vez en el propio anillo interior. Con 6
            // (par) la diferencia entre 2 siempre cae en un entero.
            width: parent.width + 6
            height: parent.height + 6
            radius: width / 2
            color: "transparent"
            border.width: 3 * Tema.escala
            border.color: Qt.rgba(Tema.colorAccent.r, Tema.colorAccent.g, Tema.colorAccent.b, 0.3)
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
                ctx.strokeStyle = fraccionTiempo < 0.2 ? Tema.colorPeligro : Tema.colorAccent;
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + fraccionTiempo * 2 * Math.PI);
                ctx.stroke();
            }
        }

        Avatar {
            anchors.centerIn: parent
            // Reducido en el showdown: mismo Avatar, solo escalado (sin recalcular su interior).
            scale: asiento.modoMuestra ? (34 * Tema.escala) / (46 * Tema.escala) : 1
            Behavior on scale { NumberAnimation { duration: 450 / Math.max(0.05, asiento.velocidad); easing.type: Easing.InOutCubic } }
            letra: nombre.charAt(0)
            tamano: 46 * Tema.escala
            // tieneMarcoBasico como 2º argumento -- bug real encontrado
            // aquí también (2026-09-01, tercera vez en un sitio distinto,
            // ver memoria qt_marco_seat_ring_contrast_bug): sin él, un
            // jugador con Hierro por victoria contra bots (sin
            // partidasGanadas "de verdad") se veía sin marco en la mesa.
            marco: Tema.marcoPorPartidasGanadas(partidasGanadas, tieneMarcoBasico)
            textura: asiento.textura
            efecto: asiento.efecto
            decoracionLateral1: asiento.decoracionLateral1
            decoracionLateral2: asiento.decoracionLateral2
            decoracionSuperior: asiento.decoracionSuperior
            acabadoLateral1: asiento.acabadoLateral1
            acabadoLateral2: asiento.acabadoLateral2
            acabadoSuperior: asiento.acabadoSuperior
            // Dorado solo cuando de verdad es tu turno — antes era
            // dorado siempre, así que "activo" no se distinguía de un
            // asiento cualquiera más que por el aro del tiempo.
            colorBorde: activo ? Tema.colorAccent : Tema.colorBorde
        }

        Rectangle {
            visible: asiento.allIn
            anchors.centerIn: parent
            width: parent.width + 8
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 3 * Tema.escala
            border.color: Tema.colorAccent
            z: 5
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: asiento.allIn && asiento.animando
                NumberAnimation { to: 0.35; duration: 650 / Math.max(0.05, asiento.velocidad); easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 650 / Math.max(0.05, asiento.velocidad); easing.type: Easing.InOutSine }
            }
        }
        Rectangle {
            id: discoApagado
            visible: opacity > 0
            opacity: asiento.eliminado ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 450 } }
            anchors.centerIn: parent
            width: parent.width - 2
            height: width
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.68)
            z: 6
            scale: asiento.eliminado ? 1 : 1.25
            Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutBounce } }
            Text {
                anchors.centerIn: parent
                text: "✕"
                color: Qt.rgba(1, 1, 1, 0.75)
                font.pixelSize: parent.width * 0.5
            }
        }

        // Marcadores de dealer/ciegas -- esquina superior derecha del
        // avatar, un poco montados sobre el borde (mismo sitio que usa
        // cualquier app de póker para el botón de dealer). En un Row para
        // que quepan los dos a la vez en heads-up (dealer = SB). El disco
        // de dealer reutiliza colorAccent (mismo "esto importa" que ya usan
        // el aro de turno y los botones); la píldora de ciega es
        // deliberadamente más discreta -- SB/BB es información de apoyo,
        // no debe competir visualmente con de quién es el turno.
        Row {
            visible: esDealer || esSb || esBb
            // Con el avatar reducido (showdown) los marcadores ocuparían casi todo el avatar y
            // taparían sus decoraciones: se apartan hacia abajo a la derecha (esa esquina no
            // lleva decoraciones: los laterales están a los lados y la superior arriba) y se
            // hacen un poco más pequeños, así se ven el avatar y los marcadores.
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: (asiento.modoMuestra ? -20 : -2) * Tema.escala
            anchors.topMargin: asiento.modoMuestra ? parent.height * 0.55 : -2 * Tema.escala
            Behavior on anchors.rightMargin { NumberAnimation { duration: 450 / Math.max(0.05, asiento.velocidad) } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 450 / Math.max(0.05, asiento.velocidad) } }
            scale: asiento.modoMuestra ? 0.8 : 1
            transformOrigin: Item.TopLeft
            Behavior on scale { NumberAnimation { duration: 450 / Math.max(0.05, asiento.velocidad) } }
            spacing: 2 * Tema.escala
            z: 10

            Rectangle {
                id: discoDealer
                visible: esDealer
                width: 20 * Tema.escala
                height: 20 * Tema.escala
                radius: width / 2
                color: Tema.colorAccent
                border.width: 1.5
                border.color: Tema.colorFondo
                Text {
                    anchors.centerIn: parent
                    text: "D"
                    font.bold: true
                    font.pixelSize: 11 * Tema.escala
                    font.family: Tema.fuenteElegante
                    color: Tema.colorFondo
                }
            }
            Rectangle {
                id: pildoraCiega
                visible: esSb || esBb
                width: textoCiega.implicitWidth + 8 * Tema.escala
                height: 18 * Tema.escala
                radius: height / 2
                color: Tema.colorPanel
                border.width: 1
                border.color: Tema.colorBorde
                Text {
                    id: textoCiega
                    anchors.centerIn: parent
                    text: esSb ? "SB" : "BB"
                    font.bold: true
                    font.pixelSize: 9 * Tema.escala
                    font.family: Tema.fuenteElegante
                    // colorAccent, no colorTextoTenue -- el tenue se leía
                    // mal sobre el fondo oscuro de la píldora (confirmado
                    // con una captura real). El tamaño/forma ya la
                    // distingue del disco de dealer sin necesidad de
                    // sacrificar legibilidad con un color de bajo contraste.
                    color: Tema.colorAccent
                }
            }
        }
    }
    // Placa de nombre/saldo + mini-cartas de mesa, YA JUNTAS al lado del
    // nombre (rediseño 2026-09-17, pedido explícito: "colocalas a un lado
    // del nombre del avatar" -- antes iban en una fila propia debajo de
    // toda la silla). Un Item con anchors a mano en vez de un Row: dentro
    // de un positioner (Row/Column) los hijos no admiten anchors propios,
    // y aquí la placa y el abanico necesitan alinearse por su centro
    // vertical, no solo colocarse uno detrás del otro.
    Item {
        id: filaNombreYCartas
        x: (parent.width - width) / 2
        readonly property real espacioCartas: 4 * Tema.escala
        readonly property bool mostrarCartas: asiento.modoMuestra || esPropio || !retirado
        width: placaNombre.width + (mostrarCartas ? espacioCartas + (asiento.usaPropias ? propias.width : abanico.width) : 0)
        height: Math.max(placaNombre.height, mostrarCartas ? (asiento.usaPropias ? propias.height : abanico.height) : 0)

        Rectangle {
            id: placaNombre
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: Tema.colorPanel
            opacity: 0.70 * asiento.atenuacionPropia
            border.width: 2
            border.color: asiento.modoMuestra && asiento.muestra.ganador ? Tema.colorAccent : Tema.colorBorde
            width: infoAsiento.width * 1.2
            height: infoAsiento.height * 1.
            radius: width / 10
            Column {
                id: infoAsiento
                anchors.centerIn: parent
                Text {
                    text: nombre
                    color: Tema.colorTexto
                    font.pixelSize: 13 * Tema.escala
                    font.family: Tema.fuenteElegante
                }
                Row {
                    spacing: 3 * Tema.escala
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: saldo
                        color: Tema.colorAccent
                        font.bold: true
                        font.pixelSize: 13 * Tema.escala
                        font.family: Tema.fuenteElegante
                    }
                    IconoFicha {
                        width: 10 * Tema.escala
                        height: width
                        anchors.verticalCenter: parent.verticalCenter
                        colorFicha: Tema.colorAccent
                    }
                }
            }
        }

        // Abanico de mini-cartas de los rivales (boca abajo; en el showdown, sus cartas enseñadas).
        // Reutiliza la técnica de "coronaDeCartas" en Avatar.qml: cada carta gira sobre su propia
        // base (transformOrigin: Item.Bottom) con un ángulo centrado por índice. Se oculta del todo
        // al retirarse. En TU asiento solo sale en el showdown (fuera de él van las propias, abajo).
        Item {
            id: abanico
            visible: filaNombreYCartas.mostrarCartas && !asiento.usaPropias
            anchors.left: placaNombre.right
            anchors.leftMargin: filaNombreYCartas.espacioCartas
            anchors.verticalCenter: placaNombre.verticalCenter
            property real anchoCarta: (asiento.modoMuestra ? 38 : 24) * Tema.escala
            property real altoCarta: (asiento.modoMuestra ? 52 : 32) * Tema.escala
            property real pasoAngulo: asiento.modoMuestra ? 5 : 24
            property real solapeX: (asiento.modoMuestra ? 30 : 10) * Tema.escala
            Behavior on anchoCarta { NumberAnimation { duration: 450 / Math.max(0.05, asiento.velocidad); easing.type: Easing.InOutCubic } }
            Behavior on altoCarta { NumberAnimation { duration: 450 / Math.max(0.05, asiento.velocidad); easing.type: Easing.InOutCubic } }
            Behavior on pasoAngulo { NumberAnimation { duration: 450 / Math.max(0.05, asiento.velocidad) } }
            Behavior on solapeX { NumberAnimation { duration: 450 / Math.max(0.05, asiento.velocidad); easing.type: Easing.InOutCubic } }
            width: anchoCarta + solapeX
            height: altoCarta * 1.15

            Repeater {
                model: 2
                delegate: Carta {
                    id: cartaAbanico
                    required property int index
                    // La cara solo se ve tras el volteo (Rotation por el eje Y, como las
                    // comunitarias): boca abajo -> canto -> cara.
                    property string mostrado: ""
                    readonly property string objetivo: asiento.reveladaMuestra ? (asiento.muestra.cartas[index] || "") : ""
                    // El modelo de jugadores se reconstruye en cada GAME_STATE, así que este asiento
                    // puede nacer con la mano ya revelada: se ve directamente, sin volteo. "listo": los
                    // valores iniciales de los bindings también disparan onObjetivoChanged y, sin él, la
                    // mano se volteaba de nuevo con cada actualización de la mesa.
                    property bool listo: false
                    Component.onCompleted: { mostrado = objetivo; listo = true; }
                    onObjetivoChanged: {
                        if (!listo) return;
                        if (objetivo !== "" && objetivo === mostrado) return;
                        if (objetivo !== "") volteoMuestra.restart();
                        else { volteoMuestra.stop(); giroMuestra.angle = 0; mostrado = ""; }
                    }
                    codigo: mostrado
                    // Cara con degradado blanco -> gris claro: las dos del abanico se solapan y, blanco
                    // sobre blanco, se fundían. La de atrás (index 0) va un tono más gris.
                    degradadoCara: true
                    tonoCara: index
                    width: abanico.anchoCarta
                    height: abanico.altoCarta
                    reversoSkin: asiento.reversoActivo
                    visible: index < asiento.cartasVisibles
                    // Solo se resaltan las cartas de la mano ganadora (aro dorado, abajo); las
                    // demás no se atenúan.
                    transformOrigin: Item.Bottom
                    rotation: (index - 0.5) * abanico.pasoAngulo
                    x: abanico.width / 2 - width / 2 + (index - 0.5) * abanico.solapeX
                    y: abanico.height - height
                    z: asiento.modoMuestra && asiento.resaltadas.indexOf(mostrado) >= 0 ? 2 + index : index
                    transform: Rotation {
                        id: giroMuestra
                        origin.x: cartaAbanico.width / 2
                        origin.y: cartaAbanico.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: 0
                    }
                    SequentialAnimation {
                        id: volteoMuestra
                        PauseAnimation { duration: cartaAbanico.index * 140 / Math.max(0.05, asiento.velocidad) }
                        NumberAnimation { target: giroMuestra; property: "angle"; to: 90; duration: 130 / Math.max(0.05, asiento.velocidad); easing.type: Easing.InQuad }
                        ScriptAction { script: cartaAbanico.mostrado = cartaAbanico.objetivo }
                        NumberAnimation { target: giroMuestra; property: "angle"; to: 0; duration: 130 / Math.max(0.05, asiento.velocidad); easing.type: Easing.OutQuad }
                    }
                    // Cartas de la mano ganadora: filo dorado + halo que late (BrilloCarta.qml).
                    BrilloCarta {
                        anchors.fill: parent
                        radio: parent.radius
                        escalaHalo: 0.6
                        filo: 2
                        animando: asiento.animando
                        velocidad: asiento.velocidad
                        visible: asiento.modoMuestra && asiento.resaltadas.indexOf(cartaAbanico.mostrado) >= 0
                    }
                }
            }
        }

        // TUS cartas: rectas y lado a lado, más grandes que las mini-cartas de los rivales (en móvil
        // son la única vista de tu mano). Nacen boca abajo cuando aterrizan (cartasVisibles) y se
        // voltean, escalonadas; sin animar salen ya de cara. No se van al retirarte.
        Item {
            id: propias
            visible: filaNombreYCartas.mostrarCartas && asiento.usaPropias
            anchors.left: placaNombre.right
            anchors.leftMargin: filaNombreYCartas.espacioCartas
            anchors.verticalCenter: placaNombre.verticalCenter
            readonly property real anchoCarta: 36 * Tema.escala
            readonly property real altoCarta: 50 * Tema.escala
            readonly property real separacion: 4 * Tema.escala
            width: 2 * anchoCarta + separacion
            height: altoCarta
            Repeater {
                model: 2
                delegate: Carta {
                    id: cartaPropia
                    required property int index
                    // Solo el asiento propio usa estas cartas (en los demás están ocultas): sin trabajo en balde.
                    readonly property string objetivo: asiento.esPropio && index < asiento.cartasVisibles
                                                       ? (index === 0 ? asiento.miCarta1 : asiento.miCarta2) : ""
                    property string mostrado: ""
                    // El modelo de jugadores se reconstruye en cada GAME_STATE: el asiento puede nacer
                    // con la mano ya repartida, y entonces se ve directamente, sin volteo. Los valores
                    // iniciales de los bindings también disparan onObjetivoChanged: sin "listo" la carta
                    // se volteaba de nuevo con CADA acción de la partida (reportado 2026-09-20).
                    property bool listo: false
                    Component.onCompleted: { mostrado = objetivo; listo = true; }
                    onObjetivoChanged: {
                        if (!listo) return;
                        if (objetivo !== "" && objetivo !== mostrado && asiento.animando) volteoPropia.restart();
                        else { volteoPropia.stop(); giroPropia.angle = 0; mostrado = objetivo; }
                    }
                    codigo: mostrado
                    propia: true
                    reversoSkin: asiento.miReversoSkin
                    width: propias.anchoCarta
                    height: propias.altoCarta
                    x: index * (propias.anchoCarta + propias.separacion)
                    visible: index < asiento.cartasVisibles
                    transform: Rotation {
                        id: giroPropia
                        origin.x: cartaPropia.width / 2
                        origin.y: cartaPropia.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: 0
                    }
                    SequentialAnimation {
                        id: volteoPropia
                        PauseAnimation { duration: (160 + cartaPropia.index * 140) / Math.max(0.05, asiento.velocidad) }
                        NumberAnimation { target: giroPropia; property: "angle"; to: 90; duration: 130 / Math.max(0.05, asiento.velocidad); easing.type: Easing.InQuad }
                        ScriptAction { script: cartaPropia.mostrado = cartaPropia.objetivo }
                        NumberAnimation { target: giroPropia; property: "angle"; to: 0; duration: 130 / Math.max(0.05, asiento.velocidad); easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }

    // Nombre de la combinación bajo las cartas reveladas.
    Text {
        visible: asiento.modoMuestra && asiento.muestra.combo !== ""
        x: (parent.width - width) / 2
        text: asiento.modoMuestra ? asiento.muestra.combo : ""
        color: asiento.modoMuestra && asiento.muestra.ganador ? Tema.colorAccent : Tema.colorTextoTenue
        font.bold: asiento.modoMuestra && asiento.muestra.ganador
        font.pixelSize: 12 * Tema.escala
        font.family: Tema.fuenteElegante
    }
}
