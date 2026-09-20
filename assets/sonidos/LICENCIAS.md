# Sonidos de la mesa: origen y licencias

Todos los sonidos de `mesa/` son de **Kenney** (https://kenney.nl), publicados bajo
**Creative Commons CC0 1.0** (dominio público): uso libre, también comercial, sin
obligación de atribución. Se cita igualmente por cortesía y trazabilidad.

| Pack (versión) | Ficheros usados |
|---|---|
| Casino Audio 1.1 | `card-*`, `chip-*`, `chips-*` |
| Impact Sounds | `impactWood_*` |
| Music Jingles | `jingles_*` |

Procesado aplicado a los originales (OGG): conversión a WAV mono 44,1 kHz 16 bit,
normalización a pico -3 dB (mismo volumen entre sí) y recorte del silencio final
(< -60 dB) con un fundido de 15 ms. Nada más: no se ha cambiado el carácter del sonido.

`eventos.json` es la mezcla elegida en el banco `AnimTest` (qué sonidos, cuántos golpes,
separación, azar y capas de cada evento del juego). Lo lee `BancoSonidos.qml`.

`mezclas/` y `mezclas.json` son DERIVADOS de `mesa/` + `eventos.json`: cada evento mezclado en un solo
WAV (mismas capas, golpes y azar) por `scripts/generar_mezclas_sonido.py`, para el móvil (una pista por
evento; ver `BancoMezclas.qml`). No añaden material nuevo: heredan la licencia CC0 de los originales.
Hay que regenerarlos (y commitearlos) cada vez que cambie `eventos.json` o un sonido de `mesa/`.

`turno.wav` (fuera de `mesa/`) es el aviso de "tu turno": `impactBell_heavy_003` de Kenney Impact Sounds
(CC0), recortado a la parte audible, con fundido de salida de 80 ms y normalizado a pico 0,55 (es un aviso, no un
efecto de mesa). Sustituyó (2026-09-20) a dos tonos sintetizados que sonaban a error.

## Ficheros de `mesa/`

* `card-place-2.wav` — Casino Audio (CC0)
* `card-place-3.wav` — Casino Audio (CC0)
* `card-slide-5.wav` — Casino Audio (CC0)
* `card-slide-6.wav` — Casino Audio (CC0)
* `chip-lay-1.wav` — Casino Audio (CC0)
* `chip-lay-3.wav` — Casino Audio (CC0)
* `chips-collide-3.wav` — Casino Audio (CC0)
* `chips-handle-4.wav` — Casino Audio (CC0)
* `chips-handle-6.wav` — Casino Audio (CC0)
* `chips-stack-2.wav` — Casino Audio (CC0)
* `chips-stack-3.wav` — Casino Audio (CC0)
* `impactWood_heavy_000.wav` — Impact Sounds (CC0)
* `impactWood_heavy_001.wav` — Impact Sounds (CC0)
* `impactWood_heavy_002.wav` — Impact Sounds (CC0)
* `impactWood_heavy_003.wav` — Impact Sounds (CC0)
* `jingles_HIT11.wav` — Music Jingles (CC0)
* `jingles_SAX03.wav` — Music Jingles (CC0)
* `jingles_SAX07.wav` — Music Jingles (CC0)
* `jingles_STEEL02.wav` — Music Jingles (CC0)
* `jingles_STEEL08.wav` — Music Jingles (CC0)
* `card-shove-1.wav` — Casino Audio (CC0)
* `card-shove-3.wav` — Casino Audio (CC0)
* `card-shuffle.wav` — Casino Audio (CC0)
