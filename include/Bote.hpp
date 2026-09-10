/**
 * @file Bote.hpp
 * @brief Bote (pot) de poker: saldo acumulado, límite de side pot y participantes elegibles.
 */
#pragma once

#include <algorithm>
#include <climits>
#include <iostream>
#include <stdexcept>
#include <vector>

#include "style.hpp"

// Forward declaration de Player para romper dependencias circulares
class Player;

/**
 * @brief Bote (pot) de poker, principal o side pot.
 *
 * Cada vez que un jugador va all-in por un importe menor al bote actual,
 * Partida::gestionarSidePots() crea un Bote secundario con límite distinto
 * y un subconjunto de participantes. Showdown evalúa cada Bote por separado.
 */
class Bote {
 public:
  Bote();

  /// Suma @p cantidad al saldo del bote.
  void agregarSaldo(int cantidad);

  /// @return Saldo acumulado en este bote.
  [[nodiscard]] int getSaldo() const;

  /// @return Límite de contribución individual (INT_MAX = sin límite).
  [[nodiscard]] int getLimite() const;

  /// Fija el límite de contribución (usado al crear side pots).
  void setLimite(int nuevoLimite);

  /// Registra un jugador elegible para ganar este bote.
  void agregarParticipante(Player* jugador);

  /// Elimina un jugador de los elegibles (fold o eliminación).
  void eliminarParticipante(Player* jugador);

  /// @return Lista de jugadores con derecho a competir por este bote.
  [[nodiscard]] const std::vector<Player*>& getParticipantes() const;

  /// Resetea saldo y participantes (reutilización entre manos).
  void limpiar();

 private:
  int limite_;                       ///< Contribución máxima por jugador (side pot).
  int saldo_;                        ///< Dinero acumulado en este bote.
  std::vector<Player*> participantes_; ///< Jugadores elegibles (punteros no poseídos).
};
