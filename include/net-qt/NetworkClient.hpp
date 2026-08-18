#pragma once

#include <functional>
#include <memory>

#include <QDebug>
#include <QObject>
#include <QTcpSocket>
#include <QTimer>

#include "../net/Protocol.hpp"
#include "QtEndian"  // qToBigEndian

class NetworkClient : public QObject {
  Q_OBJECT
 public:
  using QObject::QObject;

  Q_INVOKABLE void conectar(const QString& host, quint16 puerto,
                            QString nombre) {
    iniciarConexionConMensaje(host, puerto, nombre,
        net::buildMsg(net::MsgType::JOIN_LOBBY, {{"nombre", nombre.toStdString()}}));
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
                             bool rellenarConBots, bool abiertaTrasInicio) {
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
    }));
  }

  /// Unirse a una sala existente (pantalla "Salas disponibles"), por id
  /// (de la lista) o por código (sala privada) — el que esté vacío se
  /// ignora en el servidor.
  Q_INVOKABLE void unirseASala(const QString& host, quint16 puerto, QString nombre,
                               QString salaId, QString codigo) {
    iniciarConexionConMensaje(host, puerto, nombre, net::buildMsg(net::MsgType::JOIN_GAME, {
        {"nombre",  nombre.toStdString()},
        {"sala_id", salaId.toStdString()},
        {"codigo",  codigo.toStdString()},
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

  /// Pide la lista de partidas guardadas (.pok) del servidor — mismo
  /// patrón efímero que refrescarSalas().
  Q_INVOKABLE void listarGuardadas(const QString& host, quint16 puerto) {
    enviarPeticionEfimera(host, puerto, net::buildMsg(net::MsgType::LISTAR_GUARDADAS),
        [this](const std::string& payload) {
          emit guardadasActualizadas(
              QString::fromStdString(net::jsonGetStr(payload, "guardadas")));
        });
  }

  /// Renombra un archivo .pok existente.
  Q_INVOKABLE void renombrarGuardada(const QString& host, quint16 puerto,
                                     QString archivo, QString nuevoNombre) {
    enviarPeticionEfimera(host, puerto,
        net::buildMsg(net::MsgType::RENOMBRAR_GUARDADA, {
            {"archivo",      archivo.toStdString()},
            {"nuevo_nombre", nuevoNombre.toStdString()},
        }),
        [this](const std::string& payload) {
          emit guardadaRenombrada(
              QString::fromStdString(net::jsonGetStr(payload, "mensaje")));
        });
  }

  /// Borra un archivo .pok existente.
  Q_INVOKABLE void borrarGuardada(const QString& host, quint16 puerto, QString archivo) {
    enviarPeticionEfimera(host, puerto,
        net::buildMsg(net::MsgType::BORRAR_GUARDADA, {{"archivo", archivo.toStdString()}}),
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
    iniciarConexionConMensaje(host, puerto, nombre, net::buildMsg(net::MsgType::CARGAR_PARTIDA, {
        {"nombre",      nombre.toStdString()},
        {"archivo",     archivo.toStdString()},
        {"nombre_sala", nombreSala.toStdString()},
        {"publica",     publica ? "1" : "0"},
    }));
  }

  Q_INVOKABLE void enviarChat(const QString& texto) {
    enviarMensaje(net::buildMsg(
        net::MsgType::CHAT,
        {{"de", nombre_.toStdString()}, {"texto", texto.toStdString()}}));
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

  Q_INVOKABLE void abandonar() {
    desconexionEsperada_ = true;  // el servidor va a cerrar nuestro socket a propósito
    enviarMensaje(net::buildMsg(net::MsgType::ACTION, {{"accion", "LEAVE"}}));
  }

  Q_INVOKABLE void guardarYSalir() {
    desconexionEsperada_ = true;
    enviarMensaje(net::buildMsg(net::MsgType::ACTION, {{"accion", "SAVE_AND_EXIT"}}));
  }

 signals:
  void conectado();
  void error(QString msg);
  void lobbyActualizado(QString jugadoresCsv, int listos, int esperados, QString host,
                        QString esperadosNombresCsv);
  void chatRecibido(QString de, QString texto);
  /**
   * @brief La partida empieza — además de la señal, ahora trae las
   * reglas de la sala (fijas toda la sesión) para la sección "Mesa
   * actual" del cajón de ajustes.
   * @param manos Objetivo de manos de la sesión (0 si no llegó, por
   * compatibilidad con GAME_EVENT/PARTIDA_INICIADA sin estos campos).
   * @param tipoLimite 0=Sin límite, 1=Límite bote, 2=Límite fijo (mismo
   * enum que TipoLimite en GameTypes.hpp).
   */
  void partidaIniciada(int manos, int tipoLimite, bool permitirRecompra, bool rellenarConBots);
  void estadoMesaActualizado(QString ronda, int bote, QString turno,
                             QString jugadoresStr, int timeoutMs);
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
  void esperandoVotoExtension(QString mensaje, int manos);
  void mesaActualizada(QString mesa);
  void finDePartida(QString ganador, int saldo, bool porLimite);
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
  /// Respuesta a listarGuardadas(): "archivo:fecha:humanos:bots;..." (puede ser "").
  void guardadasActualizadas(QString guardadasCsv);
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
    auto* sock = new QTcpSocket(this);
    auto buffer = std::make_shared<QByteArray>();
    connect(sock, &QTcpSocket::connected, sock, [sock, msgSaliente]() {
      uint32_t len = qToBigEndian<uint32_t>(static_cast<uint32_t>(msgSaliente.payload.size()));
      sock->write(reinterpret_cast<const char*>(&len), 4);
      sock->write(msgSaliente.payload.data(), static_cast<qint64>(msgSaliente.payload.size()));
    });
    connect(sock, &QTcpSocket::readyRead, sock, [sock, buffer, alRecibir]() {
      *buffer += sock->readAll();
      if (buffer->size() < 4) return;
      uint32_t n = qFromBigEndian<uint32_t>(
          reinterpret_cast<const uchar*>(buffer->constData()));
      if (buffer->size() < static_cast<int>(4 + n)) return;
      std::string payload(buffer->constData() + 4, n);
      alRecibir(payload);
      sock->disconnectFromHost();
    });
    connect(sock, &QTcpSocket::errorOccurred, sock, [sock, alRecibir]() {
      alRecibir("");  // fallo silencioso: quien llama decide qué mostrar con un payload vacío
      sock->deleteLater();
    });
    connect(sock, &QTcpSocket::disconnected, sock, &QObject::deleteLater);
    sock->connectToHost(host, puerto);
  }

  /// Arranca (o reinicia) la ventana de reintentos de 60s tras perder la conexión.
  void iniciarReconexion() {
    reconectando_ = true;
    segundosReconexionRestantes_ = 60;
    emit reconectando(segundosReconexionRestantes_);
    timerReintento_.start();
  }

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
      socket_.connectToHost(host, puerto);
      return;
    }
    senalesConectadas_ = true;

    connect(&socket_, &QTcpSocket::connected, this, [this]() {
      buffer_.clear();
      esperandoHeader_ = true;
      if (reconectando_) {
        // El servidor ya nos conoce por nombre (waitReconnect); no hace
        // falta re-emitir "conectado" — eso reiniciaría al cliente a la
        // pantalla de Lobby aunque estuviéramos a mitad de partida. La
        // reconexión SIEMPRE es JOIN_LOBBY, nunca el primerMensaje original
        // (que solo tiene sentido la primera vez).
        reconectando_ = false;
        timerReintento_.stop();
        enviarMensaje(net::buildMsg(net::MsgType::JOIN_LOBBY,
                                    {{"nombre", nombre_.toStdString()}}));
        emit reconectado();
      } else {
        conectadoAlgunaVez_ = true;
        emit conectado();
        enviarMensaje(primerMensajePendiente_);
      }
    });

    connect(&socket_, &QTcpSocket::errorOccurred, this, [this]() {
      if (reconectando_) return;  // el propio timerReintento_ ya reintenta
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
    connect(&timerReintento_, &QTimer::timeout, this, [this]() {
      segundosReconexionRestantes_ -= 2;
      if (segundosReconexionRestantes_ <= 0) {
        timerReintento_.stop();
        reconectando_ = false;
        emit reconexionFallida();
        return;
      }
      emit reconectando(segundosReconexionRestantes_);
      socket_.abort();
      socket_.connectToHost(hostGuardado_, puertoGuardado_);
    });
    connect(&socket_, &QTcpSocket::readyRead, this, [this]() {
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
            emit chatRecibido(de, texto);
          } else if (tipo == "GAME_EVENT") {
            std::string evento = net::jsonGetStr(payload, "evento");
            if (evento == "PARTIDA_INICIADA") {
              int manos = net::jsonGetInt(payload, "manos");
              int tipoLimite = net::jsonGetInt(payload, "tipo_limite");
              bool permitirRecompra = net::jsonGetInt(payload, "permitir_recompra") == 1;
              bool rellenarConBots = net::jsonGetInt(payload, "rellenar_con_bots") == 1;
              emit partidaIniciada(manos, tipoLimite, permitirRecompra, rellenarConBots);
            } else if (evento == "NOMBRE_ASIGNADO") {
              // El nombre con el que el servidor nos identifica de verdad
              // (puede diferir del que escribimos, si llegó vacío o el
              // servidor lo sanitizó) — sin esto, enviarChat()/comprobar si
              // somos el host seguían usando la copia local, desincronizada.
              nombre_ = QString::fromStdString(net::jsonGetStr(payload, "nombre"));
              emit nombreAsignado(nombre_);
            } else if (evento == "TUS_CARTAS") {
              QString c1 = QString::fromStdString(net::jsonGetStr(payload, "c1"));
              QString c2 = QString::fromStdString(net::jsonGetStr(payload, "c2"));
              emit misCartasRepartidas(c1, c2);
            } else if (evento == "SALA_CREADA") {
              QString salaId = QString::fromStdString(net::jsonGetStr(payload, "sala_id"));
              QString codigo = QString::fromStdString(net::jsonGetStr(payload, "codigo"));
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
            } else if (evento == "REPARTO_INICIAL" || evento == "COMBO_UPDATE") {
              // Puramente técnicos / sin información útil para el
              // historial del jugador — antes cada uno de estos caía en
              // el genérico de más abajo y dejaba una línea sin sentido
              // ("REPARTO_INICIAL", "COMBO_UPDATE"...) en medio del historial.
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
              int manos = net::jsonGetInt(payload, "manos");
              emit esperandoVotoExtension(mensaje, manos);
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
              emit eventoJuego("Partida extendida por otras " + QString::number(manos) +
                                " manos", "sistema");
            } else if (evento == "FIN_PARTIDA" || evento == "FIN_PARTIDA_LIMITE") {
              QString ganador =
                  QString::fromStdString(net::jsonGetStr(payload, "ganador"));
              int saldo = net::jsonGetInt(payload, "saldo");
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
              // BUG corregido: esto caía en el "else" de abajo y se
              // ignoraba sin más — la predicción de mano solo se
              // actualizaba dentro de esMiTurno(), así que se quedaba
              // congelada hasta que volvía a tocarte, en cada ronda.
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
            emit estadoMesaActualizado(ronda, bote, turno, jugadoresStr, timeoutMs);
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
    socket_.connectToHost(host, puerto);
  }

  bool senalesConectadas_ = false;  // connect() de socket_ solo se hace una vez, ver iniciarConexionConMensaje()
  net::Message primerMensajePendiente_;
  QString nombre_;
  QString hostGuardado_;
  quint16 puertoGuardado_ = 0;
  bool conectadoAlgunaVez_ = false;
  bool reconectando_ = false;
  bool desconexionEsperada_ = false;  // LEAVE/SAVE_AND_EXIT: cierre a propósito, no una caída
  int segundosReconexionRestantes_ = 0;
  QTimer timerReintento_;
  QByteArray buffer_;
  bool esperandoHeader_ = true;
  uint32_t longitudEsperada_ = 0;
  QTcpSocket socket_;
};
