#include "../include/Partida.hpp"

#include <algorithm>
#include <cstddef>
#include <exception>
#include <iostream>
#include <utility>

#include "../include/Bot.hpp"
#include "../include/FileManager.hpp"
#include "../include/Interfaz.hpp"
#include "../include/LocalObserver.hpp"
#include "../include/PathUtils.hpp"
#include "../include/Persona.hpp"

Partida::Partida(const std::vector<std::string>& nombresHumanos, int numBots,
                 int saldoInicial, int manosObjetivo, int valorCiegaGrande,
                 bool supervisor, const ReglasJuego& reglas)
    : dealerIndex_(0),
      ciegaGrande_(valorCiegaGrande),
      ciegaPequena_(valorCiegaGrande / 2),
      apuestaMaximaRonda_(0),
      manoActual_(1),
      objetivoManos_(manosObjetivo),
      faseActual_(Rondas::PREFLOP),
      saldoInicial_(saldoInicial),
      modoSupervisor_(supervisor),
      reglas_(reglas),
      raisesEnEstaMano_(0),
      ultimaAccionRonda_(TipoAccion::CHECK),
      observer_(std::make_unique<LocalObserver>()) {
  for (const std::string& nombre : nombresHumanos) {
    jugadores_.push_back(new Persona(nombre, saldoInicial));
  }
  // Rellenar con Bots
  for (int i = 0; i < numBots; ++i) {
    jugadores_.push_back(new Bot("Bot_" + std::to_string(i + 1), saldoInicial));
  }
  botes_.push_back(Bote());
  mejorManoPartida_.score = -1;
}

Partida::~Partida() {
  for (Player* p : jugadores_) {
    delete p;
  }
  jugadores_.clear();
}

Partida::Partida(std::vector<Player*> jugadores, int manosObjetivo,
                 int ciegaGrande, bool supervisor, const ReglasJuego& reglas)
    : dealerIndex_(0),
      ciegaGrande_(ciegaGrande),
      ciegaPequena_(ciegaGrande / 2),
      apuestaMaximaRonda_(0),
      manoActual_(1),
      objetivoManos_(manosObjetivo),
      faseActual_(Rondas::PREFLOP),
      modoSupervisor_(supervisor),
      reglas_(reglas),
      raisesEnEstaMano_(0),
      ultimaAccionRonda_(TipoAccion::CHECK),
      observer_(std::make_unique<LocalObserver>()) {
  jugadores_ = std::move(jugadores);
  botes_.push_back(Bote());
  mejorManoPartida_.score = -1;
}

Partida::Partida(const PartidaSnapshot& snapshot)
    : dealerIndex_(0),
      ciegaGrande_(snapshot.ciegaGrande),
      ciegaPequena_(snapshot.ciegaGrande / 2),
      apuestaMaximaRonda_(0),
      manoActual_(snapshot.manoActual),
      objetivoManos_(snapshot.objetivoManos),
      faseActual_(Rondas::PREFLOP),
      modoSupervisor_(snapshot.supervisor),
      reglas_(snapshot.reglas),
      raisesEnEstaMano_(0),
      ultimaAccionRonda_(TipoAccion::CHECK),
      observer_(std::make_unique<LocalObserver>()) {
  // Recreamos a los jugadores basados en el archivo
  for (const auto& js : snapshot.jugadores) {
    Player* nuevoJugador = nullptr;
    if (js.esBot) {
      nuevoJugador = new Bot(js.nombre, js.saldo,
                             static_cast<Comportamiento>(js.comportamiento));
    } else {
      nuevoJugador = new Persona(js.nombre, js.saldo);
    }

    // si tiene dinero está ACTIVO, si no, ELIMINADO
    if (js.saldo > 0) {
      nuevoJugador->setEstado(PlayerState::ACTIVO);
    } else {
      nuevoJugador->setEstado(PlayerState::ELIMINADO);
    }

    jugadores_.push_back(nuevoJugador);
  }

  botes_.clear();
  botes_.push_back(Bote());
  mejorManoPartida_.score = -1;
}

void Partida::setArchivoOrigen(const std::string& rutaArchivo) {
  archivoOrigen_ = rutaArchivo;
}

void Partida::setObserver(std::unique_ptr<IGameObserver> obs) {
  observer_ = std::move(obs);
}

