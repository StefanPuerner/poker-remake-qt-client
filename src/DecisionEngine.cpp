#include "../include/DecisionEngine.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <random>

#include "../include/ReglasRaise.hpp"

// ═════════════════════════════════════════════════════════════════════════════
//  Utilidades: azar, evaluador rápido, percentil preflop
// ═════════════════════════════════════════════════════════════════════════════

namespace {

// thread_local: cada sala (hilo) tiene su propio generador -- ver el comentario
// equivalente en Bot.cpp.
std::mt19937& generador() {
  static thread_local std::mt19937 gen(std::random_device{}());
  return gen;
}

double unif() {
  return std::uniform_real_distribution<double>(0.0, 1.0)(generador());
}

double sigmoide(double x) { return 1.0 / (1.0 + std::exp(-x)); }

/// Decide con una transición suave alrededor de un umbral: lejos de él es casi
/// determinista, cerca es una moneda al aire. Un bot con umbrales duros es
/// legible; con una "temperatura" pequeña deja de serlo sin jugar mal.
bool superaUmbral(double valor, double umbral, double temp) {
  if (temp <= 1e-9) return valor >= umbral;
  return unif() < sigmoide((valor - umbral) / temp);
}

/// Mayor carta de una escalera dentro de una máscara de valores (bit 12 = As),
/// contando el As como 1 (rueda). -1 si no hay escalera.
int altaEscalera(int mascara) {
  int m = (mascara << 1) | ((mascara >> 12) & 1);  // bit j = valor j-1; bit 0 = As bajo
  for (int h = 13; h >= 4; --h) {
    if (((m >> (h - 4)) & 31) == 31) return h - 1;
  }
  return -1;
}

/// Los @p cuantas valores más altos de la máscara, de mayor a menor.
int tomarAltos(int mascara, int cuantas, int* fuera) {
  int n = 0;
  for (int v = 12; v >= 0 && n < cuantas; --v) {
    if (mascara & (1 << v)) fuera[n++] = v;
  }
  return n;
}

long long empaquetar(int categoria, const int* k, int m) {
  long long v = categoria;
  for (int i = 0; i < 5; ++i) v = v * 13 + (i < m ? k[i] : 0);
  return v;
}

}  // namespace

int DecisionEngine::codificar(const Carta& c) {
  int valor = static_cast<int>(c.getValor()) - 2;
  int palo = static_cast<int>(c.getPalo()) - static_cast<int>(Palo::CORAZONES);
  return valor * 4 + (palo & 3);
}

long long DecisionEngine::puntuarRapido(const int* cartas, int n) {
  int cntV[13] = {0};
  int cntP[4] = {0};
  int mascP[4] = {0};
  int mascV = 0;
  for (int i = 0; i < n; ++i) {
    int v = cartas[i] >> 2, p = cartas[i] & 3;
    ++cntV[v];
    ++cntP[p];
    mascP[p] |= 1 << v;
    mascV |= 1 << v;
  }

  // Escalera de color.
  for (int p = 0; p < 4; ++p) {
    if (cntP[p] >= 5) {
      int h = altaEscalera(mascP[p]);
      if (h >= 0) {
        int k[1] = {h};
        return empaquetar(8, k, 1);
      }
    }
  }

  int poker = -1;
  int trios[3], nt = 0, parejas[3], np = 0;
  for (int v = 12; v >= 0; --v) {
    if (cntV[v] == 4) poker = v;
    else if (cntV[v] == 3) { if (nt < 3) trios[nt++] = v; }
    else if (cntV[v] == 2) { if (np < 3) parejas[np++] = v; }
  }

  if (poker >= 0) {
    int resto = mascV & ~(1 << poker);
    int k[2] = {poker, 0};
    int alto[1];
    if (tomarAltos(resto, 1, alto) > 0) k[1] = alto[0];
    return empaquetar(7, k, 2);
  }

  if (nt >= 1 && (nt >= 2 || np >= 1)) {
    int par = -1;
    if (nt >= 2) par = trios[1];
    if (np >= 1) par = std::max(par, parejas[0]);
    int k[2] = {trios[0], par};
    return empaquetar(6, k, 2);
  }

  for (int p = 0; p < 4; ++p) {
    if (cntP[p] >= 5) {
      int k[5];
      int m = tomarAltos(mascP[p], 5, k);
      return empaquetar(5, k, m);
    }
  }

  int h = altaEscalera(mascV);
  if (h >= 0) {
    int k[1] = {h};
    return empaquetar(4, k, 1);
  }

  if (nt >= 1) {
    int resto = mascV & ~(1 << trios[0]);
    int k[3] = {trios[0], 0, 0};
    int alt[2];
    int m = tomarAltos(resto, 2, alt);
    for (int i = 0; i < m; ++i) k[1 + i] = alt[i];
    return empaquetar(3, k, 3);
  }

  if (np >= 2) {
    int resto = mascV & ~(1 << parejas[0]) & ~(1 << parejas[1]);
    int k[3] = {parejas[0], parejas[1], 0};
    int alt[1];
    if (tomarAltos(resto, 1, alt) > 0) k[2] = alt[0];
    return empaquetar(2, k, 3);
  }

  if (np == 1) {
    int resto = mascV & ~(1 << parejas[0]);
    int k[4] = {parejas[0], 0, 0, 0};
    int alt[3];
    int m = tomarAltos(resto, 3, alt);
    for (int i = 0; i < m; ++i) k[1 + i] = alt[i];
    return empaquetar(1, k, 4);
  }

  int k[5];
  int m = tomarAltos(mascV, 5, k);
  return empaquetar(0, k, m);
}

