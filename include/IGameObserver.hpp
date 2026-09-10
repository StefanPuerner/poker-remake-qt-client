/**
 * @file IGameObserver.hpp
 * @brief Interfaz Observer para todos los eventos del motor de juego.
 */
#pragma once

#include <string>
#include <vector>

#include "Carta.hpp"
#include "GameTypes.hpp"
#include "Player.hpp"

/// Un jugador que sale de la mesa entre manos, y por qué -- getJugadoresSalientes()
/// necesita distinguir un LEAVE explícito (voluntario) de una expulsión por
/// timeout de reconexión (60s sin volver, no lo pidió) para que Partida
/// sepa si debe redistribuir sus fichas (voluntario) o conservarle el
/// asiento intacto para una reconexión/recarga posterior (involuntario).
struct JugadorSaliente {
  std::string nombre;
  bool voluntario;
};

/**
 * @brief Interfaz Observer para todos los eventos del motor de juego.
 *
 * Partida dispara eventos virtuales en lugar de llamar a la UI directamente.
 * Las implementaciones concretas deciden cómo presentar cada evento:
 *
 *  - LocalObserver  → imprime en el terminal via Interfaz (modo local).
 *  - NetworkObserver → serializa a JSON y hace broadcast por socket (modo red).
 *
 * Para añadir un nuevo modo de presentación (replay, GUI, test headless…)
 * basta con crear otra clase derivada sin tocar el motor.
 */
class IGameObserver {
 public:
  virtual ~IGameObserver() = default;

  // ── Flujo de mano ──────────────────────────────────────────────────────────

  virtual void onInicioMano(int numMano, int ciegaGrande) = 0;
  virtual void onCobroCiegas(const std::string& jPequena, int montoPequena,
                             const std::string& jGrande, int montoGrande) = 0;
  /// Quién es el dealer/SB/BB de la mano que empieza -- default no-op
  /// (mismo patrón que onEstadoActualizado()): solo NetworkObserver lo
  /// necesita, para los marcadores D/SB/BB del cliente. LocalObserver ya
  /// muestra SB/BB vía onCobroCiegas() y no tiene ningún uso para el
  /// dealer explícito, así que no hace falta tocarlo ni al benchmark.
  virtual void onDealerYCiegasAsignados(const std::string& /*jDealer*/,
                                        const std::string& /*jPequena*/,
                                        const std::string& /*jGrande*/) {}
  virtual void onRepartoCartasIniciales() = 0;
  virtual void onRepartiendoComunitarias(const std::string& faseDesc, int numCartas) = 0;

  // ── Turno de jugador humano / remoto ───────────────────────────────────────

  /**
   * @brief Llamado antes de cada intento de decidirAccion() de un jugador humano.
   *
   * LocalObserver redibuja la pantalla completa. NetworkObserver serializa
   * el GameState público y lo manda al cliente para que lo renderice.
   * Las cartas privadas las envía NetworkPlayer por su cuenta (son unicast).
   */
  virtual void onPreTurnoHumano(const GameState& state,
                                const std::vector<Player*>& jugadores,
                                const std::vector<int>& botes,
                                const std::vector<std::string>& historial,
                                bool supervisor,
                                const std::vector<Carta>& cartasMesa) = 0;

  /// El jugador solicitó ver sus propias cartas (acción VER_CARTAS, no consume el turno).
  virtual void onVerCartasPropias(const std::string& nombre,
                                  const std::vector<Carta>& cartas) = 0;

  /// El motor rechazó la acción: cantidad inválida, raise insuficiente, etc.
  virtual void onErrorJugada(const std::string& error) = 0;

  // ── Acciones ───────────────────────────────────────────────────────────────

  /// Notifica la acción de cualquier jugador (bot o humano). No se llama para Persona local.
  virtual void onAccionJugador(const std::string& nombre, TipoAccion accion,
                               int cantidad) = 0;

  /// El humano hizo fold/all-in y ya no quedan humanos activos: cabecera "modo espectador".
  virtual void onCabeceraResumen() = 0;

  // ── Showdown ───────────────────────────────────────────────────────────────

