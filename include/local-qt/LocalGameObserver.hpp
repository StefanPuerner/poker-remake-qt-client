/**
 * @file LocalGameObserver.hpp
 * @brief Implementación de IGameObserver para modo offline: emite señales Qt directas.
 */
#pragma once

#include <algorithm>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <ctime>
#include <mutex>
#include <optional>

#include <QObject>
#include <QString>

#include "../GameTypes.hpp"
#include "../HandPredictor.hpp"
#include "../IGameObserver.hpp"
#include "../TimeUtils.hpp"
#include "../net/Serializer.hpp"

/**
 * @brief Implementación de IGameObserver para modo offline (1 proceso, 2 hilos).
 *
 * Equivalente de NetworkObserver sin sockets: en vez de serializar a JSON y
 * hacer broadcast por un fd, emite señales Qt con los MISMOS nombres y
 * firmas que ya usa NetworkClient (ver include/net-qt/NetworkClient.hpp) --
 * así Mesa.qml/Asiento.qml/PanelVoto.qml/Main.qml funcionan sin cambios,
 * solo cambia qué objeto está registrado como "redcliente" (ver
 * docs/plan-modo-offline.md).
 *
 * Deliberadamente MÁS PEQUEÑO que NetworkObserver: nada de multi-cliente
 * (un único humano posible), nada de reconexión (no hay red que perder),
 * nada de cuentas/progresión/logros (Tréboles/Elo/XP NUNCA offline, ver
 * CLAUDE.md Fase 7) -- todo eso vive "fuera del motor" y se resuelve en
 * capas posteriores, no aquí.
 *
 * Construida SIEMPRE en el hilo de la GUI (LocalGameClient::iniciarPartidaLocal(),
 * invocado desde QML) -- sus métodos onXxx() los llama luego el hilo de
 * motor (dentro de Partida::iniciarPartida(), que Partida posee vía
 * unique_ptr tras setObserver()). Emitir una señal Qt desde un hilo
 * distinto al de construcción del objeto es seguro: Qt la encola
 * automáticamente para el hilo receptor (validado en un proyecto Qt
 * aislado antes de escribir esta clase, ver docs/plan-modo-offline.md
 * sección 6) -- por eso esta clase NUNCA debe moverse de hilo
 * (QObject::moveToThread) ni construirse dentro del hilo de motor.
 */
class LocalGameObserver : public QObject, public IGameObserver {
  Q_OBJECT
 public:
  explicit LocalGameObserver(QObject* parent = nullptr) : QObject(parent) {}

  /// Nombre del único humano posible en esta partida -- necesario para
  /// saber a quién van los eventos "para mí" (avisoRecompra, onErrorJugada
  /// no necesita filtrar porque solo hay un humano que puede estar activo).
  void establecerJugadorHumano(const std::string& nombre) { jugadorHumano_ = nombre; }

  /// Regla de la sala (mismo campo que NetworkObserver::setPermitirRecompra()).
  void setPermitirRecompra(bool permitir) { permitirRecompra_ = permitir; }

  /// Regla de la sala (mismo campo que NetworkObserver::setPreguntarExtension()).
  void setPreguntarExtension(bool preguntar) { preguntarExtension_ = preguntar; }

  /// ¿Se acumula XP en esta partida? Solo tiene sentido en una sesión sin
  /// conexión CON cuenta cacheada -- de invitado no hay a quién acreditarlo.
  void setAcumularXp(bool acumular) { xpActivo_ = acumular; }

  // ── Puente bloqueante GUI↔motor: acción de turno ────────────────────────────
  //
  //  JugadorLocalQt::decidirAccion() (hilo de motor) llama notificarMiTurno()
  //  y luego bloquea en esperarAccion(). LocalGameClient::enviarAccion()
  //  (hilo GUI, Q_INVOKABLE llamado desde QML) llama recibirAccion() para
  //  desbloquearlo -- mismo patrón que NetworkPlayer/TU_TURNO, con un
  //  condition_variable en vez de un socket (ver docs/plan-modo-offline.md
  //  sección 2.2).

