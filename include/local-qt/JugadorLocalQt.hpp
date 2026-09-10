/**
 * @file JugadorLocalQt.hpp
 * @brief Jugador humano LOCAL (modo offline) -- equivalente sin sockets de NetworkPlayer.
 */
#pragma once

#include <algorithm>

#include <QString>

#include "../HandPredictor.hpp"
#include "../Player.hpp"
#include "../ReglasRaise.hpp"
#include "../net/Serializer.hpp"
#include "LocalGameObserver.hpp"

/**
 * @brief Jugador humano LOCAL (modo offline): sustituye la I/O de socket de
 * NetworkPlayer por una llamada directa y bloqueante a LocalGameObserver,
 * que vive en el hilo de la GUI (ver docs/plan-modo-offline.md sección 2.2).
 *
 * Mismo flujo que NetworkPlayer::decidirAccion() (ver NetworkPlayer.cpp):
 * calcula predicción de mano + límites de subida, notifica "es tu turno" a
 * la GUI (equivalente a mandar TU_TURNO por socket), y bloquea hasta que la
 * GUI entregue una decisión (equivalente a esperar el ACTION de socket) --
 * la diferencia es que aquí "enviar"/"esperar" es un condition_variable
 * (dentro de LocalGameObserver) en vez de send()/recv().
 *
 * NO es QObject a propósito -- vive y se destruye en el hilo de motor junto
 * al resto de Player* de Partida, igual que Bot/NetworkPlayer. Solo
 * LocalGameObserver necesita ser QObject (ver su comentario).
 */
class JugadorLocalQt : public Player {
 public:
  /// @param observador Ya construido en el hilo GUI, ver
  /// LocalGameClient::iniciarPartidaLocal(). No poseído.
  JugadorLocalQt(const std::string& nombre, int saldo, LocalGameObserver* observador)
      : Player(nombre, saldo), observador_(observador) {}

  bool esHumano() const override { return true; }

  Accion decidirAccion(const GameState& state) override {
    const auto& cartas = getCartasPropias();
    QString c1 = QString::fromStdString(cartas.size() > 0 ? net::ser::cartaToStr(cartas[0]) : "??");
    QString c2 = QString::fromStdString(cartas.size() > 1 ? net::ser::cartaToStr(cartas[1]) : "??");

    auto hi = predecirMano(cartas, state.cartasComunitarias);

    int aPagarParaIgualar = std::max(0, state.apuestaAIgualar - state.miApuestaEnRonda);
    auto [minSubida, maxSubida] = calcularLimitesRaise(state, aPagarParaIgualar, state.miSaldo);

    observador_->notificarMiTurno(
        state.boteTotal, state.apuestaAIgualar, state.miSaldo, state.miApuestaEnRonda,
        TURNO_TIMEOUT_MS, minSubida, maxSubida, c1, c2,
        QString::fromStdString(hi.actual), QString::fromStdString(hi.probable),
        QString::fromStdString(hi.maxima));

    return observador_->esperarAccion(aPagarParaIgualar);
  }

 private:
  LocalGameObserver* observador_;  ///< No poseído -- vive en el hilo GUI.
};
