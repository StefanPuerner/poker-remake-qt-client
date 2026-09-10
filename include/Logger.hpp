/**
 * @file Logger.hpp
 * @brief Singleton thread-safe para registro de eventos del servidor en disco.
 */
#pragma once

#include <fstream>
#include <mutex>
#include <string>

#include "PathUtils.hpp"

/**
 * @brief Singleton thread-safe para registrar eventos del servidor en disco.
 *
 * Crea un archivo `server_YYYYMMDD_HHMMSS.log` en el directorio indicado
 * al llamar a open(). Cada entrada lleva timestamp HH:MM:SS y nivel
 * (INFO / WARN / ERROR). Las entradas también se imprimen en stderr.
 *
 * Uso:
 * @code
 *   Logger::instance().open(carpetaData());
 *   LOG_INFO("Servidor listo en puerto 9000");
 *   LOG_WARN("Jugador sin saldo");
 *   LOG_ERROR("Excepción inesperada: " + msg);
 * @endcode
 */
class Logger {
 public:
  enum class Level { INFO, WARN, ERROR };

  static Logger& instance();

  /// Abre el archivo de log. Llamar una vez al inicio del servidor.
  void open(const std::string& dir = carpetaData());

  /// Cierra el archivo. Llamado automáticamente en el destructor.
  void close();

  /// Escribe una entrada con timestamp y nivel @p lvl. Thread-safe (mutex interno).
  void log(Level lvl, const std::string& msg);

  void info(const std::string& msg)  { log(Level::INFO,  msg); }
  void warn(const std::string& msg)  { log(Level::WARN,  msg); }
  void error(const std::string& msg) { log(Level::ERROR, msg); }

 private:
  Logger() = default;
  ~Logger() { close(); }
  Logger(const Logger&)            = delete;
  Logger& operator=(const Logger&) = delete;

  std::ofstream file_;
  std::mutex    mutex_;
};

/// Registra un evento informativo. @p msg puede ser std::string o literal.
#define LOG_INFO(msg)  Logger::instance().info(msg)
/// Registra una advertencia (condición inesperada pero recuperable).
#define LOG_WARN(msg)  Logger::instance().warn(msg)
/// Registra un error grave (excepción, fallo de red, corrupción).
#define LOG_ERROR(msg) Logger::instance().error(msg)