  virtual void onInicioShowdown(const std::vector<Carta>& cartasMesa) = 0;
  /// "elegibles": nombres de quienes compiten por ESTE bote (ya filtrados
  /// de fold/eliminados) — para que el cliente pueda mostrar quién compite
  /// por cada side pot, no solo el monto.
  virtual void onEvaluandoBote(int numBote, int cantidad,
                               const std::vector<std::string>& elegibles) = 0;
  /// "cartas": las 2 cartas PROPIAS del jugador (mano oculta), para
  /// mostrarlas. "combinacion": las 5 cartas de la MEJOR mano evaluada
  /// (HandResult::combination -- puede incluir cartas comunitarias, no
  /// solo "cartas") -- añadido 2026-09-01 para logros que necesitan saber
  /// el rango exacto de una combinación (p. ej. "Póker de Ases": "combo"
  /// por sí solo dice "Poker" pero no de qué valor).
  virtual void onMuestraCartas(const std::string& nombre, const std::string& combo,
                               const std::vector<Carta>& cartas,
                               const std::vector<Carta>& combinacion) = 0;
  virtual void onGanadorBote(const std::string& nombre, int premio,
                             int numBote, const std::string& combo) = 0;
  virtual void onJugadoresDerrotados(const std::vector<std::string>& eliminados) = 0;
  /// @param handName Nombre de la combinación final del ganador (mismo
  /// formato que onMuestraCartas), o "" si la mesa no llegó a tener las 5
  /// cartas comunitarias completas (todos foldearon antes del río -- no
  /// hay combinación final real que evaluar, ver Partida::repartirBotes()).
  /// No implica mostrar las cartas a nadie más: solo sirve para que las
  /// estadísticas personales cuenten esta mano igual que un showdown real.
  virtual void onGanadorSinShowdown(const std::string& nombre, int bote,
                                    const std::string& handName) = 0;

  // ── Fin de sesión / sistema ────────────────────────────────────────────────

  /// @param manosExtra Cuántas manos se añadieron (elegidas por el host).
  /// @param nuevoObjetivo Nuevo total de manos de la partida (manosExtra
  /// ya sumado) -- para que el cliente actualice su "Mano X/Y" sin tener
  /// que sumarlo él mismo sobre un valor local que podría estar obsoleto.
  virtual void onPartidaExtendida(int manosExtra, int nuevoObjetivo) = 0;
  virtual void onFinPartidaGuardada(const std::string& archivo) = 0;
  virtual void onAccionSistema(const std::string& mensaje) = 0;
  virtual void onErrorSistema(const std::string& categoria,
                              const std::string& mensaje, int codigo) = 0;
  /// @param stats Estadísticas completas de la partida terminada (ganador,
  /// saldo, manos disputadas, mejor mano de la sesión y quién la consiguió,
  /// y en qué mano quedó eliminado cada jugador) — las mismas que ya
  /// calcula Partida::generarEstadisticas() y que antes solo se guardaban
  /// en historial_general.stats sin llegar a mostrarse al terminar.
  virtual void onFinPartidaLimiteManos(const PartidaStats& stats) = 0;
  virtual void onFinPartida(const PartidaStats& stats) = 0;

  // ── Utilidades ─────────────────────────────────────────────────────────────

  virtual void onBarraCarga(int ms) = 0;
  virtual void onLimpiarPantalla() = 0;
  virtual void onPausarYEsperar() = 0;

  // ── Consultas con respuesta (el Observer devuelve la decisión del usuario) ──

  /**
   * @brief Menú de fin de mano. @return 1=continuar, 2=guardar+salir, 3=salir sin guardar.
   *
   * En NetworkObserver espera votos de todos los clientes conectados.
   */
  virtual int         onMenuFinDeMano()      = 0;

  /**
   * @brief Pregunta si se quiere extender la partida más allá del límite de manos.
   * @return Número de manos extra (0 = no extender).
   */
  virtual int         onPreguntarExtension() = 0;

  /// Solicita un nombre de archivo para guardar. NetworkObserver genera uno automático.
  virtual std::string onPedirNombreArchivo() = 0;

  // ── Hooks opcionales (default no-op) ──────────────────────────────────────

  /// Llamado tras revelar cartas comunitarias; NetworkObserver reenvía el estado a los clientes.
  virtual void onCartasReveladas(const std::vector<Carta>& /*mesa*/) {}

  /// @return Jugadores que salen de la mesa (LEAVE explícito o expulsión
  /// por timeout de reconexión), detectados en onMenuFinDeMano().
  virtual std::vector<JugadorSaliente> getJugadoresSalientes() const { return {}; }
  virtual void clearJugadoresSalientes() {}

  /// Notifica saldos actualizados tras redistribución por abandono voluntario.
  virtual void onActualizarSaldos(const std::vector<Player*>& /*jugadores*/) {}

  /// Jugador desconectado a mitad de mano: NetworkObserver cierra el fd y lo elimina.
  virtual void onJugadorDesconectado(const std::string& /*nombre*/) {}

