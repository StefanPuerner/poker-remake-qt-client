/**
 * @file LocalGameClient.hpp
 * @brief Contraparte offline de NetworkClient: partida local sin sockets, mismo API QML.
 */
#pragma once

#include <memory>
#include <thread>

#include <QDir>
#include <QFileInfo>
#include <QObject>
#include <QSettings>
#include <QStandardPaths>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

#include "../Bot.hpp"
#include "../FileManager.hpp"
#include "../TexasHoldem.hpp"
#include "../net/Serializer.hpp"
#include "JugadorLocalQt.hpp"
#include "LocalGameObserver.hpp"

/**
 * @brief Contraparte offline de NetworkClient -- se registra como
 * "redcliente" en el contexto QML al elegir "jugar offline" en vez de
 * NetworkClient, con el MISMO API invocable (mismos nombres/firmas de
 * Q_INVOKABLE y señales) para que Mesa.qml/Asiento.qml/PanelVoto.qml/
 * Main.qml funcionen sin cambios (ver docs/plan-modo-offline.md).
 *
 * Vive en el hilo de la GUI, igual que NetworkClient. Posee el hilo de
 * motor (std::thread, un TexasHoldem real corriendo iniciarPartida() de
 * forma bloqueante ahí, igual que hace el servidor hoy pero sin sockets de
 * por medio) y un LocalGameObserver -- construido aquí, en el hilo GUI,
 * pero cuya propiedad real pasa a Partida (Partida::setObserver() toma un
 * unique_ptr); observador_ es una copia NO propietaria de ese puntero,
 * válida solo mientras el hilo de motor sigue vivo (ver limpiarSiTerminado()).
 *
 * ⚠️ Simplificación deliberada de este primer corte (validar el caso
 * mínimo 1 humano + N bots, ver CLAUDE.md Fase 7): un único LocalGameClient
 * solo soporta UNA partida local a la vez -- iniciar otra antes de que la
 * anterior termine espera (join()) a que la vieja acabe primero. Suficiente
 * para validar la arquitectura; revisar si hace falta más flexibilidad
 * cuando se construya el flujo real de "jugar otra vez" / Torneos Solitario.
 */
class LocalGameClient : public QObject {
  Q_OBJECT
  Q_PROPERTY(int manosDisputadasFinal READ manosDisputadasFinal NOTIFY estadisticasFinCambiaron)
  Q_PROPERTY(QString mejorManoFinal READ mejorManoFinal NOTIFY estadisticasFinCambiaron)
  Q_PROPERTY(QString mejorManoJugadorFinal READ mejorManoJugadorFinal NOTIFY estadisticasFinCambiaron)
  Q_PROPERTY(QString eliminacionesFinalCsv READ eliminacionesFinalCsv NOTIFY estadisticasFinCambiaron)
  // ── Identidad cacheada ────────────────────────────────────────────────────
  //  Estas tres NO son "de partida": son la copia local de lo último que
  //  contó el servidor sobre la cuenta propia. Existen por DOS motivos a la
  //  vez, y conviene tener los dos presentes antes de tocarlas:
  //
  //   1. Son lo que la Fase 7 llama "Cuenta en solo-lectura con datos
  //      cacheados" -- sin conexión, Perfil/Progreso siguen mostrando tu
  //      nivel, XP y cosméticos reales en vez de una pantalla vacía.
  //   2. Sin ellas, reasignar "redcliente" a este objeto rompía ~40 bindings
  //      VIVOS de Main.qml/PopupPerfilJugador.qml del estilo
  //      "redcliente.estadisticasCuenta.xpTotal" o
  //      "redcliente.loadoutMarco.textura": al re-evaluarse contra un objeto
  //      sin esas propiedades daban "TypeError: Cannot read property 'X' of
  //      undefined", uno por binding, en silencio por consola (no rompen la
  //      pantalla, solo ensucian). Mismos NOMBRES y misma señal NOTIFY que
  //      en NetworkClient a propósito -- ver docs/plan-modo-offline.md.
  //
  //  perfilJugador (perfil de OTRA cuenta) se queda siempre vacío: offline
  //  no hay a quién consultar. Existe solo para que el binding de
  //  PopupPerfilJugador.qml no reviente al reasignar redcliente.
  Q_PROPERTY(QVariantMap estadisticasCuenta READ estadisticasCuenta NOTIFY estadisticasCuentaCambiaron)
  Q_PROPERTY(QVariantMap loadoutMarco READ loadoutMarco NOTIFY loadoutMarcoCambiaron)
  Q_PROPERTY(QVariantMap perfilJugador READ perfilJugador NOTIFY perfilJugadorCambiaron)

 public:
  explicit LocalGameClient(QObject* parent = nullptr) : QObject(parent) {
    // Lo último que se supo de la cuenta en una ejecución anterior -- así
    // un arranque en frío SIN servidor ya tiene identidad que mostrar, sin
    // esperar a hablar con nadie.
    QSettings ajustes;
    estadisticasCuenta_ = ajustes.value("offline/estadisticasCuenta").toMap();
    loadoutMarco_ = ajustes.value("offline/loadoutMarco").toMap();
    usernameCacheado_ = ajustes.value("offline/username").toString();
    logrosCacheados_ = ajustes.value("offline/logros").toList();
    tiendaCacheada_ = ajustes.value("offline/tienda").toList();
    xpOfflinePendiente_ = ajustes.value("offline/xpPendiente").toInt();
  }

  ~LocalGameClient() override {
    if (hiloMotor_.joinable()) hiloMotor_.join();
  }

