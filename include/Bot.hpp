/**
 * @file Bot.hpp
 * @brief Jugador controlado por IA con personalidad dinámica y perfilado de rivales.
 */
#pragma once

#include <map>
#include <string>

#include "Player.hpp"
#include "DecisionEngine.hpp"

/**
 * @brief Jugador controlado por la IA.
 *
 * Delega la toma de decisiones en DecisionEngine y adapta su personalidad
 * (Comportamiento) dinámicamente según el estado de la mesa. En dificultad
 * EXPERTO mantiene un mapa de perfiles estadísticos de sus rivales que se
 * acumula durante toda la partida.
 */
class Bot : public Player {
 public:
  Bot(const std::string& nombre, int saldo);
  Bot(const std::string& nombre, int saldo, Comportamiento nivel);

  /**
   * @brief Ajusta el Comportamiento del bot según la dinámica de la mesa.
   * @param saldoPromedioMesa Saldo medio de los jugadores activos.
   * @param raisesEnMesa      Raises totales en la mano (presión del entorno).
   * @param dificultad        Nivel de IA configurado en las reglas de la partida.
   */
  void actualizarPersonalidad(int saldoPromedioMesa, int raisesEnMesa,
                              DificultadBots dificultad);

  Accion decidirAccion(const GameState& state) override;

  Comportamiento getNivel() const;
  void setNivel(Comportamiento nivel);

  // ── Perfilado de rivales (solo activo en dificultad EXPERTO) ─────────────

  /// Marca el inicio de una nueva mano para el jugador @p nombre.
  void iniciarManoJugador(const std::string& nombre);

  /// Registra una acción de @p nombre para actualizar su perfil estadístico.
  void registrarAccion(const std::string& nombre, TipoAccion accion,
                       Rondas ronda, bool hayApuesta);

  /// @return Mapa de perfiles estadísticos indexado por nombre de jugador.
  const std::map<std::string, PerfilJugador>& getPerfiles() const {
    return perfiles_;
  }

  /**
   * @brief Desactiva el delay artificial de "reflexión" (1-3s) en decidirAccion().
   *
   * Solo para herramientas headless (benchmark de IA): simular miles de manos
   * con el delay real tardaría horas. No usar en partidas reales.
   */
  static void setDelaySimuladoActivo(bool activo) { delaySimuladoActivo_ = activo; }

  /**
   * @brief Realinea el ancla de momentum al saldo actual.
   *
   * Solo para herramientas headless que fuerzan el saldo entre manos (p.ej.
   * el benchmark, que repone el stack a un valor fijo para aislar cada mano
   * de la varianza de eliminación). Sin esto, ese ajuste externo se leería
   * como una "mano ganada/perdida" y contaminaría el sesgo de momentum de
   * actualizarPersonalidad(). En una partida real nunca hace falta llamarlo.
   */
  void realinearSeguimientoSaldo() { saldoAnterior_ = saldo_; }

 private:
  static bool delaySimuladoActivo_;
  Comportamiento nivel_;
  int            numRaisesMiosEnRonda_;    ///< Raises que ha hecho este bot en la ronda actual.
  Rondas         rondaInterna_;            ///< Última fase conocida (para resetear el contador de raises).
  std::map<std::string, PerfilJugador> perfiles_; ///< Historial estadístico de rivales.
  int            saldoAnterior_;           ///< Saldo al final de la última llamada a actualizarPersonalidad (ancla para medir momentum).
};
