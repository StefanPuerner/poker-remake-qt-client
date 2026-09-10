# ── Clientes Qt: PokerClientQt, PokerClientMobile y sus bancos de prueba ──────
#  Compartido con el repo público poker-remake-qt-client: este fichero se
#  copia TAL CUAL allí (scripts/sincronizar_repo_publico.sh) y su
#  CMakeLists.txt lo incluye igual que el de aquí, en el mismo orden:
#  Comun.cmake → BibliotecasCliente.cmake → ClientesQt.cmake. Así los dos
#  repos compilan los clientes con las mismas reglas y el público no se
#  queda atrás sin que nadie lo note (pasó: en 2026-09 le faltaban el motor,
#  el modo offline, los iconos y el shader, y no habría compilado).
#  ⚠️ Nada de aquí puede depender de algo que solo exista en el repo
#  privado: servidor, tests, ncurses, SQLite, OpenSSL del sistema.
#  Necesita de antes: POKER_WARN_FLAGS y POKER_APP_VERSION_STRING
#  (Comun.cmake), PokerNetClient y PokerEngine (BibliotecasCliente.cmake).

# ── PokerClientQt — cliente con interfaz gráfica Qt Quick/QML (en construcción)
#  Qt Quick en vez de Qt Widgets: hay intención real de llevar esta interfaz a
#  móvil con controles táctiles, y Quick está diseñado para tacto y animación
#  fluida desde la base (Widgets no). Opcional a propósito: los scripts de
#  cross-compilación (ARM64/Termux) usan imágenes Docker sin Qt instalado, y no
#  deben romperse por esto. Si Qt6 Quick no se encuentra, el target se omite.
#
#  ⚠️ ShaderTools va en OPTIONAL_COMPONENTS, NUNCA en la lista de COMPONENTS
#  de arriba. Estuvo ahí desde el commit del dithering (798fbce) y rompió
#  los TRES builds de release sin que nadie se enterara: con un componente
#  obligatorio que falta, find_package deja Qt6_FOUND en falso, y como la
#  llamada es QUIET no avisa -- el "if" de abajo se salta el bloque Qt
#  entero en silencio, PokerClientQt/PokerClientMobile ni llegan a existir,
#  y el fallo solo aparece al final como "No rule to make target
#  'PokerClientMobile_make_apk'" (visto en el CI de Android, 2026-09-10).
#  Los workflows instalaban Qt sin el módulo qtshadertools.
#
#  Que sea opcional AQUÍ no significa que los clientes funcionen sin él:
#  ver la comprobación FATAL_ERROR justo debajo del "if".
find_package(Qt6 COMPONENTS Quick QuickControls2 Network
             OPTIONAL_COMPONENTS ShaderTools QUIET)
