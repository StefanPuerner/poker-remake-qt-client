# Guía 10 — La migración a Qt, en detalle

Esta guía sí es del proyecto (a diferencia de 6-9, que son fundamentos
generales de Qt). Documenta exactamente qué se construyó ya en la rama
`variante-Qt`, por qué se hizo así, y qué queda por hacer con el nivel de
detalle suficiente para no tener que releer todo el hilo de chat donde se
decidió. Si no has leído 06-09 todavía, hazlo antes — aquí se asume que ya
sabes qué es una señal, un slot, `QTcpSocket`, y algo de QML.

---

## 1. Por qué Qt Quick y no Qt Widgets

La decisión inicial fue Widgets (más parecido al C++ imperativo que ya
conocías de ncurses), pero se cambió a **Qt Quick/QML** por una razón
concreta: hay intención real de llevar esta interfaz a móvil con controles
táctiles más adelante, y Widgets no está pensado para tacto — Quick sí, de
fábrica (animaciones fluidas, controles dimensionados para dedo, aceleración
por GPU). El coste es aprender QML además de C++, pero evita tener que
rehacer toda la capa visual el día que el móvil deje de ser "una idea" y se
vuelva concreto.

---

## 2. Lo que ya existe

```
src/client-qt/main.cpp          — arranque: QGuiApplication + QQmlApplicationEngine
src/client-qt/qml/Main.qml      — ventana raíz (placeholder de momento)
```

Target `PokerClientQt` en `CMakeLists.txt`, condicionado a que Qt6 Quick
esté instalado:

```cmake
find_package(Qt6 COMPONENTS Quick QuickControls2 QUIET)
if(Qt6_FOUND AND TARGET Qt6::Quick)
    qt_policy(SET QTP0001 NEW)
    qt_policy(SET QTP0004 NEW)

    qt_add_executable(PokerClientQt
        src/client-qt/main.cpp
    )
    set_target_properties(PokerClientQt PROPERTIES AUTOMOC ON)
    qt_add_qml_module(PokerClientQt
        URI PokerQuick
        VERSION 1.0
        QML_FILES
            src/client-qt/qml/Main.qml
    )
    target_link_libraries(PokerClientQt PRIVATE Qt6::Quick Qt6::QuickControls2)
endif()
```

**Por qué `QUIET` + `if`, y no obligatorio**: los scripts de cross-compilación
(`scripts/build-arm64.sh`, `build-termux.sh`) usan imágenes Docker de Ubuntu
mínimas sin Qt instalado. Con este patrón, si Qt6 Quick no está, el mensaje
de CMake lo dice claramente y el resto de targets compilan igual.

`Main.qml` es deliberadamente un placeholder — el objetivo de este andamiaje
era demostrar que la cadena de compilación completa (CMake → `qt_add_qml_module`
→ moc/registro de metatipos → `rcc` empaquetando el QML → enlazado) funciona
de principio a fin antes de construir nada real encima. Verificado además en
tiempo de ejecución con `QT_QPA_PLATFORM=offscreen ./PokerClientQt` (arranca
y corre el event loop sin errores, sin necesitar una pantalla real).

---

## 3. Tres gotchas que ya se resolvieron (y por qué)

Si tocas el `CMakeLists.txt` de `PokerClientQt` y te vuelve a salir alguno de
estos errores, aquí está la causa exacta.

### 3.1 — `qt_add_qml_module` exige AUTOMOC

```
Metatype generation requires either the use of AUTOMOC or a manual list of
generated json files
```

`qt_add_qml_module` necesita generar metainformación de tipos QML (qué
propiedades/señales expone cada tipo) incluso antes de que exista ninguna
clase C++ con `Q_OBJECT` propia — ese registro de metatipos depende del
mismo mecanismo de moc que activa AUTOMOC (guía 6, sección 3). Se resuelve
con `set_target_properties(PokerClientQt PROPERTIES AUTOMOC ON)`, scoped
solo a este target para no afectar a `PokerRemake`/`PokerServer`/etc.

### 3.2 — Aviso de políticas QTP0001 / QTP0004

Avisos, no errores: `qt_add_qml_module` pregunta si quieres el
comportamiento "nuevo" (recomendado) para el prefijo de recursos del módulo
QML (QTP0001) y para no exigir un `qmldir` manual por subcarpeta (QTP0004).
Se silencian aceptándolos explícitamente:

```cmake
qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)
```

### 3.3 — "no se puede abrir el fichero de salida PokerClientQt: Es un directorio"