void Partida::iniciarPartida() {
  bool continuarJugando = true;
  bool guardar = true;
  // BUCLE DE SESIÓN (Inner Loop)
  while (continuarJugando && manoActual_ <= objetivoManos_) {
    // Recompras (ver IGameObserver::onComprobarRecompras), una vez por
    // mano, justo antes de que limpiarEstadosMano() (primera línea de
    // ejecutarMano()) decida quién entra ACTIVO — si alguien pidió
    // recomprar a tiempo, ya tiene saldo cuando limpiarEstadosMano() mire.
    //
    // Va ANTES de contar jugadoresVivos a propósito: en una mesa de 2, el
    // jugador que acaba de perder todo su saldo cuenta como "no vivo" —
    // si se contara antes de procesar su posible recompra, una partida
    // heads-up terminaría en cuanto alguien llegara a 0, sin darle
    // ocasión real de recomprar.
    procesarRecomprasPendientes();

    int jugadoresVivos = 0;
    for (Player* p : jugadores_) {
      if (p->getSaldo() > 0) jugadoresVivos++;
    }

    if (jugadoresVivos <= 1) break;

    // Nuevos jugadores a mitad de partida — comprobación NO bloqueante
    // (ver IGameObserver::onComprobarNuevosJugadores), una vez por mano,
    // solo si la sala es "abierta tras inicio". Cuenta los asientos de bot
    // libres AHORA MISMO y deja que el observer decida a quién aceptar
    // (hasta ese número) — la sustitución es un simple cambio de puntero
    // en el mismo índice, no toca el tamaño de jugadores_ ni la rotación
    // de dealer/ciegas (que van por índice, no por el puntero).
    if (reglas_.abiertaTrasInicio) {
      // Cualquier asiento de bot es candidato, esté o no ya eliminado (un
      // bot arruinado se queda sentado sin jugar el resto de la partida,
      // no hay recompra para bots) -- el humano nuevo siempre entra con
      // saldoInicial_ fijo (ver conversación: no tiene gracia que empiece
      // con una pila rara), así que el asiento a ceder es el de MENOR
      // saldo. Motivo real (decisión del usuario, no solo cuadrar fichas):
      // un bot acorralado con poca pila ya apenas influye en la partida
      // -- es al que menos se echa en falta, y de paso es también el que
      // menos ficha "destruye" al ser sustituido (un bot ya eliminado, con
      // 0, es el caso ideal: no aporta nada y el impacto es cero).
      int asientosLibres = 0;
      for (Player* p : jugadores_) {
        if (dynamic_cast<Bot*>(p)) ++asientosLibres;
      }
      // Se llama SIEMPRE, aunque asientosLibres sea 0 -- con 0 no sienta a
      // nadie (el bucle de abajo no itera), pero onComprobarNuevosJugadores()
      // igualmente drena la cola de solicitudes pendientes y rechaza con un
      // error a quien esté esperando en vez de dejarlo colgado. Antes, con
      // el "if (asientosLibres > 0)" de guardia, esta llamada se saltaba
      // por completo cuando no había ningún bot al que sustituir -- la
      // única otra vía para atender la cola era intentarSentarNuevosJugadores()
      // (oportunista, solo corre si el poll de onMenuFinDeMano() llega a
      // agotar su timeout de 300ms), que se queda sin ocasión de correr si
      // todos los jugadores votan rápido para continuar -- alguien podía
      // quedarse en "esperando a sentarse" indefinidamente, mano tras mano
      // (bug real reportado).
      auto nuevos = observer_->onComprobarNuevosJugadores(asientosLibres);
      for (Player* nuevo : nuevos) {
        std::size_t mejorIndice = jugadores_.size();
        for (std::size_t i = 0; i < jugadores_.size(); ++i) {
          if (!dynamic_cast<Bot*>(jugadores_[i])) continue;
          if (mejorIndice == jugadores_.size() ||
              jugadores_[i]->getSaldo() < jugadores_[mejorIndice]->getSaldo()) {
            mejorIndice = i;
          }
        }
        if (mejorIndice == jugadores_.size()) {
          delete nuevo;  // no debería pasar: asientosLibres ya limitó cuántos nuevos hay
          continue;
        }
        delete jugadores_[mejorIndice];
        jugadores_[mejorIndice] = nuevo;
      }
      if (!nuevos.empty()) observer_->onActualizarSaldos(jugadores_);
    }

    // EJECUCION DE LA PARTIDA COMO TAL
    ejecutarMano();

    // Auto-save tras cada mano: estado limpio (saldos ya actualizados tras showdown).
    // Nombre fijo si salaId_ está vacío (todo el software actual) — igual
    // que siempre; con id de sala, cada sala tiene su propio autosave para
    // no pisarse con otras salas activas a la vez.
    try {
      std::string rutaAutosave = salaId_.empty()
                                      ? dirDatos() + "autosave.pok"
                                      : dirDatos() + "autosave_" + salaId_ + ".pok";
      FileManager::guardarPartida(generarSnapshot(), rutaAutosave);
    } catch (...) {}  // fallo silencioso — no interrumpe la partida

    // Contar los jugadores y humanos activos
    jugadoresVivos = 0;
    int humanosVivos = 0;
    for (Player* p : jugadores_) {
      if (p->getSaldo() > 0) {
        jugadoresVivos++;
        // esHumano() (no dynamic_cast<Persona*>) -- Persona es solo el
        // humano LOCAL de ncurses; en red los humanos son NetworkPlayer,
        // que dynamic_cast<Persona*> nunca reconoce. Con el cast, esto
        // daba humanosVivos=0 en CUALQUIER partida por red (Qt o ncurses
        // por TCP) -- el bug real por el que onPreguntarExtension() de
        // abajo nunca llegaba a llamarse ahí: la condición "humanosVivos
        // > 0" era siempre falsa, así que la partida terminaba en el
        // límite de manos sin preguntar nunca a nadie.
        if (p->esHumano()) humanosVivos++;
      }
    }

    // Última oportunidad de recompra ANTES de decidir si la partida
    // termina aquí mismo: quien acaba de perder todo su saldo en ESTA
    // mano nunca llega a ver la siguiente vuelta del bucle si el chequeo
    // de abajo rompe primero -- sin esto, procesarRecomprasPendientes()
    // del principio del bucle solo cubre a quien ya llevaba una mano
    // entera esperando, nunca a quien acaba de caer en la mano que
    // decide el final de la partida (el caso típico: mesa heads-up).
    if (jugadoresVivos <= 1) {
      procesarRecomprasPendientes();
      jugadoresVivos = 0;
      humanosVivos = 0;
      for (Player* p : jugadores_) {
        if (p->getSaldo() > 0) {
          jugadoresVivos++;
          if (p->esHumano()) humanosVivos++;
        }
      }
    }

    // 1. Si ocurrió un monopolio, salimos inmediatamente (nadie con quien
    // jugar)
    if (jugadoresVivos <= 1) {
      break;
    }

    // 2. Si completamos las manos objetivo, interceptamos ANTES de salir
    if (manoActual_ > objetivoManos_) {
      if (humanosVivos > 0) {
        // Hay humanos, les preguntamos
        int manosExtra = observer_->onPreguntarExtension();

        if (manosExtra > 0) {
          objetivoManos_ += manosExtra;
          observer_->onPartidaExtendida(manosExtra, objetivoManos_);
          observer_->onBarraCarga(1000);
          observer_->onLimpiarPantalla();
        } else {
          break;  // El jugador escribió 0, quiere terminar. Salimos del bucle.
        }
      } else {
        break;  // No hay humanos vivos para preguntar. Salimos del bucle.
      }
    }

    // Menu de fin de mano
    int opcion = observer_->onMenuFinDeMano();

    procesarJugadoresSalientes();

    if (opcion == 2) {
      // GUARDAR Y SALIR
      std::string nombreArchivo;

      // Comprobamos si la partida ya venía de un archivo guardado
      if (archivoOrigen_.empty()) {
        // Es una partida nueva, le pedimos al usuario que invente un nombre.
        // Con id de sala, se antepone para que dos salas con jugadores de
        // nombre parecido el mismo día no generen el mismo nombre de fichero
        // (onPedirNombreArchivo() no sabe nada de salas, no hace falta tocarlo).
        std::string prefijoSala = salaId_.empty() ? "" : salaId_ + "_";
        nombreArchivo =
            dirDatos() + prefijoSala + observer_->onPedirNombreArchivo();
      } else {
        // usamos la ruta existente para SOBREESCRIBIRLO
        nombreArchivo = archivoOrigen_;
      }
      // Intentamos guardar, si falla, lanzamos error
      try {
        FileManager::guardarPartida(generarSnapshot(), nombreArchivo);
        observer_->onFinPartidaGuardada(nombreArchivo);
        observer_->onAccionSistema("Volviendo al Menu...");
        observer_->onBarraCarga(600);
      } catch (const std::exception& e) {
        observer_->onErrorSistema("GUARDADO", e.what(), 0);
      }
      continuarJugando = false;
    } else if (opcion == 3) {
      // ABANDONAR SIN GUARDAR
      guardar = false;
      continuarJugando = false;
    } else {
      // CONTINUAR JUGANDO (Opción 1)
      // La rotación del dealer ya se realiza al final de ejecutarMano().
    }
  }

  // RESOLUCIÓN FINAL
  int jugadoresVivos = 0;
  for (Player* p : jugadores_) {
    if (p->getSaldo() > 0) {
      jugadoresVivos++;
    }
  }

  if ((manoActual_ > objetivoManos_ || jugadoresVivos <= 1) && guardar) {
    registrarEliminados();

    PartidaStats stats = generarEstadisticas();

    try {
      FileManager::registrarPartidaFinalizada(
          stats, dirDatos() + "historial_general.stats");
      if (objetivoManos_ < manoActual_) {
        observer_->onFinPartidaLimiteManos(stats);
      } else {
        observer_->onFinPartida(stats);
      }
      observer_->onPausarYEsperar();
    } catch (const std::exception& e) {
      observer_->onErrorSistema("HISTORIAL", e.what(), 0);
    }
    if (!archivoOrigen_.empty()) {
      try {
        FileManager::borrarArchivoGuardado(archivoOrigen_);
      } catch (const std::exception& e) {
        observer_->onErrorSistema("FILE_MANAGER", e.what(), 0);
      }
    }
  } else {
    if (!guardar) {
      if (archivoOrigen_.empty()) {
        observer_->onAccionSistema("Volviendo al Menu...");
        observer_->onBarraCarga(400);
      } else {
        observer_->onAccionSistema(
            "Desechando cambios en partida y volviendo al Menu...");
        observer_->onBarraCarga(800);
      }
    }
  }
}

