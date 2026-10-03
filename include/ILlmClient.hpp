/**
 * @file ILlmClient.hpp
 * @brief Interfaz mínima para pedir una decisión de poker a un LLM externo.
 */
#pragma once

#include <string>

/**
 * @brief Separada de BotLLM para poder inyectar un doble de prueba (sin red
 * ni coste) en los tests -- ver tests/test_botllm.cpp. LlmHttpClient es la
 * única implementación real (Messages API de Claude vía libcurl).
 */
class ILlmClient {
 public:
  virtual ~ILlmClient() = default;

  /**
   * @brief Pide una decisión al modelo dado un prompt ya construido.
   * @param prompt Contexto completo de la mano (ver BotLLM::construirPrompt).
   * @param accionOut   "FOLD"/"CALL"/"RAISE"/"ALL_IN"/"CHECK" si tuvo éxito.
   * @param cantidadOut Importe (solo relevante para RAISE; el resto lo ignora).
   * @return true si la llamada tuvo éxito y el modelo devolvió una acción
   * con la forma esperada (sin validar aún que sea LEGAL en esta mesa --
   * eso lo hace BotLLM, que es quien conoce las reglas de la ronda). false
   * ante cualquier fallo (red, timeout, HTTP, respuesta inesperada) --
   * BotLLM cae al motor local en ese caso.
   */
  virtual bool pedirDecision(const std::string& prompt, std::string& accionOut,
                             int& cantidadOut) = 0;
};
