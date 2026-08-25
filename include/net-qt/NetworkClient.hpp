#pragma once

#include <functional>
#include <memory>

#include <QCryptographicHash>
#include <QDebug>
#include <QElapsedTimer>
#include <QList>
#include <QObject>
#include <QSslCertificate>
#include <QSslError>
#include <QSslKey>
#include <QSslSocket>
#include <QTimer>
#include <QVariantMap>

#include "../net/Protocol.hpp"
#include "../net/ServerConfig.hpp"
#include "QtEndian"  // qToBigEndian

class NetworkClient : public QObject {
  Q_OBJECT
  // Estadísticas de fin de partida como propiedades en vez de parámetros
  // de la señal finDePartida -- bug real visto solo en el APK de Android
  // (nunca en escritorio ni en el propio móvil corriendo como ventana de
  // escritorio, mismo binario): con una señal de 7 parámetros conectada
  // vía "Connections { function onFinDePartida(...) {...} }", los 3
  // primeros (ganador/saldo/porLimite) llegaban bien pero los 4 últimos
  // se quedaban siempre en su valor por defecto (0/""), como si QML
  // estuviera invocando una versión más vieja del handler que ignora los
  // parámetros de más. finDePartida() vuelve a sus 3 parámetros
  // originales (esos siempre funcionaron); estos 4 datos se leen como
  // propiedades normales, el mecanismo más maduro y probado de QML/Qt --
  // se fijan ANTES de emitir finDePartida, así que ya están listos para
  // cuando el handler de QML los lee.
  Q_PROPERTY(int manosDisputadasFinal READ manosDisputadasFinal NOTIFY estadisticasFinCambiaron)
  Q_PROPERTY(QString mejorManoFinal READ mejorManoFinal NOTIFY estadisticasFinCambiaron)
  Q_PROPERTY(QString mejorManoJugadorFinal READ mejorManoJugadorFinal NOTIFY estadisticasFinCambiaron)
  Q_PROPERTY(QString eliminacionesFinalCsv READ eliminacionesFinalCsv NOTIFY estadisticasFinCambiaron)
  // Ver el comentario de consultarEstadisticas() más abajo -- mismo motivo
  // que las cuatro propiedades de arriba (bug de Android con señales de
  // muchos parámetros), un único QVariantMap en vez de veinte campos sueltos.
  Q_PROPERTY(QVariantMap estadisticasCuenta READ estadisticasCuenta NOTIFY estadisticasCuentaCambiaron)

 public:
  using QObject::QObject;

  int manosDisputadasFinal() const { return manosDisputadasFinal_; }
  QString mejorManoFinal() const { return mejorManoFinal_; }
  QString mejorManoJugadorFinal() const { return mejorManoJugadorFinal_; }
  QString eliminacionesFinalCsv() const { return eliminacionesFinalCsv_; }
  QVariantMap estadisticasCuenta() const { return estadisticasCuenta_; }

  Q_INVOKABLE void conectar(const QString& host, quint16 puerto,
                            QString nombre) {
    // Sala legacy: sin concepto de sala_id/código -- si veníamos de una
    // sesión anterior con estos rellenos (crear/unirse a otra sala antes),
    // limpiarlos aquí evita que una reconexión posterior intente un
    // JOIN_GAME con datos de una sala que ya no tiene nada que ver.
    salaIdActual_.clear();
    codigoActual_.clear();
    iniciarConexionConMensaje(host, puerto, nombre,
        net::buildMsg(net::MsgType::JOIN_LOBBY, {{"nombre", nombre.toStdString()},
                                                  {"token", token_.toStdString()}}));
  }

  /// Crea una sala nueva (pantalla "Crear sala") y se conecta a ella —
  /// la misma conexión sirve para el CREATE_GAME y, si el servidor la
  /// acepta, para toda la partida (el dispatcher reencola el mismo fd en
  /// la sala nueva, no hace falta reconectar). Ver GAME_EVENT/SALA_CREADA
  /// más abajo para el id/código que devuelve el servidor.
  Q_INVOKABLE void crearSala(const QString& host, quint16 puerto, QString nombre,
                             QString nombreSala, bool publica, int tamanoSala,
                             int numManos, int ciegaGrande, int saldo,
                             int tipoLimite, bool aplicarMinRaise, int monteFijo,
                             int dificultadBots, bool permitirRecompra,
                             bool rellenarConBots, bool abiertaTrasInicio,
                             bool preguntarExtension) {
    // El sala_id de verdad no se conoce hasta que llegue SALA_CREADA (más
    // abajo, en el bucle de readyRead) -- limpiar aquí lo de una sesión
    // anterior evita usarlo por error si la conexión se cae ANTES de esa
    // respuesta (ventana muy corta, pero incorrecta si no se limpia).
    salaIdActual_.clear();
    codigoActual_.clear();
    iniciarConexionConMensaje(host, puerto, nombre, net::buildMsg(net::MsgType::CREATE_GAME, {
        {"nombre",             nombre.toStdString()},
        {"nombre_sala",        nombreSala.toStdString()},
        {"publica",            publica ? "1" : "0"},
        {"tamano_sala",        std::to_string(tamanoSala)},
        {"num_manos",          std::to_string(numManos)},
        {"ciega_grande",       std::to_string(ciegaGrande)},
        {"saldo",              std::to_string(saldo)},
        {"tipo_limite",        std::to_string(tipoLimite)},
        {"aplicar_min_raise",  aplicarMinRaise ? "1" : "0"},
        {"monte_fijo",         std::to_string(monteFijo)},
        {"dificultad_bots",    std::to_string(dificultadBots)},
        {"permitir_recompra",  permitirRecompra ? "1" : "0"},
        {"rellenar_con_bots",  rellenarConBots ? "1" : "0"},
        {"abierta_tras_inicio", abiertaTrasInicio ? "1" : "0"},
        {"preguntar_extension", preguntarExtension ? "1" : "0"},
        {"token",              token_.toStdString()},
    }));
  }

  /// Unirse a una sala existente (pantalla "Salas disponibles"), por id
  /// (de la lista) o por código (sala privada) — el que esté vacío se
  /// ignora en el servidor.
  Q_INVOKABLE void unirseASala(const QString& host, quint16 puerto, QString nombre,
                               QString salaId, QString codigo) {
    // Recordados para la reconexión mientras seguimos en el lobby (ver
    // intentarReconexionAhora()) -- salaId puede venir vacío si se entró
    // solo por código (sala privada), por eso se guardan los dos.
    salaIdActual_ = salaId;
    codigoActual_ = codigo;
    iniciarConexionConMensaje(host, puerto, nombre, net::buildMsg(net::MsgType::JOIN_GAME, {
        {"nombre",  nombre.toStdString()},
        {"sala_id", salaId.toStdString()},
        {"codigo",  codigo.toStdString()},
        {"token",   token_.toStdString()},
    }));
  }

  /**
   * @brief Pide la lista de salas públicas disponibles.
   *
   * A propósito NO usa socket_/la conexión persistente — es una consulta
   * puntual de "antes de unirse a nada" (pantalla "Salas disponibles"),
   * con su propio socket efímero que el servidor cierra tras responder
   * (ver dispatcher, rama LISTAR_SALAS). Puede llamarse varias veces
   * (botón "Refrescar") sin arrastrar estado de una llamada a la siguiente.
   */
  Q_INVOKABLE void refrescarSalas(const QString& host, quint16 puerto) {
    enviarPeticionEfimera(host, puerto, net::buildMsg(net::MsgType::LISTAR_SALAS),
        [this](const std::string& payload) {
          emit salasActualizadas(
              QString::fromStdString(net::jsonGetStr(payload, "salas")));
        });
  }

  /**
   * @brief Sonda ligera de "¿hay servidor al otro lado?" para la pantalla
   * Inicio — mismo socket efímero que refrescarSalas() (reutiliza
   * LISTAR_SALAS: barato, y el servidor ya lo cierra tras responder), pero
   * con su propio signal en vez de salasActualizadas(), para no disparar
   * una actualización de la lista de salas cada vez que Inicio solo quiere
   * saber si hay conexión.
   */
  Q_INVOKABLE void comprobarConexion(const QString& host, quint16 puerto) {
    enviarPeticionEfimera(host, puerto, net::buildMsg(net::MsgType::LISTAR_SALAS),
        [this](const std::string& payload) {
          emit conexionComprobada(!payload.empty());
        });
  }

  /// Pide la lista de partidas guardadas (.pok) del servidor -- mismo
  /// patrón efímero que refrescarSalas(). token_ interno (no explícito):
  /// el servidor ahora restringe la lista a las guardadas donde jugó la
  /// cuenta del token (invitado, sin token, no ve ninguna).
  Q_INVOKABLE void listarGuardadas(const QString& host, quint16 puerto) {
    enviarPeticionEfimera(host, puerto,
        net::buildMsg(net::MsgType::LISTAR_GUARDADAS, {{"token", token_.toStdString()}}),
        [this](const std::string& payload) {
          emit guardadasActualizadas(
              QString::fromStdString(net::jsonGetStr(payload, "guardadas")));
        });
  }