// Salidas: un jugador puede irse VOLUNTARIAMENTE (LEAVE explícito) o ser
// expulsado por timeout de reconexión (60s sin volver) sin haberlo pedido.
// Con rellenarConBots=true, ambos casos dejan sus fichas en la mesa
// controladas por un bot (no se distingue). Con rellenarConBots=false: un
// LEAVE voluntario reparte sus fichas entre el resto, como siempre — pero
// una expulsión INVOLUNTARIA ya NO le toca saldo ni estado: conserva su
// asiento y sus fichas reales tal cual, jugando auto-fold/auto-check
// mientras esté ausente (el motor ya sabe hacerlo, NetworkPlayer::
// decidirAccion() ya tiene ese fallback), para poder reconectar o recargar
// la partida más tarde sin haber perdido el sitio ni el stack (bug real
// reportado: un asiento "desaparecía" del guardado tras un cierre brusco).
// OJO: esto NUNCA aplica a quien pierde por el juego normal (ya está a
// saldo 0 y ELIMINADO por otro camino, PlayerState::ELIMINADO vía
// registrarEliminados/limpiarEstadosMano) — aquí solo entran los que se
// van CON saldo > 0. Extraído a método propio (antes vivía inline dentro
// de iniciarPartida()) para poder testearlo sin conducir una mano entera.
void Partida::procesarJugadoresSalientes() {
  auto salientes = observer_->getJugadoresSalientes();
  observer_->clearJugadoresSalientes();
  bool huboCambioSaldo = false;
  for (const auto& saliente : salientes) {
    for (std::size_t idx = 0; idx < jugadores_.size(); ++idx) {
      Player* p = jugadores_[idx];
      if (p->getNombre() != saliente.nombre || p->getSaldo() <= 0) continue;
      int fichas = p->getSaldo();

      if (!reglas_.rellenarConBots && !saliente.voluntario) {
        // Expulsión por timeout, sala sin relleno de bots: se le
        // conserva el asiento intacto, ver comentario de arriba.
        break;
      }

      if (reglas_.rellenarConBots) {
        // Nombre genérico, NO el del jugador que se fue — si esa
        // persona volviera más tarde a unirse (mesa "abierta tras
        // inicio"), sería raro que "su propio bot" siguiera jugando
        // bajo su nombre. También evita que el historial/chat sigan
        // atribuyéndole jugadas a alguien que ya no está.
        std::string nombreBot;
        for (int n = 1;; ++n) {
          nombreBot = "Bot_" + std::to_string(n);
          bool enUso = false;
          for (Player* q : jugadores_) {
            if (q->getNombre() == nombreBot) { enUso = true; break; }
          }
          if (!enUso) break;
        }
        Bot* reemplazo = new Bot(nombreBot, fichas);
        delete p;
        jugadores_[idx] = reemplazo;
      } else {
        p->descontarSaldo(fichas);  // saldo → 0
        p->setEstado(PlayerState::ELIMINADO);  // inmediato, no esperar limpiarEstadosMano

        // Contar beneficiarios (jugadores con saldo tras el descuento)
        int numBenef = 0;
        for (Player* q : jugadores_)
          if (q->getSaldo() > 0) ++numBenef;

        if (numBenef > 0) {
          int porCabeza = fichas / numBenef;
          int resto = fichas % numBenef;
          int i = 0;
          for (Player* q : jugadores_) {
            if (q->getSaldo() > 0) {
              q->ganarSaldo(porCabeza + (i == 0 ? resto : 0));
              ++i;
            }
          }
        }
      }
      huboCambioSaldo = true;
      break;
    }
  }
  // Notificar saldos actualizados tras la redistribución/sustitución
  if (huboCambioSaldo) {
    observer_->onActualizarSaldos(jugadores_);
  }
}

