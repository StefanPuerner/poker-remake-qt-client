/**
 * @file ModoJuegoCoordinador.hpp
 * @brief Reasigna "redcliente" entre NetworkClient y LocalGameClient, y mantiene la identidad cacheada.
 */
#pragma once

#include <QObject>
#include <QQmlContext>
#include <QSettings>

#include "../net-qt/NetworkClient.hpp"
#include "LocalGameClient.hpp"

/**
 * @brief Une los dos clientes: el de red y el local. Dos responsabilidades,
 * las dos de "pegamento", ninguna de las cuales encaja dentro de ninguno de
 * los dos clientes (que no se conocen entre sí a propósito):
 *
 *  1. **Reasignar el context property "redcliente"** -- QML decide cuándo
 *     (p. ej. "Jugar" en Torneos > Solitario) llamando a
 *     activarModoLocal()/activarModoRed(). Confirmado en un proyecto Qt
 *     aislado (docs/plan-modo-offline.md sección 6) que reasignar un
 *     context property en caliente se propaga de inmediato a cualquier
 *     binding/Connections que lo use, incluso dentro del mismo bloque de JS
 *     que hizo la reasignación -- por eso "modoJuego.activarModoLocal();
 *     redcliente.iniciarPartidaLocal(...)" en dos líneas seguidas ya usa el
 *     objeto nuevo en la segunda línea.
 *
 *  2. **Cachear la identidad de la cuenta** en LocalGameClient cada vez que
 *     el servidor manda datos frescos. Se hace aquí, en C++, y no en QML, a
 *     propósito: así no hay ningún camino por el que un handler nuevo de
 *     Main.qml se olvide de cachear. LocalGameClient es quien persiste
 *     (QSettings) y quien expone los datos a QML -- ver sus Q_PROPERTY.
 */
class ModoJuegoCoordinador : public QObject {
  Q_OBJECT
  // Inicio necesita saber si hay cuenta cacheada ANTES de decidir nada, y
  // en ese momento "redcliente" todavía es el NetworkClient -- por eso se
  // consultan aquí (este objeto está siempre disponible como "modoJuego",
  // pase lo que pase con el swap) y no en LocalGameClient. Q_PROPERTY con
  // NOTIFY, no Q_INVOKABLE: un binding sobre una función suelta no se
  // refrescaría al iniciar/cerrar sesión.
  Q_PROPERTY(bool hayIdentidadCacheada READ hayIdentidadCacheada NOTIFY identidadCacheadaCambio)
  Q_PROPERTY(QString usernameCacheado READ usernameCacheado NOTIFY identidadCacheadaCambio)
  // XP ganado sin conexión, pendiente de entregar. Se consulta aquí y no en
  // "redcliente" porque hay que leerlo justo cuando redcliente es el
  // NetworkClient (al iniciar sesión), mientras que el dato vive en el
  // cliente local. Ver LocalGameClient::xpOfflinePendiente().
  Q_PROPERTY(int xpOfflinePendiente READ xpOfflinePendiente NOTIFY xpOfflinePendienteCambio)