  /// Pide el ranking global -- público, sin token. Mismo patrón efímero
  /// que refrescarSalas()/listarGuardadas().
  Q_INVOKABLE void consultarRanking(const QString& host, quint16 puerto) {
    enviarPeticionEfimera(host, puerto, net::buildMsg(net::MsgType::CONSULTAR_RANKING),
        [this](const std::string& payload) {
          emit rankingActualizado(
              QString::fromStdString(net::jsonGetStr(payload, "ranking")));
        });
  }

  /// Renombra un archivo .pok existente -- token_ interno, el servidor
  /// rechaza la operación si esa cuenta no jugó en el guardado.
  Q_INVOKABLE void renombrarGuardada(const QString& host, quint16 puerto,
                                     QString archivo, QString nuevoNombre) {
    enviarPeticionEfimera(host, puerto,
        net::buildMsg(net::MsgType::RENOMBRAR_GUARDADA, {
            {"archivo",      archivo.toStdString()},
            {"nuevo_nombre", nuevoNombre.toStdString()},
            {"token",        token_.toStdString()},
        }),
        [this](const std::string& payload) {
          emit guardadaRenombrada(
              QString::fromStdString(net::jsonGetStr(payload, "mensaje")));
        });
  }

  /// Borra un archivo .pok existente -- mismo criterio que
  /// renombrarGuardada() (token_ interno, propiedad comprobada en servidor).
  Q_INVOKABLE void borrarGuardada(const QString& host, quint16 puerto, QString archivo) {
    enviarPeticionEfimera(host, puerto,
        net::buildMsg(net::MsgType::BORRAR_GUARDADA, {
            {"archivo", archivo.toStdString()},
            {"token",   token_.toStdString()},
        }),
        [this](const std::string& payload) {
          emit guardadaBorrada(
              QString::fromStdString(net::jsonGetStr(payload, "mensaje")));
        });
  }

  /// Reanuda una partida guardada como sala nueva — misma conexión
  /// persistente que crearSala()/unirseASala() (el dispatcher reencola el
  /// mismo fd en la sala recién lanzada, ver GAME_EVENT/SALA_CREADA).
  Q_INVOKABLE void cargarPartidaGuardada(const QString& host, quint16 puerto, QString nombre,
                                         QString archivo, QString nombreSala, bool publica) {
    // Mismo motivo que en crearSala(): el sala_id de verdad llega luego,
    // en SALA_CREADA.
    salaIdActual_.clear();
    codigoActual_.clear();
    iniciarConexionConMensaje(host, puerto, nombre, net::buildMsg(net::MsgType::CARGAR_PARTIDA, {
        {"nombre",      nombre.toStdString()},
        {"archivo",     archivo.toStdString()},
        {"nombre_sala", nombreSala.toStdString()},
        {"publica",     publica ? "1" : "0"},
        {"token",       token_.toStdString()},
    }));
  }

  // ── Cuentas de usuario ────────────────────────────────────────────────────
  //  Las seis, mismo patrón efímero que refrescarSalas()/listarGuardadas()
  //  (no tocan socket_, la conexión persistente de la partida) -- token_ se
  //  guarda internamente en las que dan sesión (registrar/iniciarSesion/
  //  iniciarSesionConToken), igual que nombre_ ya se actualiza solo con
  //  NOMBRE_ASIGNADO. A partir de ahí, conectar()/crearSala()/unirseASala()/
  //  cargarPartidaGuardada() ya mandan este token_ solos.

  Q_INVOKABLE void registrar(const QString& host, quint16 puerto, QString username, QString password) {
    enviarPeticionEfimera(host, puerto, net::buildMsg(net::MsgType::REGISTER, {
        {"username", username.toStdString()},
        {"password", password.toStdString()},
    }), [this](const std::string& payload) {
      if (net::jsonGetStr(payload, "evento") == "REGISTRO_OK") {
        token_ = QString::fromStdString(net::jsonGetStr(payload, "token"));
        nombre_ = QString::fromStdString(net::jsonGetStr(payload, "username"));
        emit registroOk(net::jsonGetInt(payload, "account_id"), nombre_, token_);
      } else {
        emit registroError(QString::fromStdString(net::jsonGetStr(payload, "mensaje")));
      }
    });
  }

  Q_INVOKABLE void iniciarSesion(const QString& host, quint16 puerto, QString username, QString password) {
    enviarPeticionEfimera(host, puerto, net::buildMsg(net::MsgType::LOGIN, {
        {"username", username.toStdString()},
        {"password", password.toStdString()},
    }), [this](const std::string& payload) {
      if (net::jsonGetStr(payload, "evento") == "LOGIN_OK") {
        token_ = QString::fromStdString(net::jsonGetStr(payload, "token"));
        nombre_ = QString::fromStdString(net::jsonGetStr(payload, "username"));
        emit loginOk(net::jsonGetInt(payload, "account_id"), nombre_, token_);
      } else {
        emit loginError(QString::fromStdString(net::jsonGetStr(payload, "mensaje")));
      }
    });
  }

  /// Reautenticación silenciosa con el token que el cliente ya tenía
  /// guardado (Settings) -- se llama al arrancar, antes de mostrar Inicio.
  Q_INVOKABLE void iniciarSesionConToken(const QString& host, quint16 puerto, QString token) {
    enviarPeticionEfimera(host, puerto, net::buildMsg(net::MsgType::LOGIN_TOKEN, {
        {"token", token.toStdString()},
    }), [this](const std::string& payload) {
      if (net::jsonGetStr(payload, "evento") == "LOGIN_OK") {
        token_ = QString::fromStdString(net::jsonGetStr(payload, "token"));
        nombre_ = QString::fromStdString(net::jsonGetStr(payload, "username"));
        emit loginOk(net::jsonGetInt(payload, "account_id"), nombre_, token_);
      } else {
        emit sesionInvalida(QString::fromStdString(net::jsonGetStr(payload, "mensaje")));
      }
    });
  }

  /// Cierra sesión: revoca el token en el servidor y lo olvida aquí --
  /// conectar()/crearSala()/etc. volverán a mandar "token" vacío (invitado)
  /// hasta el próximo login. No falla nunca de forma visible (ver LOGOUT
  /// en el servidor): token_ se limpia siempre, haya o no respuesta.
  Q_INVOKABLE void cerrarSesion(const QString& host, quint16 puerto, QString token) {
    enviarPeticionEfimera(host, puerto, net::buildMsg(net::MsgType::LOGOUT, {
        {"token", token.toStdString()},
    }), [this](const std::string& /*payload*/) {
      token_.clear();
      emit logoutOk();
    });
  }

  Q_INVOKABLE void cambiarNombreUsuario(const QString& host, quint16 puerto, QString token,
                                        QString nuevoUsername) {
    enviarPeticionEfimera(host, puerto, net::buildMsg(net::MsgType::CHANGE_USERNAME, {
        {"token",          token.toStdString()},
        {"nuevo_username", nuevoUsername.toStdString()},
    }), [this](const std::string& payload) {
      if (net::jsonGetStr(payload, "evento") == "USERNAME_CAMBIADO") {
        nombre_ = QString::fromStdString(net::jsonGetStr(payload, "username"));
        emit usernameCambiado(nombre_);
      } else {
        emit usernameError(QString::fromStdString(net::jsonGetStr(payload, "mensaje")));
      }
    });
  }

  Q_INVOKABLE void cambiarPassword(const QString& host, quint16 puerto, QString token,
                                   QString passwordActual, QString passwordNueva) {
    enviarPeticionEfimera(host, puerto, net::buildMsg(net::MsgType::CHANGE_PASSWORD, {
        {"token",           token.toStdString()},
        {"password_actual", passwordActual.toStdString()},
        {"password_nueva",  passwordNueva.toStdString()},
    }), [this](const std::string& payload) {
      if (net::jsonGetStr(payload, "evento") == "PASSWORD_CAMBIADA") {
        emit passwordCambiada();
      } else {
        emit passwordError(QString::fromStdString(net::jsonGetStr(payload, "mensaje")));
      }
    });
  }

