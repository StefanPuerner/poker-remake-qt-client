/**
 * @file Serializer.hpp
 * @brief Conversión de tipos del juego a/desde strings para el protocolo de red.
 */
#pragma once

#include <string>
#include <vector>
#include "../Carta.hpp"
#include "../GameTypes.hpp"
#include "../Player.hpp"

/**
 * @brief Conversión de tipos del juego a/desde strings para el protocolo de red.
 *
 * Todas las funciones son puras (sin estado). Se agrupan en un namespace para
 * evitar colisiones con nombres genéricos en el espacio global.
 *
 * Formato de carta: 2 caracteres.
 *  - Valor: 2–9, T(Diez), J(Jota), Q(Reina), K(Rey), A(As).
 *  - Palo:  H(Corazones), D(Diamantes), C(Tréboles), S(Picas).
 *  - Ejemplo: As de corazones → "AH", diez de picas → "TS".
 *
 * Formato de lista de cartas: valores separados por coma sin espacios.
 *  - Ejemplo: [AS, KH, QD] → "AS,KH,QD".
 */
namespace net::ser {

// ── Carta ──────────────────────────────────────────────────────────────────────

/// @return Representación de 2 caracteres de la carta @p c (p.ej. "AH", "TS").
std::string cartaToStr(const Carta& c);

/// @return Lista de cartas serializada separada por comas (p.ej. "AH,TS,QD").
std::string cartasToStr(const std::vector<Carta>& cartas);

// ── Enums del juego ────────────────────────────────────────────────────────────

/// @return Nombre de la fase como string ("PREFLOP", "FLOP", "TURN", "RIVER").
std::string rondaToStr(Rondas r);

/// @return Nombre de la acción como string ("FOLD", "CALL", "RAISE", "CHECK", "ALL_IN").
std::string accionToStr(TipoAccion a);

/// Parsea la string recibida del cliente y devuelve el TipoAccion correspondiente.
TipoAccion  strToAccion(const std::string& s);

// ── Listas genéricas ───────────────────────────────────────────────────────────
//
// El protocolo reutiliza el mismo patrón "unir con un separador" en varios
// eventos (nombres separados por coma, historial separado por '|', botes
// separados por ';'...). Un único helper por tipo evita que cada evento
// nuevo reinvente su propio bucle -- ver jugadoresMesaToStr()/saldosToStr()/
// eliminacionesToStr() más abajo para los formatos compuestos que SÍ tienen
// estructura propia (esos no son solo "unir una lista").

/// Une @p valores con @p sep entre cada elemento (sin separador final).
/// Lista vacía -> "". Ej: unirStr({"Alice","Bot1"}, ',') -> "Alice,Bot1".
std::string unirStr(const std::vector<std::string>& valores, char sep);

/// Igual que unirStr() pero para enteros (ej. los side pots: "450;200").
std::string unirEnteros(const std::vector<int>& valores, char sep);

// ── Jugadores en mesa (campo "jugadores" de GAME_STATE) ───────────────────────

/// Datos de un jugador visibles en mesa para el resto (saldo/apuesta +
/// avatar/loadout). Deliberadamente desacoplado de AccountManager/
/// InfoAvatarMesa -- net::ser no depende de cuentas (SQLite), así que quien
/// arma la lista rellena esto con los valores por defecto (0/false/"") para
/// bots, invitados, o cuando no hay AccountManager de por medio (p.ej.
/// LocalGameObserver en modo offline, ver docs/plan-modo-offline.md).
struct DatosJugadorMesa {
  std::string nombre;
  int saldo = 0;
  int apuestaAcumuladaMano = 0;
  int partidasGanadas = 0;
  bool tieneMarcoBasico = false;
  std::string textura;
  std::string efecto;
  std::string decoracionLateral1;
  std::string decoracionLateral2;
  std::string decoracionSuperior;
  // Acabado de cada decoración (fase 2 del material) -- "" = sigue al marco.
  std::string acabadoLateral1;
  std::string acabadoLateral2;
  std::string acabadoSuperior;
};

/// Formato: "nombre:saldo:apuesta:partidasGanadas:tieneMarco:textura:efecto:
/// decoLat1:decoLat2:decoSup:acabLat1:acabLat2:acabSup;..." (un bloque de 13
/// campos por jugador, jugadores separados por ';'). Ej: "Alice:580:200:25:1:
/// pulido_bronce:brillo:hoja::corona:::plata;Bot1:420:150:0:0::::::::".
/// Los tres acabados van AL FINAL a propósito: los clientes leen por
/// posición, y uno ya instalado sigue encontrando los 10 primeros donde
/// estaban.
std::string jugadoresMesaToStr(const std::vector<DatosJugadorMesa>& jugadores);

// ── Saldos (campo "jugadores" de SALDOS_UPDATE) ───────────────────────────────

/// Formato: "nombre:saldo;..." -- más simple que jugadoresMesaToStr(), sin
/// avatar/loadout (SALDOS_UPDATE solo necesita el número al día).
std::string saldosToStr(const std::vector<Player*>& jugadores);

// ── Eliminaciones (campo "eliminaciones" de fin de partida) ──────────────────

/// Formato: "nombre:manoEliminacion;..." ("X" si el jugador sobrevivió,
/// ver JugadorFinStats::manoEliminacion).
std::string eliminacionesToStr(const std::vector<JugadorFinStats>& historial);

}  // namespace net::ser
