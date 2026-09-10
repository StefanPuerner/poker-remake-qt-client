/**
 * @file Protocol.hpp
 * @brief Protocolo de mensajes servidor↔cliente: tipos, framing y primitivas de I/O.
 */
#pragma once

#include <cstdint>
#include <stdexcept>
#include <string>
#include <vector>
#include <utility>

/**
 * @brief Protocolo de mensajes servidor↔cliente.
 *
 * Formato en el cable:
 * @code
 *   ┌──────────────┬────────────────────────────────────────┐
 *   │  4 bytes     │  N bytes                               │
 *   │  uint32 BE   │  JSON UTF-8                            │
 *   │  longitud N  │  {"type":"TU_TURNO","aPagar":40,...}   │
 *   └──────────────┴────────────────────────────────────────┘
 * @endcode
 *
 * El prefijo de longitud resuelve el problema de framing en streams TCP:
 * con él sabemos exactamente cuántos bytes leer antes de parsear el JSON.
 *
 * Big Endian (Network Byte Order) garantiza compatibilidad entre arquitecturas
 * distintas (x86 ↔ ARM). Conversión con htonl()/ntohl().
 */
namespace net {

/**
 * @brief Tipos de mensaje; el campo "type" del JSON siempre coincide con el nombre.
 */
enum class MsgType {
    // Servidor → todos (broadcast)
    LOBBY_UPDATE,  ///< Lista de salas y estado del lobby.
    GAME_EVENT,    ///< Evento de juego: inicio mano, acción de bot, fase...
    GAME_STATE,    ///< Estado completo de la mesa para renderizar.
    // Servidor → cliente específico (unicast)
    TU_TURNO,      ///< Es tu turno: opciones disponibles + estado + cartas privadas.
    SALAS_LISTA,   ///< Respuesta a LISTAR_SALAS: salas públicas con hueco libre.
    GUARDADAS_LISTA, ///< Respuesta a LISTAR_GUARDADAS: archivos .pok en el servidor.
    RANKING_LISTA,      ///< Respuesta a CONSULTAR_RANKING: cuentas con ≥10 partidas jugadas.
    ESTADISTICAS_CUENTA, ///< Respuesta a CONSULTAR_ESTADISTICAS: player_stats de la cuenta del token.
    /// Respuesta a SINCRONIZAR_XP_OFFLINE: "acreditado","reclamado","mensaje".
    /// "acreditado" puede ser menor que "reclamado" si los topes recortaron.
    XP_OFFLINE_SINCRONIZADO,

    // Cliente → servidor
    JOIN_LOBBY,    ///< Solicitud de unión al lobby con nombre elegido.
    CREATE_GAME,   ///< Crear una nueva sala con la configuración indicada.
    JOIN_GAME,     ///< Unirse a una sala existente por ID.
    LISTAR_SALAS,  ///< Pide la lista de salas públicas disponibles (sin payload).
    ACTION,        ///< Acción de juego: FOLD, CALL, RAISE, CHECK.
    CHAT,          ///< Mensaje de chat (lobby y entre manos).
    LISTAR_GUARDADAS,   ///< Pide la lista de partidas guardadas (.pok) del servidor.
    RENOMBRAR_GUARDADA, ///< Renombra un archivo .pok existente.
    BORRAR_GUARDADA,    ///< Borra un archivo .pok existente.
    CARGAR_PARTIDA,     ///< Reanudar una partida guardada como sala nueva.

    // Cliente → servidor -- cuentas de usuario (ver AccountManager.hpp).
    // Mismo patrón "efímero" que LISTAR_SALAS/LISTAR_GUARDADAS: conectar,
    // mandar uno, recibir GAME_EVENT de respuesta, cerrar.
    REGISTER,         ///< Crear cuenta nueva (username + password).
    LOGIN,            ///< Iniciar sesión con username + password.
    LOGIN_TOKEN,      ///< Reautenticación silenciosa con el token guardado en el cliente.
    LOGOUT,           ///< Cierra sesión (revoca el token en servidor).
    CHANGE_USERNAME,  ///< Cambia el username de la cuenta autenticada por el token.
    CHANGE_PASSWORD,  ///< Cambia la contraseña de la cuenta autenticada por el token.
    CONSULTAR_RANKING,      ///< Pide el ranking global (sin payload, ni siquiera token -- es público).
    CONSULTAR_ESTADISTICAS, ///< Pide las estadísticas propias (token de la cuenta autenticada).
    /// "token","xp" -- entrega el XP acumulado jugando SIN CONEXIÓN. Es el
    /// único mensaje cuyo número lo calcula el cliente, así que el servidor
    /// lo acota en vez de creérselo: ver AccountManager::sincronizarXpOffline().
    SINCRONIZAR_XP_OFFLINE,

