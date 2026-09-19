/**
 * @file ObservadorMultiplex.hpp
 * @brief IGameObserver que reenvía cada evento a dos observadores reales.
 *
 * Partida solo sostiene UN std::unique_ptr<IGameObserver> (observer_) --
 * ver Partida.hpp. Para que una partida en vivo alimente a la vez al
 * observador de red (NetworkObserver, lo que ve el jugador) y a la
 * analítica de partidas (AnalyticsObserver, lo que se guarda para
 * estudiar a los bots después, ver docs/plan-herramienta-desarrollador.md)
 * sin tocar Partida ni arriesgar los usos MUY específicos de
 * NetworkObserver que hace main.cpp ANTES de entregarlo (addClient(),
 * setSala(), setJugadoresPartida()...), este envoltorio solo se usa en el
 * ÚLTIMO paso, justo antes de partida.setObserver(): el "principal" sigue
 * siendo el mismo objeto concreto de siempre (su puntero crudo capturado
 * antes del move() sigue siendo válido, esto solo añade un nivel de
 * ownership, no cambia el tiempo de vida) y el "secundario" recibe todo
 * en modo mudo -- ninguna de las respuestas del secundario se usa para
 * decidir nada de la partida real.
 *
 * Si "secundario" es nullptr (analítica desactivada, ver main.cpp), se
 * comporta exactamente como si no existiera este envoltorio -- coste cero
 * más allá de la indirección de la llamada.
 */
#pragma once

#include <memory>

#include "IGameObserver.hpp"

class ObservadorMultiplex : public IGameObserver {
 public:
  ObservadorMultiplex(std::unique_ptr<IGameObserver> principal,
                       std::unique_ptr<IGameObserver> secundario)
      : principal_(std::move(principal)), secundario_(std::move(secundario)) {}

  // ── Flujo de mano ──────────────────────────────────────────────────────
  void onInicioMano(int numMano, int ciegaGrande) override {
    principal_->onInicioMano(numMano, ciegaGrande);
    if (secundario_) secundario_->onInicioMano(numMano, ciegaGrande);
  }
  void onCobroCiegas(const std::string& jPequena, int montoPequena,
                     const std::string& jGrande, int montoGrande) override {
    principal_->onCobroCiegas(jPequena, montoPequena, jGrande, montoGrande);
    if (secundario_) secundario_->onCobroCiegas(jPequena, montoPequena, jGrande, montoGrande);
  }
  void onDealerYCiegasAsignados(const std::string& jDealer, const std::string& jPequena,
                                const std::string& jGrande) override {
    principal_->onDealerYCiegasAsignados(jDealer, jPequena, jGrande);
    if (secundario_) secundario_->onDealerYCiegasAsignados(jDealer, jPequena, jGrande);
  }
  void onRepartoCartasIniciales() override {
    principal_->onRepartoCartasIniciales();
    if (secundario_) secundario_->onRepartoCartasIniciales();
  }
  void onRepartiendoComunitarias(const std::string& faseDesc, int numCartas) override {
    principal_->onRepartiendoComunitarias(faseDesc, numCartas);
    if (secundario_) secundario_->onRepartiendoComunitarias(faseDesc, numCartas);
  }

  // ── Turno de jugador humano / remoto ────────────────────────────────────
  void onPreTurnoHumano(const GameState& state, const std::vector<Player*>& jugadores,
                        const std::vector<int>& botes, const std::vector<std::string>& historial,
                        bool supervisor, const std::vector<Carta>& cartasMesa) override {
    principal_->onPreTurnoHumano(state, jugadores, botes, historial, supervisor, cartasMesa);
    if (secundario_) secundario_->onPreTurnoHumano(state, jugadores, botes, historial, supervisor, cartasMesa);
  }
  void onVerCartasPropias(const std::string& nombre, const std::vector<Carta>& cartas) override {
    principal_->onVerCartasPropias(nombre, cartas);
    if (secundario_) secundario_->onVerCartasPropias(nombre, cartas);
  }
  void onErrorJugada(const std::string& error) override {
    principal_->onErrorJugada(error);
    if (secundario_) secundario_->onErrorJugada(error);
  }