  int manosDisputadasFinal() const { return manosDisputadasFinal_; }
  QString mejorManoFinal() const { return mejorManoFinal_; }
  QString mejorManoJugadorFinal() const { return mejorManoJugadorFinal_; }
  QString eliminacionesFinalCsv() const { return eliminacionesFinalCsv_; }

  QVariantMap estadisticasCuenta() const { return estadisticasCuenta_; }
  QVariantMap loadoutMarco() const { return loadoutMarco_; }
  QVariantMap perfilJugador() const { return {}; }

  /// Nombre de cuenta de la última sesión con servidor ("" si nunca hubo).
  /// Lo usa Inicio para ofrecer "Jugar sin conexión" con identidad real en
  /// vez de un invitado anónimo.
  Q_INVOKABLE QString usernameCacheado() const { return usernameCacheado_; }

  /// ¿Hay una identidad cacheada utilizable sin servidor? Main.qml decide
  /// con esto si Inicio puede ofrecer "Jugar sin conexión" con tu cuenta.
  Q_INVOKABLE bool hayIdentidadCacheada() const { return !usernameCacheado_.isEmpty(); }

  // ── XP ganado sin conexión (Fase 7) ──────────────────────────────────────
  //  Se acumula aquí, se persiste en QSettings y se entrega al servidor en
  //  la próxima sesión con conexión. El servidor NO se lo cree tal cual:
  //  acota lo aceptado al tiempo real transcurrido (ver
  //  AccountManager::sincronizarXpOffline()). Por eso al confirmar hay que
  //  descontar lo ACREDITADO, no lo reclamado.

  /// XP pendiente de entregar al servidor.
  Q_INVOKABLE int xpOfflinePendiente() const { return xpOfflinePendiente_; }

  /// Lo llama QML cuando el servidor confirma cuánto acreditó de verdad.
  /// Se descuenta lo acreditado; si el servidor recortó, el resto se
  /// descarta a propósito en vez de quedarse acumulando para siempre (el
  /// tope existe justo para que no se pueda "ahorrar" XP inventado).
  Q_INVOKABLE void confirmarXpOfflineSincronizado(int acreditado) {
    (void)acreditado;
    xpOfflinePendiente_ = 0;
    QSettings().setValue("offline/xpPendiente", 0);
    emit xpOfflinePendienteCambio();
  }

  /// ¿Debe esta sesión acumular XP? Solo con cuenta cacheada -- de invitado
  /// no hay a quién acreditárselo. Lo fija QML en entrarSinConexion().
  Q_INVOKABLE void setAcumularXpOffline(bool acumular) { acumularXpOffline_ = acumular; }

  /**
   * @brief Vuelve a anunciar la identidad cacheada, sin cambiarla.
   *
   * Hace falta al ENTRAR en modo local. Main.qml no pinta el perfil
   * leyendo el mapa directamente: dentro de su handler
   * onEstadisticasCuentaCambiaron() lo copia a una veintena de
   * propiedades suyas (statsPartidasGanadas, statsTieneMarcoBasico...) y
   * son ESAS las que pinta. Como la caché se carga en el constructor de
   * esta clase, sin volver a emitir la señal ese handler no corre nunca
   * en una sesión offline y esas propiedades se quedan a cero aunque el
   * mapa esté lleno -- bug real: el marco de Hierro ya conseguido
   * aparecía como no conseguido sin conexión.
   *
   * Los bindings directos (redcliente.loadoutMarco.textura y compañía) sí
   * funcionaban solos, porque se re-evalúan al reasignar redcliente -- de
   * ahí que el fallo se viera solo en la mitad de la pantalla.
   */
  void reemitirIdentidad() {
    emit estadisticasCuentaCambiaron();
    emit loadoutMarcoCambiaron();
    // Logros y catálogo de tienda no son Q_PROPERTY: viajan COMO ARGUMENTO
    // de su señal, así que la única forma de que QML los recupere es
    // volver a emitirlas con lo cacheado. Sin esto, la pestaña Logros
    // (accesible sin conexión) salía vacía, y los títulos no se podían
    // resolver a nombre/rareza (eso sale del catálogo).
    if (!logrosCacheados_.isEmpty()) emit logrosActualizados(logrosCacheados_);
    if (!tiendaCacheada_.isEmpty()) emit tiendaActualizada(tiendaCacheada_);
  }

  /// Guarda (memoria + disco) los logros y el catálogo de tienda que acaba
  /// de mandar el servidor -- lo llama ModoJuegoCoordinador, igual que
  /// cachearIdentidad().
  void cachearLogros(const QVariantList& logros) {
    if (logros.isEmpty()) return;
    logrosCacheados_ = logros;
    QSettings().setValue("offline/logros", logrosCacheados_);
  }
  void cachearTienda(const QVariantList& tienda) {
    if (tienda.isEmpty()) return;
    tiendaCacheada_ = tienda;
    QSettings().setValue("offline/tienda", tiendaCacheada_);
  }

  /// Borra la identidad cacheada de memoria (el borrado en disco lo hace
  /// ModoJuegoCoordinador, que es quien decide cuándo -- al cerrar sesión).
  void olvidarIdentidadCacheada() {
    usernameCacheado_.clear();
    estadisticasCuenta_.clear();
    loadoutMarco_.clear();
    logrosCacheados_.clear();
    tiendaCacheada_.clear();
    emit estadisticasCuentaCambiaron();
    emit loadoutMarcoCambiaron();
  }

