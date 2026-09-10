/**
 * @file HandPredictor.hpp
 * @brief Predicción de mano (actual/probable/máxima) para mostrar al jugador.
 */
#pragma once

#include <string>
#include <vector>

#include "Carta.hpp"

/**
 * @brief Predicción de mano en un momento dado de la partida.
 *
 * "actual": lo que tienes ahora (o una caracterización preflop tipo "Suited
 * connector" si aún no hay cartas comunitarias). "probable": la mano más
 * frecuente al enumerar las cartas que aún pueden caer. "maxima": la mejor
 * mano posible entre esos mismos escenarios. Preflop, probable/maxima son
 * "—" (no hay suficiente información para enumerar nada útil).
 */
struct HandPrediccion {
  std::string actual, probable, maxima;
};

/**
 * @brief Calcula la predicción de mano de @p propias sobre @p mesa.
 *
 * Antes duplicado tal cual (misma struct HandInfo, mismo cuerpo) en
 * NetworkObserver.cpp (para COMBO_UPDATE) y NetworkPlayer.cpp (para
 * TU_TURNO) -- extraído aquí para que JugadorLocalQt/LocalGameObserver
 * (modo offline) puedan producir la MISMA predicción sin triplicar el
 * cuerpo una vez más (ver docs/plan-modo-offline.md).
 *
 * Nota: hace su propia enumeración de cartas desconocidas en una sola
 * pasada combinada (actual/probable/maxima a la vez) -- a diferencia de
 * Analyzer::obtenerMaximoPotencial()/obtenerCombinacionMasProbable(), que
 * hacen cada una su propia enumeración por separado (usadas por el modo
 * ncurses vía Interfaz). Se deja así a propósito: unificar ambos caminos
 * es un refactor más grande, fuera de alcance de esta extracción puntual.
 */
HandPrediccion predecirMano(const std::vector<Carta>& propias,
                            const std::vector<Carta>& mesa);
