/**
 * @file Partida.hpp
 * @brief Motor de juego base (Template Method): ciegas, apuestas, side pots y showdown.
 */
#pragma once

#include <map>
#include <memory>
#include <string>
#include <vector>

#include "Analyzer.hpp"
#include "Baraja.hpp"
#include "Bote.hpp"
#include "GameTypes.hpp"
#include "IGameObserver.hpp"
#include "Mesa.hpp"
#include "PathUtils.hpp"
#include "Player.hpp"

/**
 * @brief Motor de juego base (Template Method Pattern).
 *
 * Implementa el esqueleto común a todas las variantes de poker: gestión de
 * ciegas, rondas de apuestas, side pots y showdown. Las reglas específicas
 * (reparto de cartas, fases comunitarias) se delegan en clases derivadas
 * como TexasHoldem.
 *
 * La presentación se desacopla completamente via IGameObserver: el mismo motor
 * funciona en modo local (LocalObserver) y en modo servidor en red (NetworkObserver).
 */
class Partida {
 protected:
  // ── Componentes de juego ──────────────────────────────────────────────────
  std::vector<Player*> jugadores_;        ///< Punteros crudos (polimorfismo Persona/Bot/NetworkPlayer).
  std::vector<Bote>    botes_;            ///< Bote principal + side pots generados por all-ins.
  Baraja               baraja_;
  Mesa                 mesa_;
  std::map<Player*, int> contribucionesMano_; ///< Fichas totales invertidas por jugador en la mano.

  // ── Estado de la partida ──────────────────────────────────────────────────
  int          dealerIndex_;
  int          ciegaGrande_;
  int          ciegaPequena_;
  int          apuestaMaximaRonda_;
  int          manoActual_;
  int          objetivoManos_;
  Rondas       faseActual_;
  std::string  archivoOrigen_ = "";
  // Vacío en todo el software actual (nadie llama a setSalaId() todavía) —
  // preparado para el servidor multi-sala: cuando exista, cada sala le pone
  // su propio id para que autosave/guardado manual no colisionen entre sí.
  std::string  salaId_ = "";
  // Metadatos de sala para generarSnapshot() (host, público/privado,
  // código) -- Partida no sabe nada de SalaInfo/RoomRegistry, solo
  // guarda estos strings/bool planos que ejecutarSala() le pasa una vez
  // al construirla (mismo patrón que setArchivoOrigen()).
  std::string  hostNombre_ = "";
  bool         salaPublica_ = true;
  std::string  salaCodigo_ = "";
  // Buy-in de la sala, para poder restaurarlo en una recompra
  // (Player no tiene setSaldo(); ganarSaldo(saldoInicial_) hace lo mismo
  // ya que un jugador eliminado siempre está a 0). El constructor local ya
  // lo recibe y lo guarda solo; el constructor de red (jugadores ya
  // construidos) necesita que alguien llame a setSaldoInicial() aparte.
  int          saldoInicial_ = 0;
  /// Ver setCarpetaDatos(). Vacía = carpetaData().
  std::string  carpetaDatos_ = "";
  bool         modoSupervisor_;
  ReglasJuego  reglas_;
  int          raisesEnEstaMano_;        ///< Contador de raises en la mano actual (para range modeling en IA).
  TipoAccion   ultimaAccionRonda_;       ///< Última acción (para detectar señales de debilidad).
  std::string  ultimoAgresorNombre_;     ///< Nombre de quien hizo el último RAISE/ALL_IN en la mano actual.

  /// Observer activo; unique_ptr garantiza un único observer y su destrucción con Partida.
  std::unique_ptr<IGameObserver> observer_;

  /// Carpeta efectiva de datos -- setCarpetaDatos() si se fijó, si no la
  /// de siempre. Único punto por el que pasan autosave/guardado/historial.
  const std::string& dirDatos() const {
    return carpetaDatos_.empty() ? carpetaData() : carpetaDatos_;
  }