void Partida::procesarRecomprasPendientes() {
  if (!reglas_.permitirRecompra) return;

  std::vector<Player*> eliminados;
  for (Player* p : jugadores_) {
    if (p->getEstado() == PlayerState::ELIMINADO) eliminados.push_back(p);
  }
  if (eliminados.empty()) return;

  // Si sin ninguna recompra la mesa se queda con 1 o menos jugadores con
  // saldo > 0, esto es la última oportunidad real antes de que la
  // partida termine -- se lo decimos al observer para que esta vez sí
  // espere de verdad un momento (ver comentario en IGameObserver::
  // onComprobarRecompras) en vez del sondeo instantáneo habitual, que
  // nunca le da tiempo físico al cliente recién eliminado a responder.
  int vivosSinRecompra = 0;
  for (Player* p : jugadores_) {
    if (p->getSaldo() > 0) ++vivosSinRecompra;
  }
  bool esUltimaOportunidad = vivosSinRecompra <= 1;

  auto quierenRecomprar =
      observer_->onComprobarRecompras(eliminados, esUltimaOportunidad);
  for (Player* p : eliminados) {
    bool pidioRecompra =
        std::find(quierenRecomprar.begin(), quierenRecomprar.end(),
                  p->getNombre()) != quierenRecomprar.end();
    if (pidioRecompra) p->ganarSaldo(saldoInicial_);
  }
}

void Partida::ejecutarMano() {
  limpiarEstadosMano();

  // Inicializar perfiles de rivales al comienzo de cada mano (solo EXPERTO)
  if (reglas_.dificultadBots == DificultadBots::EXPERTO) {
    for (Player* otro : jugadores_) {
      if (Bot* b = dynamic_cast<Bot*>(otro)) {
        for (Player* p : jugadores_) {
          if (p->getEstado() != PlayerState::ELIMINADO) {
            b->iniciarManoJugador(p->getNombre());
          }
        }
      }
    }
  }

  baraja_.mezclar();

  observer_->onInicioMano(manoActual_, ciegaGrande_);

  cobrarCiegas();
  repartirCartasIniciales();  // Virtual puro

  faseActual_ = Rondas::PREFLOP;
  gestionarRondaDeApuestas();

  // Fases Comunitarias (Flop, Turn, River)
  while (!manoTerminada() && contarJugadoresActivos() > 1) {
    ejecutarFaseComunitaria();  // Virtual puro

    if (faseActual_ == Rondas::PREFLOP)
      faseActual_ = Rondas::FLOP;
    else if (faseActual_ == Rondas::FLOP)
      faseActual_ = Rondas::TURN;
    else if (faseActual_ == Rondas::TURN)
      faseActual_ = Rondas::RIVER;

    gestionarRondaDeApuestas();
  }

  // Resolución de la mano: un showdown de verdad (con reparto por bote y
  // revelado de cartas) solo hace falta si queda más de un jugador con
  // derecho a competir (ACTIVO o ALL_IN — contarJugadoresActivos() ya
  // cuenta así). Si todos se retiraron menos uno, no hay nada que
  // comparar ni cartas que enseñar — repartirBotes() (existía pero nunca
  // se llamaba) le da el bote entero al único que queda, sin showdown.
  if (contarJugadoresActivos() > 1) {
    showdown();
  } else {
    repartirBotes();
  }

  // Cambiar Personalidades BOTS
  int saldoTotalActivos = 0;
  int numVivos = 0;

  for (Player* p : jugadores_) {
    if (p->getSaldo() > 0) {
      saldoTotalActivos += p->getSaldo();
      numVivos++;
    }
  }

  if (numVivos > 1) {
    int saldoPromedio = saldoTotalActivos / numVivos;
    for (Player* p : jugadores_) {
      // Solo a los bots que siguen vivos
      Bot* b = dynamic_cast<Bot*>(p);
      if (b && b->getSaldo() > 0) {
        b->actualizarPersonalidad(saldoPromedio, raisesEnEstaMano_,
                                  reglas_.dificultadBots);
      }
    }
  }

  registrarEliminados();
  rotarDealer();
  manoActual_++;
}

// MOTOR DE APUESTAS

void Partida::cobrarCiegas() {
  int sbIndex = obtenerSiguienteJugadorActivo(dealerIndex_);
  int bbIndex = obtenerSiguienteJugadorActivo(sbIndex);

  observer_->onCobroCiegas(jugadores_[sbIndex]->getNombre(), ciegaPequena_,
                           jugadores_[bbIndex]->getNombre(), ciegaGrande_);
  observer_->onDealerYCiegasAsignados(jugadores_[dealerIndex_]->getNombre(),
                                      jugadores_[sbIndex]->getNombre(),
                                      jugadores_[bbIndex]->getNombre());

  // Aplicar descuentos y gestionar botes
  Accion accionSB = {TipoAccion::CALL, ciegaPequena_, true, ""};
  procesarAccion(jugadores_[sbIndex], accionSB);

  Accion accionBB = {TipoAccion::CALL, ciegaGrande_, true, ""};
  procesarAccion(jugadores_[bbIndex], accionBB);

  apuestaMaximaRonda_ = ciegaGrande_;

  // Poblar la mesa de los clientes ya mismo con los saldos tras las ciegas
  // — sin esto, los asientos se quedan vacíos hasta el primer
  // onTurnoIniciado() de la mano (ver IGameObserver::onEstadoActualizado).
  {
    std::vector<int> botesFrescos;
    for (const auto& b : botes_) botesFrescos.push_back(b.getSaldo());
    observer_->onEstadoActualizado(jugadores_, botesFrescos,
                                   mesa_.getCartasComunitarias(),
                                   faseActual_, apuestaMaximaRonda_);
  }
}

