#include "../include/Bote.hpp"

Bote::Bote() : limite_(INT_MAX), saldo_(0) {}

void Bote::agregarSaldo(int cantidad) {
  if (cantidad < 0) {
    throw std::invalid_argument(
        "No se puede agregar un saldo negativo al bote.");
  }
  if ((saldo_ + cantidad) > limite_)
    throw std::invalid_argument(style::Red + "Saldo sobrepasa el limite." +
                                style::Reset);
  saldo_ += cantidad;
}

[[nodiscard]] int Bote::getSaldo() const { return saldo_; }

[[nodiscard]] int Bote::getLimite() const { return limite_; }

void Bote::setLimite(int nuevoLimite) {
  if (nuevoLimite <= 0) {
    throw std::invalid_argument("El límite del bote no puede ser negativo ni nulo.");
  }
  limite_ = nuevoLimite;
}

void Bote::agregarParticipante(Player* jugador) {
  if (!jugador) {
    throw std::invalid_argument("El jugador no puede ser nulo.");
  }
  if (std::find(participantes_.begin(), participantes_.end(), jugador) ==
      participantes_.end()) {
    participantes_.push_back(jugador);
  }
}

void Bote::eliminarParticipante(Player* jugador) {
  auto it = std::find(participantes_.begin(), participantes_.end(), jugador);
  if (it != participantes_.end()) {
    participantes_.erase(it);
  }
}

[[nodiscard]] const std::vector<Player*>& Bote::getParticipantes() const {
  return participantes_;
}

void Bote::agregarAportacion(Player* jugador, int cantidad) {
  if (cantidad <= 0) return;
  for (auto& a : aportaciones_) {
    if (a.first == jugador) {
      a.second += cantidad;
      return;
    }
  }
  aportaciones_.emplace_back(jugador, cantidad);
}

const std::vector<std::pair<Player*, int>>& Bote::getAportaciones() const { return aportaciones_; }

void Bote::limpiar() {
  aportaciones_.clear();
  saldo_ = 0;
  limite_ = INT_MAX;
  participantes_.clear();
}