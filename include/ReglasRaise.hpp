/**
 * @file ReglasRaise.hpp
 * @brief Límites de subida (mínimo/máximo "extra" sobre lo que toca igualar)
 * según las reglas de la partida. Antes vivía duplicado en Persona.cpp; se
 * extrae aquí para que también lo use NetworkPlayer al informar al cliente
 * de red de su rango válido.
 */
#pragma once

#include <algorithm>
#include <utility>

#include "GameTypes.hpp"

/**
 * @brief Calcula el rango válido de "extra" a subir sobre lo que toca
 * igualar (No-Limit/Pot-Limit/Fixed-Limit según state.reglas).
 * @param aPagarParaIgualar Cuánto falta para igualar la apuesta actual.
 * @param saldo Saldo disponible del jugador que sube.
 * @return {minExtra, maxExtra}. Si maxExtra <= 0, no hay subida posible
 * (el saldo no llega ni para igualar).
 */
inline std::pair<int, int> calcularLimitesRaise(const GameState& state,
                                                 int aPagarParaIgualar,
                                                 int saldo) {
  int maxExtra = saldo - aPagarParaIgualar;
  if (maxExtra <= 0) return {0, 0};

  // Mínimo: 1 por defecto, o la apuesta actual si se exige min raise.
  int minExtra = 1;
  if (state.reglas.aplicarMinRaise && state.apuestaAIgualar > 0) {
    minExtra = state.apuestaAIgualar;  // Debes al menos doblar la apuesta actual
  } else if (state.reglas.aplicarMinRaise) {
    minExtra = state.ciegaGrande;      // Bet inicial: mínimo = ciega grande
  }

  // Máximo: según el tipo de límite.
  if (state.reglas.tipoLimite == TipoLimite::LIMITE_BOTE) {
    int potLimitMax = state.boteTotal + aPagarParaIgualar;
    maxExtra = std::min(maxExtra, potLimitMax);
  } else if (state.reglas.tipoLimite == TipoLimite::LIMITE_FIJO &&
             state.reglas.monteFijo > 0) {
    int fijo = state.reglas.monteFijo;
    minExtra = std::min(fijo, maxExtra);
    maxExtra = std::min(fijo, maxExtra);
  }

  // Garantiza min <= max (por si el saldo es muy bajo).
  if (minExtra > maxExtra) minExtra = maxExtra;
  return {minExtra, maxExtra};
}
