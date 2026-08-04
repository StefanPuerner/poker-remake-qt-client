# Guía 8 — Red asíncrona con `QTcpSocket`

Esta es la guía más importante de las cuatro (6-9): es donde el modelo que
aprendiste en las guías 1 y 2 (`socket()`, `poll()`, bloqueante) se traduce a
como lo hace Qt. Léela con las guías 1 y 2 abiertas al lado — vas a reconocer
cada problema, resuelto de otra forma.

---

## 1. Recordatorio: cómo lo hace el proyecto hoy

```cpp
// Bloqueante — src/net/SocketClient.cpp + Protocol.cpp
cliente.connect();                      // bloquea hasta conectar (o falla)
net::Message msg = net::recvMsg(fd);    // bloquea hasta tener un mensaje completo
net::sendMsg(fd, respuesta);            // bloquea si el buffer de socket está lleno
```

Y para no bloquear el teclado a la vez, envuelves todo en `poll()` (guía 2).
Este patrón — tú decides cuándo leer, tú llamas a `read()` — se llama
**E/S síncrona/bloqueante**.

---

## 2. `QTcpSocket`: el mismo socket, otro modelo

```cpp
#include <QTcpSocket>

QTcpSocket* socket = new QTcpSocket(this);
socket->connectToHost("100.83.246.15", 7777);
```

`connectToHost()` **no bloquea** — inicia la conexión y vuelve inmediatamente.
Te enteras de que terminó (bien o mal) por una señal:

```cpp
connect(socket, &QTcpSocket::connected, this, [this]() {
  qDebug() << "Conectado";
});
connect(socket, &QTcpSocket::errorOccurred, this, [this](QAbstractSocket::SocketError) {
  qDebug() << "Error:" << socket->errorString();
});
```

### Las señales que importan

| Señal | Cuándo se emite |
|---|---|
| `connected()` | La conexión se estableció |
| `readyRead()` | Llegaron bytes nuevos — el equivalente a `POLLIN` de `poll()` |
| `disconnected()` | El otro lado cerró — el equivalente a leer 0 bytes (EOF) |
| `errorOccurred(SocketError)` | Falló algo (ECONNREFUSED, etc.) |
| `bytesWritten(qint64)` | Se confirmó el envío de datos (rara vez hace falta) |

**No hay `poll()` en ningún sitio de tu código.** El event loop de Qt (guía 6,
sección 5) ya está vigilando el socket por debajo, exactamente como vigila el
teclado o los temporizadores — y te avisa con la señal correspondiente cuando
toca.

---

## 3. Leer datos: `readyRead()` + `read()`

```cpp
connect(socket, &QTcpSocket::readyRead, this, [this, socket]() {
  QByteArray datos = socket->readAll();   // todo lo que haya disponible AHORA
  procesar(datos);
});
```

**El mismo problema de siempre sigue aquí**: TCP es un stream (guía 1, sección
6). `readyRead()` se dispara cuando *hay* datos, no cuando *tu mensaje
completo* ha llegado. Puede dispararse con medio header, con un mensaje y
medio, con tres mensajes pegados... Igual que antes, necesitas acumular en un
buffer propio y extraer mensajes completos cuando puedas.

### Adaptando el framing del proyecto (4 bytes + JSON)

```cpp
class NetworkClient : public QObject {
  Q_OBJECT
 public:
  explicit NetworkClient(QObject* parent = nullptr) : QObject(parent) {
    connect(&socket_, &QTcpSocket::readyRead, this, &NetworkClient::onReadyRead);
  }

  void conectar(const QString& host, quint16 puerto) {
    socket_.connectToHost(host, puerto);
  }

  void enviar(const net::Message& msg) {
    uint32_t len = qToBigEndian<uint32_t>(msg.payload.size());
    socket_.write(reinterpret_cast<const char*>(&len), 4);
    socket_.write(msg.payload.data(), msg.payload.size());
  }

 signals:
  void mensajeRecibido(net::Message msg);

 private slots:
  void onReadyRead() {
    buffer_ += socket_.readAll();

    while (true) {
      if (esperandoHeader_ && buffer_.size() >= 4) {
        longitudEsperada_ = qFromBigEndian<uint32_t>(
            reinterpret_cast<const uchar*>(buffer_.constData()));
        buffer_.remove(0, 4);
        esperandoHeader_ = false;
      }
      if (!esperandoHeader_ && buffer_.size() >= static_cast<int>(longitudEsperada_)) {
        std::string payload(buffer_.constData(), longitudEsperada_);
        buffer_.remove(0, longitudEsperada_);
        esperandoHeader_ = true;

        std::string tipoStr = net::jsonGetStr(payload, "type");
        emit mensajeRecibido(net::Message{net::strToMsgType(tipoStr), payload});
      } else {
        break;  // no hay suficientes bytes todavía para el siguiente paso
      }
    }
  }

 private:
  QTcpSocket socket_;
  QByteArray buffer_;
  bool esperandoHeader_ = true;
  uint32_t longitudEsperada_ = 0;
};
```