namespace {

/// Puntuación tipo Chen de una mano inicial (más alto = mejor).
double puntuarChen(int v1, int v2, bool suited) {  // v = 0..12 (2..As)
  int alto = std::max(v1, v2), bajo = std::min(v1, v2);
  auto valorAlto = [](int v) {
    switch (v) {
      case 12: return 10.0;
      case 11: return 8.0;
      case 10: return 7.0;
      case 9:  return 6.0;
      default: return (v + 2) / 2.0;
    }
  };
  double pts = valorAlto(alto);
  if (alto == bajo) return std::max(5.0, pts * 2.0);
  if (suited) pts += 2.0;
  int hueco = alto - bajo - 1;
  if (hueco == 1) pts -= 1.0;
  else if (hueco == 2) pts -= 2.0;
  else if (hueco == 3) pts -= 4.0;
  else if (hueco >= 4) pts -= 5.0;
  if (hueco <= 1 && alto < 10) pts += 1.0;  // proyecto de escalera sin pasar de la reina
  return std::ceil(pts);
}

/// Puntuaciones de las 1326 manos iniciales, ordenadas (se calcula una vez).
const std::vector<double>& tablaChen() {
  static const std::vector<double> tabla = [] {
    std::vector<double> t;
    t.reserve(1326);
    for (int a = 0; a < 52; ++a) {
      for (int b = a + 1; b < 52; ++b) {
        t.push_back(puntuarChen(a >> 2, b >> 2, (a & 3) == (b & 3)));
      }
    }
    std::sort(t.begin(), t.end());
    return t;
  }();
  return tabla;
}

}  // namespace

double DecisionEngine::percentilPreflop(const Carta& a, const Carta& b) {
  int ca = codificar(a), cb = codificar(b);
  double s = puntuarChen(ca >> 2, cb >> 2, (ca & 3) == (cb & 3));
  const auto& t = tablaChen();
  auto lo = std::lower_bound(t.begin(), t.end(), s);
  auto hi = std::upper_bound(t.begin(), t.end(), s);
  double debajo = static_cast<double>(lo - t.begin());
  double iguales = static_cast<double>(hi - lo);
  return (debajo + 0.5 * iguales) / static_cast<double>(t.size());
}

// ═════════════════════════════════════════════════════════════════════════════
//  Rasgos por dificultad
// ═════════════════════════════════════════════════════════════════════════════

namespace {

/// La dificultad son rasgos de juego, no "cuánto calcula". FACIL paga de más y
/// se le nota lo que tiene; EXPERTO mezcla, lee el tamaño y se adapta.
struct Rasgos {
  int simulaciones;       ///< Muestras Monte Carlo (más = menos ruido en la equity).
  bool leeApuesta;        ///< El rango del rival depende del tamaño de su apuesta.
  double gammaFijo;       ///< Sesgo del rango si no lee la apuesta.
  double margenCall;      ///< Se suma a la equity exigida (negativo = paga de más).
  double temp;            ///< Ruido de las decisiones cerca del umbral.
  double faroles;         ///< Frecuencia base de farol/semifarol.
  double umbralValor;     ///< Equity mínima para apostar por valor.
  double umbralSubida;    ///< Equity mínima para subir por valor ante una apuesta.
  double cbet;            ///< Frecuencia de apuesta de continuación (heads-up).
  double aperturaMult;    ///< Anchura del rango de apertura preflop.
  double limp;            ///< Fracción de manos con las que iguala en vez de subir.
  double kCall;           ///< Anchura del rango con el que iguala una subida preflop.
  double k3bet;           ///< Anchura del rango con el que re-sube preflop.
  double blandura;        ///< Cuánto defiende (MDF) ante apuestas pequeñas.
  bool usaPerfiles;
  bool subeSobrePequenas; ///< Sube de farol sobre apuestas mínimas.
  bool ocultaValor;       ///< Varía el tamaño y a veces retrasa la mano fuerte.
};

Rasgos rasgosDe(DificultadBots d) {
  switch (d) {
    case DificultadBots::FACIL:
      return {150, false, 0.55, -0.07, 0.07, 0.02, 0.66, 0.80, 0.30,
              0.50, 0.50, 1.6, 0.07, 0.90, false, false, false};
    case DificultadBots::NORMAL:
      return {350, true, 0.0, 0.02, 0.035, 0.09, 0.62, 0.74, 0.60,
              0.75, 0.30, 1.55, 0.13, 0.75, false, false, true};
    default:  // EXPERTO
      return {600, true, 0.0, 0.01, 0.02, 0.17, 0.58, 0.70, 0.55,
              0.80, 0.22, 1.50, 0.16, 0.65, true, true, true};
  }
}

double factorPersonalidad(Comportamiento n) {
  return n == Comportamiento::AGRESIVO ? 1.25 : (n == Comportamiento::SEGURO ? 0.80 : 1.0);
}

}  // namespace

// ═════════════════════════════════════════════════════════════════════════════
//  Rango del rival y equity
// ═════════════════════════════════════════════════════════════════════════════