void Partida::gestionarRondaDeApuestas() {
  int idxActual;

  // Determinar quién habla primero
  if (faseActual_ == Rondas::PREFLOP) {
    int sbIdx = obtenerSiguienteJugadorActivo(dealerIndex_);
    int bbIdx = obtenerSiguienteJugadorActivo(sbIdx);
    idxActual = obtenerSiguienteJugadorActivo(bbIdx);  // UTG (Under The Gun)
  } else {
    idxActual =
        obtenerSiguienteJugadorActivo(dealerIndex_);  // La ciega pequeña
  }

  int jugadoresPendientesDeHablar = contarJugadoresActivos();
  // Resetear rastreadores de ronda (los raises de mano se acumulan entre
  // rondas)
  ultimaAccionRonda_ = TipoAccion::CHECK;
  std::vector<std::string> historialRonda;

  // Bucle de apuestas. "contarJugadoresQuePuedenApostar() > 1" es la parte
  // que falta si solo contáramos contarJugadoresActivos(): con varios
  // ALL_IN de calles anteriores en la misma mano, contarJugadoresActivos()
  // se queda en >1 (correcto, hace falta correr el tablero para esos side
  // pots) aunque ya no quede nadie con quien competir por la acción. Sin
  // este segundo chequeo, el único jugador ACTIVO tenía que pulsar "check"
  // en cada calle restante contra rivales que ya estaban all-in a 0 -- bug
  // real reportado en producción. Con el chequeo, el bucle ni se ejecuta:
  // se salta directo a la limpieza de abajo y ejecutarMano() sigue
  // repartiendo calles hasta el showdown, sin pedir ninguna decisión de más.
  while (jugadoresPendientesDeHablar > 0 && contarJugadoresActivos() > 1 &&
         contarJugadoresQuePuedenApostar() > 1) {
    Player* p = jugadores_[idxActual];

    // Solo actúan los que están ACTIVOS
    if (p->getEstado() == PlayerState::ACTIVO) {
      // Construir la fotografía del estado
      GameState state;
      state.cartasComunitarias = mesa_.getCartasComunitarias();
      state.boteTotal = 0;
      for (const auto& bote : botes_) {
        state.boteTotal += bote.getSaldo();
      }
      state.apuestaAIgualar = apuestaMaximaRonda_;
      state.miApuestaEnRonda = p->getApuestaAcumuladaRonda();
      state.miSaldo = p->getSaldo();
      state.numJugadoresActivos = contarJugadoresActivos();
      state.rondaActual = faseActual_;
      state.ciegaGrande = ciegaGrande_;
      state.reglas = reglas_;
      // Nuevos campos para IA mejorada
      state.jugadoresPendientes = std::max(0, jugadoresPendientesDeHablar - 1);
      state.raisesRivalesEstaMano = raisesEnEstaMano_;
      state.accionAnteriorFueCheck = (ultimaAccionRonda_ == TipoAccion::CHECK);
      state.nombreActual = p->getNombre();
      state.ultimoAgresorNombre = ultimoAgresorNombre_;

      std::vector<int> botesSaldos;
      for (const auto& b : botes_) botesSaldos.push_back(b.getSaldo());

      // Notifica el inicio de este turno a TODOS los observadores (humano o
      // bot), a diferencia de onPreTurnoHumano (más abajo) que solo se llama
      // para humanos. Hook opcional, default no-op — hoy solo lo aprovecha
      // NetworkObserver para difundir el estado de la mesa en cada turno.
      observer_->onTurnoIniciado(state, jugadores_, botesSaldos, historialRonda,
                                 mesa_.getCartasComunitarias(), TURNO_TIMEOUT_MS);

      Accion a;
      bool accionCompletada = false;

      // 2. Pedir acción con interceptor visual (Limpiar pantalla + VER_CARTAS)
      do {
        // Si es humano, el observer redibuja la pantalla completa antes de
        // que el jugador decida. En red, esto serializa el estado y lo manda
        // al cliente correspondiente para que lo renderice con ncurses.
        if (p->esHumano()) {
          observer_->onPreTurnoHumano(state, jugadores_, botesSaldos,
                                      historialRonda, modoSupervisor_,
                                      mesa_.getCartasComunitarias());
        }

        a = p->decidirAccion(state);

        // El jugador pidió ver sus cartas sin consumir el turno.
        if (a.tipo == TipoAccion::VER_CARTAS) {
          observer_->onVerCartasPropias(p->getNombre(), p->getCartas());
          continue;
        }

        if (!a.valido && p->esHumano()) {
          observer_->onErrorJugada(a.mensajeError);
          continue;
        }

        accionCompletada = true;
      } while (!accionCompletada);

      // Notificar la acción a todos los observadores.
      // En modo local, Persona no lo necesita (ya visible en pantalla).
      // En modo red, NetworkPlayer también debe broadcastearse a los demás.
      if (!dynamic_cast<Persona*>(p)) {
        observer_->onAccionJugador(p->getNombre(), a.tipo, a.cantidad);
      }
      // historial de ronda
      std::string accionStr = p->getNombre() + " ➜ ";
      switch (a.tipo) {
        case TipoAccion::FOLD:
          accionStr += "FOLD";
          break;
        case TipoAccion::CHECK:
          accionStr += "CHECK";
          break;
        case TipoAccion::CALL:
          accionStr += "CALL (" + std::to_string(a.cantidad) + ")";
          break;
        case TipoAccion::RAISE:
          accionStr += "RAISE (" + std::to_string(a.cantidad) + ")";
          break;
        case TipoAccion::ALL_IN:
          accionStr += "ALL-IN (" + std::to_string(a.cantidad) + ")";
          break;
        default:
          break;
      }
      historialRonda.push_back(accionStr);

      // 3. Procesar el impacto de la acción
      int maxApuestaPrevia = apuestaMaximaRonda_;
      procesarAccion(p, a);

      // Refrescar bote/saldos en el resto de clientes ya mismo — sin esto
      // se quedan con los valores de ANTES de esta acción hasta que
      // empiece el turno del siguiente jugador (ver
      // IGameObserver::onEstadoActualizado). botesSaldos se recalcula
      // aquí porque procesarAccion() puede haber creado un side pot nuevo.
      {
        std::vector<int> botesFrescos;
        for (const auto& b : botes_) botesFrescos.push_back(b.getSaldo());
        observer_->onEstadoActualizado(jugadores_, botesFrescos,
                                       mesa_.getCartasComunitarias(),
                                       faseActual_, apuestaMaximaRonda_);
      }

      // Rastrear raises para range modeling y última acción para river
      if (a.tipo == TipoAccion::RAISE || a.tipo == TipoAccion::ALL_IN) {
        ++raisesEnEstaMano_;
        ultimoAgresorNombre_ = p->getNombre();
      }
      ultimaAccionRonda_ = a.tipo;

      // Actualizar perfiles de rivales en todos los bots (solo EXPERTO)
      if (reglas_.dificultadBots == DificultadBots::EXPERTO) {
        bool hayApuesta = (state.apuestaAIgualar > 0);
        for (Player* otro : jugadores_) {
          if (Bot* b = dynamic_cast<Bot*>(otro)) {
            b->registrarAccion(p->getNombre(), a.tipo,
                               state.rondaActual, hayApuesta);
          }
        }
      }

      // Si el humano acaba de retirarse o ir all-in y ya no quedan humanos
      // activos, mostramos cabecera de "modo espectador" para que quede claro
      // que el resto de la mano la juegan los bots solos.
      if (p->esHumano() && p->getEstado() != PlayerState::ACTIVO) {
        bool quedanHumanosActivos = false;
        for (Player* j : jugadores_) {
          if (j->esHumano() &&
              j->getEstado() == PlayerState::ACTIVO) {
            quedanHumanosActivos = true;
            break;
          }
        }
        if (!quedanHumanosActivos) {
          observer_->onCabeceraResumen();
          observer_->onAccionJugador(p->getNombre(), a.tipo, a.cantidad);
        }
      }

      // 4. Si el jugador subió la apuesta real, se reinicia la cuenta
      if (apuestaMaximaRonda_ > maxApuestaPrevia) {
        jugadoresPendientesDeHablar = contarJugadoresActivos();
      }
    }

    jugadoresPendientesDeHablar--;
    idxActual = obtenerSiguienteJugadorActivo(idxActual);
  }

  // Limpieza de contadores al acabar la fase
  apuestaMaximaRonda_ = 0;
  for (Player* p : jugadores_) {
    p->resetearApuestaRonda();
  }
}