    // Cliente → servidor -- Social. Mismo patrón efímero que
    // CONSULTAR_RANKING salvo PRESENCIA_CONECTAR (única conexión que se
    // queda viva mientras el cliente esté en menús).
    PRESENCIA_CONECTAR,          ///< Abre el socket de presencia (token de cuenta real).
    BUSCAR_JUGADORES,            ///< "token","consulta" -- búsqueda de cuentas por username.
    ENVIAR_SOLICITUD_AMISTAD,    ///< "token","username_destino".
    RESPONDER_SOLICITUD,         ///< "token","solicitud_id","aceptar" -- aceptar o rechazar.
    LISTAR_AMIGOS,                ///< "token" -- amigos + presencia en vivo.
    LISTAR_SOLICITUDES,          ///< "token" -- solicitudes entrantes pendientes.
    LISTAR_JUGADORES_RECIENTES,  ///< "token" -- cuentas con mesa compartida en las últimas 24h.

    // Servidor → cliente -- respuestas de listas de Social. Formato plano
    // delimitado (";" entre filas, ":" entre campos, texto libre siempre al
    // final) -- mismo criterio que el resto del protocolo, ver Protocol.hpp.
    JUGADORES_BUSQUEDA_LISTA,    ///< "accountId:pendiente:username;..." -- respuesta a BUSCAR_JUGADORES.
    AMIGOS_LISTA,                ///< "accountId:estado:username;..." -- respuesta a LISTAR_AMIGOS.
    SOLICITUDES_LISTA,           ///< "solicitudId:fromAccountId:creadoEn:fromUsername;..." -- respuesta a LISTAR_SOLICITUDES.
    JUGADORES_RECIENTES_LISTA,   ///< "accountId:pendiente:username;..." -- respuesta a LISTAR_JUGADORES_RECIENTES.

    // Cliente → servidor -- cerrar Social v1 (chat directo, invitar a
    // sala, perfil de jugador). Mismo patrón efímero que el resto de
    // Social salvo los dos "push" de abajo, que viajan por la conexión
    // PRESENCIA_CONECTAR ya abierta, sin que el cliente pida nada.
    ENVIAR_MENSAJE_DIRECTO,      ///< "token","to_account_id","texto" -- requiere amistad confirmada.
    LISTAR_CONVERSACION,         ///< "token","con_account_id" -- historial con un amigo; marca sus mensajes como leídos.
    LISTAR_RESUMEN_CHATS,        ///< "token" -- un resumen por interlocutor (último mensaje + no leídos), para la pestaña "Chats".
    INVITAR_A_SALA,              ///< "token","to_account_id","sala_id" -- solo si el destinatario está CONECTADO a presencia ahora mismo.
    CONSULTAR_PERFIL_JUGADOR,    ///< "account_id" -- público, sin token, mismo criterio que CONSULTAR_RANKING.

    // Servidor → cliente -- respuestas de listas de la Social v1.
    // CONVERSACION_LISTA/RESUMEN_CHATS_LISTA llevan texto LIBRE de chat, a
    // diferencia de todo lo demás en este protocolo (usernames/nombres de
    // sala siempre pasan por sanitizarNombre(), que ya excluye ':' y ';').
    // Un mensaje con ':' o ';' de verdad escrito por un usuario rompería el
    // formato ":"/";" de siempre, así que estas dos usan separadores de
    // control ASCII en su lugar -- '\x1F' (unit separator) entre campos,
    // '\x1E' (record separator) entre filas -- que jsonEscape()/jsonUnescape()
    // dejan pasar intactos (solo tocan comillas/backslash/\n\r\t) y que
    // nadie escribe desde un teclado normal.
    CONVERSACION_LISTA,          ///< "id\x1FfromAccountId\x1FcreadoEn\x1Fleido\x1Ftexto\x1E..." -- respuesta a LISTAR_CONVERSACION.
    RESUMEN_CHATS_LISTA,         ///< "accountId\x1FultimoEsMio\x1FnoLeidos\x1FultimoEn\x1Fusername\x1FultimoTexto\x1E..." -- respuesta a LISTAR_RESUMEN_CHATS.
    PERFIL_JUGADOR,              ///< Campos JSON sueltos (NO lista) -- "existe","account_id","username" + los mismos campos que ESTADISTICAS_CUENTA -- respuesta a CONSULTAR_PERFIL_JUGADOR.

    // Servidor → cliente -- PUSH por el socket de presencia (único uso
    // real de ese socket en V1, ver PresenceRegistry::empujarMensaje()):
    // no son respuesta a nada que el cliente haya pedido en esa
    // conexión, llegan solos mientras el destinatario esté en menús.
    MENSAJE_DIRECTO_ENTRANTE,    ///< "fromAccountId","fromUsername","texto","creadoEn","mensajeId".
    INVITACION_SALA_ENTRANTE,    ///< "fromAccountId","fromUsername","salaId","codigo","nombreSala".

