/**
 * @file Persona.hpp
 * @brief Jugador humano local que lee su decisión de stdin/teclado.
 */
#pragma once

#include "Player.hpp"

/**
 * @brief Jugador humano local: lee su decisión de stdin/teclado.
 *
 * decidirAccion() muestra las opciones disponibles y valida la entrada.
 * El motor reconoce esHumano()==true y llama onPreTurnoHumano() antes
 * de cada intento para que Interfaz redibuje la pantalla.
 */
class Persona : public Player {
public:
    /// Crea un jugador humano con @p nombre y @p saldoInicial fichas.
    Persona(const std::string& nombre, int saldoInicial);

    Accion decidirAccion(const GameState& state) override;
    bool esHumano() const override { return true; }
};
