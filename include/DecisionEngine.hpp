/**
 * @file DecisionEngine.hpp
 * @brief Motor de decisión de la IA: calcula la acción de un Bot.
 *
 * Overhaul (v0.12): el motor anterior decidía con umbrales fijos que apenas
 * dependían del PRECIO de la apuesta y estrechaba el rango del rival igual ante
 * una apuesta mínima que ante un all-in -- exactamente lo que explota quien
 * juega sin subida mínima (apostar 1 ficha, o "subir siempre"). El motor actual
 * se apoya en tres ideas:
 *
 *  1. **Equity contra un rango ponderado por el TAMAÑO de la apuesta.** El
 *     rango del rival se ordena por fuerza sobre la mesa actual y se pondera
 *     con q^gamma, donde gamma crece con apuesta/bote (una apuesta de 1 ficha
 *     casi no dice nada; una del tamaño del bote, mucho). Sirve igual con o sin
 *     subida mínima y con cualquier tipo de límite.
 *  2. **Igualar si equity >= precio** (bote a favor), con un margen y un ruido
 *     que dependen de la dificultad, en vez de umbrales fijos.
 *  3. **Todo tamaño de apuesta sale de los límites reales de la partida**
 *     (calcularLimitesRaise): No-Limit con o sin mínimo, Pot-Limit y Fixed-Limit.
 *
 * La dificultad no es "más cálculo": es un conjunto de rasgos (cuánto lee la
 * apuesta, cuánto paga de más, cuánto farolea, cuánto se le nota...). FACIL es
 * explotable a propósito; EXPERTO mezcla y se adapta al rival.
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

/// Todo lo que el Bot aporta a una decisión además del estado de la mesa.
struct ContextoBot {
  DificultadBots dificultad = DificultadBots::NORMAL;
  Comportamiento nivel = Comportamiento::EQUILIBRADO;
  int numRaisesMiosEnRonda = 0;       ///< Subidas propias en la calle actual (tope).
  bool fuiAgresorPreflop = false;     ///< Subí antes del flop (para la apuesta de continuación).
  const std::map<std::string, PerfilJugador>* perfiles = nullptr;  ///< Solo EXPERTO.
};

/// Resultado numérico "duro" que el motor ya calcula para decidir, expuesto
/// sin decidir una acción -- para caminos de decisión externos (ver BotLLM)
/// que quieren este contexto en vez de recalcularlo a su manera. Usa
/// exactamente los mismos helpers internos que pensar(): no es un cálculo
/// paralelo ni puede desviarse del comportamiento real del motor.
struct ContextoNumerico {
  bool   esPreflop = true;
  double percentilPreflop = 0.5;  ///< Válido si esPreflop (0-1, 1 = mejor mano inicial posible).
  double equity = 0.5;            ///< Válido si !esPreflop: equity contra el rango ponderado del rival.
  double fuerzaAhora = 0.5;       ///< Válido si !esPreflop: fuerza SIN ponderar sobre la mesa actual.
  double equityRequerida = 0.0;   ///< Equity mínima para igualar (0 si no hay apuesta pendiente).
  bool   proyecto = false;        ///< La equity supera con mucho la fuerza actual (mano por hacer).
};

class DecisionEngine {
 public:
  /// Punto de entrada principal.
  static Accion pensar(const GameState& state, const std::vector<Carta>& cartasPropias,
                       const ContextoBot& ctx);

  /// Mismo cálculo que pensar() (equity vs rango ponderado, pot odds,
  /// percentil preflop) pero sin decidir una acción -- ver ContextoNumerico.
  static ContextoNumerico evaluarContexto(const GameState& state,
                                          const std::vector<Carta>& cartasPropias,
                                          const ContextoBot& ctx);

  /// Compatibilidad: usa state.reglas.dificultadBots como dificultad.
  static Accion pensarAccion(const GameState& state, Comportamiento nivel, int saldo,
                             const std::vector<Carta>& cartasPropias,
                             int numRaisesMiosEnRonda,
                             const std::map<std::string, PerfilJugador>* perfiles = nullptr);

  // ── Utilidades expuestas (también para los tests) ────────────────────────

  /// Percentil (0-1, 1 = mejor) de una mano inicial entre las 1326 posibles.
  static double percentilPreflop(const Carta& a, const Carta& b);

  /**
   * @brief Puntuación rápida de la mejor mano de 5 entre @p n cartas (5-7).
   * Las cartas se codifican como valor*4+palo con valor 0-12 (2..As) y palo 0-3.
   * Solo sirve para COMPARAR entre sí (mayor = mejor); no coincide con
   * Analyzer::HandResult::score, pero ordena igual (lo verifica un test).
   */
  static long long puntuarRapido(const int* cartas, int n);

  /// Codifica una Carta como valor*4+palo (0..51).
  static int codificar(const Carta& c);
};
