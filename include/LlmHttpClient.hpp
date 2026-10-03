/**
 * @file LlmHttpClient.hpp
 * @brief Implementación real de ILlmClient: Messages API de Claude vía libcurl.
 */
#pragma once

#include <string>

#include "ILlmClient.hpp"

/**
 * @brief Cliente HTTPS bloqueante a la Messages API de Anthropic.
 *
 * Bloqueante a propósito -- ver el comentario de arquitectura al principio
 * de BotLLM.cpp: el servidor ya bloquea su hilo de sala para el delay
 * artificial de los bots normales y para esperar la jugada de un humano,
 * así que esto no es una excepción a su modelo de concurrencia.
 *
 * Fuerza la salida con *tool use* (tool_choice obligatorio sobre una única
 * herramienta "decidir_accion") en vez de pedir JSON dentro del texto: la
 * respuesta llega siempre con la forma exacta del esquema, nunca envuelta
 * en prosa o markdown que haya que rescatar -- solo hay que validar los
 * VALORES (eso lo hace BotLLM, que conoce las reglas de la mesa).
 */
class LlmHttpClient : public ILlmClient {
 public:
  /// La clave se lee de la variable de entorno ANTHROPIC_API_KEY al
  /// construir -- nunca en el repo (ver CLAUDE.md). Si no está definida,
  /// pedirDecision() falla siempre (false) sin intentar ninguna llamada.
  explicit LlmHttpClient(std::string modelo = "claude-haiku-4-5-20251001",
                         int timeoutMs = 5000);

  bool pedirDecision(const std::string& prompt, std::string& accionOut,
                     int& cantidadOut) override;

 private:
  std::string modelo_;
  int timeoutMs_;
  std::string apiKey_;  ///< Vacío si ANTHROPIC_API_KEY no está definida.
};
