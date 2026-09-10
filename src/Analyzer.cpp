#include "../include/Analyzer.hpp"

#include <algorithm>
#include <cmath>
#include <map>

std::string Analyzer::obtenerCombinacionMasProbable(
    const std::vector<Carta>& mano, const std::vector<Carta>& mesa) {
  if (mesa.size() < 3) return "N/A (Preflop)";
  if (mesa.size() >= 5) return evaluarMano(mano, mesa).handName;

  // 1. Reconstruir baraja restante (idéntico a obtenerMaximoPotencial)
  std::vector<Carta> mazoCompleto;
  for (int p = 0; p < 4; ++p) {
    for (int v = 2; v <= 14; ++v) {
      mazoCompleto.push_back(
          Carta(static_cast<Palo>(p), static_cast<Valor>(v)));
    }
  }

  auto contiene = [](const std::vector<Carta>& vec, const Carta& c) {
    for (const auto& vc : vec) {
      if (vc.getValor() == c.getValor() && vc.getPalo() == c.getPalo())
        return true;
    }
    return false;
  };

  std::vector<Carta> desconocidas;
  for (const auto& c : mazoCompleto) {
    if (!contiene(mano, c) && !contiene(mesa, c)) {
      desconocidas.push_back(c);
    }
  }

  // Mapa para contar cuántas veces se repite cada nombre de mano
  std::map<std::string, int> frecuencias;

  // 2. Simulación de escenarios
  if (mesa.size() == 4) {  // TURN: 46 combinaciones
    for (const auto& c1 : desconocidas) {
      std::vector<Carta> mesaSimulada = mesa;
      mesaSimulada.push_back(c1);
      frecuencias[evaluarMano(mano, mesaSimulada).handName]++;
    }
  } else if (mesa.size() == 3) {  // FLOP: 1081 combinaciones
    for (size_t i = 0; i < desconocidas.size(); ++i) {
      for (size_t j = i + 1; j < desconocidas.size(); ++j) {
        std::vector<Carta> mesaSimulada = mesa;
        mesaSimulada.push_back(desconocidas[i]);
        mesaSimulada.push_back(desconocidas[j]);
        frecuencias[evaluarMano(mano, mesaSimulada).handName]++;
      }
    }
  }

  // 3. Buscar la jugada que acumuló más "votos"
  std::string combinacionMasFrecuente = "";
  int maxVotos = -1;

  for (const auto& [nombreMano, votos] : frecuencias) {
    if (votos > maxVotos) {
      maxVotos = votos;
      combinacionMasFrecuente = nombreMano;
    }
  }

  return combinacionMasFrecuente;
}

std::string Analyzer::obtenerMaximoPotencial(const std::vector<Carta>& mano,
                                             const std::vector<Carta>& mesa) {
  // En Preflop (menos de 3 cartas en mesa), no tiene sentido el cálculo
  // exhaustivo
  if (mesa.size() < 3) {
    return "N/A (Preflop)";
  }
  // En River (5 cartas), la mano máxima ya es tu mano actual
  if (mesa.size() >= 5) {
    return evaluarMano(mano, mesa).handName;
  }

  // 1. Reconstruir las cartas desconocidas
  std::vector<Carta> mazoCompleto;
  for (int p = 0; p < 4; ++p) {
    for (int v = 2; v <= 14; ++v) {
      mazoCompleto.push_back(
          Carta(static_cast<Palo>(p), static_cast<Valor>(v)));
    }
  }

  auto contiene = [](const std::vector<Carta>& vec, const Carta& c) {
    for (const auto& vc : vec) {
      if (vc.getValor() == c.getValor() && vc.getPalo() == c.getPalo())
        return true;
    }
    return false;
  };

  std::vector<Carta> desconocidas;
  for (const auto& c : mazoCompleto) {
    if (!contiene(mano, c) && !contiene(mesa, c)) {
      desconocidas.push_back(c);
    }
  }

  long long maxScore = -1;
  std::string mejorManoNombre = "";

  // 2. Fuerza bruta según la ronda
  if (mesa.size() == 4) {
    // TURN: Faltan 1 carta (aprox 46 iteraciones)
    for (const auto& c1 : desconocidas) {
      std::vector<Carta> mesaSimulada = mesa;
      mesaSimulada.push_back(c1);
      HandResult res = evaluarMano(mano, mesaSimulada);
      if (res.score > maxScore) {
        maxScore = res.score;
        mejorManoNombre = res.handName;
      }
    }
  } else if (mesa.size() == 3) {
    // FLOP: Faltan 2 cartas (aprox 1081 iteraciones)
    for (size_t i = 0; i < desconocidas.size(); ++i) {
      for (size_t j = i + 1; j < desconocidas.size(); ++j) {
        std::vector<Carta> mesaSimulada = mesa;
        mesaSimulada.push_back(desconocidas[i]);
        mesaSimulada.push_back(desconocidas[j]);
        HandResult res = evaluarMano(mano, mesaSimulada);
        if (res.score > maxScore) {
          maxScore = res.score;
          mejorManoNombre = res.handName;
        }
      }
    }
  }

  return mejorManoNombre;
}

