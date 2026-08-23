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
