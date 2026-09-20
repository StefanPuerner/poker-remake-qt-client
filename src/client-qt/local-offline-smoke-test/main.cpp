// LocalOfflineSmokeTest -- valida en vivo LocalGameClient/LocalGameObserver/
// JugadorLocalQt (modo offline, ver docs/plan-modo-offline.md) sin ninguna
// interfaz gráfica: QCoreApplication basta. Un "jugador humano" guionizado
// (check si puede, si no call, si no all-in) responde a esMiTurno().
//
// Dos fases encadenadas:
//   A. Arranca una partida local, juega un par de manos y usa
//      "guardar y salir" -- comprueba que se escribe el .pok.
//   B. Lista las guardadas, comprueba el CSV, y RECARGA esa partida para
//      terminarla -- comprueba que reanudar funciona de verdad.
//   C. Igual con un RETO de Torneos: su guardado va a su propio fichero
//      (reto_*.pok), no sale en la lista normal, "continuar" lo reanuda y
//      terminar la partida lo borra.
//
// Confirma cosas que una compilación limpia NO garantiza: que el código de
// las clases compila (nadie más las incluye), que el ciclo GUI<->motor no
// se cuelga (watchdog), y que el guardado local va a su carpeta y se puede
// releer.
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QStandardPaths>
#include <QTimer>

#include "../../../include/Bot.hpp"
#include "../../../include/local-qt/LocalGameClient.hpp"

namespace {
int manosVistas = 0;
bool finVisto = false;
bool guardadoVisto = false;
bool recargaVista = false;
bool retoTerminado = false;
QString archivoGuardado;
int faseReto = 0;  // 0 = aún no, 1 = jugando el reto, 2 = reanudado
const QString codigoReto = "reto_solitario_smoke";
}  // namespace

