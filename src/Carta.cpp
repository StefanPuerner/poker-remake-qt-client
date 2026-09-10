#include "../include/Carta.hpp"
#include "../include/style.hpp"

Carta::Carta(Palo palo, Valor valor) : palo_(palo), valor_(valor) {}

Valor Carta::getValor() const { return valor_; }

Palo Carta::getPalo() const { return palo_; }

bool Carta::operator==(const Carta& carta) const {
  return valor_ == carta.valor_ && palo_ == carta.palo_;
}

bool Carta::operator<(const Carta& carta) const {
  if (valor_ != carta.valor_) {
    return valor_ < carta.valor_;
  }
  return palo_ < carta.palo_;
}

std::ostream& operator<<(std::ostream& out, const Carta& carta) {
  std::string str_valor;
  switch (carta.getValor()) {
    case Valor::JOTA:
      str_valor = "J";
      break;
    case Valor::REINA:
      str_valor = "Q";
      break;
    case Valor::REY:
      str_valor = "K";
      break;
    case Valor::AS:
      str_valor = "A";
      break;
    default:
      str_valor = std::to_string(static_cast<int>(carta.getValor()));
      break;
  }

  std::string str_carta;
  switch (carta.getPalo()) {
    case Palo::CORAZONES:
      str_carta = style::BgWhite + style::Red + str_valor + style::Corazon;
      break;
    case Palo::DIAMANTES:
      str_carta = style::BgWhite + style::Red + str_valor + style::Diamante;
      break;
    case Palo::TREBOLES:
      str_carta = style::BgWhite + style::Black + str_valor + style::Trebol;
      break;
    case Palo::PICAS:
      str_carta = style::BgWhite + style::Black + str_valor + style::Pica;
      break;
  }
  out << str_carta << style::Reset;
  return out;
}
