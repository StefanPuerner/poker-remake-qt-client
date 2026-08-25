#include "../../include/net/Protocol.hpp"

#include <cctype>
#include <stdexcept>

// writeAll/readAll/sendMsg/recvMsg (las únicas cuatro funciones de este
// fichero que dependían de sockets POSIX crudos) viven ahora en
// SocketIO.cpp — ver el comentario de cabecera de ese fichero. Todo lo que
// queda aquí es lógica de texto pura (sin sockets), que es exactamente lo
// que necesita el cliente Qt (sobre QTcpSocket, no sockets POSIX).

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
    case MsgType::RANKING_LISTA:
      return "RANKING_LISTA";
    case MsgType::ESTADISTICAS_CUENTA:
      return "ESTADISTICAS_CUENTA";
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
    case MsgType::REGISTER:
      return "REGISTER";
    case MsgType::LOGIN:
      return "LOGIN";
    case MsgType::LOGIN_TOKEN:
      return "LOGIN_TOKEN";
    case MsgType::LOGOUT:
      return "LOGOUT";
    case MsgType::CHANGE_USERNAME:
      return "CHANGE_USERNAME";
    case MsgType::CHANGE_PASSWORD:
      return "CHANGE_PASSWORD";
    case MsgType::CONSULTAR_RANKING:
      return "CONSULTAR_RANKING";
    case MsgType::CONSULTAR_ESTADISTICAS:
      return "CONSULTAR_ESTADISTICAS";
    case MsgType::PRESENCIA_CONECTAR:
      return "PRESENCIA_CONECTAR";
    case MsgType::BUSCAR_JUGADORES:
      return "BUSCAR_JUGADORES";
    case MsgType::ENVIAR_SOLICITUD_AMISTAD:
      return "ENVIAR_SOLICITUD_AMISTAD";
    case MsgType::RESPONDER_SOLICITUD:
      return "RESPONDER_SOLICITUD";
    case MsgType::LISTAR_AMIGOS:
      return "LISTAR_AMIGOS";
    case MsgType::LISTAR_SOLICITUDES:
      return "LISTAR_SOLICITUDES";
    case MsgType::LISTAR_JUGADORES_RECIENTES:
      return "LISTAR_JUGADORES_RECIENTES";
    case MsgType::JUGADORES_BUSQUEDA_LISTA:
      return "JUGADORES_BUSQUEDA_LISTA";
    case MsgType::AMIGOS_LISTA:
      return "AMIGOS_LISTA";
    case MsgType::SOLICITUDES_LISTA:
      return "SOLICITUDES_LISTA";
    case MsgType::JUGADORES_RECIENTES_LISTA:
      return "JUGADORES_RECIENTES_LISTA";
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
  if (s == "RANKING_LISTA") return MsgType::RANKING_LISTA;
  if (s == "ESTADISTICAS_CUENTA") return MsgType::ESTADISTICAS_CUENTA;
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
  if (s == "REGISTER") return MsgType::REGISTER;
  if (s == "LOGIN") return MsgType::LOGIN;
  if (s == "LOGIN_TOKEN") return MsgType::LOGIN_TOKEN;
  if (s == "LOGOUT") return MsgType::LOGOUT;
  if (s == "CHANGE_USERNAME") return MsgType::CHANGE_USERNAME;
  if (s == "CHANGE_PASSWORD") return MsgType::CHANGE_PASSWORD;
  if (s == "CONSULTAR_RANKING") return MsgType::CONSULTAR_RANKING;
  if (s == "CONSULTAR_ESTADISTICAS") return MsgType::CONSULTAR_ESTADISTICAS;
  if (s == "PRESENCIA_CONECTAR") return MsgType::PRESENCIA_CONECTAR;
  if (s == "BUSCAR_JUGADORES") return MsgType::BUSCAR_JUGADORES;
  if (s == "ENVIAR_SOLICITUD_AMISTAD") return MsgType::ENVIAR_SOLICITUD_AMISTAD;
  if (s == "RESPONDER_SOLICITUD") return MsgType::RESPONDER_SOLICITUD;
  if (s == "LISTAR_AMIGOS") return MsgType::LISTAR_AMIGOS;
  if (s == "LISTAR_SOLICITUDES") return MsgType::LISTAR_SOLICITUDES;
  if (s == "LISTAR_JUGADORES_RECIENTES") return MsgType::LISTAR_JUGADORES_RECIENTES;
  if (s == "JUGADORES_BUSQUEDA_LISTA") return MsgType::JUGADORES_BUSQUEDA_LISTA;
  if (s == "AMIGOS_LISTA") return MsgType::AMIGOS_LISTA;
  if (s == "SOLICITUDES_LISTA") return MsgType::SOLICITUDES_LISTA;
  if (s == "JUGADORES_RECIENTES_LISTA") return MsgType::JUGADORES_RECIENTES_LISTA;
  return MsgType::UNKNOWN;
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

std::string jsonSetStr(const std::string& json, const std::string& key, const std::string& value) {
  std::string patron = "\"" + key + "\":\"";
  auto pos = json.find(patron);
  if (pos != std::string::npos) {
    auto inicioValor = pos + patron.size();
    // Mismo escaneo escape-aware que jsonGetStr() para no cortar el valor
    // actual en una comilla que forme parte del texto.
    auto fin = inicioValor;
    while (fin < json.size()) {
      if (json[fin] == '\\' && fin + 1 < json.size()) {
        fin += 2;
        continue;
      }
      if (json[fin] == '"') break;
      ++fin;
    }
    return json.substr(0, inicioValor) + jsonEscape(value) + json.substr(fin);
  }

  // No existe: se inserta justo antes del '}' final -- JSON plano de un
  // nivel, misma asunción que ya hace buildMsg().
  auto cierre = json.rfind('}');
  if (cierre == std::string::npos) return json;  // JSON malformado: nada seguro que insertar
  return json.substr(0, cierre) + ",\"" + key + "\":\"" + jsonEscape(value) + "\"" + json.substr(cierre);
}

std::string jsonSetInt(const std::string& json, const std::string& key, int value) {
  std::string patron = "\"" + key + "\":";
  auto pos = json.find(patron);
  if (pos != std::string::npos) {
    auto inicioValor = pos + patron.size();
    auto fin = inicioValor;
    while (fin < json.size() && json[fin] == ' ') ++fin;  // por si "key": 100
    if (fin < json.size() && json[fin] == '-') ++fin;
    while (fin < json.size() && json[fin] >= '0' && json[fin] <= '9') ++fin;
    return json.substr(0, inicioValor) + std::to_string(value) + json.substr(fin);
  }

  auto cierre = json.rfind('}');
  if (cierre == std::string::npos) return json;
  return json.substr(0, cierre) + ",\"" + key + "\":" + std::to_string(value) + json.substr(cierre);
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
