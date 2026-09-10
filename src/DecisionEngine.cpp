#include "../include/DecisionEngine.hpp"

#include <algorithm>
#include <cmath>
#include <map>
#include <random>

// ─────────────────────────────────────────────────────────────────────────────
//  UTILIDADES INTERNAS
// ─────────────────────────────────────────────────────────────────────────────

std::vector<Carta> DecisionEngine::obtenerCartasDesconocidas(
    const GameState& state, const std::vector<Carta>& cartasPropias) {
  std::vector<Carta> desconocidas;
  desconocidas.reserve(52);
  for (int p = static_cast<int>(Palo::CORAZONES);
       p <= static_cast<int>(Palo::PICAS); ++p) {
    for (int v = static_cast<int>(Valor::DOS); v <= static_cast<int>(Valor::AS); ++v) {
      Carta c(static_cast<Palo>(p), static_cast<Valor>(v));
      bool enMano = (c == cartasPropias[0] || c == cartasPropias[1]);
      bool enMesa = std::find(state.cartasComunitarias.begin(),
                              state.cartasComunitarias.end(), c) !=
                   state.cartasComunitarias.end();
      if (!enMano && !enMesa) desconocidas.push_back(c);
    }
  }
  return desconocidas;
}

// ─────────────────────────────────────────────────────────────────────────────
//  CÁLCULO DE FUERZA ACTUAL (exhaustivo — bueno para River)
// ─────────────────────────────────────────────────────────────────────────────

double DecisionEngine::calcularFuerzaMano(const GameState& state,
                                          const std::vector<Carta>& cartasPropias) {
  auto desconocidas = obtenerCartasDesconocidas(state, cartasPropias);
  HandResult miRes = Analyzer::evaluarMano(cartasPropias, state.cartasComunitarias);

  int victorias = 0, empates = 0, total = 0;
  for (size_t i = 0; i < desconocidas.size() - 1; ++i) {
    for (size_t j = i + 1; j < desconocidas.size(); ++j) {
      std::vector<Carta> rival = {desconocidas[i], desconocidas[j]};
      HandResult rivalRes = Analyzer::evaluarMano(rival, state.cartasComunitarias);
      if (miRes > rivalRes)      ++victorias;
      else if (miRes == rivalRes) ++empates;
      ++total;
    }
  }
  if (total == 0) return 0.0;
  return static_cast<double>(victorias + empates / 2.0) / total;
}

// ─────────────────────────────────────────────────────────────────────────────
//  FUERZA BRUTA (FACIL) — O(1): una sola evaluación, sin rango de rival
// ─────────────────────────────────────────────────────────────────────────────

