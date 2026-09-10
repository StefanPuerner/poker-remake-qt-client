/**
 * @file TimeUtils.hpp
 * @brief Envoltorio portable de localtime_r (POSIX) / localtime_s (MSVC).
 */
#pragma once

#include <ctime>

/**
 * @brief Versión reentrante de localtime, portable entre plataformas.
 *
 * localtime_r (POSIX) y localtime_s (MSVC) hacen lo mismo -- rellenar un
 * struct tm sin usar el buffer estático interno no reentrante de
 * std::localtime() -- pero con los argumentos en orden inverso y
 * convenciones de retorno distintas. Este wrapper permite llamar igual en
 * las dos plataformas: localtimePortable(&t, &tmBuf).
 */
inline void localtimePortable(const std::time_t* t, struct tm* out) {
#ifdef _WIN32
  localtime_s(out, t);
#else
  localtime_r(t, out);
#endif
}
