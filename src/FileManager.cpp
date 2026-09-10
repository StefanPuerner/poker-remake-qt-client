#include "../include/FileManager.hpp"

#include <chrono>
#include <ctime>
#include <exception>
#include <filesystem>
#include <iomanip>
#include <iostream>
#include <mutex>
#include <sstream>

#include "FileManager.hpp"
#include "../include/TimeUtils.hpp"

namespace {
// Protege la escritura en el histórico global compartido
// ("historial_general.stats"): con el servidor multi-sala, dos salas
// terminando a la vez escribirían sobre el mismo fichero a la vez sin esto.
std::mutex mutexHistorialGeneral;
}  // namespace

void FileManager::guardarPartida(const PartidaSnapshot& snapshot,
                                 const std::string& rutaArchivo) {
  std::ofstream file(rutaArchivo);
  if (!file.is_open()) {
    throw std::system_error(PokerError::ArchivoNoEncontrado,
                            "No se pudo crear el archivo: " + rutaArchivo);
  }

  // Usamos un formato Key-Value estruturado
  file << "=== POKER SAVE ===\n";
  file << "MANO_ACTUAL:" << snapshot.manoActual << "\n";
  file << "OBJETIVO_MANOS:" << snapshot.objetivoManos << "\n";
  file << "CIEGA_GRANDE:" << snapshot.ciegaGrande << "\n";
  file << "NUM_JUGADORES:" << snapshot.jugadores.size() << "\n";
  file << "MODO_SUPERVISOR:" << (snapshot.supervisor ? "1" : "0") << "\n";
  file << "TIPO_LIMITE:" << static_cast<int>(snapshot.reglas.tipoLimite) << "\n";
  file << "APLICAR_MIN_RAISE:" << (snapshot.reglas.aplicarMinRaise ? "1" : "0") << "\n";
  file << "MONTE_FIJO:" << snapshot.reglas.monteFijo << "\n";
  file << "DIFICULTAD_BOTS:" << static_cast<int>(snapshot.reglas.dificultadBots) << "\n";
  // El bug del checksum (+196) que aparcó estos tres campos ya se
  // confirmó resuelto (ver agile-doodling-wren.md) — se enganchan ahora,
  // necesarios para que reanudar una sala guardada conserve sus reglas de
  // sala (si no, una sala "abierta tras inicio" con relleno de bots
  // perdía esas dos reglas al recargar, silenciosamente).
  file << "PERMITIR_RECOMPRA:" << (snapshot.reglas.permitirRecompra ? "1" : "0") << "\n";
  file << "RELLENAR_CON_BOTS:" << (snapshot.reglas.rellenarConBots ? "1" : "0") << "\n";
  file << "ABIERTA_TRAS_INICIO:" << (snapshot.reglas.abiertaTrasInicio ? "1" : "0") << "\n";
  for (const auto& j : snapshot.jugadores) {
    // accountId AL FINAL -- añadido después de los cinco campos de
    // siempre, así un .pok escrito por una versión vieja del programa
    // (sin esta columna) sigue teniendo el mismo formato hasta donde
    // llegaba antes. No entra en el checksum (ver cargarPartida()): no es
    // un dato de juego que se pueda usar para hacer trampa, es solo
    // metadato de a quién pertenece el guardado.
    file << "JUGADOR:" << j.nombre << "," << j.saldo << ","
         << (j.esBot ? "1" : "0") << "," << j.comportamiento << ","
         << static_cast<int>(j.estado) << "," << j.accountId << "\n";
  }

  // Metadatos de sala (host, público/privado, código) -- igual que
  // accountId arriba, fuera del checksum a propósito: no son datos de
  // juego, son metadato de sala que un .pok viejo simplemente no tiene.
  file << "HOST_NOMBRE:" << snapshot.hostNombre << "\n";
  file << "SALA_PUBLICA:" << (snapshot.salaPublica ? "1" : "0") << "\n";
  file << "SALA_CODIGO:" << snapshot.salaCodigo << "\n";

  unsigned int checksum = snapshot.manoActual + snapshot.objetivoManos +
                          snapshot.ciegaGrande + snapshot.jugadores.size() +
                          (snapshot.supervisor ? 1 : 0) +
                          static_cast<int>(snapshot.reglas.tipoLimite) +
                          (snapshot.reglas.aplicarMinRaise ? 1 : 0) +
                          snapshot.reglas.monteFijo +
                          static_cast<int>(snapshot.reglas.dificultadBots) +
                          (snapshot.reglas.permitirRecompra ? 1 : 0) +
                          (snapshot.reglas.rellenarConBots ? 1 : 0) +
                          (snapshot.reglas.abiertaTrasInicio ? 1 : 0);

  for (const auto& j : snapshot.jugadores) checksum += j.saldo;
  file << "CHECKSUM:" << checksum << "\n";

  file.close();
}

