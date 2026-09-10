#include "../../include/net/Serializer.hpp"

#include <cstddef>

namespace net::ser {

// ─────────────────────────────────────────────────────────────────────────────
//  Carta → string
// ─────────────────────────────────────────────────────────────────────────────

std::string cartaToStr(const Carta& c) {
  std::string s;

  // Valor
  switch (c.getValor()) {
    case Valor::DOS:
      s += '2';
      break;
    case Valor::TRES:
      s += '3';
      break;
    case Valor::CUATRO:
      s += '4';
      break;
    case Valor::CINCO:
      s += '5';
      break;
    case Valor::SEIS:
      s += '6';
      break;
    case Valor::SIETE:
      s += '7';
      break;
    case Valor::OCHO:
      s += '8';
      break;
    case Valor::NUEVE:
      s += '9';
      break;
    case Valor::DIEZ:
      s += 'T';
      break;
    case Valor::JOTA:
      s += 'J';
      break;
    case Valor::REINA:
      s += 'Q';
      break;
    case Valor::REY:
      s += 'K';
      break;
    case Valor::AS:
      s += 'A';
      break;
  }

  // Palo
  switch (c.getPalo()) {
    case Palo::CORAZONES:
      s += 'H';
      break;
    case Palo::DIAMANTES:
      s += 'D';
      break;
    case Palo::TREBOLES:
      s += 'C';
      break;
    case Palo::PICAS:
      s += 'S';
      break;
  }

  return s;  // ej: "AH", "TS", "2C"
}

std::string cartasToStr(const std::vector<Carta>& cartas) {
  std::string result;
  for (std::size_t i = 0; i < cartas.size(); ++i) {
    if (i > 0) result += ',';
    result += cartaToStr(cartas[i]);
  }
  return result;  // ej: "AH,KD,QC" o "" si está vacía
}

// ─────────────────────────────────────────────────────────────────────────────
//  Enums → string
// ─────────────────────────────────────────────────────────────────────────────

std::string rondaToStr(Rondas r) {
  switch (r) {
    case Rondas::PREFLOP:
      return "PREFLOP";
    case Rondas::FLOP:
      return "FLOP";
    case Rondas::TURN:
      return "TURN";
    case Rondas::RIVER:
      return "RIVER";
    case Rondas::SHOWDOWN:
      return "SHOWDOWN";
  }
  return "UNKNOWN";
}

std::string accionToStr(TipoAccion a) {
  switch (a) {
    case TipoAccion::FOLD:
      return "FOLD";
    case TipoAccion::CALL:
      return "CALL";
    case TipoAccion::RAISE:
      return "RAISE";
    case TipoAccion::ALL_IN:
      return "ALL_IN";
    case TipoAccion::CHECK:
      return "CHECK";
    case TipoAccion::VER_CARTAS:
      return "VER_CARTAS";
    case TipoAccion::ERROR:
      return "ERROR";
  }
  return "ERROR";
}

TipoAccion strToAccion(const std::string& s) {
  if (s == "FOLD") return TipoAccion::FOLD;
  if (s == "CALL") return TipoAccion::CALL;
  if (s == "RAISE") return TipoAccion::RAISE;
  if (s == "ALL_IN") return TipoAccion::ALL_IN;
  if (s == "CHECK") return TipoAccion::CHECK;
  if (s == "VER_CARTAS") return TipoAccion::VER_CARTAS;
  return TipoAccion::ERROR;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Listas genéricas
// ─────────────────────────────────────────────────────────────────────────────

std::string unirStr(const std::vector<std::string>& valores, char sep) {
  std::string result;
  for (std::size_t i = 0; i < valores.size(); ++i) {
    if (i > 0) result += sep;
    result += valores[i];
  }
  return result;
}

std::string unirEnteros(const std::vector<int>& valores, char sep) {
  std::string result;
  for (std::size_t i = 0; i < valores.size(); ++i) {
    if (i > 0) result += sep;
    result += std::to_string(valores[i]);
  }
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Jugadores en mesa / saldos / eliminaciones
// ─────────────────────────────────────────────────────────────────────────────

std::string jugadoresMesaToStr(const std::vector<DatosJugadorMesa>& jugadores) {
  std::string result;
  for (std::size_t i = 0; i < jugadores.size(); ++i) {
    if (i > 0) result += ';';
    const DatosJugadorMesa& j = jugadores[i];
    result += j.nombre + ':' +
              std::to_string(j.saldo) + ':' +
              std::to_string(j.apuestaAcumuladaMano) + ':' +
              std::to_string(j.partidasGanadas) + ':' +
              (j.tieneMarcoBasico ? '1' : '0') + ':' +
              j.textura + ':' +
              j.efecto + ':' +
              j.decoracionLateral1 + ':' +
              j.decoracionLateral2 + ':' +
              j.decoracionSuperior + ':' +
              j.acabadoLateral1 + ':' +
              j.acabadoLateral2 + ':' +
              j.acabadoSuperior;
  }
  return result;
}

std::string saldosToStr(const std::vector<Player*>& jugadores) {
  std::string result;
  for (std::size_t i = 0; i < jugadores.size(); ++i) {
    if (i > 0) result += ';';
    result += jugadores[i]->getNombre() + ':' +
              std::to_string(jugadores[i]->getSaldo());
  }
  return result;
}

std::string eliminacionesToStr(const std::vector<JugadorFinStats>& historial) {
  std::string result;
  for (std::size_t i = 0; i < historial.size(); ++i) {
    if (i > 0) result += ';';
    result += historial[i].nombre + ':' + historial[i].manoEliminacion;
  }
  return result;
}

}  // namespace net::ser
