# PokerRemake v0.11.1

## Novedades

### Torneos > Solitario
- **Los retos ya cuentan como una partida contra bots normal.** Sus manos
  suman XP, marco de Hierro y los logros de mano (Escalera de Color, Póker de
  Ases, La Corona, Trasnochador, El Farolero), y las combinaciones que
  muestras y tu mejor mano aparecen en Cuenta > Perfil. Antes, si jugabas un
  reto con la sesión conectada, no contaba nada. Se entrega al servidor en
  cuanto termina la partida (por victoria, abandono o guardado), sin esperar
  a la próxima vez que inicies sesión. Como invitado no se acumula nada.
  Sigue sin contar lo que exige otras cuentas reales en la mesa: Elo,
  partidas jugadas y ganadas, Tréboles por victoria y rachas.
- **Guardar y continuar un reto**: con "Guardar y salir" vuelves a la lista
  de retos, y su tarjeta pasa a mostrar **Continuar**. "Empezar de nuevo"
  descarta la partida guardada. Terminar el reto borra el guardado.
- **Los bots ya no se retiran casi siempre ante una apuesta pequeña.** Contra
  una apuesta mínima el bot se retiraba en unas 8 de cada 10 manos a lo
  largo de las tres calles (en el flop, ~45% de las veces); ahora defiende
  con una frecuencia acorde al tamaño de la apuesta, y sigue retirándose ante
  apuestas grandes con mano débil. Afecta a todos los bots de todas las
  dificultades.

## Correcciones
- Abandonar un reto ya no deja la partida siguiente "marcada" como reto: antes,
  una partida normal ganada después podía contar como reto superado.
- Servidor: los límites de XP y de "El Farolero" aceptados tras jugar en
  local eran demasiado justos para partidas largas contra bots y recortaban
  el XP; subidos.

## Nota
- Para que las estadísticas y logros de los retos se registren, el servidor
  tiene que estar actualizado. Con un servidor antiguo, todo lo demás
  funciona igual.
