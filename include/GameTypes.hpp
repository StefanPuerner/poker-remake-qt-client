/**
 * @file GameTypes.hpp
 * @brief Tipos, enums y estructuras de datos compartidos por todo el motor de juego.
 */
#pragma once

#include <string>
#include <vector>

#include "Carta.hpp"

/// Tiempo (ms) del que dispone un jugador para decidir su turno. Compartido
/// entre el motor (Partida, al difundir onTurnoIniciado) y la capa de red
/// (NetworkPlayer, al construir TU_TURNO) para que ambos usen el mismo valor.
constexpr int TURNO_TIMEOUT_MS = 30'000;

/// Fases de una mano de poker (en orden cronológico).
enum class Rondas { PREFLOP, FLOP, TURN, RIVER, SHOWDOWN };

/// Modalidad de límite de apuesta.
enum class TipoLimite {
  SIN_LIMITE,   ///< No-Limit: cada jugador puede apostar hasta su saldo completo.
  LIMITE_BOTE,  ///< Pot-Limit: el raise máximo es el tamaño del bote tras el call.
  LIMITE_FIJO   ///< Fixed-Limit: el raise es siempre igual a monteFijo.
};

/// Nivel de dificultad de la IA de los bots.
enum class DificultadBots {
  FACIL,    ///< Equity básica + textura de mesa + posición.
  NORMAL,   ///< + range narrowing + outs precisos + river ajustado.
  EXPERTO   ///< + perfilado estadístico de rivales acumulado por partida.
};

/**
 * @brief Historial estadístico de un rival observado (solo en dificultad EXPERTO).
 *
 * Acumula datos de comportamiento a lo largo de la partida para que el bot
 * pueda estimar el rango y la agresividad del rival.
 */
struct PerfilJugador {
  int manosTotal    = 0;  ///< Manos en las que se ha observado al jugador.
  int manosVPIP     = 0;  ///< Manos con apuesta/call voluntarios (Voluntary Put In Pot).
  int raisesTotal   = 0;
  int callsTotal    = 0;
  int foldsARaise   = 0;  ///< Veces que foldeó ante una apuesta/raise.
  int vecesRaised   = 0;  ///< Veces que enfrentó una apuesta/raise.
  int preflopRaises = 0;
  bool vpipEstaMano = false;  ///< Flag temporal para no contar VPIP dos veces en la misma mano.

  static constexpr int MIN_MUESTRAS = 6;

  /// @return true si hay suficientes muestras para que el perfil sea estadísticamente fiable.
  bool esConfiable() const { return manosTotal >= MIN_MUESTRAS; }

  /// Voluntary Put money In Pot: fracción de manos en las que el jugador entra voluntariamente.
  float VPIP() const {
    return manosTotal == 0 ? 0.5f
                           : static_cast<float>(manosVPIP) / manosTotal;
  }

  /// Aggression Factor: raises / (raises + calls). Alto = agresivo.
  float agresividad() const {
    int activas = raisesTotal + callsTotal;
    return activas == 0 ? 0.5f
                        : static_cast<float>(raisesTotal) / activas;
  }

  /// Fold To Raise: porcentaje de veces que cede ante presión. Alto = bluffeable.
  float foldToRaise() const {
    return vecesRaised == 0 ? 0.5f
                            : static_cast<float>(foldsARaise) / vecesRaised;
  }

  /// Pre-Flop Raise %: frecuencia con la que sube antes del flop.
  float PFR() const {
    return manosTotal == 0 ? 0.3f
                           : static_cast<float>(preflopRaises) / manosTotal;
  }
};

/// Configuración de las reglas de la partida (pasada al constructor de Partida).
struct ReglasJuego {
  TipoLimite     tipoLimite     = TipoLimite::SIN_LIMITE;
  bool           aplicarMinRaise = false; ///< Aplica la regla de raise mínimo (= raise anterior).
  int            monteFijo      = 0;      ///< Importe fijo del raise en modo LIMITE_FIJO.
  DificultadBots dificultadBots = DificultadBots::FACIL;
  /// Si un jugador se queda sin fichas, ¿puede recomprar (volver con el
  /// saldo inicial) en vez de quedarse eliminado para siempre?
  /// NOTA: todavía NO participa en el checksum de FileManager.cpp a
  /// propósito — hay un bug real sin resolver ahí (ver agile-doodling-wren.md,
  /// "Investigación: checksum de guardado"); engancharlo antes de resolverlo
  /// contaminaría el diagnóstico. Falta ese paso cuando se arregle el bug.
  bool           permitirRecompra = false;
  /// Solo salas creadas por CREATE_GAME (Qt) — la sala legacy nunca la
  /// activa. Si alguien se va con fichas (voluntariamente o por
  /// desconexión sin reconectar en 60s), un bot ocupa su asiento
  /// conservando el saldo, en vez de repartirlo entre el resto. NO aplica
  /// a quien pierde por el juego normal (saldo ya en 0, distinto camino:
  /// Partida::registrarEliminados/PlayerState::ELIMINADO).
  bool           rellenarConBots = false;
  /// Solo salas CREATE_GAME. Con esto activo, cualquier asiento controlado
  /// por un bot (de relleno o "de toda la vida") puede ser sustituido por
  /// un humano nuevo que se una en marcha — se comprueba una vez por mano,
  /// igual que permitirRecompra.
  bool           abiertaTrasInicio = false;
  /// Al llegar al límite de manos, ¿se pregunta a los humanos si quieren
  /// extender la partida (unánime, ver NetworkObserver::onPreguntarExtension)
  /// o se termina sin más? Activado por defecto (decisión explícita del
  /// usuario) — si el host lo desactiva al crear la sala, la partida
  /// simplemente termina en el límite, como si nadie hubiera querido
  /// extender.
  bool           preguntarExtension = true;
};

