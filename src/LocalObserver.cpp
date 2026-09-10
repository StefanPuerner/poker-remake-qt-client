#include "../include/LocalObserver.hpp"

// ─────────────────────────────────────────────────────────────────────────────
//  Cada método es una línea o un bloque mínimo que delega en Interfaz.
//  No hay lógica aquí: todo el trabajo de presentación sigue viviendo
//  en Interfaz como siempre.
// ─────────────────────────────────────────────────────────────────────────────

// ── Flujo de mano ─────────────────────────────────────────────────────────────

void LocalObserver::onInicioMano(int numMano, int ciegaGrande) {
  Interfaz::mensajeInicioMano(numMano, ciegaGrande);
}

void LocalObserver::onCobroCiegas(const std::string& jPequena, int montoPequena,
                                   const std::string& jGrande,
                                   int montoGrande) {
  Interfaz::mensajeCobroCiegas(jPequena, montoPequena, jGrande, montoGrande);
}

void LocalObserver::onRepartoCartasIniciales() {
  Interfaz::mensajeRepartoCartasIniciales();
}

void LocalObserver::onRepartiendoComunitarias(const std::string& faseDesc,
                                               int numCartas) {
  Interfaz::mensajeRepartiendoComunitarias(faseDesc, numCartas);
}

// ── Turno humano ──────────────────────────────────────────────────────────────

void LocalObserver::onPreTurnoHumano(const GameState& state,
                                      const std::vector<Player*>& jugadores,
                                      const std::vector<int>& botes,
                                      const std::vector<std::string>& historial,
                                      bool supervisor,
                                      const std::vector<Carta>& cartasMesa) {
  Interfaz::mostrarEstadoPartida(state, jugadores, botes);
  if (supervisor) {
    Interfaz::mostrarCartasDebug(jugadores, cartasMesa);
  }
  Interfaz::mostrarHistorialAccionesBots(historial);
}

void LocalObserver::onVerCartasPropias(const std::string& nombre,
                                        const std::vector<Carta>& cartas) {
  // El jugador quiso ver sus cartas sin consumir el turno.
  // Limpiamos, mostramos, y pausamos antes de redibujar la mesa.
  Interfaz::limpiarPantalla();
  Interfaz::mostrarCartasPropias(nombre, cartas);
  Interfaz::pausarYEsperar();
}

void LocalObserver::onErrorJugada(const std::string& error) {
  Interfaz::mensajeErrorJugada(error);
  Interfaz::pausarYEsperar();
}

// ── Acciones ──────────────────────────────────────────────────────────────────

void LocalObserver::onAccionJugador(const std::string& nombre, TipoAccion accion,
                                     int cantidad) {
  Interfaz::mensajeAccionJugador(nombre, accion, cantidad);
}

void LocalObserver::onCabeceraResumen() {
  // El humano pasó a modo espectador. Limpiamos y mostramos la cabecera
  // para que sea obvio que ahora los bots juegan solos.
  Interfaz::limpiarPantalla();
  Interfaz::mensajeCabeceraResumen();
}

// ── Showdown ──────────────────────────────────────────────────────────────────

void LocalObserver::onInicioShowdown(const std::vector<Carta>& cartasMesa) {
  Interfaz::mensajeInicioShowdown(cartasMesa);
}

void LocalObserver::onEvaluandoBote(int numBote, int cantidad,
                                     const std::vector<std::string>& /*elegibles*/) {
  // La terminal local ya muestra la mesa completa con todos los jugadores
  // visibles — no hace falta narrar aparte quién compite por este bote.
  Interfaz::mensajeEvaluandoBote(numBote, cantidad);
}

void LocalObserver::onMuestraCartas(const std::string& nombre,
                                     const std::string& combo,
                                     const std::vector<Carta>& cartas,
                                     const std::vector<Carta>& /*combinacion*/) {
  Interfaz::mensajeMuestraCartas(nombre, combo, cartas);
}

void LocalObserver::onGanadorBote(const std::string& nombre, int premio,
                                   int numBote, const std::string& combo) {
  Interfaz::mensajeGanadorBote(nombre, premio, numBote, combo);
}

void LocalObserver::onJugadoresDerrotados(
    const std::vector<std::string>& eliminados) {
  Interfaz::mensajeJugadoresDerrotados(eliminados);
}

void LocalObserver::onGanadorSinShowdown(const std::string& nombre, int bote,
                                         const std::string& /*handName*/) {
  Interfaz::mensajeGanadorSinShowdown(nombre, bote);
}

// ── Sesión / sistema ──────────────────────────────────────────────────────────

void LocalObserver::onPartidaExtendida(int manosExtra, int /*nuevoObjetivo*/) {
  Interfaz::mensajePartidaExtendida(manosExtra);
}

void LocalObserver::onFinPartidaGuardada(const std::string& archivo) {
  Interfaz::mensajeFinPartidaGuardada(archivo);
}

void LocalObserver::onAccionSistema(const std::string& mensaje) {
  Interfaz::mensajeAccionSistema(mensaje);
}

void LocalObserver::onErrorSistema(const std::string& categoria,
                                    const std::string& mensaje, int codigo) {
  Interfaz::mensajeErrorSistema(categoria, mensaje, codigo);
}

void LocalObserver::onFinPartidaLimiteManos(const PartidaStats& stats) {
  // La pantalla local ya no muestra nada nuevo aquí a propósito -- el
  // ncurses local ya tiene su propio camino para ver estas mismas
  // estadísticas completas (menú de historial, Interfaz::mostrarDetallePartida()).
  // Este cambio de firma es solo para que Partida pueda mandar el
  // PartidaStats completo a los observers de red sin duplicar el cálculo.
  Interfaz::mensajeFinPartidaLimiteManos(stats.ganadorNombre, stats.saldoFinal);
}

void LocalObserver::onFinPartida(const PartidaStats& stats) {
  Interfaz::mensajeFinPartida(stats.ganadorNombre, stats.saldoFinal);
}

// ── Utilidades ────────────────────────────────────────────────────────────────

void LocalObserver::onBarraCarga(int ms) {
  Interfaz::mostrarBarraCarga(ms);
}

void LocalObserver::onLimpiarPantalla() {
  Interfaz::limpiarPantalla();
}

void LocalObserver::onPausarYEsperar() {
  Interfaz::pausarYEsperar();
}

// ── Consultas con respuesta ───────────────────────────────────────────────────

int LocalObserver::onMenuFinDeMano() {
  return Interfaz::menuFinDeMano();
}

int LocalObserver::onPreguntarExtension() {
  return Interfaz::preguntarExtensionPartida();
}

std::string LocalObserver::onPedirNombreArchivo() {
  return Interfaz::leerNombreArchivo();
}
