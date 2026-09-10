#include "../include/HandPredictor.hpp"

#include <cstddef>
#include <cstdlib>
#include <map>

#include "../include/Analyzer.hpp"

HandPrediccion predecirMano(const std::vector<Carta>& propias,
                            const std::vector<Carta>& mesa) {
  HandPrediccion info;
  int numMesa = static_cast<int>(mesa.size());

  if (numMesa == 0) {
    // Preflop: caracterizar las hole cards sin evaluar mano completa
    if (propias.size() < 2) {
      info.actual = "?";
      return info;
    }
    int v1 = static_cast<int>(propias[0].getValor());
    int v2 = static_cast<int>(propias[1].getValor());
    bool pocket = (v1 == v2);
    bool suited = (propias[0].getPalo() == propias[1].getPalo());
    bool connected = (std::abs(v1 - v2) == 1);
    bool oneGap = (std::abs(v1 - v2) == 2);

    if (pocket)
      info.actual = "Pocket pair";
    else if (suited && connected)
      info.actual = "Suited connector";
    else if (suited && oneGap)
      info.actual = "Suited 1-gap";
    else if (suited)
      info.actual = "Suited";
    else if (connected)
      info.actual = "Connectors";
    else
      info.actual = "Offsuit";

    info.probable = "—";
    info.maxima = "—";
    return info;
  }

  // Postflop: mano actual
  auto res = Analyzer::evaluarMano(propias, mesa);
  info.actual = res.handName;

  int faltantes = 5 - numMesa;
  if (faltantes == 0) {
    info.probable = info.actual;
    info.maxima = info.actual;
    return info;
  }

  // Cartas desconocidas (ni en la mano ni en la mesa)
  std::vector<Carta> desconocidas;
  desconocidas.reserve(52);
  for (int p = static_cast<int>(Palo::CORAZONES);
       p <= static_cast<int>(Palo::PICAS); ++p) {
    for (int v = static_cast<int>(Valor::DOS); v <= static_cast<int>(Valor::AS);
         ++v) {
      Carta c(static_cast<Palo>(p), static_cast<Valor>(v));
      bool usada = false;
      for (auto& x : propias)
        if (c == x) {
          usada = true;
          break;
        }
      if (!usada)
        for (auto& x : mesa)
          if (c == x) {
            usada = true;
            break;
          }
      if (!usada) desconocidas.push_back(c);
    }
  }

  std::map<std::string, int> freq;
  long long bestScore = 0;

  auto evalBoard = [&](std::vector<Carta> board) {
    auto r = Analyzer::evaluarMano(propias, board);
    freq[r.handName]++;
    if (r.score > bestScore) {
      bestScore = r.score;
      info.maxima = r.handName;
    }
  };

  if (faltantes == 1) {
    // Turn → River: enumerar 1 carta (~46 evaluaciones)
    for (auto& c : desconocidas) {
      auto board = mesa;
      board.push_back(c);
      evalBoard(board);
    }
  } else {
    // Flop → Turn+River: enumerar pares C(47,2)=1081
    for (std::size_t i = 0; i + 1 < desconocidas.size(); ++i) {
      for (std::size_t j = i + 1; j < desconocidas.size(); ++j) {
        auto board = mesa;
        board.push_back(desconocidas[i]);
        board.push_back(desconocidas[j]);
        evalBoard(board);
      }
    }
  }

  // Mano más frecuente = probable
  int mf = 0;
  for (auto& [name, cnt] : freq)
    if (cnt > mf) {
      mf = cnt;
      info.probable = name;
    }

  return info;
}
