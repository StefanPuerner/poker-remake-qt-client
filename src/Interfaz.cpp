#include "../include/Interfaz.hpp"

#include <cctype>
#include <chrono>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <limits>
#include <sstream>
#include <string>
#include <thread>

#include "../include/Analyzer.hpp"
#include "../include/Mesa.hpp"

void Interfaz::limpiarPantalla() {
  std::cout << "\033[2J\033[H" << std::flush;
}

void Interfaz::dibujarTituloPoker() {
  std::cout << style::Cyan << style::Bold
            << " ██████╗  ██████╗ ██╗  ██╗███████╗██████╗ \n"
            << " ██╔══██╗██╔═══██╗██║ ██╔╝██╔════╝██╔══██╗\n"
            << " ██████╔╝██║   ██║█████╔╝ █████╗  ██████╔╝\n"
            << " ██╔═══╝ ██║   ██║██╔═██╗ ██╔══╝  ██╔══██╗\n"
            << " ██║     ╚██████╔╝██║  ██╗███████╗██║  ██║\n"
            << " ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝\n\n"
            << "  " << style::Pica << "  " << style::Trebol << "  "
            << style::Corazon << "  " << style::Diamante << "    P O K E R     "
            << style::Pica << "  " << style::Trebol << "  " << style::Corazon
            << "  " << style::Diamante << "\n"
            << style::Reset << "\n";
}

void Interfaz::dibujarCartasEnParalelo(const std::vector<Carta>& cartas,
                                       int numTotal) {
  if (cartas.empty() && numTotal == 0) {
    std::cout << style::Gray << "  [ Sin cartas en la mesa ]\n" << style::Reset;
    return;
  }

  // Un vector de strings para representar las 5 líneas verticales de las cartas
  std::vector<std::string> lineas(5, "");

  for (const auto& c : cartas) {
    // Obtener el símbolo del palo y su color correspondiente
    std::string sim = "";
    std::string color = style::BrightWhite;

    switch (c.getPalo()) {
      case Palo::CORAZONES:
        sim = style::Corazon;
        color = style::BrightRed;
        break;
      case Palo::DIAMANTES:
        sim = style::Diamante;
        color = style::BrightRed;
        break;
      case Palo::TREBOLES:
        sim = style::Trebol;
        break;
      case Palo::PICAS:
        sim = style::Pica;
        break;
    }

    // Mapear el valor a texto legible (2-10, J, Q, K, A)
    std::string valStr = "";
    int v = static_cast<int>(c.getValor());
    if (v <= 10)
      valStr = std::to_string(v);
    else if (v == 11)
      valStr = "J";
    else if (v == 12)
      valStr = "Q";
    else if (v == 13)
      valStr = "K";
    else if (v == 14)
      valStr = "A";

    // Formatear espaciado interno de la carta para que no se deforme (ancho
    // fijo)
    std::string vIzq =
        style::BgWhite + valStr + (valStr.length() == 1 ? " " : "");
    std::string vDer =
        style::BgWhite + (valStr.length() == 1 ? " " : "") + valStr;

    lineas[0] += style::BgWhite + style::Black + "┌─────────┐ " + style::Reset;
    lineas[1] += style::BgWhite + style::Black + "│ " + color + vIzq +
                 style::Black + "      │ " + style::Reset;
    lineas[2] += style::BgWhite + style::Black + "│    " + color + sim +
                 style::Black + "    │ " + style::Reset;
    lineas[3] += style::BgWhite + style::Black + "│      " + color + vDer +
                 style::Black + " │ " + style::Reset;
    lineas[4] += style::BgWhite + style::Black + "└─────────┘ " + style::Reset;
  }

  // Cartas boca abajo para las posiciones aún no reveladas
  int numFaceDown = std::max(0, numTotal - static_cast<int>(cartas.size()));
  const std::string FB = style::BgBlue + style::BrightWhite;
  const std::string FI = style::BgBlue + style::White;
  const std::string R = style::Reset;
  for (int i = 0; i < numFaceDown; ++i) {
    lineas[0] += FB + "┌─────────┐ " + R;
    lineas[1] += FI + "│░░░░░░░░░│ " + R;
    lineas[2] += FI + "│░░░░░░░░░│ " + R;
    lineas[3] += FI + "│░░░░░░░░░│ " + R;
    lineas[4] += FB + "└─────────┘ " + R;
  }

  // Imprimir el bloque completo de cartas en paralelo
  for (const auto& linea : lineas) {
    std::cout << "  " << linea << "\n";
  }
}

void Interfaz::secuenciaArranqueTerminal() {
  limpiarPantalla();
  std::cout << style::Cyan
            << "  [SYS] Iniciando Texas Hold'em Engine v1.0...\n\n"
            << style::Reset;

  // Lista de mensajes técnicos para el arranque (10 mensajes)
  const std::vector<std::string> mensajes = {
      "Asignando memoria para el motor principal (Heap)...",
      "Inicializando generador de entropía (MT19937)...",
      "Cargando matrices de decisión de la IA...",
      "Calibrando analizador de manos y probabilidades...",
      "Verificando árbol de directorios locales (../data/)...",
      "Cargando paletas de colores y estilos ANSI...",
      "Preparando motor de resolución de empates (Side Pots)...",
      "Instanciando baraja criptográfica de 52 cartas...",
      "Inyectando dependencias del sistema de guardado...",
      "Sistema operativo virtual montado y listo."};

  // 10 mensajes * 60ms = 600ms (Un poco más de medio segundo)
  int contador = 10;
  for (const std::string& msg : mensajes) {
    std::string percentage = "[" + std::to_string(contador) + "%]";
    mostrarBarraCarga(60);  // Más rápido que el apagado
    std::cout << style::White << percentage << style::Gray << msg << "\n";
    contador += 10;
  }
  std::cout << style::BrightGreen
            << "\n  [OK] Todos los sistemas en línea. Lanzando interfaz...\n\n"
            << style::Reset;
  std::this_thread::sleep_for(std::chrono::milliseconds(500));
}