// La fórmula matemática aplicada: Score = Rank * 15^5 + C1 * 15^4 + C2 * 15^3 +
// C3 * 15^2 + C4 * 15^1 + C5 * 15^0
long long Analyzer::calcularScoreFinal(HandRank rank,
                                       const std::vector<Carta>& best5) {
  long long score = static_cast<long long>(rank) * 759375;  // 15^5 = 759375
  long long multiplicador = 50625;                          // Empezamos en 15^4

  for (const auto& carta : best5) {
    score += static_cast<long long>(carta.getValor()) * multiplicador;
    multiplicador /= 15;
  }
  return score;
}

HandResult Analyzer::evaluarMano(const std::vector<Carta>& mano,
                                 const std::vector<Carta>& mesa) {
  std::vector<Carta> todasLasCartas = mano;
  todasLasCartas.reserve(7);
  todasLasCartas.insert(todasLasCartas.end(), mesa.begin(), mesa.end());

  // 1. Normalización Única: Ordenamos de mayor a menor una sola vez
  std::sort(todasLasCartas.begin(), todasLasCartas.end(),
            [](const Carta& a, const Carta& b) {
              return a.getValor() > b.getValor();  // Mayor a menor
            });

  HandResult result;
  // Para este ejemplo, te muestro cómo integrar Color y Parejas/Tríos con los
  // kickers:
  if (buscarEscaleraColor(todasLasCartas, result)) return result;
  if (buscarPoker(todasLasCartas, result)) return result;
  if (buscarFullHouse(todasLasCartas, result)) return result;
  if (buscarColor(todasLasCartas, result)) return result;
  if (buscarEscalera(todasLasCartas, result)) return result;
  if (buscarTrio(todasLasCartas, result)) return result;
  if (buscarDoblePareja(todasLasCartas, result)) return result;
  if (buscarPareja(todasLasCartas, result)) return result;
  result.handName = "Carta Alta";
  result.combination.assign(todasLasCartas.begin(), todasLasCartas.begin() + 5);
  result.score = calcularScoreFinal(HandRank::CARTA_ALTA, result.combination);

  return result;
}

bool Analyzer::buscarColor(const std::vector<Carta>& cartas,
                           HandResult& result) {
  std::map<Palo, std::vector<Carta>> palos;

  for (const auto& carta : cartas) {
    palos[carta.getPalo()].push_back(carta);
  }

  for (const auto& par : palos) {
    if (par.second.size() >= 5) {
      // Como las cartas entraron ordenadas, las 5 primeras son las más altas
      result.combination.assign(par.second.begin(), par.second.begin() + 5);
      result.handName = "Color";
      result.score = calcularScoreFinal(HandRank::COLOR, result.combination);
      return true;
    }
  }
  return false;
}