  // ── Acciones ─────────────────────────────────────────────────────────────
  void onAccionJugador(const std::string& nombre, TipoAccion accion, int cantidad) override {
    principal_->onAccionJugador(nombre, accion, cantidad);
    if (secundario_) secundario_->onAccionJugador(nombre, accion, cantidad);
  }
  void onCabeceraResumen() override {
    principal_->onCabeceraResumen();
    if (secundario_) secundario_->onCabeceraResumen();
  }

  // ── Showdown ─────────────────────────────────────────────────────────────
  void onInicioShowdown(const std::vector<Carta>& cartasMesa) override {
    principal_->onInicioShowdown(cartasMesa);
    if (secundario_) secundario_->onInicioShowdown(cartasMesa);
  }
  void onEvaluandoBote(int numBote, int cantidad, const std::vector<std::string>& elegibles) override {
    principal_->onEvaluandoBote(numBote, cantidad, elegibles);
    if (secundario_) secundario_->onEvaluandoBote(numBote, cantidad, elegibles);
  }
  void onMuestraCartas(const std::string& nombre, const std::string& combo,
                       const std::vector<Carta>& cartas,
                       const std::vector<Carta>& combinacion) override {
    principal_->onMuestraCartas(nombre, combo, cartas, combinacion);
    if (secundario_) secundario_->onMuestraCartas(nombre, combo, cartas, combinacion);
  }
  void onGanadorBote(const std::string& nombre, int premio, int numBote,
                     const std::string& combo) override {
    principal_->onGanadorBote(nombre, premio, numBote, combo);
    if (secundario_) secundario_->onGanadorBote(nombre, premio, numBote, combo);
  }
  void onJugadoresDerrotados(const std::vector<std::string>& eliminados) override {
    principal_->onJugadoresDerrotados(eliminados);
    if (secundario_) secundario_->onJugadoresDerrotados(eliminados);
  }
  void onGanadorSinShowdown(const std::string& nombre, int bote,
                            const std::string& handName) override {
    principal_->onGanadorSinShowdown(nombre, bote, handName);
    if (secundario_) secundario_->onGanadorSinShowdown(nombre, bote, handName);
  }

  // ── Fin de sesión / sistema ─────────────────────────────────────────────
  void onPartidaExtendida(int manosExtra, int nuevoObjetivo) override {
    principal_->onPartidaExtendida(manosExtra, nuevoObjetivo);
    if (secundario_) secundario_->onPartidaExtendida(manosExtra, nuevoObjetivo);
  }
  void onFinPartidaGuardada(const std::string& archivo) override {
    principal_->onFinPartidaGuardada(archivo);
    if (secundario_) secundario_->onFinPartidaGuardada(archivo);
  }
  void onAccionSistema(const std::string& mensaje) override {
    principal_->onAccionSistema(mensaje);
    if (secundario_) secundario_->onAccionSistema(mensaje);
  }
  void onErrorSistema(const std::string& categoria, const std::string& mensaje, int codigo) override {
    principal_->onErrorSistema(categoria, mensaje, codigo);
    if (secundario_) secundario_->onErrorSistema(categoria, mensaje, codigo);
  }
  void onFinPartidaLimiteManos(const PartidaStats& stats) override {
    principal_->onFinPartidaLimiteManos(stats);
    if (secundario_) secundario_->onFinPartidaLimiteManos(stats);
  }
  void onFinPartida(const PartidaStats& stats) override {
    principal_->onFinPartida(stats);
    if (secundario_) secundario_->onFinPartida(stats);
  }

  // ── Utilidades ────────────────────────────────────────────────────────
  void onBarraCarga(int ms) override {
    principal_->onBarraCarga(ms);
    if (secundario_) secundario_->onBarraCarga(ms);
  }
  void onLimpiarPantalla() override {
    principal_->onLimpiarPantalla();
    if (secundario_) secundario_->onLimpiarPantalla();
  }
  void onPausarYEsperar() override {
    principal_->onPausarYEsperar();
    if (secundario_) secundario_->onPausarYEsperar();
  }

