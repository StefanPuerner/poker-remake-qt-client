// FotoAvatarHelper.hpp -- recorte/redimensionado/codificación de la foto de
// avatar, del lado del cliente. Sin red ni cuentas: solo QImage, mismo código
// en escritorio y Android (QFile abre un "content://" del selector de
// Android igual que una ruta normal, ver recortarRectYCodificar()). Se
// registra como contexto "fotoHelper" en main.cpp/main-mobile.cpp -- aparte de
// NetworkClient/LocalGameClient a propósito: es una utilidad local pura, no
// necesita paridad de API entre los dos (no se reasigna nunca).
#pragma once

#include <algorithm>
#include <cmath>

#include <QBuffer>
#include <QByteArray>
#include <QFile>
#include <QImage>
#include <QObject>
#include <QString>
#include <QUrl>

class FotoAvatarHelper : public QObject {
  Q_OBJECT
 public:
  using QObject::QObject;

  /// Recorta el rectángulo (cropX, cropY, cropW, cropH) de la imagen @p origen
  /// (píxeles de la imagen ORIGINAL, lo que entrega FileDialog.selectedFile),
  /// lo reduce a @p salidaW x @p salidaH y lo codifica en JPEG con calidad
  /// @p calidad (1-100).
  /// Avatar: cuadrado 256x256. Tapete de mesa (2026-10-03): la proporción de
  /// la pastilla, 768x384. El rectángulo lo calcula PopupRecorteFoto.qml ya
  /// dentro de los límites; aquí se vuelve a acotar por seguridad. @return
  /// base64 estándar (RFC 4648, el mismo que decodifica el servidor) o "" si
  /// el fichero no se pudo leer o no es una imagen válida. Sin valores por
  /// defecto a propósito: Q_INVOKABLE no los expone a QML.
  Q_INVOKABLE QString recortarRectYCodificar(const QUrl& origen, qreal cropX, qreal cropY,
                                             qreal cropW, qreal cropH, int salidaW,
                                             int salidaH, int calidad) const {
    QFile archivo(origen.isLocalFile() ? origen.toLocalFile() : origen.toString());
    if (!archivo.open(QIODevice::ReadOnly)) return QString();
    QImage original;
    if (!original.loadFromData(archivo.readAll())) return QString();

    const int ancho = std::clamp(static_cast<int>(std::lround(cropW)), 1, original.width());
    const int alto = std::clamp(static_cast<int>(std::lround(cropH)), 1, original.height());
    const int x = std::clamp(static_cast<int>(std::lround(cropX)), 0, original.width() - ancho);
    const int y = std::clamp(static_cast<int>(std::lround(cropY)), 0, original.height() - alto);
    const int anchoSalida = std::clamp(salidaW, 64, 2048);
    const int altoSalida = std::clamp(salidaH, 64, 2048);
    QImage cuadrada = original.copy(QRect(x, y, ancho, alto))
                          .scaled(anchoSalida, altoSalida, Qt::IgnoreAspectRatio, Qt::SmoothTransformation)
                          .convertToFormat(QImage::Format_RGB32);

    QByteArray jpeg;
    QBuffer buffer(&jpeg);
    buffer.open(QIODevice::WriteOnly);
    if (!cuadrada.save(&buffer, "JPG", std::clamp(calidad, 1, 100))) return QString();
    return QString::fromLatin1(jpeg.toBase64());
  }
};