int main(int argc, char* argv[]) {
    QCoreApplication app(argc, argv);
    // Nombre de aplicación PROPIO (no "PokerClientQt"): así QStandardPaths
    // manda los guardados de esta prueba a su propia carpeta y no ensucia
    // los del cliente real del usuario.
    QCoreApplication::setOrganizationName("PokerRemake");
    QCoreApplication::setApplicationName("PokerOfflineSmokeTest");

    // Bot::decidirAccion() simula 1-3s de "reflexión" por defecto (para que
    // no se sienta instantáneo en la UI real). Sin desactivarlo, un puñado
    // de manos ya se acerca al watchdog. Mismo patrón que BotBenchmark.
    Bot::setDelaySimuladoActivo(false);

    LocalGameClient cliente;
    // XP sin conexión activado: al terminar debe haber bolsa pendiente.
    cliente.setAcumularXpOffline(true);

    QObject::connect(&cliente, &LocalGameClient::nuevaMano, [](int mano, int ciega) {
        manosVistas = mano;
        qInfo() << "[smoke] --- mano" << mano << "ciega" << ciega << "---";
    });

    QObject::connect(&cliente, &LocalGameClient::esMiTurno,
        [&](int, int igualar, int miSaldo, int miApuesta, int, int, int,
            QString, QString, QString, QString, QString) {
            int aPagar = igualar - miApuesta;
            if (aPagar <= 0) cliente.enviarAccion("CHECK", 0);
            else if (aPagar < miSaldo) cliente.enviarAccion("CALL", 0);
            // Nunca all-in: con los bots actuales (que apuestan más fuerte) el humano
            // guionizado se quedaba sin fichas en 2 manos y el guardado ya no tenía
            // humano al que reanudar (fallo intermitente del propio test, no del juego).
            else cliente.enviarAccion("FOLD", 0);
        });

    // Fase A: tras 2 manos, guardar y salir. Fase B: seguir hasta el final.
    QObject::connect(&cliente, &LocalGameClient::esperandoVoto, [&](QString) {
        if (faseReto == 1 && manosVistas >= 2) {
            qInfo() << "[smoke] (reto) guardarYSalir() tras" << manosVistas << "manos";
            cliente.guardarYSalir();
        } else if (faseReto == 0 && !guardadoVisto && manosVistas >= 2) {
            qInfo() << "[smoke] guardarYSalir() tras" << manosVistas << "manos";
            cliente.guardarYSalir();
        } else {
            cliente.votar();
        }
    });

    QObject::connect(&cliente, &LocalGameClient::errorSala, [&](QString mensaje) {
        qCritical() << "[smoke] FALLA: errorSala:" << mensaje;
        std::exit(1);
    });

    QObject::connect(&cliente, &LocalGameClient::avisoRecompra, [&](bool puede) {
        if (puede) cliente.pedirRecompra();
    });

    // Al reanudar un guardado, preguntarExtension vuelve a su valor por
    // defecto (true): el formato .pok no lo persiste (ver arrancarPartida()
    // en LocalGameClient). Así que al llegar al límite de manos la partida
    // pregunta -- hay que contestar o el hilo de motor se queda esperando.
    QObject::connect(&cliente, &LocalGameClient::esperandoVotoExtension, [&](QString) {
        qInfo() << "[smoke] esperandoVotoExtension -> no extender";
        cliente.votarExtension(false);
    });

    QObject::connect(&cliente, &LocalGameClient::partidaGuardada, [&](QString archivo) {
        if (faseReto == 1) {
            qInfo() << "[smoke] === RETO GUARDADO ===" << archivo;
            if (!cliente.hayRetoGuardado(codigoReto)) {
                qCritical() << "[smoke] FALLA: hayRetoGuardado() dice que no hay guardado";
                std::exit(1);
            }
            if (!archivo.contains("reto_solitario_smoke")) {
                qCritical() << "[smoke] FALLA: el reto no se guardó en su fichero propio:" << archivo;
                std::exit(1);
            }
            QTimer::singleShot(200, [&]() {
                // No debe salir en la lista de guardadas normales.
                QObject::connect(&cliente, &LocalGameClient::guardadasActualizadas,
                                 [&](QString csv) {
                    if (faseReto != 1) return;
                    if (!csv.isEmpty()) {
                        qCritical() << "[smoke] FALLA: el guardado del reto sale en la lista normal:" << csv;
                        std::exit(1);
                    }
                    faseReto = 2;
                    qInfo() << "[smoke] continuando el reto";
                    cliente.continuarReto(codigoReto, 500);
                });
                cliente.listarGuardadas("", 0);
            });
            return;
        }
        guardadoVisto = true;
        archivoGuardado = archivo;
        qInfo() << "[smoke] === PARTIDA GUARDADA ===" << archivo;
        bool existe = QFileInfo::exists(archivo);
        qInfo() << "[smoke] el fichero existe en disco:" << existe;
        if (!existe) { qCritical() << "[smoke] FALLA: no se escribió el .pok"; std::exit(1); }

        // Fase B, en cola: el hilo de motor todavía está terminando.
        QTimer::singleShot(200, [&]() {
            QObject::connect(&cliente, &LocalGameClient::guardadasActualizadas,
                             [&](QString csv) {
                if (recargaVista) return;
                qInfo() << "[smoke] guardadas:" << csv;
                if (csv.isEmpty()) { qCritical() << "[smoke] FALLA: lista vacía"; std::exit(1); }
                // formato: nombre:humanos:bots:fecha
                QString nombre = csv.split(';').first().split(':').first();
                recargaVista = true;
                qInfo() << "[smoke] recargando" << nombre;
                cliente.cargarPartidaGuardada("", 0, "Humano", nombre, "", false);
            });
            cliente.listarGuardadas("", 0);
        });
    });

    QObject::connect(&cliente, &LocalGameClient::finDePartida,
        [&](QString ganador, int saldo, bool porLimite) {
            qInfo() << "[smoke] === FIN DE PARTIDA === ganador=" << ganador
                    << "saldo=" << saldo << "porLimite=" << porLimite;
            if (faseReto == 0) {
                finVisto = true;
                // Fase C: el mismo recorrido con un reto.
                faseReto = 1;
                manosVistas = 0;
                qInfo() << "[smoke] --- fase reto ---";
                cliente.setRetoEnCurso(codigoReto);
                cliente.iniciarPartidaLocal("Humano", 2, 6, 20, 500, 0, false, 0, 0, false, false);
                return;
            }
            if (faseReto == 2) {
                if (cliente.hayRetoGuardado(codigoReto)) {
                    qCritical() << "[smoke] FALLA: terminar el reto no borró su guardado";
                    std::exit(1);
                }
                retoTerminado = true;
                QCoreApplication::quit();
            }
        });

    QTimer::singleShot(60'000, &app, [&]() {
        if (retoTerminado) return;
        qCritical() << "[smoke] TIMEOUT -- posible deadlock. manos=" << manosVistas
                    << "guardado=" << guardadoVisto << "recarga=" << recargaVista;
        std::exit(1);
    });

    cliente.iniciarPartidaLocal(/*nombre=*/"Humano", /*numBots=*/2, /*numManos=*/6,
                                /*ciegaGrande=*/20, /*saldo=*/500, /*tipoLimite=*/0,
                                /*aplicarMinRaise=*/false, /*monteFijo=*/0,
                                /*dificultadBots=*/0, /*permitirRecompra=*/false,
                                /*preguntarExtension=*/false);

    int rc = app.exec();
    if (!guardadoVisto) { qCritical() << "[smoke] FALLA: nunca se guardó"; return 1; }
    if (!recargaVista)  { qCritical() << "[smoke] FALLA: nunca se recargó"; return 1; }
    if (!finVisto)      { qCritical() << "[smoke] FALLA: no terminó"; return 1; }
    if (!retoTerminado) { qCritical() << "[smoke] FALLA: el reto no llegó al final"; return 1; }
    qInfo() << "[smoke] XP offline acumulado:" << cliente.xpOfflinePendiente();
    if (cliente.xpOfflinePendiente() <= 0) {
        qCritical() << "[smoke] FALLA: no se acumuló XP sin conexión";
        return 1;
    }
    qInfo() << "[smoke] OK -- partida local, guardado, listado y recarga completos.";
    return rc;
}