namespace {

struct Evaluacion {
  double equity = 0.5;       ///< Probabilidad de ganar (empates a la mitad) contra el rango.
  double fuerzaAhora = 0.5;  ///< Con la mesa actual, fracción de manos del rival que vencemos.
};

/// Equity de @p mias contra @p rivales rivales con rango sesgado hacia manos
/// fuertes por q^gamma (q = percentil de fuerza SOBRE LA MESA ACTUAL).
Evaluacion evaluarContraRango(const std::array<int, 2>& mias, const std::vector<int>& mesa,
                              int rivales, double gamma, int simulaciones) {
  Evaluacion ev;
  const int nMesa = static_cast<int>(mesa.size());
  std::uint64_t usadas = 0;
  usadas |= 1ULL << mias[0];
  usadas |= 1ULL << mias[1];
  for (int c : mesa) usadas |= 1ULL << c;

  std::vector<int> libres;
  libres.reserve(52);
  for (int c = 0; c < 52; ++c) {
    if (!(usadas & (1ULL << c))) libres.push_back(c);
  }
  const int nl = static_cast<int>(libres.size());

  // Puntuación de cada mano posible del rival sobre la mesa actual.
  struct Combo { int a, b; long long puntos; double peso; };
  std::vector<Combo> combos;
  combos.reserve(static_cast<std::size_t>(nl * (nl - 1) / 2));
  int buf[7];
  for (int i = 0; i < nMesa; ++i) buf[i] = mesa[i];
  for (int i = 0; i < nl; ++i) {
    for (int j = i + 1; j < nl; ++j) {
      buf[nMesa] = libres[i];
      buf[nMesa + 1] = libres[j];
      combos.push_back({libres[i], libres[j], DecisionEngine::puntuarRapido(buf, nMesa + 2), 1.0});
    }
  }
  if (combos.empty()) return ev;

  buf[nMesa] = mias[0];
  buf[nMesa + 1] = mias[1];
  const long long mio = DecisionEngine::puntuarRapido(buf, nMesa + 2);

  // Percentil de cada mano (0..1) por orden de fuerza; los empates comparten.
  std::sort(combos.begin(), combos.end(),
            [](const Combo& x, const Combo& y) { return x.puntos < y.puntos; });
  const double total = static_cast<double>(combos.size());
  double batidos = 0.0;
  for (std::size_t i = 0; i < combos.size();) {
    std::size_t j = i;
    while (j < combos.size() && combos[j].puntos == combos[i].puntos) ++j;
    double q = ((static_cast<double>(i) + static_cast<double>(j)) * 0.5) / total;  // percentil medio
    double peso = gamma <= 1e-9 ? 1.0 : std::pow(std::max(q, 1e-3), gamma);
    for (std::size_t k = i; k < j; ++k) combos[k].peso = peso;
    if (combos[i].puntos < mio) batidos += static_cast<double>(j - i);
    else if (combos[i].puntos == mio) batidos += 0.5 * static_cast<double>(j - i);
    i = j;
  }
  ev.fuerzaAhora = batidos / total;

  std::vector<double> acumulado(combos.size());
  double suma = 0.0;
  for (std::size_t i = 0; i < combos.size(); ++i) {
    suma += combos[i].peso;
    acumulado[i] = suma;
  }

  // Río: no queda nada por salir, la equity es exacta contra el rango ponderado.
  if (nMesa == 5) {
    double gana = 0.0;
    for (const Combo& c : combos) {
      if (c.puntos < mio) gana += c.peso;
      else if (c.puntos == mio) gana += 0.5 * c.peso;
    }
    double e = gana / suma;
    ev.equity = rivales <= 1 ? e : std::pow(e, rivales);
    return ev;
  }

  // Calle intermedia: Monte Carlo con rivales sacados del rango y el resto de
  // la mesa al azar.
  auto muestrear = [&](std::uint64_t ocupadas, int& a, int& b) {
    for (int intento = 0; intento < 12; ++intento) {
      double x = unif() * suma;
      std::size_t idx = static_cast<std::size_t>(
          std::lower_bound(acumulado.begin(), acumulado.end(), x) - acumulado.begin());
      if (idx >= combos.size()) idx = combos.size() - 1;
      const Combo& c = combos[idx];
      if (!(ocupadas & (1ULL << c.a)) && !(ocupadas & (1ULL << c.b))) {
        a = c.a;
        b = c.b;
        return true;
      }
    }
    return false;
  };

  double ganadas = 0.0;
  int hechas = 0;
  const int faltan = 5 - nMesa;
  for (int s = 0; s < simulaciones; ++s) {
    std::uint64_t ocupadas = usadas;
    int manos[4][2];
    int nr = 0;
    for (int r = 0; r < rivales && r < 4; ++r) {
      int a = 0, b = 0;
      if (!muestrear(ocupadas, a, b)) break;
      manos[nr][0] = a;
      manos[nr][1] = b;
      ++nr;
      ocupadas |= (1ULL << a) | (1ULL << b);
    }
    if (nr == 0) continue;

    int siete[7];
    for (int i = 0; i < nMesa; ++i) siete[i] = mesa[i];
    for (int i = 0; i < faltan; ++i) {
      int c;
      do { c = static_cast<int>(generador()() % 52); } while (ocupadas & (1ULL << c));
      ocupadas |= 1ULL << c;
      siete[nMesa + i] = c;
    }

    siete[5] = mias[0];
    siete[6] = mias[1];
    long long m = DecisionEngine::puntuarRapido(siete, 7);
    double resultado = 1.0;
    for (int r = 0; r < nr; ++r) {
      siete[5] = manos[r][0];
      siete[6] = manos[r][1];
      long long o = DecisionEngine::puntuarRapido(siete, 7);
      if (o > m) { resultado = 0.0; break; }
      if (o == m) resultado = 0.5;
    }
    ganadas += resultado;
    ++hechas;
  }
  ev.equity = hechas > 0 ? ganadas / hechas : 0.5;
  return ev;
}

}  // namespace