bool Analyzer::buscarEscaleraColor(const std::vector<Carta>& cartas,
                                   HandResult& result) {
  std::map<Palo, std::vector<Carta>> palos;
  for (const auto& carta : cartas) {
    palos[carta.getPalo()].push_back(carta);
  }

  for (const auto& par : palos) {
    if (par.second.size() >= 5) {
      HandResult tempResult;
      if (buscarEscalera(par.second, tempResult)) {
        result = tempResult;

        // Detectar si es Escalera Real comprobando el primer valor de la
        // escalera encontrada
        if (result.combination[0].getValor() == Valor::AS) {
          result.handName = "Escalera Real";
          result.score =
              calcularScoreFinal(HandRank::ESCALERA_REAL, result.combination);
        } else {
          result.handName = "Escalera Color";
          result.score =
              calcularScoreFinal(HandRank::ESCALERA_COLOR, result.combination);
        }
        return true;
      }
    }
  }
  return false;
}

bool Analyzer::buscarPoker(const std::vector<Carta>& cartas,
                           HandResult& result) {
  for (size_t i = 0; i + 3 < cartas.size(); ++i) {
    if (cartas[i].getValor() == cartas[i + 3].getValor()) {
      result.combination.assign(cartas.begin() + i, cartas.begin() + i + 4);

      // Buscar el mejor kicker (1 carta)
      for (const auto& c : cartas) {
        if (c.getValor() != cartas[i].getValor()) {
          result.combination.push_back(c);
          break;
        }
      }

      result.handName = "Poker";
      result.score = calcularScoreFinal(HandRank::POKER, result.combination);
      return true;
    }
  }
  return false;
}

bool Analyzer::buscarFullHouse(const std::vector<Carta>& cartas,
                               HandResult& result) {
  int valorTrio = -1;
  std::vector<Carta> trioCartas;

  // Buscar el trío más alto
  for (size_t i = 0; i + 2 < cartas.size(); ++i) {
    if (cartas[i].getValor() == cartas[i + 2].getValor()) {
      valorTrio = static_cast<int>(cartas[i].getValor());
      trioCartas.assign(cartas.begin() + i, cartas.begin() + i + 3);
      break;
    }
  }

  if (valorTrio != -1) {
    // Buscar la pareja más alta que no sea parte del trío
    for (size_t i = 0; i + 1 < cartas.size(); ++i) {
      if (cartas[i].getValor() == cartas[i + 1].getValor() &&
          static_cast<int>(cartas[i].getValor()) != valorTrio) {
        result.combination = trioCartas;
        result.combination.push_back(cartas[i]);
        result.combination.push_back(cartas[i + 1]);

        result.handName = "Full House";
        result.score =
            calcularScoreFinal(HandRank::FULL_HOUSE, result.combination);
        return true;
      }
    }
  }
  return false;
}

bool Analyzer::buscarEscalera(const std::vector<Carta>& cartas,
                              HandResult& result) {
  if (cartas.empty()) return false;

  // 1. Filtrar duplicados (si hay pareja de 8, solo necesitamos un 8 para
  // evaluar la escalera)
  std::vector<Carta> unicas;
  unicas.push_back(cartas[0]);
  for (size_t i = 1; i < cartas.size(); ++i) {
    if (cartas[i].getValor() != unicas.back().getValor()) {
      unicas.push_back(cartas[i]);
    }
  }

  // 2. Buscar escalera normal (5 cartas consecutivas)
  for (size_t i = 0; i + 4 < unicas.size(); ++i) {
    if (static_cast<int>(unicas[i].getValor()) -
            static_cast<int>(unicas[i + 4].getValor()) ==
        4) {
      result.combination.assign(unicas.begin() + i, unicas.begin() + i + 5);
      result.handName = "Escalera";
      result.score = calcularScoreFinal(HandRank::ESCALERA, result.combination);
      return true;
    }
  }

  // 3. Caso especial: Escalera baja (A-2-3-4-5) asumiendo que el As = 14
  if (!unicas.empty() && unicas[0].getValor() == Valor::AS) {
    std::vector<Carta> lowStraight;
    for (int val = 5; val >= 2; --val) {
      bool encontrada = false;
      for (const auto& c : unicas) {
        if (static_cast<int>(c.getValor()) == val) {
          lowStraight.push_back(c);
          encontrada = true;
          break;
        }
      }
      if (!encontrada) break;
    }

    if (lowStraight.size() == 4) {
      // Tenemos 5,4,3,2. Añadimos el As al FINAL para que puntúe como carta
      // baja en el score.
      result.combination = lowStraight;
      result.combination.push_back(unicas[0]);

      result.handName = "Escalera";
      result.score = calcularScoreFinal(HandRank::ESCALERA, result.combination);
      return true;
    }
  }
  return false;
}