 public:
  ModoJuegoCoordinador(QQmlContext* contexto, NetworkClient* clienteRed,
                       LocalGameClient* clienteLocal, QObject* parent = nullptr)
      : QObject(parent), contexto_(contexto), clienteRed_(clienteRed), clienteLocal_(clienteLocal) {
    // Estadísticas/loadout: se cachean en cuanto el servidor los manda.
    connect(clienteRed_, &NetworkClient::estadisticasCuentaCambiaron, this, [this]() {
      clienteLocal_->cachearIdentidad(usernameSesion_, clienteRed_->estadisticasCuenta(), {});
    });
    connect(clienteRed_, &NetworkClient::loadoutMarcoCambiaron, this, [this]() {
      clienteLocal_->cachearIdentidad(usernameSesion_, {}, clienteRed_->loadoutMarco());
    });
    // Logros y catálogo de tienda viajan como ARGUMENTO de su señal, no
    // como Q_PROPERTY -- se cachean tal cual llegan. La pestaña Logros es
    // accesible sin conexión, y el catálogo hace falta para resolver el
    // nombre/rareza de un título.
    connect(clienteRed_, &NetworkClient::logrosActualizados, this,
            [this](QVariantList logros) { clienteLocal_->cachearLogros(logros); });
    connect(clienteRed_, &NetworkClient::tiendaActualizada, this,
            [this](QVariantList tienda) { clienteLocal_->cachearTienda(tienda); });
    // El username no tiene getter en NetworkClient -- llega por estas dos
    // señales al autenticarse (y por nombreAsignado si el servidor lo
    // sanea). Se recuerda aquí para acompañar a los dos mapas de arriba.
    connect(clienteRed_, &NetworkClient::loginOk, this,
            [this](int, QString username, QString) { recordarUsername(username); });
    connect(clienteRed_, &NetworkClient::registroOk, this,
            [this](int, QString username, QString) { recordarUsername(username); });
    connect(clienteRed_, &NetworkClient::nombreAsignado, this,
            [this](QString nombre) { recordarUsername(nombre); });
    // Cerrar sesión borra la identidad cacheada: sin esto se podría seguir
    // jugando sin conexión como una cuenta de la que ya te saliste a
    // propósito (y viéndole las estadísticas), en un equipo compartido.
    connect(clienteRed_, &NetworkClient::logoutOk, this, [this]() { olvidarIdentidad(); });
    // Reemitir hacia QML: el dato vive en el cliente local pero se consulta
    // a través de este objeto (ver la Q_PROPERTY de arriba).
    connect(clienteLocal_, &LocalGameClient::xpOfflinePendienteCambio, this,
            &ModoJuegoCoordinador::xpOfflinePendienteCambio);
  }

  Q_INVOKABLE void activarModoLocal() {
    contexto_->setContextProperty("redcliente", clienteLocal_);
    // Reanunciar la identidad cacheada DESPUÉS del swap: los
    // Connections de QML tienen que estar ya reapuntados a clienteLocal_
    // para oír estas señales. En cola (no directo) a propósito, para no
    // depender de que la re-vinculación de los Connections termine dentro
    // de la propia llamada a setContextProperty(). Ver
    // LocalGameClient::reemitirIdentidad() para qué arregla esto.
    QMetaObject::invokeMethod(
        clienteLocal_, [this] { clienteLocal_->reemitirIdentidad(); }, Qt::QueuedConnection);
  }

  Q_INVOKABLE void activarModoRed() {
    contexto_->setContextProperty("redcliente", clienteRed_);
  }

  bool hayIdentidadCacheada() const { return clienteLocal_->hayIdentidadCacheada(); }
  QString usernameCacheado() const { return clienteLocal_->usernameCacheado(); }
  int xpOfflinePendiente() const { return clienteLocal_->xpOfflinePendiente(); }

  /// Lo llama QML cuando el servidor confirma cuánto XP offline acreditó.
  Q_INVOKABLE void confirmarXpOfflineSincronizado(int acreditado) {
    clienteLocal_->confirmarXpOfflineSincronizado(acreditado);
  }

 signals:
  void identidadCacheadaCambio();
  void xpOfflinePendienteCambio();

 private:
  void recordarUsername(const QString& username) {
    if (username.isEmpty() || username == usernameSesion_) return;
    usernameSesion_ = username;
    clienteLocal_->cachearIdentidad(usernameSesion_, {}, {});
    emit identidadCacheadaCambio();
  }

  void olvidarIdentidad() {
    usernameSesion_.clear();
    QSettings ajustes;
    ajustes.remove("offline/username");
    ajustes.remove("offline/estadisticasCuenta");
    ajustes.remove("offline/loadoutMarco");
    clienteLocal_->olvidarIdentidadCacheada();
    emit identidadCacheadaCambio();
  }

  QQmlContext* contexto_;         ///< No poseído.
  NetworkClient* clienteRed_;     ///< No poseído -- el de main.cpp.
  LocalGameClient* clienteLocal_; ///< No poseído -- el de main.cpp.
  QString usernameSesion_;        ///< Última identidad autenticada de ESTA ejecución.
};
