# PokerRemake v0.11.0

## Novedades

### Animaciones en la mesa
- **Apuestas con fichas**: cuando alguien apuesta, salen fichas doradas de su
  avatar y vuelan hasta el bote. El número de fichas depende de cuánto se
  apuesta respecto a lo que hay en la mesa: un call pequeño sale con una
  ficha, un all-in con siete. El contador del bote sube cuando las fichas
  llegan.
- **Cobro del bote**: al cerrarse el showdown, las fichas van del bote al
  ganador (o a cada ganador, si se reparte).
- **Las cartas de la mesa se dan la vuelta** al empezar la mano siguiente.
- Entre una mano y la siguiente hay ahora una pausa breve (1,3 s) para que
  todo esto se vea antes del preflop. Necesita que el servidor esté
  actualizado; con un servidor antiguo la pausa no existe y el cobro se
  solapa con la mano nueva.

## Servidor
- **Una partida ya no se queda colgada esperando un voto**: en las pantallas
  de entre manos, si alguien no responde en 60 s se continúa (y si no hay
  unanimidad para alargar la partida, termina en el límite).
- Un cliente que conecta y no dice nada ya no retrasa a los demás, y un
  cliente que deja de leer ya no bloquea la sala.