PartidaSnapshot FileManager::cargarPartida(const std::string& rutaArchivo) {
  std::ifstream file(rutaArchivo);
  if (!file.is_open()) {
    throw std::system_error(PokerError::ArchivoNoEncontrado,
                            "No se pudo leer el archivo: " + rutaArchivo);
  }

  PartidaSnapshot snapshot;
  std::string linea;

  std::getline(file, linea);
  if (linea.find("=== POKER SAVE ===") == std::string::npos) {
    throw std::system_error(PokerError::FormatoInvalido,
                            "El archivo no es una partida guardada válida.");
  }

  unsigned int checksumEsperado = 0;
  unsigned int checksumLeido = 0;
  bool checksumEncontrado = false;

  try {
    while (std::getline(file, linea)) {
      if (linea.empty()) continue;

      size_t pos = linea.find(':');
      if (pos == std::string::npos) continue;

      std::string key = linea.substr(0, pos);
      std::string value = linea.substr(pos + 1);

      if (key == "MANO_ACTUAL") {
        snapshot.manoActual = std::stoi(value);
        checksumEsperado += snapshot.manoActual;
      } else if (key == "OBJETIVO_MANOS") {
        snapshot.objetivoManos = std::stoi(value);
        checksumEsperado += snapshot.objetivoManos;
      } else if (key == "CIEGA_GRANDE") {
        snapshot.ciegaGrande = std::stoi(value);
        checksumEsperado += snapshot.ciegaGrande;
      } else if (key == "NUM_JUGADORES") {
        checksumEsperado += std::stoi(value);
      } else if (key == "MODO_SUPERVISOR") {
        snapshot.supervisor = std::stoi(value) == 1 ? true : false;
        checksumEsperado += std::stoi(value);
      } else if (key == "TIPO_LIMITE") {
        int v = std::stoi(value);
        snapshot.reglas.tipoLimite = static_cast<TipoLimite>(v);
        checksumEsperado += v;
      } else if (key == "APLICAR_MIN_RAISE") {
        int v = std::stoi(value);
        snapshot.reglas.aplicarMinRaise = (v == 1);
        checksumEsperado += v;
      } else if (key == "MONTE_FIJO") {
        snapshot.reglas.monteFijo = std::stoi(value);
        checksumEsperado += snapshot.reglas.monteFijo;
      } else if (key == "DIFICULTAD_BOTS") {
        int v = std::stoi(value);
        snapshot.reglas.dificultadBots = static_cast<DificultadBots>(v);
        checksumEsperado += v;
      } else if (key == "PERMITIR_RECOMPRA") {
        int v = std::stoi(value);
        snapshot.reglas.permitirRecompra = (v == 1);
        checksumEsperado += v;
      } else if (key == "RELLENAR_CON_BOTS") {
        int v = std::stoi(value);
        snapshot.reglas.rellenarConBots = (v == 1);
        checksumEsperado += v;
      } else if (key == "ABIERTA_TRAS_INICIO") {
        int v = std::stoi(value);
        snapshot.reglas.abiertaTrasInicio = (v == 1);
        checksumEsperado += v;
      } else if (key == "JUGADOR") {
        std::stringstream ss(value);
        std::string item;
        JugadorSnapshot j;

        std::getline(ss, j.nombre, ',');

        std::getline(ss, item, ',');
        j.saldo = std::stoi(item);
        checksumEsperado += j.saldo;

        std::getline(ss, item, ',');
        j.esBot = (item == "1");

        std::getline(ss, item, ',');
        j.comportamiento = std::stoi(item);

        std::getline(ss, item, ',');
        j.estado = static_cast<PlayerState>(std::stoi(item));

        // accountId: puede faltar en un .pok escrito antes de este campo
        // -- std::getline devuelve false sin tocar "item" cuando ya no
        // queda nada que leer, así que un fichero viejo lo deja en 0
        // (invitado) sin más, en vez de fallar.
        if (std::getline(ss, item, ',')) {
          j.accountId = std::stoi(item);
        }

        verificarIntegridadJugador(j);
        snapshot.jugadores.push_back(j);
      } else if (key == "CHECKSUM") {
        checksumLeido = (unsigned int)std::stoul(value);
        checksumEncontrado = true;
      } else if (key == "HOST_NOMBRE") {
        snapshot.hostNombre = value;
      } else if (key == "SALA_PUBLICA") {
        snapshot.salaPublica = (value == "1");
      } else if (key == "SALA_CODIGO") {
        snapshot.salaCodigo = value;
      }
    }
  } catch (const std::exception& e) {
    throw std::system_error(
        PokerError::FormatoInvalido,
        "Error parseando tipos de datos. Posible manipulación.");
  }

  // Checksum
  if (!checksumEncontrado || checksumLeido != checksumEsperado) {
    throw std::system_error(
        PokerError::FicheroCorrupto,
        "El checksum no coincide. El archivo fue editado manualmente.");
  }

  // Validación de Reglas
  validarRangoJugadores(snapshot.jugadores.size());
  validarConsistenciaSaldo(snapshot.jugadores);

  return snapshot;
}