Este es el más confuso la primera vez. Causa: `qt_add_qml_module(... URI
PokerClientQt ...)` crea una carpeta con el nombre del URI dentro del
directorio de build (para los ficheros generados del módulo QML) — y este
proyecto pone **todos** los ejecutables directamente en la raíz de ese mismo
directorio de build (`CMAKE_RUNTIME_OUTPUT_DIRECTORY`, fijado al principio
del `CMakeLists.txt` para que `PokerRemake`/`PokerServer`/etc. no queden
enterrados en subcarpetas). Si el URI del módulo coincide con el nombre del
target, ambos quieren el mismo nombre en el mismo sitio: la carpeta del
módulo gana la carrera, y el enlazador falla al intentar escribir el
ejecutable encima de una carpeta.

**Solución**: URI distinto del nombre del target — por eso el target se
llama `PokerClientQt` pero el URI del módulo es `PokerQuick`. Si renombras
uno de los dos, no hace falta que coincidan; de hecho, mejor que nunca
coincidan.

---

## 4. Mapa de reutilización, con código real

### Se reutiliza tal cual, sin tocar una línea

**`include/net/Protocol.hpp`** — el framing (4 bytes + JSON) y los builders:

```cpp
net::Message msg = net::buildMsg(net::MsgType::ACTION,
                                 {{"accion", "RAISE"}, {"cantidad", "200"}});
std::string accion = net::jsonGetStr(msg.payload, "accion");
```

Esto es C++ puro, sin ningún tipo de Qt ni QML de por medio — se incluye
igual desde `NetworkClient`.

**`PokerServer` entero** — cero cambios, ni recompilar hace falta. El
protocolo por el cable es el mismo, así que el mismo servidor sirve a
clientes ncurses y Qt Quick a la vez, incluso en la misma partida.

**La lógica de parseo de payloads** — funciones como las de
`src/ui/PokerUI.cpp` (`parseCartas`, `parseJugadores`) no tocan ncurses en
ningún momento, son puro procesamiento de strings. Se pueden mover a
`NetworkClient` o a una clase de estado intermedia sin reescribir la lógica.

### Se reescribe

| Pieza actual | Por qué no vale tal cual |
|---|---|
| `PokerUI` completo (2258 líneas) | Todo el dibujo está en primitivas ncurses (`mvwaddstr`, `wattr_set`...) |
| El `poll()` manual de `client/main.cpp` | Qt ya multiplexa red+teclado/tacto dentro de su propio event loop (guía 8) |
| `askAction()` / `askVoto()` (bloquean) | Ni Widgets ni Quick bloquean nunca esperando input — se pasa a señales/slots expuestas a QML (sección 6) |
| Sockets crudos (`SocketClient`) | Se sustituyen por `QTcpSocket` (guía 8) — el protocolo por encima no cambia |

---

## 5. `NetworkClient` — la pieza nueva central

Sigue siendo C++ puro (no depende de si la UI es Widgets o Quick — esa es
precisamente la ventaja de mantener la red separada de la presentación, el
mismo patrón Observer que ya usa el motor de juego). Ver guía 8, sección 3,
para el esqueleto completo con el buffer de framing.

Lo que sí cambia respecto al plan original con Widgets es **cómo se conecta
con la UI**: en vez de `connect()` de C++ a C++, se expone como propiedad de
contexto para que QML la use directamente (guía 7, sección 7):

```cpp
// main.cpp
QQmlApplicationEngine engine;
NetworkClient cliente;
engine.rootContext()->setContextProperty("redCliente", &cliente);
engine.loadFromModule("PokerQuick", "Main");
```

```qml
// Main.qml
Connections {
    target: redCliente
    function onTurnoRecibido(payload) { /* mostrar panel de turno */ }
    function onEstadoRecibido(payload) { /* actualizar la mesa */ }
}
```

---

## 6. El cambio de fondo: el turno, de bloqueante a basado en estado

Esto es lo más delicado de toda la migración, así que merece verse en
paralelo, antes/después. El razonamiento es idéntico se use Widgets o
Quick — solo cambia la sintaxis del lado de la UI.

### Antes (`include/ui/PokerUI.hpp` + `src/client/main.cpp`)

```cpp
// client/main.cpp — game loop
case net::MsgType::TU_TURNO: {
    nodelay(stdscr, FALSE);
    net::Message accion = ui.askAction(msg.payload);  // ← BLOQUEA aquí
    nodelay(stdscr, TRUE);
    net::sendMsg(fd, accion);
    break;
}
```

