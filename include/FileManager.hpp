/**
 * @file FileManager.hpp
 * @brief Persistencia de partidas e historial en archivos de texto con checksum.
 */
#pragma once

#include <fstream>
#include <string>
#include <vector>

#include "DecisionEngine.hpp"
#include "PathUtils.hpp"
#include "PokerError.hpp"
#include "GameTypes.hpp"
#include "style.hpp"

/**
 * @brief Persistencia de partidas e historial en archivos de texto.
 *
 * Todos los métodos son estáticos. Los archivos incluyen un checksum simple
 * para detectar modificaciones manuales y mantener la integridad de los datos.
 *
 * Formato de guardado: texto plano con campos separados por '|' y una línea
 * de checksum al final. El directorio por defecto es carpetaData() (ver
 * PathUtils.hpp) — no depende del directorio de trabajo del proceso.
 */
class FileManager {
 public:
  /**
   * @brief Guarda el estado actual de la partida en @p rutaArchivo.
   * @throws std::system_error con PokerError si no se puede escribir.
   */
  static void guardarPartida(const PartidaSnapshot& snapshot,
                             const std::string& rutaArchivo);

  /**
   * @brief Carga una partida guardada y devuelve su snapshot.
   * @throws std::system_error con PokerError::FormatoInvalido o FicheroCorrupto.
   */
  static PartidaSnapshot cargarPartida(const std::string& rutaArchivo);

  /// Añade una entrada al historial de partidas finalizadas.
  static void registrarPartidaFinalizada(
      PartidaStats& stats,
      const std::string& rutaArchivo = "historial.log");

  /// @return Lista de estadísticas de todas las partidas registradas en el historial.
  static std::vector<PartidaStats> cargarHistorialCompleto(
      const std::string& rutaArchivo);

  /// @return Archivos de partida guardada encontrados en @p directorio.
  static std::vector<ArchivoGuardado> obtenerPartidasGuardadas(
      const std::string& directorio = carpetaData());

  /// Borra el archivo en @p path. @throws std::system_error si falla.
  static void borrarArchivoGuardado(const std::string& path);

  /// Renombra @p pathActual a @p pathNuevo. @throws std::system_error si ya existe o falla.
  static void renombrarArchivoGuardado(const std::string& pathActual,
                                       const std::string& pathNuevo);

 private:
  static void validarRangoJugadores(size_t numJugadores);
  static void verificarIntegridadJugador(const JugadorSnapshot& data);
  static void validarConsistenciaSaldo(
      const std::vector<JugadorSnapshot>& jugadores);

  /// XOR checksum sobre los campos de @p linea para detección de manipulación manual.
  static unsigned int calcularChecksum(const std::string& linea);
};