// ═════════════════════════════════════════════════════════════════════════════
//  Construcción de acciones (siempre dentro de los límites de la partida)
// ═════════════════════════════════════════════════════════════════════════════

namespace {

Accion accion(TipoAccion t, int cantidad = 0) { return {t, cantidad, true, ""}; }

/// Igualar (o pasar si es gratis). Si igualar cuesta todo el saldo es all-in.
Accion igualar(int aPagar, int saldo) {
  if (aPagar <= 0) return accion(TipoAccion::CHECK);
  if (aPagar >= saldo) return accion(TipoAccion::ALL_IN, saldo);
  return accion(TipoAccion::CALL, aPagar);
}

/// Sube "hasta" @p objetivoTotal fichas puestas en esta ronda (o lo más cerca
/// que permitan las reglas). Respeta No-Limit con o sin mínimo, Pot-Limit y
/// Fixed-Limit a través de calcularLimitesRaise(). Si no cabe ninguna subida,
/// iguala.
Accion subirA(const GameState& st, int saldo, int aPagar, int objetivoTotal) {
  auto [minExtra, maxExtra] = calcularLimitesRaise(st, aPagar, saldo);
  if (maxExtra <= 0) return igualar(aPagar, saldo);
  int extra = objetivoTotal - st.apuestaAIgualar;
  extra = std::clamp(extra, minExtra, maxExtra);
  // ¿Se queda sin fichas? Entonces es all-in, y solo es legal si el tope de la
  // subida (Pot-Limit) permite llegar hasta ahí -- calcularLimitesRaise() ya lo
  // ha acotado, así que aPagar + extra >= saldo solo ocurre si cabe.
  if (aPagar + extra >= saldo) return accion(TipoAccion::ALL_IN, saldo);
  return accion(TipoAccion::RAISE, aPagar + extra);
}

/// Sube una fracción del bote (bote tras igualar = boteTotal + aPagar).
Accion subirFraccion(const GameState& st, int saldo, int aPagar, double fraccion,
                     double minimoSensato = 0.25, double equity = 1.0) {
  double baseBote = static_cast<double>(st.boteTotal + aPagar);
  int extraDeseado = static_cast<int>(std::lround(fraccion * baseBote));
  // Una subida de 1 ficha no es una jugada: aunque las reglas la permitan, el
  // bot no la hace (sí sabe responder a las de los demás).
  int extraMinimo = std::max(1, static_cast<int>(std::lround(minimoSensato * baseBote)));
  extraDeseado = std::max(extraDeseado, extraMinimo);
  // Sin una mano muy fuerte no se apuesta (ni se sube) más del 60% del saldo: se deja
  // margen en vez de comprometer la pila -- así una mano media no acaba en all-in.
  if (equity < 0.85 && aPagar + extraDeseado >= static_cast<int>(0.6 * saldo)) {
    extraDeseado = std::max(extraMinimo, static_cast<int>(0.4 * saldo) - aPagar);
  }
  int objetivo = st.apuestaAIgualar + extraDeseado;
  // Compromiso: si la apuesta se lleva casi todo el saldo (más de ~80%) se va all-in
  // -- con el 60% de antes, dos apuestas normales en el mismo bote acababan en
  // un all-in y eliminaban a alguien en la primera mano (reportado 2026-09-20).
  if (aPagar + extraDeseado >= static_cast<int>(0.8 * saldo)) objetivo = st.apuestaAIgualar + saldo;
  return subirA(st, saldo, aPagar, objetivo);
}

}  // namespace

// ═════════════════════════════════════════════════════════════════════════════
//  Preflop
// ═════════════════════════════════════════════════════════════════════════════