void Interfaz::secuenciaApagadoTerminal() {
  limpiarPantalla();
  std::cout << style::BrightRed
            << "  [ALERTA] Iniciando secuencia de apagado seguro...\n\n"
            << style::Reset;
  const std::vector<std::string> mensajes = {
      "Deteniendo motor de apuestas y evaluación...",
      "Guardando estado de la memoria dinámica (Heap)...",
      "Cerrando manejadores de archivos (.pok)...",
      "Sincronizando reloj de entropía del sistema...",
      "Desactivando matrices de decisión de los Bots...",
      "Liberando semillas del motor Mersenne Twister...",
      "Purgando buffers de entrada/salida de la consola...",
      "Desvinculando punteros de la baraja virtual...",
      "Destruyendo instancias de jugadores activos...",
      "Vaciando historial residual de botes (Side Pots)...",
      "Finalizando subprocesos del evaluador de manos...",
      "Cerrando descriptores de Interfaz Visual...",
      "Limpiando caché de la mesa comunitaria...",
      "Calculando y cifrando checksums finales...",
      "Desconectando recolector de basura manual...",
      "Liberando bloques de memoria asignados...",
      "Comprobando integridad de las estructuras JSON...",
      "Apagando subsistema genérico de C++17...",
      "Desmontando TexasHoldem Engine v1.0...",
      "Enviando señal de terminación (SIGTERM)..."};

  // 20 mensajes * 80ms = 1600ms (1.6 segundos en total)
  for (const std::string& msg : mensajes) {
    std::cout << style::Gray << "  [SYS] " << style::Reset << msg << "\n";
    mostrarBarraCarga(
        80);  // Llama a la barra que hicimos antes, a toda velocidad
  }

  std::cout << style::BrightGreen
            << "\n  [OK] Apagado completado con éxito. ¡Hasta pronto!\n\n"
            << style::Reset;
  std::this_thread::sleep_for(std::chrono::milliseconds(500));
  limpiarPantalla();
}

void Interfaz::mostrarEstadoPartida(const GameState& state,
                                    const std::vector<Player*>& jugadores,
                                    const std::vector<int>& botes) {
  limpiarPantalla();

  // 1. Cabecera y Mesa  (85 chars totales: "  ╔" + 81═ + "╗")
  {
    const std::string titulo = "MESA DE JUEGO";
    int lp = (81 - static_cast<int>(titulo.size())) / 2;
    int rp = 81 - static_cast<int>(titulo.size()) - lp;
    std::cout << style::Yellow << style::Bold
              << "  "
                 "╔════════════════════════════════════════════════════════════"
                 "═════════════════════╗\n"
              << "  ║" << std::string(lp, ' ') << titulo << std::string(rp, ' ')
              << "║\n"
              << "  "
                 "╚════════════════════════════════════════════════════════════"
                 "═════════════════════╝\n"
              << style::Reset;
  }

  std::string faseActualStr;
  switch (state.rondaActual) {
    case Rondas::PREFLOP:
      faseActualStr = "PREFLOP";
      break;
    case Rondas::FLOP:
      faseActualStr = "FLOP";
      break;
    case Rondas::TURN:
      faseActualStr = "TURN";
      break;
    case Rondas::RIVER:
      faseActualStr = "RIVER";
      break;
    case Rondas::SHOWDOWN:
      faseActualStr = "SHOWDOWN";
      break;
  }

  std::cout << "\n  " << style::Cyan << "Cartas Comunitarias (" << faseActualStr
            << "):" << style::Reset << "\n";
  // numTotal=5 siempre: las posiciones no reveladas se dibujan boca abajo
  dibujarCartasEnParalelo(state.cartasComunitarias, 5);

  // 2. Información de Botes
  std::cout << "\n  " << style::Yellow << style::Bold
            << "BOTES EN JUEGO:" << style::Reset << "\n";
  for (size_t i = 0; i < botes.size(); ++i) {
    if (i == 0) {
      std::cout << "  " << style::Green << "▶ Principal :" << botes[i]
                << style::Reset << "\n";
    } else {
      std::cout << "  " << style::Gray << "▶ Side Pot " << i << ": " << botes[i]
                << style::Reset << "\n";
    }
  }
  std::cout << "  " << style::Cyan
            << "▶ Apuesta Actual (A Igualar): " << state.apuestaAIgualar
            << style::Reset << "\n\n";

  // 3. Cuadro de Jugadores  (85 chars: "  │ " + 16+3+10+3+10+3+14+3+17 + " │")
  std::cout << style::BrightWhite
            << "  "
               "┌──────────────────┬────────────┬────────────┬────────────────┬"
               "───────────────────┐\n"
            << "  │ JUGADOR          │ ESTADO     │ SALDO      │ EN ESTA RONDA "
               " │ EN ESTA MANO      │\n"
            << "  "
               "├──────────────────┼────────────┼────────────┼────────────────┼"
               "───────────────────┤\n"
            << style::Reset;

  for (const auto* p : jugadores) {
    std::string nombre = p->getNombre();
    if (nombre.length() > 15) nombre = nombre.substr(0, 15) + ".";

    std::string estStr;
    std::string colorEst;
    switch (p->getEstado()) {
      case PlayerState::ACTIVO:
        estStr = "ACTIVO";
        colorEst = style::Green;
        break;
      case PlayerState::FOLD:
        estStr = "FOLDED";
        colorEst = style::Gray;
        break;
      case PlayerState::ALL_IN:
        estStr = "ALL-IN";
        colorEst = style::Red;
        break;
      case PlayerState::ELIMINADO:
        estStr = "(x_x)";
        colorEst = style::BrightRed;
        break;
    }

    std::string saldoStr = "" + std::to_string(p->getSaldo());
    std::string apuestaStr = "" + std::to_string(p->getApuestaAcumuladaRonda());

    std::string manoStr = std::to_string(p->getApuestaAcumuladaMano());

    std::cout << "  │ " << style::Cyan << std::left << std::setw(16) << nombre
              << style::Reset << " │ " << colorEst << std::left << std::setw(10)
              << estStr << style::Reset << " │ " << style::Yellow << std::left
              << std::setw(10) << saldoStr << style::Reset << " │ "
              << style::BrightWhite << std::left << std::setw(14) << apuestaStr
              << style::Reset << " │ " << style::BrightCyan << std::left
              << std::setw(17) << manoStr << style::Reset << " │\n";
  }
  std::cout << style::BrightWhite
            << "  "
               "└──────────────────┴────────────┴────────────┴────────────────┴"
               "───────────────────┘\n\n"
            << style::Reset;
}

