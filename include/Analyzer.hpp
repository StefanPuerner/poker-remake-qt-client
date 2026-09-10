/**
 * @file Analyzer.hpp
 * @brief Evaluador de manos Texas Hold'em: HandResult, HandRank y Analyzer.
 */
#pragma once

#include <algorithm>
#include <string>
#include <vector>

#include "Carta.hpp"

/**
 * @brief Resultado de la evaluación de una mano de poker.
 *
 * score codifica la jerarquía completa en base 15 para que dos HandResult
 * se puedan comparar directamente con >, <, == sin lógica adicional.
 */
struct HandResult {
  long long          score;       ///< Puntuación compuesta (HandRank * 15^n + kickers).
  std::string        handName;    ///< Nombre legible ("Color", "Full House", etc.).
  std::vector<Carta> combination; ///< Las 5 cartas que forman la mejor mano.

  bool operator>(const HandResult& other) const { return score > other.score; }
  bool operator<(const HandResult& other) const { return score < other.score; }
  bool operator==(const HandResult& other) const { return score == other.score; }
};

/// Jerarquía de manos de menor a mayor (valores numéricos usados en calcularScoreFinal).
enum class HandRank {
  CARTA_ALTA = 0,
  PAREJA,
  DOBLE_PAREJA,
  TRIO,
  ESCALERA,
  COLOR,
  FULL_HOUSE,
  POKER,
  ESCALERA_COLOR,
  ESCALERA_REAL
};

/**
 * @brief Evaluador de manos de Texas Hold'em.
 *
 * Recibe las 7 cartas disponibles (2 privadas + hasta 5 comunitarias) y
 * determina la mejor mano de 5 cartas posible. Todos los métodos son estáticos.
 */
class Analyzer {
 public:
  /**
   * @brief Evalúa la mejor mano de 5 cartas a partir de @p mano y @p mesa.
   * @param mano  Cartas privadas del jugador (normalmente 2).
   * @param mesa  Cartas comunitarias visibles (0–5).
   * @return HandResult con score, nombre y las 5 cartas de la mejor mano.
   */
  static HandResult evaluarMano(const std::vector<Carta>& mano,
                                const std::vector<Carta>& mesa);

  /// @return Nombre de la mejor mano posible si cayeran las mejores cartas restantes.
  static std::string obtenerMaximoPotencial(const std::vector<Carta>& mano,
                                            const std::vector<Carta>& mesa);

  /// @return Nombre de la combinación más probable con las cartas actuales.
  static std::string obtenerCombinacionMasProbable(
      const std::vector<Carta>& mano, const std::vector<Carta>& mesa);

 private:
  /// Calcula la puntuación final en base 15 a partir del rango y las 5 cartas.
  static long long calcularScoreFinal(HandRank rank,
                                      const std::vector<Carta>& best5);

  // Funciones de evaluación ordenadas de mayor a menor jerarquía.
  static bool buscarEscaleraColor  (const std::vector<Carta>& cartas, HandResult& result);
  static bool buscarPoker          (const std::vector<Carta>& cartas, HandResult& result);
  static bool buscarFullHouse      (const std::vector<Carta>& cartas, HandResult& result);
  static bool buscarColor          (const std::vector<Carta>& cartas, HandResult& result);
  static bool buscarEscalera       (const std::vector<Carta>& cartas, HandResult& result);
  static bool buscarTrio           (const std::vector<Carta>& cartas, HandResult& result);
  static bool buscarDoblePareja    (const std::vector<Carta>& cartas, HandResult& result);
  static bool buscarPareja         (const std::vector<Carta>& cartas, HandResult& result);
};
