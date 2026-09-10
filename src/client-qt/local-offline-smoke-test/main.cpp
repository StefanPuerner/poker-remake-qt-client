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
QString archivoGuardado;
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
            else cliente.enviarAccion("ALL_IN", miSaldo);
        });

    // Fase A: tras 2 manos, guardar y salir. Fase B: seguir hasta el final.
    QObject::connect(&cliente, &LocalGameClient::esperandoVoto, [&](QString) {
        if (!guardadoVisto && manosVistas >= 2) {
            qInfo() << "[smoke] guardarYSalir() tras" << manosVistas << "manos";
            cliente.guardarYSalir();
        } else {
            cliente.votar();
        }
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
            finVisto = true;
            QCoreApplication::quit();
        });

    QTimer::singleShot(30'000, &app, [&]() {
        if (finVisto) return;
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
    qInfo() << "[smoke] XP offline acumulado:" << cliente.xpOfflinePendiente();
    if (cliente.xpOfflinePendiente() <= 0) {
        qCritical() << "[smoke] FALLA: no se acumuló XP sin conexión";
        return 1;
    }
    qInfo() << "[smoke] OK -- partida local, guardado, listado y recarga completos.";
    return rc;
}