  /// Estadísticas propias -- token vacío (invitado) ni se manda, el
  /// servidor respondería igualmente a cero pero no tiene sentido
  /// preguntar. Mismo patrón efímero que cambiarPassword() (token explícito
  /// en vez de token_ interno -- QML ya lo tiene en ventana.tokenSesion).
  //
  // QVariantMap vía Q_PROPERTY en vez de veinte parámetros en la señal --
  // MISMO motivo que estadisticasFinCambiaron/manosDisputadasFinal arriba
  // (bug real de Android: una señal con demasiados parámetros conectada
  // desde QML pierde los últimos SOLO en el APK, nunca en escritorio).
  // Aquí ni siquiera hacen falta propiedades sueltas por campo -- un único
  // QVariantMap ya evita el problema (una señal de UN parámetro) y QML lo
  // desestructura por nombre de campo, no por posición.
  Q_INVOKABLE void consultarEstadisticas(const QString& host, quint16 puerto, QString token) {
    if (token.isEmpty()) return;
    enviarPeticionEfimera(host, puerto,
        net::buildMsg(net::MsgType::CONSULTAR_ESTADISTICAS, {{"token", token.toStdString()}}),
        [this](const std::string& payload) {
          QVariantMap m;
          m["manosJugadas"] = net::jsonGetInt(payload, "manos_jugadas");
          m["manosGanadas"] = net::jsonGetInt(payload, "manos_ganadas");
          m["partidasJugadas"] = net::jsonGetInt(payload, "partidas_jugadas");
          m["partidasGanadas"] = net::jsonGetInt(payload, "partidas_ganadas");
          m["rachaActual"] = net::jsonGetInt(payload, "racha_actual");
          m["rachaMaxima"] = net::jsonGetInt(payload, "racha_maxima");
          m["mayorBote"] = net::jsonGetInt(payload, "mayor_bote");
          m["mejorManoNombre"] = QString::fromStdString(net::jsonGetStr(payload, "mejor_mano_nombre"));
          m["mejorManoFecha"] = net::jsonGetInt(payload, "mejor_mano_fecha");
          m["vecesCartaAlta"] = net::jsonGetInt(payload, "veces_carta_alta");
          m["vecesPareja"] = net::jsonGetInt(payload, "veces_pareja");
          m["vecesDoblePareja"] = net::jsonGetInt(payload, "veces_doble_pareja");
          m["vecesTrio"] = net::jsonGetInt(payload, "veces_trio");
          m["vecesEscalera"] = net::jsonGetInt(payload, "veces_escalera");
          m["vecesColor"] = net::jsonGetInt(payload, "veces_color");
          m["vecesFullHouse"] = net::jsonGetInt(payload, "veces_full_house");
          m["vecesPoker"] = net::jsonGetInt(payload, "veces_poker");
          m["vecesEscaleraColor"] = net::jsonGetInt(payload, "veces_escalera_color");
          m["vecesEscaleraReal"] = net::jsonGetInt(payload, "veces_escalera_real");
          estadisticasCuenta_ = m;
          emit estadisticasCuentaCambiaron();
        });
  }

  /// @param canal "sala" (se ve en la sala de espera y también en la
  /// partida — quien esté esperando a sentarse lo recibe igual) o
  /// "partida" (solo llega a los jugadores ya sentados). Ver
  /// NetworkObserver::relayPendingChat()/broadcastASala() en el servidor.
  Q_INVOKABLE void enviarChat(const QString& texto, const QString& canal) {
    enviarMensaje(net::buildMsg(
        net::MsgType::CHAT,
        {{"de", nombre_.toStdString()},
         {"texto", texto.toStdString()},
         {"canal", canal.toStdString()}}));
  }

  Q_INVOKABLE void enviarAccion(const QString& accion, int cantidad) {
    enviarMensaje(net::buildMsg(net::MsgType::ACTION,
                                {{"accion", accion.toStdString()},
                                 {"cantidad", std::to_string(cantidad)}}));
  }

  /// El host pide arrancar la partida ya, sin esperar a que se llene el
  /// cupo de humanos — el servidor valida que quien lo pide sea de verdad
  /// el host (server/main.cpp, ejecutarSala).
  Q_INVOKABLE void empezarPartida() {
    enviarMensaje(net::buildMsg(net::MsgType::ACTION, {{"accion", "EMPEZAR_PARTIDA"}}));
  }

  /// Pide recomprar (volver con el saldo inicial) tras quedarte sin
  /// fichas — solo tiene efecto si la sala lo permite; se aplica una vez
  /// por mano (ver Partida::iniciarPartida()/onComprobarRecompras).
  Q_INVOKABLE void pedirRecompra() {
    enviarMensaje(net::buildMsg(net::MsgType::ACTION, {{"accion", "RECOMPRA"}}));
  }

  Q_INVOKABLE void votar() {
    enviarMensaje(net::buildMsg(net::MsgType::ACTION, {{"accion", "VOTO"}}));
  }

  Q_INVOKABLE void votarExtension(bool siExtender) {
    enviarMensaje(net::buildMsg(
        net::MsgType::ACTION,
        {{"accion", siExtender ? "EXTENDER" : "NO_EXTENDER"}}));
  }

  /// Solo lo llama el host, tras ELEGIR_MANOS_EXTRA (todos ya aceptaron
  /// continuar) -- cuántas manos más quiere añadir.
  Q_INVOKABLE void elegirManosExtra(int cantidad) {
    enviarMensaje(net::buildMsg(
        net::MsgType::ACTION,
        {{"accion", "MANOS_EXTRA"}, {"cantidad", std::to_string(cantidad)}}));
  }

  Q_INVOKABLE void abandonar() {
    desconexionEsperada_ = true;  // el servidor va a cerrar nuestro socket a propósito
    enviarMensaje(net::buildMsg(net::MsgType::ACTION, {{"accion", "LEAVE"}}));
  }

  Q_INVOKABLE void guardarYSalir() {
    desconexionEsperada_ = true;
    enviarMensaje(net::buildMsg(net::MsgType::ACTION, {{"accion", "SAVE_AND_EXIT"}}));
  }

 signals:
  // ── Cuentas de usuario ──────────────────────────────────────────────────
  /// Cuenta creada con éxito -- token_/nombre_ ya están al día
  /// internamente, listos para el próximo conectar()/crearSala()/etc.
  void registroOk(int accountId, QString username, QString token);
  void registroError(QString mensaje);
  void loginOk(int accountId, QString username, QString token);
  void loginError(QString mensaje);
  /// Respuesta a iniciarSesionConToken() con un token caducado/inválido --
  /// limpiar el token guardado en Settings y quedarse en Inicio/Login.
  void sesionInvalida(QString mensaje);
  void logoutOk();
  void usernameCambiado(QString nuevoUsername);
  void usernameError(QString mensaje);
  void passwordCambiada();
  void passwordError(QString mensaje);

