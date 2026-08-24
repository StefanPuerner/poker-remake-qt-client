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
// Dominio DuckDNS de la máquina remota (IP pública dinámica, actualizada
// sola vía crontab) -- puerto reenviado por el router, ya no depende de
// Tailscale para que un cliente cualquiera llegue al servidor.
constexpr const char* SERVER_HOST = "labandadehalcones.duckdns.org";

// ── TLS ──────────────────────────────────────────────────────────────────
//  Ver include/net/Tls.hpp para la implementación. El servidor exige TLS
//  en toda conexión (sin modo mixto texto-plano/cifrado) -- estas
//  constantes dimensionan ese cifrado, no lo activan/desactivan.

/// Conexiones simultáneas aceptadas antes de empezar a rechazar por
/// límite (ver Tls::intentarRegistrarConexion()). Punto de partida
/// razonable para "una cantidad moderada de jugadores", no una promesa
/// de capacidad exacta -- fácil de subir si hace falta.
constexpr int MAX_CONEXIONES_SIMULTANEAS = 200;

/// Segundos que el *dispatcher* espera a que una conexión recién
/// aceptada complete el *handshake* TLS + mande su primer mensaje, antes
/// de darla por perdida. Acota el peor caso de bloqueo del *dispatcher*
/// (antes indefinido, ver Tls.hpp) sin afectar a partidas ya en marcha:
/// el socket vuelve a modo bloqueante sin timeout en cuanto se entrega a
/// una sala (Tls::quitarTimeout()).
constexpr int TLS_HANDSHAKE_TIMEOUT_S = 10;

/// SHA-256 (hex, minúsculas) del SubjectPublicKeyInfo del certificado del
/// servidor -- el *pin* que el cliente Qt verifica en NetworkClient.hpp
/// antes de aceptar la conexión (ver sslErrors()/QSslError::
/// SelfSignedCertificate ahí). Se calcula con
/// scripts/generar_cert_tls.sh tras generar el certificado real; vacío
/// mientras tanto (ninguna huella coincide con "", así que el cliente
/// rechaza cualquier certificado hasta que esto se rellene -- fallo
/// seguro, no un pinning desactivado por accidente).
constexpr const char* SERVER_CERT_PIN_SHA256 =
    "7dbbb404d98a3697892a736a46fe8a605144a03a6c7b7d6d94a5720b7fb704a6";

}  // namespace net
