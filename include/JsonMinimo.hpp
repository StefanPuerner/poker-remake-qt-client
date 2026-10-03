/**
 * @file JsonMinimo.hpp
 * @brief JSON mínimo a mano para los clientes HTTP de APIs externas.
 *
 * NO es un parser general: solo conoce lo necesario para escapar un string
 * al construir una petición, y para extraer campos de una respuesta de
 * forma = "busca esta clave y lee hasta su valor" -- mismo espíritu que
 * net::Protocol para el protocolo del juego (ver su propio comentario),
 * pero compartido entre los clientes de APIs externas (LlmHttpClient,
 * ClaudeModeradorImagen) para no duplicar la misma docena de líneas en cada
 * uno. Header-only a propósito: ninguno de los dos necesita más.
 */
#pragma once

#include <string>

namespace jsonmin {

inline std::string escape(const std::string& s) {
  std::string out;
  out.reserve(s.size());
  for (char c : s) {
    switch (c) {
      case '"':  out += "\\\""; break;
      case '\\': out += "\\\\"; break;
      case '\n': out += "\\n";  break;
      case '\r': out += "\\r";  break;
      case '\t': out += "\\t";  break;
      default:
        if (static_cast<unsigned char>(c) < 0x20) continue;  // control char, descartado
        out += c;
    }
  }
  return out;
}

/// Busca "clave" seguida de ':' y '{', y devuelve el objeto completo hasta
/// su '}' correspondiente -- cuenta llaves respetando literales de cadena
/// (para que un '}' dentro de un string, p.ej. en un mensaje de error, no
/// corte antes de tiempo). Cadena vacía si no se encuentra.
inline std::string extraerObjeto(const std::string& json, const std::string& clave) {
  std::string buscado = "\"" + clave + "\"";
  std::size_t pos = json.find(buscado);
  if (pos == std::string::npos) return "";
  pos = json.find(':', pos + buscado.size());
  if (pos == std::string::npos) return "";
  pos = json.find('{', pos);
  if (pos == std::string::npos) return "";

  std::size_t inicio = pos;
  int balance = 0;
  bool enString = false;
  bool escapando = false;
  for (std::size_t i = inicio; i < json.size(); ++i) {
    char c = json[i];
    if (enString) {
      if (escapando) { escapando = false; }
      else if (c == '\\') { escapando = true; }
      else if (c == '"') { enString = false; }
      continue;
    }
    if (c == '"') { enString = true; continue; }
    if (c == '{') ++balance;
    else if (c == '}') {
      --balance;
      if (balance == 0) return json.substr(inicio, i - inicio + 1);
    }
  }
  return "";
}

/// Igual que extraerObjeto() pero para un array ('[' ... ']' al mismo nivel).
inline std::string extraerArray(const std::string& json, const std::string& clave) {
  std::string buscado = "\"" + clave + "\"";
  std::size_t pos = json.find(buscado);
  if (pos == std::string::npos) return "";
  pos = json.find(':', pos + buscado.size());
  if (pos == std::string::npos) return "";
  pos = json.find('[', pos);
  if (pos == std::string::npos) return "";

  std::size_t inicio = pos;
  int balance = 0;
  bool enString = false;
  bool escapando = false;
  for (std::size_t i = inicio; i < json.size(); ++i) {
    char c = json[i];
    if (enString) {
      if (escapando) { escapando = false; }
      else if (c == '\\') { escapando = true; }
      else if (c == '"') { enString = false; }
      continue;
    }
    if (c == '"') { enString = true; continue; }
    if (c == '[') ++balance;
    else if (c == ']') {
      --balance;
      if (balance == 0) return json.substr(inicio, i - inicio + 1);
    }
  }
  return "";
}

/// Valor de "clave":"valor" (string) dentro de @p obj. Cadena vacía si no está.
inline std::string extraerString(const std::string& obj, const std::string& clave) {
  std::string buscado = "\"" + clave + "\"";
  std::size_t pos = obj.find(buscado);
  if (pos == std::string::npos) return "";
  pos = obj.find(':', pos + buscado.size());
  if (pos == std::string::npos) return "";
  pos = obj.find('"', pos);
  if (pos == std::string::npos) return "";
  ++pos;
  std::string out;
  bool escapando = false;
  for (std::size_t i = pos; i < obj.size(); ++i) {
    char c = obj[i];
    if (escapando) { out += c; escapando = false; continue; }
    if (c == '\\') { escapando = true; continue; }
    if (c == '"') break;
    out += c;
  }
  return out;
}

/// Valor de "clave":numero dentro de @p obj. 0 si no está.
inline int extraerInt(const std::string& obj, const std::string& clave) {
  std::string buscado = "\"" + clave + "\"";
  std::size_t pos = obj.find(buscado);
  if (pos == std::string::npos) return 0;
  pos = obj.find(':', pos + buscado.size());
  if (pos == std::string::npos) return 0;
  ++pos;
  while (pos < obj.size() && (obj[pos] == ' ' || obj[pos] == '\t')) ++pos;
  bool negativo = false;
  if (pos < obj.size() && obj[pos] == '-') { negativo = true; ++pos; }
  long long valor = 0;
  bool alguno = false;
  while (pos < obj.size() && obj[pos] >= '0' && obj[pos] <= '9') {
    valor = valor * 10 + (obj[pos] - '0');
    ++pos;
    alguno = true;
  }
  if (!alguno) return 0;
  return static_cast<int>(negativo ? -valor : valor);
}

/// Valor de "clave":true|false dentro de @p obj. false si no está (o si el
/// valor no es literalmente "true").
inline bool extraerBool(const std::string& obj, const std::string& clave) {
  std::string buscado = "\"" + clave + "\"";
  std::size_t pos = obj.find(buscado);
  if (pos == std::string::npos) return false;
  pos = obj.find(':', pos + buscado.size());
  if (pos == std::string::npos) return false;
  ++pos;
  while (pos < obj.size() && (obj[pos] == ' ' || obj[pos] == '\t')) ++pos;
  return obj.compare(pos, 4, "true") == 0;
}

}  // namespace jsonmin
