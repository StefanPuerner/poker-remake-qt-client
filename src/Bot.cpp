#include "../include/Bot.hpp"

#include <algorithm>
#include <chrono>
#include <random>
#include <thread>

bool Bot::delaySimuladoActivo_ = true;

Bot::Bot(const std::string& nombre, int saldo)
    : Player(nombre, saldo),
      numRaisesMiosEnRonda_(0),
      rondaInterna_(Rondas::PREFLOP),
      saldoAnterior_(saldo) {
  std::random_device rd;
  std::mt19937 gen(rd());
  std::uniform_int_distribution<> dis(0, 2);
  switch (dis(gen)) {
    case 0:  nivel_ = Comportamiento::SEGURO;      break;
    case 1:  nivel_ = Comportamiento::AGRESIVO;    break;
    default: nivel_ = Comportamiento::EQUILIBRADO; break;
  }
}

Bot::Bot(const std::string& nombre, int saldo, Comportamiento nivel)
    : Player(nombre, saldo),
      nivel_(nivel),
      numRaisesMiosEnRonda_(0),
      rondaInterna_(Rondas::PREFLOP),
      saldoAnterior_(saldo) {}

void Bot::actualizarPersonalidad(int saldoPromedioMesa, int raisesEnMesa,
                                  DificultadBots dificultad) {
  // Momentum: cuánto ganó/perdió en la mano que se acaba de jugar. Se calcula
  // y se ancla ANTES de cualquier return para que nunca se pierda una mano.
  int deltaUltimaMano = saldo_ - saldoAnterior_;
  saldoAnterior_ = saldo_;

  if (saldoPromedioMesa <= 0) return;

  // Pesos relativos (no probabilidades aún): partimos de un reparto neutro
  // apoyado en EQUILIBRADO, y cada señal SUMA o RESTA peso a un rasgo en vez
  // de sustituir tablas de porcentajes fijos — así los tres factores (stack,
  // momentum, mesa) se combinan de forma natural en vez de pisarse entre sí.
  double pesoAgresivo = 1.0, pesoSeguro = 1.0, pesoEquilibrado = 1.6;

  // ── 1. Profundidad de stack (push/fold estándar) ────────────────────────
  // Antes: stack corto → sobre todo SEGURO. Eso es al revés de la teoría de
  // push/fold: con pocas fichas, jugar pasivo solo deja que las ciegas te
  // coman sin generar fold equity. Cuanto más corto, más agresivo.
  double prop = static_cast<double>(saldo_) / saldoPromedioMesa;
  if (prop < 0.30) {
    pesoAgresivo += 3.2;  // crítico: casi siempre push/fold
    pesoSeguro   -= 0.8;
  } else if (prop < 0.5) {
    pesoAgresivo += 1.8;
    pesoSeguro   -= 0.5;
  } else if (prop > 1.5) {
    // Líder de fichas: algo más conservador para proteger la ventaja, pero
    // sin descartar aplicar presión — sigue siendo variado.
    pesoSeguro   += 0.9;
    pesoAgresivo += 0.4;
  }

  // ── 2. Momentum: resultado de la mano anterior ──────────────────────────
  // Ganar una mano grande empuja a presionar la racha; perder una grande
  // empuja a proteger lo que queda. Sin esto, la personalidad no tenía
  // memoria de nada y era puro ruido redibujado cada mano.
  double deltaRelativo = static_cast<double>(deltaUltimaMano) / saldoPromedioMesa;
  if (deltaRelativo > 0.15) {
    pesoAgresivo += 1.0;
  } else if (deltaRelativo < -0.15) {
    pesoSeguro += 1.0;
  }

  // ── 3. Composición de la mesa (solo EXPERTO, vía perfiles_) ─────────────
  // EXPERTO ya construye un perfil estadístico de cada rival para las
  // decisiones dentro de la mano; hasta ahora la personalidad lo ignoraba
  // por completo. Un jugador fuerte adapta su "imagen de mesa" a quién tiene
  // enfrente, no solo a su propia pila.
  if (dificultad == DificultadBots::EXPERTO && !perfiles_.empty()) {
    float agrProm = 0.0f, ftrProm = 0.0f, vipProm = 0.0f;
    int n = 0;
    for (const auto& [nombre, perf] : perfiles_) {
      if (perf.esConfiable()) {
        agrProm += perf.agresividad();
        ftrProm += perf.foldToRaise();
        vipProm += perf.VPIP();
        ++n;
      }
    }
    if (n > 0) {
      agrProm /= n; ftrProm /= n; vipProm /= n;
      if (vipProm < 0.30f && ftrProm > 0.55f) {
        // Mesa tight/foldy: hay fold equity de sobra que explotar.
        pesoAgresivo += 1.2;
      } else if (vipProm > 0.55f && ftrProm < 0.35f) {
        // Calling stations: farolear no rinde, mejor ir a valor sin prisa.
        pesoSeguro += 0.6; pesoEquilibrado += 0.6; pesoAgresivo -= 0.3;
      } else if (vipProm > 0.50f && agrProm > 0.55f) {
        // Mesa de LAGs: alta varianza ambiente, conviene jugar más sólido.
        pesoSeguro += 0.8;
      }
    }
  }

  // ── 4. Anti-tilt: mesa ya muy subida, moderar la propia agresividad ─────
  if (dificultad != DificultadBots::FACIL && raisesEnMesa >= 3) {
    pesoAgresivo *= 0.5;
  }

  pesoAgresivo    = std::max(0.05, pesoAgresivo);
  pesoSeguro      = std::max(0.05, pesoSeguro);
  pesoEquilibrado = std::max(0.05, pesoEquilibrado);

  // ── Sorteo ponderado ─────────────────────────────────────────────────────
  // thread_local, no static a secas: con el servidor multi-sala en marcha,
  // cada sala corre en su propio hilo — un generador compartido entre hilos
  // sería una carrera de datos real (mismo motivo que en DecisionEngine.cpp).
  static thread_local std::mt19937 gen(std::random_device{}());
  double total = pesoAgresivo + pesoSeguro + pesoEquilibrado;
  std::uniform_real_distribution<> dis(0.0, total);
  double tirada = dis(gen);

  if (tirada < pesoAgresivo)              nivel_ = Comportamiento::AGRESIVO;
  else if (tirada < pesoAgresivo + pesoSeguro) nivel_ = Comportamiento::SEGURO;
  else                                     nivel_ = Comportamiento::EQUILIBRADO;
}