    // Cliente → servidor -- herramienta de estadísticas mínima (Fase 1 del
    // sistema de progresión, ver memoria qt_progression_system_design).
    // "token" debe resolver a una cuenta con accounts.es_admin=1 (marcada a
    // mano en la base -- ver AccountManager::migrarEsquema, v6) o se
    // responde con GAME_EVENT{"evento":"EXPORTAR_ESTADISTICAS_ERROR"}. Con
    // éxito, GAME_EVENT{"evento":"ESTADISTICAS_EXPORTADAS","archivo":"..."}
    // -- el fichero se escribe en data/, no viaja por el protocolo.
    EXPORTAR_ESTADISTICAS,       ///< "token" -- solo cuentas admin, ver AccountManager::exportarEstadisticas().

    // Fase 4 del sistema de progresión (ver memoria qt_progression_system_design).
    CONSULTAR_LOGROS,            ///< "token" -- catálogo completo + desbloqueados de la cuenta. Exige sesión.
    // "codigo\x1Frareza\x1FxpRecompensa\x1Fdesbloqueado\x1FdesbloqueadoEn\x1Fnombre\x1Fdescripcion\x1E..."
    // -- mismos separadores de control que CONVERSACION_LISTA/RESUMEN_CHATS_LISTA
    // (nombre/descripcion son texto libre en principio; hoy son cadenas
    // fijas de la propia app, pero el formato queda listo para si algún
    // día no lo son).
    LOGROS_LISTA,                ///< Respuesta a CONSULTAR_LOGROS.

    // Fase 5 del sistema de progresión: marcos v2 + tienda. Mismo criterio
    // que CONSULTAR_LOGROS -- exigen sesión, no son datos públicos.
    CONSULTAR_TIENDA,           ///< "token" -- catálogo completo + poseído/equipado de la cuenta.
    // "codigo\x1Fcategoria\x1FprecioTreboles\x1FnivelMinimo\x1FesDeLogro\x1Fposeido\x1Fequipado\x1Fnombre\x1E..."
    TIENDA_LISTA,                ///< Respuesta a CONSULTAR_TIENDA.
    COMPRAR_OBJETO,              ///< "token","codigo" -- ack vía GAME_EVENT (OBJETO_COMPRADO/OBJETO_COMPRA_ERROR).
    EQUIPAR_OBJETO,              ///< "token","slot","codigo" ("codigo" vacío desequipa) -- ack vía GAME_EVENT.
    CONSULTAR_LOADOUT,           ///< "token" -- el marco equipado de la propia cuenta.
    LOADOUT_ACTUAL,              ///< Respuesta a CONSULTAR_LOADOUT -- campos JSON sueltos (textura/efecto/decoracion_lateral_1/decoracion_lateral_2/decoracion_superior/titulo).

    // Herramienta de pruebas/admin, punto 2 de la prioridad confirmada
    // (2026-09-01, ver memoria qt_progression_review_2026_09_01) --
    // cierra el hueco real de "todo QA de logros/tienda ha sido SQL a
    // mano contra cuentas.db". "token" debe resolver a una cuenta con
    // es_admin=1 (igual que EXPORTAR_ESTADISTICAS) o se rechaza sin
    // más. "codigo" prueba primero como código de LOGRO (concede
    // también los objetos que ese logro trae, igual que si se hubiera
    // desbloqueado jugando) y si no, como objeto de tienda suelto (sin
    // Tréboles/nivel/gate de marco -- es un regalo admin, no una
    // compra). Ack vía GAME_EVENT (ADMIN_CONCEDER_OK/_ERROR, "mensaje").
    ADMIN_CONCEDER_ITEM,         ///< "token","username_destino","codigo".

    // Segunda mitad del punto 2 (mismo día, ver memoria de arriba):
    // fabrica cuentas de PRUEBA con partidas/elo variados, para poder
    // diseñar/probar Ranking y un futuro podio sin esperar jugadores
    // reales. Mismo criterio de permiso que ADMIN_CONCEDER_ITEM. Ack vía
    // GAME_EVENT (ADMIN_FABRICAR_OK/_ERROR, "mensaje").
    ADMIN_FABRICAR_CUENTAS,      ///< "token","cantidad" (recortado a [1,20] en el servidor).

    UNKNOWN        ///< Tipo desconocido o mensaje malformado.
};

/// Convierte MsgType al string que va en el campo "type" del JSON.
const char* msgTypeStr(MsgType t);

/// Parsea el campo "type" del JSON y devuelve el MsgType correspondiente.
MsgType strToMsgType(const std::string& s);

/// Mensaje listo para enviar o recibir: tipo + payload JSON completo.
struct Message {
    MsgType     tipo;
    std::string payload;  ///< Contenido JSON completo como string.