bool Analyzer::buscarTrio(const std::vector<Carta>& cartas,
                          HandResult& result) {
  for (size_t i = 0; i + 2 < cartas.size(); ++i) {
    if (cartas[i].getValor() == cartas[i + 2].getValor()) {
      result.combination.assign(cartas.begin() + i, cartas.begin() + i + 3);

      // Buscar los 2 mejores kickers
      for (const auto& c : cartas) {
        if (c.getValor() != cartas[i].getValor()) {
          result.combination.push_back(c);
          if (result.combination.size() == 5) break;
        }
      }

      result.handName = "Trio";
      result.score = calcularScoreFinal(HandRank::TRIO, result.combination);
      return true;
    }
  }
  return false;
}

bool Analyzer::buscarDoblePareja(const std::vector<Carta>& cartas,
                                 HandResult& result) {
  std::vector<Carta> parejas;
  int valorP1 = -1, valorP2 = -1;

  for (size_t i = 0; i + 1 < cartas.size(); ++i) {
    if (cartas[i].getValor() == cartas[i + 1].getValor()) {
      if (valorP1 == -1) {
        valorP1 = static_cast<int>(cartas[i].getValor());
        parejas.push_back(cartas[i]);
        parejas.push_back(cartas[i + 1]);
        ++i;  // Saltar la siguiente carta para no solapar
      } else if (valorP2 == -1 &&
                 static_cast<int>(cartas[i].getValor()) != valorP1) {
        valorP2 = static_cast<int>(cartas[i].getValor());
        parejas.push_back(cartas[i]);
        parejas.push_back(cartas[i + 1]);
        break;  // Ya encontramos las dos parejas
      }
    }
  }

  if (parejas.size() == 4) {
    result.combination = parejas;

    // Buscar el mejor kicker (1 carta)
    for (const auto& c : cartas) {
      if (static_cast<int>(c.getValor()) != valorP1 &&
          static_cast<int>(c.getValor()) != valorP2) {
        result.combination.push_back(c);
        break;
      }
    }

    result.handName = "Doble Pareja";
    result.score =
        calcularScoreFinal(HandRank::DOBLE_PAREJA, result.combination);
    return true;
  }
  return false;
}

bool Analyzer::buscarPareja(const std::vector<Carta>& cartas,
                            HandResult& result) {
  for (size_t i = 0; i + 1 < cartas.size(); ++i) {
    if (cartas[i].getValor() == cartas[i + 1].getValor()) {
      result.combination.assign(cartas.begin() + i, cartas.begin() + i + 2);

      // Buscar los 3 mejores kickers
      for (const auto& c : cartas) {
        if (c.getValor() != cartas[i].getValor()) {
          result.combination.push_back(c);
          if (result.combination.size() == 5) break;
        }
      }

      result.handName = "Pareja";
      result.score = calcularScoreFinal(HandRank::PAREJA, result.combination);
      return true;
    }
  }
  return false;
}
