/**
 * @file PathUtils.hpp
 * @brief Resuelve la carpeta "data/" de forma independiente al directorio
 * de trabajo desde el que se lance el ejecutable.
 */
#pragma once

#include <filesystem>
#include <string>

/**
 * @brief Ruta absoluta de la carpeta "data/", con "/" final incluido.
 *
 * Antes, todo el código usaba el literal "../data/" a secas — funciona
 * solo si el proceso se lanza con el directorio de trabajo dentro de
 * build/ (de donde sale el ejecutable). Lanzarlo desde cualquier otro
 * sitio (p. ej. la raíz del repo, `./build/PokerServer`) resuelve esa
 * ruta relativa a un sitio distinto y equivocado — el guardado, el log y
 * el histórico fallan en silencio o con "ERROR_SISTEMA" según el caso.
 *
 * Aquí se calcula a partir de dónde está el propio binario en disco
 * (`/proc/self/exe`, Linux/Android — únicas plataformas que build en este
 * proyecto), no del directorio de trabajo actual, así que el resultado es
 * el mismo sin importar desde dónde se invoque.
 */
inline const std::string& carpetaData() {
  static const std::string ruta = [] {
    std::error_code ec;
    auto exe = std::filesystem::read_symlink("/proc/self/exe", ec);
    std::filesystem::path base =
        ec ? std::filesystem::current_path() : exe.parent_path();
    std::string r = (base / ".." / "data").lexically_normal().string() + "/";
    // En una instalación nueva (primera vez que alguien lo ejecuta, p. ej.
    // desde el AppImage/instalador) esta carpeta todavía no existe — sin
    // esto, el guardado/log/histórico fallaban en silencio (o con
    // ERROR_SISTEMA) la primera vez, en vez de crearla sola como cabría
    // esperar. create_directories() no falla si ya existe.
    std::error_code ecDir;
    std::filesystem::create_directories(r, ecDir);
    return r;
  }();
  return ruta;
}