  // ── Rastreo histórico para estadísticas ──────────────────────────────────
  std::map<std::string, std::string> eliminaciones_; ///< nombre → mano de eliminación.
  HandResult  mejorManoPartida_;
  std::string jugadorMejorMano_;
  void        registrarEliminados();

 public:
  /**
   * @brief Constructor estándar: crea Persona(s) y Bots internamente.
   * @param nombresHumanos  Nombres de los jugadores humanos locales.
   * @param numBots         Número de bots a crear.
   * @param saldoInicial    Fichas con las que empieza cada jugador.
   * @param manosObjetivo   Número de manos hasta el límite de partida.
   * @param valorCiegaGrande Ciega grande inicial.
   * @param supervisor      Activa el modo debug (muestra cartas de todos).
   * @param reglas          Configuración de límite de apuesta, dificultad IA, etc.
   */
  Partida(const std::vector<std::string>& nombresHumanos, int numBots,
          int saldoInicial, int manosObjetivo, int valorCiegaGrande,
          bool supervisor, const ReglasJuego& reglas = ReglasJuego{});

  /**
   * @brief Constructor para modo red: recibe jugadores ya construidos.
   *
   * El servidor crea NetworkPlayer + Bot antes de llamar a este constructor.
   * Partida toma propiedad de los punteros y los destruye al terminar.
   */
  Partida(std::vector<Player*> jugadores, int manosObjetivo, int ciegaGrande,
          bool supervisor, const ReglasJuego& reglas = ReglasJuego{});

  /// Constructor para reanudar una partida guardada desde un PartidaSnapshot.
  Partida(const PartidaSnapshot& snapshot);

  void setArchivoOrigen(const std::string& rutaArchivo);
  void setSalaId(const std::string& salaId) { salaId_ = salaId; }
  void setHostNombre(const std::string& host) { hostNombre_ = host; }
  void setSalaPublica(bool publica) { salaPublica_ = publica; }
  void setSalaCodigo(const std::string& codigo) { salaCodigo_ = codigo; }
  void setManoActual(int mano) { manoActual_ = mano; }
  /// Necesario para la recompra en el constructor de red (jugadores ya
  /// construidos, sin buy-in explícito) — el constructor local lo fija solo.
  void setSaldoInicial(int saldo) { saldoInicial_ = saldo; }

  /**
   * @brief Carpeta donde van autosave, guardado manual e historial.
   *
   * Por defecto carpetaData() (ver PathUtils.hpp): la carpeta "data/"
   * junto al binario, que es lo que quieren el servidor y el cliente de
   * terminal. El cliente Qt en modo OFFLINE la cambia por la carpeta de
   * datos de aplicación del sistema (QStandardPaths::AppDataLocation, ver
   * LocalGameClient) -- una aplicación de escritorio/móvil instalada no
   * puede dar por hecho que puede escribir junto a su propio ejecutable,
   * y menos aún compartir carpeta con los guardados del servidor.
   *
   * Debe terminar en '/'. Vacía = usar carpetaData().
   */
  void setCarpetaDatos(const std::string& carpeta) { carpetaDatos_ = carpeta; }

  /**
   * @brief Acceso mutable a jugadores_ para NetworkObserver.
   *
   * Necesario para que un jugador nuevo pueda sentarse en un asiento de
   * bot DURANTE una espera bloqueante del propio observer (el voto de fin
   * de mano, onMenuFinDeMano() — poll indefinido mientras alguien no
   * vota) y no solo entre manos (onComprobarNuevosJugadores(), que Partida
   * sí puede llamar porque ahí manda ella). Sin esto, alguien podía
   * quedarse encolado indefinidamente si el resto tardaba en votar — el
   * "hueco" real para entrar es precisamente esa espera, no solo el
   * instante justo antes de repartir.
   */
  std::vector<Player*>& jugadoresMutable() { return jugadores_; }

  /**
   * @brief Sustituye el observer en tiempo de ejecución.
   *
   * El modo red lo usa para instalar un NetworkObserver antes de iniciarPartida().
   */
  void setObserver(std::unique_ptr<IGameObserver> obs);

