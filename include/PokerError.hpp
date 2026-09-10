/**
 * @file PokerError.hpp
 * @brief Códigos de error del sistema integrados con std::error_code.
 */
#pragma once

#include <string>
#include <system_error>

/**
 * @brief Códigos de error del sistema de poker.
 *
 * Integrado con std::error_code para que las excepciones std::system_error
 * lanzadas por FileManager incluyan un código semánticamente correcto.
 */
enum class PokerError {
  Exito               = 0,
  ArchivoNoEncontrado = 1,
  FormatoInvalido     = 2,
  FicheroCorrupto     = 3,
  SaldoInconsistente  = 4,
  DatosFueraDeRango   = 5
};

namespace std {
/// Registra PokerError como compatible con std::error_code.
template <>
struct is_error_code_enum<PokerError> : true_type {};
}  // namespace std

/// Categoría de error personalizada para mensajes legibles en las excepciones.
class PokerErrorCategory : public std::error_category {
 public:
  const char* name() const noexcept override { return "PokerSystem"; }

  std::string message(int ev) const override {
    switch (static_cast<PokerError>(ev)) {
      case PokerError::Exito:               return "Exito";
      case PokerError::ArchivoNoEncontrado: return "Archivo no encontrado o inaccesible";
      case PokerError::FormatoInvalido:     return "Formato de archivo no reconocido";
      case PokerError::FicheroCorrupto:     return "Fichero corrupto o manipulado";
      case PokerError::SaldoInconsistente:  return "Inconsistencia detectada en el saldo total";
      case PokerError::DatosFueraDeRango:   return "Valores fuera del rango permitido (ej. bots > 23)";
      default:                             return "Error desconocido en PokerSystem";
    }
  }
};

/// Crea el std::error_code correspondiente a @p e para usar en std::system_error.
inline std::error_code make_error_code(PokerError e) {
  static PokerErrorCategory const category{};
  return {static_cast<int>(e), category};
}