if(Qt6_FOUND AND TARGET Qt6::Quick)
    # Con Qt Quick presente, ShaderTools deja de ser opcional: el QML de los
    # dos clientes carga "dither.frag.qsb" en decenas de superficies
    # (layer.effect: ShaderEffect { fragmentShader: ... }), y ese .qsb solo
    # existe si qt_add_shaders() lo compila en el build. Sin él, cada una de
    # esas superficies se queda sin su shader en tiempo de ejecución -- no
    # es "sale con banding", es interfaz rota. Así que se corta aquí, con un
    # error que dice qué falta, en vez de dejar que el bloque desaparezca en
    # silencio (lo de antes) o de compilar un cliente que se ve mal (lo que
    # decían los antiguos "message(WARNING ... compilará sin dithering)").
    if(NOT TARGET Qt6::ShaderTools)
        message(FATAL_ERROR
            "Qt6 Quick está instalado pero Qt6 ShaderTools NO. Los clientes Qt "
            "lo necesitan para compilar el shader de dithering "
            "(assets/shaders/dither.frag), que el QML usa en decenas de "
            "superficies. Instala el módulo qtshadertools: en un workflow, "
            "'modules: qtshadertools' en install-qt-action; en Arch/CachyOS, "
            "el paquete qt6-shadertools.")
    endif()

    # Variantes por metal de las decoraciones METÁLICAS (<icono>_<metal>.png,
    # fase 1 del plan de material, 2026-09-10), generadas con
    # "scripts/generar_iconos.sh acabados". El oro usa el fichero base. Se
    # construye aquí una vez y la usan los dos clientes. ⚠️ Esta lista,
    # METALICOS del script y decoracionesMetalicas en los dos Avatar.qml
    # tienen que coincidir.
    # ── Pestaña Torneos, solo mientras está en desarrollo ────────────────
    #  OFF por defecto: los releases (repo público) enseñan "Próximamente",
    #  como antes de que existiera Solitario. El CMakeLists.txt del repo
    #  privado la enciende para seguir desarrollándola. Pedido del usuario
    #  (2026-09-10): "hasta que esté listo, bloquear en el público de nuevo
    #  la sección de torneos". Llega al QML como la propiedad de contexto
    #  "torneosHabilitados" (ver los dos main). Variable normal y no
    #  option(): el repo privado pide CMake 3.10, y ahí option() pisaría un
    #  set() hecho antes (política CMP0077).
    if(NOT DEFINED POKER_TORNEOS)
        set(POKER_TORNEOS OFF)
    endif()
    message(STATUS "Pestaña Torneos en los clientes: ${POKER_TORNEOS}")

    set(ICONOS_METALICOS corona_inicial corona_laurel corona_real cinta_ondulada constelacion ojo_vigilante)
    set(ICONOS_ACABADO)
    foreach(icono IN LISTS ICONOS_METALICOS)
        foreach(metal hierro bronce plata platino)
            list(APPEND ICONOS_ACABADO assets/iconos/${icono}_${metal}.png)
        endforeach()
    endforeach()
    # Políticas explícitas de qt_add_qml_module (silencian avisos de CMake):
    # QTP0001 = usar el prefijo de recursos por defecto ':/qt/qml/'.
    # QTP0004 = no exigir qmldir manual por cada subcarpeta con .qml.
    # QTP0004 solo existe desde Qt 6.8 (confirmado leyendo el propio
    # Qt6QmlMacros.cmake: "__qt_internal_setup_policy(QTP0004 "6.8.0" ...)")
    # -- el build de Android usa 6.7.3 (la versión más reciente que el
    # catálogo de aqtinstall reconoce, ver build-android-dev.yml) y
    # qt_policy(SET QTP0004 NEW) ahí aborta el configure entero con
    # "QTP0004 is not a known Qt policy". Sin el guard, Qt6_VERSION < 6.8
    # simplemente no lo pide -- comportamiento de antes de que la política
    # existiera, no un cambio funcional real.
    qt_policy(SET QTP0001 NEW)
    if(Qt6_VERSION VERSION_GREATER_EQUAL "6.8.0")
        qt_policy(SET QTP0004 NEW)
    endif()

    qt_add_executable(PokerClientQt
        src/client-qt/main.cpp
        include/net-qt/NetworkClient.hpp
        include/net-qt/VersionChecker.hpp
        # Modo offline (Fase 7, ver docs/plan-modo-offline.md) -- LocalGameObserver
        # y LocalGameClient son Q_OBJECT, tienen que listarse aquí explícitamente
        # o AUTOMOC no los mocea y el enlazado falla con "vtable sin definir" sin
        # ningún aviso de compilación previo (ya mordió una vez con
        # VersionChecker.hpp, ver CLAUDE.md). JugadorLocalQt.hpp NO es Q_OBJECT
        # (es un Player normal, como Bot/NetworkPlayer) -- no hace falta listarlo.
        include/local-qt/LocalGameObserver.hpp
        include/local-qt/LocalGameClient.hpp
        include/local-qt/ModoJuegoCoordinador.hpp
    )
    # Sin esto, el .exe de Windows se queda con el icono genérico del
    # sistema (ni el Explorador ni la barra de tareas muestran nada
    # propio) -- windeployqt no lo hace por su cuenta, hace falta un
    # recurso .rc compilado dentro del propio ejecutable.
    if(WIN32)
        target_sources(PokerClientQt PRIVATE assets/app.rc)
    endif()
    # qt_add_qml_module necesita AUTOMOC (registro de metatipos QML) incluso
    # antes de que exista ninguna clase C++ con Q_OBJECT propia.
    set_target_properties(PokerClientQt PROPERTIES AUTOMOC ON)
    # URI del módulo QML distinto del nombre del target a propósito: Qt genera
    # una carpeta con el nombre del URI dentro del directorio de build, y este
    # proyecto pone todos los ejecutables en la raíz de ese mismo directorio
    # (CMAKE_RUNTIME_OUTPUT_DIRECTORY, cmake/Comun.cmake) — con el mismo nombre,
    # colisionan (el enlazador falla: "es un directorio").
    # qt_add_qml_module no detecta solo el "pragma Singleton" de Tema.qml —
    # sin esto, el qmldir generado lo lista como un tipo normal en vez de
    # "singleton Tema ...", y qmllint (que sí lee el qmldir al pie de la
    # letra) no reconoce ninguna de sus propiedades (falsos positivos
    # "Member ... not found on type Tema" en cualquier fichero que use
    # Tema.colorX/escala). El propio motor de Qt en tiempo de ejecución no
    # se ve afectado (ya funcionaba antes de este fix), esto es solo para
    # que el linter entienda el singleton correctamente.
    set_source_files_properties(src/client-qt/qml/Tema.qml PROPERTIES
        QT_QML_SINGLETON_TYPE TRUE
    )

    qt_add_qml_module(PokerClientQt
        URI PokerQuick
        VERSION 1.0
        QML_FILES
            src/client-qt/qml/Main.qml
            src/client-qt/qml/Tema.qml
            src/client-qt/qml/Carta.qml
            src/client-qt/qml/PaloIcono.qml
            src/client-qt/qml/IconoFicha.qml
            src/client-qt/qml/IconoTrebol.qml
            src/client-qt/qml/Asiento.qml
            src/client-qt/qml/AsientoMini.qml
            src/client-qt/qml/Mesa.qml
            src/client-qt/qml/Interruptor.qml
            src/client-qt/qml/SelectorPildoras.qml
            src/client-qt/qml/BotonContorno.qml
            src/client-qt/qml/BotonRelleno.qml
            # Relieve compartido (2026-09-09) -- ver MarcoHueco.qml para
            # el porqué: sobre un panel con textura de fieltro, un
            # contorno de 1px no separa nada.
            src/client-qt/qml/MarcoHueco.qml
            src/client-qt/qml/MarcoRelieve.qml
            src/client-qt/qml/CampoTexto.qml
            src/client-qt/qml/PanelVoto.qml
            src/client-qt/qml/TarjetaReveal.qml
            src/client-qt/qml/BarraSuperior.qml
            src/client-qt/qml/ChatBox.qml
            src/client-qt/qml/PanelLateral.qml
            src/client-qt/qml/RielNavegacion.qml
            src/client-qt/qml/Proximamente.qml
            src/client-qt/qml/SelectorSegmentado.qml
            src/client-qt/qml/Avatar.qml
            src/client-qt/qml/PopupPerfilJugador.qml
            src/client-qt/qml/BannerVersionNueva.qml
            src/client-qt/qml/AnilloNivel.qml
            src/client-qt/qml/PopupInvitarAmigos.qml
            src/client-qt/qml/BannerInvitacionSala.qml
            src/client-qt/qml/PopupSeleccionCarta.qml
            src/client-qt/qml/PopupAcabado.qml
            src/client-qt/qml/CajaTitulo.qml
        RESOURCES
            # EB Garamond (SIL Open Font License) empaquetada con el binario:
            # los nombres de fuente del sistema ("Georgia", "Palatino"...) no
            # son fiables entre plataformas (no existen en Linux/Android), así
            # que se embebe el fichero real en vez de confiar en que el
            # sistema la tenga instalada. Licencia completa en assets/fonts/OFL.txt.
            assets/fonts/EBGaramond.ttf
            # Aviso de "tu turno" — dos tonos sintetizados (sin depender de
            # audio con licencia de terceros), ver assets/sonidos/.
            assets/sonidos/turno.wav
            # Nota: el dithering de degradados (BotonRelleno/SelectorSegmentado)
            # ya NO usa una textura -- ver assets/shaders/dither.frag y el
            # bloque qt_add_shaders() más abajo. Dos intentos con textura
            # (ruido blanco, luego Bayer 8x8) se descartaron por dar rayas de
            # moiré con la escala fraccional del compositor (1.5x en
            # Hyprland, el caso real que lo motivó).
            # Iconos de Textura/Efecto/Decoraciones y tarjetas de la Tienda
            # (Fase 5) -- antes dibujados a mano en Canvas (Avatar.qml),
            # sustituidos 2026-08-31 por iconos reales de game-icons.net
            # (CC BY 3.0, crédito junto a donde se usan) recoloreados al
            # estilo de la app. Ver assets/iconos_candidatos/README.md para
            # más por si hace falta ampliar el catálogo.
            #
            # Se REGENERAN con scripts/generar_iconos.sh (2026-09-09): esa
            # tanda pasó de color plano a contorno oscuro + degradado,
            # porque los iconos claros (constelación era blanco puro)
            # desaparecían sobre el tema claro. No editarlos a mano -- se
            # pierde la receta, que es justo lo que pasó con la primera
            # tanda.
            assets/iconos/gema_roja.png
            assets/iconos/gema_azul.png
            assets/iconos/punto_de_luz.png
            assets/iconos/pila_fichas.png
            assets/iconos/colmillo.png
            assets/iconos/ojo_vigilante.png
            assets/iconos/corona_laurel.png
            assets/iconos/cinta_ondulada.png
            assets/iconos/constelacion.png
            assets/iconos/corona_inicial.png
            assets/iconos/corona_real.png
            ${ICONOS_ACABADO}
            assets/iconos/palos_en_fila.png
            # "mano_real" (La Corona) dejó de ser un icono suelto -- ahora
            # es un abanico de 5 cartas de verdad alrededor de la parte de
            # arriba del marco (pedido explícito 2026-08-31: "para
            # conseguirse con una escalera real es un símbolo muy
            # sencillote"), ver el Item coronaDeCartas en Avatar.qml. Los 5
            # ficheros "card_X.png" que usaba (solo picas, sin distinción
            # de palo) se quitaron 2026-09-01 -- coronaDeCartas ahora es
            # genérico (composicionesCartas) y reutiliza directamente la
            # baraja de 52 de aquí abajo, así el mismo icono sirve para
            # mano_real, escalera_diamantes y cuatro_ases sin duplicar
            # ningún fichero.
            # "carta_poker" quitada -- sustituida por la baraja completa
            # (52 cartas sueltas, una por rango/palo) para el selector
            # "+" de la Tienda (pedido explícito 2026-08-31: "eso abre
            # un desplegable y eliges una carta cualquiera de la
            # baraja"). Mismo autor/licencia que arriba (aussiesim,
            # CC BY 3.0).
            assets/iconos/carta_2_treboles.png
            assets/iconos/carta_3_treboles.png
            assets/iconos/carta_4_treboles.png
            assets/iconos/carta_5_treboles.png
            assets/iconos/carta_6_treboles.png
            assets/iconos/carta_7_treboles.png
            assets/iconos/carta_8_treboles.png
            assets/iconos/carta_9_treboles.png
            assets/iconos/carta_10_treboles.png
            assets/iconos/carta_jack_treboles.png
            assets/iconos/carta_queen_treboles.png
            assets/iconos/carta_king_treboles.png
            assets/iconos/carta_ace_treboles.png
            assets/iconos/carta_2_diamantes.png
            assets/iconos/carta_3_diamantes.png
            assets/iconos/carta_4_diamantes.png
            assets/iconos/carta_5_diamantes.png
            assets/iconos/carta_6_diamantes.png
            assets/iconos/carta_7_diamantes.png
            assets/iconos/carta_8_diamantes.png
            assets/iconos/carta_9_diamantes.png
            assets/iconos/carta_10_diamantes.png
            assets/iconos/carta_jack_diamantes.png
            assets/iconos/carta_queen_diamantes.png
            assets/iconos/carta_king_diamantes.png
            assets/iconos/carta_ace_diamantes.png
            assets/iconos/carta_2_corazones.png
            assets/iconos/carta_3_corazones.png
            assets/iconos/carta_4_corazones.png
            assets/iconos/carta_5_corazones.png
            assets/iconos/carta_6_corazones.png
            assets/iconos/carta_7_corazones.png
            assets/iconos/carta_8_corazones.png
            assets/iconos/carta_9_corazones.png
            assets/iconos/carta_10_corazones.png
            assets/iconos/carta_jack_corazones.png
            assets/iconos/carta_queen_corazones.png
            assets/iconos/carta_king_corazones.png
            assets/iconos/carta_ace_corazones.png
            assets/iconos/carta_2_picas.png
            assets/iconos/carta_3_picas.png
            assets/iconos/carta_4_picas.png
            assets/iconos/carta_5_picas.png
            assets/iconos/carta_6_picas.png
            assets/iconos/carta_7_picas.png
            assets/iconos/carta_8_picas.png
            assets/iconos/carta_9_picas.png
            assets/iconos/carta_10_picas.png
            assets/iconos/carta_jack_picas.png
            assets/iconos/carta_queen_picas.png
            assets/iconos/carta_king_picas.png
            assets/iconos/carta_ace_picas.png
            # Símbolo genérico de categoría (2026-09-02, ver
            # rutaIconoObjetoTienda() en Main.qml) -- gema facetada
            # (lorc_gems) y llama (carl-olsen_flame), game-icons.net,
            # recoloreadas al dorado del tema.
            assets/iconos/textura_generica.png
            assets/iconos/efecto_generico.png
    )

    # Dithering de degradados (BotonRelleno/SelectorSegmentado, ver el
    # comentario largo en assets/shaders/dither.frag) -- ShaderTools es el
    # módulo de Qt6 que compila GLSL a .qsb (bytecode portable entre los
    # backends de la RHI: Vulkan/Metal/D3D/OpenGL) en tiempo de build. Solo
    # para PokerClientQt por ahora (2026-09-03, primer uso de shaders
    # custom en el proyecto) -- si se valida bien, extender a
    # PokerClientMobile/qml-mobile más adelante.
    # Sin "if(TARGET Qt6::ShaderTools)": su presencia ya la garantiza
    # el FATAL_ERROR del principio del bloque Qt. El "else" con un
    # WARNING de "compilará sin dithering" que había aquí era
    # engañoso (sin el .qsb la interfaz no sale con banding, sale
    # rota) y además inalcanzable en la práctica: el bloque entero
    # desaparecía antes de llegar a él.
    qt_add_shaders(PokerClientQt "pokerclientqt_shaders"
        PREFIX "/qt/qml/PokerQuick"
        FILES
            assets/shaders/dither.frag
    )

    target_include_directories(PokerClientQt PRIVATE include)
    # PokerEngine (motor de juego): modo offline (Fase 7, ver
    # docs/plan-modo-offline.md) -- antes ninguno de los dos clientes Qt lo
    # enlazaba, solo hablaban con el motor a través del protocolo de red
    # (PokerNetClient). LocalGameClient/LocalGameObserver/JugadorLocalQt
    # embeben un TexasHoldem real dentro del propio proceso del cliente.
    target_link_libraries(PokerClientQt PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::Network PokerNetClient PokerEngine)
    target_compile_options(PokerClientQt PRIVATE ${POKER_WARN_FLAGS})
    # Un aviso que no es nuestro: el cargador de caché QML que GENERA
    # qmlcachegen usa Q_GLOBAL_STATIC(Registry, unitRegistry), que omite el
    # argumento variádico de la macro -- legal desde C++20, "extensión" en
    # el C++17 de este proyecto, así que -Wpedantic lo señala. Se silencia
    # SOLO en ese fichero generado: el resto de PokerClientQt conserva el
    # aviso, por si algún día lo escribimos nosotros.
    check_cxx_compiler_flag(-Wvariadic-macro-arguments-omitted POKER_CXX_TIENE_WVARIADIC_OMITIDO)
    if(POKER_CXX_TIENE_WVARIADIC_OMITIDO)
        set_source_files_properties(
            "${CMAKE_CURRENT_BINARY_DIR}/.rcc/qmlcache/PokerClientQt_qmlcache_loader.cpp"
            PROPERTIES COMPILE_OPTIONS -Wno-variadic-macro-arguments-omitted)
    endif()
    target_compile_definitions(PokerClientQt PRIVATE POKER_APP_VERSION="${POKER_APP_VERSION_STRING}"
                                                 POKER_TORNEOS=$<BOOL:${POKER_TORNEOS}>)

    # Sonido de notificación ("tu turno") — Multimedia es un módulo
    # ADICIONAL de Qt6 (no viene con Quick), y solo hace falta para
    # PokerClientQt, nunca para PokerClientMobile. "if(NOT ANDROID)": al
    # cross-compilar para Android este mismo fichero se procesa entero
    # igualmente con el kit de Qt-para-Android como CMAKE_TOOLCHAIN (ver
    # build-android-dev.yml) -- ese kit no tiene por qué traer Multimedia
    # instalado, así que buscarlo ahí rompería el configure entero de una
    # build que ni siquiera compila PokerClientQt. target_link_libraries
    # usa "if(TARGET ...)" en vez de asumir que existe, por el mismo motivo.
    if(NOT ANDROID)
        find_package(Qt6 REQUIRED COMPONENTS Multimedia)
    endif()
    if(TARGET Qt6::Multimedia)
        target_link_libraries(PokerClientQt PRIVATE Qt6::Multimedia)
    endif()

    message(STATUS "Qt6 Quick encontrado — PokerClientQt disponible")

    # ── PokerClientMobile — interfaz táctil/landscape para Android (en construcción)
    #  Árbol QML separado de PokerClientQt (decisión tomada al empezar este
    #  trabajo): reutiliza solo la capa de red (NetworkClient.hpp) — el resto
    #  de ficheros QML (tema, componentes) parte de cero en qml-mobile/, para
    #  poder rediseñar tamaños de objetivo táctil, feedback "pressed" en vez
    #  de hover, y tipografía a la densidad real de un móvil, sin arriesgar
    #  el cliente de escritorio ya probado. URI distinto (mismo motivo que
    #  PokerQuick arriba: evitar colisión de carpetas en el directorio de build).
    qt_add_executable(PokerClientMobile
        src/client-qt/main-mobile.cpp
        include/net-qt/NetworkClient.hpp
        include/net-qt/VersionChecker.hpp
        # Ver el comentario gemelo en PokerClientQt más arriba.
        include/local-qt/LocalGameObserver.hpp
        include/local-qt/LocalGameClient.hpp
        include/local-qt/ModoJuegoCoordinador.hpp
    )
    set_target_properties(PokerClientMobile PROPERTIES AUTOMOC ON)

    # Solo importa al cross-compilar para Android (androiddeployqt la lee
    # para generar el APK) — en Linux/escritorio, PokerClientMobile es un
    # binario normal y esta propiedad simplemente no se usa. Fija el
    # bloqueo a horizontal (decisión ya tomada) y el nombre de la app.
    if(ANDROID)
        set_target_properties(PokerClientMobile PROPERTIES
            QT_ANDROID_PACKAGE_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src/client-qt/android
            # QT_ANDROID_MIN_SDK_VERSION sí es una propiedad real que leen
            # las macros de Qt (a juego con el AndroidManifest.xml). NOTA:
            # también se probó QT_ANDROID_TARGET_SDK_VERSION aquí para
            # forzar qué plataforma SDK usa androiddeployqt al compilar
            # recursos (compileSdk), pero no tuvo ningún efecto -- CMake
            # ignora en silencio una propiedad que sus macros no leen para
            # ese propósito. El control real de eso resultó ser qué
            # plataformas hay INSTALADAS en el runner (ver
            # build-android-dev.yml: se desinstala la más nueva a
            # propósito para que no quede otra que la compatible).
            QT_ANDROID_MIN_SDK_VERSION 28
        )
    endif()

    # Mismo motivo que el Tema.qml de escritorio más arriba: sin esto
    # qmllint no reconoce el singleton y "Member ... not found on type
    # Tema" sale como falso positivo en cualquier fichero que lo use.
    set_source_files_properties(src/client-qt/qml-mobile/Tema.qml
                                 src/client-qt/qml-mobile/EstadoOverlays.qml PROPERTIES
        QT_QML_SINGLETON_TYPE TRUE
    )

    # NO_CACHEGEN: en el móvil real (Android) se vio en vivo, con logcat,
    # que muchas propiedades de Tema (el singleton de color/escala) llegan
    # como "undefined" SOLO en el primerísimo instante de arranque, en
    # varios componentes distintos a la vez -- pero nunca en escritorio ni
    # en Linux. La diferencia real entre las dos plataformas: Android
    # empaqueta TODO en una única librería .so, mientras que en Linux es
    # un ejecutable normal. qmlcachegen (la compilación anticipada a
    # bytecode que hace esto por defecto) registra cada módulo QML vía
    # inicializadores estáticos de C++ -- y el orden en que corren esos
    # inicializadores ENTRE ficheros distintos dentro de una sola .so no
    # está garantizado (el clásico "static initialization order fiasco").
    # NO_CACHEGEN vuelve al camino interpretado normal (sin bytecode
    # precompilado), que no depende de ese orden.
    qt_add_qml_module(PokerClientMobile
        URI PokerQuickMobile
        VERSION 1.0
        NO_CACHEGEN
        QML_FILES
            src/client-qt/qml-mobile/Main.qml
            src/client-qt/qml-mobile/Tema.qml
            src/client-qt/qml-mobile/EstadoOverlays.qml
            src/client-qt/qml-mobile/BotonContorno.qml
            src/client-qt/qml-mobile/BotonRelleno.qml
            # Ver el comentario gemelo de PokerClientQt más arriba.
            src/client-qt/qml-mobile/IconoLupa.qml
            src/client-qt/qml-mobile/MarcoHueco.qml
            src/client-qt/qml-mobile/MarcoRelieve.qml
            src/client-qt/qml-mobile/CampoTexto.qml
            src/client-qt/qml-mobile/TecladoNumerico.qml
            src/client-qt/qml-mobile/CampoEmergente.qml
            src/client-qt/qml-mobile/SelectorNumerico.qml
            src/client-qt/qml-mobile/Interruptor.qml
            src/client-qt/qml-mobile/SelectorPildoras.qml
            src/client-qt/qml-mobile/BarraSuperior.qml
            src/client-qt/qml-mobile/IconoAjustes.qml
            src/client-qt/qml-mobile/IconoChuleta.qml
            src/client-qt/qml-mobile/CabeceraPullRefrescar.qml
            src/client-qt/qml-mobile/AsientoMini.qml
            src/client-qt/qml-mobile/ChatBox.qml
            src/client-qt/qml-mobile/Carta.qml
            src/client-qt/qml-mobile/PaloIcono.qml
            src/client-qt/qml-mobile/IconoFicha.qml
            src/client-qt/qml-mobile/IconoTrebol.qml
            src/client-qt/qml-mobile/Avatar.qml
            src/client-qt/qml-mobile/Asiento.qml
            src/client-qt/qml-mobile/Mesa.qml
            src/client-qt/qml-mobile/CajonPartida.qml
            src/client-qt/qml-mobile/PanelVoto.qml
            src/client-qt/qml-mobile/TarjetaReveal.qml
            src/client-qt/qml-mobile/ChuletaFlotante.qml
            src/client-qt/qml-mobile/RielNavegacion.qml
            src/client-qt/qml-mobile/Proximamente.qml
            src/client-qt/qml-mobile/SelectorSegmentado.qml
            src/client-qt/qml-mobile/VistaChatDirecto.qml
            src/client-qt/qml-mobile/PopupPerfilJugador.qml
            src/client-qt/qml-mobile/PopupInvitarAmigos.qml
            src/client-qt/qml-mobile/BannerInvitacionSala.qml
            src/client-qt/qml-mobile/BannerVersionNueva.qml
            src/client-qt/qml-mobile/CajaTitulo.qml
            src/client-qt/qml-mobile/AnilloNivel.qml
            src/client-qt/qml-mobile/PopupSeleccionCarta.qml
            src/client-qt/qml-mobile/PopupAcabado.qml
        RESOURCES
            # Mismo motivo que PokerClientQt más arriba -- se quedó fuera
            # al principio, sin darse cuenta: sin esto, Tema.fuenteElegante
            # nunca se resuelve (el FontLoader apunta a un recurso que no
            # existe) y toda la app usa la fuente por defecto del sistema
            # en vez de EB Garamond.
            assets/fonts/EBGaramond.ttf
            # Iconos de Textura/Efecto/Decoraciones y tarjetas de la
            # Tienda (Fase 5) -- mismo catálogo exacto que
            # PokerClientQt más arriba (ver ese comentario para
            # crédito/licencia por icono); Fase M0 del port de
            # progresión a móvil (2026-09-01, ver memoria
            # qt_mobile_progression_port_plan) -- antes NINGÚN icono
            # estaba empaquetado aquí, así que Avatar.qml (móvil) no
            # podía pintar ninguna decoración aunque el código ya las
            # soportara. Se regeneran con scripts/generar_iconos.sh, igual
            # que los del cliente de escritorio.
            assets/iconos/gema_roja.png
            assets/iconos/gema_azul.png
            assets/iconos/punto_de_luz.png
            assets/iconos/pila_fichas.png
            assets/iconos/colmillo.png
            assets/iconos/ojo_vigilante.png
            assets/iconos/corona_laurel.png
            assets/iconos/cinta_ondulada.png
            assets/iconos/constelacion.png
            assets/iconos/corona_inicial.png
            assets/iconos/corona_real.png
            ${ICONOS_ACABADO}
            assets/iconos/palos_en_fila.png
            # "mano_real" (La Corona) dejó de ser un icono suelto -- ahora
            # es un abanico de 5 cartas de verdad alrededor de la parte de
            # arriba del marco (pedido explícito 2026-08-31: "para
            # conseguirse con una escalera real es un símbolo muy
            # sencillote"), ver el Item coronaDeCartas en Avatar.qml. Los 5
            # ficheros "card_X.png" que usaba (solo picas, sin distinción
            # de palo) se quitaron 2026-09-01 -- coronaDeCartas ahora es
            # genérico (composicionesCartas) y reutiliza directamente la
            # baraja de 52 de aquí abajo, así el mismo icono sirve para
            # mano_real, escalera_diamantes y cuatro_ases sin duplicar
            # ningún fichero.
            # "carta_poker" quitada -- sustituida por la baraja completa
            # (52 cartas sueltas, una por rango/palo) para el selector
            # "+" de la Tienda (pedido explícito 2026-08-31: "eso abre
            # un desplegable y eliges una carta cualquiera de la
            # baraja"). Mismo autor/licencia que arriba (aussiesim,
            # CC BY 3.0).
            assets/iconos/carta_2_treboles.png
            assets/iconos/carta_3_treboles.png
            assets/iconos/carta_4_treboles.png
            assets/iconos/carta_5_treboles.png
            assets/iconos/carta_6_treboles.png
            assets/iconos/carta_7_treboles.png
            assets/iconos/carta_8_treboles.png
            assets/iconos/carta_9_treboles.png
            assets/iconos/carta_10_treboles.png
            assets/iconos/carta_jack_treboles.png
            assets/iconos/carta_queen_treboles.png
            assets/iconos/carta_king_treboles.png
            assets/iconos/carta_ace_treboles.png
            assets/iconos/carta_2_diamantes.png
            assets/iconos/carta_3_diamantes.png
            assets/iconos/carta_4_diamantes.png
            assets/iconos/carta_5_diamantes.png
            assets/iconos/carta_6_diamantes.png
            assets/iconos/carta_7_diamantes.png
            assets/iconos/carta_8_diamantes.png
            assets/iconos/carta_9_diamantes.png
            assets/iconos/carta_10_diamantes.png
            assets/iconos/carta_jack_diamantes.png
            assets/iconos/carta_queen_diamantes.png
            assets/iconos/carta_king_diamantes.png
            assets/iconos/carta_ace_diamantes.png
            assets/iconos/carta_2_corazones.png
            assets/iconos/carta_3_corazones.png
            assets/iconos/carta_4_corazones.png
            assets/iconos/carta_5_corazones.png
            assets/iconos/carta_6_corazones.png
            assets/iconos/carta_7_corazones.png
            assets/iconos/carta_8_corazones.png
            assets/iconos/carta_9_corazones.png
            assets/iconos/carta_10_corazones.png
            assets/iconos/carta_jack_corazones.png
            assets/iconos/carta_queen_corazones.png
            assets/iconos/carta_king_corazones.png
            assets/iconos/carta_ace_corazones.png
            assets/iconos/carta_2_picas.png
            assets/iconos/carta_3_picas.png
            assets/iconos/carta_4_picas.png
            assets/iconos/carta_5_picas.png
            assets/iconos/carta_6_picas.png
            assets/iconos/carta_7_picas.png
            assets/iconos/carta_8_picas.png
            assets/iconos/carta_9_picas.png
            assets/iconos/carta_10_picas.png
            assets/iconos/carta_jack_picas.png
            assets/iconos/carta_queen_picas.png
            assets/iconos/carta_king_picas.png
            assets/iconos/carta_ace_picas.png
            # Símbolo genérico de categoría (2026-09-02, ver
            # rutaIconoObjetoTienda() en Main.qml) -- gema facetada
            # (lorc_gems) y llama (carl-olsen_flame), game-icons.net,
            # recoloreadas al dorado del tema.
            assets/iconos/textura_generica.png
            assets/iconos/efecto_generico.png
    )

    # Dithering de degradados en móvil -- mismo shader fuente que
    # PokerClientQt (assets/shaders/dither.frag), compilado aparte porque
    # cada target tiene su propio namespace de recursos QML
    # (PokerQuickMobile vs PokerQuick). Qt6::ShaderTools ya se buscó más
    # arriba (bloque de PokerClientQt) -- basta con comprobar el target.
    # Sin "if(TARGET Qt6::ShaderTools)": su presencia ya la garantiza
    # el FATAL_ERROR del principio del bloque Qt. El "else" con un
    # WARNING de "compilará sin dithering" que había aquí era
    # engañoso (sin el .qsb la interfaz no sale con banding, sale
    # rota) y además inalcanzable en la práctica: el bloque entero
    # desaparecía antes de llegar a él.
    qt_add_shaders(PokerClientMobile "pokerclientmobile_shaders"
        PREFIX "/qt/qml/PokerQuickMobile"
        # Grano de 2 píxeles físicos en vez de 1 (2026-09-10): con la
        # densidad de un móvil, la textura de tapete no se veía. Ver la nota
        # de TAMANO_GRANO en assets/shaders/dither.frag. DEFINES existe ya en
        # Qt 6.7 (el del CI de Android), comprobado en su documentación.
        DEFINES "TAMANO_GRANO=2.0"
        FILES
            assets/shaders/dither.frag
        # Nombre de salida PROPIO, obligatorio desde que esta variante lleva
        # otro DEFINES: qt_add_shaders escribe en
        # ${CMAKE_CURRENT_BINARY_DIR}/.qsb/<nombre> -- por DIRECTORIO, no por
        # target --, y PokerClientQt, AvatarTest y este target viven en el
        # mismo directorio. Con el mismo nombre, las tres llamadas
        # compartían un único fichero (CMake fusionaba las reglas porque
        # eran idénticas); con defines distintos, una variante pisaría a la
        # otra. Y el nombre del fichero y el del recurso van atados
        # (QT_RESOURCE_ALIAS = nombre de salida), así que el QML móvil
        # carga "dither_movil.frag.qsb".
        OUTPUTS
            assets/shaders/dither_movil.frag.qsb
    )

    target_include_directories(PokerClientMobile PRIVATE include)
    # Ver el comentario gemelo en PokerClientQt más arriba.
    target_link_libraries(PokerClientMobile PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::Network PokerNetClient PokerEngine)
    target_compile_options(PokerClientMobile PRIVATE ${POKER_WARN_FLAGS})
    # POKER_CLIENTE_MOVIL: el enlace de descarga de Ajustes da siempre el APK
    # en este cliente, también en un PC -- ver VersionChecker::urlDescarga().
    target_compile_definitions(PokerClientMobile PRIVATE POKER_APP_VERSION="${POKER_APP_VERSION_STRING}"
                                                     POKER_TORNEOS=$<BOOL:${POKER_TORNEOS}>
                                                     POKER_CLIENTE_MOVIL=1)

    # ── OpenSSL para Android (rama feature/red-segura) ─────────────────────
    #  QSslSocket (usado por NetworkClient.hpp para el TLS del servidor)
    #  necesita un backend OpenSSL de verdad -- en Android, a diferencia de
    #  escritorio, no basta con que esté instalado en el sistema (las apps
    #  no pueden cargar el libssl.so privado del propio Android desde hace
    #  varias versiones): hay que empaquetar las .so de OpenSSL DENTRO del
    #  APK. android_openssl (KDAB, Apache-2.0) es el paquete de libs
    #  prebuilt + integración CMake estándar para esto -- mismo patrón que
    #  Catch2 en el CMakeLists del repo privado (FetchContent, se baja solo la primera vez).
    #  add_android_openssl_libraries() añade las .so a QT_ANDROID_EXTRA_LIBS
    #  (para que androiddeployqt las meta en el APK) y enlaza
    #  OpenSSL::SSL/OpenSSL::Crypto -- no significa que este target llame a
    #  la API de OpenSSL directamente (no lo hace, QSslSocket es la única
    #  interfaz), solo que el plugin TLS de Qt encuentre las .so en tiempo
    #  de ejecución dentro del APK.
    if(ANDROID)
        include(FetchContent)
        FetchContent_Declare(
            android_openssl
            DOWNLOAD_EXTRACT_TIMESTAMP true
            URL https://github.com/KDAB/android_openssl/archive/refs/heads/master.zip
        )
        FetchContent_MakeAvailable(android_openssl)
        include(${android_openssl_SOURCE_DIR}/android_openssl.cmake)
        add_android_openssl_libraries(PokerClientMobile)
    endif()

    message(STATUS "Qt6 Quick encontrado — PokerClientMobile disponible")

    # ── AvatarTest — banco de pruebas standalone de los marcos de avatar
    #  (bronce/plata/oro/platino/campeón), SOLO escritorio: se usa para
    #  revisar/afinar los marcos ANTES de integrarlos en Asiento/Ranking de
    #  verdad, no aporta nada compilado para Android. Reutiliza tal cual
    #  Tema.qml y Avatar.qml de qml/ (mismo fichero, mismo URI de origen)
    #  para que los colores/proporciones sean EXACTAMENTE los reales, no
    #  una aproximación aparte que se pueda desincronizar.
    if(NOT ANDROID)
        set_source_files_properties(src/client-qt/qml/Tema.qml PROPERTIES
            QT_QML_SINGLETON_TYPE TRUE
        )
        qt_add_executable(AvatarTest
            src/client-qt/avatar-test/main.cpp
        )
        set_target_properties(AvatarTest PROPERTIES AUTOMOC ON)
        qt_add_qml_module(AvatarTest
            URI PokerAvatarTest
            VERSION 1.0
            QML_FILES
                src/client-qt/avatar-test/Main.qml
                src/client-qt/qml/Tema.qml
                src/client-qt/qml/Avatar.qml
        )
        # Avatar.qml pide sus iconos por ruta ABSOLUTA bajo el prefijo del
        # cliente real ("qrc:/qt/qml/PokerQuick/assets/iconos/..."), así
        # que el banco tiene que registrarlos bajo ESE prefijo aunque su
        # URI de módulo sea otro. Sin esto, el banco no podía pintar
        # ninguna decoración -- que es justo lo que hacía falta revisar
        # (2026-09-09, al arreglar los iconos).
        file(GLOB ICONOS_BANCO RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} assets/iconos/*.png)
        qt_add_resources(AvatarTest "avatartest_iconos"
            PREFIX "/qt/qml/PokerQuick"
            FILES ${ICONOS_BANCO}
        )
        if(TARGET Qt6::ShaderTools)
            qt_add_shaders(AvatarTest "avatartest_shaders"
                PREFIX "/qt/qml/PokerQuick"
                FILES
                    assets/shaders/dither.frag
            )
        endif()
        target_link_libraries(AvatarTest PRIVATE Qt6::Quick Qt6::QuickControls2)
        message(STATUS "AvatarTest disponible (banco de pruebas de marcos y cosméticos)")
    endif()

    # ── LocalOfflineSmokeTest — valida en vivo el modo offline (Fase 7, ver
    #  docs/plan-modo-offline.md) sin necesitar interfaz gráfica: arranca una
    #  partida local real (1 humano guionizado + 1 bot) y la juega sola de
    #  principio a fin. Necesario porque una compilación limpia de
    #  LocalGameObserver/LocalGameClient (moc solo mocea la DECLARACIÓN de
    #  la clase, no analiza los cuerpos de método) no demuestra por sí sola
    #  que el código dentro de esos métodos compila de verdad ni que el
    #  ciclo bloqueante GUI<->motor no se queda colgado -- Qt6::Core basta
    #  (sin Quick/QML, no hay nada que dibujar). SOLO escritorio (dev tool),
    #  mismo motivo que AvatarTest.
    if(NOT ANDROID)
        find_package(Qt6 REQUIRED COMPONENTS Core)
        add_executable(LocalOfflineSmokeTest
            src/client-qt/local-offline-smoke-test/main.cpp
            include/local-qt/LocalGameObserver.hpp
            include/local-qt/LocalGameClient.hpp
        )
        set_target_properties(LocalOfflineSmokeTest PROPERTIES AUTOMOC ON)
        target_include_directories(LocalOfflineSmokeTest PRIVATE include)
        # PokerNetClient (no PokerNet): net::ser vive en Serializer.cpp, que
        # PokerNetClient ya compila sin arrastrar OpenSSL/sockets (ver el
        # comentario de NET_CLIENT_SOURCES, cmake/BibliotecasCliente.cmake) -- mismo motivo por
        # el que PokerClientQt/PokerClientMobile lo enlazan.
        target_link_libraries(LocalOfflineSmokeTest PRIVATE Qt6::Core PokerEngine PokerNetClient)
        target_compile_options(LocalOfflineSmokeTest PRIVATE ${POKER_WARN_FLAGS})
        message(STATUS "LocalOfflineSmokeTest disponible (validación en vivo del modo offline)")
    endif()
else()
    message(STATUS "Qt6 Quick no encontrado — PokerClientQt/PokerClientMobile omitidos (opcional)")
endif()
