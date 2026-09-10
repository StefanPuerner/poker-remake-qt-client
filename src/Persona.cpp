#include "../include/Persona.hpp"

#include <algorithm>
#include <iostream>
#include <limits>

#include "../include/Analyzer.hpp"
#include "../include/Interfaz.hpp"
#include "../include/ReglasRaise.hpp"

Persona::Persona(const std::string& nombre, int saldoInicial)
    : Player(nombre, saldoInicial) {}

Accion Persona::decidirAccion(const GameState& state) {
  Accion accionElegida;
  accionElegida.valido = true;
  accionElegida.cantidad = 0;
  accionElegida.mensajeError = "";

  int aPagarParaIgualar = state.apuestaAIgualar - state.miApuestaEnRonda;
  if (aPagarParaIgualar < 0) aPagarParaIgualar = 0;

  std::string actual = "N/A (Sin comunitarias)";
  std::string probable = "N/A (Preflop)";
  std::string potencial = "N/A (Preflop)";

  if (!state.cartasComunitarias.empty()) {
    actual = Analyzer::evaluarMano(cartasPropias_, state.cartasComunitarias)
                 .handName;
    potencial = Analyzer::obtenerMaximoPotencial(cartasPropias_,
                                                 state.cartasComunitarias);
    probable = Analyzer::obtenerCombinacionMasProbable(cartasPropias_, state.cartasComunitarias);
  }

  // LLAMAMOS A LA INTERFAZ CON LOS NUEVOS PARÁMETROS
  Interfaz::mostrarOpcionesAccion(nombre_, aPagarParaIgualar, state.miSaldo,
                                  actual, probable, potencial);

  int opcion = Interfaz::leerOpcionMenu(1, 5);

  switch (opcion) {
    case 1:
      accionElegida.tipo = TipoAccion::VER_CARTAS;
      break;

    case 2:
      accionElegida.tipo = TipoAccion::FOLD;
      break;

    case 3:
      if (aPagarParaIgualar == 0) {
        accionElegida.tipo = TipoAccion::CHECK;
      } else {
        accionElegida.tipo = TipoAccion::CALL;
        accionElegida.cantidad = std::min(aPagarParaIgualar, state.miSaldo);
      }
      break;

    case 4: {
      auto [minExtra, maxExtraPosible] =
          calcularLimitesRaise(state, aPagarParaIgualar, state.miSaldo);

      if (maxExtraPosible <= 0) {
        return {TipoAccion::ERROR, 0, false,
                "No tienes saldo suficiente para subir la apuesta."};
      }

      int extraRaise = Interfaz::leerMontoRaise(minExtra, maxExtraPosible);

      accionElegida.tipo = TipoAccion::RAISE;
      accionElegida.cantidad = aPagarParaIgualar + extraRaise;
      break;
    }

    case 5:
      accionElegida.tipo = TipoAccion::ALL_IN;
      accionElegida.cantidad = state.miSaldo;
      break;
  }

  return accionElegida;
}