namespace {

Accion decidirPreflop(const GameState& st, double ph, int saldo, const ContextoBot& ctx,
                      const Rasgos& rg) {
  const int BB = std::max(1, st.ciegaGrande);
  const int aPagar = std::max(0, st.apuestaAIgualar - st.miApuestaEnRonda);
  const int N = std::max(2, st.numJugadoresActivos);
  const double pers = factorPersonalidad(ctx.nivel);
  const double stackBB = static_cast<double>(saldo + st.miApuestaEnRonda) / BB;

  // Posición: 1 = actúo la última (botón), 0 = la primera. Cara a cara, quien
  // abre preflop es el botón: la mejor posición postflop.
  double pos = N <= 2 ? (aPagar > 0 && st.miApuestaEnRonda < BB ? 0.9 : 0.4)
                      : 1.0 - static_cast<double>(st.jugadoresPendientes) / (N - 1);
  pos = std::clamp(pos, 0.0, 1.0);

  const bool sinSubida = st.raisesRivalesEstaMano == 0 && st.apuestaAIgualar <= BB;

  // Con pocas ciegas el único movimiento es empujar o retirarse.
  const bool pilaCorta = stackBB <= 10.0;

  if (sinSubida) {
    double base = N == 2 ? 0.75 : (N == 3 ? 0.38 : (N <= 5 ? 0.27 : 0.19));
    double apertura = std::clamp(base * (0.75 + 0.5 * pos) * rg.aperturaMult * pers, 0.02, 0.97);
    int limpers = std::max(0, static_cast<int>(std::lround(static_cast<double>(st.boteTotal) / BB - 1.5)));

    if (aPagar == 0) {
      // Ciega grande con opción: sube sobre los iguales solo con buena mano.
      double frecuencia = std::clamp(apertura * 0.45, 0.03, 0.6);
      if (superaUmbral(ph, 1.0 - frecuencia, rg.temp * 2.0)) {
        double bb = 3.0 + limpers;
        return subirA(st, saldo, aPagar, static_cast<int>(bb * BB));
      }
      return accion(TipoAccion::CHECK);
    }

    if (pilaCorta && ph >= 1.0 - apertura * 0.9) return accion(TipoAccion::ALL_IN, saldo);

    if (superaUmbral(ph, 1.0 - apertura, rg.temp * 2.0)) {
      // Con pilas cortas (menos de ~40 ciegas) una apertura de 3 ciegas ya es una
      // parte grande de la pila: se abre a 2-2.5 y se suma una ciega por cada igual.
      double bb = (stackBB < 40.0 ? 2.2 : 2.5) + limpers + (unif() < 0.35 ? 0.5 : 0.0);
      if (!rg.ocultaValor) bb = (stackBB < 40.0 ? 2.5 : 3.0) + limpers;  // FACIL: siempre igual
      return subirA(st, saldo, aPagar, static_cast<int>(bb * BB));
    }
    // Iguala (limp) manos jugables; el resto se retira. Completar la ciega
    // pequeña cara a cara es casi gratis, así que solo se tiran las peores.
    double rangoLimp = rg.limp * (N == 2 ? 1.6 : 1.0);
    double suelo = (N == 2 && aPagar <= BB) ? 0.12 : 1.0 - apertura - rangoLimp;
    if (ph >= suelo) return igualar(aPagar, saldo);
    return accion(TipoAccion::FOLD);
  }

  // ── Ante una subida ────────────────────────────────────────────────────
  // Sin nada que igualar (ya puse lo que toca) no hay decisión que tomar.
  if (aPagar == 0) return accion(TipoAccion::CHECK);
  const double r = static_cast<double>(st.apuestaAIgualar) / BB;  // subida en ciegas
  const double rho0 = N == 2 ? 0.66 : 0.36;                        // rango de quien sube
  double rho = std::clamp(rho0 / std::pow(std::max(r, 1.2) / 2.5, 0.85), 0.04, 0.92);
  if (st.raisesRivalesEstaMano >= 2) rho *= std::pow(0.6, st.raisesRivalesEstaMano - 1);
  rho = std::max(rho, 0.03);

  const double potPrevio = static_cast<double>(std::max(1, st.boteTotal - aPagar));
  const double precio = static_cast<double>(aPagar) / (potPrevio + 2.0 * aPagar);  // equity mínima aprox.
  double fraccionCall = rho * rg.kCall * std::clamp(0.33 / std::max(precio, 0.05), 0.55, 1.8);

  // Defensa mínima: ante una subida barata no se abandona todo el rango.
  if (aPagar <= 0.25 * saldo) {
    double mdf = potPrevio / (potPrevio + aPagar);
    fraccionCall = std::max(fraccionCall, mdf * rg.blandura * 0.75);
  }
  fraccionCall = std::clamp(fraccionCall, 0.03, 0.97);

  // Perfil del que sube (EXPERTO): a un loco se le paga más ancho, a un roca
  // menos.
  if (rg.usaPerfiles && ctx.perfiles && !st.ultimoAgresorNombre.empty()) {
    auto it = ctx.perfiles->find(st.ultimoAgresorNombre);
    if (it != ctx.perfiles->end() && it->second.esConfiable()) {
      const PerfilJugador& p = it->second;
      if (p.agresividad() > 0.6f && p.VPIP() > 0.5f) fraccionCall = std::min(0.97, fraccionCall * 1.5);
      else if (p.VPIP() < 0.25f) fraccionCall *= 0.75;
    }
  }

  // Sube (re-sube) por valor con la parte alta de su rango de continuación.
  double kSube = rg.k3bet * pers;
  double umbralSube = 1.0 - std::clamp(rho * kSube, 0.02, 0.15);
  bool puedeSubir = st.raisesRivalesEstaMano <= 2 && ctx.numRaisesMiosEnRonda < 1;
  if (st.raisesRivalesEstaMano >= 2) umbralSube = std::max(umbralSube, 0.985);

  if (pilaCorta) {
    if (ph >= 1.0 - std::clamp(fraccionCall * 0.9, 0.05, 0.9)) return accion(TipoAccion::ALL_IN, saldo);
    return accion(TipoAccion::FOLD);
  }

  if (puedeSubir && superaUmbral(ph, umbralSube, rg.temp * 2.0)) {
    double mult = st.raisesRivalesEstaMano >= 2 ? 2.0 : (pos > 0.6 ? 2.4 : 2.7);
    int objetivo = static_cast<int>(mult * st.apuestaAIgualar);
    // Una re-subida que se lleva más de un tercio de la pila ya es casi ir all-in:
    // con pilas cortas eso eliminaba a un bot en la primera mano. Solo con las
    // mejores manos (AA/KK y poco más) se llega a eso; con el resto, se iguala.
    const int pilaTotal = saldo + st.miApuestaEnRonda;
    if (objetivo > pilaTotal / 3 && ph < 0.985) {
      if (superaUmbral(ph, 1.0 - fraccionCall, rg.temp * 2.0)) return igualar(aPagar, saldo);
      return accion(TipoAccion::FOLD);
    }
    return subirA(st, saldo, aPagar, objetivo);
  }

  // Re-subida de farol con manos justo por debajo del rango de valor.
  if (puedeSubir && N == 2 && st.raisesRivalesEstaMano == 1 && rg.faroles > 0.05 && r <= 4.0 &&
      ph >= 1.0 - fraccionCall && ph < umbralSube) {
    double prob = rg.faroles * 0.35 * pers;
    if (unif() < prob) {
      return subirA(st, saldo, aPagar, static_cast<int>((pos > 0.6 ? 3.0 : 3.5) * st.apuestaAIgualar));
    }
  }

  if (superaUmbral(ph, 1.0 - fraccionCall, rg.temp * 2.0)) return igualar(aPagar, saldo);
  return accion(TipoAccion::FOLD);
}

}  // namespace

