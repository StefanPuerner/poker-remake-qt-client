#version 440

// dither.frag — dithering de degradados vía Interleaved Gradient Noise
// (Jorge Jiménez, "Next Generation Post Processing in Call of Duty:
// Advanced Warfare", SIGGRAPH 2014) — la técnica estándar en motores de
// videojuegos para eliminar el banding de un degradado renderizado a 8
// bits/canal sin dithing nativo (que es lo que hace Qt Quick por defecto
// en su Gradient/GradientStop).
//
// Por qué NO una textura de ruido tileada (primer intento, descartado):
// una textura repetida con Image.Tile solo encaja limpio contra la
// rejilla de píxeles físicos cuando el factor de escala del compositor es
// un entero (1x, 2x...). Con escala fraccional (1.5x en Hyprland, el caso
// real que motivó esto — ver hyprctl monitors), cada repetición del tile
// cae en un desfase de subpíxel distinto al de la repetición anterior,
// generando un patrón de interferencia (moiré/rayas) en vez de dithering
// limpio. Esta técnica no tiene ese problema porque no muestrea ninguna
// textura para el ruido — lo calcula directo a partir de gl_FragCoord, la
// coordenada del píxel FÍSICO ya renderizado, así que es correcta sea
// cual sea el factor de escala del compositor.
//
// Se usa como layer.effect (ver BotonRelleno.qml/SelectorSegmentado.qml):
// Qt Quick renderiza el Rectangle con el degradado a una textura interna
// y nos la pasa en "source" — aquí solo le sumamos el ruido antes de
// escribir el resultado final.
//
// "amplitud" -- confirmado en pruebas reales (2026-09-03) que a nivel
// exagerado (60/255) el efecto se ve y se ejecuta correctamente en el
// backend gráfico (Hyprland/Vulkan-OpenGL, escala 1.5x) -- descartado que
// fuera un fallo de pipeline, solo faltaba amplitud en superficies
// grandes/de bajo contraste. Sorpresa real del usuario probándolo: a ese
// nivel "grotesco" el ruido se percibe como una textura de tapete de
// fieltro, que pega estéticamente con el tema de póker -- pero SOLO fuera
// de los botones ("en los botones no, en el resto sí"). Por eso la
// amplitud es un uniform, no una constante: cada superficie declara la
// suya (ver el valor por defecto de "amplitud" en cada ShaderEffect QML).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float amplitud;  ///< Amplitud del dither en niveles de 8 bits (0-255) por canal.
};

layout(binding = 1) uniform sampler2D source;

// Tamaño del grano, en PÍXELES FÍSICOS. 1.0 = un grano por píxel, lo de
// siempre (escritorio). El cliente móvil compila su propia copia de este
// shader con -DTAMANO_GRANO=2.0 (ver DEFINES en el qt_add_shaders de
// PokerClientMobile, cmake/ClientesQt.cmake): con densidades de x3 o más, un grano
// por píxel físico mide un tercio de píxel lógico y la textura de tapete
// "apenas se nota" (pedido explícito 2026-09-10). Se hace en compilación y
// no como uniform a propósito: un uniform nuevo obligaría a declarar su
// propiedad en las ~70 superficies con dithering de los dos clientes, y
// ShaderEffect avisa por consola de cada una que no la tenga.
//
// El tamaño de celda es un entero de píxeles físicos, así que la rejilla
// sigue alineada con la de la pantalla -- no reaparece el moiré con escala
// fraccional que descartó la textura tileada (ver arriba). Verificado antes
// con una simulación de esta misma fórmula: a 2 px el IGN se lee como un
// tejido tipo sarga, sin rayado; a 3 ya se ve la trama.
#ifndef TAMANO_GRANO
#define TAMANO_GRANO 1.0
#endif

// Fórmula original de Jiménez (SIGGRAPH 2014) — genera ruido de alta
// frecuencia espacial (poca correlación entre píxeles vecinos), lo que
// evita el aspecto "grumoso" de un ruido blanco genérico a la misma
// amplitud.
float ruidoDegradadoEntrelazado(vec2 coordenadaFragmento) {
    return fract(52.9829189 * fract(dot(coordenadaFragmento, vec2(0.06711056, 0.00583715))));
}

void main() {
    vec4 color = texture(source, qt_TexCoord0);

    // [0,1) -> [-0.5,0.5): perturbación simétrica alrededor de 0, para no
    // aclarar ni oscurecer el degradado en conjunto, solo redistribuir a
    // qué nivel de 8 bits redondea cada píxel (o, a amplitud alta a
    // propósito, dar la textura de tapete).
    float ruido = ruidoDegradadoEntrelazado(floor(gl_FragCoord.xy / TAMANO_GRANO)) - 0.5;

    // Qt Quick trabaja con alfa premultiplicado; escalar por color.a evita
    // aclarar el borde antialiasado de las esquinas redondeadas (ahí el
    // color ya viene atenuado por una alfa < 1).
    color.rgb += ruido * (amplitud / 255.0) * color.a;

    fragColor = color * qt_Opacity;
}
