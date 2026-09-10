#include "../include/Baraja.hpp"

Baraja::Baraja() { generar(); }

void Baraja::generar() {
  cartas_.clear();
  cartas_.reserve(52);  
  for (int p = static_cast<int>(Palo::CORAZONES);
       p <= static_cast<int>(Palo::PICAS); ++p) {
    for (int v = static_cast<int>(Valor::DOS); v <= static_cast<int>(Valor::AS);
         ++v) {
      cartas_.emplace_back(static_cast<Palo>(p), static_cast<Valor>(v));
    }
  }
}

void Baraja::mezclar() {
  generar();
  // std::random_device obtiene entropía del hardware del sistema operativo
  std::random_device randomDevice;
  // Inicializamos el motor Mersenne Twister con la semilla aleatoria
  std::mt19937 engine(randomDevice());
  std::shuffle(cartas_.begin(), cartas_.end(), engine);
}

Carta Baraja::repartir() {
  if (cartas_.empty()) {
    throw std::out_of_range(style::Red +
                            "Error: Intento de repartir de una baraja vacía." +
                            style::Reset);
  }
  Carta carta_repartida = cartas_.back();
  cartas_.pop_back(); 
  return carta_repartida;
}

[[nodiscard]] size_t Baraja::getCartasRestantes() const {
  return cartas_.size();
}