  void conectado();
  void error(QString msg);
  void lobbyActualizado(QString jugadoresCsv, int listos, int esperados, QString host,
                        QString esperadosNombresCsv);
  /// @param canal "sala" o "partida" — ver enviarChat(). Vacío (mensajes
  /// del lobby previo a esta funcionalidad, o de la fase de lobby anterior
  /// al arranque de la partida, que no etiqueta el campo) se trata igual
  /// que "sala" en el cliente.
  void chatRecibido(QString de, QString texto, QString canal);
  /// Se aceptó tu JOIN_GAME a mitad de partida pero todavía no tienes
  /// asiento — llegará PARTIDA_INICIADA cuando de verdad te sienten.
  void enEspera(QString mensaje);
  /// Roster de quién está esperando a sentarse en esta sala ahora mismo
  /// (puede estar vacío si nadie espera).
  void salaEsperandoActualizada(QStringList nombres);
  /**
   * @brief La partida empieza — además de la señal, ahora trae las
   * reglas de la sala (fijas toda la sesión) para la sección "Mesa
   * actual" del cajón de ajustes.
   * @param manos Objetivo de manos de la sesión (0 si no llegó, por
   * compatibilidad con GAME_EVENT/PARTIDA_INICIADA sin estos campos).
   * @param tipoLimite 0=Sin límite, 1=Límite bote, 2=Límite fijo (mismo
   * enum que TipoLimite en GameTypes.hpp).
   */
  void partidaIniciada(int manos, int tipoLimite, bool permitirRecompra, bool rellenarConBots,
                       bool preguntarExtension);
  void estadoMesaActualizado(QString ronda, int bote, QString turno,
                             QString jugadoresStr, int timeoutMs,
                             QString dealer, QString sb, QString bb);
  /**
   * @brief Una línea para el historial de partida.
   * @param tipo Categoría para colorear el punto de la entrada en Main.qml:
   * "separador" (Mano N / FLOP-TURN-RIVER), "sistema" (ciegas, conexión,
   * modo espectador...), "error" (ERROR_JUGADA/ERROR_SISTEMA/eliminado/
   * recompra), "fold", "agresion" (raise/all-in), "accion" (check/call,
   * el resto por defecto) o "showdown" (bote, cartas, ganador).
   * @param jugador Nombre del jugador protagonista de esta línea, si lo
   * hay ("" si no aplica, p. ej. separadores o avisos generales) — Main.qml
   * lo pinta aparte del resto de la línea (dorado si es el propio jugador,
   * otro color si es cualquier otro) para que los nombres destaquen.
   */
  void eventoJuego(QString evento, QString tipo = "accion", QString jugador = "");
  void accionRealizada(QString jugador, QString accion);
  void nuevaMano(int mano, int ciega);
  /// Cartas propias, justo al repartir — antes solo llegaban dentro de
  /// esMiTurno(), así que no se conocían hasta el primer turno propio.
  void misCartasRepartidas(QString c1, QString c2);
  void esMiTurno(int bote, int igualar, int miSaldo, int miApuesta, int timeoutMs, int minSubida,
                 int maxSubida, QString c1, QString c2, QString comboActual,
                 QString comboProbable, QString comboMaxima);
  /// COMBO_UPDATE: el servidor ya lo manda en cada turno (de cualquiera,
  /// no solo el propio) para que la predicción de mano no se quede
  /// congelada hasta que vuelva a tocarte — antes se ignoraba en el
  /// cliente, que solo actualizaba comboActual/etc. dentro de esMiTurno().
  void comboActualizado(QString actual, QString probable, QString maxima);
  void esperandoVoto(QString mensaje);
  /// FASE 1 de la extensión de partida: todos votan si quieren seguir
  /// jugando o no (sin número de manos todavía, eso lo decide el host
  /// solo si la votación sale que sí -- ver elegirManosExtraPedido()).
  void esperandoVotoExtension(QString mensaje);
  /// FASE 2, solo para el HOST: la votación salió que sí, hay que elegir
  /// cuántas manos más añadir (con elegirManosExtra()).
  void elegirManosExtraPedido(QString mensaje);
  /// FASE 2, para el RESTO (no host): aviso de que se está esperando a que
  /// el host termine de elegir, para no dejarlos mirando una pantalla
  /// muda sin saber qué pasa.
  void esperandoEleccionManos(QString mensaje, QString host);
  /// La partida se extendió de verdad -- nuevoObjetivoManos ya incluye las
  /// manos añadidas (no hay que sumarlas a mano en QML).
  void partidaExtendida(int manosExtra, int nuevoObjetivoManos);
  void mesaActualizada(QString mesa);
  /// @param manosDisputadas Total de manos jugadas en la sesión.
  /// @param mejorMano Nombre de la mejor combinación conseguida en toda la
  /// partida (ej. "Escalera de Color"), o "" si nadie llegó a showdown.
  /// @param mejorManoJugador Quién la consiguió, o "" si mejorMano está vacío.
  /// @param eliminacionesCsv "nombre1:mano1;nombre2:mano2;..." -- "mano" es
  /// el número de mano en que ese jugador quedó eliminado, o "X" si
  /// terminó la partida todavía en juego (mismo formato que ya usa
  /// Interfaz::mostrarDetallePartida() en ncurses).
  void finDePartida(QString ganador, int saldo, bool porLimite);
  /// Avisa de que manosDisputadasFinal/mejorManoFinal/mejorManoJugadorFinal/
  /// eliminacionesFinalCsv ya están al día -- se emite justo antes de
  /// finDePartida, así que para cuando ese llega, estas propiedades ya
  /// tienen el valor de la partida que acaba de terminar.
  void estadisticasFinCambiaron();
  void abandonaste(QString mensaje);
  void saldosActualizados(QString jugadoresStr);
  void partidaGuardada(QString archivo);
  /// Se ha perdido la conexión y se está reintentando; segundosRestantes cuenta hacia 0.
  void reconectando(int segundosRestantes);
  /// Reconexión conseguida — la partida sigue igual, no hace falta volver al Lobby.
  void reconectado();
  /// Se agotó la ventana de reconexión (60s) sin éxito.
  void reconexionFallida();
  /// El servidor rechazó el nombre (hoy solo al cargar una partida guardada).
  void nombreRechazado(QString mensaje);
  /// El nombre efectivo con el que el servidor nos identifica (puede
  /// diferir del que escribimos: llegó vacío o se sanitizó).
  void nombreAsignado(QString nombre);
  /// CREATE_GAME aceptado: id de la sala nueva y código (vacío si es pública).
  void salaCreada(QString salaId, QString codigo);
  /// JOIN_GAME rechazado (sala inexistente, llena o ya empezada).
  void errorSala(QString mensaje);
  /// Respuesta a refrescarSalas(): "id:nombre:conectados:esperados;..." (puede ser "").
  void salasActualizadas(QString salasCsv);
  /// Respuesta a comprobarConexion(): true si el servidor respondió algo,
  /// false si la conexión falló (host caído, puerto cerrado, sin red...).
  void conexionComprobada(bool conectado);
  /// Respuesta a listarGuardadas(): "archivo:fecha:humanos:bots;..." (puede ser "").
  void guardadasActualizadas(QString guardadasCsv);
  /// Respuesta a consultarRanking(): "partidasJugadas:partidasGanadas:username;..." (puede ser "").
  void rankingActualizado(QString rankingCsv);
  /// Avisa de que la propiedad estadisticasCuenta ya está al día --
  /// respuesta a consultarEstadisticas() (las propias). Ver el comentario
  /// largo junto a consultarEstadisticas() para el porqué de un
  /// QVariantMap en vez de parámetros sueltos.
  void estadisticasCuentaCambiaron();
  /// Respuesta a renombrarGuardada() — mensaje vacío si fue bien.
  void guardadaRenombrada(QString mensaje);
  /// Respuesta a borrarGuardada() — mensaje vacío si fue bien.
  void guardadaBorrada(QString mensaje);
  /// Te quedaste sin fichas; indica si la sala permite pedir recompra.
  void avisoRecompra(bool puedeRecomprar);
  /// Empieza el showdown — cartasCsv son las comunitarias finales
  /// ("AS,KH,..."). Dispara la pantalla dedicada en Main.qml.
  void showdownIniciado(QString cartasCsv);
  /// Se empieza a resolver un bote (0 = principal, 1+ = side pots) — antes
  /// de saber quién gana. "jugadoresCsv": nombres de quienes compiten por
  /// ESTE bote en concreto, separados por comas — para mostrar de forma
  /// transparente quién puede ganarlo, no solo el monto.
  void boteEvaluado(int numBote, int cantidad, QString jugadoresCsv);
  /// Un jugador enseña su mano en el showdown (cartasCsv: "AS,KH").
  void cartasMostradas(QString jugador, QString cartasCsv, QString combo);
  /// Un jugador se lleva un bote (principal o side pot) en el showdown.
  void boteGanado(QString jugador, int premio, int numBote, QString combo);
  /// Todos se retiraron menos uno — se lleva el bote sin mostrar cartas
  /// (no hay MUESTRA_CARTAS). Main.qml reutiliza el overlay de showdown
  /// para este caso también, con una única tarjeta sin cartas.
  void ganadorSinShowdown(QString jugador, int bote);

 private:
  void enviarMensaje(const net::Message& msg) {
    uint32_t len =
        qToBigEndian<uint32_t>(static_cast<uint32_t>(msg.payload.size()));
    socket_.write(reinterpret_cast<const char*>(&len), 4);
    socket_.write(msg.payload.data(), static_cast<qint64>(msg.payload.size()));
  }

  /**
   * @brief *Pinning* de certificado -- se conecta a sslErrors() de
   * cualquier QSslSocket (persistente o efímero) para decidir si vale la
   * pena ignorar sus errores.
   *
   * El servidor usa un certificado autofirmado (no hay CA pública para
   * un servidor propio, ver scripts/generar_cert_tls.sh) -- sin esto, Qt
   * aborta SIEMPRE la conexión por "certificado autofirmado". PERO
   * ignorarlo a ciegas (sslErrors conectado a ignoreSslErrors() sin
   * condición) es exactamente el patrón "TrustManager inseguro" que el
   * escáner de Google Play Console marca en el pre-launch report --
   * aceptaría CUALQUIER certificado, no solo el nuestro.
   *
   * Por eso: solo se ignora si el ÚNICO error reportado es
   * "certificado autofirmado" Y la clave pública del certificado
   * recibido coincide EXACTAMENTE (SHA-256) con
   * net::SERVER_CERT_PIN_SHA256 (ver ServerConfig.hpp, calculado por el
   * script al generar el certificado). Cualquier otro caso -- hash
   * distinto, o cualquier error que no sea ese -- se deja sin ignorar:
   * Qt aborta la conexión sola, y errorOccurred()/el timeout de
   * enviarPeticionEfimera() ya manejan ese fallo como cualquier otro.
   */
  static void gestionarErroresSsl(QSslSocket* sock, const QList<QSslError>& errores) {
    if (errores.size() != 1 || errores.first().error() != QSslError::SelfSignedCertificate) {
      return;
    }
    QByteArray huella = QCryptographicHash::hash(
        errores.first().certificate().publicKey().toDer(), QCryptographicHash::Sha256).toHex();
    if (huella == QByteArray(net::SERVER_CERT_PIN_SHA256)) {
      sock->ignoreSslErrors();
    }
  }