    Message() : tipo(MsgType::UNKNOWN), payload("{}") {}
    Message(MsgType t, std::string p) : tipo(t), payload(std::move(p)) {}
};

// ── Excepciones de red ────────────────────────────────────────────────────────

/// El otro extremo cerró la conexión (EOF en read()).
struct ConexionCerrada : std::runtime_error {
    ConexionCerrada()
        : std::runtime_error("Conexión cerrada por el otro extremo") {}
};

/// Error de red o de sistema; errno tiene el detalle.
struct ErrorRed : std::runtime_error {
    explicit ErrorRed(const std::string& msg) : std::runtime_error(msg) {}
};

// ── Primitivas de I/O ────────────────────────────────────────────────────────

/**
 * @brief Escribe exactamente @p n bytes en @p fd, reintentando si es necesario.
 * @throws ErrorRed si el write falla.
 */
void writeAll(int fd, const void* buf, std::size_t n);

/**
 * @brief Lee exactamente @p n bytes de @p fd, reintentando si es necesario.
 * @throws ConexionCerrada si el peer cierra la conexión.
 * @throws ErrorRed si el read falla.
 */
void readAll(int fd, void* buf, std::size_t n);

// ── API de mensajes ───────────────────────────────────────────────────────────

/// Serializa y envía un Message completo (header de 4 bytes + payload JSON).
void sendMsg(int fd, const Message& msg);

/// Recibe y deserializa un Message completo. Bloquea hasta tenerlo.
Message recvMsg(int fd);

// ── Constructores de JSON ─────────────────────────────────────────────────────

/**
 * @brief Tipo alias para lista de pares clave→valor que forman el JSON.
 *
 * Los valores numéricos deben pasarse como string; buildMsg los detecta
 * automáticamente (solo dígitos) y los escribe sin comillas en el JSON.
 */
using JsonFields = std::vector<std::pair<std::string, std::string>>;

/// Construye un Message con el tipo dado y los campos JSON indicados.
Message buildMsg(MsgType tipo, const JsonFields& campos = {});

// ── Parsers de JSON ───────────────────────────────────────────────────────────

/// Extrae el valor string del campo @p key del JSON @p json. Devuelve "" si no existe.
std::string jsonGetStr(const std::string& json, const std::string& key);

/// Extrae el valor entero del campo @p key del JSON @p json. Devuelve 0 si no existe.
int jsonGetInt(const std::string& json, const std::string& key);

/**
 * @brief Inserta o reemplaza el campo string @p key en @p json con @p value
 * (escapado), sin reconstruir el resto de campos. Si @p key no existe se
 * añade justo antes del '}' final -- asume JSON plano de un nivel, misma
 * asunción que ya hace buildMsg().
 *
 * Lo usa el dispatcher para sobrescribir "nombre"/añadir "account_id" en el
 * payload de CREATE_GAME/JOIN_GAME/etc. cuando el token que manda el
 * cliente resuelve a una cuenta real, sin tener que reparsear y
 * reconstruir el resto de campos (config de sala...) que ese payload
 * pueda traer.
 */
std::string jsonSetStr(const std::string& json, const std::string& key, const std::string& value);

/// Igual que jsonSetStr() pero para un entero sin comillas -- usado para
/// añadir "account_id" al payload reencolado.
std::string jsonSetInt(const std::string& json, const std::string& key, int value);

/**
 * @brief Limpia un nombre de jugador recibido por red: solo alfanuméricos,
 * '_' y espacios, sin espacios sobrantes en los extremos, máx. 24 chars.
 *
 * Vive aquí (no solo en server/main.cpp, donde nació) porque
 * NetworkObserver también necesita sanear nombres al dar de alta a un
 * jugador nuevo a mitad de partida (onComprobarNuevosJugadores).
 */
std::string sanitizarNombre(const std::string& crudo);

/**
 * @brief Limpia un nombre de ARCHIVO .pok recibido por red: alfanuméricos,
 * '_', '-', '.' y espacios, sin ".." (evita traversal fuera de data/) ni
 * espacios/puntos sobrantes en los extremos, máx. 64 chars.
 *
 * Distinto de sanitizarNombre() a propósito: un nombre de jugador no
 * necesita ni debe llevar puntos, pero un archivo SÍ (la extensión
 * ".pok") — usar sanitizarNombre() aquí se comía el punto y dejaba
 * "archivo.pok" convertido en "archivopok", ilegible para el sistema
 * de ficheros.
 */
std::string sanitizarNombreArchivo(const std::string& crudo);

}  // namespace net
