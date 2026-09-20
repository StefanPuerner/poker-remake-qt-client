// Idioma.qml (móvil) — mismo papel que src/client-qt/qml/Idioma.qml
// (escritorio, ver el comentario largo ahí para el porqué de cada cosa).
// Copia gemela a propósito -- mismo criterio que Tema.qml, "nada se
// hereda automáticamente" entre los dos árboles QML. Si tocas uno, toca
// el otro.
//
// Cómo se elige: property "actual" persistida (ver Settings en Main.qml,
// mismo patrón de sincronización manual que Tema.temaActual -- un alias
// directo a la propiedad de un singleton no funciona, ver el comentario
// de "tema" en Main.qml). Al primer arranque (nada guardado todavía) se
// detecta el idioma del sistema -- si no es de los tres, cae a español.
//
// Cómo se traduce una cadena NUEVA: añadir su clave a "textos" con las
// tres traducciones y llamar a Idioma.t("esa_clave") donde antes hubiera
// un literal. Una clave que falte en la tabla se devuelve TAL CUAL (nunca
// una cadena vacía ni un error) -- así queda un aviso legible de que
// falta traducir, en vez de romper nada, mientras se sigue convirtiendo
// el resto de la app poco a poco (ver el estado real, pantalla a
// pantalla, en docs/plan-idiomas.md -- hoy NO está toda traducida).
pragma Singleton
import QtQuick