  /**
   * @brief Socket efímero: manda @p msgSaliente, espera UNA respuesta y
   * cierra — mismo patrón que ya usaba refrescarSalas() a mano, extraído
   * aquí porque ahora lo reutilizan cuatro operaciones distintas (listar/
   * renombrar/borrar partidas guardadas, además de listar salas). NO usa
   * socket_/la conexión persistente: son consultas puntuales de antes de
   * unirse a nada, y el servidor cierra el fd tras responder.
   * @param alRecibir Recibe el payload JSON completo ("" si falló la
   * conexión); construye el signal Qt correspondiente.
   */
  void enviarPeticionEfimera(const QString& host, quint16 puerto,
                             const net::Message& msgSaliente,
                             std::function<void(const std::string&)> alRecibir) {
    auto* sock = new QSslSocket(this);
    auto buffer = std::make_shared<QByteArray>();
    // Evita que alRecibir() se dispare dos veces (p. ej. el timeout de
    // abajo Y un errorOccurred casi simultáneo al hacer sock->abort()).
    auto respondido = std::make_shared<bool>(false);
    connect(sock, &QSslSocket::sslErrors, sock, [sock](const QList<QSslError>& errores) {
      gestionarErroresSsl(sock, errores);
    });
    // encrypted(), no connected(): connected() solo confirma el TCP
    // crudo -- mandar el mensaje ahí sería mandarlo antes de que el
    // *handshake* TLS termine.
    connect(sock, &QSslSocket::encrypted, sock, [sock, msgSaliente]() {
      uint32_t len = qToBigEndian<uint32_t>(static_cast<uint32_t>(msgSaliente.payload.size()));
      sock->write(reinterpret_cast<const char*>(&len), 4);
      sock->write(msgSaliente.payload.data(), static_cast<qint64>(msgSaliente.payload.size()));
    });
    connect(sock, &QSslSocket::readyRead, sock, [sock, buffer, alRecibir, respondido]() {
      *buffer += sock->readAll();
      if (buffer->size() < 4) return;
      uint32_t n = qFromBigEndian<uint32_t>(
          reinterpret_cast<const uchar*>(buffer->constData()));
      if (buffer->size() < static_cast<int>(4 + n)) return;
      std::string payload(buffer->constData() + 4, n);
      if (!*respondido) { *respondido = true; alRecibir(payload); }
      sock->disconnectFromHost();
    });
    connect(sock, &QSslSocket::errorOccurred, sock, [sock, alRecibir, respondido]() {
      if (!*respondido) { *respondido = true; alRecibir(""); }  // fallo silencioso: quien llama decide qué mostrar con un payload vacío
      sock->deleteLater();
    });
    connect(sock, &QSslSocket::disconnected, sock, &QObject::deleteLater);
    // Timeout explícito -- sin esto, connectToHost() contra una IP
    // inalcanzable de verdad (p. ej. la IP de Tailscale tras apagar la
    // VPN, sin RST ni ICMP de vuelta) se queda colgado lo que tarde el
    // SO en agotar sus reintentos de SYN -- en Linux, con los valores por
    // defecto, más de un minuto. El indicador de conexión de Inicio
    // sondea cada 12s sin cancelar el intento anterior, así que sin este
    // timeout se quedaba pegado en "conectado" mucho más de lo esperable
    // tras cortar la VPN (bug real reportado: quitar la VPN no hacía
    // volver el indicador a "sin conexión").
    QTimer::singleShot(4000, sock, [sock, alRecibir, respondido]() {
      if (*respondido) return;
      *respondido = true;
      alRecibir("");
      sock->abort();
    });
    sock->connectToHostEncrypted(host, puerto);
  }

  /// Arranca (o reinicia) la ventana de reintentos de 60s tras perder la conexión.
  void iniciarReconexion() {
    reconectando_ = true;
    relojReconexion_.start();
    segundosReconexionRestantes_ = 60;
    emit reconectando(segundosReconexionRestantes_);
    timerReintento_.start();
  }

  /// Segundos reales restantes de la ventana de 60s, medidos contra
  /// relojReconexion_ (reloj de pared) en vez de contar "ticks" del
  /// QTimer de 2s — ver el porqué en intentarReconexionAhora().
  int segundosRealesRestantes() const {
    return std::max(0, 60 - static_cast<int>(relojReconexion_.elapsed() / 1000));
  }

 public:
  /**
   * @brief Un intento de reconexión, ahora mismo — comparte lógica entre
   * el QTimer de 2s y la llamada explícita al volver de segundo plano
   * (ver aplicarPantallaInmersiva()/applicationStateChanged en
   * main-mobile.cpp).
   *
   * Antes, la ventana de 60s se llevaba restando "2" a un contador cada
   * vez que el QTimer disparaba — asumiendo que cada disparo representa
   * siempre 2 segundos reales. En Android, un móvil suspendido (pantalla
   * apagada) puede congelar el bucle de eventos de la app entero durante
   * la suspensión: ningún QTimer dispara mientras tanto. Al volver, el
   * temporizador se reanuda con normalidad, pero como el contador nunca
   * avanzó durante la suspensión, la ventana de 60s "efectivos" podía
   * alargarse muchísimo más allá de 60 segundos reales — el bucle de
   * "reconectando" que se ve en el móvil, disparando cada 2s sin llegar
   * nunca a agotarse. El reemplazo mide contra relojReconexion_ (reloj de
   * pared real, con QElapsedTimer, que SÍ seguía corriendo mientras la
   * app estaba suspendida) en vez de contar disparos — así la ventana de
   * 60s es de verdad 60 segundos de reloj, pase lo que pase con el bucle
   * de eventos mientras tanto. Además, llamarlo explícitamente al
   * reanudar la app fuerza un intento inmediato en vez de esperar a que
   * el próximo tick del QTimer (que pudo quedar con retraso) dispare.
   */
  void intentarReconexionAhora() {
    if (!reconectando_) return;  // nada que reintentar ahora mismo
    int restantes = segundosRealesRestantes();
    if (restantes <= 0) {
      timerReintento_.stop();
      reconectando_ = false;
      esperandoConfirmacionTrasReconectar_ = false;
      emit reconexionFallida();
      return;
    }
    segundosReconexionRestantes_ = restantes;
    emit reconectando(restantes);
    if (esperandoConfirmacionTrasReconectar_) {
      // Bug real encontrado en vivo: este método se llama cada 2s pase lo
      // que pase, y ANTES hacía socket_.abort()+connectToHost() sin mirar
      // si ya había un intento en curso -- en una red con latencia real
      // (RTT + hasta 300ms de poll del lado servidor antes de que
      // comprobarReconexiones() procese el JOIN_LOBBY), la vuelta completa
      // podía tardar más de 2s. El propio timer entonces abortaba SU
      // PROPIO intento a medias antes de que la confirmación llegara,
      // reiniciando el handshake una y otra vez sin dejarlo nunca
      // completarse -- el temporizador de 60s bajaba con normalidad pero
      // la reconexión, en la práctica, nunca tenía ocasión real de
      // terminar. Mientras esperandoConfirmacionTrasReconectar_ sea true
      // ya hay un socket conectado y un JOIN_LOBBY en camino: dejarlo
      // seguir en vez de cortarlo. Si ESTE intento en concreto vuelve a
      // caer antes de confirmar, errorOccurred() (más abajo) limpia el
      // flag para que el próximo tick sí reintente desde cero.
      return;
    }
    socket_.abort();
    socket_.connectToHostEncrypted(hostGuardado_, puertoGuardado_);
  }