// --- LÓGICA DE BOTES Y SIDE POTS ---

void Partida::procesarAccion(Player* p, const Accion& a) {
  if (a.tipo == TipoAccion::FOLD) {
    p->setEstado(PlayerState::FOLD);
    return;
  }

  int cantidadADescontar = a.cantidad;

  // Seguridad: no puede apostar más de lo que tiene
  if (cantidadADescontar > p->getSaldo()) {
    cantidadADescontar = p->getSaldo();
  }

  p->descontarSaldo(cantidadADescontar);

  // Si se queda a cero, su estado es ALL_IN
  if (p->getSaldo() == 0 && a.tipo != TipoAccion::FOLD) {
    p->setEstado(PlayerState::ALL_IN);
  }

  // Actualizar la meta a igualar en la mesa si este jugador la ha superado
  if (p->getApuestaAcumuladaRonda() > apuestaMaximaRonda_) {
    apuestaMaximaRonda_ = p->getApuestaAcumuladaRonda();
  }

  gestionarSidePots(p, cantidadADescontar);
}

void Partida::gestionarSidePots(Player* p, int cantidad) {
  // 1. Registrar la aportación histórica de este jugador en la mano actual
  contribucionesMano_[p] += cantidad;

  // 2. Destruimos los botes actuales; vamos a recalcular la fotografía exacta
  botes_.clear();

  // 3. Creamos una estructura auxiliar local para no alterar el mapa original
  // durante las restas
  struct AuxJugadorBote {
    Player* player;
    int restante;
    bool esAllIn;
    bool esFold;
  };

  std::vector<AuxJugadorBote> simulacion;
  for (Player* pl : jugadores_) {
    if (contribucionesMano_[pl] > 0) {
      simulacion.push_back({pl, contribucionesMano_[pl],
                            pl->getEstado() == PlayerState::ALL_IN,
                            pl->getEstado() == PlayerState::FOLD});
    }
  }

  // 4. Bucle de Slicing (Corte por niveles)
  while (true) {
    // Encontrar el nivel de corte más bajo provocado por un ALL-IN activo
    int nivelCorte = -1;
    for (const auto& aux : simulacion) {
      if (aux.restante > 0 && aux.esAllIn) {
        if (nivelCorte == -1 || aux.restante < nivelCorte) {
          nivelCorte = aux.restante;
        }
      }
    }

    // Si no hay All-Ins con fichas pendientes, el corte es el máximo dinero que
    // quede de cualquier jugador
    if (nivelCorte == -1) {
      int maxRestante = 0;
      for (const auto& aux : simulacion) {
        if (aux.restante > maxRestante) {
          maxRestante = aux.restante;
        }
      }
      if (maxRestante == 0)
        break;  // Ya hemos repartido todas las fichas de la mesa en botes
      nivelCorte = maxRestante;
    }

    // 5. Crear el bote para este nivel de fichas
    Bote nuevoBote;

    for (auto& aux : simulacion) {
      if (aux.restante > 0) {
        int aportacion = std::min(aux.restante, nivelCorte);

        nuevoBote.agregarSaldo(aportacion);
        aux.restante -= aportacion;

        // Si el jugador aportó dinero a este nivel, no ha foldeado y no está
        // eliminado, es elegible para ganar este bote.
        if (!aux.esFold &&
            aux.player->getEstado() != PlayerState::ELIMINADO) {
          nuevoBote.agregarParticipante(aux.player);
        }
      }
    }

    // Almacenar el bote si contiene dinero
    if (nuevoBote.getSaldo() > 0) {
      botes_.push_back(nuevoBote);
    }
  }
}