// ═════════════════════════════════════════════════════════════════════════════
//  Postflop
// ═════════════════════════════════════════════════════════════════════════════

namespace {

/// Sesgo del rango del rival hacia manos fuertes: crece con el tamaño de su
/// apuesta relativo al bote. 0 = manos al azar; ~2 = apuesta del tamaño del
/// bote; >2.5 = sobreapuesta.
double calcularGamma(const GameState& st, double fraccionApuesta, const ContextoBot& ctx,
                     const Rasgos& rg) {
  if (!rg.leeApuesta) return rg.gammaFijo;
  double g;
  if (fraccionApuesta <= 0.0) {
    // Nadie ha apostado: su rango es más débil que el medio (pasó).
    g = st.accionAnteriorFueCheck ? 0.2 : 0.35;
  } else if (st.reglas.tipoLimite == TipoLimite::LIMITE_FIJO) {
    // Fixed-Limit: todas las apuestas miden lo mismo, así que su tamaño no dice
    // nada de la mano (el bote sí crece con cada calle, y una apuesta fija
    // parece "grande" en el flop y "pequeña" en el río). Solo cuenta que apostó.
    g = 0.9;
    if (st.raisesRivalesEstaMano > 1) g += std::min(0.8, 0.3 * (st.raisesRivalesEstaMano - 1));
  } else {
    g = 0.4 + 1.6 * std::pow(std::min(fraccionApuesta, 1.0), 0.8);
    if (fraccionApuesta > 1.0) g += 0.25 * (std::min(fraccionApuesta, 3.0) - 1.0);
    // Varias subidas seguidas: aún más fuerte.
    if (st.raisesRivalesEstaMano > 1) g += std::min(1.0, 0.35 * (st.raisesRivalesEstaMano - 1));
  }
  if (rg.usaPerfiles && ctx.perfiles && !st.ultimoAgresorNombre.empty() && fraccionApuesta > 0) {
    auto it = ctx.perfiles->find(st.ultimoAgresorNombre);
    if (it != ctx.perfiles->end() && it->second.esConfiable()) {
      const PerfilJugador& p = it->second;
      if (p.agresividad() > 0.6f && p.VPIP() > 0.5f) g *= 0.7;        // apuesta con casi todo
      else if (p.VPIP() < 0.25f && p.agresividad() < 0.45f) g *= 1.2; // roca: cuando apuesta, va en serio
      if (p.apuestasTotal >= 6 && fraccionApuesta <= 0.45 &&
          static_cast<double>(p.apuestasPequenas) / p.apuestasTotal > 0.5) {
        g *= 0.65;  // acostumbra a apostar poco con cualquier cosa
      }
    }
  }
  return std::clamp(g, 0.0, 3.2);
}

double fraccionApuestaValor(double equity, Rondas ronda, const Rasgos& rg) {
  if (!rg.ocultaValor) return equity >= 0.8 ? 0.8 : 0.5;  // FACIL: se le nota
  double f;
  if (equity >= 0.86) f = 0.75;
  else if (equity >= 0.72) f = 0.62;
  else f = 0.45;
  if (ronda == Rondas::RIVER && equity >= 0.8) f += 0.1;
  f += (unif() - 0.5) * (rg.usaPerfiles ? 0.3 : 0.2);
  if (rg.usaPerfiles && ronda == Rondas::RIVER && equity >= 0.9 && unif() < 0.10) f = 1.2;  // sobreapuesta
  return std::clamp(f, 0.25, 1.3);
}

Accion decidirPostflop(const GameState& st, const std::array<int, 2>& mias,
                       const std::vector<int>& mesa, int saldo, const ContextoBot& ctx,
                       const Rasgos& rg) {
  const int aPagar = std::max(0, st.apuestaAIgualar - st.miApuestaEnRonda);
  const int N = std::max(2, st.numJugadoresActivos);
  const int rivales = N - 1;
  const double pers = factorPersonalidad(ctx.nivel);
  const bool enPosicion = st.jugadoresPendientes == 0;
  const bool rio = st.rondaActual == Rondas::RIVER;

  const double potPrevio = static_cast<double>(std::max(1, st.boteTotal - aPagar));
  const double b = static_cast<double>(aPagar) / potPrevio;  // apuesta rival / bote
  const double gamma = calcularGamma(st, b, ctx, rg);

  Evaluacion ev = evaluarContraRango(mias, mesa, rivales, gamma, rg.simulaciones);
  const double E = ev.equity;

  // Proyecto: la equity supera con mucho lo que ya vale la mano hoy.
  const bool proyecto = !rio && E - ev.fuerzaAhora >= 0.08 && ev.fuerzaAhora < 0.75;

  // Perfil del rival (EXPERTO): cuánto se retira ante presión.
  double presion = 1.0;    // >1 = se retira mucho (farolear rinde)
  double valorFino = 0.0;  // umbral de valor más bajo contra estaciones de pago
  if (rg.usaPerfiles && ctx.perfiles && !st.ultimoAgresorNombre.empty()) {
    auto it = ctx.perfiles->find(st.ultimoAgresorNombre);
    if (it != ctx.perfiles->end() && it->second.esConfiable() && it->second.vecesRaised >= 4) {
      float ftr = it->second.foldToRaise();
      if (ftr > 0.6f) presion = 1.5;
      else if (ftr < 0.3f) { presion = 0.3; valorFino = 0.03; }
    }
  }

  // ── Nadie ha apostado: apostar o pasar ─────────────────────────────────
  if (aPagar == 0) {
    double umbral = rg.umbralValor - valorFino - (enPosicion ? 0.02 : 0.0) - (pers - 1.0) * 0.06;
    if (rio) umbral += 0.05;
    if (rivales >= 2) umbral += 0.04;

    bool valor = superaUmbral(E, umbral, rg.temp);
    // Retrasar la mano muy fuerte (solo EXPERTO, en el flop, a veces).
    if (valor && rg.usaPerfiles && E >= 0.93 && st.rondaActual == Rondas::FLOP && rivales == 1 &&
        unif() < 0.18) {
      valor = false;
    }
    if (valor && unif() < (rg.ocultaValor ? 0.88 : 0.93)) {
      double f = fraccionApuestaValor(E, st.rondaActual, rg);
      // Control del bote: con una mano que no es muy fuerte no se hace una apuesta que
      // se lleve media pila -- sería la primera de dos que acaban en all-in (con pilas
      // de ~25 ciegas eliminaba a alguien en la primera mano).
      if (f * st.boteTotal >= 0.5 * saldo && E < 0.78) f = std::min(f, 0.33);
      return subirFraccion(st, saldo, 0, f, 0.25, E);
    }

    // Apuesta de continuación: quien subió antes del flop sigue apostando.
    double pApuesta = 0.0;
    if (ctx.fuiAgresorPreflop && st.rondaActual == Rondas::FLOP && rivales == 1 &&
        ctx.numRaisesMiosEnRonda == 0) {
      pApuesta = rg.cbet * (E > 0.3 ? 1.0 : 0.6);
    }
    // Farol y semifarol.
    double pFarol = rg.faroles * pers;
    if (proyecto) pFarol *= 2.2;
    if (enPosicion || st.accionAnteriorFueCheck) pFarol *= 1.4;
    if (rivales >= 2) pFarol *= 0.3;
    if (rio) pFarol = ev.fuerzaAhora < 0.3 ? pFarol * 1.1 : 0.0;
    if (E > 0.55) pFarol = 0.0;  // con mano de valor se apuesta por valor, no de farol
    if (static_cast<double>(saldo) < 0.6 * st.boteTotal) pFarol *= 0.3;  // sin fichas no hay presión
    pFarol *= presion;
    pApuesta = std::max(pApuesta, pFarol);
    if (unif() < std::clamp(pApuesta, 0.0, 0.9)) {
      double f = 0.4;
      if (rg.ocultaValor) {
        if (rg.usaPerfiles) {
          double u = unif();
          f = u < 0.5 ? 0.5 : (u < 0.8 ? 0.66 : 0.85);
        } else {
          f = 0.55;
        }
      }
      return subirFraccion(st, saldo, 0, f, 0.25, E);
    }
    return accion(TipoAccion::CHECK);
  }

  // ── Hay una apuesta que igualar ────────────────────────────────────────
  const double potFinal = static_cast<double>(st.boteTotal + aPagar);
  double requerida = static_cast<double>(aPagar) / potFinal;  // equity mínima para igualar
  // Odds implícitas: con proyecto y fichas detrás se paga algo más.
  if (proyecto && !rio && static_cast<double>(saldo) > 3.0 * aPagar) requerida *= 0.88;
  double margen = rg.margenCall - (pers - 1.0) * 0.05;
  // Jugarse media pila o toda la pila tiene su varianza: se exige más ventaja.
  if (aPagar >= saldo) margen += 0.08;
  else if (2 * aPagar >= saldo) margen += 0.04;

  const bool puedeSubirMas = ctx.numRaisesMiosEnRonda < 2 && st.raisesRivalesEstaMano < 4;

  // Subida por valor.
  if (puedeSubirMas && aPagar < saldo) {
    double umbral = rg.umbralSubida + 0.05 * std::max(0, st.raisesRivalesEstaMano - 1) - (pers - 1.0) * 0.05;
    if (superaUmbral(E, umbral, rg.temp) && unif() < (rg.usaPerfiles ? 0.85 : 0.75)) {
      return subirFraccion(st, saldo, aPagar, E >= 0.88 ? 0.75 : 0.55, 0.5, E);
    }
    // Subida de farol/semifarol: ante apuestas pequeñas (fáciles de mover) y
    // con proyecto o aire; nunca con mano que ya paga.
    if (rg.faroles > 0.05 && E < 0.5 && rivales == 1 &&
        static_cast<double>(saldo) > 1.0 * (aPagar + st.boteTotal)) {
      double p = rg.faroles * pers * (b <= 0.45 ? 1.6 : 0.5);
      if (rg.subeSobrePequenas && b <= 0.45) p *= 1.5;
      if (proyecto) p *= 1.6;
      if (rio) p *= (ev.fuerzaAhora < 0.3 ? 0.6 : 0.0);
      p *= presion;
      if (unif() < std::clamp(p, 0.0, 0.5)) return subirFraccion(st, saldo, aPagar, 0.6, 0.5, E);
    }
  }

  // Igualar o retirarse: la equity contra su rango frente al precio.
  double x = E - requerida - margen;
  // Jugarse media pila o toda la pila exige una mano de verdad, aunque el precio
  // del bote salga a cuenta: sin esto los bots se eliminaban unos a otros con manos
  // medias en la primera mano (con ~25 ciegas de pila, reportado 2026-09-20).
  {
    const bool facil = rg.margenCall < 0.0;  // FACIL paga de más a propósito, pero también se frena
    const double minimoTodo = facil ? 0.55 : 0.66;
    const double minimoMedia = facil ? 0.48 : 0.60;
    if (aPagar >= saldo) x = std::min(x, E - minimoTodo);
    else if (2 * aPagar >= saldo) x = std::min(x, E - minimoMedia);
  }
  // Contra apuestas pequeñas no se abandona todo el rango (defensa mínima).
  if (x < 0 && aPagar < saldo && b <= 0.8 && st.raisesRivalesEstaMano < 3) {
    double mdf = potPrevio / (potPrevio + aPagar);
    double cerca = std::clamp(1.0 - (-x) / 0.25, 0.0, 1.0);
    double pDefiende = std::clamp(mdf * rg.blandura * (0.3 + 0.7 * cerca) * 0.6, 0.0, 0.6);
    if (unif() < pDefiende) return igualar(aPagar, saldo);
  }
  if (superaUmbral(x, 0.0, rg.temp)) return igualar(aPagar, saldo);
  return accion(TipoAccion::FOLD);
}

}  // namespace

