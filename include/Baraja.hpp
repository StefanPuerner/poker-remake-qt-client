/**
 * @file Baraja.hpp
 * @brief Baraja francesa de 52 cartas: generación, mezcla y reparto.
 */
#pragma once
#include <algorithm>
#include <random>
#include <stdexcept>
#include <vector>

#include "Carta.hpp"
#include "style.hpp"

/// Baraja francesa de 52 cartas con generación, mezcla y reparto.
class Baraja {
 public:
  Baraja();
  /// Genera las 52 cartas (borra el estado anterior).
  void generar();
  /// Mezcla las cartas usando std::shuffle con mt19937.
  void mezclar();
  /// Saca y devuelve la carta de la cima. @throws std::runtime_error si está vacía.
  Carta repartir();
  /// @return Número de cartas que quedan en el mazo.
  [[nodiscard]] size_t getCartasRestantes() const;

 private:
  std::vector<Carta> cartas_;
};
