# PokerRemake v0.12.0

> **Esta versión necesita el servidor actualizado** (reclamar logros, avisos de
> solicitudes y el blindaje de la reconexión viven en él). Con un servidor
> antiguo lo demás sigue funcionando, pero los logros nuevos no se podrán
> reclamar.

## Bots: overhaul completo
- **Juegan bien con o sin subida mínima y con cualquier tipo de límite**
  (No-Limit, Pot-Limit, Fixed-Limit). Antes se retiraban ante casi cualquier
  apuesta pequeña (apostarles 1 ficha o el mínimo funcionaba siempre) y tratan
  igual una subida mínima que un all-in. Ahora leen el **tamaño** de la apuesta
  respecto al bote.
- **Las tres dificultades se notan de verdad**: FACIL paga de más y se le nota la
  mano; NORMAL juega ajustado y con criterio; EXPERTO mezcla faroles y valor, varía
  los tamaños y se adapta a cada rival. Cara a cara, NORMAL y EXPERTO ganan
  claramente a FACIL, y el nuevo motor gana al anterior en las tres.
- Preflop con rangos de apertura según posición y jugadores, defensa según el
  tamaño de la subida y re-subidas.

## Torneos Solitario y logros
- **Los logros se reclaman a mano**: al conseguirlo ves un punto de aviso en
  **Cuenta** (y en la pestaña Logros) y un botón **Reclamar** que concede el XP, el
  título y los objetos. Lo desbloqueado antes de esta versión ya está reclamado.
- Los retos guardan y **continúan** (botón Continuar) y cuentan como partida contra
  bots (XP, marco, logros y estadísticas).

## Social
- **Punto de aviso al recibir una solicitud de amistad**: sale en **Social** y en la
  pestaña **Solicitudes**, igual que los mensajes.

## Mesas y decoraciones
- **Las mesas se compran por tipo y el color se elige después**: en vez de un objeto por
  color, ahora compras la textura (Rombos, Palos, Puntos y las nuevas **Lino** y **Rayas**)
  y eliges cualquier color al equiparla (Verde, Granate, Azul, Grafito, Taberna, Porcelana,
  y los nuevos Violeta y Petróleo). Las de **madera** (Madera y Casino) traen 3 maderas:
  Roble, **Roble oscuro** y **Nogal**. Lo que ya tenías se convierte solo: conservas tu mesa
  con el mismo color y puedes elegir cualquier otro.
- **Decoraciones laterales**: al tocarlas se abre una ventana para elegir el lado
  (izquierda, derecha o **ambos**, con la misma decoración en los dos) y, si es de metal,
  el material.

## Interfaz
- **Los temas ya no ocupan media barra de Ajustes**: un botón abre una ventana
  flotante con todos, cada uno con sus colores.
- **La tienda va ordenada**: arriba lo que puedes comprar (por nivel y, dentro del
  nivel, por precio), luego lo que se consigue por logro, y abajo del todo lo que ya
  tienes.
- **"Confirmar all-in" se recuerda** entre sesiones (antes había que activarlo cada vez).
- La fecha de "mejor mano" del perfil ya se muestra corta (DD/MM/AA) y no se solapa con el texto.
- **Anillo de nivel/XP** siempre visible arriba a la izquierda en Cuenta (escritorio) y en la esquina izquierda del Perfil (móvil).

## Correcciones
- **Carta repetida en el showdown** (un 7 de picas en la mesa y en la mano de un
  bot): quien quedaba all-in al poner la ciega no recibía cartas nuevas y jugaba con
  las de la mano anterior. Arreglado.
- **El dealer saltaba a los bots** en partidas con personas: el botón se saltaba a
  quien se había retirado (los bots, sobre todo). Ahora avanza asiento a asiento.
- **Recompra**: dejaba de funcionar tras extender la partida (la petición se perdía
  durante la votación). **Quien recompra ya no puede ganar la partida.**
- **Contraseñas de letras y números**: en el móvil el teclado dejaba los últimos
  caracteres sin confirmar y una contraseña de 8 se leía de 7.
- **Reconexión, blindada**: latido de conexión para detectar una conexión medio
  muerta (móvil que cambia de red), el servidor acepta al jugador que vuelve aunque
  aún no hubiera notado la caída, le manda el estado completo de la mesa (ya no
  vuelves a un showdown viejo sin poder hacer nada) y la pantalla de conexión
  perdida ya no deja pulsar los botones de debajo.
