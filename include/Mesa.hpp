/**
 * @file Mesa.hpp
 * @brief Mesa de juego: cartas comunitarias y apuesta mínima de la ronda.
 */
#pragma once

#include <iostream>
#include <stdexcept>
#include <vector>

#include "Carta.hpp"

/// Mesa de juego: almacena las cartas comunitarias y la apuesta mínima vigente.
class Mesa {
 private:
  std::vector<Carta> cartasComunitarias_;
  int apuestaMinima_;  ///< Apuesta más alta de la ronda que los demás deben igualar.

 public:
  /// Inicializa la mesa sin cartas y con apuesta mínima 0.
  Mesa();

  /// Añade una carta comunitaria (flop/turn/river).
  void agregarCarta(const Carta& carta);

  /// Limpia cartas comunitarias y resetea la apuesta mínima al inicio de cada mano.
  void limpiarMano();

  /// Resetea solo la apuesta mínima entre fases (las cartas permanecen).
  void reiniciarApuestasRonda() { apuestaMinima_ = 0; }

  /// @return Cartas comunitarias visibles en la mesa.
  [[nodiscard]] const std::vector<Carta>& getCartasComunitarias() const;

  /// @return Apuesta mínima que deben igualar los jugadores pendientes.
  [[nodiscard]] int getApuestaMinima() const;

  /// Actualiza la apuesta mínima cuando alguien sube.
  void actualizarApuestaMinima(int nuevaApuesta);

  /// Imprime las cartas comunitarias y la apuesta mínima actual.
  friend std::ostream& operator<<(std::ostream& os, const Mesa& mesa);
};
