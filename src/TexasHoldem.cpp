#include "../include/TexasHoldem.hpp"

#include <utility>

TexasHoldem::TexasHoldem(const std::vector<std::string>& nombres, int numBots,
                         int numJugadores, int manosObjetivo,
                         int valorCiegaGrande, bool supervisor,
                         const ReglasJuego& reglas)
    : Partida(nombres, numBots, numJugadores, manosObjetivo, valorCiegaGrande,
              supervisor, reglas) {}

TexasHoldem::TexasHoldem(std::vector<Player*> jugadores, int manosObjetivo,
                         int ciegaGrande, bool supervisor,
                         const ReglasJuego& reglas)
    : Partida(std::move(jugadores), manosObjetivo, ciegaGrande, supervisor, reglas) {}

TexasHoldem::TexasHoldem(PartidaSnapshot snap) : Partida(snap) {}

void TexasHoldem::repartirCartasIniciales() {
  // observer_ es protected en Partida, accesible desde hijas
  observer_->onRepartoCartasIniciales();

  for (Player* p : jugadores_) {
    if (p->getEstado() == PlayerState::ACTIVO) {
      Carta c1 = baraja_.repartir();
      Carta c2 = baraja_.repartir();
      p->recibirCartas(c1, c2);
    }
  }

  observer_->onCartasPropiasRepartidas(jugadores_);
}

void TexasHoldem::ejecutarFaseComunitaria() {
  if (faseActual_ != Rondas::RIVER) {
    baraja_.repartir();  // Quemar carta
  }

  switch (faseActual_) {
    case Rondas::PREFLOP:
      observer_->onRepartiendoComunitarias("FLOP", 3);
      mesa_.agregarCarta(baraja_.repartir());
      mesa_.agregarCarta(baraja_.repartir());
      mesa_.agregarCarta(baraja_.repartir());
      observer_->onCartasReveladas(mesa_.getCartasComunitarias());
      break;

    case Rondas::FLOP:
      observer_->onRepartiendoComunitarias("TURN", 1);
      mesa_.agregarCarta(baraja_.repartir());
      observer_->onCartasReveladas(mesa_.getCartasComunitarias());
      break;

    case Rondas::TURN:
      observer_->onRepartiendoComunitarias("RIVER", 1);
      mesa_.agregarCarta(baraja_.repartir());
      observer_->onCartasReveladas(mesa_.getCartasComunitarias());
      break;

    default:
      break;
  }
}

bool TexasHoldem::manoTerminada() { return faseActual_ == Rondas::RIVER; }
