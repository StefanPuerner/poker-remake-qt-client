# PokerRemake v0.10.0

## Novedades

### Mesa y cosméticos
- **Reversos de carta**: 5 diseños (Azul real, Esmeralda, Carmesí,
  Obsidiana y Taberna). En la mesa se ve el reverso del que reparte, o el
  tuyo si juegas solo contra bots. El dorso ocupa toda la carta, con las
  esquinas redondeadas como las del juego.
- **Tapetes de mesa**: 8 tapetes nuevos, con dibujos sobre el paño
  (rombos, palos, puntos), aro de madera y una madera de veta fina que gana
  densidad al agrandar la mesa. Los de color, a nivel 12; **Casino** (aro de
  madera con el paño de tu tema) y **Madera**, a nivel 14. Se compran en
  **Tienda > Mesa** y se equipan en **Personalizar > Mesa**, con vista
  previa como el resto de objetos.
- Por defecto ves el tapete del anfitrión; con uno equipado puedes elegir
  ver el tuyo desde Ajustes.
- **Tema nuevo "Taberna real"**: marrón y dorado.
- Las cartas de los rivales se ven ahora junto a su nombre, en abanico.

### Escritorio
- **Pantalla completa** con el atajo de cada sistema (F11 en Windows y
  Linux, Ctrl+Cmd+F en macOS) y un interruptor en Ajustes.

## Correcciones
- **Motor: una mano podía terminar sin que un jugador pudiera responder a
  un all-in** (uno pasa, otro va all-in, un tercero se retira: el primero
  se quedaba sin turno). Arreglado.
- **Las jugadas de los jugadores ahora se validan en el servidor**: ya no es
  posible pasar con una apuesta pendiente ni mandar importes ilegales.
- **Contraseñas formadas solo por números** (por ejemplo `12345678`) se
  rechazaban como demasiado cortas, y los mensajes de chat solo numéricos se
  perdían. Arreglado.
- **Reconexión**: si la partida ya no existe, vuelves a Inicio al instante
  con el motivo, en vez de esperar un minuto. El aviso se queda 20 s en
  pantalla.
- Servidor: detecta antes a los clientes que se han caído sin avisar y
  aguanta mejor las ráfagas de conexiones.
- Las tarjetas sin icono de Personalizar y Tienda ya no reservan un hueco
  vacío.