// --- SHOWDOWN Y LIMPIEZA ---

void Partida::showdown() {
  observer_->onInicioShowdown(mesa_.getCartasComunitarias());
  faseActual_ = Rondas::SHOWDOWN;

  // Resolver cada bote de forma independiente, de más viejo (principal) a más
  // nuevo (side pots)
  for (size_t b = 0; b < botes_.size(); ++b) {
    Bote& bote = botes_[b];
    const auto& elegibles = bote.getParticipantes();

    if (elegibles.empty()) continue;

    // Filtrar: excluir jugadores que foldearon o fueron eliminados.
    // Los botes se reconstruyen solo cuando hay movimiento de dinero, por lo
    // que un jugador que foldea DESPUÉS de la última apuesta puede quedar en la
    // lista de participantes aunque ya no tenga derecho al bote.
    std::vector<Player*> elegiblesVivos;
    for (Player* p : elegibles) {
      if (p->getEstado() != PlayerState::FOLD &&
          p->getEstado() != PlayerState::ELIMINADO) {
        elegiblesVivos.push_back(p);
      }
    }

    if (elegiblesVivos.empty()) continue;

    std::vector<std::string> nombresElegibles;
    for (Player* p : elegiblesVivos) nombresElegibles.push_back(p->getNombre());
    observer_->onEvaluandoBote(b, bote.getSaldo(), nombresElegibles);

    std::vector<std::pair<Player*, HandResult>> competidores;
    for (Player* p : elegiblesVivos) {
      HandResult hr =
          Analyzer::evaluarMano(p->getCartas(), mesa_.getCartasComunitarias());
      competidores.push_back({p, hr});

      // Siempre mostrar cartas en showdown, aunque sea el único elegible.
      observer_->onMuestraCartas(p->getNombre(), hr.handName,
                                 p->getCartasPropias(), hr.combination);

      // Comprobar si es la mejor mano histórica de la partida
      if (hr.score > mejorManoPartida_.score) {
        mejorManoPartida_ = hr;
        jugadorMejorMano_ = p->getNombre();
      }
    }

    if (competidores.empty()) continue;

    // Ordenar competidores de mejor a peor mano
    std::sort(competidores.begin(), competidores.end(),
              [](const auto& a, const auto& b) { return a.second > b.second; });

    // Encontrar empates en la cima para dividir el bote si es necesario
    std::vector<Player*> ganadoresBote = {competidores[0].first};
    for (size_t i = 1; i < competidores.size(); ++i) {
      if (competidores[i].second == competidores[0].second) {
        ganadoresBote.push_back(competidores[i].first);
      } else {
        break;  // Ya no empatan
      }
    }
    int premioIndividual = bote.getSaldo() / ganadoresBote.size();
    int fichasSobrantes =
        bote.getSaldo() %
        ganadoresBote.size();  // Calculamos el resto de la división

    for (size_t i = 0; i < ganadoresBote.size(); ++i) {
      Player* ganador = ganadoresBote[i];
      int premioFinal = premioIndividual;

      // Si sobran fichas, se las damos al primer ganador del empate
      if (i == 0) {
        premioFinal += fichasSobrantes;
      }

      ganador->ganarSaldo(premioFinal);

      observer_->onGanadorBote(ganador->getNombre(), premioFinal, b,
                               competidores[0].second.handName);
    }

    // Refrescar saldos/bote en el resto de clientes tras pagar este bote —
    // sin esto, el "Bote" del cliente se queda congelado con el valor de
    // justo antes del showdown durante toda la resolución (no hay ningún
    // turno de por medio que dispare un refresco propio). Los botes ya
    // resueltos (índices <= b) se mandan a 0: Bote no lleva su propio
    // contador de "ya pagado", pero el saldo del jugador ya sí lo está.
    {
      std::vector<int> botesFrescos;
      for (size_t i = 0; i < botes_.size(); ++i)
        botesFrescos.push_back(i <= b ? 0 : botes_[i].getSaldo());
      observer_->onEstadoActualizado(jugadores_, botesFrescos,
                                     mesa_.getCartasComunitarias(),
                                     faseActual_, 0);
    }
  }
  std::vector<std::string> listaArruinados;
  for (Player* p : jugadores_) {
    // Si su saldo es 0 y no estaba ya marcado como eliminado de antes
    if (p->getSaldo() <= 0 && p->getEstado() != PlayerState::ELIMINADO) {
      listaArruinados.push_back(p->getNombre());
      p->setEstado(PlayerState::ELIMINADO);
      p->vaciarCartasPropias();
    }
  }
  if (!listaArruinados.empty()) {
    observer_->onJugadoresDerrotados(listaArruinados);
  }
}

void Partida::repartirBotes() {
  // Variante para cuando todos se retiran menos uno
  Player* unicoActivo = nullptr;
  for (Player* p : jugadores_) {
    if (p->getEstado() != PlayerState::FOLD &&
        p->getEstado() != PlayerState::ELIMINADO) {
      unicoActivo = p;
      break;
    }
  }
  if (unicoActivo) {
    int totalBote = 0;
    for (const auto& b : botes_) totalBote += b.getSaldo();
    unicoActivo->ganarSaldo(totalBote);

    // Combinación final del ganador -- solo si la mesa ya tenía las 5
    // cartas comunitarias completas (alguien ganó sin showdown DESPUÉS
    // del río, todos foldearon a la última apuesta). Si todos foldearon
    // antes del río, ejecutarMano() nunca llegó a repartir flop/turn/
    // river -- no hay combinación final real que evaluar, y no se
    // inventan cartas que no se llegaron a jugar. Decisión ya tomada:
    // las estadísticas personales solo cuentan esta mano cuando el board
    // estaba completo de verdad (antes NUNCA contaba, ni siquiera así).
    std::string handName;
    if (mesa_.getCartasComunitarias().size() >= 5) {
      HandResult hr = Analyzer::evaluarMano(unicoActivo->getCartas(),
                                            mesa_.getCartasComunitarias());
      handName = hr.handName;
      if (hr.score > mejorManoPartida_.score) {
        mejorManoPartida_ = hr;
        jugadorMejorMano_ = unicoActivo->getNombre();
      }
    }
    observer_->onGanadorSinShowdown(unicoActivo->getNombre(), totalBote, handName);
  }
}

