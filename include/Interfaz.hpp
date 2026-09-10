/**
 * @file Interfaz.hpp
 * @brief Capa de presentación estática para partidas en modo terminal local.
 */
#pragma once

#include <string>
#include <vector>

#include "GameTypes.hpp"
#include "Player.hpp"
#include "style.hpp"

class Mesa;

/**
 * @brief Capa de presentación para partidas en local (modo terminal).
 *
 * Todos los métodos son estáticos: no hay instancia. LocalObserver delega
 * en esta clase para imprimir cada evento del motor en el terminal.
 *
 * No contiene lógica de juego: solo formatea y muestra información.
 */
class Interfaz {
 public:
  // ── Control de pantalla ───────────────────────────────────────────────────

  /// Limpia la terminal (equivalente a `clear`).
  static void limpiarPantalla();
  /// Imprime el título ASCII "POKER" centrado en la terminal.
  static void dibujarTituloPoker();

  /// Dibuja las cartas de @p cartas en columnas paralelas alineadas.
  static void dibujarCartasEnParalelo(const std::vector<Carta>& cartas, int numTotal = 0);

  /// Animación de arranque (barra de carga + título) al iniciar el programa.
  static void secuenciaArranqueTerminal();
  /// Animación de cierre con mensaje de despedida al salir del programa.
  static void secuenciaApagadoTerminal();

  // ── Pantallas de juego ────────────────────────────────────────────────────

  /// Muestra el estado completo de la mesa: botes, jugadores, apuestas y fase.
  static void mostrarEstadoPartida(const GameState& state,
                                   const std::vector<Player*>& jugadores,
                                   const std::vector<int>& botes);

  /// Muestra las dos cartas privadas del jugador en arte ASCII.
  static void mostrarCartasPropias(const std::string& nombreJugador,
                                   const std::vector<Carta>& cartas);

  /// Muestra las opciones de acción disponibles junto con la mano actual del jugador.
  static void mostrarOpcionesAccion(const std::string& nombre,
                                    int aPagarParaIgualar, int miSaldo,
                                    const std::string& actual,
                                    const std::string& probable,
                                    const std::string& potencial);

  // ── Ajustes ───────────────────────────────────────────────────────────────

  /// Dibuja el menú de ajustes con el estado actual de cada opción.
  static void dibujarAjustesBots(bool botsHabilitados, bool supervisorHabilitado,
                                 const ReglasJuego& reglas);
  /// Dibuja el panel de reglas de la partida (tipo límite, dificultad, etc.).
  static void dibujarPanelReglas(const ReglasJuego& reglas);

  // ── Historial ────────────────────────────────────────────────────────────

  /// Lista todas las partidas del historial con índice, fecha, ganador y manos.
  static void mostrarHistorialCompleto(const std::vector<PartidaStats>& historial);
  /// Muestra los detalles de una partida concreta del historial (jugadores, mejor mano…).
  static void mostrarDetallePartida(const PartidaStats& stats, int indice);
  /// Lista los archivos de partida guardada con nombre y fecha.
  static void mostrarArchivosGuardados(const std::vector<ArchivoGuardado>& archivos);

  // ── Mensajes del programa ─────────────────────────────────────────────────

  /// Pantalla de bienvenida al arrancar el programa.
  static void mensajeBienvenida();
  /// Dibuja las opciones del menú principal (nueva partida, cargar, historial, salir).
  static void mensajeMenuPrincipal();
  /// Instrucciones para borrar un archivo de guardado (muestra @p numArchivos disponibles).
  static void mensajeBorrarArchivo(int numArchivos);
  /// Instrucciones para renombrar un archivo de guardado.
  static void mensajeRenombrarArchivo(int numArchivos);
  /// Cabecera de inicio de mano con número y valor de ciega grande.
  static void mensajeInicioMano(int numMano, int ciegaGrande);
  /// Imprime el separador "--- RESUMEN (modo espectador) ---".
  static void mensajeCabeceraResumen();
  /// Informa del cobro de ciegas: quién paga qué importe.
  static void mensajeCobroCiegas(const std::string& jPequena, int montoPequena,
                                 const std::string& jGrande, int montoGrande);
  /// Anuncia el cambio de fase (FLOP, TURN, RIVER, SHOWDOWN).
  static void mensajeCambioDeFase(Rondas fase);

  /// Pregunta al usuario si quiere extender la partida más allá del límite.
  /// @return Número de manos extra (0 = no extender).
  static int preguntarExtensionPartida();

