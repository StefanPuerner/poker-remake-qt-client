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