  /**
   * @brief Guarda (memoria + disco) lo último que contó el servidor.
   *
   * Lo llama ModoJuegoCoordinador cada vez que NetworkClient recibe datos
   * frescos de la cuenta -- ni QML ni NetworkClient saben que esto existe,
   * así no hay ningún camino por el que alguien "se olvide" de cachear.
   */
  void cachearIdentidad(const QString& username, const QVariantMap& estadisticas,
                        const QVariantMap& loadout) {
    QSettings ajustes;
    if (!username.isEmpty() && username != usernameCacheado_) {
      usernameCacheado_ = username;
      ajustes.setValue("offline/username", usernameCacheado_);
    }
    if (!estadisticas.isEmpty()) {
      estadisticasCuenta_ = estadisticas;
      ajustes.setValue("offline/estadisticasCuenta", estadisticasCuenta_);
      emit estadisticasCuentaCambiaron();
    }
    if (!loadout.isEmpty()) {
      loadoutMarco_ = loadout;
      ajustes.setValue("offline/loadoutMarco", loadoutMarco_);
      emit loadoutMarcoCambiaron();
    }
  }

  /**
   * @brief Arranca una partida local nueva (motor en su propio hilo).
   *
   * Mismos nombres/orden de parámetros que NetworkClient::crearSala() donde
   * aplican (ver su comentario) -- sin host/puerto/nombreSala/publica/
   * tamanoSala/rellenarConBots/abiertaTrasInicio (conceptos de sala en red
   * sin sentido en un proceso único), con @p numBots añadido en su lugar.
   * @param dificultadBots 0=FACIL, 1=NORMAL, 2=EXPERTO (mismo orden que
   * DificultadBots, ver GameTypes.hpp).
   */
  Q_INVOKABLE void iniciarPartidaLocal(const QString& nombre, int numBots, int numManos,
                                       int ciegaGrande, int saldo, int tipoLimite,
                                       bool aplicarMinRaise, int monteFijo, int dificultadBots,
                                       bool permitirRecompra, bool preguntarExtension) {
    // Si una partida anterior de este mismo LocalGameClient no se ha
    // limpiado todavía, esperar a que termine antes de arrancar la nueva
    // -- ver el comentario de la clase sobre esta simplificación.
    if (hiloMotor_.joinable()) hiloMotor_.join();

    std::string nombreStd = nombre.toStdString();

    // Construido en ESTE hilo (GUI) a propósito -- ver el comentario de la
    // clase y docs/plan-modo-offline.md sección 6: un QObject emite señales
    // de forma segura desde cualquier hilo hacia el suyo propio, pero solo
    // si nació en el hilo receptor.
    auto observadorOwned = std::make_unique<LocalGameObserver>();
    observador_ = observadorOwned.get();
    observador_->establecerJugadorHumano(nombreStd);
    observador_->setPermitirRecompra(permitirRecompra);
    observador_->setPreguntarExtension(preguntarExtension);
    observador_->setAcumularXp(acumularXpOffline_);
    conectarSenales();

    ReglasJuego reglas;
    reglas.tipoLimite = static_cast<TipoLimite>(tipoLimite);
    reglas.aplicarMinRaise = aplicarMinRaise;
    reglas.monteFijo = monteFijo;
    reglas.dificultadBots = static_cast<DificultadBots>(dificultadBots);
    reglas.permitirRecompra = permitirRecompra;

    std::vector<Player*> jugadores;
    jugadores.reserve(1 + numBots);
    jugadores.push_back(new JugadorLocalQt(nombreStd, saldo, observador_));
    for (int i = 0; i < numBots; ++i) {
      jugadores.push_back(new Bot("Bot" + std::to_string(i + 1), saldo));
    }

    hiloMotor_ = std::thread([this, jugadores, numManos, ciegaGrande, reglas, saldo,
                              obs = std::move(observadorOwned)]() mutable {
      TexasHoldem partida(jugadores, numManos, ciegaGrande, /*supervisor=*/false, reglas);
      partida.setSaldoInicial(saldo);
      partida.setCarpetaDatos(carpetaGuardadoLocal().toStdString());
      obs->setJugadoresPartida(&partida.jugadoresMutable());
      partida.setObserver(std::move(obs));
      partida.iniciarPartida();
      // Al volver aquí, iniciarPartida() ya llamó onFinPartida()/
      // onFinPartidaLimiteManos() (o el humano abandonó/guardó, ver
      // onMenuFinDeMano()) -- la partida (y con ella, su LocalGameObserver
      // poseído vía unique_ptr) están a punto de destruirse al salir de
      // este scope. partidaActiva_ se limpia DESPUÉS de que eso ya haya
      // pasado del todo.
      partidaActiva_.store(false);
    });
    partidaActiva_.store(true);

    // Mismo campo/orden que NetworkClient (ver su dispatcher, evento
    // PARTIDA_INICIADA) -- es lo que hace que Main.qml haga
    // "pantalla = 'Partida'" y empiece a mostrar Mesa.qml. A diferencia
    // de la red, aquí no hace falta esperar a que "llegue" nada: la
    // partida ya está construida y el hilo de motor arrancado, así que
    // se emite de inmediato. rellenarConBots siempre false -- no hay
    // sala en la que puedan entrar jugadores de red a mitad de partida.
    emit partidaIniciada(numManos, tipoLimite, permitirRecompra, /*rellenarConBots=*/false,
                         preguntarExtension, nombre);
  }

