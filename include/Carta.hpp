/**
 * @file Carta.hpp
 * @brief Tipos Palo, Valor y la clase Carta de una baraja francesa estándar.
 */
#pragma once
#include <iostream>

/// Palo de una carta francesa estándar.
enum class Palo {
  CORAZONES,
  DIAMANTES,
  TREBOLES,
  PICAS
};

/// Valor numérico de una carta; el As vale 14 para facilitar comparaciones.
enum class Valor {
    DOS = 2, TRES, CUATRO, CINCO, SEIS, SIETE, OCHO, NUEVE, DIEZ,
    JOTA = 11, REINA = 12, REY = 13, AS = 14
};

/// Carta individual de una baraja francesa estándar (palo + valor).
class Carta {
 public:
  /// Construye una carta con el palo y valor indicados.
  Carta(Palo palo, Valor valor);
  /// @return Valor numérico de la carta (2–14).
  [[nodiscard]] Valor getValor() const;
  /// @return Palo de la carta.
  [[nodiscard]] Palo getPalo() const;
  /// @return true si palo y valor coinciden exactamente.
  bool operator==(const Carta& carta) const;
  /// Ordena por valor numérico; útil para ordenar manos antes de evaluar.
  bool operator<(const Carta& carta) const;
  /// Imprime la carta como "J♥" o "A♠" usando los símbolos de palo Unicode.
  friend std::ostream& operator<<(std::ostream& out, const Carta& carta);
 private:
 Palo palo_;
 Valor valor_;
};
