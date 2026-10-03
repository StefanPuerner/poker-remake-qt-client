/**
 * @file Base64.hpp
 * @brief Codificación/decodificación Base64 (RFC 4648), implementación propia.
 *
 * Mismo criterio que crypto/Sha256.hpp: vendorizar la primitiva en vez de
 * traer una librería para esto solo. Hace falta server-side para la foto
 * de perfil (el protocolo del juego es texto JSON, una imagen viaja como
 * campo base64 -- ver docs/plan-actualizaciones-2026-09-30.md) y para las
 * peticiones a APIs externas que esperan la imagen en base64 (Azure
 * Content Safety). El cliente Qt no necesita esto: QByteArray::toBase64()/
 * fromBase64() ya lo trae.
 */
#pragma once

#include <cstdint>
#include <string>

namespace base64 {

inline std::string encode(const std::string& datos) {
  static const char tabla[] =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  std::string out;
  out.reserve(((datos.size() + 2) / 3) * 4);
  std::size_t i = 0;
  while (i + 3 <= datos.size()) {
    std::uint32_t n = (static_cast<std::uint8_t>(datos[i]) << 16) |
                       (static_cast<std::uint8_t>(datos[i + 1]) << 8) |
                       static_cast<std::uint8_t>(datos[i + 2]);
    out += tabla[(n >> 18) & 0x3F];
    out += tabla[(n >> 12) & 0x3F];
    out += tabla[(n >> 6) & 0x3F];
    out += tabla[n & 0x3F];
    i += 3;
  }
  std::size_t restantes = datos.size() - i;
  if (restantes == 1) {
    std::uint32_t n = static_cast<std::uint8_t>(datos[i]) << 16;
    out += tabla[(n >> 18) & 0x3F];
    out += tabla[(n >> 12) & 0x3F];
    out += "==";
  } else if (restantes == 2) {
    std::uint32_t n = (static_cast<std::uint8_t>(datos[i]) << 16) |
                       (static_cast<std::uint8_t>(datos[i + 1]) << 8);
    out += tabla[(n >> 18) & 0x3F];
    out += tabla[(n >> 12) & 0x3F];
    out += tabla[(n >> 6) & 0x3F];
    out += "=";
  }
  return out;
}

/// "" si @p b64 no es base64 válido (longitud o carácter fuera de tabla).
inline std::string decode(const std::string& b64) {
  auto valor = [](unsigned char c) -> int {
    if (c >= 'A' && c <= 'Z') return c - 'A';
    if (c >= 'a' && c <= 'z') return c - 'a' + 26;
    if (c >= '0' && c <= '9') return c - '0' + 52;
    if (c == '+') return 62;
    if (c == '/') return 63;
    return -1;
  };
  std::string limpio;
  limpio.reserve(b64.size());
  for (char c : b64) {
    if (c == '=' || c == '\n' || c == '\r' || c == ' ') continue;
    limpio += c;
  }
  if (limpio.size() % 4 == 1) return "";  // longitud imposible

  std::string out;
  out.reserve((limpio.size() / 4) * 3 + 3);
  std::size_t i = 0;
  while (i + 4 <= limpio.size()) {
    int a = valor(limpio[i]), b = valor(limpio[i + 1]), c = valor(limpio[i + 2]), d = valor(limpio[i + 3]);
    if (a < 0 || b < 0 || c < 0 || d < 0) return "";
    std::uint32_t n = (a << 18) | (b << 12) | (c << 6) | d;
    out += static_cast<char>((n >> 16) & 0xFF);
    out += static_cast<char>((n >> 8) & 0xFF);
    out += static_cast<char>(n & 0xFF);
    i += 4;
  }
  std::size_t restantes = limpio.size() - i;
  if (restantes == 2) {
    int a = valor(limpio[i]), b = valor(limpio[i + 1]);
    if (a < 0 || b < 0) return "";
    std::uint32_t n = (a << 18) | (b << 12);
    out += static_cast<char>((n >> 16) & 0xFF);
  } else if (restantes == 3) {
    int a = valor(limpio[i]), b = valor(limpio[i + 1]), c = valor(limpio[i + 2]);
    if (a < 0 || b < 0 || c < 0) return "";
    std::uint32_t n = (a << 18) | (b << 12) | (c << 6);
    out += static_cast<char>((n >> 16) & 0xFF);
    out += static_cast<char>((n >> 8) & 0xFF);
  } else if (restantes == 1) {
    return "";  // byte suelto, no es base64 válido
  }
  return out;
}

}  // namespace base64
