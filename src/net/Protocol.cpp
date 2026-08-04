#include "../../include/net/Protocol.hpp"

#include <arpa/inet.h>  // htonl(), ntohl() — conversión Big Endian
#include <unistd.h>     // read(), write()

#include <cctype>
#include <cerrno>
#include <cstring>
#include <stdexcept>

namespace net {

// ─────────────────────────────────────────────────────────────────────────────
//  Conversión MsgType ↔ string
// ─────────────────────────────────────────────────────────────────────────────

const char* msgTypeStr(MsgType t) {
  switch (t) {
    case MsgType::LOBBY_UPDATE:
      return "LOBBY_UPDATE";
    case MsgType::GAME_EVENT:
      return "GAME_EVENT";
    case MsgType::GAME_STATE:
      return "GAME_STATE";
    case MsgType::TU_TURNO:
      return "TU_TURNO";
    case MsgType::SALAS_LISTA:
      return "SALAS_LISTA";
    case MsgType::GUARDADAS_LISTA:
      return "GUARDADAS_LISTA";
    case MsgType::JOIN_LOBBY:
      return "JOIN_LOBBY";
    case MsgType::CREATE_GAME:
      return "CREATE_GAME";
    case MsgType::JOIN_GAME:
      return "JOIN_GAME";
    case MsgType::LISTAR_SALAS:
      return "LISTAR_SALAS";
    case MsgType::ACTION:
      return "ACTION";
    case MsgType::CHAT:
      return "CHAT";
    case MsgType::LISTAR_GUARDADAS:
      return "LISTAR_GUARDADAS";
    case MsgType::RENOMBRAR_GUARDADA:
      return "RENOMBRAR_GUARDADA";
    case MsgType::BORRAR_GUARDADA:
      return "BORRAR_GUARDADA";
    case MsgType::CARGAR_PARTIDA:
      return "CARGAR_PARTIDA";
    default:
      return "UNKNOWN";
  }
}

MsgType strToMsgType(const std::string& s) {
  if (s == "LOBBY_UPDATE") return MsgType::LOBBY_UPDATE;
  if (s == "GAME_EVENT") return MsgType::GAME_EVENT;
  if (s == "GAME_STATE") return MsgType::GAME_STATE;
  if (s == "TU_TURNO") return MsgType::TU_TURNO;
  if (s == "SALAS_LISTA") return MsgType::SALAS_LISTA;
  if (s == "GUARDADAS_LISTA") return MsgType::GUARDADAS_LISTA;
  if (s == "JOIN_LOBBY") return MsgType::JOIN_LOBBY;
  if (s == "CREATE_GAME") return MsgType::CREATE_GAME;
  if (s == "JOIN_GAME") return MsgType::JOIN_GAME;
  if (s == "LISTAR_SALAS") return MsgType::LISTAR_SALAS;
  if (s == "ACTION") return MsgType::ACTION;
  if (s == "CHAT") return MsgType::CHAT;
  if (s == "LISTAR_GUARDADAS") return MsgType::LISTAR_GUARDADAS;
  if (s == "RENOMBRAR_GUARDADA") return MsgType::RENOMBRAR_GUARDADA;
  if (s == "BORRAR_GUARDADA") return MsgType::BORRAR_GUARDADA;
  if (s == "CARGAR_PARTIDA") return MsgType::CARGAR_PARTIDA;
  return MsgType::UNKNOWN;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Primitivas de I/O — la base de todo
// ─────────────────────────────────────────────────────────────────────────────

void writeAll(int fd, const void* buf, std::size_t n) {
  const char* ptr = static_cast<const char*>(buf);
  std::size_t restante = n;

  while (restante > 0) {
    // write() devuelve cuántos bytes escribió realmente.
    // En un socket lleno de buffer puede ser menos que lo pedido.
    ssize_t wr = ::write(fd, ptr, restante);

    if (wr == 0) {
      throw ConexionCerrada{};
    }
    if (wr < 0) {
      // EINTR: una señal del sistema interrumpió la llamada.
      // No es un error real: simplemente reintentamos.
      if (errno == EINTR) continue;
      throw ErrorRed{"write() falló: " + std::string{strerror(errno)}};
    }

    ptr += wr;
    restante -= static_cast<std::size_t>(wr);
  }
}

void readAll(int fd, void* buf, std::size_t n) {
  char* ptr = static_cast<char*>(buf);
  std::size_t restante = n;

  while (restante > 0) {
    // read() puede devolver menos bytes de los pedidos.
    // Eso es completamente normal en sockets: el kernel fragmenta
    // los datos según el tamaño del buffer y la velocidad de llegada.
    ssize_t rd = ::read(fd, ptr, restante);

    if (rd == 0) {
      // EOF: el otro extremo cerró su lado de la conexión.
      throw ConexionCerrada{};
    }
    if (rd < 0) {
      if (errno == EINTR) continue;
      throw ErrorRed{"read() falló: " + std::string{strerror(errno)}};
    }

    ptr += rd;
    restante -= static_cast<std::size_t>(rd);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  sendMsg / recvMsg — el protocolo completo
// ─────────────────────────────────────────────────────────────────────────────

void sendMsg(int fd, const Message& msg) {
  // El payload ya contiene el campo "type" dentro del JSON,
  // así que en el cable solo enviamos: longitud (4 bytes) + JSON.

  // htonl() convierte el uint32 al orden de bytes de red (Big Endian).
  // Si el servidor corre en x86 (Little Endian) y el cliente en ARM,
  // ambos leen el mismo número gracias a esta conversión.
  uint32_t longitudBE = htonl(static_cast<uint32_t>(msg.payload.size()));

  writeAll(fd, &longitudBE, 4);                          // header
  writeAll(fd, msg.payload.data(), msg.payload.size());  // payload
}

Message recvMsg(int fd) {
  // 1. Leer los 4 bytes del header
  uint32_t longitudBE;
  readAll(fd, &longitudBE, 4);

  // ntohl() invierte la conversión: Big Endian → orden nativo de la CPU
  uint32_t longitud = ntohl(longitudBE);

  // Sanidad: rechazar mensajes absurdamente grandes.
  // Protege contra datos corruptos o clientes maliciosos.
  constexpr uint32_t MAX_MSG = 4 * 1024 * 1024;  // 4 MB
  if (longitud > MAX_MSG) {
    throw ErrorRed{"Mensaje demasiado grande: " + std::to_string(longitud)};
  }

  // 2. Leer exactamente 'longitud' bytes de payload
  std::string payload(longitud, '\0');
  if (longitud > 0) {
    readAll(fd, payload.data(), longitud);
  }

  // 3. Extraer el campo "type" del JSON para construir el enum
  std::string tipoStr = jsonGetStr(payload, "type");
  return Message{strToMsgType(tipoStr), std::move(payload)};
}

// ─────────────────────────────────────────────────────────────────────────────
//  Escapado de strings JSON
// ─────────────────────────────────────────────────────────────────────────────
//
//  Los valores de texto (nombre de jugador, chat...) llegan de entrada de
//  usuario y pueden contener comillas o backslashes. Sin escapar, un simple
//  '"' en el chat rompe el framing del JSON y jsonGetStr() empieza a leer
//  campos de otro sitio (o directamente falla). buildMsg()/jsonGetStr() son
//  la única fuente y el único consumidor de este formato, así que basta con
//  que ambos se pongan de acuerdo: no hace falta un escapado JSON completo.

namespace {

std::string jsonEscape(const std::string& valor) {
  std::string out;
  out.reserve(valor.size());
  for (char c : valor) {
    switch (c) {
      case '"':  out += "\\\""; break;
      case '\\': out += "\\\\"; break;
      case '\n': out += "\\n";  break;
      case '\r': out += "\\r";  break;
      case '\t': out += "\\t";  break;
      default:   out += c;      break;
    }
  }
  return out;
}

std::string jsonUnescape(const std::string& valor) {
  std::string out;
  out.reserve(valor.size());
  for (std::size_t i = 0; i < valor.size(); ++i) {
    if (valor[i] != '\\' || i + 1 >= valor.size()) {
      out += valor[i];
      continue;
    }
    char siguiente = valor[++i];
    switch (siguiente) {
      case 'n': out += '\n'; break;
      case 'r': out += '\r'; break;
      case 't': out += '\t'; break;
      default:  out += siguiente; break;  // cubre comillas y backslash escapados
    }
  }
  return out;
}

}  // namespace

// ─────────────────────────────────────────────────────────────────────────────
//  Constructor de mensajes JSON
// ─────────────────────────────────────────────────────────────────────────────

Message buildMsg(MsgType tipo, const JsonFields& campos) {
  // Construimos el JSON a mano para no depender de librerías externas.
  // Ejemplo resultado: {"type":"ACTION","tipoAccion":"RAISE","cantidad":100}

  std::string json = "{\"type\":\"";
  json += msgTypeStr(tipo);
  json += "\"";

  for (const auto& [clave, valor] : campos) {
    json += ",\"";
    json += clave;
    json += "\":";

    // Detectar si el valor es numérico (solo dígitos, opcionalmente '-')
    bool esNumero = !valor.empty();
    for (std::size_t i = 0; i < valor.size() && esNumero; ++i) {
      if (i == 0 && valor[0] == '-') continue;
      if (valor[i] < '0' || valor[i] > '9') esNumero = false;
    }

    if (esNumero) {
      json += valor;  // número sin comillas: "cantidad":100
    } else {
      json += "\"";
      json += jsonEscape(valor);  // string con comillas, escapado
      json += "\"";
    }
  }

  json += "}";
  return Message{tipo, std::move(json)};
}

// ─────────────────────────────────────────────────────────────────────────────
//  Parsers de JSON mínimos
// ─────────────────────────────────────────────────────────────────────────────

std::string jsonGetStr(const std::string& json, const std::string& key) {
  // Busca el patrón: "key":"VALUE"
  // Devuelve VALUE sin las comillas ni el escapado, o "" si no existe.
  std::string patron = "\"" + key + "\":\"";
  auto pos = json.find(patron);
  if (pos == std::string::npos) return "";

  pos += patron.size();

  // Buscar la comilla de cierre saltando pares escapados (\" y \\) para no
  // cortar el valor en una comilla que en realidad forma parte del texto.
  auto fin = pos;
  while (fin < json.size()) {
    if (json[fin] == '\\' && fin + 1 < json.size()) {
      fin += 2;
      continue;
    }
    if (json[fin] == '"') break;
    ++fin;
  }
  if (fin >= json.size()) return "";

  return jsonUnescape(json.substr(pos, fin - pos));
}

int jsonGetInt(const std::string& json, const std::string& key) {
  // Busca el patrón: "key":NUMBER
  // Devuelve NUMBER como int, o 0 si no existe.
  std::string patron = "\"" + key + "\":";
  auto pos = json.find(patron);
  if (pos == std::string::npos) return 0;

  pos += patron.size();
  // Saltar espacios (por si hay: "key": 100)
  while (pos < json.size() && json[pos] == ' ') ++pos;
  if (pos >= json.size()) return 0;

  try {
    return std::stoi(json.substr(pos));
  } catch (...) {
    return 0;
  }
}

std::string sanitizarNombre(const std::string& crudo) {
  std::string limpio;
  limpio.reserve(crudo.size());
  for (char c : crudo) {
    if (std::isalnum(static_cast<unsigned char>(c)) || c == '_' || c == ' ') {
      limpio += c;
    }
  }
  while (!limpio.empty() && limpio.front() == ' ') limpio.erase(limpio.begin());
  while (!limpio.empty() && limpio.back() == ' ') limpio.pop_back();
  constexpr std::size_t MAX_LEN = 24;
  if (limpio.size() > MAX_LEN) limpio.resize(MAX_LEN);
  return limpio;
}

std::string sanitizarNombreArchivo(const std::string& crudo) {
  std::string limpio;
  limpio.reserve(crudo.size());
  for (char c : crudo) {
    if (std::isalnum(static_cast<unsigned char>(c)) || c == '_' || c == ' ' ||
        c == '-' || c == '.') {
      limpio += c;
    }
  }
  // Colapsa ".." a un solo '.' — sin esto, un nombre como "../../etc" (ya
  // sin barras, filtradas arriba) seguiría pudiendo intentar subir de
  // directorio vía puntos dobles sueltos.
  std::string sinDobles;
  sinDobles.reserve(limpio.size());
  for (std::size_t i = 0; i < limpio.size(); ++i) {
    if (limpio[i] == '.' && i + 1 < limpio.size() && limpio[i + 1] == '.') continue;
    sinDobles += limpio[i];
  }
  while (!sinDobles.empty() && (sinDobles.front() == ' ' || sinDobles.front() == '.'))
    sinDobles.erase(sinDobles.begin());
  while (!sinDobles.empty() && sinDobles.back() == ' ') sinDobles.pop_back();
  constexpr std::size_t MAX_LEN = 64;
  if (sinDobles.size() > MAX_LEN) sinDobles.resize(MAX_LEN);
  return sinDobles;
}

}  // namespace net
