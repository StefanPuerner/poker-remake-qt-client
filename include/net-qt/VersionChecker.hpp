#pragma once

// VersionChecker.hpp — comprueba en segundo plano, sin bloquear Inicio, si
// hay una versión más reciente publicada en el repo público de GitHub que
// la que trae este binario. Consulta la API pública de releases (sin
// autenticación, sujeta al límite de peticiones anónimas de GitHub — de
// sobra para una comprobación puntual al arrancar) en vez de que el
// servidor reporte una versión "recomendada": la API de GitHub siempre
// está exacta en cuanto se publica un release, sin depender de que alguien
// se acuerde de actualizar un valor a mano en otro sitio. Ver diseño en
// memoria qt_progression_system_design.md, sección "Aviso de versión
// antigua + release de Android".
//
// POKER_APP_VERSION lo define cmake/ClientesQt.cmake (target_compile_definitions)
// a partir del mismo "MAYOR.MENOR.PARCHE" que llevan los tags de git
// (v0.7.1 → "0.7.1") — un único sitio que actualizar en cada release.

#include <algorithm>

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QUrl>

#ifndef POKER_APP_VERSION
#define POKER_APP_VERSION "0.0.0"
#endif

class VersionChecker : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString versionActual READ versionActual CONSTANT)
  Q_PROPERTY(bool hayVersionNueva READ hayVersionNueva NOTIFY hayVersionNuevaChanged)
  Q_PROPERTY(QString versionRemota READ versionRemota NOTIFY hayVersionNuevaChanged)
  Q_PROPERTY(QString urlRelease READ urlRelease NOTIFY hayVersionNuevaChanged)
  Q_PROPERTY(QString urlDescarga READ urlDescarga CONSTANT)

 public:
  explicit VersionChecker(QObject* parent = nullptr) : QObject(parent) {}

  QString versionActual() const { return QString::fromUtf8(POKER_APP_VERSION); }
  bool hayVersionNueva() const { return hayVersionNueva_; }
  QString versionRemota() const { return versionRemota_; }
  QString urlRelease() const { return urlRelease_; }

  // Descarga DIRECTA del fichero de esta plataforma en la última release
  // pública (pendiente 9 de CLAUDE.md, 2026-09-10: "si puede ser,
  // directamente a la descarga"). GitHub redirige
  // .../releases/latest/download/<fichero> al de la release más reciente (no
  // cuenta borradores ni pre-releases). ⚠️ Los nombres los ponen los
  // workflows del repo público (build-android/linux/windows.yml): renombrar
  // un fichero allí rompe esto sin avisar. Sin fichero propio (macOS...), la
  // página de la última release -- y el cliente móvil también, ver abajo el
  // porqué. Cuando la app esté en Google Play, en Android esto pasa a ser la
  // ficha de la app.
  QString urlDescarga() const {
    const QString ultima =
        QStringLiteral("https://github.com/StefanPuerner/poker-remake-qt-client/releases/latest");
    // El cliente MÓVIL abre la PÁGINA de la última release, no el .apk: en
    // Brave para Android, un enlace que va directo a un fichero se abre en una
    // vista de solo descarga que llega al 100% y nunca termina (visto en real
    // en v0.8.0, 2026-09-10; en Chrome sí terminaba). Desde la página, la
    // descarga va por la pestaña normal del navegador. También en un PC: el
    // AppImage y el zip llevan el cliente de escritorio, que es otro
    // programa. POKER_CLIENTE_MOVIL lo pone cmake/ClientesQt.cmake solo en
    // ese target. Y Android antes que Linux: en Android también está
    // definido Q_OS_LINUX.
#if defined(Q_OS_ANDROID) || defined(POKER_CLIENTE_MOVIL)
    return ultima;
#elif defined(Q_OS_WIN)
    return ultima + QStringLiteral("/download/PokerRemake-Windows-x86_64.zip");
#elif defined(Q_OS_LINUX)
    return ultima + QStringLiteral("/download/PokerRemake-x86_64.AppImage");
#else
    return ultima;
#endif
  }

  // Se llama una vez al arrancar (ver Main.qml, Component.onCompleted de
  // la ventana raíz). Fallo silencioso a propósito en cualquier error (sin
  // red, API caída, JSON inesperado) — esto es un aviso de cortesía, nunca
  // debe interrumpir ni retrasar que la app arranque.
  Q_INVOKABLE void comprobar() {
    auto* manager = new QNetworkAccessManager(this);
    QNetworkRequest peticion(QUrl(
        "https://api.github.com/repos/StefanPuerner/poker-remake-qt-client/releases/latest"));
    // La API de GitHub devuelve 403 sin esto, sea cual sea el valor.
    peticion.setRawHeader("User-Agent", "PokerRemake-VersionChecker");
    QNetworkReply* respuesta = manager->get(peticion);
    connect(respuesta, &QNetworkReply::finished, this, [this, respuesta, manager]() {
      respuesta->deleteLater();
      manager->deleteLater();
      if (respuesta->error() != QNetworkReply::NoError) return;

      QJsonDocument doc = QJsonDocument::fromJson(respuesta->readAll());
      if (!doc.isObject()) return;
      QJsonObject obj = doc.object();
      QString tag = obj.value("tag_name").toString();  // p.ej. "v0.7.1"
      QString url = obj.value("html_url").toString();
      if (tag.isEmpty()) return;

      QString remota = tag.startsWith('v') ? tag.mid(1) : tag;
      if (esVersionMasNueva(remota, versionActual())) {
        versionRemota_ = remota;
        urlRelease_ = url;
        hayVersionNueva_ = true;
        emit hayVersionNuevaChanged();
      }
    });
  }

 signals:
  void hayVersionNuevaChanged();

 private:
  bool hayVersionNueva_ = false;
  QString versionRemota_;
  QString urlRelease_;

  // Compara dos versiones "MAYOR.MENOR.PARCHE" numéricas componente a
  // componente -- suficiente para el esquema de tags que ya usa el
  // proyecto, sin traer una librería de semver completa para un caso tan
  // simple.
  static bool esVersionMasNueva(const QString& remota, const QString& actual) {
    QStringList r = remota.split('.');
    QStringList a = actual.split('.');
    int n = std::max(r.size(), a.size());
    for (int i = 0; i < n; ++i) {
      int vr = i < r.size() ? r.at(i).toInt() : 0;
      int va = i < a.size() ? a.at(i).toInt() : 0;
      if (vr != va) return vr > va;
    }
    return false;
  }
};