  // ── Resto del API de NetworkClient: no-ops ────────────────────────────────
  //
  //  Todo lo que sigue existe SOLO para que "redcliente.loQueSea(...)" nunca
  //  sea un TypeError mientras redcliente apunta aquí. No son olvidos ni
  //  deuda: son operaciones que por definición necesitan servidor (cuentas,
  //  salas de red, social, tienda, ranking), y offline la respuesta correcta
  //  es "no pasa nada", no "revienta".
  //
  //  El motivo de cubrir el API ENTERO y no solo lo que hoy se puede tocar
  //  sin conexión: Main.qml comparte los mismos handlers y pantallas entre
  //  los dos modos, así que basta con que alguien añada mañana una llamada
  //  en una pantalla que resulte estar accesible offline para reintroducir
  //  el bug -- uno silencioso, que solo se ve mirando la consola. Con el
  //  API completo cubierto eso ya no puede pasar. Cualquier método nuevo en
  //  NetworkClient que QML pueda llamar debería añadirse también aquí.
  //
  //  Consecuencia asumida: alguna acción sin sentido offline (p. ej.
  //  equipar un cosmético desde Cuenta > Personalizar) simplemente no hace
  //  nada en vez de avisar. Aceptable de momento; si molesta, el arreglo es
  //  ocultar/deshabilitar esos controles con "sesionOffline" en QML, no
  //  quitar el stub.
  Q_INVOKABLE void conectarPresencia(const QString&, quint16) {}
  Q_INVOKABLE void refrescarSalas(const QString&, quint16) {}
  Q_INVOKABLE void comprobarConexion(const QString&, quint16) {}
  Q_INVOKABLE QVariantMap intentarRecuperarSesion(const QString&, quint16) { return {}; }
  // Cuentas
  Q_INVOKABLE void iniciarSesion(const QString&, quint16, QString, QString) {}
  Q_INVOKABLE void iniciarSesionConToken(const QString&, quint16, QString) {}
  Q_INVOKABLE void registrar(const QString&, quint16, QString, QString) {}
  Q_INVOKABLE void cerrarSesion(const QString&, quint16, QString) {}
  Q_INVOKABLE void cambiarNombreUsuario(const QString&, quint16, QString, QString) {}
  Q_INVOKABLE void cambiarPassword(const QString&, quint16, QString, QString, QString) {}
  // Progresión / cuenta propia -- los datos que QML pinta salen de las
  // Q_PROPERTY cacheadas de arriba, así que "consultar" no tiene nada que
  // hacer: ya están puestas.
  Q_INVOKABLE void consultarEstadisticas(const QString&, quint16, QString) {}
  Q_INVOKABLE void consultarLoadout(const QString&, quint16, QString) {}
  Q_INVOKABLE void consultarLogros(const QString&, quint16, QString) {}
  Q_INVOKABLE void consultarTienda(const QString&, quint16, QString) {}
  Q_INVOKABLE void exportarEstadisticas(const QString&, quint16, QString) {}
  Q_INVOKABLE void sincronizarXpOffline(const QString&, quint16, QString, int) {}
  Q_INVOKABLE void comprarObjeto(const QString&, quint16, QString, QString) {}
  Q_INVOKABLE void equiparObjeto(const QString&, quint16, QString, QString, QString) {}
  // Ranking / social / perfiles ajenos
  Q_INVOKABLE void consultarRanking(const QString&, quint16) {}
  Q_INVOKABLE void consultarPerfilJugador(const QString&, quint16, int) {}
  Q_INVOKABLE void buscarJugadores(const QString&, quint16, QString) {}
  Q_INVOKABLE void listarAmigos(const QString&, quint16) {}
  Q_INVOKABLE void listarJugadoresRecientes(const QString&, quint16) {}
  Q_INVOKABLE void listarSolicitudesPendientes(const QString&, quint16) {}
  Q_INVOKABLE void enviarSolicitudAmistad(const QString&, quint16, QString) {}
  Q_INVOKABLE void responderSolicitud(const QString&, quint16, int, bool) {}
  Q_INVOKABLE void listarResumenChats(const QString&, quint16) {}
  Q_INVOKABLE void listarConversacion(const QString&, quint16, int) {}
  Q_INVOKABLE void enviarMensajeDirecto(const QString&, quint16, int, QString) {}
  Q_INVOKABLE void invitarASala(const QString&, quint16, int, QString) {}
  // Salas de RED (las locales van por iniciarPartidaLocal()) y partidas
  // guardadas en el servidor.
  Q_INVOKABLE void crearSala(const QString&, quint16, QString, QString, bool, int, int, int,
                             int, int, bool, int, int, bool, bool, bool, bool) {}
  Q_INVOKABLE void unirseASala(const QString&, quint16, QString, QString, QString) {}
  Q_INVOKABLE void empezarPartida() {}
  Q_INVOKABLE void enviarChat(const QString&, const QString&) {}
  // ── Partidas guardadas LOCALES ────────────────────────────────────────
  //  Estas cuatro NO son no-ops: son la versión local de lo que en red
  //  resuelve el servidor. Mismos nombres, firmas y señales de respuesta
  //  que en NetworkClient (los parámetros host/puerto se ignoran, claro),
  //  así que la pantalla de "Partidas guardadas" funciona igual sin tocar
  //  QML. Todo vive en carpetaGuardadoLocal(), nunca en la data/ del
  //  servidor -- ver ese método.

  Q_INVOKABLE void listarGuardadas(const QString&, quint16) { emitirListaGuardadas(); }