  /// Llamado por JugadorLocalQt ANTES de bloquear -- notifica a la GUI que
  /// es su turno (equivalente a mandar TU_TURNO). Hilo de motor.
  void notificarMiTurno(int bote, int igualar, int miSaldo, int miApuesta,
                        int timeoutMs, int minSubida, int maxSubida,
                        const QString& c1, const QString& c2,
                        const QString& comboActual, const QString& comboProbable,
                        const QString& comboMaxima) {
    emit esMiTurno(bote, igualar, miSaldo, miApuesta, timeoutMs, minSubida,
                   maxSubida, c1, c2, comboActual, comboProbable, comboMaxima);
  }

  /// Bloquea (hilo de motor) hasta que recibirAccion() entregue una
  /// decisión, o hasta TURNO_TIMEOUT_MS + margen sin respuesta -- mismo
  /// margen de 2s y mismo fallback (check si no hay nada que pagar, fold si
  /// hay) que NetworkPlayer::decidirAccion() (ver NetworkPlayer.cpp).
  Accion esperarAccion(int aPagarParaIgualar) {
    std::unique_lock<std::mutex> lock(mutexAccion_);
    bool llego = cvAccion_.wait_for(
        lock, std::chrono::milliseconds(TURNO_TIMEOUT_MS + 2'000),
        [this] { return accionPendiente_.has_value(); });
    if (!llego) {
      TipoAccion autoAccion =
          (aPagarParaIgualar == 0) ? TipoAccion::CHECK : TipoAccion::FOLD;
      return Accion{autoAccion, 0, true, ""};
    }
    Accion a = *accionPendiente_;
    accionPendiente_.reset();
    return a;
  }

  /// Llamado por LocalGameClient::enviarAccion() (hilo GUI) -- entrega la
  /// decisión y despierta al hilo de motor bloqueado en esperarAccion().
  void recibirAccion(TipoAccion tipo, int cantidad) {
    std::lock_guard<std::mutex> lock(mutexAccion_);
    accionPendiente_ = Accion{tipo, cantidad, true, ""};
    cvAccion_.notify_one();
  }

  // ── Puente bloqueante GUI↔motor: menú de fin de mano ────────────────────────
  //
  //  Con un único humano posible, "votar entre todos" (como hace
  //  NetworkObserver::onMenuFinDeMano(), sondeando N clientes) se reduce a
  //  esperar la decisión de UNO solo -- misma idea, mucho más simple.

  /// Llamado por LocalGameClient::votar()/guardarYSalir()/abandonar()
  /// (hilo GUI). @p opcion: 1=continuar, 2=guardar+salir, 3=salir sin
  /// guardar (mismo contrato que IGameObserver::onMenuFinDeMano()).
  void recibirDecisionMenu(int opcion) {
    std::lock_guard<std::mutex> lock(mutexMenu_);
    decisionMenuPendiente_ = opcion;
    cvMenu_.notify_one();
  }

  // ── Puente bloqueante GUI↔motor: extensión de partida ───────────────────────

  /// Llamado por LocalGameClient::votarExtension() (hilo GUI).
  void recibirVotoExtension(bool siExtender) {
    std::lock_guard<std::mutex> lock(mutexExtension_);
    if (!siExtender) manosExtraPendiente_ = 0;
    quiereExtenderPendiente_ = siExtender;
    cvExtension_.notify_one();
  }

  /// Llamado por LocalGameClient::elegirManosExtra() (hilo GUI) -- solo
  /// tiene efecto si ya se votó que sí (ver onPreguntarExtension()).
  void recibirManosExtra(int cantidad) {
    std::lock_guard<std::mutex> lock(mutexExtension_);
    manosExtraPendiente_ = cantidad;
    cvExtension_.notify_one();
  }

  // ── Puente no bloqueante: recompra ──────────────────────────────────────────

  /// Llamado por LocalGameClient::pedirRecompra() (hilo GUI). Simple flag
  /// atómico -- a diferencia de los de arriba, onComprobarRecompras() nunca
  /// bloquea esperándolo (sondeo, mismo criterio que NetworkObserver).
  void marcarRecompraPedida() { recompraPedida_.store(true); }

  // ── IGameObserver: flujo de mano ─────────────────────────────────────────────

  void onInicioMano(int numMano, int ciegaGrande) override {
    // Mano nueva: la predicción de la mano anterior ya no vale hasta que
    // onCartasPropiasRepartidas() rellene esto de nuevo -- sin esto,
    // enviarComboSiAplica() seguiría usando las cartas de la mano ya
    // terminada durante el breve hueco antes del reparto.
    jugadorHumanoCartas_.clear();
    humanoFoldeoEstaMano_ = false;
    humanoGanoEstaMano_ = false;
    humanoRepartidoEstaMano_ = false;
    emit nuevaMano(numMano, ciegaGrande);
    emit eventoJuego(
        QString("── Mano %1 · Ciega %2/%3 ──")
            .arg(numMano)
            .arg(ciegaGrande / 2)
            .arg(ciegaGrande),
        "separador");
  }

  void onCobroCiegas(const std::string& jPequena, int montoPequena,
                     const std::string& jGrande, int montoGrande) override {
    emit eventoJuego(QString(": ciega pequeña (%1)").arg(montoPequena), "sistema",
                     QString::fromStdString(jPequena));
    emit eventoJuego(QString(": ciega grande (%1)").arg(montoGrande), "sistema",
                     QString::fromStdString(jGrande));
  }

  void onDealerYCiegasAsignados(const std::string& jDealer,
                                const std::string& jPequena,
                                const std::string& jGrande) override {
    dealerNombre_ = jDealer;
    sbNombre_ = jPequena;
    bbNombre_ = jGrande;
  }

  void onRepartoCartasIniciales() override {
    // No-op a propósito -- NetworkClient tampoco hace nada con
    // REPARTO_INICIAL ("Puramente técnico / sin información útil", ver su
    // dispatcher). Las cartas propias llegan por onCartasPropiasRepartidas().
  }

  void onRepartiendoComunitarias(const std::string& faseDesc, int /*numCartas*/) override {
    emit eventoJuego(QString("── %1 ──").arg(QString::fromStdString(faseDesc)), "separador");
  }

  void onCartasReveladas(const std::vector<Carta>& mesa) override {
    emit mesaActualizada(QString::fromStdString(net::ser::cartasToStr(mesa)));
    enviarComboSiAplica(mesa);
  }

  // ── Turno humano ──────────────────────────────────────────────────────────

  void onPreTurnoHumano(const GameState& state, const std::vector<Player*>& jugadores,
                        const std::vector<int>& botes, const std::vector<std::string>& /*historial*/,
                        bool /*supervisor*/, const std::vector<Carta>& /*cartasMesa*/) override {
    emitirEstadoMesa(state, jugadores, botes, -1);
  }

  void onTurnoIniciado(const GameState& state, const std::vector<Player*>& jugadores,
                       const std::vector<int>& botes, const std::vector<std::string>& /*historial*/,
                       const std::vector<Carta>& /*cartasMesa*/, int timeoutMs) override {
    emitirEstadoMesa(state, jugadores, botes, timeoutMs);
    // A diferencia de NetworkObserver: sin comprobarDesconexiones/
    // Reconexiones/ListaEspera -- no hay red que pueda caerse offline.
  }

  void onVerCartasPropias(const std::string& /*nombre*/, const std::vector<Carta>& /*cartas*/) override {
    // No-op, igual que en red (ver NetworkObserver::onVerCartasPropias()).
  }

  void onErrorJugada(const std::string& error) override {
    emit eventoJuego("⚠ " + QString::fromStdString(error), "error");
  }

  // ── Acciones ───────────────────────────────────────────────────────────────

  void onAccionJugador(const std::string& nombre, TipoAccion accion, int cantidad) override {
    QString accionStr = QString::fromStdString(net::ser::accionToStr(accion));
    QString linea = ": " + accionStr;
    if (cantidad > 0) linea += " " + QString::number(cantidad);
    QString tipo = "accion";
    if (accion == TipoAccion::FOLD) tipo = "fold";
    else if (accion == TipoAccion::RAISE || accion == TipoAccion::ALL_IN) tipo = "agresion";
    if (nombre == jugadorHumano_ && accion == TipoAccion::FOLD) humanoFoldeoEstaMano_ = true;
    emit eventoJuego(linea, tipo, QString::fromStdString(nombre));
    emit accionRealizada(QString::fromStdString(nombre), accionStr);
  }

  void onCabeceraResumen() override {
    emit eventoJuego(
        "El resto de la mano la juegan los bots — no quedan humanos activos.",
        "sistema");
  }

  // ── Showdown ───────────────────────────────────────────────────────────────

  void onInicioShowdown(const std::vector<Carta>& cartasMesa) override {
    emit showdownIniciado(QString::fromStdString(net::ser::cartasToStr(cartasMesa)));
  }

  void onEvaluandoBote(int numBote, int cantidad, const std::vector<std::string>& elegibles) override {
    QString linea = numBote == 0
                        ? QString("── Bote principal (%1)").arg(cantidad)
                        : QString("── Side pot %1 (%2)").arg(numBote).arg(cantidad);
    emit eventoJuego(linea, "showdown");
    emit boteEvaluado(numBote, cantidad,
                      QString::fromStdString(net::ser::unirStr(elegibles, ',')));
  }

  void onMuestraCartas(const std::string& nombre, const std::string& combo,
                       const std::vector<Carta>& cartas,
                       const std::vector<Carta>& /*combinacion*/) override {
    // Sin cuentas_ offline: nada de registrarManoMostrada()/logros aquí
    // (Tréboles/logros nunca offline, ver CLAUDE.md Fase 7).
    QString cartasStr = QString::fromStdString(net::ser::cartasToStr(cartas));
    QString comboQ = QString::fromStdString(combo);
    emit eventoJuego(": " + cartasStr + "  " + comboQ, "showdown", QString::fromStdString(nombre));
    emit cartasMostradas(QString::fromStdString(nombre), cartasStr, comboQ);
  }

  void onGanadorBote(const std::string& nombre, int premio, int numBote,
                     const std::string& combo) override {
    QString comboQ = QString::fromStdString(combo);
    emit eventoJuego(QString(": +%1  (%2)").arg(premio).arg(comboQ), "showdown",
                     QString::fromStdString(nombre));
    if (nombre == jugadorHumano_) humanoGanoEstaMano_ = true;
    emit boteGanado(QString::fromStdString(nombre), premio, numBote, comboQ);
  }

  void onJugadoresDerrotados(const std::vector<std::string>& eliminados) override {
    QString lista = QString::fromStdString(net::ser::unirStr(eliminados, ','));
    emit eventoJuego("☠ " + lista + " se ha quedado sin fichas", "error");
    // AVISO_RECOMPRA -- solo aplica si el humano es uno de los eliminados
    // (el único destinatario posible offline, a diferencia del unicast por
    // fd que hace NetworkObserver aquí mismo).
    for (const std::string& n : eliminados) {
      if (n == jugadorHumano_) {
        emit eventoJuego(permitirRecompra_ ? "Te has quedado sin fichas — puedes pedir recompra."
                                            : "Te has quedado sin fichas.",
                         "error");
        emit avisoRecompra(permitirRecompra_);
        break;
      }
    }
  }

  void onGanadorSinShowdown(const std::string& nombre, int bote,
                            const std::string& /*handName*/) override {
    // Sin cuentas_ offline: nada de registrarManoMostrada()/logros aquí,
    // igual que onMuestraCartas().
    emit eventoJuego(QString(": +%1").arg(bote), "showdown", QString::fromStdString(nombre));
    if (nombre == jugadorHumano_) humanoGanoEstaMano_ = true;
    emit ganadorSinShowdown(QString::fromStdString(nombre), bote);
  }

  // ── Fin de sesión / sistema ────────────────────────────────────────────────

  void onPartidaExtendida(int manosExtra, int nuevoObjetivo) override {
    emit eventoJuego(QString("Partida extendida por otras %1 manos").arg(manosExtra), "sistema");
    emit partidaExtendida(manosExtra, nuevoObjetivo);
  }

  void onFinPartidaGuardada(const std::string& archivo) override {
    // Guardar y salir termina la sesión sin pasar por onFinPartida() -- sin
    // esto el XP de las manos ya jugadas se perdía. Sin bono de ganador: la
    // partida no ha terminado, se retoma después.
    volcarXpDePartida(/*ganadorEsHumano=*/false);
    emit partidaGuardada(QString::fromStdString(archivo));
  }

  void onAccionSistema(const std::string& mensaje) override {
    emit eventoJuego(QString::fromStdString(mensaje), "sistema");
  }

  void onErrorSistema(const std::string& categoria, const std::string& mensaje, int /*codigo*/) override {
    emit eventoJuego("⚠ [" + QString::fromStdString(categoria) + "] " +
                         QString::fromStdString(mensaje),
                     "error");
  }

  void onFinPartidaLimiteManos(const PartidaStats& stats) override { emitirFinPartida(stats, true); }
  void onFinPartida(const PartidaStats& stats) override { emitirFinPartida(stats, false); }

  // ── Utilidades: el cliente Qt controla su propia pantalla ───────────────────

  void onBarraCarga(int /*ms*/) override {}
  void onLimpiarPantalla() override {}
  void onPausarYEsperar() override {}

  // ── Consultas con respuesta ──────────────────────────────────────────────────

  int onMenuFinDeMano() override {
    // Mismo punto exacto que NetworkObserver::onMenuFinDeMano(): la mano ya
    // disparó todos sus eventos (showdown/ganadores) pero el motor todavía
    // no ha limpiado nada de cara a la siguiente.
    cerrarXpDeLaMano();
    emit esperandoVoto("Pulsa Enter para continuar a la siguiente mano");
    std::unique_lock<std::mutex> lock(mutexMenu_);
    cvMenu_.wait(lock, [this] { return decisionMenuPendiente_.has_value(); });
    int opcion = *decisionMenuPendiente_;
    decisionMenuPendiente_.reset();
    if (opcion == 1) emit votoConfirmado();
    // Abandonar (3): en red este aviso lo manda el servidor (evento
    // ABANDONASTE) y es lo que saca a QML de la pantalla de Partida. Aquí
    // no hay servidor que lo mande, así que sin esto el motor paraba pero
    // la pantalla se quedaba colgada para siempre. Ver el comentario de
    // la señal en LocalGameClient.
    if (opcion == 3) {
      // Igual que guardar y salir: se sale del bucle sin onFinPartida(). El
      // XP de las manos jugadas se conserva (el umbral antifarm ya filtra a
      // quien solo se retira), sin bono de ganador.
      volcarXpDePartida(/*ganadorEsHumano=*/false);
      emit abandonaste("Abandonaste la partida.");
    }
    return opcion;
  }

  int onPreguntarExtension() override {
    if (!preguntarExtension_) return 0;
    emit esperandoVotoExtension("¿Quieres seguir jugando más allá del límite de manos?");
    {
      std::unique_lock<std::mutex> lock(mutexExtension_);
      cvExtension_.wait(lock, [this] { return quiereExtenderPendiente_.has_value(); });
      bool siExtender = *quiereExtenderPendiente_;
      quiereExtenderPendiente_.reset();
      if (!siExtender) return 0;
    }
    emit elegirManosExtraPedido("¿Cuántas manos más quieres añadir?");
    std::unique_lock<std::mutex> lock(mutexExtension_);
    cvExtension_.wait(lock, [this] { return manosExtraPendiente_.has_value(); });
    int manos = *manosExtraPendiente_;
    manosExtraPendiente_.reset();
    return manos;
  }

  std::string onPedirNombreArchivo() override {
    // Mismo formato que NetworkObserver::onPedirNombreArchivo() (nombres
    // ordenados + fecha) -- aquí "clientes_" no existe, se usa la lista de
    // jugadores humanos real (solo puede haber uno, pero se deja genérico).
    std::vector<std::string> nombres;
    for (Player* p : *jugadoresPartidaParaGuardar_) {
      if (p->esHumano()) nombres.push_back(p->getNombre());
    }
    std::sort(nombres.begin(), nombres.end());
    std::string base = net::ser::unirStr(nombres, '-');
    auto now = std::chrono::system_clock::now();
    std::time_t t = std::chrono::system_clock::to_time_t(now);
    char buf[16];
    struct tm tmBuf {};
    localtimePortable(&t, &tmBuf);
    std::strftime(buf, sizeof(buf), "_%Y%m%d", &tmBuf);
    return base + buf + ".pok";
  }

  /// LocalGameClient lo fija una vez, justo tras construir la Partida --
  /// necesario para onPedirNombreArchivo() (arriba). No poseído.
  void setJugadoresPartida(std::vector<Player*>* jugadores) { jugadoresPartidaParaGuardar_ = jugadores; }

  // ── Hooks opcionales ──────────────────────────────────────────────────────

  std::vector<JugadorSaliente> getJugadoresSalientes() const override { return jugadoresSalientes_; }
  void clearJugadoresSalientes() override { jugadoresSalientes_.clear(); }

  void onActualizarSaldos(const std::vector<Player*>& jugadores) override {
    emit saldosActualizados(QString::fromStdString(net::ser::saldosToStr(jugadores)));
  }

  std::vector<std::string> onComprobarRecompras(const std::vector<Player*>& eliminados,
                                                bool /*esperarUltimaOportunidad*/) override {
    // Simplificación deliberada frente a NetworkObserver: sin espera
    // acotada en "última oportunidad" (esa variante existe en red para no
    // colgar la mesa entera esperando a un jugador remoto concreto -- aquí
    // solo hay un humano posible y su decisión ya viaja por un flag
    // atómico sin bloquear nada; si hace falta un margen real de espera,
    // añadir cuando el flujo de recompra offline se pruebe en vivo).
    if (!recompraPedida_.load()) return {};
    for (Player* p : eliminados) {
      if (p->getNombre() == jugadorHumano_) {
        recompraPedida_.store(false);
        return {jugadorHumano_};
      }
    }
    return {};
  }

  void onCartasPropiasRepartidas(const std::vector<Player*>& jugadores) override {
    for (Player* p : jugadores) {
      if (p->getNombre() != jugadorHumano_) continue;
      const auto& cartas = p->getCartasPropias();
      if (cartas.size() < 2) return;
      jugadorHumanoCartas_ = cartas;
      humanoRepartidoEstaMano_ = true;
      emit misCartasRepartidas(QString::fromStdString(net::ser::cartaToStr(cartas[0])),
                               QString::fromStdString(net::ser::cartaToStr(cartas[1])));
      break;
    }
    // Predicción fresca desde el primer instante de la mano -- mismo
    // motivo que NetworkObserver::onCartasPropiasRepartidas().
    enviarComboSiAplica({});
  }

  void onEstadoActualizado(const std::vector<Player*>& jugadores, const std::vector<int>& botes,
                           const std::vector<Carta>& /*cartasMesa*/, Rondas rondaActual,
                           int apuestaAIgualar) override {
    GameState state;
    state.apuestaAIgualar = apuestaAIgualar;
    state.rondaActual = rondaActual;
    // nombreActual vacío a propósito -- ver el comentario gemelo en
    // NetworkObserver::onEstadoActualizado(): este refresco no implica
    // cambio de turno.
    emitirEstadoMesa(state, jugadores, botes, -1);
  }

 signals:
  // Mismos nombres y firmas que NetworkClient (include/net-qt/NetworkClient.hpp)
  // -- Mesa.qml/Asiento.qml/PanelVoto.qml/Main.qml se conectan a estas señales
  // sin saber si vienen de un NetworkClient o de un LocalGameClient (que
  // relay-conecta cada una de estas 1:1 con las suyas propias, ver
  // LocalGameClient.hpp).
  void nuevaMano(int mano, int ciega);
  void eventoJuego(QString evento, QString tipo = "accion", QString jugador = "");
  void mesaActualizada(QString mesa);
  void estadoMesaActualizado(QString ronda, int bote, QString turno, QString jugadoresStr,
                             int timeoutMs, QString dealer, QString sb, QString bb);
  void esMiTurno(int bote, int igualar, int miSaldo, int miApuesta, int timeoutMs,
                int minSubida, int maxSubida, QString c1, QString c2, QString comboActual,
                QString comboProbable, QString comboMaxima);
  void comboActualizado(QString actual, QString probable, QString maxima);
  void misCartasRepartidas(QString c1, QString c2);
  void accionRealizada(QString jugador, QString accion);
  void showdownIniciado(QString cartasCsv);
  void boteEvaluado(int numBote, int cantidad, QString jugadoresCsv);
  void cartasMostradas(QString jugador, QString cartasCsv, QString combo);
  void boteGanado(QString jugador, int premio, int numBote, QString combo);
  void ganadorSinShowdown(QString jugador, int bote);
  void avisoRecompra(bool puedeRecomprar);
  void esperandoVoto(QString mensaje);
  void votoConfirmado();
  void esperandoVotoExtension(QString mensaje);
  void elegirManosExtraPedido(QString mensaje);
  void partidaExtendida(int manosExtra, int nuevoObjetivoManos);
  void saldosActualizados(QString jugadoresStr);
  void partidaGuardada(QString archivo);
  /// Ver onMenuFinDeMano(): equivalente local del evento ABANDONASTE que
  /// en red manda el servidor.
  void abandonaste(QString mensaje);
  /// XP acumulado en la partida que acaba de terminar (ya con el bono de
  /// ganador y el umbral antifarm aplicados). Lo recoge LocalGameClient
  /// para guardarlo hasta que haya servidor al que entregárselo.
  void xpOfflineGanado(int xp);
  /// Datos crudos de fin de partida -- LocalGameClient los guarda en sus
  /// propias Q_PROPERTY (manosDisputadasFinal/etc) y ES QUIEN emite
  /// estadisticasFinCambiaron()/finDePartida() de verdad hacia QML (mismo
  /// orden que NetworkClient: primero estadísticas, luego finDePartida).
  void estadisticasFinListas(int manosDisputadas, QString mejorMano,
                             QString mejorManoJugador, QString eliminacionesCsv);
  void finDePartida(QString ganador, int saldo, bool porLimite);

 private:
  void emitirEstadoMesa(const GameState& state, const std::vector<Player*>& jugadores,
                        const std::vector<int>& botes, int timeoutMs) {
    std::vector<net::ser::DatosJugadorMesa> datos;
    datos.reserve(jugadores.size());
    for (Player* p : jugadores) {
      // Sin AccountManager offline -- avatar/loadout siempre a su valor
      // por defecto (0/false/""), igual que NetworkObserver cuando
      // cuentas_ es nullptr (ver su comentario en emitirGameState()).
      datos.push_back({p->getNombre(), p->getSaldo(), p->getApuestaAcumuladaMano(),
                       0, false, "", "", "", "", "", "", "", ""});
    }
    int boteTotal = 0;
    for (int b : botes) boteTotal += b;
    if (!state.nombreActual.empty()) jugadorActual_ = state.nombreActual;

    emit estadoMesaActualizado(
        QString::fromStdString(net::ser::rondaToStr(state.rondaActual)), boteTotal,
        QString::fromStdString(jugadorActual_),
        QString::fromStdString(net::ser::jugadoresMesaToStr(datos)), timeoutMs,
        QString::fromStdString(dealerNombre_), QString::fromStdString(sbNombre_),
        QString::fromStdString(bbNombre_));

    enviarComboSiAplica(cartasMesaActual_);
  }

  /// Recalcula y emite la predicción de mano del humano si tiene cartas
  /// repartidas y no es su turno activo (su propia predicción, cuando es
  /// su turno, ya viaja dentro de esMiTurno()) -- mismo criterio que
  /// NetworkObserver::enviarCombosActualizados(), reducido a un único
  /// destinatario posible. jugadorHumano_ vacío (sin humano registrado)
  /// es no-op.
  void enviarComboSiAplica(const std::vector<Carta>& cartasMesa) {
    cartasMesaActual_ = cartasMesa;
    if (jugadorHumano_.empty() || jugadorHumano_ == jugadorActual_) return;
    if (jugadorHumanoCartas_.size() < 2) return;
    auto hi = predecirMano(jugadorHumanoCartas_, cartasMesa);
    emit comboActualizado(QString::fromStdString(hi.actual),
                          QString::fromStdString(hi.probable),
                          QString::fromStdString(hi.maxima));
  }

  /// Cierra la contabilidad de XP de la mano recién terminada -- 20 si el
  /// humano ganó algún bote, 2 si se retiró, 10 si llegó al final sin ganar.
  /// Mismos números que NetworkObserver::finalizarXpDeLaMano().
  void cerrarXpDeLaMano() {
    if (!xpActivo_ || !humanoRepartidoEstaMano_) return;
    if (humanoGanoEstaMano_) {
      xpPartida_ += 20;
      xpUmbralCumplido_ = true;
    } else if (humanoFoldeoEstaMano_) {
      xpPartida_ += 2;
    } else {
      xpPartida_ += 10;
      xpUmbralCumplido_ = true;
    }
    humanoRepartidoEstaMano_ = false;
  }

  /**
   * @brief Cierra la sesión de XP y lo entrega, si procede.
   *
   * Hay que llamarlo en TODOS los finales posibles de una partida, no solo
   * en el normal: guardar-y-salir y abandonar sacan al motor del bucle sin
   * pasar por onFinPartida(), y sin esto el XP de esas manos se perdía
   * (detectado por el smoke test: 2 manos jugadas, guardar y salir, 0 XP).
   *
   * Idempotente: deja el acumulador a cero, así que un final que pase por
   * dos caminos no cuenta dos veces.
   */
  void volcarXpDePartida(bool ganadorEsHumano) {
    cerrarXpDeLaMano();
    if (xpActivo_) {
      int total = xpPartida_;
      // +25% al ganador de la partida, igual que BONO_XP_GANADOR_PARTIDA.
      if (ganadorEsHumano) total += static_cast<int>(total * 0.25);
      // Umbral antifarm: si nunca llegaste al final de una mano sin
      // retirarte, el XP de toda la partida se descarta (mismo criterio que
      // acreditarXpPartida() en el servidor).
      if (!xpUmbralCumplido_) total = 0;
      if (total > 0) emit xpOfflineGanado(total);
    }
    xpPartida_ = 0;
    xpUmbralCumplido_ = false;
  }

  void emitirFinPartida(const PartidaStats& stats, bool porLimite) {
    volcarXpDePartida(stats.ganadorNombre == jugadorHumano_);
    emitirFinPartidaReal(stats, porLimite);
  }

  void emitirFinPartidaReal(const PartidaStats& stats, bool porLimite) {
    QString eliminaciones = QString::fromStdString(net::ser::eliminacionesToStr(stats.historialJugadores));
    emit estadisticasFinListas(stats.manosJugadas, QString::fromStdString(stats.mejorManoNombre),
                               QString::fromStdString(stats.mejorManoJugador), eliminaciones);
    emit finDePartida(QString::fromStdString(stats.ganadorNombre), stats.saldoFinal, porLimite);
  }

  std::string jugadorHumano_;
  // ── XP sin conexión (Fase 7) ─────────────────────────────────────────
  //  Mismas reglas que NetworkObserver::finalizarXpDeLaMano() en el
  //  servidor -- si divergen, el offline daría más o menos XP que el
  //  online por la misma partida: 20 si ganas bote, 2 si te retiras, 10 si
  //  llegas al final sin ganar, +25% al ganador de la partida. Y el mismo
  //  umbral antifarm: si NUNCA llegaste al final de una mano sin
  //  retirarte, el XP de toda la partida se descarta (corta el "entrar,
  //  foldear todo, salir, repetir").
  bool xpActivo_ = false;       ///< Solo se acumula si el llamador lo pide.
  int xpPartida_ = 0;
  bool xpUmbralCumplido_ = false;
  bool humanoFoldeoEstaMano_ = false;
  bool humanoGanoEstaMano_ = false;
  bool humanoRepartidoEstaMano_ = false;
  bool permitirRecompra_ = false;
  bool preguntarExtension_ = true;
  std::string jugadorActual_;
  std::string dealerNombre_, sbNombre_, bbNombre_;
  std::vector<Carta> cartasMesaActual_;
  /// Copia de las cartas propias del humano, rellenada por
  /// onCartasPropiasRepartidas() y limpiada en cada onInicioMano() -- ver
  /// enviarComboSiAplica(). Una copia, no un puntero: los Player* que
  /// llegan a cada onXxx() son válidos solo durante esa llamada.
  std::vector<Carta> jugadorHumanoCartas_;
  std::vector<JugadorSaliente> jugadoresSalientes_;
  std::vector<Player*>* jugadoresPartidaParaGuardar_ = nullptr;  ///< No poseído, ver setJugadoresPartida().

  std::mutex mutexAccion_;
  std::condition_variable cvAccion_;
  std::optional<Accion> accionPendiente_;

  std::mutex mutexMenu_;
  std::condition_variable cvMenu_;
  std::optional<int> decisionMenuPendiente_;

  std::mutex mutexExtension_;
  std::condition_variable cvExtension_;
  std::optional<bool> quiereExtenderPendiente_;
  std::optional<int> manosExtraPendiente_;

  std::atomic<bool> recompraPedida_{false};
};