void Interfaz::mostrarCartasPropias(const std::string& nombreJugador,
                                    const std::vector<Carta>& cartas) {
  std::cout << style::Cyan
            << "  ╔════════════════════════════════════════════════╗\n"
            << "  ║            " << style::Bold << "Cartas Ocultas de "
            << style::Bold << std::setw(15) << (nombreJugador + ":") << style::Reset
            << style::Cyan << "   ║\n"
            << "  ╚════════════════════════════════════════════════╝\n"
            << style::Reset << "\n";
  dibujarCartasEnParalelo(cartas);
  std::cout << "\n";
}

void Interfaz::mostrarOpcionesAccion(const std::string& nombre,
                                     int aPagarParaIgualar, int miSaldo,
                                     const std::string& actual,
                                     const std::string& probable,
                                     const std::string& potencial) {
  // Panel de opciones — 85 chars: "  ║ "(4) + contenido(80) + "║"(1)
  const std::string Y = style::Yellow;
  const std::string Rs = style::Reset;
  auto optLine = [&](const std::string& numColor, const std::string& num,
                     const std::string& text) {
    // " [N] texto" = 5 + text. Pad a 80 chars visual. text es ASCII puro.
    int pad = std::max(0, 80 - 5 - static_cast<int>(text.size()));
    std::cout << "  ║ " << Rs << " [" << numColor << num << Rs << "] " << text
              << std::string(pad, ' ') << Y << "║\n";
  };
  auto infoLine = [&](const std::string& label, const std::string& valColor,
                      const std::string& val) {
    // label + val. Pad a 80 chars visual. Ambos son ASCII.
    int pad = std::max(
        0, 80 - static_cast<int>(label.size()) - static_cast<int>(val.size()));
    std::cout << "  ║ " << Rs << style::White << label << valColor << val << Rs
              << std::string(pad, ' ') << Y << "║\n";
  };

  std::cout << Y
            << "  "
               "╔══════════════════════════════════════════════════════════════"
               "═══════════════════╗\n"
            << "  ║ " << Rs << "TURNO DE: " << style::Cyan << std::left
            << std::setw(70) << nombre << Y << "║\n"
            << "  "
               "╠══════════════════════════════════════════════════════════════"
               "═══════════════════╣\n";

  infoLine("Mano Actual: ", style::BrightYellow, actual);
  infoLine("Mano Probable: ", style::BrightCyan, probable);
  infoLine("Potencial Max: ", style::BrightGreen, potencial);

  std::cout << Y
            << "  "
               "╠══════════════════════════════════════════════════════════════"
               "═══════════════════╣\n"
            << "  ║ " << Rs << std::left << std::setw(80)
            << "Opciones Disponibles:" << Y << "║\n";

  optLine(style::BrightCyan, "1", "VER CARTAS (Ocultas por defecto)");
  optLine(style::BrightRed, "2", "FOLD (Retirarse)");

  if (aPagarParaIgualar == 0) {
    optLine(style::Green, "3", "CHECK (Pasar gratis)");
  } else {
    int callPosible = std::min(aPagarParaIgualar, miSaldo);
    optLine(
        style::Green, "3",
        "CALL (Igualar la apuesta por " + std::to_string(callPosible) + ")");
  }

  if (miSaldo > aPagarParaIgualar) {
    optLine(style::Yellow, "4", "RAISE (Subir apuesta)");
  } else {
    optLine(style::Gray, "4", "RAISE (Bloq. Saldo insuficiente)");
  }

  optLine(style::BrightMagenta, "5",
          "ALL-IN (Apostar todo tu saldo: " + std::to_string(miSaldo) + ")");

  std::cout << Y
            << "  "
               "╚══════════════════════════════════════════════════════════════"
               "═══════════════════╝\n"
            << Rs;

  // Prompt final (Fuera de la caja)
  std::cout << "\n  " << style::ArrowIcon << " Opcion: ";
}

void Interfaz::dibujarAjustesBots(bool botsHabilitados,
                                  bool supervisorHabilitado,
                                  const ReglasJuego& reglas) {
  std::cout << "\n";
  std::cout << style::Cyan
            << "  ╔════════════════════════════════════════════════╗\n"
            << "  ║                " << style::Bold << "PANEL DE AJUSTES"
            << style::Reset << style::Cyan << "                ║\n"
            << "  ╚════════════════════════════════════════════════╝\n"
            << style::Reset << "\n";

  std::string estadoBots = botsHabilitados
                               ? style::BrightGreen + "ACTIVADO" + style::Reset
                               : style::Gray + "DESACTIVADO" + style::Reset;
  std::string estadoSup = supervisorHabilitado
                              ? style::BrightGreen + "ACTIVADO" + style::Reset
                              : style::Gray + "DESACTIVADO" + style::Reset;

  std::string tipoStr;
  switch (reglas.tipoLimite) {
    case TipoLimite::SIN_LIMITE:
      tipoStr = style::BrightGreen + "SIN LIMITE" + style::Reset;
      break;
    case TipoLimite::LIMITE_BOTE:
      tipoStr = style::Yellow + "LIMITE BOTE" + style::Reset;
      break;
    case TipoLimite::LIMITE_FIJO:
      tipoStr = style::Cyan + "LIMITE FIJO (" +
                std::to_string(reglas.monteFijo) + ")" + style::Reset;
      break;
  }
  std::string minRaiseStr = reglas.aplicarMinRaise
                                ? style::BrightGreen + "SI" + style::Reset
                                : style::Gray + "NO" + style::Reset;

  std::cout << "  [1] Bots en partidas      : " << estadoBots << "\n";
  std::cout << "  [2] Modo Supervisor       : " << estadoSup << "\n";
  std::cout << "  [3] Reglas de Apuesta     : " << tipoStr
            << "  |  Min Raise: " << minRaiseStr << "\n";

  std::cout << "\n"
            << style::Cyan
            << "  --------------------------------------------------\n"
            << style::Reset;
  std::cout << "  [0] Volver al menu principal\n\n  " << style::ArrowIcon
            << " ";
}