  Q_INVOKABLE void renombrarGuardada(const QString&, quint16, QString archivo,
                                     QString nuevoNombre) {
    QString destino = nuevoNombre.trimmed();
    if (destino.isEmpty()) {
      emit guardadaRenombrada("El nombre no puede estar vacío.");
      return;
    }
    if (!destino.endsWith(".pok")) destino += ".pok";
    // Un nombre con separadores de ruta escaparía de la carpeta local.
    if (destino.contains('/') || destino.contains('\\')) {
      emit guardadaRenombrada("El nombre no puede contener barras.");
      return;
    }
    try {
      FileManager::renombrarArchivoGuardado(rutaGuardado(archivo).toStdString(),
                                            rutaGuardado(destino).toStdString());
      emit guardadaRenombrada("");
    } catch (const std::exception& e) {
      emit guardadaRenombrada(QString::fromUtf8(e.what()));
    }
    emitirListaGuardadas();
  }

  Q_INVOKABLE void borrarGuardada(const QString&, quint16, QString archivo) {
    try {
      FileManager::borrarArchivoGuardado(rutaGuardado(archivo).toStdString());
      emit guardadaBorrada("");
    } catch (const std::exception& e) {
      emit guardadaBorrada(QString::fromUtf8(e.what()));
    }
    emitirListaGuardadas();
  }

  /// Reanuda una partida local guardada. Los dos últimos parámetros
  /// (nombre de sala y pública) solo tienen sentido en red -- se ignoran.
  Q_INVOKABLE void cargarPartidaGuardada(const QString&, quint16, QString /*nombre*/,
                                         QString archivo, QString, bool) {
    PartidaSnapshot snap;
    try {
      snap = FileManager::cargarPartida(rutaGuardado(archivo).toStdString());
    } catch (const std::exception& e) {
      emit errorSala(QString("No se pudo cargar la partida: ") + QString::fromUtf8(e.what()));
      return;
    }
    arrancarPartida(snap, rutaGuardado(archivo));
  }
  // Herramienta admin
  Q_INVOKABLE void adminConcederItem(const QString&, quint16, QString, QString, QString) {}
  Q_INVOKABLE void adminFabricarCuentasPrueba(const QString&, quint16, QString, int) {}

  Q_INVOKABLE void enviarAccion(const QString& accion, int cantidad) {
    if (!observador_) return;
    observador_->recibirAccion(net::ser::strToAccion(accion.toStdString()), cantidad);
  }

  Q_INVOKABLE void pedirRecompra() {
    if (observador_) observador_->marcarRecompraPedida();
  }

  Q_INVOKABLE void votar() {
    if (observador_) observador_->recibirDecisionMenu(1);
  }

  Q_INVOKABLE void votarExtension(bool siExtender) {
    if (observador_) observador_->recibirVotoExtension(siExtender);
  }

  Q_INVOKABLE void elegirManosExtra(int cantidad) {
    if (observador_) observador_->recibirManosExtra(cantidad);
  }

  Q_INVOKABLE void abandonar() {
    if (observador_) observador_->recibirDecisionMenu(3);
  }

  Q_INVOKABLE void guardarYSalir() {
    if (observador_) observador_->recibirDecisionMenu(2);
  }

 signals:
  // Mismos nombres/firmas que NetworkClient -- relay 1:1 de LocalGameObserver
  // (que vive del lado del motor), ver conectarSenales(). El QML que ya
  // existe (Mesa.qml/Asiento.qml/PanelVoto.qml/Main.qml) no distingue si
  // "redcliente" es un NetworkClient o un LocalGameClient.
  //
  // partidaIniciada() es la excepción: no viene de LocalGameObserver (el
  // hilo de motor todavía no existe cuando hace falta emitirla) -- se
  // emite aquí mismo, directamente, al final de iniciarPartidaLocal().
  void partidaIniciada(int manos, int tipoLimite, bool permitirRecompra,
                       bool rellenarConBots, bool preguntarExtension, QString host);
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
  void estadisticasFinCambiaron();
  void finDePartida(QString ganador, int saldo, bool porLimite);
  // NOTIFY de la identidad cacheada -- mismos nombres que en NetworkClient
  // (ver el comentario de las Q_PROPERTY correspondientes).
  void estadisticasCuentaCambiaron();
  void loadoutMarcoCambiaron();
  void perfilJugadorCambiaron();
  /// Cambió el XP pendiente de sincronizar (se ganó en una partida local, o
  /// se entregó al servidor). QML lo usa para saber si tiene algo que
  /// mandar al reconectar.
  void xpOfflinePendienteCambio();

