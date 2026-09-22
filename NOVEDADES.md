# PokerRemake v0.13.1 — versión EXPERIMENTAL

## Novedades de la 0.13.1
- **"Torneos" pasa a llamarse "Retos"** (icono nuevo) y suma dos apartados junto a la
  escalera de siempre:
  - **Reto diario**: cada día toca uno distinto de un grupo variado (mesas rápidas,
    cara a cara, mesas grandes...) — se destaca en la pantalla, se puede jugar sin
    conexión y se reclama una vez reconectado. Solo se puede jugar/reclamar el de
    ese día.
  - **Racha semanal**: un calendario de 7 días de conexión, con recompensa creciente
    y un título especial al completarlo.
- **Ajustes de sonido, reorganizados**: la lista de volumen + qué grupo de sonido
  suena o no ya no ocupa medio panel de Ajustes — ahora hay un botón que abre una
  ventana aparte, igual que ya pasaba con los temas de color.
- **Corregido: algunos controles de Ajustes (zoom de interfaz, interruptores) se
  recortaban por el lado derecho** en ciertos tamaños de pantalla/ventana.
- **Corregido: la tienda rechazaba comprar accesorios de marco a quien ya tenía el
  marco de Hierro** si esa victoria fue contra bots (o un reto sin conexión) en vez
  de una partida oficial — el mensaje además decía "gana tu primera partida", que
  llevaba a confusión. Ahora basta con tener el marco, sea cual sea el camino por el
  que se consiguió.

> ## ⚠️ Versión experimental: estate atento a los errores
> Esta versión cambia **mucho** de golpe: el showdown, las animaciones de la mesa, los
> sonidos y buena parte de la interfaz del móvil. Casi todo se ha probado con partidas
> automáticas y en pocos dispositivos reales, así que es probable que se cuele algún
> **error visual** (cartas mal colocadas, textos tapados, cosas que se solapan en tu
> pantalla) o de **sonido**. Si juegas con esta versión, **fíjate y cuéntanos lo que veas**:
> mejor con una **captura** y diciendo el móvil o el ordenador y en qué momento de la mano
> pasó. Cuantos más errores lleguen ahora, antes quedan arreglados.
>
> **Necesita el servidor actualizado.** Con un servidor antiguo la partida funciona, pero
> sin los avisos de all-in, el orden del showdown ni el temporizador opcional, y con
> pausas y reglas de heads-up de antes.

## El showdown se hace sobre la propia mesa
- **Ya no hay una ventana que tape la mesa**: las manos se enseñan en cada asiento. Primero
  se preparan todos a la vez y luego se **revelan de uno en uno, en orden de apuesta**, con
  la combinación escrita debajo de cada mano.
- **La mano ganadora se resalta** con un filo dorado y un halo que late (no se apagan las
  demás cartas).
- **Botes con detalle**: si hay side pots aparecen etiquetas compactas (*Principal*, *Side 1*…);
  al pulsar una ves quién entró, cuánto puso y quién lo ganó.
- **Mostrar cartas**: si te retiraste, o ganas sin que nadie llegue al showdown, puedes
  enseñar tu mano si quieres (no influye en el resultado).
- **Cintas de aviso** sobre las comunitarias: all-in, "¡Ganas!", "X gana" y eliminado.
- Si todos los que quedan están all-in, **se enseñan las manos antes de las calles que
  faltan**.

## Animaciones de la mesa
- **Las cartas se reparten** de una en una a cada asiento (y tus dos cartas se voltean al
  llegar); en el móvil salen del **dealer**, en el ordenador del mazo. Las comunitarias
  también vuelan a su sitio.
- **Fin de mano**: las cartas vuelven al mazo, los avatares recuperan su tamaño y los
  marcadores **D / SB / BB viajan** al asiento siguiente antes de empezar la mano nueva.
- **All-in**: aro dorado pulsante en el asiento, cinta y, si es grande, un pequeño temblor.
- **Regla real de heads-up**: con dos jugadores el dealer pone la ciega pequeña.
- Nuevo ajuste **Animaciones** (completas / reducidas / desactivadas). Con las
  desactivadas el modo local tampoco espera entre fases.

## Sonidos de la mesa
- Sonidos reales (Kenney, CC0): reparto, fichas, all-in, ganar, perder, eliminado, retirada,
  barajar… **Ajustes > Sonidos**: interruptor general (**apagado por defecto**), volumen y
  qué grupos quieres oír. Los sonidos se ajustan a lo que pasa (más fichas, más cartas…).
- Nuevo **aviso de "tu turno"** (una campana corta) y una **retirada más sutil**.
- En el móvil, cada evento es **una sola pista ya mezclada** (antes, con muchas pistas a la vez,
  Android dejaba sin sonar los más tardíos). En Ajustes > Sonidos hay un botón **Probar** y un
  contador de sonidos cargados: si no oyes nada, dinos qué número sale.

## Móvil
- **Tus cartas van en tu asiento**, más grandes, con volteo al llegar, y **se quedan cuando te
  retiras** (la estimación de combinaciones sigue). Los rivales que se retiran devuelven las suyas.
- **Cajón de la partida rehecho**: sin la pestaña *Cartas* y más estrecho (la **mesa gana
  ancho**); las decisiones de fin de mano (continuar, abandonar, guardar, mostrar cartas)
  salen en la pestaña *Turno*; **historial y chat con el estilo nuevo**; al empezar tu turno
  salta solo a *Turno*.
- El centro de la mesa se **recoloca en el showdown** para que la combinación del ganador no
  quede tapada por las comunitarias ni por tu avatar.

## Partidas
- **Temporizador entre manos opcional**: al crear una sala online puedes desactivarlo; entonces
  la mesa espera a que voten todos los que siguen conectados. Con él activado, cuenta atrás
  visible (60 s) y la partida sigue sola si nadie vota.

## Correcciones
- **Las cartas propias giraban con cada acción** en el móvil. Arreglado.
- Un jugador retirado ya no vuelve a mostrar el aro de turno y el reloj tras retirarse.
- **Contraseña en el móvil**: el teclado dejaba caracteres sin confirmar y solo se dibujaban 6-7
  puntos aunque la contraseña fuese más larga.
- El **ranking** debería abrirse ya desde el podio (el scroll iba a un punto equivocado); si no, avísanos.
- La reconexión ya no se dispara por error cuando la propia aplicación se para un momento.

## Qué conviene mirar al probar
- El **centro de la mesa** con side pots y 6 o más jugadores, en pantallas pequeñas.
- **Sonido en el móvil**: ¿suenan todos los eventos? ¿algún corte o tirón?
- Que **nadie retirado** reciba turno ni apueste, y que ninguna carta se quede en un sitio raro
  al acabar la mano.
- La **conexión**: si se reconecta sola sin motivo, apunta cuándo (durante una animación, al
  bloquear el móvil…).
