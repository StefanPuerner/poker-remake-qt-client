/**
 * @file ClaudeModeradorImagen.hpp
 * @brief Implementación real de IModeradorImagen: Messages API de Claude
 * (vision) vía libcurl -- misma cuenta/clave que BotLLM (ANTHROPIC_API_KEY),
 * sin dependencia nueva. Sustituye a un proveedor dedicado (se evaluó Azure
 * AI Content Safety, descartado 2026-10-02: Microsoft exige tarjeta de
 * crédito para crear la cuenta, sin alternativa de prepago, y el usuario no
 * quiere darla) -- reutilizar la API que ya se paga es la opción de menor
 * fricción, no solo la más barata de implementar.
 */
#pragma once

#include <string>

#include "IModeradorImagen.hpp"

/**
 * @brief Cliente HTTPS bloqueante a la Messages API de Anthropic (vision),
 * mismo patrón que LlmHttpClient (tool_choice obligatorio sobre una única
 * herramienta, para que la respuesta llegue siempre con la forma exacta del
 * esquema -- aprobada/motivo -- nunca envuelta en prosa).
 *
 * Umbral deliberadamente SUAVE (2026-10-02, pedido explícito: "iré probando
 * poco a poco qué admite") -- el prompt solo pide rechazar lo claramente
 * inapropiado (sexual explícito, violencia gráfica, odio, autolesión),
 * aprobando cualquier otra cosa. Ajustable sin tocar código: es solo el
 * texto del prompt en el .cpp.
 */
class ClaudeModeradorImagen : public IModeradorImagen {
 public:
  /// La clave se lee de ANTHROPIC_API_KEY al construir -- nunca en el repo
  /// (ver CLAUDE.md). Si no está definida, moderar() rechaza siempre
  /// (fail-closed), sin intentar ninguna llamada.
  explicit ClaudeModeradorImagen(std::string modelo = "claude-haiku-4-5-20251001",
                                  int timeoutMs = 8000);

  ResultadoModeracion moderar(const std::string& datosImagen) override;

 private:
  std::string modelo_;
  int timeoutMs_;
  std::string apiKey_;  ///< Vacío si ANTHROPIC_API_KEY no está definida.
};