// MÉTODOS DE VALIDACIÓN

void FileManager::validarRangoJugadores(size_t numJugadores) {
  if (numJugadores < 2 || numJugadores > 23) {
    throw std::system_error(PokerError::DatosFueraDeRango,
                            "El número de jugadores debe estar entre 2 y 23.");
  }
}

void FileManager::verificarIntegridadJugador(const JugadorSnapshot& data) {
  if (data.saldo < 0) {
    throw std::system_error(
        PokerError::SaldoInconsistente,
        "El jugador " + data.nombre + " tiene saldo negativo.");
  }
  if (data.esBot && (data.comportamiento < 0 || data.comportamiento > 2)) {
    throw std::system_error(
        PokerError::DatosFueraDeRango,
        "Comportamiento inválido para el bot " + data.nombre);
  }
}

void FileManager::validarConsistenciaSaldo(
    const std::vector<JugadorSnapshot>& jugadores) {
  // long long saldoTotal = 0;
  for (const auto& j : jugadores) {
    if (j.saldo < 0)
      throw std::system_error(PokerError::SaldoInconsistente,
                              "Saldo de jugador no valido (< 0)");
  }
  // // Suponiendo que el sistema empezó con saldo base conocido (ej. 1000 *
  // // numJugadores) Aquí puedes ajustar la regla según cómo funcione la
  // economía
  // // de tu juego.
  // long long saldoEsperado = jugadores.size() * 1000;
  // if (saldoTotal != saldoEsperado) {
  //   throw std::system_error(
  //       PokerError::SaldoInconsistente,
  //       "El dinero total en la mesa no coincide con la emisión inicial.");
  // }
}

void FileManager::registrarPartidaFinalizada(PartidaStats& stats,
                                             const std::string& rutaArchivo) {
  // Con el servidor multi-sala, dos hilos de sala pueden llamar a esto a la
  // vez sobre el mismo fichero compartido (ruta fija, no por sala) — sin
  // este lock, la escritura de una sala podría intercalarse con la de otra
  // y corromper el fichero.
  std::lock_guard<std::mutex> lock(mutexHistorialGeneral);

  std::ofstream file(rutaArchivo, std::ios::app);
  if (!file.is_open()) {
    throw std::system_error(
        PokerError::ArchivoNoEncontrado,
        "No se pudo acceder al registro histórico unificado.");
  }

  // Generar Fecha y Hora actual.
  // localtime_r en vez de std::localtime(): éste devuelve un puntero a un
  // buffer estático compartido por todo el proceso, no es seguro si dos
  // salas (hilos) formatean una fecha a la vez.
  std::time_t t = std::time(nullptr);
  struct tm tmBuf {};
  localtimePortable(&t, &tmBuf);
  char buffer[100];
  std::strftime(buffer, sizeof(buffer), "%d/%m/%Y %H:%M:%S", &tmBuf);
  std::string buffer_STR(buffer);
  stats.fechaHora = buffer_STR;

  file << "=== PARTIDA_TERMINADA ===\n";
  file << "FECHA_HORA:" << stats.fechaHora << "\n";
  file << "GANADOR:" << stats.ganadorNombre << "\n";
  file << "SALDO_FINAL:" << stats.saldoFinal << "\n";
  file << "MANOS_JUGADAS:" << stats.manosJugadas << "\n";
  file << "MEJOR_MANO_NOMBRE:" << stats.mejorManoNombre << "\n";
  file << "MEJOR_MANO_JUGADOR:" << stats.mejorManoJugador << "\n";

  for (const auto& j : stats.historialJugadores) {
    file << "HISTORIAL_JUGADOR:" << j.nombre << "," << j.manoEliminacion
         << "\n";
  }
  file << "=== FIN_PARTIDA ===\n";
  file.close();
}