Accion Bot::decidirAccion(const GameState& state) {
  if (state.rondaActual != rondaInterna_) {
    rondaInterna_ = state.rondaActual;
    numRaisesMiosEnRonda_ = 0;
  }

  const std::map<std::string, PerfilJugador>* perfiles = nullptr;
  if (state.reglas.dificultadBots == DificultadBots::EXPERTO) {
    perfiles = &perfiles_;
  }

  Accion accionElegida = DecisionEngine::pensarAccion(
      state, nivel_, saldo_, cartasPropias_, numRaisesMiosEnRonda_, perfiles);

  if (accionElegida.tipo == TipoAccion::RAISE) {
    numRaisesMiosEnRonda_++;
  }

  // Simular tiempo de reflexión: 1–3 segundos aleatorios.
  // thread_local en vez de std::rand(): std::rand() usa estado global de
  // libc, no seguro si dos salas (hilos) lo llaman a la vez.
  if (delaySimuladoActivo_) {
    static thread_local std::mt19937 genDelay(std::random_device{}());
    int delayMs = 1000 + static_cast<int>(genDelay() % 2001);
    std::this_thread::sleep_for(std::chrono::milliseconds(delayMs));
  }

  return accionElegida;
}

Comportamiento Bot::getNivel() const { return nivel_; }

void Bot::setNivel(Comportamiento nivel) { nivel_ = nivel; }

void Bot::iniciarManoJugador(const std::string& nombre) {
  auto& p = perfiles_[nombre];
  p.manosTotal++;
  p.vpipEstaMano = false;
}

void Bot::registrarAccion(const std::string& nombre, TipoAccion accion,
                           Rondas ronda, bool hayApuesta) {
  auto& p = perfiles_[nombre];

  switch (accion) {
    case TipoAccion::RAISE:
      p.raisesTotal++;
      if (!p.vpipEstaMano) { p.manosVPIP++; p.vpipEstaMano = true; }
      if (ronda == Rondas::PREFLOP) p.preflopRaises++;
      if (hayApuesta) p.vecesRaised++;
      break;
    case TipoAccion::ALL_IN:
      p.raisesTotal++;
      if (!p.vpipEstaMano) { p.manosVPIP++; p.vpipEstaMano = true; }
      if (hayApuesta) p.vecesRaised++;
      break;
    case TipoAccion::CALL:
      p.callsTotal++;
      if (!p.vpipEstaMano) { p.manosVPIP++; p.vpipEstaMano = true; }
      if (hayApuesta) p.vecesRaised++;
      break;
    case TipoAccion::FOLD:
      if (hayApuesta) {
        p.foldsARaise++;
        p.vecesRaised++;
      }
      break;
    default:
      break;
  }
}
