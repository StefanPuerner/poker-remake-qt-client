/**
 * @file style.hpp
 * @brief Constantes de escape ANSI para colores y atributos de texto en terminal.
 */
#pragma once

#include <string>

/**
 * @brief Constantes de escape ANSI para colorear la salida del terminal.
 *
 * Definidas como `inline const` (C++17) para que exista una única instancia
 * en todo el programa, independientemente del número de TUs que incluyan
 * este header. Combínalas con el operador + de std::string:
 * @code
 *   std::cout << style::Bold + style::Green + "OK" + style::Reset;
 * @endcode
 */
namespace style {

// ── Atributos de texto ─────────────────────────────────────────────────────
inline const std::string Reset     = "\033[0m";
inline const std::string Bold      = "\033[1m";
inline const std::string Dim       = "\033[2m";
inline const std::string Italic    = "\033[3m";
inline const std::string Underline = "\033[4m";
inline const std::string Blink     = "\033[5m";
inline const std::string Invert    = "\033[7m";
inline const std::string Hidden    = "\033[8m";

// ── Colores estándar ───────────────────────────────────────────────────────
inline const std::string Black   = "\033[30m";
inline const std::string Red     = "\033[31m";
inline const std::string Green   = "\033[32m";
inline const std::string Yellow  = "\033[33m";
inline const std::string Blue    = "\033[34m";
inline const std::string Magenta = "\033[35m";
inline const std::string Cyan    = "\033[36m";
inline const std::string White   = "\033[37m";

// ── Colores brillantes ─────────────────────────────────────────────────────
inline const std::string Gray          = "\033[90m";
inline const std::string BrightRed     = "\033[91m";
inline const std::string BrightGreen   = "\033[92m";
inline const std::string BrightYellow  = "\033[93m";
inline const std::string BrightBlue    = "\033[94m";
inline const std::string BrightMagenta = "\033[95m";
inline const std::string BrightCyan    = "\033[96m";
inline const std::string BrightWhite   = "\033[97m";

// ── Fondos ─────────────────────────────────────────────────────────────────
inline const std::string BgBlack  = "\033[40m";
inline const std::string BgRed    = "\033[41m";
inline const std::string BgGreen  = "\033[42m";
inline const std::string BgYellow = "\033[43m";
inline const std::string BgBlue   = "\033[44m";
inline const std::string BgWhite  = "\033[47m";

// ── Iconos ─────────────────────────────────────────────────────────────────
inline const std::string InfoIcon    = "(ℹ)";
inline const std::string SuccessIcon = "✔";
inline const std::string ErrorIcon   = "✖";
inline const std::string WarnIcon    = "⚠";
inline const std::string ArrowIcon   = "➜";
inline const std::string Corazon     = "♥";
inline const std::string Diamante    = "♦";
inline const std::string Pica        = "♠";
inline const std::string Trebol      = "♣";

}  // namespace style
