# PokerRemake v0.14.0

## Novedades de la 0.14.0

### Cosméticos nuevos
- **Dos efectos de marco**: "Destello" (una chispa que da una vuelta rápida al anillo
  y se detiene) y "Onda" (un aro que crece y se desvanece, como un pin de sonar).
- **Dos reversos de carta**: "Porcelana dorada" y "Plata".
- **Elegir el palo** de las decoraciones "Mano Real" y "Escalera de Color" — antes
  siempre salían con el mismo palo fijo.
- **Borde de tapete independiente de la base**: el borde de madera ya se puede
  combinar con cualquier tapete, no solo con los que lo traían integrado.

### Logros
- **5 logros nuevos**: "Milenario" (1000 manos jugadas), "Racha invencible" (10 manos
  oficiales ganadas seguidas), "Racha de faroles" (10 manos ganadas sin showdown
  seguidas), y dos de humor por jugar "mal" — **"Cobarde detectado"** (retirarte 200
  veces) y **"Se fue por tabaco"** (abandonar 10 partidas).
- **Barra de progreso visible** en todos los logros que la tienen de verdad (antes
  varios de los nuevos aparecían como "Puntual" por error, sin más).

### Partida
- **Pulsa tus propias cartas** para ocultarlas o volver a mostrarlas — más directo
  que buscar el icono de ojo (que sigue ahí).
- **El Ranking ya enseña las decoraciones de cada jugador en toda la lista**, no solo
  en el podio — igual que ya pasaba en Social.

### Bot con IA (experimental)
- Nuevo interruptor en Crear Sala: **"Bots con IA"**. Si el servidor al que te
  conectas lo tiene configurado, los bots de esa sala deciden su jugada llamando a
  una IA externa en vez del motor de siempre — y si esa llamada falla o tarda
  demasiado, cae sola al motor local, la mano nunca se queda colgada.
- Contra un servidor que no lo soporte, el interruptor simplemente no hace nada.

## Correcciones
- **Kick a los pocos segundos de salir de una partida ya terminada.**
- **El reparto mostraba el reverso de carta equipado por ti**, no el que tocaba esa
  mano (el del jugador con el rol de dealer) — en los dos clientes.
- **Los empates no resaltaban a todos los ganadores**, solo al último en llegar (y
  lo mismo si alguien ganaba varios botes con combinaciones distintas en la misma
  mano).
- **Amigos que se veían "Desconectado" sin estarlo**: dos causas distintas — una al
  entrar en partida, otra con la sesión quieta en los menús un buen rato.

## Qué conviene mirar al probar
- Los 2 efectos y los 2 reversos nuevos son puramente estéticos — si algo no se ve
  bien en tu tema de color, dilo.
- Si usas el bot IA: el ritmo de las manos (la llamada añade un poco de espera) y si
  las jugadas que elige te parecen razonables.
