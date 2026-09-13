// Idioma.qml — traducción de la interfaz (Fase de idiomas, ver
// docs/plan-idiomas.md). Singleton -- mismo criterio que Tema.qml: NO se
// comparte con qml-mobile/ (son dos árboles QML independientes, "nada se
// hereda automáticamente"), así que hay una copia gemela en
// qml-mobile/Idioma.qml que hay que mantener en el mismo estado.
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
    })
}
