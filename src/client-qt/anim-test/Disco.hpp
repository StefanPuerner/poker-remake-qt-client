// Disco.hpp (AnimTest) -- leer/escribir ficheros de texto desde QML. Qt bloquea
// la escritura desde XMLHttpRequest, y el banco necesita guardar la selección
// de sonidos; hacerlo aquí, con el resultado real, evita "guardar" sin guardar.
#pragma once
#include <QFile>
#include <QObject>
#include <QSaveFile>

class Disco : public QObject {
  Q_OBJECT
 public:
  using QObject::QObject;
  Q_INVOKABLE bool escribir(const QString& ruta, const QString& texto) {
    QSaveFile f(ruta);
    if (!f.open(QIODevice::WriteOnly)) return false;
    f.write(texto.toUtf8());
    return f.commit();
  }
  Q_INVOKABLE QString leer(const QString& ruta) {
    QFile f(ruta);
    if (!f.open(QIODevice::ReadOnly)) return QString();
    return QString::fromUtf8(f.readAll());
  }
};