 private:
  /**
   * @brief Conexión persistente compartida por conectar()/crearSala()/unirseASala().
   *
   * Las tres solo difieren en el PRIMER mensaje que mandan al conectar
   * (JOIN_LOBBY / CREATE_GAME / JOIN_GAME) — todo lo demás (reconexión,
   * framing, despacho de mensajes entrantes) es idéntico, así que vive una
   * sola vez aquí en vez de triplicarse.
   */
  void iniciarConexionConMensaje(const QString& host, quint16 puerto,
                                 QString nombre, net::Message primerMensaje) {
    nombre_ = nombre;
    hostGuardado_ = host;
    puertoGuardado_ = puerto;
    // Nueva sesión de verdad (no un reintento de reconexión, que no pasa
    // por aquí -- ver intentarReconexionAhora()): todavía no hay
    // PARTIDA_INICIADA para ESTA sesión. salaIdActual_/codigoActual_ los
    // gestiona cada Q_INVOKABLE (conectar/crearSala/unirseASala) por su
    // cuenta, antes de llamar aquí -- tocarlos en este punto compartido
    // pisaría el valor que unirseASala() ya dejó puesto justo antes.
    enPartida_ = false;
    // Miembro, no capturado por valor en la lambda de "connected": esta
    // función puede llamarse varias veces (reintentar tras un ERROR_NOMBRE
    // con otro nombre, por ejemplo) — si las señales de socket_ solo se
    // conectan UNA vez (ver el "if" de abajo), la lambda ya conectada tiene
    // que leer el mensaje ACTUAL, no el que había la primera vez que se
    // llamó. Antes, cada llamada añadía una conexión más sin quitar la
    // anterior: al reconectar, TODAS disparaban a la vez y se reenviaba
    // también el primer intento (con el nombre ya rechazado).
    primerMensajePendiente_ = std::move(primerMensaje);

    if (senalesConectadas_) {
      // abort() primero: si ya hay un intento en curso (doble clic, o un
      // "Refrescar"/conexión anterior que no ha terminado de resolverse),
      // connectToHost() sobre un socket todavía conectando/conectado
      // dispara el aviso de Qt "called when already looking up or
      // connecting/connected" y se queda sin hacer nada. abort() lo
      // resetea a UnconnectedState de forma segura antes de reintentar.
      socket_.abort();
      socket_.connectToHostEncrypted(host, puerto);
      return;
    }
    senalesConectadas_ = true;

    connect(&socket_, &QSslSocket::sslErrors, this,
            [this](const QList<QSslError>& errores) { gestionarErroresSsl(&socket_, errores); });

    // encrypted(), no connected(): connected() solo confirma el TCP
    // crudo -- el resto de este bloque (reconexión, primer mensaje...)
    // no debe correr hasta que el *handshake* TLS termine de verdad.
    connect(&socket_, &QSslSocket::encrypted, this, [this]() {
      buffer_.clear();
      esperandoHeader_ = true;
      if (reconectando_) {
        // OJO: un connected() aquí es solo el handshake TCP -- NO significa
        // que ya estemos reconectados de verdad. Antes esto ponía
        // reconectando_ = false y emitía reconectado() en este mismo punto;
        // en una red inestable el socket podía conectar y caerse otra vez
        // milisegundos después, antes de que el servidor llegara siquiera a
        // leer el JOIN_LOBBY -- errorOccurred() encontraba reconectando_ ya
        // en false y lo trataba como una caída COMPLETAMENTE NUEVA,
        // reiniciando la ventana de 60s desde cero. Resultado real, visto
        // en el móvil: el aviso de "reconectando" parpadeando y
        // reiniciándose cada 1-2s sin avanzar nunca. reconectando_ se deja
        // en true (y el reintento sigue vivo) hasta que llega la
        // confirmación de verdad: el primer mensaje real del servidor tras
        // el JOIN_LOBBY (ver el bloque que marca esperandoConfirmacionTrasReconectar_
        // más abajo, en el bucle de readyRead).
        esperandoConfirmacionTrasReconectar_ = true;
        // "token": si somos una cuenta, comprobarReconexiones() en el
        // servidor ya exige que coincida con la cuenta que tenía asignada
        // este nombre antes de caerse (ver AccountManager::tokenPerteneceACuenta) --
        // sin mandarlo aquí, una cuenta real nunca podría reconectar sola.
        //
        // JOIN_GAME en vez de JOIN_LOBBY si la caída fue mientras
        // seguíamos en el lobby (partida sin empezar todavía): el
        // dispatcher solo sabe reconectar a una sala EN_CURSO
        // (buscarSalaDeJugadorEnCurso, ver RoomRegistry) -- una sala
        // todavía en LOBBY es invisible por ese camino, así que JOIN_LOBBY
        // ahí no tiene forma de encontrarla nunca (bug real, visto en
        // producción: el temporizador de 60s se agotaba sin ninguna
        // posibilidad real de éxito). JOIN_GAME con el sala_id/código
        // recordados sí la encuentra (estaEnLobbyYHayHueco()), y si para
        // entonces la sala ya pasó a EN_CURSO (el host pulsó "Empezar"
        // justo en ese momento), el dispatcher también lo cubre (ver la
        // rama nueva con tieneJugador() en el bloque JOIN_GAME de
        // server/main.cpp). Una vez PARTIDA_INICIADA llega de verdad,
        // enPartida_ pasa a true y el resto de caídas usa JOIN_LOBBY como
        // siempre (ese camino ya funciona, no se toca).
        if (!enPartida_ && (!salaIdActual_.isEmpty() || !codigoActual_.isEmpty())) {
          enviarMensaje(net::buildMsg(net::MsgType::JOIN_GAME, {
              {"nombre",  nombre_.toStdString()},
              {"sala_id", salaIdActual_.toStdString()},
              {"codigo",  codigoActual_.toStdString()},
              {"token",   token_.toStdString()},
          }));
        } else {
          enviarMensaje(net::buildMsg(net::MsgType::JOIN_LOBBY,
                                      {{"nombre", nombre_.toStdString()},
                                       {"token", token_.toStdString()}}));
        }
      } else {
        conectadoAlgunaVez_ = true;
        emit conectado();
        enviarMensaje(primerMensajePendiente_);
      }
    });

    connect(&socket_, &QSslSocket::errorOccurred, this, [this]() {
      if (reconectando_) {
        // Este intento concreto (con o sin TCP ya establecido) acaba de
        // fallar -- limpiar el flag de "esperando confirmación" para que
        // el PRÓXIMO tick de timerReintento_ vuelva a intentar
        // socket_.abort()+connectToHost() en vez de quedarse callado para
        // siempre esperando una confirmación que ya no va a llegar por
        // este socket (ver el comentario largo en intentarReconexionAhora()).
        esperandoConfirmacionTrasReconectar_ = false;
        return;
      }
      if (desconexionEsperada_) return;  // salida a propósito (LEAVE/SAVE_AND_EXIT) — no es una caída
      if (conectadoAlgunaVez_) {
        iniciarReconexion();
      } else {
        emit error(socket_.errorString());  // fallo en la conexión inicial
      }
    });

    // Reintentos de reconexión: mismo ritmo que el cliente ncurses
    // (src/client/main.cpp) — un intento cada 2s, hasta 60s en total,
    // igual que la ventana que espera el servidor (NetworkObserver::waitReconnect).
    timerReintento_.setInterval(2000);
    connect(&timerReintento_, &QTimer::timeout, this,
            [this]() { intentarReconexionAhora(); });
    connect(&socket_, &QSslSocket::readyRead, this, [this]() {
      buffer_ += socket_.readAll();  // todo lo que ha llegado se ACUMULA aquí

      while (true) {
        if (esperandoHeader_ && buffer_.size() >= 4) {
          longitudEsperada_ = qFromBigEndian<uint32_t>(
              reinterpret_cast<const uchar*>(buffer_.constData()));
          buffer_.remove(0, 4);  // ya leídos, fuera del buffer
          esperandoHeader_ = false;
        }
        if (!esperandoHeader_ &&
            buffer_.size() >= static_cast<int>(longitudEsperada_)) {
          std::string payload(buffer_.constData(), longitudEsperada_);
          buffer_.remove(0, longitudEsperada_);
          esperandoHeader_ = true;  // listo para el próximo mensaje

          // Confirmación real de reconexión: el primer mensaje que de
          // verdad llega del servidor tras el connected()+JOIN_LOBBY de
          // más arriba. Solo AQUÍ se puede dar la reconexión por buena
          // (ver el porqué en el comentario de connected()).
          if (esperandoConfirmacionTrasReconectar_) {
            esperandoConfirmacionTrasReconectar_ = false;
            reconectando_ = false;
            timerReintento_.stop();
            emit reconectado();
          }

          qDebug() << "Mensaje completo:" << QString::fromStdString(payload);
          std::string tipo = net::jsonGetStr(payload, "type");
          if (tipo == "LOBBY_UPDATE") {
            QString jugadores =
                QString::fromStdString(net::jsonGetStr(payload, "jugadores"));
            int listos = net::jsonGetInt(payload, "listos");
            int esperados = net::jsonGetInt(payload, "esperados");
            QString host = QString::fromStdString(net::jsonGetStr(payload, "host"));
            // Solo viene relleno al reanudar una partida guardada — los
            // nombres humanos que grabó el snapshot, para que quien entra
            // sepa con qué nombre unirse aunque no lo recuerde.
            QString esperadosNombres =
                QString::fromStdString(net::jsonGetStr(payload, "esperados_nombres"));
            emit lobbyActualizado(jugadores, listos, esperados, host, esperadosNombres);
          } else if (tipo == "CHAT") {
            QString de = QString::fromStdString(net::jsonGetStr(payload, "de"));
            QString texto =
                QString::fromStdString(net::jsonGetStr(payload, "texto"));
            QString canal =
                QString::fromStdString(net::jsonGetStr(payload, "canal"));
            emit chatRecibido(de, texto, canal);
          } else if (tipo == "GAME_EVENT") {
            std::string evento = net::jsonGetStr(payload, "evento");
            if (evento == "PARTIDA_INICIADA") {
              // A partir de aquí, si la conexión se cae, la reconexión
              // debe usar JOIN_LOBBY (camino ya probado, ver
              // intentarReconexionAhora()) en vez de JOIN_GAME -- la sala
              // ya no está en lobby.
              enPartida_ = true;
              int manos = net::jsonGetInt(payload, "manos");
              int tipoLimite = net::jsonGetInt(payload, "tipo_limite");
              bool permitirRecompra = net::jsonGetInt(payload, "permitir_recompra") == 1;
              bool rellenarConBots = net::jsonGetInt(payload, "rellenar_con_bots") == 1;
              // jsonGetInt da 0 (false) si el servidor no manda el campo
              // (partida legacy vieja) -- pero el comportamiento de
              // siempre en la sala legacy SIEMPRE pregunta, así que
              // tratar "ausente" como true (no false, a diferencia de los
              // otros campos de arriba) es lo que de verdad coincide con
              // lo que esa sala hace.
              bool preguntarExtension = net::jsonGetStr(payload, "preguntar_extension").empty()
                                             ? true
                                             : net::jsonGetInt(payload, "preguntar_extension") == 1;
              emit partidaIniciada(manos, tipoLimite, permitirRecompra, rellenarConBots,
                                   preguntarExtension);
            } else if (evento == "NOMBRE_ASIGNADO") {
              // El nombre con el que el servidor nos identifica de verdad
              // (puede diferir del que escribimos, si llegó vacío o el
              // servidor lo sanitizó) — sin esto, enviarChat()/comprobar si
              // somos el host seguían usando la copia local, desincronizada.
              nombre_ = QString::fromStdString(net::jsonGetStr(payload, "nombre"));
              emit nombreAsignado(nombre_);
            } else if (evento == "EN_ESPERA") {
              QString mensaje = QString::fromStdString(net::jsonGetStr(payload, "mensaje"));
              emit enEspera(mensaje);
            } else if (evento == "SALA_ESPERANDO_UPDATE") {
              QString csv = QString::fromStdString(net::jsonGetStr(payload, "jugadores"));
              QStringList nombres = csv.isEmpty() ? QStringList{} : csv.split(',');
              emit salaEsperandoActualizada(nombres);
            } else if (evento == "TUS_CARTAS") {
              QString c1 = QString::fromStdString(net::jsonGetStr(payload, "c1"));
              QString c2 = QString::fromStdString(net::jsonGetStr(payload, "c2"));
              emit misCartasRepartidas(c1, c2);
            } else if (evento == "SALA_CREADA") {
              QString salaId = QString::fromStdString(net::jsonGetStr(payload, "sala_id"));
              QString codigo = QString::fromStdString(net::jsonGetStr(payload, "codigo"));
              // Igual que en unirseASala(): recordados para poder mandar
              // JOIN_GAME (no JOIN_LOBBY) si la conexión se cae mientras
              // seguimos en el lobby de ESTA sala recién creada.
              salaIdActual_ = salaId;
              codigoActual_ = codigo;
              emit salaCreada(salaId, codigo);
            } else if (evento == "ERROR_SALA") {
              QString mensaje = QString::fromStdString(net::jsonGetStr(payload, "mensaje"));
              // Mismo motivo que ERROR_NOMBRE más abajo: el servidor cierra
              // el socket justo después — no hay nada que reconectar.
              conectadoAlgunaVez_ = false;
              emit errorSala(mensaje);
            } else if (evento == "ERROR_NOMBRE") {
              QString mensaje = QString::fromStdString(net::jsonGetStr(payload, "mensaje"));
              // El servidor cierra el socket justo después de este evento
              // (nombre no reconocido en una partida guardada). Sin esto,
              // el cierre que sigue dispararía el reintento de reconexión
              // de 60s por error — aquí no hay nada que reconectar, solo
              // hay que dejar que el usuario pruebe otro nombre.
              conectadoAlgunaVez_ = false;
              emit nombreRechazado(mensaje);
            } else if (evento == "INICIO_MANO") {
              int mano = net::jsonGetInt(payload, "mano");
              int ciega = net::jsonGetInt(payload, "ciega");
              emit nuevaMano(mano, ciega);
              emit eventoJuego("── Mano " + QString::number(mano) + " · Ciega " +
                                QString::number(ciega / 2) + "/" + QString::number(ciega) +
                                " ──", "separador");
            } else if (evento == "CIEGAS") {
              QString jPequena =
                  QString::fromStdString(net::jsonGetStr(payload, "jp"));
              int montoPequena = net::jsonGetInt(payload, "mp");
              QString jGrande =
                  QString::fromStdString(net::jsonGetStr(payload, "jg"));
              int montoGrande = net::jsonGetInt(payload, "mg");
              emit eventoJuego(": ciega pequeña (" + QString::number(montoPequena) + ")",
                                "sistema", jPequena);
              emit eventoJuego(": ciega grande (" + QString::number(montoGrande) + ")",
                                "sistema", jGrande);
            } else if (evento == "COMUNITARIAS") {
              QString fase = QString::fromStdString(net::jsonGetStr(payload, "fase"));
              emit eventoJuego("── " + fase + " ──", "separador");
            } else if (evento == "REPARTO_INICIAL") {
              // Puramente técnico / sin información útil para el
              // historial del jugador — antes caía en el genérico de más
              // abajo y dejaba una línea sin sentido ("REPARTO_INICIAL")
              // en medio del historial. "COMBO_UPDATE" ya NO va aquí: caía
              // en esta rama por delante de la suya propia (más abajo, ver
              // "BUG corregido") y la dejaba inalcanzable -- por eso la
              // predicción de mano nunca se refrescaba con las cartas
              // comunitarias, solo en el propio turno.
            } else if (evento == "SHOWDOWN") {
              // No va al historial de texto (ya queda anunciado de sobra
              // por las líneas de EVALUANDO_BOTE/MUESTRA_CARTAS que le
              // siguen) — dispara la pantalla de showdown dedicada.
              QString mesa = QString::fromStdString(net::jsonGetStr(payload, "mesa"));
              emit showdownIniciado(mesa);
            } else if (evento == "MODO_ESPECTADOR") {
              emit eventoJuego("El resto de la mano la juegan los bots — no quedan humanos activos.", "sistema");
            } else if (evento == "AVISO_RECOMPRA") {
              bool puedeRecomprar = net::jsonGetInt(payload, "puede_recomprar") == 1;
              emit eventoJuego(puedeRecomprar
                                    ? "Te has quedado sin fichas — puedes pedir recompra."
                                    : "Te has quedado sin fichas.", "error");
              emit avisoRecompra(puedeRecomprar);
            } else if (evento == "ELIMINADOS") {
              QString jugadores =
                  QString::fromStdString(net::jsonGetStr(payload, "jugadores"));
              emit eventoJuego("☠ " + jugadores + " se ha quedado sin fichas", "error");
            } else if (evento == "ERROR_JUGADA") {
              QString mensaje = QString::fromStdString(net::jsonGetStr(payload, "mensaje"));
              emit eventoJuego("⚠ " + mensaje, "error");
            } else if (evento == "ERROR_SISTEMA") {
              QString categoria =
                  QString::fromStdString(net::jsonGetStr(payload, "categoria"));
              QString mensaje = QString::fromStdString(net::jsonGetStr(payload, "mensaje"));
              emit eventoJuego("⚠ [" + categoria + "] " + mensaje, "error");
            } else if (evento == "ACCION") {
              QString jugador =
                  QString::fromStdString(net::jsonGetStr(payload, "jugador"));
              QString accion =
                  QString::fromStdString(net::jsonGetStr(payload, "accion"));
              int cantidad = net::jsonGetInt(payload, "cantidad");
              QString linea = ": " + accion;
              if (cantidad > 0) linea += " " + QString::number(cantidad);
              QString tipoAccion = "accion";
              if (accion == "FOLD") tipoAccion = "fold";
              else if (accion == "RAISE" || accion == "ALL_IN") tipoAccion = "agresion";
              emit eventoJuego(linea, tipoAccion, jugador);
              emit accionRealizada(jugador, accion);
            } else if (evento == "ESPERAR_VOTO") {
              QString mensaje = QString::fromStdString(net::jsonGetStr(payload, "mensaje"));
              emit esperandoVoto(mensaje);
            } else if (evento == "ESPERAR_VOTO_EXTENSION") {
              QString mensaje = QString::fromStdString(net::jsonGetStr(payload, "mensaje"));
              emit esperandoVotoExtension(mensaje);
            } else if (evento == "ELEGIR_MANOS_EXTRA") {
              QString mensaje = QString::fromStdString(net::jsonGetStr(payload, "mensaje"));
              emit elegirManosExtraPedido(mensaje);
            } else if (evento == "ESPERANDO_ELECCION_MANOS") {
              QString mensaje = QString::fromStdString(net::jsonGetStr(payload, "mensaje"));
              QString host = QString::fromStdString(net::jsonGetStr(payload, "host"));
              emit esperandoEleccionManos(mensaje, host);
            } else if (evento == "MESA_UPDATE") {
              QString mesa = QString::fromStdString(net::jsonGetStr(payload, "mesa"));
              emit mesaActualizada(mesa);
            } else if (evento == "EVALUANDO_BOTE") {
              int numBote = net::jsonGetInt(payload, "num_bote");
              int cantidad = net::jsonGetInt(payload, "cantidad");
              // "jugadores" es un campo de texto libre (nombres separados
              // por comas) — va último en el payload por la misma razón de
              // siempre en este protocolo (evitar que un nombre con
              // caracteres raros desalinee campos numéricos detrás suyo).
              QString jugadoresCsv =
                  QString::fromStdString(net::jsonGetStr(payload, "jugadores"));
              QString linea = numBote == 0
                                  ? "── Bote principal (" + QString::number(cantidad) + ")"
                                  : "── Side pot " + QString::number(numBote) + " (" +
                                        QString::number(cantidad) + ")";
              emit eventoJuego(linea, "showdown");
              emit boteEvaluado(numBote, cantidad, jugadoresCsv);
            } else if (evento == "MUESTRA_CARTAS") {
              QString jugador =
                  QString::fromStdString(net::jsonGetStr(payload, "jugador"));
              QString combo = QString::fromStdString(net::jsonGetStr(payload, "combo"));
              QString cartas = QString::fromStdString(net::jsonGetStr(payload, "cartas"));
              emit eventoJuego(": " + cartas + "  " + combo, "showdown", jugador);
              emit cartasMostradas(jugador, cartas, combo);
            } else if (evento == "GANADOR_BOTE") {
              QString jugador =
                  QString::fromStdString(net::jsonGetStr(payload, "jugador"));
              QString combo = QString::fromStdString(net::jsonGetStr(payload, "combo"));
              int premio = net::jsonGetInt(payload, "premio");
              int numBote = net::jsonGetInt(payload, "num_bote");
              emit eventoJuego(": +" + QString::number(premio) + "  (" + combo + ")",
                                "showdown", jugador);
              emit boteGanado(jugador, premio, numBote, combo);
            } else if (evento == "GANADOR_SIN_SHOWDOWN") {
              QString jugador =
                  QString::fromStdString(net::jsonGetStr(payload, "jugador"));
              int bote = net::jsonGetInt(payload, "bote");
              emit eventoJuego(": +" + QString::number(bote), "showdown", jugador);
              emit ganadorSinShowdown(jugador, bote);
            } else if (evento == "PARTIDA_EXTENDIDA") {
              int manos = net::jsonGetInt(payload, "manos");
              int nuevoObjetivo = net::jsonGetInt(payload, "objetivo_nuevo");
              emit eventoJuego("Partida extendida por otras " + QString::number(manos) +
                                " manos", "sistema");
              emit partidaExtendida(manos, nuevoObjetivo);
            } else if (evento == "FIN_PARTIDA" || evento == "FIN_PARTIDA_LIMITE") {
              QString ganador =
                  QString::fromStdString(net::jsonGetStr(payload, "ganador"));
              int saldo = net::jsonGetInt(payload, "saldo");
              manosDisputadasFinal_ = net::jsonGetInt(payload, "manos_disputadas");
              mejorManoFinal_ =
                  QString::fromStdString(net::jsonGetStr(payload, "mejor_mano"));
              mejorManoJugadorFinal_ =
                  QString::fromStdString(net::jsonGetStr(payload, "mejor_mano_jugador"));
              eliminacionesFinalCsv_ =
                  QString::fromStdString(net::jsonGetStr(payload, "eliminaciones"));
              emit estadisticasFinCambiaron();
              emit finDePartida(ganador, saldo, evento == "FIN_PARTIDA_LIMITE");
            } else if (evento == "ABANDONASTE") {
              QString mensaje = QString::fromStdString(net::jsonGetStr(payload, "mensaje"));
              emit abandonaste(mensaje);
            } else if (evento == "JUGADOR_SALE") {
              QString jugador =
                  QString::fromStdString(net::jsonGetStr(payload, "jugador"));
              emit eventoJuego(" ha abandonado la partida", "sistema", jugador);
            } else if (evento == "RECONECTANDO") {
              QString jugador =
                  QString::fromStdString(net::jsonGetStr(payload, "jugador"));
              int secs = net::jsonGetInt(payload, "secs");
              emit eventoJuego(" se ha desconectado — reconectando (" +
                                QString::number(secs) + "s)", "sistema", jugador);
            } else if (evento == "RECONECTANDO_TICK") {
              // Cuenta atrás segundo a segundo de la reconexión de OTRO
              // jugador — se ignora a propósito (sin este "else if" caería
              // en el genérico de abajo y spamearía el historial una línea
              // por segundo durante toda la ventana de reconexión).
            } else if (evento == "RECONECTADO") {
              QString jugador =
                  QString::fromStdString(net::jsonGetStr(payload, "jugador"));
              emit eventoJuego(" se ha reconectado", "sistema", jugador);
            } else if (evento == "SALDOS_UPDATE") {
              QString jugadoresStr =
                  QString::fromStdString(net::jsonGetStr(payload, "jugadores"));
              emit saldosActualizados(jugadoresStr);
            } else if (evento == "GUARDANDO_PARTIDA") {
              // El host lo pidió, pero el servidor cierra el socket de
              // TODOS los clientes al terminar de guardar — no solo del que
              // lo solicitó — así que cualquiera que reciba esto debe dejar
              // de tratar el cierre que viene a continuación como una caída.
              desconexionEsperada_ = true;
              QString mensaje = QString::fromStdString(net::jsonGetStr(payload, "mensaje"));
              emit eventoJuego(mensaje, "sistema");
            } else if (evento == "PARTIDA_GUARDADA") {
              QString archivo = QString::fromStdString(net::jsonGetStr(payload, "archivo"));
              emit partidaGuardada(archivo);
            } else if (evento == "COMBO_UPDATE") {
              // BUG corregido: esta rama quedaba inalcanzable -- un "else
              // if" anterior (ver "REPARTO_INICIAL" arriba) también
              // matcheaba "COMBO_UPDATE" y ganaba siempre por ir primero,
              // así que la predicción de mano solo se actualizaba dentro
              // de esMiTurno() y se quedaba congelada hasta que volvía a
              // tocarte, en cada ronda.
              QString actual = QString::fromStdString(net::jsonGetStr(payload, "combo_actual"));
              QString probable = QString::fromStdString(net::jsonGetStr(payload, "combo_probable"));
              QString maxima = QString::fromStdString(net::jsonGetStr(payload, "combo_maxima"));
              emit comboActualizado(actual, probable, maxima);
            } else {
              // Antes esto volcaba el nombre crudo del evento al historial
              // ("COMUNITARIAS"...) para CUALQUIER tipo no
              // contemplado explícitamente arriba — ruido garantizado cada
              // vez que se añadía un evento nuevo al protocolo sin acordarse
              // de tratarlo aquí. Mejor lista blanca: lo que no se reconoce
              // se ignora en vez de mostrarse tal cual.
            }
          } else if (tipo == "GAME_STATE") {
            QString ronda =
                QString::fromStdString(net::jsonGetStr(payload, "ronda"));
            int bote = net::jsonGetInt(payload, "bote");
            QString turno =
                QString::fromStdString(net::jsonGetStr(payload, "turno"));
            QString jugadoresStr =
                QString::fromStdString(net::jsonGetStr(payload, "jugadores"));
            // jsonGetInt devuelve 0 si el servidor no manda "timeout_ms" (el
            // GAME_STATE que precede a onPreTurnoHumano no lo incluye); 0
            // nunca es un valor real (siempre TURNO_TIMEOUT_MS, 30000), así
            // que Main.qml lo trata como "sin temporizador para este turno".
            int timeoutMs = net::jsonGetInt(payload, "timeout_ms");
            QString dealer =
                QString::fromStdString(net::jsonGetStr(payload, "dealer"));
            QString sb = QString::fromStdString(net::jsonGetStr(payload, "sb"));
            QString bb = QString::fromStdString(net::jsonGetStr(payload, "bb"));
            emit estadoMesaActualizado(ronda, bote, turno, jugadoresStr, timeoutMs,
                                       dealer, sb, bb);
          } else if (tipo == "TU_TURNO") {
            int bote = net::jsonGetInt(payload, "bote");
            int igualar = net::jsonGetInt(payload, "igualar");
            int miSaldo = net::jsonGetInt(payload, "mi_saldo");
            int miApuesta = net::jsonGetInt(payload, "mi_apuesta");
            int timeoutMs = net::jsonGetInt(payload, "timeout_ms");
            int minSubida = net::jsonGetInt(payload, "min_subida");
            int maxSubida = net::jsonGetInt(payload, "max_subida");
            QString c1 = QString::fromStdString(net::jsonGetStr(payload, "c1"));
            QString c2 = QString::fromStdString(net::jsonGetStr(payload, "c2"));
            QString comboActual =
                QString::fromStdString(net::jsonGetStr(payload, "combo_actual"));
            QString comboProbable =
                QString::fromStdString(net::jsonGetStr(payload, "combo_probable"));
            QString comboMaxima =
                QString::fromStdString(net::jsonGetStr(payload, "combo_maxima"));
            emit esMiTurno(bote, igualar, miSaldo, miApuesta, timeoutMs, minSubida, maxSubida, c1,
                           c2, comboActual, comboProbable, comboMaxima);
          }
        } else {
          break;  // no hay bytes suficientes todavía — esperar al próximo
                  // readyRead
        }
      }
    });
    socket_.connectToHostEncrypted(host, puerto);
  }