// ═════════════════════════════════════════════════════════════════════════════
//  Punto de entrada
// ═════════════════════════════════════════════════════════════════════════════

namespace {

Accion pensarInterno(const GameState& state, const std::vector<Carta>& cartasPropias,
                     const ContextoBot& ctx, const Rasgos& rg) {
  const int saldo = state.miSaldo;
  if (state.rondaActual == Rondas::PREFLOP || state.cartasComunitarias.size() < 3) {
    double ph = DecisionEngine::percentilPreflop(cartasPropias[0], cartasPropias[1]);
    return decidirPreflop(state, ph, saldo, ctx, rg);
  }

  const std::array<int, 2> mias = {DecisionEngine::codificar(cartasPropias[0]),
                                   DecisionEngine::codificar(cartasPropias[1])};
  std::vector<int> mesa;
  mesa.reserve(5);
  for (const Carta& c : state.cartasComunitarias) mesa.push_back(DecisionEngine::codificar(c));
  return decidirPostflop(state, mias, mesa, saldo, ctx, rg);
}

}  // namespace

Accion DecisionEngine::pensar(const GameState& state, const std::vector<Carta>& cartasPropias,
                              const ContextoBot& ctx) {
  const int saldo = state.miSaldo;
  const int aPagar = std::max(0, state.apuestaAIgualar - state.miApuestaEnRonda);
  if (cartasPropias.size() < 2 || saldo <= 0) return igualar(aPagar, saldo);

  const Rasgos rg = rasgosDe(ctx.dificultad);
  Accion a = pensarInterno(state, cartasPropias, ctx, rg);
  // Red de seguridad: retirarse cuando pasar es gratis nunca es lo correcto.
  if (a.tipo == TipoAccion::FOLD && aPagar == 0) return accion(TipoAccion::CHECK);
  return a;
}

Accion DecisionEngine::pensarAccion(const GameState& state, Comportamiento nivel, int saldo,
                                    const std::vector<Carta>& cartasPropias,
                                    int numRaisesMiosEnRonda,
                                    const std::map<std::string, PerfilJugador>* perfiles) {
  GameState st = state;
  if (saldo > 0) st.miSaldo = saldo;
  ContextoBot ctx;
  ctx.dificultad = state.reglas.dificultadBots;
  ctx.nivel = nivel;
  ctx.numRaisesMiosEnRonda = numRaisesMiosEnRonda;
  ctx.perfiles = perfiles;
  return pensar(st, cartasPropias, ctx);
}