  // ── Resto de señales de NetworkClient ─────────────────────────────────
  //
  //  Mismo criterio que con los Q_INVOKABLE de más arriba, y por un motivo
  //  concreto: un bloque "Connections { target: redcliente }" con un
  //  "function onLoQueSea()" cuyo target NO declara esa señal suelta un
  //  warning de QML por handler cada vez que se reasigna el target. QML
  //  maneja 82 señales de redcliente; sin esto, entrar en modo local
  //  llenaba la consola de avisos.
  //
  //  Casi todas no se emiten nunca aquí (no hay red que las provoque);
  //  están para que el contrato del objeto sea el mismo. Las que SÍ se
  //  emiten de verdad están arriba, con el flujo de partida.
  //  "abandonaste" es la excepción interesante: la emite
  //  LocalGameObserver al elegir "Abandonar" en el panel de fin de mano
  //  (opción 3). Sin ella, abandonar una partida local dejaba la pantalla
  //  de Partida colgada para siempre: el motor paraba, pero nada avisaba
  //  a QML de que se había acabado -- en red ese aviso lo manda el
  //  servidor, aquí no había nadie que lo hiciera.
  void abandonaste(QString mensaje);
  void logrosActualizados(QVariantList logros);
  void tiendaActualizada(QVariantList tienda);
  void conectado();
  void error(QString msg);
  void conexionComprobada(bool conectado);
  void loginOk(int accountId, QString username, QString token);
  void loginError(QString mensaje);
  void registroOk(int accountId, QString username, QString token);
  void registroError(QString mensaje);
  void logoutOk();
  void sesionInvalida(QString mensaje);
  void usernameCambiado(QString nuevoUsername);
  void usernameError(QString mensaje);
  void passwordCambiada();
  void passwordError(QString mensaje);
  void nombreAsignado(QString nombre);
  void nombreRechazado(QString mensaje);
  void lobbyActualizado(QString jugadoresCsv, int listos, int esperados, QString host,
                        QString esperadosNombresCsv);
  void chatRecibido(QString de, QString texto, QString canal);
  void enEspera(QString mensaje);
  void salaEsperandoActualizada(QStringList nombres);
  void salaCreada(QString salaId, QString codigo);
  void errorSala(QString mensaje);
  void salasActualizadas(QString salasCsv);
  void guardadasActualizadas(QString guardadasCsv);
  void guardadaRenombrada(QString mensaje);
  void guardadaBorrada(QString mensaje);
  void hostCambiado(QString host);
  void esperandoEleccionManos(QString mensaje, QString host);
  void rankingActualizado(QString rankingCsv);
  void estadisticasExportadas(QString archivo);
  void estadisticasExportadasError(QString mensaje);
  void objetoComprado(QString codigo);
  void objetoCompraError(QString mensaje);
  void objetoEquipado(QString slot, QString codigo);
  void objetoEquiparError(QString mensaje);
  void adminConcederOk(QString mensaje);
  void adminConcederError(QString mensaje);
  void adminFabricarOk(QString mensaje);
  void adminFabricarError(QString mensaje);
  void jugadoresBusquedaActualizados(QVariantList jugadores);
  void amigosActualizados(QVariantList amigos);
  void solicitudesActualizadas(QVariantList solicitudes);
  void jugadoresRecientesActualizados(QVariantList recientes);
  void solicitudAmistadEnviada();
  void solicitudAmistadError(QString mensaje);
  void solicitudRespondida();
  void solicitudRespondidaError(QString mensaje);
  void conversacionActualizada(QVariantList mensajes);
  void resumenChatsActualizado(QVariantList chats);
  void mensajeDirectoRecibido(int fromAccountId, QString fromUsername, QString texto,
                              int creadoEn, int mensajeId);
  void invitacionEnviada();
  void invitacionError(QString mensaje);
  void invitacionSalaRecibida(int fromAccountId, QString fromUsername, QString salaId,
                              QString codigo, QString nombreSala);
  void reconectando(int segundosRestantes);
  void reconectado();
  void reconexionFallida();
  void xpOfflineSincronizado(int acreditado, int reclamado, QString mensaje);

 private:
  /**
   * @brief Carpeta donde viven los guardados LOCALES (con '/' final).
   *
   * QStandardPaths::AppDataLocation, no la data/ junto al binario que usa
   * el resto del proyecto (carpetaData(), PathUtils.hpp): una aplicación
   * de escritorio instalada -- y no digamos un APK de Android -- no puede
   * dar por hecho que puede escribir junto a su propio ejecutable. Y
   * aunque pudiera, no debería compartir carpeta con los guardados del
   * servidor: son partidas de otra naturaleza y el usuario no espera
   * verlas mezcladas (decisión ya tomada, ver docs/plan-modo-offline.md).
   *
   * Subcarpeta "partidas/" para no mezclarlas con lo que Qt guarde ahí.
   * Se crea sola la primera vez.
   */
  QString carpetaGuardadoLocal() const {
    static const QString ruta = [] {
      QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
      // Sin AppDataLocation utilizable (caso raro, pero devuelve "" si el
      // entorno no define HOME/XDG) se cae a la carpeta temporal en vez de
      // escribir en un sitio impredecible relativo al CWD.
      if (base.isEmpty()) base = QDir::tempPath() + "/PokerRemake";
      QString r = base + "/partidas/";
      QDir().mkpath(r);
      return r;
    }();
    return ruta;
  }

  /// Ruta absoluta de un guardado local a partir de su nombre de fichero.
  /// Se queda solo con el nombre base a propósito: un "archivo" que llegue
  /// desde QML con separadores de ruta no debe poder salirse de la carpeta.
  QString rutaGuardado(const QString& archivo) const {
    return carpetaGuardadoLocal() + QFileInfo(archivo).fileName();
  }

