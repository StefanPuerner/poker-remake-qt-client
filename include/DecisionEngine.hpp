/**
 * @file DecisionEngine.hpp
 * @brief Motor de decisión de la IA: calcula la acción óptima para un Bot.
 */
#pragma once

#include <map>
#include <string>
#include <vector>

#include "Analyzer.hpp"
#include "Carta.hpp"
#include "GameTypes.hpp"

/// Estilos de juego que un Bot puede adoptar en cualquier momento.
enum class Comportamiento { SEGURO, EQUILIBRADO, AGRESIVO };

/**
 * @brief Motor de decisión de la IA: calcula la acción óptima para un Bot.
 *
 * Todos los métodos son estáticos (sin estado): el Bot proporciona su
 * contexto en cada llamada. La calidad de la decisión escala con la
 * dificultad configurada en ReglasJuego::dificultadBots:
 *
 *  - FACIL:   equity + textura básica + posición.
 *  - NORMAL:  + range narrowing + cálculo de outs + river ajustado.
 *  - EXPERTO: + perfilado estadístico de rivales acumulado por partida.
 */
class DecisionEngine {
 public:
  /**
   * @brief Punto de entrada principal: devuelve la Accion que debe ejecutar el Bot.
   * @param state        Estado público de la mesa en este momento.
   * @param nivel        Comportamiento actual del bot (SEGURO/EQUILIBRADO/AGRESIVO).
   * @param saldo        Fichas disponibles del bot.
   * @param cartasPropias Cartas privadas del bot.
   * @param numRaisesMiosEnRonda Raises que ya ha hecho el bot en esta ronda (cap de raises).
   * @param perfiles     Perfiles estadísticos de rivales (solo EXPERTO; nullptr = ignorar).
   */
  static Accion pensarAccion(const GameState& state, Comportamiento nivel,
                             int saldo, const std::vector<Carta>& cartasPropias,
                             int numRaisesMiosEnRonda,
                             const std::map<std::string, PerfilJugador>* perfiles = nullptr);

 private:
  static std::vector<Carta> obtenerCartasDesconocidas(
      const GameState& state, const std::vector<Carta>& cartasPropias);

  /// Fuerza relativa de la mano actual respecto a la mejor posible (0–1).
  static double calcularFuerzaMano(const GameState& state,
                                   const std::vector<Carta>& cartasPropias);

  /**
   * @brief Estimación de fuerza O(1) para FACIL: una sola evaluación de la
   * categoría de mano (pareja, color, full...) mapeada a un valor fijo, sin
   * comparar contra el rango del rival. Es deliberadamente cruda: no
   * distingue kickers ni number de rivales, igual que un jugador principiante
   * que solo mira "qué tengo" sin pensar en "qué puede tener el otro".
   */
  static double calcularFuerzaBruta(const std::vector<Carta>& cartasPropias,
                                    const std::vector<Carta>& mesa);

  /// Probabilidad de mejorar la mano en las próximas calles (0–1).
  static double calcularProbabilidadMejorar(
      const GameState& state, const std::vector<Carta>& cartasPropias);

  static int calcularMontoRaise(const GameState& state, Comportamiento nivel,
                                int saldo, double fuerza);

  static bool decidirFarol(Rondas ronda, Comportamiento nivel, double fuerza,
                           double mejora, bool accionAnteriorFueCheck = false);

  /// Equity estimada por simulación Monte Carlo con @p numSimulaciones muestras.
  static double simularEquityMonteCarlo(const GameState& state,
                                        const std::vector<Carta>& cartasPropias,
                                        int numSimulaciones = 600);

  static double calcularDecisionScore(Rondas ronda, double fuerzaActual,
                                      double equityFutura, int numJugadores = 2);

  /// Peligro de la mesa: detecta posibles flushes/escaleras en las comunitarias (0–1).
  static double analizarPeligroMesa(const std::vector<Carta>& mesa);

  /// Número de outs (cartas que mejorarían la mano).
  static int contarOuts(const GameState& state,
                        const std::vector<Carta>& cartasPropias);

  /// Convierte outs a probabilidad de mejorar según la calle (rule of 2 & 4).
  static double calcularEquityPorOuts(int outs, Rondas ronda);

  /// Contribución propia al board: cuánto depende la mano de las cartas privadas (0–1).
  static double calcularContribucionPropia(const std::vector<Carta>& cartasPropias,
                                           const std::vector<Carta>& mesa);

  /// Fuerza ajustada al rango estimado de rivales (narrow range en NORMAL/EXPERTO).
  static double estimarFuerzaConRango(const GameState& state,
                                      const std::vector<Carta>& cartasPropias);
};