void Interfaz::dibujarPanelReglas(const ReglasJuego& reglas) {
  std::cout << "\n";
  std::cout << style::Yellow
            << "  ╔════════════════════════════════════════════════╗\n"
            << "  ║            " << style::Bold << "CONFIGURACION DE REGLAS"
            << style::Reset << style::Yellow << "             ║\n"
            << "  ╚════════════════════════════════════════════════╝\n"
            << style::Reset << "\n";

  // Tipo de límite actual
  std::string tipoStr;
  switch (reglas.tipoLimite) {
    case TipoLimite::SIN_LIMITE:
      tipoStr = style::BrightGreen + "SIN LIMITE (No-Limit)" + style::Reset;
      break;
    case TipoLimite::LIMITE_BOTE:
      tipoStr = style::Yellow + "LIMITE BOTE (Pot-Limit)" + style::Reset;
      break;
    case TipoLimite::LIMITE_FIJO:
      tipoStr = style::Cyan + "LIMITE FIJO (" +
                std::to_string(reglas.monteFijo) + " fichas)" + style::Reset;
      break;
  }
  std::string minStr =
      reglas.aplicarMinRaise
          ? style::BrightGreen + "SI (raise >= apuesta actual)" + style::Reset
          : style::Gray + "NO (cualquier cantidad)" + style::Reset;

  std::string difStr;
  switch (reglas.dificultadBots) {
    case DificultadBots::FACIL:
      difStr =
          style::BrightGreen + "FACIL   (equity + posicion)" + style::Reset;
      break;
    case DificultadBots::NORMAL:
      difStr = style::Yellow + "NORMAL  (rango + outs + river)" + style::Reset;
      break;
    case DificultadBots::EXPERTO:
      difStr =
          style::Magenta + "EXPERTO (+ perfilado de rivales)" + style::Reset;
      break;
  }

  std::cout << "  Tipo de limite actual : " << tipoStr << "\n";
  std::cout << "  Raise minimo forzado  : " << minStr << "\n";
  std::cout << "  Dificultad de bots    : " << difStr << "\n\n";

  std::cout << "  [1] Cambiar tipo de limite  (cicla: Sin Limite -> Pot-Limit "
               "-> Fixed)\n";
  std::cout << "  [2] " << (reglas.aplicarMinRaise ? "Desactivar" : "Activar")
            << " raise minimo obligatorio\n";
  if (reglas.tipoLimite == TipoLimite::LIMITE_FIJO) {
    std::cout << "  [3] Cambiar monte fijo      (actual: " << reglas.monteFijo
              << ")\n";
    std::cout << "  [4] Cambiar dificultad bots (cicla: Facil -> Normal -> "
                 "Experto)\n";
  } else {
    std::cout << "  [3] Cambiar dificultad bots (cicla: Facil -> Normal -> "
                 "Experto)\n";
  }

  std::cout << "\n"
            << style::Cyan
            << "  --------------------------------------------------\n"
            << style::Reset;
  std::cout << "  [0] Volver a Ajustes\n\n  " << style::ArrowIcon << " ";
}

void Interfaz::mostrarHistorialCompleto(
    const std::vector<PartidaStats>& historial) {
  limpiarPantalla();
  std::cout << style::Yellow << style::Bold
            << "==============================================================="
               "======\n"
            << "                 HISTORIAL GENERAL DE PARTIDAS FINALIZADAS\n"
            << "==============================================================="
               "======\n"
            << style::Reset;

  if (historial.empty()) {
    std::cout << style::Gray << "  " << style::InfoIcon
              << " No hay registros de partidas jugadas aún.\n"
              << style::Reset;
    return;
  }

  std::cout << "  " << style::Bold << std::left << std::setw(10) << "ID"
            << std::setw(25) << "FECHA Y HORA"
            << "GANADOR" << style::Reset << "\n";
  std::cout << style::Gray
            << "  "
               "-------------------------------------------------------------"
               "------\n"
            << style::Reset;

  for (size_t i = 0; i < historial.size(); ++i) {
    std::cout << style::Cyan << "  [" << std::setw(4) << (i + 1) << "]   "
              << style::Reset << std::left << std::setw(25)
              << historial[i].fechaHora << style::Green
              << historial[i].ganadorNombre << style::Reset << "\n";
  }
  std::cout << style::Gray
            << "  "
               "-------------------------------------------------------------"
               "------\n"
            << style::Reset;
  std::cout
      << "  " << style::Yellow
      << "Escribe el ID de la partida para ver detalles (o 0 para volver): "
      << style::Reset;
}

void Interfaz::mostrarDetallePartida(const PartidaStats& stats, int indice) {
  limpiarPantalla();
  std::cout << style::Cyan << style::Bold << "  DETALLES DE LA PARTIDA #"
            << indice << style::Reset << "\n";
  std::cout << style::Gray << "  " << stats.fechaHora << "\n" << style::Reset;
  std::cout << "  "
               "┌────────────────────────────────────────────────────────────"
               "───┐\n";
  std::cout << "  │ Ganador Absoluto : " << style::Green << std::left
            << std::setw(42) << stats.ganadorNombre << style::Reset << " │\n";
  std::cout << "  │ Fortuna Obtenida : " << style::Yellow << "" << std::left
            << std::setw(41) << stats.saldoFinal << style::Reset << " │\n";
  std::cout << "  │ Manos Disputadas : " << std::left << std::setw(42)
            << stats.manosJugadas << " │\n";
  std::cout << "  │ Mejor Mano       : " << style::Yellow << std::left
            << std::setw(20) << stats.mejorManoNombre << style::Reset << " por "
            << std::left << std::setw(13) << stats.mejorManoJugador << " │\n";
  std::cout << "  "
               "├────────────────────────────────────────────────────────────"
               "───┤\n";
  std::cout << "  │ " << style::Gray << std::left << std::setw(25) << "Jugador"
            << std::left << std::setw(35) << "Ronda Eliminación" << style::Reset
            << " │\n";

  for (const auto& j : stats.historialJugadores) {
    std::string status =
        (j.manoEliminacion == "X")
            ? (style::Green + "Sigue en juego" + style::Reset)
            : (style::Red + "Mano " + j.manoEliminacion + style::Reset);
    std::cout << "  │  - " << std::left << std::setw(22) << j.nombre << " : "
              << std::left << std::setw(42) << status << " │\n";
  }
  std::cout << "  "
               "└──────────────────────────────────────────────────────────────"
               "─┘\n\n";
}

// --- ENCAPSULAMIENTO RADICAL DE MENSAJES DEL PROGRAMA ---

