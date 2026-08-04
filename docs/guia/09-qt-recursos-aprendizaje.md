# Guía 9 — Dónde seguir aprendiendo Qt

Lo de las guías 6-7 es lo mínimo para entender qué está pasando en el
andamiaje que ya existe (Qt Quick/QML). Para ir más allá (Model/View en QML,
`QSettings`, internacionalización...) estos son los recursos que merecen la
pena, de más a menos oficiales.

---

## 1. Documentación oficial — tu primera parada siempre

**https://doc.qt.io/**

Es, sin exagerar, de la mejor documentación de cualquier framework de C++.
Cada página de tipo QML tiene: propiedades, señales, ejemplo de código, y
enlaces a los tipos relacionados. Páginas concretas que te van a servir
pronto:

- `Qt Quick` (página conceptual) — visión general del módulo
- `ApplicationWindow`, `Item`, `Rectangle` — los tipos base de cualquier UI Quick
- `Qt Quick Layouts` y `Positioners` (Row/Column/Grid) — las tres formas de
  posicionar de la guía 7
- `States, Transitions and Animations in Qt Quick` (página conceptual) — la
  explican mejor que cualquier tutorial de fuera
- `QTcpSocket` — para cuando construyas `NetworkClient`
- `Qt QML` → "Exposing Attributes of C++ Types to QML" — el puente C++↔QML
  de la guía 7, sección 7

Truco: casi toda instalación de Qt trae la documentación offline. Si tienes
Qt Creator instalado, `Ayuda` → puedes buscarla sin conexión.

---

## 2. Ejemplos incluidos con la instalación

Qt se instala con **decenas de proyectos de ejemplo completos y
compilables**, no fragmentos sueltos. Búscalos en tu sistema (con Qt6 de
Arch suelen estar bajo algo como `/usr/share/doc/qt6/examples` o accesibles
desde Qt Creator en `Bienvenida → Ejemplos`, buscando "quick" o "qml"). Los
más relevantes para este proyecto:

- Ejemplo de **Fortune Client/Server** (a veces listado como "Fortune
  Client") — un cliente/servidor con `QTcpSocket` prácticamente calcado al
  problema que tienes que resolver en `NetworkClient`. Está escrito con
  Widgets, pero la parte de red (lo que importa) es idéntica en Quick.
- Categoría **Qt Quick Examples → Animation** — states, transitions,
  `Behavior`, todo lo de la guía 7 sección 6 en proyectos reales.
- Categoría **Qt Quick Controls → Gallery** — todos los controles táctiles
  disponibles (`Button`, `Slider`, `Dial`...) en una sola app navegable.
- Ejemplo **"Same Game"** o cualquiera bajo **Qt Quick Examples → Scene
  Graph** — dibujo/animación de elementos tipo "ficha" moviéndose por la
  pantalla, cercano a lo que necesitarás para cartas/fichas.

Si tienes Qt Creator instalado (viene con `qt6-base` normalmente como
paquete aparte, `qtcreator` en Arch), es la forma más rápida de encontrarlos
y ejecutarlos con un clic — y con Quick además tienes vista previa en vivo
del `.qml` mientras lo editas, sin recompilar (sección 5).

---

## 3. Libro de referencia

**"C++ GUI Programming with Qt"** (Blanchette & Summerfield) — el libro
"clásico" de Qt, pero centrado en Widgets, no en Quick/QML — la sintaxis del
lenguaje QML en sí no está ahí. Sigue siendo útil para los conceptos de
fondo compartidos (señales/slots, event loop, moc), pero para QML
específicamente la documentación oficial (sección 1) es mejor punto de
partida que cualquier libro: el lenguaje ha evolucionado mucho entre
versiones y los libros quedan desactualizados rápido en esa parte concreta.

---

## 4. Vídeo / cursos

No te voy a inventar un enlace concreto a un vídeo que no puedo verificar que
siga existiendo — mejor te doy nombres para que busques tú y elijas el que
mejor te encaje:

- **Canal de YouTube "VoidRealms"** — además de su serie de Widgets, tiene
  una serie específica de **QML/Qt Quick**. Busca "VoidRealms QML tutorial"
  o "VoidRealms Qt Quick".
- **Canal oficial de Qt** (la propia empresa "Qt Group") en YouTube — charlas
  de conferencias (Qt World Summit) con demos de Qt Quick en móvil y
  embedded, que es exactamente el caso de uso que te interesa. Más para
  inspirarte con lo que se puede hacer que para aprender paso a paso.
- **Qt Academy** (`qt.io` tiene una sección de formación oficial, "Qt
  Academy") — tiene una ruta específica de aprendizaje para Qt Quick/QML,
  no solo Widgets.

Si alguno de estos ya no existe o cambió de nombre cuando lo busques, no pasa
nada — el propósito es darte términos de búsqueda con los que vas a encontrar
contenido actualizado, no atarte a un enlace que puede quedar roto.

---

## 5. Qt Creator, el IDE oficial

No es obligatorio (este proyecto se compila con CMake a mano, como todo lo
demás), pero para QML específicamente tiene una ventaja mucho más grande que
para Widgets: el **preview en vivo** de un `.qml` — lo editas y ves el
resultado sin recompilar ni reiniciar la app, porque QML se interpreta. Muy
útil mientras aprendes la sintaxis y ajustas posiciones/animaciones a ojo.

También existe **Qt Design Studio**, una herramienta hermana pensada
específicamente para diseñar interfaces Quick de forma visual (más orientada
a diseñadores que a programadores) — opcional, probablemente no la
necesites viniendo de C++, pero existe si en algún momento quieres iterar el
diseño visual sin tocar código.

---

## 6. Cuando te atasques con algo muy específico del proyecto

Vuelve a `10-migracion-qt.md` — ahí está el mapeo concreto de qué parte del
código actual (ncurses/sockets) corresponde a qué parte nueva (Qt Quick),
con el razonamiento de cada decisión que ya se tomó, incluido por qué se
eligió Quick sobre Widgets.
