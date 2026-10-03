/**
 * @file IModeradorImagen.hpp
 * @brief Interfaz mínima para comprobar si una imagen subida es apta.
 */
#pragma once

#include <string>

/// Resultado de moderar una imagen. "motivo" es una clave corta (no texto
/// libre) cuando !aprobada, mismo criterio que el resto del protocolo.
struct ResultadoModeracion {
  bool aprobada = false;
  std::string motivo;
};

/**
 * @brief Separada de la implementación real para poder inyectar un doble de
 * prueba en tests (sin red ni coste), y para poder cambiar de proveedor sin
 * tocar el dispatcher del servidor -- ya pasó una vez (Azure AI Content
 * Safety → `ClaudeModeradorImagen`, 2026-10-02, descartado Azure por exigir
 * tarjeta de crédito sin alternativa de prepago). `ClaudeModeradorImagen`
 * es la implementación real de hoy.
 *
 * Fail-closed por contrato: cualquier implementación debe devolver
 * aprobada=false ante un fallo de red/configuración, nunca aprobada=true
 * "por si acaso" -- un fallo de moderación nunca debe colar una imagen sin
 * revisar.
 */
class IModeradorImagen {
 public:
  virtual ~IModeradorImagen() = default;
  virtual ResultadoModeracion moderar(const std::string& datosImagen) = 0;
};