  bool senalesConectadas_ = false;  // connect() de socket_ solo se hace una vez, ver iniciarConexionConMensaje()
  net::Message primerMensajePendiente_;
  QString nombre_;
  /// Token de sesión de la cuenta activa ("" = invitado). Lo fijan
  /// registrar()/iniciarSesion()/iniciarSesionConToken() al tener éxito y
  /// lo limpia cerrarSesion() -- conectar()/crearSala()/unirseASala()/
  /// cargarPartidaGuardada() lo mandan siempre, vacío o no.
  QString token_;
  QString hostGuardado_;
  quint16 puertoGuardado_ = 0;
  // Sala actual, para poder reconectar con JOIN_GAME (no JOIN_LOBBY) si la
  // caída fue mientras seguíamos en su lobby -- ver
  // intentarReconexionAhora() y el comentario largo ahí. Los rellenan
  // conectar()/crearSala()/unirseASala()/cargarPartidaGuardada() (limpios)
  // y el handler de SALA_CREADA (rellenos, en cuanto se conoce el id real).
  QString salaIdActual_;
  QString codigoActual_;
  // true en cuanto llega GAME_EVENT/PARTIDA_INICIADA de verdad -- a partir
  // de ahí una reconexión ya debe usar JOIN_LOBBY como siempre (la sala ya
  // no está en lobby). false de nuevo al arrancar cualquier conexión nueva
  // (ver iniciarConexionConMensaje()), nunca durante un simple reintento.
  bool enPartida_ = false;
  bool conectadoAlgunaVez_ = false;
  bool reconectando_ = false;
  bool esperandoConfirmacionTrasReconectar_ = false;  // ver connected(), no basta con el handshake TCP
  bool desconexionEsperada_ = false;  // LEAVE/SAVE_AND_EXIT: cierre a propósito, no una caída
  int segundosReconexionRestantes_ = 0;
  QElapsedTimer relojReconexion_;  // reloj de pared real, ver intentarReconexionAhora()
  QTimer timerReintento_;
  QByteArray buffer_;
  bool esperandoHeader_ = true;
  uint32_t longitudEsperada_ = 0;
  QSslSocket socket_;

  int manosDisputadasFinal_ = 0;
  QString mejorManoFinal_;
  QString mejorManoJugadorFinal_;
  QString eliminacionesFinalCsv_;
  QVariantMap estadisticasCuenta_;
};
