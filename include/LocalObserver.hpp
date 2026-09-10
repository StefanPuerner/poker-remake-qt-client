/**
 * @file LocalObserver.hpp
 * @brief Implementación de IGameObserver para partidas en local (terminal).
 */
#pragma once

#include "IGameObserver.hpp"
#include "Interfaz.hpp"

/**
 * @brief Implementación de IGameObserver para partidas en local.
 *
 * Traduce cada evento del motor en una llamada a los métodos estáticos de
 * Interfaz, que imprimen el resultado en la terminal. El comportamiento del
 * juego local es idéntico al anterior a la introducción del Observer.
 */
class LocalObserver : public IGameObserver {
 public:
  // ── Flujo de mano ──────────────────────────────────────────────────────────
  void onInicioMano(int numMano, int ciegaGrande) override;
  void onCobroCiegas(const std::string& jPequena, int montoPequena,
                     const std::string& jGrande, int montoGrande) override;
  void onRepartoCartasIniciales() override;
  void onRepartiendoComunitarias(const std::string& faseDesc, int numCartas) override;

  // ── Turno humano ───────────────────────────────────────────────────────────
  void onPreTurnoHumano(const GameState& state,
                        const std::vector<Player*>& jugadores,
                        const std::vector<int>& botes,
                        const std::vector<std::string>& historial,
                        bool supervisor,
                        const std::vector<Carta>& cartasMesa) override;
  void onVerCartasPropias(const std::string& nombre,
                          const std::vector<Carta>& cartas) override;
  void onErrorJugada(const std::string& error) override;

  // ── Acciones ───────────────────────────────────────────────────────────────
  void onAccionJugador(const std::string& nombre, TipoAccion accion,
                       int cantidad) override;
  void onCabeceraResumen() override;

  // ── Showdown ───────────────────────────────────────────────────────────────
  void onInicioShowdown(const std::vector<Carta>& cartasMesa) override;
  void onEvaluandoBote(int numBote, int cantidad,
                        const std::vector<std::string>& elegibles) override;
  void onMuestraCartas(const std::string& nombre, const std::string& combo,
                       const std::vector<Carta>& cartas,
                       const std::vector<Carta>& combinacion) override;
  void onGanadorBote(const std::string& nombre, int premio, int numBote,
                     const std::string& combo) override;
  void onJugadoresDerrotados(const std::vector<std::string>& eliminados) override;
  void onGanadorSinShowdown(const std::string& nombre, int bote,
                            const std::string& handName) override;

  // ── Sesión / sistema ───────────────────────────────────────────────────────
  void onPartidaExtendida(int manosExtra, int nuevoObjetivo) override;
  void onFinPartidaGuardada(const std::string& archivo) override;
  void onAccionSistema(const std::string& mensaje) override;
  void onErrorSistema(const std::string& categoria, const std::string& mensaje,
                      int codigo) override;
  void onFinPartidaLimiteManos(const PartidaStats& stats) override;
  void onFinPartida(const PartidaStats& stats) override;

  // ── Utilidades ─────────────────────────────────────────────────────────────
  void onBarraCarga(int ms) override;
  void onLimpiarPantalla() override;
  void onPausarYEsperar() override;

  // ── Consultas con respuesta ────────────────────────────────────────────────
  int         onMenuFinDeMano()      override;
  int         onPreguntarExtension() override;
  std::string onPedirNombreArchivo() override;
};