  /**
   * @brief Emite guardadasActualizadas() con el MISMO formato que el
   * servidor ("nombre:humanos:bots:fecha;...", ver el dispatcher de
   * LISTAR_GUARDADAS en src/server/main.cpp).
   *
   * La fecha va la ÚLTIMA a propósito, igual que en red: trae su propio
   * ':' (la hora), así que en cualquier otra posición desalinearía el
   * split del cliente.
   */
  void emitirListaGuardadas() {
    QString csv;
    for (const ArchivoGuardado& a :
         FileManager::obtenerPartidasGuardadas(carpetaGuardadoLocal().toStdString())) {
      // autosave*/recovery_* son la red de seguridad interna del motor,
      // no partidas que el jugador haya guardado -- mismo filtro que el
      // servidor aplica antes de ofrecerlas.
      if (a.nombre.rfind("autosave", 0) == 0 || a.nombre.rfind("recovery_", 0) == 0) continue;
      int humanos = 0, bots = 0;
      try {
        PartidaSnapshot snap =
            FileManager::cargarPartida(carpetaGuardadoLocal().toStdString() + a.nombre);
        for (const auto& js : snap.jugadores) {
          if (js.saldo <= 0) continue;
          if (js.esBot) ++bots; else ++humanos;
        }
      } catch (...) {
        continue;  // corrupto o ilegible: no se ofrece
      }
      if (!csv.isEmpty()) csv += ';';
      csv += QString::fromStdString(a.nombre) + ":" + QString::number(humanos) + ":" +
             QString::number(bots) + ":" + QString::fromStdString(a.fecha);
    }
    emit guardadasActualizadas(csv);
  }

  /**
   * @brief Arranca el hilo de motor reanudando @p snap.
   *
   * Reconstruye los jugadores A MANO en vez de usar el constructor
   * TexasHoldem(PartidaSnapshot): ese crea un Persona para cada humano, y
   * Persona lee de std::cin -- dentro del cliente Qt colgaría el hilo de
   * motor para siempre esperando un teclado que no existe. Es el mismo
   * motivo por el que el servidor tampoco lo usa y reconstruye su vector
   * (ver el bloque "cfg.desdeArchivo" en src/server/main.cpp).
   *
   * El primer no-bot del snapshot es el jugador local; cualquier otro
   * humano (un .pok que viniera de una partida en red) pasa a ser un bot,
   * igual que hace el servidor con los humanos que no reconectan.
   */
  void arrancarPartida(const PartidaSnapshot& snap, const QString& rutaOrigen) {
    if (hiloMotor_.joinable()) hiloMotor_.join();

    auto observadorOwned = std::make_unique<LocalGameObserver>();
    observador_ = observadorOwned.get();
    observador_->setPermitirRecompra(snap.reglas.permitirRecompra);
    // ⚠️ El formato .pok NO persiste preguntarExtension (ni el servidor lo
    // guarda: lo saca de la config de la sala, ver FileManager::guardarPartida
    // -- ahí se escriben tipoLimite/minRaise/monteFijo/dificultad/recompra/
    // rellenarConBots/abiertaTrasInicio, y ese campo no). Al reanudar se
    // queda en su valor por defecto, true: si eliges "no preguntar" al crear
    // la partida y luego la guardas y la reanudas, sí te preguntará al llegar
    // al límite de manos. Preferible a tocar el formato del fichero (y su
    // checksum, compartido con el servidor) por un detalle menor.
    observador_->setPreguntarExtension(true);

    std::vector<Player*> jugadores;
    std::string nombreHumano;
    int botsSustitutos = 0;
    for (const auto& js : snap.jugadores) {
      if (js.saldo <= 0) continue;  // eliminado: no vuelve a la mesa
      if (!js.esBot && nombreHumano.empty()) {
        nombreHumano = js.nombre;
        jugadores.push_back(new JugadorLocalQt(js.nombre, js.saldo, observador_));
        continue;
      }
      if (!js.esBot) {
        jugadores.push_back(new Bot("Bot_" + std::to_string(++botsSustitutos), js.saldo));
        continue;
      }
      jugadores.push_back(new Bot(js.nombre, js.saldo,
                                  static_cast<Comportamiento>(js.comportamiento)));
    }
    if (nombreHumano.empty() || jugadores.size() < 2) {
      emit errorSala("La partida guardada no tiene jugadores suficientes para reanudarla.");
      observador_ = nullptr;
      return;
    }
    observador_->establecerJugadorHumano(nombreHumano);
    observador_->setAcumularXp(acumularXpOffline_);
    conectarSenales();

    int saldoInicial = 0;
    for (const auto& js : snap.jugadores) saldoInicial = std::max(saldoInicial, js.saldo);

    hiloMotor_ = std::thread([this, jugadores, snap, rutaOrigen, saldoInicial,
                              obs = std::move(observadorOwned)]() mutable {
      TexasHoldem partida(jugadores, snap.objetivoManos, snap.ciegaGrande, snap.supervisor,
                          snap.reglas);
      partida.setSaldoInicial(saldoInicial);
      partida.setCarpetaDatos(carpetaGuardadoLocal().toStdString());
      // Reanudar sobreescribe el MISMO fichero al volver a guardar, en vez
      // de ir dejando copias nuevas por cada sesión (ver archivoOrigen_ en
      // Partida::iniciarPartida()).
      partida.setArchivoOrigen(rutaOrigen.toStdString());
      partida.setManoActual(snap.manoActual);
      obs->setJugadoresPartida(&partida.jugadoresMutable());
      partida.setObserver(std::move(obs));
      partida.iniciarPartida();
      partidaActiva_.store(false);
    });
    partidaActiva_.store(true);

    emit partidaIniciada(snap.objetivoManos, static_cast<int>(snap.reglas.tipoLimite),
                         snap.reglas.permitirRecompra, /*rellenarConBots=*/false,
                         /*preguntarExtension=*/true, QString::fromStdString(nombreHumano));
  }