double DecisionEngine::calcularFuerzaBruta(const std::vector<Carta>& cartasPropias,
                                            const std::vector<Carta>& mesa) {
  if (mesa.empty()) return 0.5;
  HandResult hr = Analyzer::evaluarMano(cartasPropias, mesa);
  long long categoria = hr.score / 759375LL;
  switch (static_cast<HandRank>(categoria)) {
    case HandRank::CARTA_ALTA:   return 0.18;
    case HandRank::PAREJA:       return 0.38;
    case HandRank::DOBLE_PAREJA: return 0.58;
    case HandRank::TRIO:         return 0.72;
    case HandRank::ESCALERA:     return 0.82;
    case HandRank::COLOR:        return 0.87;
    case HandRank::FULL_HOUSE:   return 0.92;
    case HandRank::POKER:        return 0.97;
    default:                     return 0.99;  // escalera de color / real
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RANGE NARROWING — solo considera rivales con top-40% de manos
// ─────────────────────────────────────────────────────────────────────────────

double DecisionEngine::estimarFuerzaConRango(const GameState& state,
                                              const std::vector<Carta>& cartasPropias) {
  auto desconocidas = obtenerCartasDesconocidas(state, cartasPropias);
  HandResult miRes = Analyzer::evaluarMano(cartasPropias, state.cartasComunitarias);

  // Paso 1: recopilar scores de todas las manos posibles del rival
  std::vector<long long> scores;
  scores.reserve(desconocidas.size() * desconocidas.size() / 2);
  for (size_t i = 0; i < desconocidas.size() - 1; ++i) {
    for (size_t j = i + 1; j < desconocidas.size(); ++j) {
      std::vector<Carta> rival = {desconocidas[i], desconocidas[j]};
      scores.push_back(Analyzer::evaluarMano(rival, state.cartasComunitarias).score);
    }
  }
  if (scores.empty()) return 0.5;

  // Sin agresión: eliminar el 45% de manos más débiles (rango de limp/call).
  // Cada escalada de apuestas estrecha más el rango estimado del rival.
  double corte;
  if      (state.raisesRivalesEstaMano >= 3) corte = 0.72;
  else if (state.raisesRivalesEstaMano >= 2) corte = 0.62;
  else if (state.raisesRivalesEstaMano >= 1) corte = 0.50;
  else                                        corte = 0.45;
  std::vector<long long> sorted = scores;
  std::sort(sorted.begin(), sorted.end());
  long long umbral = sorted[static_cast<size_t>(sorted.size() * corte)];

  // Paso 2: comparar solo contra manos fuertes.
  // scores[k] ya es la puntuación completa de esa mano rival (calculada en el
  // paso 1): comparar el long long directamente evita re-evaluar la mano por
  // segunda vez, que es el costo dominante de esta función.
  int victorias = 0, empates = 0, total = 0;
  for (long long s : scores) {
    if (s < umbral) continue;
    if (miRes.score > s)      ++victorias;
    else if (miRes.score == s) ++empates;
    ++total;
  }
  if (total == 0) return 0.5;
  return static_cast<double>(victorias + empates / 2.0) / total;
}

// ─────────────────────────────────────────────────────────────────────────────
//  MONTE CARLO — simula múltiples rivales según numJugadoresActivos
// ─────────────────────────────────────────────────────────────────────────────

double DecisionEngine::simularEquityMonteCarlo(
    const GameState& state, const std::vector<Carta>& cartasPropias,
    int numSimulaciones) {
  auto desconocidas = obtenerCartasDesconocidas(state, cartasPropias);
  if (desconocidas.empty()) return 0.5;

  int cartasFaltantes = 5 - static_cast<int>(state.cartasComunitarias.size());
  if (cartasFaltantes <= 0)
    return calcularFuerzaMano(state, cartasPropias);

  // Preflop: siempre 1v1 — la fuerza de la mano inicial es relativa a un rival;
  // el precio de entrar en multijugador ya lo gestiona el potOdds.
  // Postflop: simular rivales reales (hasta 4) para mayor realismo.
  int numRivales = (state.rondaActual == Rondas::PREFLOP)
      ? 1
      : std::max(1, std::min(state.numJugadoresActivos - 1, 4));
  int cartasNecesarias = cartasFaltantes + numRivales * 2;
  while (cartasNecesarias > static_cast<int>(desconocidas.size()) && numRivales > 1) {
    --numRivales;
    cartasNecesarias = cartasFaltantes + numRivales * 2;
  }
  if (static_cast<int>(desconocidas.size()) < cartasNecesarias) return 0.5;

  std::random_device rd;
  std::mt19937 gen(rd());
  int victorias = 0, empates = 0;

  for (int s = 0; s < numSimulaciones; ++s) {
    std::vector<Carta> pool = desconocidas;
    std::shuffle(pool.begin(), pool.end(), gen);

    std::vector<Carta> mesa = state.cartasComunitarias;
    for (int i = 0; i < cartasFaltantes; ++i) {
      mesa.push_back(pool.back());
      pool.pop_back();
    }

    HandResult miRes = Analyzer::evaluarMano(cartasPropias, mesa);
    bool perdio = false, empato = false;

    for (int r = 0; r < numRivales && pool.size() >= 2; ++r) {
      std::vector<Carta> manoRival = {pool.back()};
      pool.pop_back();
      manoRival.push_back(pool.back());
      pool.pop_back();
      HandResult rivalRes = Analyzer::evaluarMano(manoRival, mesa);
      if (rivalRes > miRes)      { perdio = true; break; }
      if (rivalRes == miRes)       empato = true;
    }

    if (!perdio) {
      if (empato) ++empates;
      else        ++victorias;
    }
  }

  return static_cast<double>(victorias + empates / 2.0) / numSimulaciones;
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROBABILIDAD DE MEJORAR (para semi-faroles)
// ─────────────────────────────────────────────────────────────────────────────

double DecisionEngine::calcularProbabilidadMejorar(
    const GameState& state, const std::vector<Carta>& cartasPropias) {
  if (state.rondaActual == Rondas::RIVER || state.rondaActual == Rondas::SHOWDOWN)
    return 0.0;

  auto desconocidas = obtenerCartasDesconocidas(state, cartasPropias);
  HandResult actual = Analyzer::evaluarMano(cartasPropias, state.cartasComunitarias);
  long long catActual = actual.score / 759375LL;

  int mejoras = 0;
  for (const auto& futura : desconocidas) {
    std::vector<Carta> mesaFutura = state.cartasComunitarias;
    mesaFutura.push_back(futura);
    if (Analyzer::evaluarMano(cartasPropias, mesaFutura).score / 759375LL > catActual)
      ++mejoras;
  }
  return desconocidas.empty() ? 0.0
                               : static_cast<double>(mejoras) / desconocidas.size();
}

// ─────────────────────────────────────────────────────────────────────────────
//  PELIGRO DE MESA — color/escalera/mesa pareada (0.0 = segura, 1.0 = peligrosa)
// ─────────────────────────────────────────────────────────────────────────────

double DecisionEngine::analizarPeligroMesa(const std::vector<Carta>& mesa) {
  if (mesa.size() < 3) return 0.0;
  double peligro = 0.0;

  // Riesgo de color: 3+ cartas del mismo palo
  std::map<int, int> palos;
  for (const auto& c : mesa) palos[static_cast<int>(c.getPalo())]++;
  for (const auto& [p, cnt] : palos) {
    if (cnt >= 4) peligro += 0.45;
    else if (cnt >= 3) peligro += 0.22;
  }

  // Riesgo de escalera: cartas conectadas en ventana de 5
  std::vector<int> vals;
  for (const auto& c : mesa) vals.push_back(static_cast<int>(c.getValor()));
  std::sort(vals.begin(), vals.end());
  vals.erase(std::unique(vals.begin(), vals.end()), vals.end());
  // As bajo
  if (!vals.empty() && vals.back() == 14) vals.insert(vals.begin(), 1);

  int maxConectadas = 0;
  for (size_t i = 0; i < vals.size(); ++i) {
    int start = vals[i], count = 1;
    for (size_t j = i + 1; j < vals.size() && vals[j] <= start + 4; ++j)
      ++count;
    maxConectadas = std::max(maxConectadas, count);
  }
  if (maxConectadas >= 4) peligro += 0.35;
  else if (maxConectadas >= 3) peligro += 0.15;

  // Mesa pareada: pareja en tablón = cualquier rival con esa carta tiene trio
  // Se penaliza más porque es la amenaza más común y menos obvia
  std::map<int, int> cuentaVals;
  for (const auto& c : mesa) cuentaVals[static_cast<int>(c.getValor())]++;
  for (const auto& [v, cnt] : cuentaVals) {
    if (cnt >= 3) peligro += 0.45; // Trio en mesa: potencial full/poker para rivales
    else if (cnt >= 2) peligro += 0.32; // Pareja en mesa: trio muy alcanzable
  }

  return std::clamp(peligro, 0.0, 1.0);
}

// ─────────────────────────────────────────────────────────────────────────────
//  OUTS — cartas que mejorarían mi mano
// ─────────────────────────────────────────────────────────────────────────────

int DecisionEngine::contarOuts(const GameState& state,
                                const std::vector<Carta>& cartasPropias) {
  if (state.rondaActual == Rondas::RIVER || state.rondaActual == Rondas::SHOWDOWN)
    return 0;

  auto desconocidas = obtenerCartasDesconocidas(state, cartasPropias);
  HandResult actual = Analyzer::evaluarMano(cartasPropias, state.cartasComunitarias);
  long long catActual = actual.score / 759375LL;

  int outs = 0;
  for (const auto& futura : desconocidas) {
    std::vector<Carta> mesaFutura = state.cartasComunitarias;
    mesaFutura.push_back(futura);
    if (Analyzer::evaluarMano(cartasPropias, mesaFutura).score / 759375LL > catActual)
      ++outs;
  }
  return outs;
}

// Regla del 2 y del 4
double DecisionEngine::calcularEquityPorOuts(int outs, Rondas ronda) {
  if (ronda == Rondas::FLOP) return std::min(1.0, outs * 0.04);
  if (ronda == Rondas::TURN) return std::min(1.0, outs * 0.02);
  return 0.0;
}

// ─────────────────────────────────────────────────────────────────────────────
//  CONTRIBUCIÓN PROPIA — cuántas de mis 5 cartas ganadoras son mías (0.0–0.4)
//  0.0 = la mesa hace la mano por mí (todos pueden tenerla)
//  0.4 = ambas cartas propias están en la combinación (ventaja exclusiva)
// ─────────────────────────────────────────────────────────────────────────────

double DecisionEngine::calcularContribucionPropia(
    const std::vector<Carta>& cartasPropias, const std::vector<Carta>& mesa) {
  if (mesa.empty() || cartasPropias.size() < 2) return 0.5;

  HandResult res = Analyzer::evaluarMano(cartasPropias, mesa);
  int propias = 0;
  for (const auto& c : res.combination) {
    if (c == cartasPropias[0] || c == cartasPropias[1]) ++propias;
  }
  return static_cast<double>(propias) / 5.0;
}

// ─────────────────────────────────────────────────────────────────────────────
//  SCORE DE DECISIÓN — ponderación fuerza/equity según ronda
// ─────────────────────────────────────────────────────────────────────────────

double DecisionEngine::calcularDecisionScore(Rondas ronda, double fuerzaActual,
                                              double equityFutura, int numJugadores) {
  if (ronda == Rondas::PREFLOP) {
    // Equity 1v1: cuanto más jugadores activos, más calidad necesita la mano.
    // Con 2 jugadores (HU): minEq=0.358; con 6 jugadores: minEq=0.390.
    int rivales = std::max(1, numJugadores - 1);
    double minEq = 0.35 + rivales * 0.008;
    return std::clamp((equityFutura - minEq) / 0.40, 0.0, 1.0);
  }
  if (ronda == Rondas::FLOP)  return fuerzaActual * 0.60 + equityFutura * 0.40;
  if (ronda == Rondas::TURN)  return fuerzaActual * 0.85 + equityFutura * 0.15;
  return fuerzaActual; // RIVER: solo importa la fuerza actual
}

// ─────────────────────────────────────────────────────────────────────────────
//  SIZING DE RAISE — basado en el bote (NORMAL/DIFICIL) o multiplicador (FACIL)
// ─────────────────────────────────────────────────────────────────────────────

int DecisionEngine::calcularMontoRaise(const GameState& state,
                                       Comportamiento nivel, int saldo,
                                       double fuerza) {
  int aPagar = std::max(0, state.apuestaAIgualar - state.miApuestaEnRonda);
  int minRaise = std::max(state.ciegaGrande,
                          state.apuestaAIgualar > 0 ? state.apuestaAIgualar
                                                    : state.ciegaGrande);
  // Si el saldo no llega al mínimo de raise, el único movimiento posible es all-in.
  // Clampear aquí evita que clamp() reciba hi < lo y aborte el proceso.
  if (saldo <= 0) return 0;
  minRaise = std::min(minRaise, saldo);

  // Todos los niveles: apuesta fracción del bote calibrada según fuerza
  int boteEfectivo = state.boteTotal + aPagar;
  double fraccion;
  if (nivel == Comportamiento::AGRESIVO)
    fraccion = (fuerza > 0.80) ? 0.80 : 0.60;
  else if (nivel == Comportamiento::SEGURO)
    fraccion = (fuerza > 0.90) ? 0.55 : 0.40;
  else
    fraccion = (fuerza > 0.75) ? 0.65 : 0.50;

  // Value bet más alto en River con mano fuerte
  if (state.rondaActual == Rondas::RIVER && fuerza > 0.70)
    fraccion = std::min(1.0, fraccion + 0.15);

  int cantidad = std::max(static_cast<int>(boteEfectivo * fraccion), minRaise);

  if (state.rondaActual == Rondas::PREFLOP) {
    // Open: 2.5-3x BB. Re-raise: 3x la apuesta anterior (no pot-sizing).
    int openSize = static_cast<int>(state.ciegaGrande * 2.5);
    if (state.apuestaAIgualar > state.ciegaGrande) {
      // Ya hay un raise anterior → 3-bet estándar = 3x el raise previo
      cantidad = std::min(cantidad, state.apuestaAIgualar * 3);
    }
    cantidad = std::max(cantidad, openSize);
  }

  return std::clamp(cantidad, minRaise, saldo);
}

// ─────────────────────────────────────────────────────────────────────────────
//  FAROL — con detección de debilidad del rival en River
// ─────────────────────────────────────────────────────────────────────────────

bool DecisionEngine::decidirFarol(Rondas ronda, Comportamiento nivel,
                                   double fuerza, double mejora,
                                   bool accionAnteriorFueCheck) {
  // Preflop: no hay líneas de betting que justifiquen farol; la fuerza de mano
  // ya filtra cuándo abrir/subir/pasar. Evitar raises aleatorios preflop.
  if (ronda == Rondas::PREFLOP) return false;

  std::random_device rd;
  std::mt19937 gen(rd());
  std::uniform_real_distribution<> dis(0.0, 1.0);

  double prob = 0.02;

  // Semi-farol: mano débil con proyecto real (mejora > 0.22 filtra gutshots sueltos)
  if (fuerza < 0.45 && mejora > 0.22) prob += 0.12;

  if (nivel == Comportamiento::SEGURO)        prob *= 0.4;
  else if (nivel == Comportamiento::AGRESIVO) prob *= 1.4;

  if (ronda == Rondas::RIVER) {
    if (fuerza < 0.20) {
      // Farol puro: solo si el rival mostró debilidad con un check previo
      if (accionAnteriorFueCheck) {
        prob = (nivel == Comportamiento::AGRESIVO)   ? 0.20 :
               (nivel == Comportamiento::EQUILIBRADO) ? 0.07 : 0.02;
      } else {
        // Rival apostó → raramente faroleamos encima
        prob = (nivel == Comportamiento::AGRESIVO) ? 0.04 : 0.01;
      }
    } else {
      prob = 0.0; // Tenemos valor → check/call, no farol
    }
  }

  return dis(gen) < prob;
}

// ─────────────────────────────────────────────────────────────────────────────
//  PENSARACCION — motor de decisión principal
// ─────────────────────────────────────────────────────────────────────────────

Accion DecisionEngine::pensarAccion(const GameState& state,
                                    Comportamiento nivel, int saldo,
                                    const std::vector<Carta>& cartasPropias,
                                    int numRaisesMiosEnRonda,
                                    const std::map<std::string, PerfilJugador>* perfiles) {
  DificultadBots dificultad = state.reglas.dificultadBots;

  int aPagar = std::max(0, state.apuestaAIgualar - state.miApuestaEnRonda);
  double potOdds = (state.boteTotal + aPagar > 0)
      ? static_cast<double>(aPagar) / (state.boteTotal + aPagar) : 0.0;

  // ── 1. FUERZA ACTUAL ────────────────────────────────────────────────────────
  // NORMAL/EXPERTO: range narrowing — los rivales activos no tienen manos
  // aleatorias; como mínimo filtramos el 30% inferior (manos que no continuarían).
  // El corte se estrecha automáticamente con cada raise dentro de estimarFuerzaConRango.
  // FACIL: solo mira su propia categoría de mano (calcularFuerzaBruta, O(1)),
  // sin modelar el rango del rival — el leak clásico de un jugador principiante.
  double fuerzaActual = 0.0;
  if (state.rondaActual != Rondas::PREFLOP) {
    fuerzaActual = (dificultad == DificultadBots::FACIL)
        ? calcularFuerzaBruta(cartasPropias, state.cartasComunitarias)
        : estimarFuerzaConRango(state, cartasPropias);
  }

  // ── 2. EQUITY FUTURA (Monte Carlo multi-rival) ──────────────────────────────
  double equityFutura = 0.0;
  if (state.rondaActual != Rondas::RIVER && state.rondaActual != Rondas::SHOWDOWN) {
    int numSim = (dificultad == DificultadBots::EXPERTO) ? 1000 :
                 (dificultad == DificultadBots::NORMAL)  ? 700 : 250;
    equityFutura = simularEquityMonteCarlo(state, cartasPropias, numSim);
  }

  // ── 3. EQUITY POR OUTS (Flop/Turn, NORMAL+) ────────────────────────────────
  double equityPorOuts = 0.0;
  if (dificultad != DificultadBots::FACIL &&
      (state.rondaActual == Rondas::FLOP || state.rondaActual == Rondas::TURN)) {
    int outs = contarOuts(state, cartasPropias);
    equityPorOuts = calcularEquityPorOuts(outs, state.rondaActual);
  }
  double equityEfectiva = std::max(equityFutura, equityPorOuts);

  // ── 4. TEXTURA DE MESA Y CONTRIBUCIÓN PERSONAL (NORMAL+) ───────────────────
  // FACIL ignora el peligro del tablón: no descuenta su mano aunque la mesa
  // esté pareada o con proyecto de color/escalera a la vista.
  double peligroMesa      = 0.0;
  double contribucionPropia = 0.5; // neutral en preflop
  if (dificultad != DificultadBots::FACIL && !state.cartasComunitarias.empty()) {
    peligroMesa       = analizarPeligroMesa(state.cartasComunitarias);
    contribucionPropia = calcularContribucionPropia(cartasPropias,
                                                    state.cartasComunitarias);
    // Penalizar fuerza si la ventaja es de la mesa (compartida con rivales)
    // y la mesa es peligrosa. Si mis cartas son la clave → penalización mínima.
    double penalizacion = peligroMesa * std::max(0.0, 0.5 - contribucionPropia);
    fuerzaActual = std::max(0.0, fuerzaActual - penalizacion);
  }

  // ── 4b. PENALIZACIÓN POR ESCALADA DE APUESTAS (postflop, NORMAL+) ──────────
  // Cuando los rivales siguen subiendo en cadena, es señal de manos muy fuertes.
  // Se descuenta el decisionScore final para que el bot no se "pique" a contraatacar.
  // FACIL no reacciona a esto: sigue pagando escaladas como si nada (leak explotable).
  if (dificultad != DificultadBots::FACIL &&
      state.rondaActual != Rondas::PREFLOP &&
      state.raisesRivalesEstaMano >= 2) {
    int exceso = state.raisesRivalesEstaMano - 1; // cuántos raises por encima del primero
    double descuento = exceso * 0.06 + peligroMesa * exceso * 0.04;
    fuerzaActual   = std::max(0.0, fuerzaActual - descuento);
    equityEfectiva = std::max(0.0, equityEfectiva - descuento * 0.5);
  }

  // ── 5. DECISION SCORE ───────────────────────────────────────────────────────
  double decisionScore = calcularDecisionScore(state.rondaActual, fuerzaActual,
                                               equityEfectiva,
                                               state.numJugadoresActivos);

  // ── 6. AJUSTE POR POSICIÓN (NORMAL+) ───────────────────────────────────────
  if (dificultad != DificultadBots::FACIL) {
    if (state.jugadoresPendientes > 3)
      decisionScore -= 0.08;
    else if (state.jugadoresPendientes == 0)
      decisionScore += 0.05;
  }
  decisionScore = std::clamp(decisionScore, 0.0, 1.0);

  // ── 7. FAROL ────────────────────────────────────────────────────────────────
  // FACIL no detecta proyectos (mejora=0): no hace semi-faroles con draws.
  double mejora = (dificultad == DificultadBots::FACIL)
      ? 0.0 : calcularProbabilidadMejorar(state, cartasPropias);
  bool farol = decidirFarol(state.rondaActual, nivel, fuerzaActual, mejora,
                            state.accionAnteriorFueCheck);

  // ── 8. LÓGICA ESPECIAL DEL RIVER ────────────────────────────────────────────
  if (state.rondaActual == Rondas::RIVER) {
    if (fuerzaActual >= 0.20) farol = false;
  }

  // ── 9. UMBRALES ─────────────────────────────────────────────────────────────
  double umbralFoldBase, umbralRaise;
  switch (dificultad) {
    case DificultadBots::FACIL:
      umbralFoldBase = (nivel == Comportamiento::SEGURO) ? 0.40 :
                       (nivel == Comportamiento::AGRESIVO ? 0.32 : 0.35);
      umbralRaise    = (nivel == Comportamiento::SEGURO) ? 0.85 :
                       (nivel == Comportamiento::AGRESIVO ? 0.68 : 0.76);
      break;
    case DificultadBots::NORMAL:
      umbralFoldBase = (nivel == Comportamiento::SEGURO) ? 0.45 :
                       (nivel == Comportamiento::AGRESIVO ? 0.38 : 0.40);
      umbralRaise    = (nivel == Comportamiento::SEGURO) ? 0.80 :
                       (nivel == Comportamiento::AGRESIVO ? 0.62 : 0.71);
      break;
    default: // EXPERTO
      umbralFoldBase = (nivel == Comportamiento::SEGURO) ? 0.45 :
                       (nivel == Comportamiento::AGRESIVO ? 0.35 : 0.40);
      umbralRaise    = (nivel == Comportamiento::SEGURO) ? 0.78 :
                       (nivel == Comportamiento::AGRESIVO ? 0.60 : 0.69);
  }

  double factorRiesgo = (nivel == Comportamiento::AGRESIVO) ? 0.80 :
                        (nivel == Comportamiento::SEGURO    ? 1.20 : 1.0);
  double umbralFold = std::max(umbralFoldBase, potOdds * factorRiesgo);

  // PREFLOP: el umbral de fold escala con el nivel de agresión en la mesa.
  if (state.rondaActual == Rondas::PREFLOP) {
    double minFoldPreflop = (dificultad == DificultadBots::FACIL) ? 0.10 : 0.18;
    // Sin raise: limpar solo cuesta 1BB; umbral mínimo (solo foldar basura)
    // Con raise: ajustar por pot-odds y presión de la mesa
    double ajustePorSubida;
    if (state.raisesRivalesEstaMano == 0) {
      ajustePorSubida = minFoldPreflop;
    } else {
      ajustePorSubida = (potOdds > 0.30) ? potOdds * factorRiesgo : minFoldPreflop;
    }
    double ajustePorRaises = state.raisesRivalesEstaMano * 0.04;
    umbralFold = std::max(minFoldPreflop, ajustePorSubida + ajustePorRaises);
  }

  if (farol && potOdds > 0.35) farol = false;

  // ── 9b. AJUSTE POR PERFILES (solo EXPERTO) ──────────────────────────────────
  if (dificultad == DificultadBots::EXPERTO && perfiles && !perfiles->empty()) {
    float agrProm = 0.0f, ftrProm = 0.0f, vipProm = 0.0f;
    int n = 0;
    for (const auto& [nombre, perf] : *perfiles) {
      if (perf.esConfiable()) {
        agrProm += perf.agresividad();
        ftrProm += perf.foldToRaise();
        vipProm += perf.VPIP();
        ++n;
      }
    }
    if (n > 0) {
      agrProm /= n; ftrProm /= n; vipProm /= n;
      float agr = agrProm, ftr = ftrProm, vip = vipProm;

      // Si sabemos quién fue el último en subir, su perfil individual pesa más
      // que la media de la mesa: es la información más relevante para reaccionar
      // a ESTA apuesta concreta, no a "cómo juega la mesa en general".
      if (!state.ultimoAgresorNombre.empty()) {
        auto itAgresor = perfiles->find(state.ultimoAgresorNombre);
        if (itAgresor != perfiles->end() && itAgresor->second.esConfiable()) {
          agr = 0.65f * itAgresor->second.agresividad() + 0.35f * agrProm;
          ftr = 0.65f * itAgresor->second.foldToRaise() + 0.35f * ftrProm;
          vip = 0.65f * itAgresor->second.VPIP()        + 0.35f * vipProm;
        }
      }

      // Rock/Nit: tight-passive → sus apuestas son manos fuertes, bluffear más
      if (vip < 0.25f && agr < 0.40f) {
        umbralFold = std::min(umbralFold + 0.06, 1.0);
        if (!farol && decisionScore > 0.20 && mejora > 0.10)
          farol = true;
      }
      // Calling Station: llaman todo → nunca farolear, apostar valor fino
      else if (vip > 0.60f && ftr < 0.35f) {
        farol       = false;
        umbralRaise = std::max(umbralRaise - 0.05, 0.40);
      }
      // LAG: loose-aggressive → su agresión no correlaciona con la fuerza de
      // su mano, así que "respetar" sus subidas (como con un TAG) es un error:
      // hay que pagar más ligero, no menos. Tampoco merece la pena farolear
      // a alguien que ya apuesta y sube sin ningún criterio.
      //
      // Además, estimarFuerzaConRango() ya descontó fuerzaActual asumiendo que
      // cada raise viene de una mano fuerte (state.raisesRivalesEstaMano). Esa
      // asunción es la base de todo el rango estrechado, y es precisamente la
      // que NO se cumple con un LAG: hay que revertir parte del descuento aquí,
      // donde ya sabemos (por perfil) que el supuesto de partida era erróneo.
      else if (vip > 0.50f && agr > 0.55f) {
        umbralFold = std::max(umbralFold - 0.06, 0.0);
        farol      = false;
        decisionScore = std::clamp(decisionScore + 0.10, 0.0, 1.0);
      }
      // TAG: tight-aggressive → cuando apuestan van en serio
      else if (vip < 0.35f && agr > 0.55f) {
        umbralFold = std::min(umbralFold + 0.08, 1.0);
      }
    }
  }

  bool intentarRaise = (farol || decisionScore >= umbralRaise);

  // Preflop: raise solo con manos fuertes; máximo 1 raise por bot por ronda.
  if (state.rondaActual == Rondas::PREFLOP && intentarRaise) {
    double minPreflop = (dificultad == DificultadBots::EXPERTO) ? 0.72 :
                        (dificultad == DificultadBots::NORMAL)  ? 0.75 : 0.80;
    // Cada raise previo en la ronda exige más mano para re-subir
    minPreflop += state.raisesRivalesEstaMano * 0.05;
    minPreflop  = std::min(minPreflop, 0.95);
    // Solo se permite un raise propio preflop (evita guerras de re-raises)
    if (decisionScore < minPreflop || numRaisesMiosEnRonda >= 1)
      intentarRaise = false;
  }

  // ── 9c. 3-BET LIGERO DE FAROL PREFLOP (solo EXPERTO) ───────────────────────
  // El resto de niveles nunca farolea preflop (decidirFarol lo bloquea sin
  // excepción). EXPERTO se permite una excepción muy acotada: re-subir de farol
  // a un rival perfilado como excesivamente nitty (se rinde a un raise más del
  // 65% de las veces), y solo si la propia mano no es papel mojado del todo.
  bool farolPreflopLigero = false;
  if (dificultad == DificultadBots::EXPERTO && !intentarRaise &&
      state.rondaActual == Rondas::PREFLOP &&
      state.raisesRivalesEstaMano == 1 && numRaisesMiosEnRonda == 0 &&
      decisionScore > 0.35 && perfiles && !state.ultimoAgresorNombre.empty()) {
    auto itAgresor = perfiles->find(state.ultimoAgresorNombre);
    if (itAgresor != perfiles->end() && itAgresor->second.esConfiable() &&
        itAgresor->second.foldToRaise() > 0.65f) {
      static thread_local std::mt19937 genBluffPreflop(std::random_device{}());
      std::uniform_real_distribution<> probBluffPreflop(0.0, 1.0);
      if (probBluffPreflop(genBluffPreflop) < 0.12) {
        intentarRaise = true;
        farolPreflopLigero = true;
      }
    }
  }

  // Máximo de raises propios por ronda (postflop: hasta 2)
  if (intentarRaise && state.rondaActual != Rondas::PREFLOP
      && numRaisesMiosEnRonda >= 2)
    intentarRaise = false;

  // Margen del 7%: no llamar en el límite exacto de pot-odds sino con ventaja real.
  bool callMatematico = (aPagar > 0 && decisionScore >= potOdds + 0.07);

  // ── 10. RESOLUCIÓN ──────────────────────────────────────────────────────────
  if (intentarRaise) {
    // EXPERTO: al farolear, el tamaño de la apuesta debe representar una mano
    // fuerte de verdad. Si el sizing se derivara directamente del decisionScore
    // real (bajo, por definición, cuando se farolea) el farol se apostaría más
    // pequeño que un value bet — un patrón explotable por un rival observador.
    double fuerzaParaSizing = decisionScore;
    if (dificultad == DificultadBots::EXPERTO && (farol || farolPreflopLigero)) {
      fuerzaParaSizing = std::max(decisionScore, 0.82);
    }
    int cantidad = calcularMontoRaise(state, nivel, saldo, fuerzaParaSizing);

    // Respetar límites de la partida
    if (state.reglas.tipoLimite == TipoLimite::LIMITE_BOTE) {
      int potMax = state.boteTotal + 2 * aPagar;
      if (potMax > 0 && cantidad > potMax) cantidad = potMax;
    } else if (state.reglas.tipoLimite == TipoLimite::LIMITE_FIJO &&
               state.reglas.monteFijo > 0) {
      cantidad = state.reglas.monteFijo;
    }

    if (state.reglas.aplicarMinRaise) {
      int minRaise = state.apuestaAIgualar > 0 ? state.apuestaAIgualar
                                               : state.ciegaGrande;
      if (cantidad < minRaise && cantidad < saldo) {
        if (aPagar == 0)   return {TipoAccion::CHECK,  0,      true, ""};
        if (aPagar >= saldo) return {TipoAccion::ALL_IN, saldo, true, ""};
        return {TipoAccion::CALL, aPagar, true, ""};
      }
    }

    cantidad = std::min(cantidad, saldo);
    if (cantidad >= saldo) {
      // All-in solo con mano suficientemente fuerte según la calle
      double umbralAllin = (state.rondaActual == Rondas::PREFLOP) ? 0.88 :
                           (state.rondaActual == Rondas::RIVER)   ? 0.88 : 0.75;
      if (decisionScore >= umbralAllin)
        return {TipoAccion::ALL_IN, saldo, true, ""};
      // Mano no llega al umbral: apostar fracción del bote sin ir all-in
      int minRaiseCalc = std::max(state.ciegaGrande,
          state.apuestaAIgualar > 0 ? state.apuestaAIgualar : state.ciegaGrande);
      minRaiseCalc = std::min(minRaiseCalc, saldo);
      // Si minRaiseCalc == saldo (stack corto), el hi de este clamp no puede
      // caer por debajo del lo o std::clamp() aborta el proceso. En ese caso
      // betAlt == saldo fuerza el fallback a CALL/CHECK justo debajo.
      int betAlt = std::clamp(
          static_cast<int>((state.boteTotal + aPagar) * 0.55),
          minRaiseCalc, std::max(minRaiseCalc, saldo - 1));
      if (betAlt >= saldo || betAlt < minRaiseCalc) {
        if (aPagar == 0) return {TipoAccion::CHECK, 0, true, ""};
        return {TipoAccion::CALL, std::min(aPagar, saldo), true, ""};
      }
      return {TipoAccion::RAISE, betAlt, true, ""};
    }
    return {TipoAccion::RAISE, cantidad, true, ""};
  }

  if (decisionScore >= umbralFold || farol || aPagar == 0 || callMatematico) {
    if (aPagar == 0) return {TipoAccion::CHECK, 0, true, ""};
    if (aPagar >= saldo) {
      // All-in requiere mano muy sólida; con muchas subidas previas, más aún
      double umbralAllIn = 0.80;
      if (state.raisesRivalesEstaMano >= 2) umbralAllIn += 0.05;
      if (state.raisesRivalesEstaMano >= 3) umbralAllIn += 0.05;
      umbralAllIn = std::min(umbralAllIn, 0.93); // techo: nunca imposible
      if (decisionScore > umbralAllIn) return {TipoAccion::ALL_IN, saldo, true, ""};
      return {TipoAccion::FOLD, 0, true, ""};
    }
    return {TipoAccion::CALL, aPagar, true, ""};
  }

  return {TipoAccion::FOLD, 0, true, ""};
}