void Interfaz::mensajeBienvenida() {
  std::cout << style::Yellow
            << "¡Bienvenido al Simulador Blindado de Texas Hold'em!\n"
            << style::Reset;
}

void Interfaz::mensajeMenuPrincipal() {
  dibujarTituloPoker();
  std::cout << style::Yellow << "         ╔═════════════════════╗\n"
            << "         ║  NUEVA PARTIDA[1]   ║\n"
            << "         ╚═════════════════════╝\n\n"
            << "         ╔═════════════════════╗\n"
            << "         ║  CARGAR PARTIDA[2]  ║\n"
            << "         ╚═════════════════════╝\n\n"
            << "         ╔═════════════════════╗\n"
            << "         ║   VER AJUSTES [3]   ║\n"
            << "         ╚═════════════════════╝\n\n"
            << "         ╔═════════════════════╗\n"
            << "         ║  VER HISTORIAL [4]  ║\n"
            << "         ╚═════════════════════╝\n\n"
            << "         ╔═════════════════════╗\n"
            << "         ║      SALIR[5]       ║\n"
            << "         ╚═════════════════════╝\n\n"
            << style::Reset;

  std::cout << "  " << style::ArrowIcon << " ¿Qué deseas hacer? ";
}

void Interfaz::mensajeBorrarArchivo(int numArchivos) {
  std::cout << "\n  " << style::BrightRed
            << "¿Qué partida deseas ELIMINAR de forma permanente? (1 - "
            << numArchivos << " o 0 para cancelar): " << style::Reset;
}

void Interfaz::mensajeRenombrarArchivo(int numArchivos) {
  std::cout << "\n  " << style::Yellow << "¿Qué partida deseas RENOMBRAR? (1 - "
            << numArchivos << " o 0 para cancelar): " << style::Reset;
}

void Interfaz::mensajeInicioMano(int numMano, int ciegaGrande) {
  std::cout << style::Cyan << "\n[MANO #" << numMano
            << "] Iniciando nueva ronda. Ciega Grande actual: " << ciegaGrande
            << style::Reset << "\n";
}

void Interfaz::mensajeCabeceraResumen() {
  std::cout
      << "\n"
      << style::Yellow << style::Bold
      << "  "
         "╔════════════════════════════════════════════════════════════════╗\n"
      << "  ║                     RESUMEN DE PARTIDA                         "
         "║\n"
      << "  "
         "╚════════════════════════════════════════════════════════════════╝\n"
         "\n"
      << style::Reset;
}

void Interfaz::mensajeCobroCiegas(const std::string& jPequena, int montoPequena,
                                  const std::string& jGrande, int montoGrande) {
  std::cout << style::Gray << "  [CIEGAS] " << jPequena
            << " aporta Ciega Pequeña (" << montoPequena << ") y " << jGrande
            << " aporta Ciega Grande (" << montoGrande << ")\n"
            << style::Reset;
}

void Interfaz::mensajeCambioDeFase(Rondas fase) {
  std::cout << style::Yellow
            << "\n>> Avanzando a la fase del juego: " << static_cast<int>(fase)
            << " <<\n"
            << style::Reset;
}

int Interfaz::preguntarExtensionPartida() {
  std::cout << "\n";
  std::cout
      << style::Yellow << style::Bold
      << "  "
         "╔════════════════════════════════════════════════════════════════╗\n"
      << "  ║                  ¡LÍMITE DE MANOS ALCANZADO!                   "
         "║\n"
      << "  "
         "╚════════════════════════════════════════════════════════════════╝\n"
      << style::Reset;

  std::cout << "  La partida ha llegado a su límite programado.\n";
  std::cout << "  ¿Quieres extender la partida jugando más manos?\n\n";

  std::cout << "    [" << style::BrightRed << "0" << style::Reset
            << "] No, terminar la partida y ver resultados.\n";
  std::cout << "    [" << style::BrightGreen << "N" << style::Reset
            << "] Sí, extender! (cantidad?)\n\n";

  std::cout << "  " << style::Cyan << "▶" << style::Reset << " Tu elección: ";

  // Usa tu función habitual para leer inputs (asegurándote de que no meta
  // letras)
  int extraManos = leerOpcionMenu(
      0, 100);  // Suponiendo que usas leerOpcionMenu y el máximo es 1000

  return extraManos;
}

void Interfaz::mensajePartidaExtendida(int manosExtra) {
  std::cout << "  " << style::Cyan << style::Bold
            << "Partida extendida por otras " << style::BrightGreen
            << manosExtra << style::Cyan << " manos, buena suerte!\n\n";
  Interfaz::mensajeAccionSistema("Reanudando Partida...");
}

void Interfaz::mensajeAccionJugador(const std::string& nombre,
                                    TipoAccion accion, int cantidad) {
  std::cout << "  " << style::ArrowIcon << " " << style::Cyan << nombre
            << style::Reset;
  switch (accion) {
    case TipoAccion::FOLD:
      std::cout << style::Gray << " se retira (FOLD).\n" << style::Reset;
      break;
    case TipoAccion::CHECK:
      std::cout << " pasa (CHECK).\n";
      break;
    case TipoAccion::CALL:
      std::cout << " iguala (CALL) por " << cantidad << ".\n";
      break;
    case TipoAccion::RAISE:
      std::cout << style::Yellow << " sube la apuesta (RAISE) a " << cantidad
                << ".\n"
                << style::Reset;
      break;
    case TipoAccion::ALL_IN:
      std::cout << style::BrightRed << " ¡PONE TODO SU SALDO (ALL-IN) por "
                << cantidad << "!\n"
                << style::Reset;
      break;
    case TipoAccion::ERROR:  // Cubrir caso del enum
      std::cout << style::Red << " intentó una acción inválida.\n"
                << style::Reset;
      break;
    case TipoAccion::VER_CARTAS:
      std::cout << style::Cyan << " observa sus cartas.\n" << style::Reset;
      break;
  }
}

void Interfaz::mensajeGanadorMano(const std::string& nombre, int boteGanado,
                                  const std::string& comboNombre) {
  std::cout << style::Green << "\n[FIN DE LA MANO] " << style::Yellow << nombre
            << style::Green << " se lleva el bote de " << style::Yellow << ""
            << boteGanado << style::Green << " gracias a: " << style::Cyan
            << comboNombre << style::Reset << "\n";
}

