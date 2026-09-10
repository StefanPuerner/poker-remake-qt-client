/**
 * @file Player.hpp
 * @brief Interfaz polimórfica de jugador (Persona, Bot, NetworkPlayer).
 */
#pragma once

#include <string>
#include <vector>

#include "../include/Carta.hpp"
#include "GameTypes.hpp"

/**
 * @brief Interfaz polimórfica de jugador.
 *
 * Implementaciones concretas: Persona (entrada por teclado), Bot (IA) y
 * NetworkPlayer (cliente remoto via socket). El motor de Partida solo conoce
 * Player*, lo que permite mezclar los tres tipos en la misma mesa.
 */
class Player {
 public:
  /// @param accountId 0 = invitado, sin cuenta (Persona/Bot nunca lo
  /// pasan). NetworkPlayer lo recibe del servidor cuando el token que
  /// mandó el cliente resolvió a una cuenta real (ver AccountManager) --
  /// no implica todavía ninguna estadística/logro, solo deja la
  /// identidad disponible para cuando se implementen (ver el plan de
  /// cuentas, fuera de alcance de esta rama).
  Player(const std::string& nombre, int saldoInicial, int accountId = 0)
      : nombre_(nombre),
        saldo_(saldoInicial),
        accountId_(accountId),
        estado_(PlayerState::ACTIVO),
        apuestaAcumuladaRonda_(0),
        apuestaAcumuladaMano_(0) {}

  virtual ~Player() = default;

  /**
   * @brief Decide la acción del jugador dado el estado actual del juego.
   *
   * En Persona lee de stdin; en Bot ejecuta DecisionEngine; en NetworkPlayer
   * serializa el estado y espera la respuesta del cliente remoto.
   */
  virtual Accion decidirAccion(const GameState& state) = 0;

  /**
   * @return true si el motor debe llamar onPreTurnoHumano() y onErrorJugada()
   *         antes/después de cada intento de decidirAccion().
   */
  virtual bool esHumano() const { return false; }

  // ── Getters ───────────────────────────────────────────────────────────────

  [[nodiscard]] std::string getNombre() const { return nombre_; }
  [[nodiscard]] int getSaldo() const { return saldo_; }
  /// @return id de cuenta (0 = invitado, sin cuenta).
  [[nodiscard]] int getAccountId() const { return accountId_; }
  [[nodiscard]] PlayerState getEstado() const { return estado_; }
  [[nodiscard]] const std::vector<Carta>& getCartas() const { return cartasPropias_; }
  [[nodiscard]] const std::vector<Carta>& getCartasPropias() const { return cartasPropias_; }

  /// @return Fichas apostadas en la ronda actual (se resetea entre fases).
  [[nodiscard]] int getApuestaAcumuladaRonda() const { return apuestaAcumuladaRonda_; }

  /// @return Fichas apostadas en toda la mano (se resetea entre manos).
  [[nodiscard]] int getApuestaAcumuladaMano() const { return apuestaAcumuladaMano_; }

  // ── Setters / mutadores ───────────────────────────────────────────────────

  void setEstado(PlayerState nuevoEstado) { estado_ = nuevoEstado; }

  /// Asigna las dos cartas privadas del jugador para esta mano.
  void recibirCartas(const Carta& c1, const Carta& c2) {
    cartasPropias_.clear();
    cartasPropias_.push_back(c1);
    cartasPropias_.push_back(c2);
  }

  /// Descuenta @p cantidad del saldo; si llega a 0 cambia estado a ALL_IN.
  void descontarSaldo(int cantidad) {
    if (cantidad > saldo_) cantidad = saldo_;
    saldo_ -= cantidad;
    apuestaAcumuladaRonda_ += cantidad;
    apuestaAcumuladaMano_  += cantidad;
    if (saldo_ == 0) estado_ = PlayerState::ALL_IN;
  }

  /// Añade @p cantidad al saldo (ganar bote o redistribución).
  void ganarSaldo(int cantidad) { saldo_ += cantidad; }

  void resetearApuestaRonda() { apuestaAcumuladaRonda_ = 0; }
  void resetearApuestaMano()  { apuestaAcumuladaMano_  = 0; }
  void vaciarCartasPropias()  { cartasPropias_.clear(); }

 protected:
  std::string          nombre_;
  int                  saldo_;
  int                  accountId_;  ///< 0 = invitado, sin cuenta.
  std::vector<Carta>   cartasPropias_;
  PlayerState          estado_;
  int                  apuestaAcumuladaRonda_; ///< Acumulado en la fase de apuestas vigente.
  int                  apuestaAcumuladaMano_;  ///< Acumulado en toda la mano.
};
