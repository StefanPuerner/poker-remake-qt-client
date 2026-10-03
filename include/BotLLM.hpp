/**
 * @file BotLLM.hpp
 * @brief Jugador controlado por un LLM externo (prototipo experimental).
 */
#pragma once

#include <map>
#include <memory>
#include <string>

#include "DecisionEngine.hpp"
#include "ILlmClient.hpp"
#include "Player.hpp"

/**
 * @brief Jugador cuya acción decide un LLM externo (ver ILlmClient), no
 * DecisionEngine -- pero recibiendo el mismo contexto numérico "duro"
 * (equity, pot odds, percentil preflop; ver DecisionEngine::evaluarContexto)
 * que ya calcula el motor local, más el perfil de oponente que ya acumula
 * un Bot EXPERTO (VPIP, agresividad, fold-to-raise) y el historial de la
 * ronda en curso (GameState::historialRonda).
 *
 * Es un tipo de bot ADICIONAL, seleccionable por sala (ver TipoBots) --
 * convive con los Bot normales, no los sustituye. Si la llamada al LLM
 * falla, tarda demasiado, o la acción que devuelve no es legal en esta
 * mesa tras recortarla a lo más cercano permitido, decidirAccion() cae a
 * DecisionEngine::pensar() -- la mano nunca se queda colgada ni recibe una
 * acción inválida (nunca devuelve Accion::valido == false).
 */
class BotLLM : public Player {
 public:
  /// @param cliente Inyectado para poder sustituirlo por un doble de prueba
  /// en tests; en producción, un LlmHttpClient real (API de Claude).
  BotLLM(const std::string& nombre, int saldo, std::shared_ptr<ILlmClient> cliente);

  Accion decidirAccion(const GameState& state) override;

  // ── Perfilado de rivales (mismo contrato y lógica que Bot) ───────────────
  void iniciarManoJugador(const std::string& nombre) override;
  void registrarAccion(const std::string& nombre, TipoAccion accion, Rondas ronda,
                       bool hayApuesta, int cantidad = 0, int boteAntes = 0) override;

 private:
  std::shared_ptr<ILlmClient> cliente_;
  std::map<std::string, PerfilJugador> perfiles_;
};