### Después (Qt Quick) — como estado + señal

```cpp
// NetworkClient — parte C++
signals:
  void turnoRecibido(QString payload);
```

```qml
// Main.qml — conectado una vez, al cargar
Connections {
    target: redCliente
    function onTurnoRecibido(payload) {
        panelTurno.mostrarTurno(payload)   // rellena opciones, hace visible el panel
    }
}

// El panel de turno emite su propia señal QML al pulsar un botón:
Button {
    text: "Retirarse"
    onClicked: redCliente.enviarAccion("FOLD", 0)
}
```

Nada bloquea. `mostrarTurno()` parsea el payload y actualiza propiedades QML
(cartas, bote, qué botones están habilitados) y vuelve inmediatamente. El
resto de la app (chat, animaciones, el timer visual) sigue funcionando con
total normalidad mientras tanto — cosa que con `askAction()` bloqueando no
pasaba.

**El timer de turno**: en vez del `steady_clock` dentro del bucle de
`wgetch`, un `Timer` de QML (`import QtQml; Timer { interval: 1000; repeat:
true; onTriggered: segundosRestantes-- }`) actualizando una propiedad, con
una `ProgressBar` o un `Rectangle` cuyo `width` esté bindeado a esa
propiedad — la barra se anima sola sin código de dibujo manual.

---

## 7. Reconexión: nada de `sleep()`

Igual que con Widgets — el detalle está en la guía 8, sección 6. Un
`QTimer::singleShot` (o su equivalente QML `Timer` con `running: true`)
reintenta sin bloquear el event loop. `sleep()` en cualquier slot conectado
a una señal Qt congela toda la interfaz — no hay animación de "reconectando"
que valga si el hilo está dormido.

---

## 8. El voto de fin de mano (`askVoto`)

Mismo patrón que el turno (sección 6): hoy `askVoto()` tiene su propio bucle
`poll()`+`wgetch` interno para poder chatear MIENTRAS se espera el voto de
todos (guía 2, sección 5). En Quick no hace falta ningún truco especial —
el chat y el panel de voto son dos componentes QML normales, cada uno
reaccionando a sus propias señales de `NetworkClient` de forma
independiente. La "simultaneidad" que en ncurses requería un `poll()` con
dos fds a mano es, con Qt, simplemente cómo funciona siempre el event loop.

---

## 9. Orden de implementación sugerido

1. **Mockup estático, sin red.** Un `Main.qml` con la mesa, los asientos y
   el panel de acción, con datos escritos a mano (sin `NetworkClient`
   todavía). Verificas layout, anchors y dibujo antes de complicarte con
   async.
2. **`NetworkClient` con datos reales**, expuesto como propiedad de
   contexto, conectado a un `PokerServer` de verdad. Reutiliza
   `Protocol.hpp` sin cambios (sección 4).
3. **El turno como estado** (sección 6) — la pieza conceptualmente más
   distinta a lo que ya conoces.
4. **Chat, historial, lobby** — mecánico una vez el patrón de la sección
   6/8 está asentado; son la misma idea repetida.
5. **Reconexión con `Timer`** (sección 7) — fácil de dejar para el final
   porque no bloquea nada mientras no lo implementes.
6. **Los extras que solo Quick permite** — perfiles de rivales en vivo (los
   datos de `PerfilJugador` en `Bot.hpp` ya existen, ver
   `05-benchmark-ia.md` para cómo se calculan), transiciones de estado para
   cartas/fichas, sonido, y finalmente el propio empaquetado táctil/móvil
   que motivó elegir Quick desde el principio.

---

## Preguntas de comprensión

1. Si el URI de un módulo QML coincide con el nombre del ejecutable, ¿qué
   error concreto da el enlazador, y por qué?
2. ¿Por qué `qt_add_qml_module` necesita AUTOMOC incluso en un proyecto que
   todavía no tiene ninguna clase con `Q_OBJECT`?
3. ¿Por qué `PokerServer` no necesita ningún cambio para que
   `PokerClientQt` funcione, sea Widgets o Quick?
4. ¿Qué widget/componente reemplaza al bucle `poll()` de dos fds de
   `askVoto()` para conseguir la misma simultaneidad chat+voto?
5. Si mañana añades una clase `NetworkClient` con `Q_OBJECT` y el enlazado
   vuelve a fallar con "vtable sin definir" (el mismo síntoma que en la
   versión Widgets de este andamiaje), ¿qué es lo primero que revisas?