  /// Conecta cada señal de observador_ a la señal gemela de este objeto --
  /// ambos QObject viven en el hilo GUI (ver el comentario de la clase),
  /// así que Qt::AutoConnection resuelve esto como conexión directa
  /// normal, sin cola de por medio (el cruce de hilo real ya ocurrió
  /// DENTRO de cada emit de observador_, hecho desde el hilo de motor).
  void conectarSenales() {
    connect(observador_, &LocalGameObserver::nuevaMano, this, &LocalGameClient::nuevaMano);
    connect(observador_, &LocalGameObserver::eventoJuego, this, &LocalGameClient::eventoJuego);
    connect(observador_, &LocalGameObserver::mesaActualizada, this, &LocalGameClient::mesaActualizada);
    connect(observador_, &LocalGameObserver::estadoMesaActualizado, this,
            &LocalGameClient::estadoMesaActualizado);
    connect(observador_, &LocalGameObserver::esMiTurno, this, &LocalGameClient::esMiTurno);
    connect(observador_, &LocalGameObserver::comboActualizado, this, &LocalGameClient::comboActualizado);
    connect(observador_, &LocalGameObserver::misCartasRepartidas, this,
            &LocalGameClient::misCartasRepartidas);
    connect(observador_, &LocalGameObserver::accionRealizada, this, &LocalGameClient::accionRealizada);
    connect(observador_, &LocalGameObserver::showdownIniciado, this, &LocalGameClient::showdownIniciado);
    connect(observador_, &LocalGameObserver::boteEvaluado, this, &LocalGameClient::boteEvaluado);
    connect(observador_, &LocalGameObserver::cartasMostradas, this, &LocalGameClient::cartasMostradas);
    connect(observador_, &LocalGameObserver::boteGanado, this, &LocalGameClient::boteGanado);
    connect(observador_, &LocalGameObserver::ganadorSinShowdown, this,
            &LocalGameClient::ganadorSinShowdown);
    connect(observador_, &LocalGameObserver::avisoRecompra, this, &LocalGameClient::avisoRecompra);
    connect(observador_, &LocalGameObserver::esperandoVoto, this, &LocalGameClient::esperandoVoto);
    connect(observador_, &LocalGameObserver::votoConfirmado, this, &LocalGameClient::votoConfirmado);
    connect(observador_, &LocalGameObserver::esperandoVotoExtension, this,
            &LocalGameClient::esperandoVotoExtension);
    connect(observador_, &LocalGameObserver::elegirManosExtraPedido, this,
            &LocalGameClient::elegirManosExtraPedido);
    connect(observador_, &LocalGameObserver::partidaExtendida, this, &LocalGameClient::partidaExtendida);
    connect(observador_, &LocalGameObserver::saldosActualizados, this,
            &LocalGameClient::saldosActualizados);
    connect(observador_, &LocalGameObserver::partidaGuardada, this, &LocalGameClient::partidaGuardada);
    connect(observador_, &LocalGameObserver::abandonaste, this, &LocalGameClient::abandonaste);
    // No es un relay 1:1: el XP de la partida se SUMA a la bolsa pendiente y
    // se persiste, para entregarlo cuando vuelva a haber servidor.
    connect(observador_, &LocalGameObserver::xpOfflineGanado, this, [this](int xp) {
      if (xp <= 0) return;
      xpOfflinePendiente_ += xp;
      QSettings().setValue("offline/xpPendiente", xpOfflinePendiente_);
      emit xpOfflinePendienteCambio();
    });
    connect(observador_, &LocalGameObserver::finDePartida, this, &LocalGameClient::finDePartida);
    // estadisticasFinListas lleva los datos crudos -- se guardan en las
    // Q_PROPERTY propias y SOLO entonces se emite estadisticasFinCambiaron()
    // (mismo orden que NetworkClient: los datos ya están listos para
    // cuando Main.qml reacciona a esa señal). No es un relay 1:1 como el
    // resto.
    connect(observador_, &LocalGameObserver::estadisticasFinListas, this,
            [this](int manos, QString mejorMano, QString mejorManoJugador, QString eliminaciones) {
              manosDisputadasFinal_ = manos;
              mejorManoFinal_ = mejorMano;
              mejorManoJugadorFinal_ = mejorManoJugador;
              eliminacionesFinalCsv_ = eliminaciones;
              emit estadisticasFinCambiaron();
            });
  }

  std::thread hiloMotor_;
  /// No poseído -- la propiedad real es de Partida (ver setObserver() en
  /// iniciarPartidaLocal()). Válido solo mientras hiloMotor_ sigue vivo;
  /// dejar de usarlo tras join() (ver el destructor y el comentario de la
  /// clase). No se pone a nullptr explícitamente al terminar la partida en
  /// este primer corte -- ver la simplificación documentada arriba: una
  /// partida nueva siempre hace join() de la vieja antes de sobrescribirlo.
  LocalGameObserver* observador_ = nullptr;
  std::atomic<bool> partidaActiva_{false};

  int manosDisputadasFinal_ = 0;
  QString mejorManoFinal_;
  QString mejorManoJugadorFinal_;
  QString eliminacionesFinalCsv_;

  /// Identidad cacheada (ver las Q_PROPERTY de arriba). Persistida en
  /// QSettings bajo el prefijo "offline/" -- misma organización/aplicación
  /// que el resto de ajustes del cliente (los fija main.cpp).
  QVariantMap estadisticasCuenta_;
  QVariantMap loadoutMarco_;
  QVariantList logrosCacheados_;
  QVariantList tiendaCacheada_;
  QString usernameCacheado_;
  int xpOfflinePendiente_ = 0;
  bool acumularXpOffline_ = false;
};