  /// Genera un snapshot serializable del estado actual (para guardar partida).
  PartidaSnapshot generarSnapshot() const;

  /// Genera las estadísticas finales de la partida (para historial y pantalla de fin).
  PartidaStats generarEstadisticas() const;

  virtual ~Partida();

  // ── Flujo principal (Template Method) ────────────────────────────────────

  /// Bucle principal de la partida: juega manos hasta el límite o hasta que quede un ganador.
  void iniciarPartida();

  /// Ejecuta una mano completa (ciegas → preflop → flop/turn/river → showdown).
  void ejecutarMano();

  // ── Métodos virtuales puros (implementados por las variantes) ─────────────

  virtual void repartirCartasIniciales() = 0;   ///< Texas: 2 cartas; Omaha: 4.
  virtual void ejecutarFaseComunitaria() = 0;   ///< Destapa la(s) carta(s) comunitaria(s) de la fase actual.
  virtual bool manoTerminada()           = 0;   ///< true cuando se han completado todas las fases.

 protected:
  // ── Motor de apuestas ─────────────────────────────────────────────────────

  /// Ejecuta una ronda de apuestas completa para todos los jugadores activos.
  void gestionarRondaDeApuestas();
  void cobrarCiegas();
  void rotarDealer();

  // ── Lógica de botes y acciones ────────────────────────────────────────────

  /// Aplica la acción de @p p al estado del juego (descontar saldo, cambiar estado).
  void procesarAccion(Player* p, const Accion& a);

  /// Crea side pots cuando @p p va all-in por @p cantidad menor al bote principal.
  void gestionarSidePots(Player* p, int cantidad);

  // ── Showdown y limpieza ───────────────────────────────────────────────────

  virtual void showdown();

  /// Entrega el bote al único jugador que no ha hecho fold (sin showdown).
  void repartirBotes();

  void limpiarEstadosMano();

  /// Aplica LEAVE/expulsión-por-timeout de observer_->getJugadoresSalientes()
  /// entre manos: redistribuye fichas o sustituye por bot según
  /// reglas_.rellenarConBots, salvo una expulsión involuntaria sin relleno
  /// de bots, que conserva el asiento intacto (ver el comentario largo en
  /// Partida.cpp). Se llama una vez por vuelta del bucle de iniciarPartida(),
  /// justo tras onMenuFinDeMano().
  void procesarJugadoresSalientes();

  // ── Auxiliares internos ───────────────────────────────────────────────────

  /// @return Índice del siguiente jugador en la lista que no está FOLD ni ELIMINADO.
  int obtenerSiguienteJugadorActivo(int indexActual) const;

  /// @return Jugadores en estado ACTIVO o ALL_IN (elegibles para la mano).
  int contarJugadoresActivos() const;

  /// @return Jugadores en estado ACTIVO (con una decisión de apuesta real
  /// que tomar todavía) -- no cuenta ALL_IN, a diferencia de
  /// contarJugadoresActivos(). Ver el comentario donde se usa en
  /// gestionarRondaDeApuestas().
  int contarJugadoresQuePuedenApostar() const;

  /**
   * @brief Aplica cualquier recompra pendiente (ver
   * IGameObserver::onComprobarRecompras) de jugadores ELIMINADOS, si
   * reglas_.permitirRecompra está activo. Se llama en dos puntos de
   * iniciarPartida(): al principio de cada vuelta del bucle (cubre a
   * quien lleva una o más manos esperando) y justo después de
   * ejecutarMano(), antes de comprobar si la mano que acaba de terminar
   * deja la mesa con 1 o menos jugadores vivos — sin esta segunda
   * llamada, quien se queda a 0 en la ÚLTIMA mano posible nunca llega a
   * ver la vuelta siguiente del bucle, así que su recompra nunca se
   * comprobaba (bug real encontrado en vivo: en una mesa heads-up,
   * perder la mano que te deja a 0 siempre coincide con "ya no queda con
   * quién jugar", y ese caso pasaba de largo por esta función).
   */
  void procesarRecomprasPendientes();
};
