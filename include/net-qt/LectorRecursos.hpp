// LectorRecursos.hpp -- lee ficheros de texto EMPAQUETADOS en el ejecutable (recursos Qt) desde QML.
//
// XMLHttpRequest no sirve para esto: Qt 6 trata "qrc:" como fichero local y el GET viene bloqueado
// de fábrica (haría falta QML_XHR_ALLOW_FILE_READ=1, una variable de entorno que un usuario no va a
// poner). Se registra como contexto "recursos" en main.cpp.
#pragma once

#include <QFile>
#include <QObject>
#include <QString>

class LectorRecursos : public QObject {
  Q_OBJECT
 public:
  using QObject::QObject;
  /// "qrc:/qt/qml/...", ":/qt/qml/..." o "/qt/qml/...". Devuelve "" si no existe.
  Q_INVOKABLE QString leerTexto(const QString& ruta) const {
    QString r = ruta;
    if (r.startsWith("qrc:")) r = r.mid(4);
    if (!r.startsWith(':')) r.prepend(':');
    QFile f(r);
    if (!f.open(QIODevice::ReadOnly)) return QString();
    return QString::fromUtf8(f.readAll());
  }
};
