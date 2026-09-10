#include "../include/Mesa.hpp"

Mesa::Mesa() : apuestaMinima_(0) {}

void Mesa::agregarCarta(const Carta& carta) {
  if (cartasComunitarias_.size() >= 5) {
    throw std::logic_error(
        "Error: No se pueden agregar más de 5 cartas a la mesa.");
  }
  cartasComunitarias_.push_back(carta);
}

void Mesa::limpiarMano() {
  cartasComunitarias_.clear();
  apuestaMinima_ = 0;
}

// Getters y Setters 
[[nodiscard]] const std::vector<Carta>& Mesa::getCartasComunitarias() const {
  return cartasComunitarias_;
}

[[nodiscard]] int Mesa::getApuestaMinima() const { return apuestaMinima_; }

void Mesa::actualizarApuestaMinima(int nuevaApuesta) {
  if (nuevaApuesta < apuestaMinima_) {
    throw std::invalid_argument(
        "La nueva apuesta no puede ser menor a la apuesta mínima actual a "
        "igualar.");
  }
  apuestaMinima_ = nuevaApuesta;
}

std::ostream& operator<<(std::ostream& os, const Mesa& mesa) {
  os << "=== MESA === | Apuesta a igualar: " << mesa.apuestaMinima_
     << " | Cartas: ";
  if (mesa.cartasComunitarias_.empty()) {
    os << "[ Vacía ]";
  } else {
    for (const auto& carta : mesa.cartasComunitarias_) {
      os << carta << " ";
    }
  }
  return os;
}
