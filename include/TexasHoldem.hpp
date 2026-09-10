/**
 * @file TexasHoldem.hpp
 * @brief Variante Texas Hold'em del motor de juego (2 cartas privadas + 5 comunitarias).
 */
#pragma once

#include "Partida.hpp"
#include "GameTypes.hpp"

/**
 * @brief Variante Texas Hold'em: implementa las reglas específicas de reparto.
 *
 * - repartirCartasIniciales(): 2 cartas privadas por jugador.
 * - ejecutarFaseComunitaria(): 3 cartas en el flop, 1 en turn y 1 en river.
 * - manoTerminada(): true cuando se ha completado el river.
 */
class TexasHoldem : public Partida {
public:
    TexasHoldem(const std::vector<std::string>& nombresHumanos, int numBots,
                int saldoInicial, int manosObjetivo, int valorCiegaGrande,
                bool supervisor, const ReglasJuego& reglas = ReglasJuego{});

    /// Constructor para modo red: jugadores pre-construidos (NetworkPlayer + Bot).
    TexasHoldem(std::vector<Player*> jugadores, int manosObjetivo,
                int ciegaGrande, bool supervisor,
                const ReglasJuego& reglas = ReglasJuego{});

    /// Constructor para reanudar desde un PartidaSnapshot guardado.
    TexasHoldem(PartidaSnapshot);

    ~TexasHoldem() override = default;

    /// Reparte 2 cartas privadas a cada jugador activo.
    void repartirCartasIniciales() override;
    /// Destapa 3 cartas en el flop, 1 en el turn y 1 en el river según la fase actual.
    void ejecutarFaseComunitaria() override;
    /// @return true cuando el river ha sido completado (5 cartas comunitarias repartidas).
    bool manoTerminada() override;
};
