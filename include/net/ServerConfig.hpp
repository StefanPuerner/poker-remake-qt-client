/**
 * @file ServerConfig.hpp
 * @brief Punto único de configuración de red: puerto y host por defecto.
 */
#pragma once

#include <cstdint>

/**
 * @brief Punto único de configuración de red.
 *
 * Modifica SERVER_HOST con la IP Tailscale del servidor (visible en
 * `tailscale status`). El cliente usa estos valores por defecto;
 * el servidor ignora SERVER_HOST y siempre escucha en 0.0.0.0.
 */
namespace net {

constexpr uint16_t    SERVER_PORT = 7777;
constexpr const char* SERVER_HOST = "100.83.246.15";

}  // namespace net