  // ── Consultas con respuesta -- SIEMPRE gana el principal; el secundario
  //    solo se avisa (si la sobrescribe) para que pueda registrar el
  //    evento, su respuesta se descarta siempre ──────────────────────────
  int onMenuFinDeMano() override {
    if (secundario_) secundario_->onMenuFinDeMano();
    return principal_->onMenuFinDeMano();
  }
  int onPreguntarExtension() override {
    if (secundario_) secundario_->onPreguntarExtension();
    return principal_->onPreguntarExtension();
  }
  std::string onPedirNombreArchivo() override {
    if (secundario_) secundario_->onPedirNombreArchivo();
    return principal_->onPedirNombreArchivo();
  }

  // ── Hooks opcionales ──────────────────────────────────────────────────
  void onCartasReveladas(const std::vector<Carta>& mesa) override {
    principal_->onCartasReveladas(mesa);
    if (secundario_) secundario_->onCartasReveladas(mesa);
  }
  std::vector<JugadorSaliente> getJugadoresSalientes() const override {
    // Solo el principal lleva la cuenta real (ver su comentario en
    // IGameObserver.hpp) -- Partida actúa sobre lo que devuelva esto.
    return principal_->getJugadoresSalientes();
  }
  void clearJugadoresSalientes() override {
    principal_->clearJugadoresSalientes();
    if (secundario_) secundario_->clearJugadoresSalientes();
  }
  void onActualizarSaldos(const std::vector<Player*>& jugadores) override {
    principal_->onActualizarSaldos(jugadores);
    if (secundario_) secundario_->onActualizarSaldos(jugadores);
  }
  void onJugadorDesconectado(const std::string& nombre) override {
    principal_->onJugadorDesconectado(nombre);
    if (secundario_) secundario_->onJugadorDesconectado(nombre);
  }
  void onTurnoIniciado(const GameState& state, const std::vector<Player*>& jugadores,
                       const std::vector<int>& botes, const std::vector<std::string>& historial,
                       const std::vector<Carta>& cartasMesa, int timeoutMs) override {
    principal_->onTurnoIniciado(state, jugadores, botes, historial, cartasMesa, timeoutMs);
    if (secundario_) secundario_->onTurnoIniciado(state, jugadores, botes, historial, cartasMesa, timeoutMs);
  }
  std::vector<std::string> onComprobarRecompras(const std::vector<Player*>& eliminados,
                                                bool esperarUltimaOportunidad = false) override {
    // Consulta con respuesta usada por Partida -- solo el principal decide.
    if (secundario_) secundario_->onComprobarRecompras(eliminados, esperarUltimaOportunidad);
    return principal_->onComprobarRecompras(eliminados, esperarUltimaOportunidad);
  }
  void onCartasPropiasRepartidas(const std::vector<Player*>& jugadores) override {
    principal_->onCartasPropiasRepartidas(jugadores);
    if (secundario_) secundario_->onCartasPropiasRepartidas(jugadores);
  }
  std::vector<Player*> onComprobarNuevosJugadores(int asientosLibres) override {
    if (secundario_) secundario_->onComprobarNuevosJugadores(asientosLibres);
    return principal_->onComprobarNuevosJugadores(asientosLibres);
  }
  void onEstadoActualizado(const std::vector<Player*>& jugadores, const std::vector<int>& botes,
                           const std::vector<Carta>& cartasMesa, Rondas rondaActual,
                           int apuestaAIgualar) override {
    principal_->onEstadoActualizado(jugadores, botes, cartasMesa, rondaActual, apuestaAIgualar);
    if (secundario_) secundario_->onEstadoActualizado(jugadores, botes, cartasMesa, rondaActual, apuestaAIgualar);
  }

 private:
  std::unique_ptr<IGameObserver> principal_;
  std::unique_ptr<IGameObserver> secundario_;  // puede ser nullptr
};