Esto es la traducción directa de `readAll()`/`recvMsg()` de `Protocol.cpp` a
un modelo donde nunca bloqueas: en vez de "leer hasta tener 4 bytes" (bucle
bloqueante), es "si ya tengo 4 bytes acumulados, avanza de fase; si no, espera
al próximo `readyRead()`". Nota que `net::buildMsg`, `net::jsonGetStr`,
`net::strToMsgType` — todo el `Protocol.hpp` de siempre — se reutilizan tal
cual, sin cambiar una línea.

---

## 4. Enviar datos: sin sorpresas

```cpp
socket_.write(datos);   // no bloquea; Qt lo encola y lo envía cuando puede
```

A diferencia de la lectura, escribir es más simple: `write()` no bloquea
nunca (Qt gestiona su propio buffer de salida internamente), así que no hace
falta ningún patrón especial para enviar mensajes.

---

## 5. Comparación directa

| | `SocketClient` (actual) | `QTcpSocket` |
|---|---|---|
| Conectar | `connect()` bloquea | `connectToHost()` + señal `connected()` |
| Saber si hay datos | `poll()` manual | Señal `readyRead()` automática |
| Leer | `recvMsg()` bloquea hasta N bytes | `readAll()` da lo que haya YA; tú acumulas |
| Enviar | `sendMsg()`, puede bloquear | `write()`, nunca bloquea |
| Desconexión | excepción `ConexionCerrada` | señal `disconnected()` |
| Multiplexar con teclado | `poll()` con 2 fds | No hace falta — Qt ya multiplexa todo dentro de `exec()` |

---

## 6. Un cuidado especial: nada de `sleep()`

En `client/main.cpp` actual, la reconexión hace `sleep(2)` entre intentos —
válido porque bloquear ESE proceso está bien, no hay nada más que hacer
mientras tanto. **En Qt, `sleep()` congela toda la interfaz** (el event loop
no puede procesar nada mientras el hilo está dormido — ni redibujar, ni
teclado, ni la propia animación de "reconectando"). El equivalente correcto
es un `QTimer`:

```cpp
QTimer::singleShot(2000, this, [this]() {
  intentarReconectar();
});
```

Programa una llamada dentro de 2000ms **sin bloquear nada** — el event loop
sigue funcionando mientras tanto. Este es el cambio de mentalidad más
importante al portar cualquier bucle con `sleep()` a Qt.

---

## Preguntas de comprensión

1. ¿Por qué `readyRead()` puede dispararse con un mensaje incompleto? ¿Qué
   guía anterior explica exactamente el mismo problema con sockets crudos?
2. En el código de `onReadyRead()` de arriba, ¿qué pasa si llegan de golpe
   3 mensajes completos pegados en el mismo `readyRead()`? Sigue el `while`
   paso a paso.
3. ¿Por qué `write()` en `QTcpSocket` no necesita un bucle "reintentar hasta
   enviar todo" como sí lo necesita `write()` de sockets crudos (`writeAll`
   en `Protocol.cpp`)?
4. ¿Qué pasaría si usas `sleep(2)` dentro de un slot conectado a una señal de
   Qt? ¿Se congelaría solo esa ventana o toda la aplicación?
5. ¿Qué reemplaza a `poll()` en una aplicación Qt: quién decide cuándo hay
   que leer del socket?