/// Tipos de acción que puede realizar un jugador en su turno.
enum class TipoAccion { FOLD, CALL, RAISE, ALL_IN, CHECK, ERROR, VER_CARTAS };

/// Estado de un jugador durante la mano.
enum class PlayerState { ACTIVO, ELIMINADO, FOLD, ALL_IN };

/// Resultado de una decisión de jugador.
struct Accion {
  TipoAccion  tipo;
  int         cantidad;       ///< Importe del raise (solo relevante en RAISE; CALL se calcula).
  bool        valido;         ///< false = el motor rechazará esta acción y pedirá otra.
  std::string mensajeError;   ///< Razón del rechazo (solo si !valido).
};

/**
 * @brief Fotografía del estado público de la mesa en el momento del turno.
 *
 * Se pasa a decidirAccion() tanto en modo local (Bot/Persona) como en modo
 * red (NetworkPlayer la serializa para enviarla al cliente).
 */
struct GameState {
  std::vector<Carta> cartasComunitarias;
  int     boteTotal;
  int     apuestaAIgualar;        ///< Apuesta más alta actual que los demás deben igualar.
  int     miApuestaEnRonda;
  int     miSaldo;
  int     numJugadoresActivos;
  Rondas  rondaActual;
  int     ciegaGrande;            ///< Para calcular el raise mínimo en No-Limit.
  ReglasJuego reglas;
  int     jugadoresPendientes;    ///< Jugadores que actúan DESPUÉS de este en la ronda actual.
  int     raisesRivalesEstaMano;  ///< Raises totales en la mano (para modelado de rango en IA).
  bool    accionAnteriorFueCheck; ///< El jugador anterior pasó (señal de debilidad).
  std::string nombreActual;       ///< Nombre del jugador que debe actuar ahora.
  std::string ultimoAgresorNombre; ///< Nombre de quien hizo el último RAISE/ALL_IN en la mano ("" si nadie subió aún).
};

// ── Estructuras de persistencia ───────────────────────────────────────────────

/// Snapshot de un jugador para guardar/cargar partida.
struct JugadorSnapshot {
  std::string nombre;
  int         saldo;
  bool        esBot;
  int         comportamiento;
  PlayerState estado;
  // 0 = invitado o bot (los bots nunca llevan cuenta, ver Bot.cpp) -- para
  // que LISTAR_GUARDADAS/CARGAR_PARTIDA/RENOMBRAR_GUARDADA/BORRAR_GUARDADA
  // en el servidor puedan restringir una partida guardada a las cuentas
  // reales que jugaron en ella (ver FileManager::guardarPartida()).
  // Ficheros .pok viejos (de antes de este campo) lo leen como 0 sin más.
  int accountId = 0;
};

/// Snapshot completo de la partida para guardar/cargar.
struct PartidaSnapshot {
  int  manoActual;
  int  objetivoManos;
  int  ciegaGrande;
  std::vector<JugadorSnapshot> jugadores;
  bool supervisor;
  ReglasJuego reglas;

  // Metadatos de sala (host, público/privado, código) -- ausentes en
  // ficheros .pok de antes de este campo, que cargan con estos defaults
  // (mismo criterio que accountId==0 arriba): hostNombre vacío deja que
  // el servidor caiga al comportamiento antiguo ("primero en conectar
  // es host"), y salaPublica=true reproduce lo que desktop ya mandaba
  // siempre antes de que este dato se guardase de verdad.
  std::string hostNombre;
  bool        salaPublica = true;
  std::string salaCodigo;
};

// ── Estructuras de estadísticas ───────────────────────────────────────────────

/// Registro de eliminación de un jugador (para el historial).
struct JugadorFinStats {
  std::string nombre;
  std::string manoEliminacion;  ///< Número de mano en que fue eliminado ("X" si sobrevivió).
  int         accountId = 0;    ///< 0 = invitado -- ver Player::getAccountId(). Para player_stats.
  int         saldoFinal = 0;   ///< Saldo de ESTE jugador al terminar (no solo el del ganador).
};

/// Estadísticas finales de una partida completa (para historial.log y,
/// desde net/, para actualizar player_stats de quien tenga cuenta).
struct PartidaStats {
  std::string fechaHora;
  std::string ganadorNombre;
  int         saldoFinal;
  int         saldoInicial = 0;  ///< Fijo para toda la partida (rebuys aparte, ver comentario en NetworkObserver::actualizarStatsCuentas).
  int         manosJugadas;
  std::string mejorManoNombre;   ///< Nombre de la mejor mano conseguida en la partida.
  std::string mejorManoJugador;  ///< Quién consiguió la mejor mano.
  std::vector<JugadorFinStats> historialJugadores;
};

/// Referencia a un archivo de partida guardada (para la lista de guardados).
struct ArchivoGuardado {
    std::string nombre;
    std::string fecha;
};