void Partida::limpiarEstadosMano() {
  mesa_.limpiarMano();
  contribucionesMano_.clear();
  botes_.clear();
  botes_.push_back(Bote());
  apuestaMaximaRonda_ = 0;
  raisesEnEstaMano_ = 0;
  ultimaAccionRonda_ = TipoAccion::CHECK;
  ultimoAgresorNombre_.clear();

  // Todos los jugadores que tengan dinero vuelven a estar activos
  for (Player* p : jugadores_) {
    if (p->getSaldo() > 0) {
      p->setEstado(PlayerState::ACTIVO);
    } else {
      p->setEstado(PlayerState::ELIMINADO);
      p->vaciarCartasPropias();  // limpiar cartas residuales de eliminados
    }
    p->resetearApuestaRonda();
    p->resetearApuestaMano();
  }
}

void Partida::rotarDealer() {
  dealerIndex_ = obtenerSiguienteJugadorActivo(dealerIndex_);
}

// --- AUXILIARES INTERNOS ---

int Partida::obtenerSiguienteJugadorActivo(int indexActual) const {
  int n = jugadores_.size();
  for (int i = 1; i <= n; ++i) {
    int nextIdx = (indexActual + i) % n;
    // Se considera elegible para hablar a alguien que no se haya retirado
    if (jugadores_[nextIdx]->getEstado() != PlayerState::FOLD &&
        jugadores_[nextIdx]->getEstado() != PlayerState::ELIMINADO) {
      return nextIdx;
    }
  }
  return indexActual;  // Fallback
}

int Partida::contarJugadoresActivos() const {
  int count = 0;
  for (Player* p : jugadores_) {
    // En el juego un All-In cuenta como activo porque tiene derecho a competir
    // por la mesa
    if (p->getEstado() != PlayerState::FOLD &&
        p->getEstado() != PlayerState::ELIMINADO) {
      count++;
    }
  }
  return count;
}

// A diferencia de contarJugadoresActivos() (que cuenta también los ALL_IN,
// porque siguen compitiendo por el bote), esto cuenta solo a quien todavía
// puede TOMAR una decisión real de apuesta. La distinción importa en
// gestionarRondaDeApuestas(): con varios ALL_IN de manos anteriores en la
// misma mano, contarJugadoresActivos() se queda en >1 (correcto, hace
// falta correr el tablero para resolver esos side pots), pero si solo
// queda un jugador en PlayerState::ACTIVO no hay nadie con quien compita
// por la acción -- pedirle "check" en cada calle restante no es una
// decisión real.
int Partida::contarJugadoresQuePuedenApostar() const {
  int count = 0;
  for (Player* p : jugadores_) {
    if (p->getEstado() == PlayerState::ACTIVO) count++;
  }
  return count;
}

// GENERAR SNAPSHOT (GUARDAR PARTIDA)
PartidaSnapshot Partida::generarSnapshot() const {
  PartidaSnapshot snap;
  snap.manoActual = manoActual_;
  snap.ciegaGrande = ciegaGrande_;
  snap.objetivoManos = objetivoManos_;
  snap.reglas = reglas_;
  snap.supervisor = modoSupervisor_;
  snap.hostNombre = hostNombre_;
  snap.salaPublica = salaPublica_;
  snap.salaCodigo = salaCodigo_;

  for (Player* p : jugadores_) {
    JugadorSnapshot js;
    js.nombre = p->getNombre();
    js.saldo = p->getSaldo();
    js.estado = p->getEstado();
    js.accountId = p->getAccountId();

    // Usamos dynamic_cast para saber si el puntero genérico es en realidad un
    // Bot
    Bot* botPtr = dynamic_cast<Bot*>(p);
    if (botPtr) {
      js.esBot = true;
      js.comportamiento = static_cast<int>(botPtr->getNivel());
    } else {
      js.esBot = false;
      js.comportamiento = 0;
    }
    snap.jugadores.push_back(js);
  }
  return snap;
}

PartidaStats Partida::generarEstadisticas() const {
  PartidaStats stats;
  stats.manosJugadas =
      manoActual_ - 1;  // La manoActual sumó 1 al terminar el último bucle

  // Encontrar al ganador (quien tenga más saldo, asumiendo que los demás están
  // a 0, o el que va ganando si la partida se cortó por límite de manos)
  Player* ganador = jugadores_[0];

  for (Player* p : jugadores_) {
    if (p->getSaldo() > ganador->getSaldo()) {
      ganador = p;
    }

    // Registrar qué le pasó a este jugador
    JugadorFinStats jfs;
    jfs.nombre = p->getNombre();
    jfs.accountId = p->getAccountId();
    jfs.saldoFinal = p->getSaldo();

    auto it = eliminaciones_.find(p->getNombre());
    if (it != eliminaciones_.end()) {
      jfs.manoEliminacion = it->second;  // Perdió en esta mano
    } else {
      jfs.manoEliminacion = "X";  // Sobrevivió hasta el final
    }
    stats.historialJugadores.push_back(jfs);
  }

  stats.ganadorNombre = ganador->getNombre();
  stats.saldoFinal = ganador->getSaldo();
  stats.saldoInicial = saldoInicial_;

  if (mejorManoPartida_.score > 0) {
    stats.mejorManoNombre = mejorManoPartida_.handName;
    stats.mejorManoJugador = jugadorMejorMano_;
  } else {
    stats.mejorManoNombre = "Ninguna (solo fold)";
    stats.mejorManoJugador = "N/A";
  }

  return stats;
}

void Partida::registrarEliminados() {
  for (Player* p : jugadores_) {
    // Si el jugador está sin blanca y aún no estaba en el mapa de eliminados
    if (p->getSaldo() == 0 &&
        eliminaciones_.find(p->getNombre()) == eliminaciones_.end()) {
      eliminaciones_[p->getNombre()] = std::to_string(manoActual_);
    }
  }
}