  /**
   * @brief Llamado al empezar el turno de CUALQUIER jugador (humano o bot),
   * sin el filtro de onPreTurnoHumano(). Pensado para que NetworkObserver
   * difunda el estado de la mesa en cada turno, no solo antes del humano —
   * LocalObserver no lo sobrescribe a propósito (evita redibujar toda la
   * pantalla ncurses local en cada turno de bot).
   * @param timeoutMs Tiempo del que dispone el jugador para decidir (mismo
   * valor que ve el jugador activo vía TU_TURNO; informativo para el resto).
   */
  virtual void onTurnoIniciado(const GameState& /*state*/,
                               const std::vector<Player*>& /*jugadores*/,
                               const std::vector<int>& /*botes*/,
                               const std::vector<std::string>& /*historial*/,
                               const std::vector<Carta>& /*cartasMesa*/,
                               int /*timeoutMs*/) {}

  /**
   * @brief Comprobación de si algún jugador ELIMINADO ha pedido recomprar
   * (ver Partida::iniciarPartida()). Normalmente NO bloqueante — no debe
   * frenar al resto de la mesa, así que solo consulta, sin esperar, y
   * Partida es quien aplica el resultado (ganarSaldo) para el jugador que
   * corresponda.
   * @param esperarUltimaOportunidad Si esta recompra es lo único que evita
   * que la partida termine ya mismo (el resto de la mesa ya no tiene "más
   * manos" que jugar mientras se decide, así que no hay nadie a quien no
   * bloquear), sí vale la pena esperar de verdad un momento en vez del
   * sondeo instantáneo habitual — de lo contrario el eliminado nunca tiene
   * ocasión real de que su RECOMPRA llegue a tiempo.
   * @return Nombres de los eliminados que han pedido recomprar, si los hay.
   */
  virtual std::vector<std::string> onComprobarRecompras(
      const std::vector<Player*>& /*eliminados*/,
      bool /*esperarUltimaOportunidad*/ = false) { return {}; }

  /**
   * @brief Llamado justo después de repartir las cartas iniciales de la
   * mano (TexasHoldem::repartirCartasIniciales()).
   *
   * A diferencia de onRepartoCartasIniciales() (sin datos, solo un aviso
   * de "se está repartiendo"), este llega DESPUÉS con la lista completa de
   * jugadores ya con sus cartas asignadas — NetworkObserver lo usa para
   * mandarle a cada humano su propia mano de inmediato. Sin esto, un
   * cliente de red no conocía sus propias cartas hasta su primer turno
   * (TU_TURNO era el único mensaje que las llevaba), así que se veían como
   * desconocidas toda la fase previa aunque ya estuvieran repartidas.
   */
  virtual void onCartasPropiasRepartidas(const std::vector<Player*>& /*jugadores*/) {}

  /**
   * @brief Comprobación NO bloqueante, llamada una vez antes de cada mano
   * (mismo patrón que onComprobarRecompras()), de si hay humanos nuevos
   * esperando para ocupar un asiento de bot — solo tiene sentido si la
   * sala es "abierta tras inicio".
   *
   * @param asientosLibres Cuántos asientos de bot hay disponibles AHORA
   * MISMO (Partida es quien lo sabe, recorriendo jugadores_) — el
   * observer no debe aceptar más solicitudes que las que caben; las que
   * sobren las rechaza él mismo (p. ej. con un mensaje de red), Partida
   * no necesita enterarse de ese rechazo.
   * @return Jugadores ya construidos y listos para ocupar un asiento —
   * Partida decide a qué bot concreto sustituye cada uno.
   */
  virtual std::vector<Player*> onComprobarNuevosJugadores(int /*asientosLibres*/) {
    return {};
  }

  /**
   * @brief Refresca bote/saldos/cartas comunitarias SIN implicar cambio de
   * turno — a diferencia de onTurnoIniciado(), no lleva "de quién es el
   * turno" ni reinicia ningún temporizador en el cliente. Se llama justo
   * después de procesar cada acción y en cada paso del showdown, momentos
   * en los que no hay un onTurnoIniciado() propio que arrastre la
   * actualización (el bucle de apuestas solo llama a onTurnoIniciado() al
   * EMPEZAR el turno de alguien, antes de que actúe — así que, sin esto,
   * el resto de clientes ve el bote/saldos "un paso por detrás" del
   * historial, y durante el showdown se quedan completamente congelados
   * hasta la mano siguiente).
   */
  virtual void onEstadoActualizado(const std::vector<Player*>& /*jugadores*/,
                                   const std::vector<int>& /*botes*/,
                                   const std::vector<Carta>& /*cartasMesa*/,
                                   Rondas /*rondaActual*/,
                                   int /*apuestaAIgualar*/) {}
};