std::vector<PartidaStats> FileManager::cargarHistorialCompleto(
    const std::string& rutaArchivo) {
  std::ifstream file(rutaArchivo);
  std::vector<PartidaStats> historial;
  if (!file.is_open()) return historial;

  std::string linea;
  PartidaStats statsActual;
  bool dentroDePartida = false;

  while (std::getline(file, linea)) {
    if (linea == "=== PARTIDA_TERMINADA ===") {
      statsActual = PartidaStats();
      dentroDePartida = true;
      continue;
    }
    if (linea == "=== FIN_PARTIDA ===") {
      historial.push_back(statsActual);
      dentroDePartida = false;
      continue;
    }

    if (dentroDePartida) {
      size_t pos = linea.find(':');
      if (pos == std::string::npos) continue;

      std::string key = linea.substr(0, pos);
      std::string value = linea.substr(pos + 1);

      if (key == "FECHA_HORA")
        statsActual.fechaHora = value;
      else if (key == "GANADOR")
        statsActual.ganadorNombre = value;
      else if (key == "SALDO_FINAL")
        statsActual.saldoFinal = std::stoi(value);
      else if (key == "MANOS_JUGADAS")
        statsActual.manosJugadas = std::stoi(value);
      else if (key == "MEJOR_MANO_NOMBRE")
        statsActual.mejorManoNombre = value;
      else if (key == "MEJOR_MANO_JUGADOR")
        statsActual.mejorManoJugador = value;
      else if (key == "HISTORIAL_JUGADOR") {
        std::stringstream ss(value);
        JugadorFinStats jfs;
        std::getline(ss, jfs.nombre, ',');
        std::getline(ss, jfs.manoEliminacion, ',');
        statsActual.historialJugadores.push_back(jfs);
      }
    }
  }
  return historial;
}

std::vector<ArchivoGuardado> FileManager::obtenerPartidasGuardadas(
    const std::string& directorio) {
  std::vector<ArchivoGuardado> lista;

  // Si la carpeta no existe, devolvemos lista vacía pa que no pete
  if (!std::filesystem::exists(directorio)) {
    return lista;
  }

  for (const auto& entry : std::filesystem::directory_iterator(directorio)) {
    if (entry.is_regular_file() && entry.path().extension() == ".pok") {
      ArchivoGuardado arch;
      arch.nombre = entry.path().filename().string();
      auto ftime = std::filesystem::last_write_time(entry);
      auto sctp =
          std::chrono::time_point_cast<std::chrono::system_clock::duration>(
              ftime - decltype(ftime)::clock::now() +
              std::chrono::system_clock::now());
      std::time_t cftime = std::chrono::system_clock::to_time_t(sctp);

      char buffer[80];
      struct tm tmBuf {};
      localtimePortable(&cftime, &tmBuf);
      std::strftime(buffer, sizeof(buffer), "%d/%m/%Y %H:%M", &tmBuf);
      arch.fecha = std::string(buffer);

      lista.push_back(arch);
    }
  }
  return lista;
}
void FileManager::borrarArchivoGuardado(const std::string& path) {
  try {
    std::filesystem::remove(path);
  } catch (const std::exception& e) {
    throw std::system_error(
        PokerError::ArchivoNoEncontrado,
        style::Red + "No se pudo borrar el archivo" + path +
            " verifique el path y asegúrese de que no está en uso.");
  }
}

void FileManager::renombrarArchivoGuardado(const std::string& pathActual,
                                           const std::string& pathNuevo) {
  if (std::filesystem::exists(pathNuevo)) {
    throw std::system_error(
        PokerError::ArchivoNoEncontrado,
        "Ya existe un archivo con ese nombre: " + pathNuevo);
  }
  try {
    std::filesystem::rename(pathActual, pathNuevo);
  } catch (const std::exception& e) {
    throw std::system_error(
        PokerError::ArchivoNoEncontrado,
        "No se pudo renombrar el archivo: " + std::string(e.what()));
  }
}