  /// Confirma que la partida se ha extendido @p manosExtra manos más.
  static void mensajePartidaExtendida(int manosExtra);
  /// Imprime la acción de un jugador (FOLD/CALL/RAISE/CHECK/ALL_IN con importe).
  static void mensajeAccionJugador(const std::string& nombre, TipoAccion accion,
                                   int cantidad);
  /// Anuncia el ganador de un bote con el nombre de la combinación ganadora.
  static void mensajeGanadorMano(const std::string& nombre, int boteGanado,
                                 const std::string& comboNombre);
  /// Informa de la eliminación de un jugador indicando la mano en que ocurrió.
  static void mensajeJugadorEliminado(const std::string& nombre, int manoEliminacion);
  /// Pantalla de fin de partida por límite de manos con ganador y saldo final.
  static void mensajeFinPartidaLimiteManos(const std::string& ganador, int saldoFinal);
  /// Pantalla de fin de partida definitiva (un solo jugador queda con fichas).
  static void mensajeFinPartida(const std::string& ganador, int saldoFinal);
  /// Barra de progreso durante operaciones de archivo (guardar/cargar).
  static void mensajeProgresoArchivo(const std::string& operacion, int porcentaje);
  /// Muestra un error del sistema con categoría, mensaje y código de error.
  static void mensajeErrorSistema(const std::string& categoria,
                                  const std::string& mensaje, int codigo);

  // ── Entrada de usuario ────────────────────────────────────────────────────

  /// Muestra @p mensaje y devuelve la línea introducida por el usuario.
  static std::string pedirCadena(const std::string& mensaje);

  /// Lee un número de menú entre @p min y @p max, rechazando entradas inválidas.
  static int leerOpcionMenu(int min, int max);

  /// Lee el importe de un raise dentro del rango [minRaise, maxRaise].
  static int leerMontoRaise(int minRaise, int maxRaise);

  /// Solicita un nombre de archivo y lo devuelve (sin extensión ni ruta).
  static std::string leerNombreArchivo();

  /// Menú interactivo de fin de mano. @return 1=continuar, 2=guardar+salir, 3=salir.
  static int menuFinDeMano();

  /// Confirma que la partida se ha guardado con éxito en @p archivo.
  static void mensajeFinPartidaGuardada(const std::string& archivo);

  // ── Mensajes adicionales del motor ────────────────────────────────────────

  /// Muestra el motivo de rechazo de una acción inválida del jugador.
  static void mensajeErrorJugada(const std::string& error);
  /// Encabezado del showdown con las cartas comunitarias finales.
  static void mensajeInicioShowdown(const std::vector<Carta>& cartasComunitarias);
  /// Muestra las cartas y la combinación de un jugador durante el showdown.
  static void mensajeMuestraCartas(const std::string& nombre, const std::string& combo,
                                   const std::vector<Carta>& cartasPersonales);
  /// Muestra el historial de acciones de los bots al final del modo espectador.
  static void mostrarHistorialAccionesBots(const std::vector<std::string>& acciones);
  /// Anuncia que @p nombre gana el bote sin showdown (todos los demás hicieron fold).
  static void mensajeGanadorSinShowdown(const std::string& nombre, int bote);
  /// Cabecera de evaluación de un bote (bote #N con @p cantidad fichas).
  static void mensajeEvaluandoBote(int numBote, int cantidad);
  /// Anuncia el ganador de un bote concreto con su combinación y premio.
  static void mensajeGanadorBote(const std::string& nombre, int premio,
                                 int numBote, const std::string& combo);
  /// Lista los jugadores eliminados al final de la mano.
  static void mensajeJugadoresDerrotados(const std::vector<std::string>& eliminados);
  /// Anuncia el reparto de cartas privadas al inicio de la mano.
  static void mensajeRepartoCartasIniciales();
  /// Anuncia el destape de cartas comunitarias en la fase indicada.
  static void mensajeRepartiendoComunitarias(const std::string& faseDesc, int numCartas);

  // ── Herramientas de sistema ───────────────────────────────────────────────

  /// Espera a que el usuario pulse Enter antes de continuar.
  static void pausarYEsperar();
  /// Muestra una barra de carga animada durante @p tiempoTotalMS milisegundos.
  static void mostrarBarraCarga(int tiempoTotalMS);
  /// Solicita un número entero de configuración dentro de [@p min, @p max].
  static int  pedirDatoConfiguracion(const std::string& mensaje, int min, int max);
  /// Imprime un mensaje informativo del sistema (p.ej. "Guardando partida…").
  static void mensajeAccionSistema(const std::string& mensaje);

  // ── Depuración ────────────────────────────────────────────────────────────

  /// Muestra las cartas de todos los jugadores (solo en modo supervisor/debug).
  static void mostrarCartasDebug(const std::vector<Player*>& jugadores,
                                 const std::vector<Carta>& cartasMesa);
};