void Interfaz::mensajeJugadorEliminado(const std::string& nombre,
                                       int manoEliminacion) {
  std::cout << style::BrightRed << "[ELIMINACIÓN] El jugador " << nombre
            << " se ha quedado sin fichas y es eliminado en la mano "
            << manoEliminacion << ".\n"
            << style::Reset;
}

void Interfaz::mensajeFinPartidaLimiteManos(const std::string& ganador,
                                            int saldoFinal) {
  std::cout << style::Yellow
            << "\n🏆 ¡FIN DE LA PARTIDA POR LÍMITE DE MANOS! El Ganador "
               "definitivo es "
            << ganador << " con un imperio de " << saldoFinal << " 🏆\n"
            << style::Reset;
}

void Interfaz::mensajeFinPartida(const std::string& ganador, int saldoFinal) {
  std::cout << style::Yellow
            << "\n🏆 ¡FIN DE LA PARTIDA! El Ganador "
               "definitivo es "
            << ganador << " con un imperio de " << saldoFinal << " 🏆\n"
            << style::Reset;
}

void Interfaz::mensajeProgresoArchivo(const std::string& operacion,
                                      int porcentaje) {
  std::cout << style::Gray << "  [DISCO] " << operacion << "... [" << porcentaje
            << "%]\n"
            << style::Reset;
}

void Interfaz::mensajeErrorSistema(const std::string& categoria,
                                   const std::string& mensaje, int codigo) {
  std::cerr << style::BrightRed << "\n[ERROR CRÍTICO] [" << categoria
            << " (Código: " << codigo << ")] -> " << mensaje << style::Reset
            << "\n\n";
}

void Interfaz::mensajeErrorJugada(const std::string& error) {
  std::cout << style::BrightRed << "  [!] Acción Rechazada: " << error
            << style::Reset << "\n";
}

void Interfaz::mensajeInicioShowdown(
    const std::vector<Carta>& cartasComunitarias) {
  // limpiarPantalla();
  std::cout << style::Yellow << style::Bold
            << "╔══════════════════════════════════════════════════════════════"
               "══════╗\n"
            << "║                            SHOWDOWN                          "
               "      ║\n"
            << "╚══════════════════════════════════════════════════════════════"
               "══════╝\n"
            << style::Reset;
  dibujarCartasEnParalelo(cartasComunitarias);
}

void Interfaz::mensajeMuestraCartas(
    const std::string& nombre, const std::string& combo,
    const std::vector<Carta>& cartasPersonales) {
  std::cout << style::BrightWhite << "  • " << style::Cyan << nombre
            << style::Reset << " revela: " << cartasPersonales[0] << " "
            << cartasPersonales[1] << style::Yellow << " [" << combo << "!]"
            << style::Reset << std::endl;
}

void Interfaz::mostrarHistorialAccionesBots(
    const std::vector<std::string>& acciones) {
  if (!acciones.empty()) {
    // Marco 85 chars: "  ╔" (3) + 81═ + "╗" (1)
    std::cout << style::Yellow << style::Bold
              << "  ╔═════════════════════════════ HISTORIAL DE LA RONDA "
                 "═════════════════════════════╗\n"
              << style::Reset;
    for (const auto& msg : acciones) {
      // msg contiene "➜" (U+279C = 3 bytes UTF-8, 1 char visual).
      // Ancho visual = msg.size() - 2  (los 2 bytes extra de ➜).
      // Fila: "  ║ "(4v) + "▶ "(2v) + msg(visualMsg v) + pad + "║"(1v) = 85
      // → pad = 78 - visualMsg = 80 - msg.size()
      int pad = std::max(0, 80 - static_cast<int>(msg.size()));
      std::cout << style::Yellow << style::Bold << "  ║ " << style::Cyan << "▶ "
                << msg << style::Reset << std::string(pad, ' ') << style::Yellow
                << style::Bold << "║\n";
    }
    std::cout << style::Yellow << style::Bold
              << "  "
                 "╚════════════════════════════════════════════════════════════"
                 "═════════════════════╝\n"
              << style::Reset;
  }
}

void Interfaz::mensajeGanadorSinShowdown(const std::string& nombre, int bote) {
  std::cout << style::Green
            << "\n  [FIN DE LA MANO] Todos los rivales se retiraron.\n"
            << "  " << style::Yellow << nombre << style::Green
            << " gana el bote de " << bote
            << " sin tener que enseñar sus cartas.\n"
            << style::Reset;
}

void Interfaz::mensajeEvaluandoBote(int numBote, int cantidad) {
  std::string nombreBote = (numBote == 0)
                               ? "BOTE PRINCIPAL"
                               : ("SIDE POT #" + std::to_string(numBote));
  std::cout << style::Cyan << "\n  [" << nombreBote
            << "] Evaluando ganadores. Valor total: " << style::Yellow << ""
            << cantidad << style::Reset << "\n";
}

void Interfaz::mensajeGanadorBote(const std::string& nombre, int premio,
                                  int numBote, const std::string& combo) {
  std::string nombreBote = (numBote == 0)
                               ? "Bote Principal"
                               : ("Side Pot #" + std::to_string(numBote));
  std::cout << style::Green << "  >>> ¡" << style::Yellow << nombre
            << style::Green << " GANA " << style::Yellow << "" << premio
            << style::Green << " del " << nombreBote << " con " << style::Cyan
            << combo << style::Green << "! <<<\n"
            << style::Reset;
}

void Interfaz::mensajeJugadoresDerrotados(
    const std::vector<std::string>& eliminados) {
  std::cout << style::Cyan << "\n  [JUGADORES ELIMINADOS]\n";
  if (!eliminados.empty()) {
    for (const std::string& player : eliminados) {
      std::cout << style::BrightRed << "  >>> ¡" << style::Yellow << player
                << style::BrightRed << " HA PERDIDO! <<<\n";
    }
  }
}

void Interfaz::pausarYEsperar() {
  std::cout << style::Yellow << "\n  Presiona Enter para continuar..."
            << style::Reset;
  std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
  std::cin.get();
}

int Interfaz::pedirDatoConfiguracion(const std::string& mensaje, int min,
                                     int max) {
  std::cout << "  " << style::ArrowIcon << " " << mensaje << " (" << min
            << " - " << max << "): ";
  return leerOpcionMenu(
      min, max);  // Reutilizamos el lector a prueba de fallos que ya tienes
}