QtObject {
    id: idioma

    property string actual: "es"  // "es" | "en" | "de"

    readonly property var idiomasDisponibles: ["es", "en", "de"]
    readonly property var nombreIdioma: ({
        "es": "Español", "en": "English", "de": "Deutsch"
    })

    // Qt.locale().name es "es_ES"/"en_US"/"de_DE" -- los dos primeros
    // caracteres bastan. Cualquier otro idioma del sistema cae a español,
    // no a inglés -- es el idioma nativo del proyecto y el que más se
    // conoce ya de sobra por dentro.
    function idiomaDelSistema() {
        var codigo = Qt.locale().name.substring(0, 2);
        return idiomasDisponibles.indexOf(codigo) !== -1 ? codigo : "es";
    }

    function t(clave) {
        var entrada = idioma.textos[clave];
        if (!entrada) return clave;
        return entrada[idioma.actual] || entrada.es || clave;
    }
    // Como t(), sustituyendo "{0}", "{1}"... por @p valores -- para textos
    // con una parte variable (un nombre, una cantidad).
    function tf(clave, valores) {
        var s = idioma.t(clave);
        for (var i = 0; i < valores.length; i++) {
            s = s.replace("{" + i + "}", valores[i]);
        }
        return s;
    }

    readonly property var textos: ({
        // ── Inicio ───────────────────────────────────────────────────────
        "app_subtitulo": {
            es: "MESA PRIVADA · TEXAS HOLD'EM",
            en: "PRIVATE TABLE · TEXAS HOLD'EM",
            de: "PRIVATER TISCH · TEXAS HOLD'EM"
        },
        "conexion_comprobando": {
            es: "Comprobando conexión…", en: "Checking connection…", de: "Verbindung wird geprüft…"
        },
        "conexion_conectado": {
            es: "Conectado al servidor", en: "Connected to the server", de: "Mit dem Server verbunden"
        },
        "conexion_sin_conexion": {
            es: "Sin conexión con el servidor", en: "No connection to the server",
            de: "Keine Verbindung zum Server"
        },
        "boton_iniciar_sesion": { es: "Iniciar sesión", en: "Log in", de: "Anmelden" },
        "boton_crear_cuenta": { es: "Crear cuenta", en: "Create account", de: "Konto erstellen" },
        "boton_entrar_invitado": {
            es: "Entrar como invitado", en: "Continue as guest", de: "Als Gast fortfahren"
        },
        "boton_jugar_sin_conexion": { es: "Jugar sin conexión", en: "Play offline", de: "Offline spielen" },
        "boton_jugar_como_invitado": {
            es: "Jugar como invitado", en: "Play as guest", de: "Als Gast spielen"
        },
        "boton_salir": { es: "Salir", en: "Quit", de: "Beenden" },
        "offline_como_usuario": {
            es: "Como {0} · sin Tréboles ni Elo", en: "As {0} · no Clovers or Elo",
            de: "Als {0} · keine Kleeblätter oder Elo"
        },
        "offline_sin_cuenta_cacheada": {
            es: "Inicia sesión al menos una vez con el servidor disponible para poder jugar sin conexión con tu cuenta.",
            en: "Log in at least once while the server is available to be able to play offline with your account.",
            de: "Melde dich mindestens einmal an, während der Server erreichbar ist, um offline mit deinem Konto spielen zu können."
        },

        // ── Login / Registro ────────────────────────────────────────────────
        "boton_entrar": { es: "Entrar", en: "Log in", de: "Anmelden" },
        "boton_entrando": { es: "Entrando…", en: "Logging in…", de: "Anmeldung läuft…" },
        "boton_volver": { es: "Volver", en: "Back", de: "Zurück" },
        "placeholder_usuario": { es: "Usuario", en: "Username", de: "Benutzername" },
        "placeholder_usuario_min3": {
            es: "Usuario (mín. 3 caracteres)", en: "Username (min. 3 characters)",
            de: "Benutzername (mind. 3 Zeichen)"
        },
        "placeholder_password": { es: "Contraseña", en: "Password", de: "Passwort" },
        "placeholder_password_min8": {
            es: "Contraseña (8+ caracteres)", en: "Password (8+ characters)", de: "Passwort (8+ Zeichen)"
        },
        "placeholder_password_repetir": {
            es: "Repite la contraseña", en: "Repeat the password", de: "Passwort wiederholen"
        },
        "enlace_crear_cuenta": {
            es: "¿No tienes cuenta? Crear una", en: "Don't have an account? Create one",
            de: "Kein Konto? Eins erstellen"
        },
        "enlace_iniciar_sesion": {
            es: "¿Ya tienes cuenta? Iniciar sesión", en: "Already have an account? Log in",
            de: "Schon ein Konto? Anmelden"
        },
        "error_falta_usuario": {
            es: "Escribe tu nombre de usuario.", en: "Enter your username.",
            de: "Gib deinen Benutzernamen ein."
        },
        "error_falta_password": {
            es: "Escribe tu contraseña.", en: "Enter your password.", de: "Gib dein Passwort ein."
        },
        "error_usuario_corto": {
            es: "El nombre de usuario debe tener al menos 3 caracteres.",
            en: "The username must be at least 3 characters long.",
            de: "Der Benutzername muss mindestens 3 Zeichen lang sein."
        },
        "error_password_corta": {
            es: "La contraseña debe tener al menos 8 caracteres.",
            en: "The password must be at least 8 characters long.",
            de: "Das Passwort muss mindestens 8 Zeichen lang sein."
        },
        "error_passwords_no_coinciden": {
            es: "Las contraseñas no coinciden.", en: "The passwords don't match.",
            de: "Die Passwörter stimmen nicht überein."
        },
        // ── Riel de navegación (RielNavegacion.qml) ─────────────────────────
        "riel_salas": { es: "SALAS", en: "ROOMS", de: "RÄUME" },
        "riel_ranking": { es: "RANKING", en: "RANKING", de: "RANGLISTE" },
        "riel_torneos": { es: "TORNEOS", en: "TOURNAMENTS", de: "TURNIERE" },
        "riel_social": { es: "SOCIAL", en: "SOCIAL", de: "SOZIAL" },
        "riel_tienda": { es: "TIENDA", en: "SHOP", de: "SHOP" },
        "riel_cuenta": { es: "CUENTA", en: "ACCOUNT", de: "KONTO" },

        // ── Pantalla Salas ───────────────────────────────────────────────────
        "titulo_partida_local": { es: "Partida local", en: "Local game", de: "Lokales Spiel" },
        "titulo_salas_disponibles": {
            es: "Salas disponibles", en: "Available rooms", de: "Verfügbare Räume"
        },
        "titulo_partidas_guardadas": {
            es: "Partidas guardadas", en: "Saved games", de: "Gespeicherte Partien"
        },
        "placeholder_codigo_sala": {
            es: "Código de sala privada", en: "Private room code", de: "Code für privaten Raum"
        },
        "boton_unirse_codigo": { es: "Unirse por código", en: "Join by code", de: "Mit Code beitreten" },
        "tab_salas": { es: "Salas", en: "Rooms", de: "Räume" },
        "boton_partida_local": {
            es: "Nueva partida local", en: "New local game", de: "Neues lokales Spiel"
        },
        "boton_crear_sala": { es: "Crear sala nueva", en: "Create new room", de: "Neuen Raum erstellen" },
        "vacio_sin_salas": {
            es: "No hay salas públicas disponibles ahora mismo.",
            en: "There are no public rooms available right now.",
            de: "Gerade sind keine öffentlichen Räume verfügbar."
        },
        "vacio_sin_guardadas": {
            es: "No hay partidas guardadas en el servidor.",
            en: "There are no saved games on the server.",
            de: "Es gibt keine gespeicherten Partien auf dem Server."
        },
        "boton_unirse": { es: "Unirse", en: "Join", de: "Beitreten" },
        "guardada_detalle": {
            es: "{0} · {1} humano(s), {2} bot(s)", en: "{0} · {1} human(s), {2} bot(s)",
            de: "{0} · {1} Mensch(en), {2} Bot(s)"
        },
        "boton_reanudar": { es: "Reanudar", en: "Resume", de: "Fortsetzen" },
        "boton_confirmar_borrado": { es: "¿Seguro?", en: "Sure?", de: "Sicher?" },
        // Solo usados en qml-mobile/ (escritorio usa "tab_salas" a secas y
        // el emoji "🗑" en vez de texto), pero viven en la tabla común de
        // todas formas -- mismo criterio que el resto de la tabla.
        "tab_salas_publicas": { es: "Salas públicas", en: "Public rooms", de: "Öffentliche Räume" },
        "tab_sala_privada": { es: "Sala privada", en: "Private room", de: "Privater Raum" },
        // Versión abreviada de boton_partida_local/boton_crear_sala -- solo
        // qml-mobile/, ver el comentario junto al botón en Main.qml
        // (rediseño 2026-08-28: "Crear sala nueva" se comía la barra en
        // landscape compacto).
        "boton_partida_local_corto": { es: "+ Partida", en: "+ Game", de: "+ Spiel" },
        "boton_crear_sala_corto": { es: "+ Sala", en: "+ Room", de: "+ Raum" },

        // ── Pantalla Ranking ─────────────────────────────────────────────────
        "titulo_ranking_global": { es: "Ranking global", en: "Global ranking", de: "Globale Rangliste" },
        // Solo escritorio -- móvil quitó este aviso el 2026-09-02 (ver el
        // comentario junto a cabeceraRankingMovil) para ganar altura.
        "ranking_subtitulo": {
            es: "Cuentas con al menos 5 partidas jugadas · ordenado por {0}",
            en: "Accounts with at least 5 games played · sorted by {0}",
            de: "Konten mit mindestens 5 gespielten Partien · sortiert nach {0}"
        },
        "orden_victorias": { es: "victorias", en: "wins", de: "Siege" },
        "orden_ratio": { es: "ratio", en: "ratio", de: "Quote" },
        "orden_elo": { es: "Elo", en: "Elo", de: "Elo" },
        "popup_ranking_titulo": {
            es: "¿Cuándo cuenta una partida?", en: "When does a game count?",
            de: "Wann zählt eine Partie?"
        },
        "popup_ranking_texto1": {
            es: "Para las estadísticas personales (manos y partidas jugadas/ganadas, racha, mayor bote) hacen falta al menos 2 cuentas reales en la mesa y al menos 5 manos jugadas. Jugar en solitario contra bots no cuenta nunca, sea cual sea la duración.",
            en: "For personal statistics (hands and games played/won, streak, biggest pot) you need at least 2 real accounts at the table and at least 5 hands played. Playing solo against bots never counts, no matter how long.",
            de: "Für persönliche Statistiken (gespielte/gewonnene Hände und Partien, Serie, größter Pot) sind mindestens 2 echte Konten am Tisch und mindestens 5 gespielte Hände nötig. Alleine gegen Bots spielen zählt nie, egal wie lange."
        },
        "popup_ranking_texto2": {
            es: "Las combinaciones mostradas en un showdown (mejor mano, contador por tipo) sí cuentan siempre, sin ese requisito.",
            en: "Hands shown at a showdown (best hand, counter by type) always count, without that requirement.",
            de: "Beim Showdown gezeigte Kombinationen (beste Hand, Zähler nach Typ) zählen immer, ohne diese Voraussetzung."
        },
        "popup_ranking_texto3": {
            es: "Para aparecer en este ranking hace falta además al menos 5 partidas jugadas de las que sí cuentan.",
            en: "To appear in this ranking you also need at least 5 played games that count.",
            de: "Um in dieser Rangliste zu erscheinen, sind außerdem mindestens 5 zählende gespielte Partien nötig."
        },
        "popup_ranking_texto4": {
            es: "Elo (pestaña por defecto) mide habilidad, no dedicación: +10 al ganar una partida oficial, −3 al perderla, sin ajustar por el nivel del rival. \"Más victorias\" y \"ratio\" son históricos y nunca se resetean; Elo sí -- se reinicia con cada temporada nueva.",
            en: "Elo (default tab) measures skill, not dedication: +10 for winning an official game, −3 for losing it, without adjusting for the opponent's level. \"Most wins\" and \"ratio\" are historical and never reset; Elo does -- it resets every new season.",
            de: "Elo (Standard-Tab) misst Können, nicht Fleiß: +10 beim Gewinnen einer offiziellen Partie, −3 beim Verlieren, ohne Anpassung an das Niveau des Gegners. \"Meiste Siege\" und \"Quote\" sind historisch und werden nie zurückgesetzt; Elo hingegen schon -- mit jeder neuen Saison."
        },
        "tab_mas_victorias": { es: "Más victorias", en: "Most wins", de: "Meiste Siege" },
        "tab_mejor_ratio": { es: "Mejor ratio", en: "Best ratio", de: "Beste Quote" },
        "vacio_ranking": {
            es: "Todavía no hay cuentas con partidas suficientes para aparecer en el ranking.",
            en: "There are no accounts yet with enough games to appear in the ranking.",
            de: "Es gibt noch keine Konten mit genug Partien, um in der Rangliste zu erscheinen."
        },
        "header_jugador": { es: "JUGADOR", en: "PLAYER", de: "SPIELER" },
        "header_elo": { es: "ELO", en: "ELO", de: "ELO" },
        "header_ganadas": { es: "GANADAS", en: "WINS", de: "SIEGE" },
        "header_partidas": { es: "PARTIDAS", en: "GAMES", de: "PARTIEN" },
        "header_ratio": { es: "RATIO", en: "RATIO", de: "QUOTE" },
        "podio_stat_elo": { es: "{0} Elo", en: "{0} Elo", de: "{0} Elo" },
        "podio_stat_ratio": {
            es: "{0}% de ratio", en: "{0}% ratio", de: "{0}% Quote"
        },
        "podio_stat_victorias": { es: "{0} victorias", en: "{0} wins", de: "{0} Siege" },
        "sufijo_tu": { es: " (tú)", en: " (you)", de: " (du)" },

        // ── Pantalla Torneos (placeholder + escalera Solitario) ─────────────
        "titulo_torneos": { es: "Torneos", en: "Tournaments", de: "Turniere" },
        "torneos_proximamente_descripcion": {
            es: "Organiza partidas por eliminatorias para un grupo fijo de jugadores -- como crear una sala, pero con llave de torneo.",
            en: "Organize elimination games for a fixed group of players -- like creating a room, but with a tournament bracket.",
            de: "Organisiere K.-o.-Partien für eine feste Gruppe von Spielern -- wie das Erstellen eines Raums, aber mit einem Turnierbaum."
        },
        "titulo_torneos_solitario": {
            es: "Torneos Solitario", en: "Solo Challenges", de: "Solo-Herausforderungen"
        },
        "torneos_solitario_subtitulo": {
            es: "Una escalera de 5 retos contra bots, cada uno más difícil que el anterior. Jugar no necesita conexión -- reclamar la recompensa, sí.",
            en: "A ladder of 5 challenges against bots, each harder than the last. Playing needs no connection -- claiming the reward does.",
            de: "Eine Leiter aus 5 Herausforderungen gegen Bots, jede schwerer als die vorherige. Spielen braucht keine Verbindung -- die Belohnung einlösen schon."
        },
        // Insignia + aviso de "todavía en obras" -- pedido explícito del
        // usuario (2026-09-15): dejar claro que esta sección concreta puede
        // cambiar bastante antes de llegar a la 1.0, para poder activarla
        // en el repo público (POKER_TORNEOS) sin prometer más de lo que hay.
        "etiqueta_experimental": { es: "Experimental", en: "Experimental", de: "Experimentell" },
        "torneos_solitario_aviso_experimental": {
            es: "Sección experimental: los retos, recompensas y reglas de esta escalera pueden cambiar bastante antes de la versión final.",
            en: "Experimental section: this ladder's challenges, rewards and rules may change a lot before the final version.",
            de: "Experimenteller Bereich: Herausforderungen, Belohnungen und Regeln dieser Leiter können sich vor der finalen Version noch stark ändern."
        },
        "marca_completado": { es: "✓ Completado", en: "✓ Completed", de: "✓ Abgeschlossen" },
        // Reward row del rediseño de tarjetas (2026-09-16, "menos texto,
        // que se entienda visualmente") -- sustituye a la vieja
        // "reto_recompensa" (una frase completa por tarjeta). Ahora es
        // "Recompensas:" + icono+número de Tréboles/XP + el sufijo del
        // título (el único que SÍ va escrito, pedido explícito del
        // usuario -- los demás son icono, no texto).
        "etiqueta_recompensas_reto": { es: "Recompensas:", en: "Rewards:", de: "Belohnungen:" },
        "sufijo_mas_titulo": { es: "+ título", en: "+ title", de: "+ Titel" },
        // Pedido explícito 2026-09-16: nada de icono para XP (un rayo
        // recuerda a "energía", no a experiencia) -- las letras tal
        // cual, en Torneos y en cualquier sitio que use XP a partir de
        // ahora.
        "etiqueta_xp_valor": { es: "{0} XP", en: "{0} XP", de: "{0} XP" },
        "etiqueta_mas_decoracion": { es: "+ {0}", en: "+ {0}", de: "+ {0}" },
        "boton_reclamar_recompensa": {
            es: "Reclamar recompensa", en: "Claim reward", de: "Belohnung einlösen"
        },
        "boton_reclamar_necesita_conexion": {
            es: "Necesitas conexión para reclamar", en: "You need a connection to claim",
            de: "Du brauchst eine Verbindung zum Einlösen"
        },
        "boton_jugar": { es: "Jugar", en: "Play", de: "Spielen" },
        "enlace_jugar_de_nuevo": { es: "Jugar de nuevo", en: "Play again", de: "Nochmal spielen" },
        "boton_continuar_reto": { es: "Continuar", en: "Continue", de: "Fortsetzen" },
        "boton_reclamar_logro": { es: "Reclamar", en: "Claim", de: "Abholen" },
        "etiqueta_logro_por_reclamar": { es: "¡Conseguido! Reclama tu recompensa (+%1 XP)", en: "Achieved! Claim your reward (+%1 XP)", de: "Geschafft! Hol dir deine Belohnung (+%1 XP)" },
        "error_logro_no_disponible": { es: "Este logro ya no se puede reclamar.", en: "This achievement can no longer be claimed.", de: "Diese Errungenschaft kann nicht mehr abgeholt werden." },
        "error_logro_no_existe": { es: "Logro desconocido.", en: "Unknown achievement.", de: "Unbekannte Errungenschaft." },
        "enlace_empezar_de_nuevo": { es: "Empezar de nuevo", en: "Start over", de: "Neu beginnen" },
        "reto_solitario_1_nombre": {
            es: "Reto 1 · Primeros pasos", en: "Challenge 1 · First steps",
            de: "Herausforderung 1 · Erste Schritte"
        },
        "reto_solitario_1_descripcion": {
            es: "2 bots, dificultad fácil, hasta que alguien se quede con todas las fichas.",
            en: "2 bots, easy difficulty, until someone takes all the chips.",
            de: "2 Bots, leichter Schwierigkeitsgrad, bis jemand alle Chips hat."
        },
        "reto_solitario_2_nombre": {
            es: "Reto 2 · Mesa concurrida", en: "Challenge 2 · Crowded table",
            de: "Herausforderung 2 · Voller Tisch"
        },
        "reto_solitario_2_descripcion": {
            es: "5 bots, dificultad fácil, hasta que alguien se quede con todas las fichas.",
            en: "5 bots, easy difficulty, until someone takes all the chips.",
            de: "5 Bots, leichter Schwierigkeitsgrad, bis jemand alle Chips hat."
        },
        "reto_solitario_3_nombre": {
            es: "Reto 3 · Cara a cara", en: "Challenge 3 · Face to face",
            de: "Herausforderung 3 · Von Angesicht zu Angesicht"
        },
        "reto_solitario_3_descripcion": {
            es: "1 solo bot, dificultad experta -- mano a mano, sin nadie más en la mesa.",
            en: "Just 1 bot, expert difficulty -- heads-up, no one else at the table.",
            de: "Nur 1 Bot, Experten-Schwierigkeitsgrad -- eins gegen eins, sonst niemand am Tisch."
        },
        "reto_solitario_4_nombre": {
            es: "Reto 4 · Contrarreloj", en: "Challenge 4 · Against the clock",
            de: "Herausforderung 4 · Gegen die Uhr"
        },
        "reto_solitario_4_descripcion": {
            es: "3 bots, dificultad normal, solo 12 manos -- gana quien más fichas tenga al final.",
            en: "3 bots, normal difficulty, only 12 hands -- whoever has the most chips at the end wins.",
            de: "3 Bots, normaler Schwierigkeitsgrad, nur 12 Hände -- wer am Ende die meisten Chips hat, gewinnt."
        },
        "reto_solitario_5_nombre": {
            es: "Reto 5 · La gran mesa", en: "Challenge 5 · The big table",
            de: "Herausforderung 5 · Der große Tisch"
        },
        "reto_solitario_5_descripcion": {
            es: "5 bots, dificultad experta -- el peldaño final de la escalera.",
            en: "5 bots, expert difficulty -- the final rung of the ladder.",
            de: "5 Bots, Experten-Schwierigkeitsgrad -- die letzte Sprosse der Leiter."
        },

        // ── Pantalla Social ──────────────────────────────────────────────────
        "titulo_social": { es: "Social", en: "Social", de: "Sozial" },
        "social_invitado_aviso": {
            es: "Estás jugando como invitado. Inicia sesión o crea una cuenta para añadir amigos y ver quién está conectado.",
            en: "You're playing as a guest. Log in or create an account to add friends and see who's online.",
            de: "Du spielst als Gast. Melde dich an oder erstelle ein Konto, um Freunde hinzuzufügen und zu sehen, wer online ist."
        },
        "tab_amigos": { es: "Amigos", en: "Friends", de: "Freunde" },
        "tab_buscar_jugadores": { es: "Buscar jugadores", en: "Find players", de: "Spieler suchen" },
        "tab_jugadores_recientes": { es: "Jugadores Recientes", en: "Recent Players", de: "Kürzliche Spieler" },
        "tab_solicitudes": { es: "Solicitudes", en: "Requests", de: "Anfragen" },
        // Etiquetas abreviadas -- solo qml-mobile/, ver el comentario junto
        // a tabsSocialMovil en Main.qml (landscape móvil deja menos ancho
        // por segmento).
        "tab_buscar_corto": { es: "Buscar", en: "Search", de: "Suchen" },
        "tab_recientes_corto": { es: "Recientes", en: "Recent", de: "Kürzlich" },
        "vacio_amigos": {
            es: "Todavía no tienes amigos añadidos. Búscalos en \"{0}\" o mira \"{1}\".",
            en: "You haven't added any friends yet. Search for them in \"{0}\" or check \"{1}\".",
            de: "Du hast noch keine Freunde hinzugefügt. Suche sie unter \"{0}\" oder schau bei \"{1}\" nach."
        },
        "prefijo_tu_dos_puntos": { es: "Tú: ", en: "You: ", de: "Du: " },
        "placeholder_toca_chatear": { es: "Toca para chatear", en: "Tap to chat", de: "Zum Chatten tippen" },
        "estado_conectado": { es: "Conectado", en: "Online", de: "Online" },
        "estado_en_partida": { es: "En partida", en: "In a game", de: "In einer Partie" },
        "estado_desconectado": { es: "Desconectado", en: "Offline", de: "Offline" },
        "chat_elige_conversacion": {
            es: "Elige una conversación de la lista", en: "Pick a conversation from the list",
            de: "Wähle eine Unterhaltung aus der Liste"
        },
        "placeholder_nombre_usuario": { es: "Nombre de usuario", en: "Username", de: "Benutzername" },
        "boton_buscar": { es: "Buscar", en: "Search", de: "Suchen" },
        "vacio_buscar_jugadores": {
            es: "Busca por nombre de usuario para mandar una solicitud de amistad.",
            en: "Search by username to send a friend request.",
            de: "Suche nach Benutzername, um eine Freundschaftsanfrage zu senden."
        },
        "estado_solicitud_enviada": { es: "Enviada", en: "Sent", de: "Gesendet" },
        "boton_enviar_solicitud": { es: "Enviar solicitud", en: "Send request", de: "Anfrage senden" },
        "vacio_jugadores_recientes": {
            es: "Todavía no has compartido mesa con nadie en las últimas 24h.",
            en: "You haven't shared a table with anyone in the last 24h.",
            de: "Du hast in den letzten 24 Stunden mit niemandem an einem Tisch gesessen."
        },
        "vacio_solicitudes": {
            es: "No tienes solicitudes de amistad pendientes.",
            en: "You have no pending friend requests.",
            de: "Du hast keine ausstehenden Freundschaftsanfragen."
        },
        "boton_rechazar": { es: "Rechazar", en: "Decline", de: "Ablehnen" },
        "boton_aceptar": { es: "Aceptar", en: "Accept", de: "Annehmen" },
        // Solo qml-mobile/ -- la "caja falsa" de búsqueda y el
        // CampoEmergente que abre (ver cajaBusquedaSocialMovil en Main.qml).
        "placeholder_buscar_username_movil": {
            es: "Buscar por nombre de usuario", en: "Search by username", de: "Nach Benutzername suchen"
        },
        "etiqueta_buscar_jugadores_movil": {
            es: "Buscar jugadores por nombre de usuario", en: "Find players by username",
            de: "Spieler nach Benutzername suchen"
        },

        // ── ChatBox.qml (chat de sala y chat directo, los dos árboles) ──────
        "yo_chat": { es: "Tú", en: "You", de: "Du" },
        "placeholder_mensaje_chat": {
            es: "Escribe un mensaje...", en: "Type a message...", de: "Nachricht schreiben..."
        },
        "boton_enviar": { es: "Enviar", en: "Send", de: "Senden" },

        // ── Pantalla Tienda ──────────────────────────────────────────────────
        "titulo_tienda": { es: "Tienda", en: "Shop", de: "Shop" },
        "tab_marco": { es: "Marco", en: "Frame", de: "Rahmen" },
        // Fase 1 de "segunda ola de cosméticos" (2026-09-17).
        "tab_mesa": { es: "Mesa", en: "Table", de: "Tisch" },
        "tab_perfil": { es: "Perfil", en: "Profile", de: "Profil" },
        "tienda_invitado_aviso": {
            es: "Inicia sesión para entrar en la tienda.", en: "Log in to enter the shop.",
            de: "Melde dich an, um den Shop zu betreten."
        },
        "placeholder_buscar_tienda": {
            es: "Buscar en la tienda...", en: "Search the shop...", de: "Im Shop suchen..."
        },
        // Solo qml-mobile/ -- el CampoEmergente que abre el botón de lupa
        // (sin puntos suspensivos, ver cabeceraTiendaMovil en Main.qml).
        "etiqueta_buscar_tienda_movil": {
            es: "Buscar en la tienda", en: "Search the shop", de: "Im Shop suchen"
        },
        "sufijo_equipado": { es: " · Equipado", en: " · Equipped", de: " · Ausgerüstet" },
        "etiqueta_nivel": { es: "· nivel {0}", en: "· level {0}", de: "· Stufe {0}" },
        "etiqueta_logro": { es: "Logro: {0}", en: "Achievement: {0}", de: "Erfolg: {0}" },
        "texto_se_consigue_con_logro": {
            es: "Se consigue con un logro", en: "Obtained through an achievement",
            de: "Wird durch einen Erfolg freigeschaltet"
        },
        "boton_comprar": { es: "Comprar", en: "Buy", de: "Kaufen" },
        "boton_comprado": { es: "Comprado", en: "Owned", de: "Erworben" },
        // Mismo estado final visiblemente inactivo que "boton_comprado",
        // pero para objetos que vinieron de un logro (nunca se compraron) --
        // pedido explícito 2026-09-17.
        "boton_obtenido": { es: "Obtenido", en: "Obtained", de: "Erhalten" },
        "boton_quitar_izq": { es: "Quitar izq.", en: "Remove left", de: "Links entfernen" },
        "boton_a_la_izq": { es: "A la izq.", en: "To the left", de: "Nach links" },
        "boton_quitar_der": { es: "Quitar der.", en: "Remove right", de: "Rechts entfernen" },
        "boton_a_la_der": { es: "A la der.", en: "To the right", de: "Nach rechts" },
        "titulo_vista_previa": { es: "VISTA PREVIA", en: "PREVIEW", de: "VORSCHAU" },
        "vista_previa_sin_marco": {
            es: "Así se verá con tu primer marco, Hierro. Gana una partida para desbloquear los accesorios.",
            en: "This is how it'll look with your first frame, Iron. Win a game to unlock accessories.",
            de: "So sieht es mit deinem ersten Rahmen aus, Eisen. Gewinne eine Partie, um Zubehör freizuschalten."
        },

        // ── PopupAcabado.qml (elegir metal al equipar, los dos árboles) ─────
        "popup_deco_lado": { es: "¿En qué lado?", en: "Which side?", de: "Welche Seite?" },
        "lado_izquierda": { es: "Izquierda", en: "Left", de: "Links" },
        "lado_derecha": { es: "Derecha", en: "Right", de: "Rechts" },
        "lado_ambos": { es: "Ambos lados", en: "Both sides", de: "Beide Seiten" },
        "popup_acabado_titulo": { es: "Elige el acabado", en: "Choose the finish", de: "Wähle das Finish" },
        "popup_acabado_descripcion": {
            es: "Los metales de los marcos que ya has conseguido. Con el de tu marco, la decoración sube con él cuando tu marco suba.",
            en: "The metals of the frames you've already earned. With your frame's own metal, the decoration upgrades with it when your frame does.",
            de: "Die Metalle der Rahmen, die du bereits erhalten hast. Mit dem Metall deines eigenen Rahmens steigt die Dekoration mit ihm auf."
        },
        "etiqueta_tu_marco": { es: "tu marco", en: "your frame", de: "dein Rahmen" },
        "boton_modificar": { es: "Modificar", en: "Change", de: "Ändern" },
        "boton_cerrar": { es: "Cerrar", en: "Close", de: "Schließen" },
        "boton_cancelar": { es: "Cancelar", en: "Cancel", de: "Abbrechen" },
        "boton_equipar": { es: "Equipar", en: "Equip", de: "Ausrüsten" },

        // ── PopupSeleccionCarta.qml (elegir carta de la baraja, escritorio) ──
        "popup_carta_titulo": { es: "Elige una carta", en: "Choose a card", de: "Wähle eine Karte" },
        "popup_carta_descripcion": {
            es: "Toca una carta para elegirla -- se verá en la previsualización. Comprar o equipar la que elijas se hace desde la propia tarjeta de la Tienda.",
            en: "Tap a card to choose it -- it'll show in the preview. Buying or equipping the one you choose is done from the shop card itself.",
            de: "Tippe auf eine Karte, um sie auszuwählen -- sie erscheint in der Vorschau. Die gewählte Karte wird über die Shop-Karte selbst gekauft oder ausgerüstet."
        },
        "palo_treboles": { es: "Tréboles", en: "Clubs", de: "Kreuz" },
        "palo_diamantes": { es: "Diamantes", en: "Diamonds", de: "Karo" },
        "palo_corazones": { es: "Corazones", en: "Hearts", de: "Herz" },
        "palo_picas": { es: "Picas", en: "Spades", de: "Pik" },

        // ── Pantalla Cuenta ──────────────────────────────────────────────────
        "titulo_cuenta": { es: "Cuenta", en: "Account", de: "Konto" },
        "cuenta_invitado_aviso": {
            es: "Estás jugando como invitado. Inicia sesión o crea una cuenta para ver tu perfil, tus estadísticas y gestionarla.",
            en: "You're playing as a guest. Log in or create an account to see your profile, your stats, and manage it.",
            de: "Du spielst als Gast. Melde dich an oder erstelle ein Konto, um dein Profil und deine Statistiken zu sehen und zu verwalten."
        },
        "tab_progreso": { es: "Progreso", en: "Progress", de: "Fortschritt" },
        "tab_logros": { es: "Logros", en: "Achievements", de: "Erfolge" },
        "tab_personalizar": { es: "Personalizar", en: "Customize", de: "Anpassen" },
        "cuenta_offline_aviso": {
            es: "Sin conexión · datos de tu última sesión con el servidor, solo lectura.",
            en: "Offline · data from your last session with the server, read-only.",
            de: "Offline · Daten aus deiner letzten Sitzung mit dem Server, nur lesbar."
        },
        "titulo_estadisticas": { es: "ESTADÍSTICAS", en: "STATISTICS", de: "STATISTIKEN" },
        "stat_partidas_jugadas": { es: "Partidas jugadas", en: "Games played", de: "Gespielte Partien" },
        "stat_partidas_oficiales_ganadas": {
            es: "Partidas oficiales ganadas", en: "Official games won", de: "Gewonnene offizielle Partien"
        },
        "sufijo_stat_partidas_ganadas": {
            es: "{0} partidas oficiales ganadas", en: "{0} official games won",
            de: "{0} offizielle Partien gewonnen"
        },
        "stat_ratio_victorias": { es: "Ratio de victorias", en: "Win ratio", de: "Gewinnquote" },
        "stat_racha_actual": { es: "Racha actual", en: "Current streak", de: "Aktuelle Serie" },
        "stat_mejor_racha": { es: "Mejor racha", en: "Best streak", de: "Beste Serie" },
        "stat_manos_jugadas": { es: "Manos jugadas", en: "Hands played", de: "Gespielte Hände" },
        "stat_manos_ganadas": { es: "Manos ganadas", en: "Hands won", de: "Gewonnene Hände" },
        "stat_mayor_bote_ganado": { es: "Mayor bote ganado", en: "Biggest pot won", de: "Größter gewonnener Pot" },
        "stat_mejor_mano": { es: "Mejor mano", en: "Best hand", de: "Beste Hand" },
        "titulo_combinaciones_mostradas": {
            es: "COMBINACIONES MOSTRADAS", en: "HANDS SHOWN", de: "GEZEIGTE HÄNDE"
        },
        "combo_carta_alta": { es: "Carta alta", en: "High Card", de: "Höchste Karte" },
        "combo_pareja": { es: "Pareja", en: "Pair", de: "Ein Paar" },
        "combo_doble_pareja": { es: "Doble pareja", en: "Two Pair", de: "Zwei Paare" },
        "combo_trio": { es: "Trío", en: "Three of a Kind", de: "Drilling" },
        "combo_escalera": { es: "Escalera", en: "Straight", de: "Straße" },
        "combo_color": { es: "Color", en: "Flush", de: "Flush" },
        "combo_full_house": { es: "Full House", en: "Full House", de: "Full House" },
        "combo_poker": { es: "Póker", en: "Four of a Kind", de: "Vierling" },
        "combo_escalera_color": { es: "Escalera de color", en: "Straight Flush", de: "Straight Flush" },
        "combo_escalera_real": { es: "Escalera real", en: "Royal Flush", de: "Royal Flush" },
        "vacio_partidas_oficiales": {
            es: "Todavía no tienes partidas oficiales registradas.",
            en: "You don't have any official games recorded yet.",
            de: "Du hast noch keine offiziellen Partien aufgezeichnet."
        },
        "boton_cambiar_username": {
            es: "Cambiar nombre de usuario", en: "Change username", de: "Benutzernamen ändern"
        },
        "placeholder_nuevo_username": {
            es: "Nuevo nombre de usuario", en: "New username", de: "Neuer Benutzername"
        },
        "boton_confirmar": { es: "Confirmar", en: "Confirm", de: "Bestätigen" },
        "boton_cambiar_password": { es: "Cambiar contraseña", en: "Change password", de: "Passwort ändern" },
        "placeholder_password_actual": {
            es: "Contraseña actual", en: "Current password", de: "Aktuelles Passwort"
        },
        "placeholder_password_nueva": {
            es: "Contraseña nueva (8+ caracteres)", en: "New password (8+ characters)",
            de: "Neues Passwort (8+ Zeichen)"
        },
        "error_falta_password_actual": {
            es: "Escribe tu contraseña actual.", en: "Enter your current password.",
            de: "Gib dein aktuelles Passwort ein."
        },
        "error_password_nueva_corta": {
            es: "La contraseña nueva debe tener al menos 8 caracteres.",
            en: "The new password must be at least 8 characters long.",
            de: "Das neue Passwort muss mindestens 8 Zeichen lang sein."
        },
        "boton_cerrar_sesion": { es: "Cerrar sesión", en: "Log out", de: "Abmelden" },
        "boton_exportar_estadisticas": {
            es: "Exportar estadísticas (admin)", en: "Export statistics (admin)",
            de: "Statistiken exportieren (Admin)"
        },
        "texto_exportando": { es: "Exportando...", en: "Exporting...", de: "Exportiere..." },
        "admin_titulo_conceder": {
            es: "Conceder logro/objeto (admin)", en: "Grant achievement/item (admin)",
            de: "Erfolg/Objekt gewähren (Admin)"
        },
        "placeholder_username_destino": {
            es: "Username destino", en: "Target username", de: "Ziel-Benutzername"
        },
        "placeholder_codigo_logro_objeto": {
            es: "Código (logro u objeto de tienda)", en: "Code (achievement or shop item)",
            de: "Code (Erfolg oder Shop-Objekt)"
        },
        "boton_conceder": { es: "Conceder", en: "Grant", de: "Gewähren" },
        "error_admin_rellena_campos": {
            es: "Rellena username y código.", en: "Fill in username and code.",
            de: "Fülle Benutzername und Code aus."
        },
        "texto_concediendo": { es: "Concediendo...", en: "Granting...", de: "Gewähre..." },
        "boton_fabricar_cuentas_prueba": {
            es: "Fabricar 15 cuentas de prueba (admin)", en: "Create 15 test accounts (admin)",
            de: "15 Testkonten erstellen (Admin)"
        },
        "texto_fabricando": { es: "Fabricando...", en: "Creating...", de: "Erstelle..." },
        // Pedido explícito 2026-09-16 -- "necesito poder asignar marcos,
        // por ejemplo el de hierro que no se le dio a mi amigo". Reutiliza
        // el mismo campo de username que "Conceder logro/objeto" de
        // arriba.
        "boton_conceder_marco_hierro": {
            es: "Conceder marco Hierro (admin)", en: "Grant Iron frame (admin)",
            de: "Rahmen Eisen gewähren (Admin)"
        },
        "error_admin_rellena_username": {
            es: "Rellena el username.", en: "Fill in the username.", de: "Fülle den Benutzernamen aus."
        },
        "marca_hierro_concedido": {
            es: "Marco Hierro concedido.", en: "Iron frame granted.", de: "Rahmen Eisen gewährt."
        },
        "progreso_invitado_aviso": {
            es: "Inicia sesión para ver tu progreso hacia el siguiente marco de avatar.",
            en: "Log in to see your progress toward the next avatar frame.",
            de: "Melde dich an, um deinen Fortschritt zum nächsten Avatar-Rahmen zu sehen."
        },
        "etiqueta_xp_siguiente_nivel": {
            es: "{0} / {1} XP para el siguiente nivel", en: "{0} / {1} XP to the next level",
            de: "{0} / {1} XP bis zur nächsten Stufe"
        },
        "etiqueta_marco_actual": { es: "Marco actual: {0}", en: "Current frame: {0}", de: "Aktueller Rahmen: {0}" },
        "etiqueta_siguiente_marco": {
            es: "Siguiente marco: {0}", en: "Next frame: {0}", de: "Nächster Rahmen: {0}"
        },
        "etiqueta_victorias_progreso": {
            es: "{0} / {1} victorias", en: "{0} / {1} wins", de: "{0} / {1} Siege"
        },
        "texto_marco_maximo": {
            es: "Has desbloqueado el marco más alto: {0}.", en: "You've unlocked the highest frame: {0}.",
            de: "Du hast den höchsten Rahmen freigeschaltet: {0}."
        },
        "texto_ganar_partidas_para_avanzar": {
            es: "Gana partidas oficiales (con otras personas reales) para avanzar de marco.",
            en: "Win official games (with other real people) to advance your frame.",
            de: "Gewinne offizielle Partien (mit anderen echten Personen), um deinen Rahmen zu verbessern."
        },
        "titulo_todos_los_marcos": { es: "Todos los marcos", en: "All frames", de: "Alle Rahmen" },
        "texto_conseguido": { es: "Conseguido", en: "Unlocked", de: "Freigeschaltet" },
        "marco_hierro": { es: "Hierro", en: "Iron", de: "Eisen" },
        "marco_bronce": { es: "Bronce", en: "Bronze", de: "Bronze" },
        "marco_plata": { es: "Plata", en: "Silver", de: "Silber" },
        "marco_oro": { es: "Oro", en: "Gold", de: "Gold" },
        "marco_platino": { es: "Platino", en: "Platinum", de: "Platin" },
        "marco_ninguno": { es: "Sin marco", en: "No frame", de: "Kein Rahmen" },
        "logros_invitado_aviso": {
            es: "Inicia sesión para ver tus logros.", en: "Log in to see your achievements.",
            de: "Melde dich an, um deine Erfolge zu sehen."
        },
        "etiqueta_logros_desbloqueados": {
            es: "{0} / {1} desbloqueados", en: "{0} / {1} unlocked", de: "{0} / {1} freigeschaltet"
        },
        "etiqueta_logro_desbloqueado_fecha": {
            es: "Desbloqueado el {0} · +{1} XP", en: "Unlocked on {0} · +{1} XP",
            de: "Freigeschaltet am {0} · +{1} XP"
        },
        "texto_logro_puntual": { es: "Puntual", en: "One-time", de: "Einmalig" },
        "personalizar_invitado_aviso": {
            es: "Inicia sesión para personalizar tu avatar.", en: "Log in to customize your avatar.",
            de: "Melde dich an, um deinen Avatar anzupassen."
        },
        "tab_texturas": { es: "Texturas", en: "Textures", de: "Texturen" },
        "tab_efectos": { es: "Efectos", en: "Effects", de: "Effekte" },
        "tab_decoraciones": { es: "Decoraciones", en: "Decorations", de: "Dekorationen" },
        "tab_titulos": { es: "Títulos", en: "Titles", de: "Titel" },
        // Fase 1 de "segunda ola de cosméticos" (2026-09-17).
        "tab_reversos": { es: "Reversos", en: "Card backs", de: "Kartenrückseiten" },
        "vacio_personalizar": {
            es: "Todavía no tienes nada de esto -- consíguelo en la Tienda.",
            en: "You don't have any of these yet -- get them in the Shop.",
            de: "Davon hast du noch nichts -- hol es dir im Shop."
        },
        "boton_quitar": { es: "Quitar", en: "Remove", de: "Entfernen" },
        // Solo qml-mobile/: aviso de invitado con redacción propia (no
        // menciona "estadísticas", el resto del texto de Cuenta sí las
        // separa por pestaña) y etiquetas más cortas que caben mejor en
        // una pantalla estrecha.
        "cuenta_invitado_aviso_movil": {
            es: "Estás jugando como invitado. Inicia sesión o crea una cuenta para ver tu perfil, tu progreso y tus logros.",
            en: "You're playing as a guest. Log in or create an account to see your profile, your progress, and your achievements.",
            de: "Du spielst als Gast. Melde dich an oder erstelle ein Konto, um dein Profil, deinen Fortschritt und deine Erfolge zu sehen."
        },
        "etiqueta_password_nueva_movil": {
            es: "Contraseña nueva", en: "New password", de: "Neues Passwort"
        },
        "etiqueta_siguiente_marco_corto": {
            es: "Siguiente: {0}", en: "Next: {0}", de: "Nächster: {0}"
        },
        "titulo_tu_avatar": { es: "TU AVATAR", en: "YOUR AVATAR", de: "DEIN AVATAR" },
        "titulo_tu_mesa": { es: "TU MESA", en: "YOUR TABLE", de: "DEIN TISCH" },

        // ── Cajón de Ajustes ─────────────────────────────────────────────────
        "titulo_ajustes": { es: "AJUSTES", en: "SETTINGS", de: "EINSTELLUNGEN" },
        "titulo_tema_color": { es: "TEMA DE COLOR", en: "COLOR THEME", de: "FARBTHEMA" },
        "tema_verde_clasico": { es: "Verde clásico", en: "Classic Green", de: "Klassisches Grün" },
        "tema_azul_medianoche": { es: "Azul medianoche", en: "Midnight Blue", de: "Mitternachtsblau" },
        "tema_burdeos": { es: "Burdeos", en: "Burgundy", de: "Burgund" },
        "tema_grafito": { es: "Grafito", en: "Graphite", de: "Graphit" },
        "tema_porcelana_dorada": { es: "Porcelana dorada", en: "Golden Porcelain", de: "Goldenes Porzellan" },
        "tema_taberna_real": { es: "Taberna real", en: "Royal Tavern", de: "Königliche Taverne" },
        "titulo_mesa_actual": { es: "MESA ACTUAL", en: "CURRENT TABLE", de: "AKTUELLER TISCH" },
        "ajustes_ciega_actual": { es: "Ciega actual", en: "Current blind", de: "Aktuelles Blind" },
        "ajustes_mano": { es: "Mano", en: "Hand", de: "Hand" },
        "ajustes_tipo_limite": { es: "Tipo de límite", en: "Limit type", de: "Limit-Typ" },
        "ajustes_permite_recompra": { es: "Permite recompra", en: "Allows rebuy", de: "Erlaubt Rebuy" },
        "ajustes_rellena_bots": { es: "Rellena con bots", en: "Fills with bots", de: "Füllt mit Bots auf" },
        "ajustes_pregunta_extender": {
            es: "Pregunta al extender", en: "Asks when extending", de: "Fragt beim Verlängern"
        },
        "ajustes_codigo_invitacion": {
            es: "Código de invitación", en: "Invite code", de: "Einladungscode"
        },
        "limite_sin_limite": { es: "Sin límite", en: "No limit", de: "No Limit" },
        "limite_limite_bote": { es: "Límite bote", en: "Pot limit", de: "Pot Limit" },
        "limite_limite_fijo": { es: "Límite fijo", en: "Fixed limit", de: "Fixed Limit" },
        "texto_si": { es: "Sí", en: "Yes", de: "Ja" },
        "texto_no": { es: "No", en: "No", de: "Nein" },
        "titulo_cliente": { es: "CLIENTE", en: "CLIENT", de: "CLIENT" },
        "titulo_idioma": { es: "Idioma", en: "Language", de: "Sprache" },
        "texto_sonido_notificaciones": {
            es: "Sonido de notificaciones", en: "Notification sound", de: "Benachrichtigungston"
        },
        "texto_confirmar_allin": {
            es: "Confirmar antes de ALL-IN", en: "Confirm before ALL-IN", de: "Vor ALL-IN bestätigen"
        },
        "texto_tamano_interfaz": {
            es: "Tamaño de la interfaz", en: "Interface size", de: "Oberflächengröße"
        },
        "titulo_version": { es: "VERSIÓN", en: "VERSION", de: "VERSION" },
        "etiqueta_version_instalada": {
            es: "Instalada: v{0}", en: "Installed: v{0}", de: "Installiert: v{0}"
        },
        "etiqueta_version_nueva_disponible": {
            es: " · hay una nueva: v{0}", en: " · a new one is available: v{0}",
            de: " · eine neue ist verfügbar: v{0}"
        },
        "boton_descargar_version": {
            es: "Descargar la última versión", en: "Download the latest version",
            de: "Neueste Version herunterladen"
        },
        "boton_ver_version_github": {
            es: "Ver la última versión en GitHub", en: "View the latest version on GitHub",
            de: "Neueste Version auf GitHub ansehen"
        },

        // ── Pantalla Lobby (sala de espera) ──────────────────────────────────
        "titulo_sala_de": { es: "Sala de {0}", en: "{0}'s Room", de: "{0}s Raum" },
        "titulo_sala_espera": { es: "Sala de espera", en: "Waiting Room", de: "Warteraum" },
        "etiqueta_listos": { es: "{0} / {1} listos", en: "{0} / {1} ready", de: "{0} / {1} bereit" },
        "etiqueta_codigo_invitar": {
            es: "Código para invitar: {0}", en: "Invite code: {0}", de: "Einladungscode: {0}"
        },
        "texto_copiado": { es: "Copiado", en: "Copied", de: "Kopiert" },
        "boton_copiar": { es: "Copiar", en: "Copy", de: "Kopieren" },
        "etiqueta_nombres_esperados": {
            es: "Nombres esperados: {0}", en: "Expected names: {0}", de: "Erwartete Namen: {0}"
        },
        "boton_empezar_ahora": { es: "Empezar ahora", en: "Start now", de: "Jetzt starten" },
        "boton_invitar_amigos": { es: "Invitar amigos", en: "Invite friends", de: "Freunde einladen" },
        "boton_abandonar_sala": { es: "Abandonar sala", en: "Leave room", de: "Raum verlassen" },
        "etiqueta_esperando_sentarse": {
            es: "Esperando a sentarse: {0}", en: "Waiting to sit down: {0}", de: "Warten auf Platznahme: {0}"
        },

        // ── Pantalla Partida (Mesa) ──────────────────────────────────────────
        "etiqueta_estado_mesa": {
            es: "{0} · Mano {1} · Ciega {2}/{3} · Turno de {4}",
            en: "{0} · Hand {1} · Blind {2}/{3} · {4}'s turn",
            de: "{0} · Hand {1} · Blind {2}/{3} · {4} ist am Zug"
        },
        "titulo_ranking_manos": { es: "Ranking de manos", en: "Hand ranking", de: "Handrangliste" },
        "etiqueta_combo_actual": { es: "ACTUAL", en: "CURRENT", de: "AKTUELL" },
        "etiqueta_combo_probable": { es: "PROBABLE", en: "LIKELY", de: "WAHRSCHEINLICH" },
        "etiqueta_combo_maxima": { es: "MÁXIMA", en: "BEST POSSIBLE", de: "MAXIMAL" },
        "boton_retirarse": { es: "Retirarse", en: "Fold", de: "Aussteigen" },
        "boton_igualar": { es: "Igualar · {0}", en: "Call · {0}", de: "Mitgehen · {0}" },
        "boton_pasar": { es: "Pasar", en: "Check", de: "Schieben" },
        "boton_subir": { es: "Subir", en: "Raise", de: "Erhöhen" },
        "texto_all": { es: "ALL", en: "ALL", de: "ALL" },
        "texto_sin_fichas": {
            es: "Te has quedado sin fichas", en: "You've run out of chips", de: "Du hast keine Chips mehr"
        },
        "texto_recompra_enviada": { es: "Recompra enviada…", en: "Rebuy sent…", de: "Rebuy gesendet…" },
        "boton_recomprar": { es: "Recomprar", en: "Rebuy", de: "Rebuy" },
        "texto_ventana_pequena": {
            es: "La ventana es demasiado pequeña para mostrar la partida correctamente.\nAgrándala para continuar.",
            en: "The window is too small to display the game correctly.\nMake it bigger to continue.",
            de: "Das Fenster ist zu klein, um die Partie korrekt anzuzeigen.\nVergrößere es, um fortzufahren."
        },
        "texto_conexion_perdida": {
            es: "Conexión perdida — reconectando...", en: "Connection lost — reconnecting...",
            de: "Verbindung verloren — Wiederverbindung..."
        },
        "etiqueta_segundos_restantes": {
            es: "{0}s restantes", en: "{0}s remaining", de: "Noch {0}s"
        },
        "titulo_showdown": { es: "SHOWDOWN", en: "SHOWDOWN", de: "SHOWDOWN" },
        "etiqueta_bote_total": { es: "Bote: {0}", en: "Pot: {0}", de: "Pot: {0}" },
        "etiqueta_bote_principal": { es: "Bote principal", en: "Main pot", de: "Hauptpot" },
        "etiqueta_side_pot": { es: "Side pot {0}", en: "Side pot {0}", de: "Side Pot {0}" },
        "etiqueta_compiten": { es: " — compiten {0}", en: " — competing: {0}", de: " — es kämpfen: {0}" },
        "etiqueta_gano_bote": { es: " · ganó {0} (+{1})", en: " · {0} won (+{1})", de: " · {0} hat gewonnen (+{1})" },
        "titulo_fin_mano": { es: "Fin de la mano", en: "End of hand", de: "Ende der Hand" },
        "boton_si_extender": { es: "Sí, extender", en: "Yes, extend", de: "Ja, verlängern" },
        "boton_no_terminar": { es: "No, terminar aquí", en: "No, end here", de: "Nein, hier beenden" },
        "texto_gano_sin_mostrar": {
            es: "Se llevó el bote sin mostrar cartas", en: "Took the pot without showing cards",
            de: "Hat den Pot gewonnen, ohne Karten zu zeigen"
        },
        "boton_continuar_siguiente_mano": {
            es: "Continuar a la siguiente mano", en: "Continue to the next hand",
            de: "Weiter zur nächsten Hand"
        },
        "boton_abandonar_partida": { es: "Abandonar partida", en: "Leave game", de: "Partie verlassen" },
        "boton_guardar_salir": { es: "Guardar y salir", en: "Save and exit", de: "Speichern und beenden" },
        "titulo_confirmar_abandono": {
            es: "¿Abandonar la partida?", en: "Leave the game?", de: "Partie verlassen?"
        },
        "texto_confirmar_abandono_descripcion": {
            es: "Se contará como partida perdida en tus estadísticas si la partida ya lleva manos suficientes jugadas. Tus fichas se reparten entre el resto.",
            en: "It will count as a loss in your statistics if the game has already played enough hands. Your chips are split among the rest.",
            de: "Es zählt in deinen Statistiken als Niederlage, wenn die Partie schon genug Hände gespielt hat. Deine Chips werden unter den übrigen aufgeteilt."
        },
        "boton_abandonar": { es: "Abandonar", en: "Leave", de: "Verlassen" },
        "tab_historial": { es: "Historial", en: "History", de: "Verlauf" },
        "tab_chat": { es: "Chat", en: "Chat", de: "Chat" },
        // BarraSuperior.qml -- compartida por (casi) todas las pantallas.
        "texto_reconectando_corto": {
            es: "Reconectando… · ", en: "Reconnecting… · ", de: "Verbindung wird wiederhergestellt… · "
        },
        "boton_salir_sesion": { es: "Salir", en: "Exit", de: "Verlassen" },
        // PopupPerfilJugador.qml
        "texto_cargando_perfil": { es: "Cargando perfil...", en: "Loading profile...", de: "Profil wird geladen..." },
        "texto_jugador_no_existe": {
            es: "Ese jugador ya no existe.", en: "That player no longer exists.",
            de: "Dieser Spieler existiert nicht mehr."
        },
        "etiqueta_logros_porcentaje": {
            es: "{0} / {1} logros ({2}%)", en: "{0} / {1} achievements ({2}%)", de: "{0} / {1} Erfolge ({2}%)"
        },
        // Distinto de stat_partidas_oficiales_ganadas (Cuenta) -- este
        // popup de perfil AJENO nunca recibió el cambio de etiqueta
        // pedido para el propio (ver docs/plan-idiomas.md), así que
        // conserva su texto real tal cual, sin renombrarlo de más.
        "stat_partidas_ganadas": { es: "Partidas ganadas", en: "Games won", de: "Gewonnene Partien" },
        "texto_sin_estadisticas_ajenas": {
            es: "Todavía no tiene estadísticas registradas.", en: "Doesn't have any statistics recorded yet.",
            de: "Hat noch keine Statistiken erfasst."
        },
        // PopupInvitarAmigos.qml
        "titulo_invitar_sala": { es: "Invitar a la sala", en: "Invite to the room", de: "In den Raum einladen" },
        "vacio_amigos_conectados": {
            es: "Ninguno de tus amigos está conectado ahora mismo.",
            en: "None of your friends are online right now.",
            de: "Gerade ist keiner deiner Freunde online."
        },
        "boton_invitar": { es: "Invitar", en: "Invite", de: "Einladen" },
        "invitacion_enviada": { es: "Invitación enviada.", en: "Invitation sent.", de: "Einladung gesendet." },
        // BannerInvitacionSala.qml
        "etiqueta_invitacion_sala": {
            es: "{0} te invitó a su sala", en: "{0} invited you to their room", de: "{0} hat dich zu seinem Raum eingeladen"
        },
        "boton_descartar": { es: "Descartar", en: "Dismiss", de: "Verwerfen" },
        // BannerVersionNueva.qml
        "etiqueta_version_nueva_banner": {
            es: "Hay una versión nueva disponible (v{0})", en: "A new version is available (v{0})",
            de: "Eine neue Version ist verfügbar (v{0})"
        },
        "boton_ver": { es: "Ver", en: "View", de: "Ansehen" },
        // Solo qml-mobile/ -- pista de scroll del overlay de showdown.
        "texto_mas_abajo": { es: "más abajo", en: "more below", de: "weiter unten" },
        // CajonPartida.qml -- solo qml-mobile/ (el cajón de pestañas que
        // sustituye la barra de acciones + PanelLateral de escritorio).
        "tab_turno": { es: "Turno", en: "Turn", de: "Zug" },
        "tab_cartas": { es: "Cartas", en: "Cards", de: "Karten" },
        "tab_estimacion": { es: "Estim.", en: "Est.", de: "Sch." },
        "titulo_tus_cartas": { es: "TUS CARTAS", en: "YOUR CARDS", de: "DEINE KARTEN" },
        "etiqueta_turno_de": { es: "Turno de {0}", en: "{0}'s turn", de: "{0} ist am Zug" },
        "etiqueta_ronda_mano": {
            es: "{0} · Mano {1} / {2}", en: "{0} · Hand {1} / {2}", de: "{0} · Hand {1} / {2}"
        },
        // Sin el punto medio de boton_igualar (escritorio) -- versión más
        // compacta para el botón estrecho del cajón móvil.
        "boton_igualar_movil": { es: "Igualar {0}", en: "Call {0}", de: "Mitgehen {0}" },
        "texto_sin_fichas_corto": { es: "Sin fichas", en: "Out of chips", de: "Keine Chips mehr" },
        "texto_enviada_corta": { es: "Enviada…", en: "Sent…", de: "Gesendet…" },
        // SelectorNumerico.qml -- solo qml-mobile/ (stepper de subida/manos extra).
        "etiqueta_valor_exacto": { es: "Valor exacto", en: "Exact value", de: "Genauer Wert" },

        // ── Pantalla Fin (resultado de la partida) ──────────────────────────
        "titulo_partida_guardada": { es: "PARTIDA GUARDADA", en: "GAME SAVED", de: "PARTIE GESPEICHERT" },
        "titulo_partida_finalizada": { es: "PARTIDA FINALIZADA", en: "GAME OVER", de: "PARTIE BEENDET" },
        "etiqueta_ganador": { es: "Ganador", en: "Winner", de: "Gewinner" },
        "etiqueta_fichas": { es: "{0} fichas", en: "{0} chips", de: "{0} Chips" },
        "texto_fin_por_limite": {
            es: "Se alcanzó el límite de manos.", en: "The hand limit was reached.",
            de: "Das Handlimit wurde erreicht."
        },
        "texto_fin_por_eliminacion": {
            es: "El resto de jugadores ha quedado eliminado.", en: "The rest of the players have been eliminated.",
            de: "Die übrigen Spieler wurden eliminiert."
        },
        "etiqueta_manos_disputadas": {
            es: "Manos disputadas: {0}", en: "Hands played: {0}", de: "Gespielte Hände: {0}"
        },
        "titulo_mejor_mano_partida": {
            es: "MEJOR MANO DE LA PARTIDA", en: "BEST HAND OF THE GAME", de: "BESTE HAND DER PARTIE"
        },
        "texto_sigue_en_juego": { es: "Sigue en juego", en: "Still in the game", de: "Noch im Spiel" },
        "etiqueta_mano_numero": { es: "Mano {0}", en: "Hand {0}", de: "Hand {0}" },
        "texto_host_puede_continuar": {
            es: "El Host puede continuar la partida desde sus partidas guardadas.",
            en: "The Host can continue the game from their saved games.",
            de: "Der Host kann die Partie über seine gespeicherten Partien fortsetzen."
        },
        "boton_volver_a_salas": { es: "Volver a salas", en: "Back to rooms", de: "Zurück zu den Räumen" },

        // ── Pantalla CrearSala ───────────────────────────────────────────────
        "titulo_partida_local_seccion": {
            es: "PARTIDA LOCAL", en: "LOCAL GAME", de: "LOKALES SPIEL"
        },
        "etiqueta_numero_bots": {
            es: "Número de bots (rivales)", en: "Number of bots (opponents)", de: "Anzahl Bots (Gegner)"
        },
        "titulo_seccion_sala": { es: "SALA", en: "ROOM", de: "RAUM" },
        "placeholder_nombre_sala": {
            es: "Nombre de la sala", en: "Room name", de: "Raumname"
        },
        "etiqueta_sala_publica": { es: "Sala pública", en: "Public room", de: "Öffentlicher Raum" },
        "etiqueta_tamano_sala": {
            es: "Tamaño de sala (asientos totales, máx. 9)",
            en: "Room size (total seats, max. 9)",
            de: "Raumgröße (Plätze insgesamt, max. 9)"
        },
        "etiqueta_rellenar_bots": {
            es: "Rellenar con bots los asientos vacíos", en: "Fill empty seats with bots",
            de: "Leere Plätze mit Bots auffüllen"
        },
        "texto_ayuda_rellenar_bots": {
            es: "Si faltan humanos al arrancar (o alguien se va con fichas), un bot ocupa el asiento en vez de perderlo o repartir sus fichas.",
            en: "If there aren't enough humans at the start (or someone leaves with chips), a bot takes the seat instead of losing it or splitting the chips.",
            de: "Fehlen beim Start Menschen (oder verlässt jemand das Spiel mit Chips), übernimmt ein Bot den Platz, statt ihn zu verlieren oder die Chips aufzuteilen."
        },
        "etiqueta_abierta_tras_iniciar": {
            es: "Abierta tras iniciar", en: "Open after starting", de: "Offen nach dem Start"
        },
        "texto_ayuda_abierta_tras_iniciar": {
            es: "Con esto activo, cualquier asiento ocupado por un bot se puede sustituir por un jugador nuevo en cualquier momento de la partida.",
            en: "With this on, any seat occupied by a bot can be replaced by a new player at any point in the game.",
            de: "Ist dies aktiv, kann jeder von einem Bot besetzte Platz jederzeit während der Partie von einem neuen Spieler übernommen werden."
        },
        "titulo_seccion_reglas_apuesta": {
            es: "REGLAS DE APUESTA", en: "BETTING RULES", de: "SETZREGELN"
        },
        "etiqueta_dificultad_bots": { es: "Dificultad de bots", en: "Bot difficulty", de: "Bot-Schwierigkeit" },
        "dificultad_facil": { es: "Fácil", en: "Easy", de: "Leicht" },
        "dificultad_normal": { es: "Normal", en: "Normal", de: "Normal" },
        "dificultad_experto": { es: "Experto", en: "Expert", de: "Experte" },
        "etiqueta_monte_fijo": { es: "Cantidad fija por raise", en: "Fixed raise amount", de: "Fester Erhöhungsbetrag" },
        "etiqueta_min_raise_obligatorio": {
            es: "Min-raise obligatorio", en: "Mandatory min-raise", de: "Mindest-Erhöhung Pflicht"
        },
        "etiqueta_permitir_recompra": {
            es: "Permitir recompra al quedarse sin fichas", en: "Allow rebuy when out of chips",
            de: "Rebuy erlauben, wenn keine Chips mehr vorhanden sind"
        },
        "titulo_seccion_partida": { es: "PARTIDA", en: "GAME", de: "PARTIE" },
        "etiqueta_numero_manos": { es: "Número de manos", en: "Number of hands", de: "Anzahl Hände" },
        "etiqueta_preguntar_extension": {
            es: "Preguntar si extender al llegar al límite de manos",
            en: "Ask whether to extend when the hand limit is reached",
            de: "Beim Erreichen des Handlimits nach Verlängerung fragen"
        },
        "etiqueta_ciega_grande": { es: "Ciega grande", en: "Big blind", de: "Big Blind" },
        "etiqueta_saldo_inicial": { es: "Saldo inicial", en: "Starting stack", de: "Startguthaben" },
        "boton_empezar_partida": { es: "Empezar partida", en: "Start game", de: "Partie starten" },
        // Solo qml-mobile/: dos etiquetas más cortas que su equivalente de
        // escritorio, sin "totales"/"de manos" -- caben mejor en la
        // columna estrecha del formulario móvil.
        "etiqueta_tamano_sala_movil": {
            es: "Tamaño de sala (asientos, máx. 9)", en: "Room size (seats, max. 9)",
            de: "Raumgröße (Plätze, max. 9)"
        },
        "etiqueta_preguntar_extension_movil": {
            es: "Preguntar si extender al llegar al límite",
            en: "Ask whether to extend when the limit is reached",
            de: "Beim Erreichen des Limits nach Verlängerung fragen"
        },
        // Solo qml-mobile/ -- CampoEmergente para el nombre propio (guest)
        // y para renombrar una partida guardada.
        "etiqueta_tu_nombre": { es: "Tu nombre", en: "Your name", de: "Dein Name" },
        "etiqueta_nuevo_nombre": { es: "Nuevo nombre", en: "New name", de: "Neuer Name" },
        // Nombre de la tarjeta sintética "la baraja entera" en el
        // catálogo de la Tienda (los dos árboles) -- ver esCartaBaraja().
        "nombre_carta_baraja": { es: "Carta de póker", en: "Poker card", de: "Pokerkarte" },
        // Prefijo del nombre de invitado generado al azar ("Invitado42891")
        // -- sin dependencias en C++/otro QML que busquen este texto
        // literal, seguro de traducir sin más (los dos árboles).
        "prefijo_invitado": { es: "Invitado", en: "Guest", de: "Gast" },
        // Prefijo de mensajeErrorConexion cuando NetworkClient manda un
        // error de conexión genérico (onError) -- el resto del mensaje
        // sigue viniendo en español fijo del servidor (ver el punto 3 de
        // docs/plan-idiomas.md), esto solo traduce la palabra "Error:".
        "prefijo_error": { es: "Error: ", en: "Error: ", de: "Fehler: " },
        "boton_renombrar": { es: "Renombrar", en: "Rename", de: "Umbenennen" },
        "boton_borrar": { es: "Borrar", en: "Delete", de: "Löschen" },

        // ── Errores genéricos de red (NetworkClient.hpp) ────────────────────
        "error_conexion_timeout": {
            es: "No se pudo conectar con el servidor. Inténtalo de nuevo.",
            en: "Couldn't connect to the server. Please try again.",
            de: "Verbindung zum Server fehlgeschlagen. Bitte versuche es erneut."
        },

        // ── Torneos > Solitario: reclamarRecompensaReto (AccountManager.cpp) --
        // primer ejemplo real de "el servidor manda claves, el cliente
        // traduce" (ver docs/plan-idiomas.md) -- estas claves son las que
        // ahora manda el servidor en vez de la frase ya hecha.
        "error_sesion_invalida": {
            es: "Sesión no válida.", en: "Invalid session.", de: "Ungültige Sitzung."
        },
        "error_reto_no_existe": {
            es: "Ese reto no existe.", en: "That challenge doesn't exist.",
            de: "Diese Herausforderung gibt es nicht."
        },
        "error_reto_orden": {
            es: "Completa antes el reto anterior de la escalera.",
            en: "Complete the previous challenge in the ladder first.",
            de: "Schließe zuerst die vorherige Herausforderung der Leiter ab."
        },
        "error_reto_ya_reclamado": {
            es: "Ya reclamaste este reto.", en: "You already claimed this challenge.",
            de: "Du hast diese Herausforderung bereits eingelöst."
        },
        "reto_reclamado_treboles": {
            es: "+{0} Tréboles.", en: "+{0} Clovers.", de: "+{0} Kleeblätter."
        },

        // ── Mensajes de error/aviso que el servidor mandaba en prosa fija
        // (AccountManager.cpp/src/server/main.cpp), terminando docs/plan-idiomas.md
        // "Lo que falta" punto 2 (2026-09-15). Mismo criterio que el reto de
        // arriba: el servidor manda la CLAVE, el cliente la traduce -- ya
        // envuelto en Idioma.t()/resolverMensajeServidor() en todos los
        // sitios donde se muestran (mensajeErrorLogin, mensajeErrorSocial,
        // mensajeTienda, mensajeErrorConexion), así que no hizo falta tocar
        // QML aparte de esas envolturas. Las 3 con "{0}" llevan un dato que
        // el servidor no puede convertir a clave (nivel mínimo, lista de
        // nombres, texto de excepción) -- viajan como "clave:valor"
        // (resolverMensajeServidor() las separa y llama a tf()).
        "error_usuario_existente": {
            es: "Ese nombre de usuario ya existe.", en: "That username already exists.",
            de: "Dieser Benutzername existiert bereits."
        },
        "error_login_incorrecto": {
            es: "Usuario o contraseña incorrectos.", en: "Incorrect username or password.",
            de: "Falscher Benutzername oder falsches Passwort."
        },
        "error_sesion_caducada": {
            es: "Sesión caducada, inicia sesión de nuevo.", en: "Session expired, please log in again.",
            de: "Sitzung abgelaufen, bitte melde dich erneut an."
        },
        "error_password_actual_incorrecta": {
            es: "La contraseña actual no es correcta.", en: "The current password is incorrect.",
            de: "Das aktuelle Passwort ist falsch."
        },
        "error_usuario_no_existe": {
            es: "Ese usuario no existe.", en: "That user doesn't exist.", de: "Diesen Benutzer gibt es nicht."
        },
        "error_solicitud_a_ti_mismo": {
            es: "No puedes enviarte una solicitud a ti mismo.",
            en: "You can't send a request to yourself.",
            de: "Du kannst dir selbst keine Anfrage schicken."
        },
        "error_ya_sois_amigos": {
            es: "Ya sois amigos.", en: "You're already friends.", de: "Ihr seid bereits befreundet."
        },
        "error_solicitud_pendiente": {
            es: "Ya hay una solicitud pendiente con ese jugador.",
            en: "There's already a pending request with that player.",
            de: "Es gibt bereits eine ausstehende Anfrage mit diesem Spieler."
        },
        "error_solicitud_no_existe": {
            es: "Esa solicitud ya no existe.", en: "That request no longer exists.",
            de: "Diese Anfrage existiert nicht mehr."
        },
        "error_solicitud_ajena": {
            es: "Esa solicitud no es tuya.", en: "That request isn't yours.",
            de: "Diese Anfrage gehört dir nicht."
        },
        "error_mensaje_a_ti_mismo": {
            es: "No puedes enviarte un mensaje a ti mismo.",
            en: "You can't send a message to yourself.",
            de: "Du kannst dir selbst keine Nachricht schicken."
        },
        "error_mensaje_vacio": {
            es: "El mensaje no puede estar vacío.", en: "The message can't be empty.",
            de: "Die Nachricht darf nicht leer sein."
        },
        "error_mensaje_muy_largo": {
            es: "El mensaje es demasiado largo (máximo 1000 caracteres).",
            en: "The message is too long (1000 characters max).",
            de: "Die Nachricht ist zu lang (maximal 1000 Zeichen)."
        },
        "error_solo_amigos": {
            es: "Solo puedes escribir a tus amigos.", en: "You can only write to your friends.",
            de: "Du kannst nur deinen Freunden schreiben."
        },
        "error_sin_estadisticas": {
            es: "La cuenta no tiene estadísticas todavía.", en: "The account has no statistics yet.",
            de: "Das Konto hat noch keine Statistiken."
        },
        "aviso_xp_offline_recortado": {
            es: "Parte del XP sin conexión no se ha acreditado (límite por tiempo de juego).",
            en: "Some of your offline XP wasn't credited (limited by play time).",
            de: "Ein Teil deiner Offline-XP wurde nicht gutgeschrieben (durch die Spielzeit begrenzt)."
        },
        "aviso_progreso_offline_recortado": {
            es: "Parte del progreso sin conexión no se ha acreditado (límite por tiempo de juego).",
            en: "Some of your offline progress wasn't credited (limited by play time).",
            de: "Ein Teil deines Offline-Fortschritts wurde nicht gutgeschrieben (durch die Spielzeit begrenzt)."
        },
        "error_objeto_no_existe": {
            es: "Ese objeto no existe.", en: "That item doesn't exist.", de: "Dieses Objekt gibt es nicht."
        },
        "error_objeto_de_logro": {
            es: "Ese objeto no se compra -- se consigue con un logro.",
            en: "That item can't be bought -- it's earned through an achievement.",
            de: "Dieses Objekt kann nicht gekauft werden -- man erhält es durch eine Errungenschaft."
        },
        "error_ya_tienes_objeto": {
            es: "Ya tienes ese objeto.", en: "You already have that item.", de: "Du hast dieses Objekt bereits."
        },
        "error_cuenta_sin_estadisticas": {
            es: "Cuenta sin estadísticas -- inténtalo de nuevo.",
            en: "Account has no statistics -- try again.",
            de: "Konto ohne Statistiken -- versuche es erneut."
        },
        "error_marco_no_desbloqueado": {
            es: "Gana tu primera partida para desbloquear accesorios de marco.",
            en: "Win your first game to unlock frame accessories.",
            de: "Gewinne deine erste Partie, um Rahmen-Zubehör freizuschalten."
        },
        "error_nivel_insuficiente": {
            es: "Necesitas nivel {0} para este objeto.", en: "You need level {0} for this item.",
            de: "Du brauchst Level {0} für dieses Objekt."
        },
        "error_treboles_insuficientes": {
            es: "No tienes suficientes Tréboles.", en: "You don't have enough Clovers.",
            de: "Du hast nicht genug Kleeblätter."
        },
        "error_slot_invalido": {
            es: "Slot no válido.", en: "Invalid slot.", de: "Ungültiger Slot."
        },
        "error_hueco_sin_acabado": {
            es: "Ese hueco no lleva acabado.", en: "That slot doesn't take a finish.",
            de: "Dieser Slot hat keine Oberfläche."
        },
        "error_acabado_invalido": {
            es: "Acabado no válido.", en: "Invalid finish.", de: "Ungültige Oberfläche."
        },
        "error_objeto_no_encaja": {
            es: "Ese objeto no encaja en ese hueco.", en: "That item doesn't fit in that slot.",
            de: "Dieses Objekt passt nicht in diesen Slot."
        },
        "error_no_tienes_objeto": {
            es: "No tienes ese objeto.", en: "You don't have that item.", de: "Du hast dieses Objekt nicht."
        },
        "error_acabado_marco_no_tienes": {
            es: "Ese acabado es de un marco que todavía no tienes.",
            en: "That finish belongs to a frame you don't have yet.",
            de: "Diese Oberfläche gehört zu einem Rahmen, den du noch nicht hast."
        },
        "error_admin_sin_permiso": {
            es: "No tienes permiso de administrador.", en: "You don't have administrator permission.",
            de: "Du hast keine Administratorberechtigung."
        },
        "error_codigo_no_valido": {
            es: "Ese código no es ni un logro ni un objeto de tienda.",
            en: "That code is neither an achievement nor a shop item.",
            de: "Dieser Code ist weder eine Errungenschaft noch ein Shop-Objekt."
        },
        "error_admin_fabricar_fallo": {
            es: "No se pudo crear ninguna cuenta de prueba.",
            en: "Couldn't create any test accounts.",
            de: "Es konnten keine Testkonten erstellt werden."
        },
        "error_nombre_en_uso_sala": {
            es: "Ese nombre ya está en uso en esta sala. Elige otro.",
            en: "That name is already in use in this room. Choose another one.",
            de: "Dieser Name wird in diesem Raum bereits verwendet. Wähle einen anderen."
        },
        "error_nombre_no_reconocido_guardada": {
            es: "Nombre no reconocido en la partida guardada. Esperados: {0}",
            en: "Name not recognized in the saved game. Expected: {0}",
            de: "Name in der gespeicherten Partie nicht erkannt. Erwartet: {0}"
        },
        "aviso_en_espera_proxima_mano": {
            es: "Te sentarás en cuanto empiece la próxima mano.",
            en: "You'll take a seat as soon as the next hand starts.",
            de: "Du setzt dich, sobald die nächste Hand beginnt."
        },
        "error_sala_no_disponible": {
            es: "La sala no existe, está llena o no admite más jugadores.",
            en: "The room doesn't exist, is full, or isn't accepting more players.",
            de: "Der Raum existiert nicht, ist voll oder nimmt keine weiteren Spieler mehr auf."
        },
        "error_partida_ajena": {
            es: "Esa partida guardada no te pertenece.", en: "That saved game doesn't belong to you.",
            de: "Diese gespeicherte Partie gehört dir nicht."
        },
        "error_cargar_partida": {
            es: "No se pudo cargar la partida: {0}", en: "Couldn't load the game: {0}",
            de: "Die Partie konnte nicht geladen werden: {0}"
        },
        "error_exportar_sin_permiso": {
            es: "No tienes permiso para exportar estadísticas.",
            en: "You don't have permission to export statistics.",
            de: "Du hast keine Berechtigung, Statistiken zu exportieren."
        },
        "error_exportar_escritura": {
            es: "No se pudo escribir el fichero en el servidor.",
            en: "Couldn't write the file on the server.",
            de: "Die Datei konnte nicht auf dem Server geschrieben werden."
        },
        "error_partida_ya_no_existe": {
            es: "La partida ya no existe: terminó mientras estabas desconectado.",
            en: "The game no longer exists: it ended while you were disconnected.",
            de: "Die Partie existiert nicht mehr: sie endete, während du getrennt warst."
        },
        "error_conexion_perdida": {
            es: "Se perdió la conexión con el servidor.", en: "Connection to the server was lost.",
            de: "Die Verbindung zum Server wurde unterbrochen."
        },
        // Avisos de votación de fin de mano/extensión de partida -- mismo
        // barrido, encontrados al comprobar cada sitio que muestra un
        // "mensaje" de servidor sin envolver. "_offline" son la variante
        // (más corta, sin servidor real detrás) de LocalGameObserver.hpp --
        // divergen a propósito del texto online, no se unificó la
        // redacción al convertir a clave, solo se tradujo tal cual estaba.
        "error_nombre_invalido": {
            es: "Nombre inválido.", en: "Invalid name.", de: "Ungültiger Name."
        },
        "error_sala_llena": {
            es: "La sala ya no admite más jugadores.", en: "The room isn't accepting more players.",
            de: "Der Raum nimmt keine weiteren Spieler mehr auf."
        },
        "aviso_esperar_voto_extension": {
            es: "Se ha alcanzado el límite de manos establecido para esta partida. ¿Quieres continuar jugando? Hace falta que todos los jugadores acepten para extenderla.",
            en: "This game's hand limit has been reached. Do you want to keep playing? Every player needs to agree to extend it.",
            de: "Das Handlimit dieser Partie wurde erreicht. Möchtest du weiterspielen? Alle Spieler müssen zustimmen, um zu verlängern."
        },
        "aviso_esperando_eleccion_manos": {
            es: "Todos los jugadores han aceptado continuar. Esperando a que {0} elija cuántas manos más se jugarán.",
            en: "Everyone agreed to continue. Waiting for {0} to choose how many more hands to play.",
            de: "Alle haben zugestimmt weiterzuspielen. Warte, bis {0} auswählt, wie viele Hände noch gespielt werden."
        },
        "aviso_elegir_manos_extra": {
            es: "Todos los jugadores han aceptado continuar. ¿Cuántas manos más quieres añadir?",
            en: "Everyone agreed to continue. How many more hands do you want to add?",
            de: "Alle haben zugestimmt weiterzuspielen. Wie viele Hände möchtest du noch hinzufügen?"
        },
        "aviso_abandonaste": {
            es: "Abandonaste la partida. Tus fichas se reparten.",
            en: "You left the game. Your chips are being distributed.",
            de: "Du hast die Partie verlassen. Deine Chips werden verteilt."
        },
        "aviso_esperar_voto_extension_offline": {
            es: "¿Quieres seguir jugando más allá del límite de manos?",
            en: "Do you want to keep playing past the hand limit?",
            de: "Möchtest du über das Handlimit hinaus weiterspielen?"
        },
        "aviso_elegir_manos_extra_offline": {
            es: "¿Cuántas manos más quieres añadir?", en: "How many more hands do you want to add?",
            de: "Wie viele Hände möchtest du noch hinzufügen?"
        },
        "aviso_abandonaste_offline": {
            es: "Abandonaste la partida.", en: "You left the game.", de: "Du hast die Partie verlassen."
        },

        // ── Catálogo de logros y tienda (dato del SERVIDOR, ver
        // AccountManager.cpp::kCatalogoLogros/semillaTienda) -- claves por
        // "codigo", no envueltas por t()/tf() directamente: se resuelven
        // con nombreLogroLocalizado()/descripcionLogroLocalizado()/
        // nombreObjetoLocalizado() (Main.qml, los dos árboles), que caen
        // de vuelta al texto en español que manda el servidor si el
        // "codigo" no tiene fila aquí -- así un objeto/logro nuevo en el
        // servidor se ve en español hasta traducirlo aquí, nunca roto. La
        // localización se aplica UNA VEZ, al llegar onLogrosActualizados/
        // onTiendaActualizada -- si cambias de idioma con el catálogo ya
        // cargado, hace falta volver a pedirlo (entrar de nuevo en
        // Cuenta/Tienda) para que se re-resuelva, ver docs/plan-idiomas.md.
        "logro_primera_sangre_nombre": { es: "Primera sangre", en: "First Blood", de: "Erstes Blut" },
        "logro_primera_sangre_descripcion": {
            es: "Gana tu primera partida oficial.", en: "Win your first official game.",
            de: "Gewinne deine erste offizielle Partie."
        },
        "logro_trasnochador_nombre": { es: "Trasnochador", en: "Night Owl", de: "Nachtschwärmer" },
        "logro_trasnochador_descripcion": {
            es: "Termina una partida después de medianoche.", en: "Finish a game after midnight.",
            de: "Beende eine Partie nach Mitternacht."
        },
        "logro_club_de_los_cien_nombre": { es: "Club de los Cien", en: "Century Club", de: "Klub der Hundert" },
        "logro_club_de_los_cien_descripcion": {
            es: "Juega 100 manos en total.", en: "Play 100 hands in total.",
            de: "Spiele insgesamt 100 Hände."
        },
        "logro_manos_de_hierro_nombre": { es: "Manos de Hierro", en: "Iron Hands", de: "Eiserne Hände" },
        "logro_manos_de_hierro_descripcion": {
            es: "Gana 5 manos oficiales seguidas sin retirarte.",
            en: "Win 5 official hands in a row without folding.",
            de: "Gewinne 5 offizielle Hände in Folge, ohne auszusteigen."
        },
        "logro_circulo_cerrado_nombre": { es: "Círculo cerrado", en: "Inner Circle", de: "Geschlossener Kreis" },
        "logro_circulo_cerrado_descripcion": {
            es: "Juega una partida oficial con 4 o más amigos a la vez en tu mesa.",
            en: "Play an official game with 4 or more friends at your table at once.",
            de: "Spiele eine offizielle Partie mit 4 oder mehr Freunden gleichzeitig an deinem Tisch."
        },
        "logro_el_farolero_nombre": { es: "El Farolero", en: "The Bluffer", de: "Der Bluffer" },
        "logro_el_farolero_descripcion": {
            es: "Gana un bote sin showdown 15 veces.", en: "Win a pot without a showdown 15 times.",
            de: "Gewinne 15-mal einen Pot ohne Showdown."
        },
        "logro_el_fenix_nombre": { es: "El Fénix", en: "The Phoenix", de: "Der Phönix" },
        "logro_el_fenix_descripcion": {
            es: "Gana una mano tras entrar en ella con menos del 10% de tu stack inicial en juego.",
            en: "Win a hand after entering it with less than 10% of your starting stack in play.",
            de: "Gewinne eine Hand, nachdem du mit weniger als 10 % deines Startstacks eingestiegen bist."
        },
        "logro_la_corona_nombre": { es: "La Corona", en: "The Crown", de: "Die Krone" },
        "logro_la_corona_descripcion": {
            es: "Muestra una escalera real en un showdown.", en: "Show a royal flush at a showdown.",
            de: "Zeige einen Royal Flush bei einem Showdown."
        },
        "logro_escalera_color_nombre": { es: "Escalera de Color", en: "Straight Flush", de: "Straight Flush" },
        "logro_escalera_color_descripcion": {
            es: "Muestra una escalera de color en un showdown.", en: "Show a straight flush at a showdown.",
            de: "Zeige einen Straight Flush bei einem Showdown."
        },
        "logro_poker_ases_nombre": { es: "Póker de Ases", en: "Quad Aces", de: "Vierling Asse" },
        "logro_poker_ases_descripcion": {
            es: "Consigue un póker de ases en un showdown.", en: "Get four of a kind aces at a showdown.",
            de: "Erziele einen Vierling Asse bei einem Showdown."
        },
        "logro_barrida_total_nombre": { es: "Rey de la Mesa", en: "King of the Table", de: "König des Tisches" },
        "logro_barrida_total_descripcion": {
            es: "Gana una partida quedándote con todas las fichas de la mesa.",
            en: "Win a game by taking every chip at the table.",
            de: "Gewinne eine Partie, indem du alle Chips am Tisch einsammelst."
        },
        "logro_centurion_nombre": { es: "Centurión", en: "Centurion", de: "Zenturio" },
        "logro_centurion_descripcion": {
            es: "Gana 100 manos en total.", en: "Win 100 hands in total.", de: "Gewinne insgesamt 100 Hände."
        },
        "logro_reto_solitario_1_nombre": { es: "Aprendiz de mesa", en: "Table Apprentice", de: "Tischlehrling" },
        "logro_reto_solitario_1_descripcion": {
            es: "Gana el primer reto de Torneos Solitario (2 bots, fácil).",
            en: "Win the first Solo Challenge (2 bots, easy).",
            de: "Gewinne die erste Solo-Herausforderung (2 Bots, leicht)."
        },
        "logro_reto_solitario_2_nombre": {
            es: "Cazador de mesa llena", en: "Full Table Hunter", de: "Jäger des vollen Tisches"
        },
        "logro_reto_solitario_2_descripcion": {
            es: "Gana el segundo reto de Torneos Solitario (5 bots, fácil).",
            en: "Win the second Solo Challenge (5 bots, easy).",
            de: "Gewinne die zweite Solo-Herausforderung (5 Bots, leicht)."
        },
        "logro_reto_solitario_3_nombre": { es: "Duelista", en: "Duelist", de: "Duellant" },
        "logro_reto_solitario_3_descripcion": {
            es: "Gana el tercer reto de Torneos Solitario (cara a cara contra un bot experto).",
            en: "Win the third Solo Challenge (heads-up against an expert bot).",
            de: "Gewinne die dritte Solo-Herausforderung (eins gegen eins gegen einen Experten-Bot)."
        },
        "logro_reto_solitario_4_nombre": {
            es: "Rápido y certero", en: "Fast and Precise", de: "Schnell und Treffsicher"
        },
        "logro_reto_solitario_4_descripcion": {
            es: "Gana el cuarto reto de Torneos Solitario (contrarreloj, manos limitadas).",
            en: "Win the fourth Solo Challenge (against the clock, limited hands).",
            de: "Gewinne die vierte Solo-Herausforderung (Zeitdruck, begrenzte Hände)."
        },
        "logro_reto_solitario_5_nombre": {
            es: "Rey del Solitario", en: "King of Solo Play", de: "König des Solospiels"
        },
        "logro_reto_solitario_5_descripcion": {
            es: "Gana el quinto y último reto de Torneos Solitario (5 bots expertos).",
            en: "Win the fifth and final Solo Challenge (5 expert bots).",
            de: "Gewinne die fünfte und letzte Solo-Herausforderung (5 Experten-Bots)."
        },

        // Objetos de tienda: tanto los COMPRABLES sueltos como los que
        // concede un logro (títulos y decoraciones -- mismo "shop_items",
        // ver AccountManager.cpp) comparten esta única tabla por código.
        "objeto_titulo_primera_sangre_nombre": { es: "Primera sangre", en: "First Blood", de: "Erstes Blut" },
        "objeto_titulo_trasnochador_nombre": { es: "Trasnochador", en: "Night Owl", de: "Nachtschwärmer" },
        "objeto_titulo_club_cien_nombre": { es: "Club de los Cien", en: "Century Club", de: "Klub der Hundert" },
        "objeto_titulo_manos_hierro_nombre": { es: "Manos de hierro", en: "Iron Hands", de: "Eiserne Hände" },
        "objeto_titulo_circulo_cerrado_nombre": {
            es: "Círculo cerrado", en: "Inner Circle", de: "Geschlossener Kreis"
        },
        "objeto_ojo_vigilante_nombre": { es: "Ojo vigilante", en: "Watchful Eye", de: "Wachsames Auge" },
        "objeto_titulo_farolero_nombre": { es: "El Farolero", en: "The Bluffer", de: "Der Bluffer" },
        "objeto_colmillo_nombre": { es: "Colmillo", en: "Fang", de: "Reißzahn" },
        "objeto_titulo_fenix_nombre": { es: "El Fénix", en: "The Phoenix", de: "Der Phönix" },
        "objeto_mano_real_nombre": { es: "Mano Real", en: "Royal Hand", de: "Königliche Hand" },
        "objeto_titulo_mano_real_nombre": { es: "Mano Real", en: "Royal Hand", de: "Königliche Hand" },
        "objeto_escalera_diamantes_nombre": {
            es: "Escalera de diamantes", en: "Diamond Staircase", de: "Diamant-Treppe"
        },
        "objeto_titulo_escalon_encima_nombre": {
            es: "Un escalón por encima", en: "A Cut Above", de: "Eine Stufe darüber"
        },
        "objeto_cuatro_ases_nombre": { es: "Cuatro ases", en: "Four Aces", de: "Vier Asse" },
        "objeto_titulo_as_bajo_manga_nombre": {
            es: "As bajo la manga", en: "Ace Up the Sleeve", de: "Ass im Ärmel"
        },
        "objeto_corona_real_nombre": { es: "Corona real", en: "Royal Crown", de: "Königskrone" },
        "objeto_titulo_rey_mesa_nombre": { es: "Rey de la mesa", en: "King of the Table", de: "König des Tisches" },
        "objeto_titulo_centurion_nombre": { es: "Centurión", en: "Centurion", de: "Zenturio" },
        "objeto_titulo_aprendiz_mesa_nombre": {
            es: "Aprendiz de mesa", en: "Table Apprentice", de: "Tischlehrling"
        },
        "objeto_titulo_cazador_mesa_nombre": {
            es: "Cazador de mesa llena", en: "Full Table Hunter", de: "Jäger des vollen Tisches"
        },
        "objeto_titulo_duelista_nombre": { es: "Duelista", en: "Duelist", de: "Duellant" },
        "objeto_titulo_rapido_certero_nombre": {
            es: "Rápido y certero", en: "Fast and Precise", de: "Schnell und Treffsicher"
        },
        "objeto_titulo_rey_solitario_nombre": {
            es: "Rey del Solitario", en: "King of Solo Play", de: "König des Solospiels"
        },
        // Comprables sueltos (sin logro detrás).
        "objeto_trenzado_nombre": { es: "Trenzado", en: "Braided", de: "Geflochten" },
        "objeto_grabado_nombre": { es: "Grabado", en: "Engraved", de: "Graviert" },
        "objeto_facetado_nombre": { es: "Facetado", en: "Faceted", de: "Facettiert" },
        "objeto_canto_ficha_nombre": { es: "Canto de ficha", en: "Chip Edge", de: "Chip-Kante" },
        "objeto_pulso_nombre": { es: "Pulso", en: "Pulse", de: "Puls" },
        "objeto_gema_roja_nombre": { es: "Gema engastada (roja)", en: "Set Gem (red)", de: "Gefasster Edelstein (rot)" },
        "objeto_gema_azul_nombre": {
            es: "Gema engastada (azul)", en: "Set Gem (blue)", de: "Gefasster Edelstein (blau)"
        },
        "objeto_punto_de_luz_nombre": { es: "Punto de luz", en: "Point of Light", de: "Lichtpunkt" },
        "objeto_pila_fichas_nombre": { es: "Pila de fichas", en: "Chip Stack", de: "Chipstapel" },
        "objeto_cinta_ondulada_nombre": { es: "Cinta ondulada", en: "Wavy Ribbon", de: "Gewelltes Band" },
        "objeto_corona_laurel_nombre": { es: "Corona de laurel", en: "Laurel Crown", de: "Lorbeerkrone" },
        "objeto_constelacion_nombre": { es: "Constelación", en: "Constellation", de: "Konstellation" },
        "objeto_palos_en_fila_nombre": { es: "Palos en fila", en: "Suits in a Row", de: "Farben in einer Reihe" },
        "objeto_corona_inicial_nombre": { es: "Corona inicial", en: "Starter Crown", de: "Anfangskrone" },
        "objeto_titulo_buena_estrella_nombre": { es: "Buena estrella", en: "Lucky Star", de: "Glücksstern" },
        "objeto_titulo_perro_viejo_nombre": { es: "Perro viejo", en: "Old Hand", de: "Alter Hase" },
        "objeto_titulo_veterano_nombre": { es: "Veterano", en: "Veteran", de: "Veteran" },
        "objeto_titulo_implacable_nombre": { es: "Implacable", en: "Relentless", de: "Unerbittlich" },
        "objeto_titulo_sangre_fria_nombre": { es: "Sangre fría", en: "Cold Blood", de: "Kaltblütig" },
        "objeto_titulo_tahur_nombre": { es: "Tahúr", en: "Card Shark", de: "Kartenhai" },
        "objeto_titulo_cara_piedra_nombre": { es: "Cara de piedra", en: "Poker Face", de: "Pokerface" },
        "objeto_titulo_nervios_acero_nombre": { es: "Nervios de acero", en: "Nerves of Steel", de: "Nerven aus Stahl" },
        "objeto_titulo_ultima_ficha_nombre": { es: "Última ficha", en: "Last Chip", de: "Letzter Chip" },
        "objeto_titulo_rompebancas_nombre": { es: "Rompebancas", en: "Bank Breaker", de: "Bankbrecher" },
        "objeto_titulo_la_casa_nombre": { es: "La Casa", en: "The House", de: "Das Haus" },
        // Reverso de cartas -- Fase 1 de la "segunda ola de cosméticos".
        "objeto_reverso_azul_real_nombre": { es: "Azul real", en: "Royal Blue", de: "Königsblau" },
        "objeto_reverso_esmeralda_nombre": { es: "Esmeralda", en: "Emerald", de: "Smaragd" },
        "objeto_reverso_carmesi_nombre": { es: "Carmesí", en: "Crimson", de: "Karmesinrot" },
        "objeto_reverso_obsidiana_nombre": { es: "Obsidiana", en: "Obsidian", de: "Obsidian" },
        "objeto_reverso_taberna_nombre": { es: "Taberna", en: "Tavern", de: "Taverne" },
        // Tapetes de mesa (2026-09-19).
        "objeto_tapete_rombos_nombre": { es: "Rombos", en: "Diamonds", de: "Rauten" },
        "objeto_tapete_palos_nombre": { es: "Palos", en: "Suits", de: "Farben" },
        "objeto_tapete_puntos_nombre": { es: "Puntos", en: "Dots", de: "Punkte" },
        "objeto_tapete_lino_nombre": { es: "Lino", en: "Linen", de: "Leinen" },
        "objeto_tapete_rayas_nombre": { es: "Rayas", en: "Stripes", de: "Streifen" },
        "objeto_tapete_casino_nombre": { es: "Casino", en: "Casino", de: "Casino" },
        "objeto_tapete_madera_nombre": { es: "Madera", en: "Wood", de: "Holz" },
        "tapete_variante_verde": { es: "Verde", en: "Green", de: "Grün" },
        "tapete_variante_granate": { es: "Granate", en: "Garnet", de: "Granat" },
        "tapete_variante_azul": { es: "Azul", en: "Blue", de: "Blau" },
        "tapete_variante_grafito": { es: "Grafito", en: "Graphite", de: "Graphit" },
        "tapete_variante_taberna": { es: "Taberna", en: "Tavern", de: "Taverne" },
        "tapete_variante_porcelana": { es: "Porcelana", en: "Porcelain", de: "Porzellan" },
        "tapete_variante_violeta": { es: "Violeta", en: "Violet", de: "Violett" },
        "tapete_variante_petroleo": { es: "Petróleo", en: "Teal", de: "Petrol" },
        "tapete_variante_roble": { es: "Roble", en: "Oak", de: "Eiche" },
        "tapete_variante_roble_oscuro": { es: "Roble oscuro", en: "Dark oak", de: "Dunkle Eiche" },
        "tapete_variante_nogal": { es: "Nogal", en: "Walnut", de: "Nussbaum" },
        "popup_tapete_descripcion_pano": { es: "Elige el color del paño. Puedes cambiarlo cuando quieras, sin coste.", en: "Pick the felt colour. You can change it any time, at no cost.", de: "Wähle die Farbe des Tuchs. Du kannst sie jederzeit kostenlos ändern." },
        "popup_tapete_descripcion_madera": { es: "Elige el tipo de madera. Puedes cambiarlo cuando quieras, sin coste.", en: "Pick the wood. You can change it any time, at no cost.", de: "Wähle das Holz. Du kannst es jederzeit kostenlos ändern." },
        "texto_ver_mi_tapete": {
            es: "Ver mi tapete (si no, el del anfitrión)", en: "Show my table (otherwise the host's)",
            de: "Meinen Tisch anzeigen (sonst den des Gastgebers)"
        },
        "texto_tapete_sin_equipado": {
            es: "Tapete: el del anfitrión (equipa uno para elegir)",
            en: "Table: the host's (equip one to choose)",
            de: "Tisch: der des Gastgebers (rüste einen aus, um zu wählen)"
        },
    })
}