void Interfaz::mensajeAccionSistema(const std::string& mensaje) {
  std::cout << style::Gray << "  [SISTEMA] " << mensaje << style::Reset << "\n";
}

void Interfaz::mostrarCartasDebug(const std::vector<Player*>& jugadores,
                                  const std::vector<Carta>& cartasMesa) {
  if (jugadores.empty()) return;

  // Anchos visuales de columna (sin contar bytes de ANSI ni UTF-8 multilbyte)
  constexpr int WN = 16;  // Nombre (incluye prefijo "▶ " o "  " = 2 vis)
  constexpr int WC = 9;   // Cartas (máx "10♥  10♣" = 8 vis + 1 margen)
  constexpr int WA = 14;  // ACTUAL  ("Escalera Color" = 14)
  constexpr int WP = 14;  // PROBABLE
  constexpr int WM = 14;  // MAX

  // Rellena hasta w caracteres; solo para strings sin ANSI (byte == visual)
  auto pad = [](const std::string& s, int w) -> std::string {
    int n = static_cast<int>(s.size());
    return (n >= w) ? s.substr(0, w) : s + std::string(w - n, ' ');
  };

  // Anchura visual de una carta (valor + símbolo del palo)
  auto cardVW = [](const Carta& c) {
    return (static_cast<int>(c.getValor()) == 10) ? 3 : 2;
  };

  // Carta como string con ANSI
  auto cardStr = [](const Carta& c) -> std::string {
    std::ostringstream ss;
    ss << c;
    return ss.str();
  };

  const std::string M = style::Magenta + style::Bold;
  const std::string R = style::Reset;
  // │ es 1 char visual; Magenta para coincidir con el marco del panel
  const std::string SEP = style::Magenta + style::Bold + " │ " + R;

  // Líneas del marco: ancho total = 85 chars (con "  " de indentación)
  // Contenido entre "║ " y " ║" = WN+3+WC+3+WA+3+WP+3+WM = 79 chars visuales
  std::cout << M
            << "  ╔════════════════════════════ MODO SUPERVISOR: CARTAS "
               "════════════════════════════╗\n"
            << "  ║ " << R << style::BrightWhite << style::Bold
            << pad("Nombre", WN) << SEP << pad("Cartas", WC) << SEP
            << pad("ACTUAL", WA) << SEP << pad("PROBABLE", WP) << SEP
            << pad("MAX", WM) << M << " ║\n"
            << "  "
               "╠══════════════════╪═══════════╪════════════════╪══════════════"
               "══╪════════════════╣\n"
            << R;

  for (const auto* p : jugadores) {
    const PlayerState est = p->getEstado();
    const bool activo =
        (est == PlayerState::ACTIVO || est == PlayerState::ALL_IN);

    std::cout << M << "  ║ " << R;

    // ── Columna Nombre ────────────────────────────────────────────────
    std::string nombre = p->getNombre();
    if ((int)nombre.size() > WN - 2) nombre = nombre.substr(0, WN - 3) + ".";
    int npad = WN - 2 - (int)nombre.size();
    std::cout << (activo ? style::Cyan : style::Gray) << (activo ? "▶ " : "  ")
              << nombre << std::string(npad, ' ') << R;

    // ── Columna Cartas ────────────────────────────────────────────────
    std::cout << SEP;
    const auto& cartas = p->getCartas();
    if (cartas.size() >= 2) {
      int vw1 = cardVW(cartas[0]), vw2 = cardVW(cartas[1]);
      // Dos cartas con dos espacios entre ellas; relleno hasta WC
      std::cout << cardStr(cartas[0]) << "  " << cardStr(cartas[1])
                << std::string(WC - vw1 - 2 - vw2, ' ');
    } else {
      // Sin cartas (jugador eliminado antes del reparto)
      std::cout << style::BgWhite << style::Red << style::ErrorIcon << R << "  "
                << style::BgWhite << style::Black << style::ErrorIcon << R
                << std::string(WC - 4, ' ');  // "✖  ✖" = 4 visual
    }

    // ── Columnas Info (ACTUAL / PROBABLE / MAX) ───────────────────────
    if (activo && !cartasMesa.empty()) {
      std::string actual =
          Analyzer::evaluarMano(p->getCartasPropias(), cartasMesa).handName;
      std::string prob = Analyzer::obtenerCombinacionMasProbable(
          p->getCartasPropias(), cartasMesa);
      std::string maxima =
          Analyzer::obtenerMaximoPotencial(p->getCartasPropias(), cartasMesa);
      std::cout << SEP << style::Green << pad(actual, WA) << R << SEP
                << style::Yellow << pad(prob, WP) << R << SEP << style::Cyan
                << pad(maxima, WM) << R;
    } else if (activo) {
      // PREFLOP: sin cartas comunitarias aún
      // "─" es U+2500 (3 bytes UTF-8, 1 visual). No usar pad() con él.
      std::cout << SEP << style::Gray << "─" << std::string(WA - 1, ' ') << R
                << SEP << style::Gray << "─" << std::string(WP - 1, ' ') << R
                << SEP << style::Gray << "─" << std::string(WM - 1, ' ') << R;
    } else if (est == PlayerState::FOLD) {
      std::string actual =
          (!cartasMesa.empty() && cartas.size() >= 2)
              ? Analyzer::evaluarMano(cartas, cartasMesa).handName
              : "(fold)";
      std::cout << SEP << style::Gray << pad(actual, WA) << R << SEP
                << std::string(WP, ' ') << SEP << std::string(WM, ' ');
    } else {
      // ELIMINADO
      std::cout << SEP << style::BrightRed << pad("(ELIMINADO)", WA) << R << SEP
                << std::string(WP, ' ') << SEP << std::string(WM, ' ');
    }

    std::cout << M << " ║\n" << R;
  }

  std::cout << M
            << "  "
               "╚══════════════════╧═══════════╧════════════════╧══════════════"
               "══╧════════════════╝\n"
            << R;
}

void Interfaz::mensajeRepartoCartasIniciales() {
  std::cout
      << style::Cyan
      << "\n  [REPARTO] Distribuyendo 2 cartas ocultas a cada jugador...\n"
      << style::Reset;
}

void Interfaz::mensajeRepartiendoComunitarias(const std::string& faseDesc,
                                              int numCartas) {
  std::cout << style::Yellow << "\n  [MESA] --- REPARTIENDO EL " << faseDesc
            << " (" << numCartas << " Cartas) ---\n"
            << style::Reset;
}

int Interfaz::leerOpcionMenu(int min, int max) {
  int opcion;
  while (true) {
    if (std::cin >> opcion && opcion >= min && opcion <= max) {
      // CRÍTICO: Limpiar el buffer tras una lectura exitosa
      std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
      return opcion;
    }
    std::cin.clear();
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    std::cout << style::BrightRed << "  " << style::WarnIcon
              << " Opción inválida. Elige entre " << min << " y " << max << ": "
              << style::Reset;
  }
}

int Interfaz::leerMontoRaise(int minRaise, int maxRaise) {
  std::cout << style::Yellow
            << "  Introduce la cantidad que deseas subir (Min: " << minRaise
            << " | Max: " << maxRaise << "): " << style::Reset;
  int monto;
  while (true) {
    if (std::cin >> monto && monto >= minRaise && monto <= maxRaise) {
      // CRÍTICO: Limpiar el buffer
      std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
      return monto;
    }
    std::cin.clear();
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    std::cout << style::BrightRed << "  " << style::WarnIcon
              << " Monto inválido. Introduce un valor entre " << minRaise
              << " y " << maxRaise << ": " << style::Reset;
  }
}

std::string Interfaz::leerNombreArchivo() {
  std::string input;
  std::cout << style::Yellow
            << "   Nombre para el archivo de guardado (Presiona Enter para "
               "nombre automático): \n  "
            << style::ArrowIcon << " " << style::Reset;

  std::getline(std::cin, input);

  // SANITIZACIÓN: Eliminar espacios y caracteres especiales
  std::string sanitizado = "";
  for (char c : input) {
    if (std::isalnum(c) || c == '_' || c == '-') {
      sanitizado += c;
    }
  }

  // Si introdujo basura o lo dejó vacío, generamos uno por defecto
  if (sanitizado.empty()) {
    int numAleatorio = std::rand() % 10000;
    sanitizado = "POKER" + std::to_string(numAleatorio);
  }

  // Añadimos extensión obligatoria
  return sanitizado + ".pok";
}

int Interfaz::menuFinDeMano() {
  std::cout
      << "\n"
      << style::Cyan
      << "  "
         "╔════════════════════════════════════════════════════════════════╗\n"
      << "  ║ " << style::Bold << "MANO FINALIZADA" << style::Reset
      << style::Cyan << "                                                ║\n"
      << "  "
         "╠════════════════════════════════════════════════════════════════╣\n"
      << "  ║ [" << style::Green << "1" << style::Cyan
      << "] Siguiente Mano                                             ║\n"
      << "  ║ [" << style::Yellow << "2" << style::Cyan
      << "] Guardar Partida y Volver al Menú                           ║\n"
      << "  ║ [" << style::Red << "3" << style::Cyan
      << "] Abandonar (Sin Guardar)                                    ║\n"
      << "  "
         "╚════════════════════════════════════════════════════════════════╝\n"
      << style::Reset;
  std::cout << "  " << style::ArrowIcon << " Opción: ";
  return leerOpcionMenu(1, 3);
}

void Interfaz::mensajeFinPartidaGuardada(const std::string& archivo) {
  std::cout << style::Green << "\n  " << style::InfoIcon
            << " Partida guardada con éxito en: " << style::Yellow << archivo
            << style::Reset << "\n";
}

std::string Interfaz::pedirCadena(const std::string& mensaje) {
  std::cout << "  " << style::ArrowIcon << " " << mensaje << ": ";
  std::string input;
  std::cin >> input;
  std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
  return input;
}

void Interfaz::mostrarArchivosGuardados(
    const std::vector<ArchivoGuardado>& archivos) {
  std::cout << style::Cyan << "  --- PARTIDAS GUARDADAS DISPONIBLES ---\n\n"
            << style::Reset;

  std::cout << "  " << style::Bold << std::left << std::setw(5) << "Nº"
            << std::setw(30) << "NOMBRE DEL ARCHIVO"
            << "FECHA DE GUARDADO" << style::Reset << "\n";
  std::cout
      << "  ------------------------------------------------------------\n";

  for (size_t i = 0; i < archivos.size(); ++i) {
    std::cout << "  [" << style::Yellow << i + 1 << style::Reset << "] "
              << std::left << std::setw(26) << archivos[i].nombre << "    "
              << style::Gray << archivos[i].fecha << style::Reset << "\n";
  }
  std::cout
      << "  ------------------------------------------------------------\n";
  std::cout << "\n  [" << style::BrightRed << archivos.size() + 1
            << style::Reset << "] ELIMINAR una partida\n";
  std::cout << "  [" << style::Yellow << archivos.size() + 2 << style::Reset
            << "] RENOMBRAR una partida\n\n";
  std::cout << "  [" << style::Yellow << "0" << style::Reset
            << "] Cancelar y volver al Menú Principal\n\n  ➜ ";
}

void Interfaz::mostrarBarraCarga(int tiempoTotalMs = 1500) {
  const int longitudBarra = 30;  // Cantidad de "cuadritos" de la barra
  int tiempoPorPaso = tiempoTotalMs / longitudBarra;

  std::cout << "  ";  // Margen izquierdo

  for (int i = 0; i <= longitudBarra; ++i) {
    // '\r' vuelve el cursor al inicio de la línea sin saltar hacia abajo
    std::cout << "\r  [";

    // Pintamos la parte llena
    for (int j = 0; j < i; ++j) {
      std::cout << "■";  // Puedes cambiarlo por '#', '=' o '█'
    }

    // Pintamos la parte vacía
    for (int j = i; j < longitudBarra; ++j) {
      std::cout << "=";
    }

    // Calculamos el porcentaje
    int porcentaje = (i * 100) / longitudBarra;
    std::cout << "] " << porcentaje << "%"
              << std::flush;  // flush es OBLIGATORIO aquí

    // Dormimos el programa hasta el siguiente fotograma
    if (i < longitudBarra) {
      std::this_thread::sleep_for(std::chrono::milliseconds(tiempoPorPaso));
    }
  }
  std::cout << "\n\n";  // Salto de línea final cuando termina
}