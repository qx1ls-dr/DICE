#include <iostream>

#include <SFML/Graphics.hpp>
#include <nlohmann/json.hpp>

#include <spdlog/spdlog.h>

// Для sol2 и Lua
extern "C" {
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
}
#include <sol/sol.hpp>

int main() {
    // Инициализация логгера
    spdlog::info("DICE Application Starting...");

    // Создание окна SFML
    sf::RenderWindow window(sf::VideoMode(800, 600), "DICE - Board Game Engine");
    window.setFramerateLimit(60);

    // Тест JSON
    nlohmann::json config;
    config["window"]["width"] = 800;
    config["window"]["height"] = 600;
    config["title"] = "DICE";
    spdlog::info("Configuration: {}", config.dump(2));

    // Тест Lua
    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::math, sol::lib::string);

    lua.script(R"(
        print("Lua integration test successful!")
        function greet(name)
            return "Hello from Lua, " .. name .. "!"
        end
    )");

    std::string greeting = lua["greet"]("DICE");
    spdlog::info("{}", greeting);

    // Создание простого объекта для отрисовки
    sf::CircleShape shape(50.f);
    shape.setFillColor(sf::Color::Red);
    shape.setPosition(375.f, 275.f);

    sf::Font font;
    sf::Text text;
    text.setString("DICE Engine\nНажмите ESC для выхода");
    text.setCharacterSize(24);
    text.setFillColor(sf::Color::White);
    text.setPosition(300.f, 50.f);

    spdlog::info("Вход в основной цикл...");

    // Основной игровой цикл
    while (window.isOpen()) {
        sf::Event event;
        while (window.pollEvent(event)) {
            if (event.type == sf::Event::Closed) {
                window.close();
            }

            if (event.type == sf::Event::KeyPressed) {
                if (event.key.code == sf::Keyboard::Escape) {
                    window.close();
                }
            }

            // Пример: вращение фигуры по клику мыши
            if (event.type == sf::Event::MouseButtonPressed) {
                if (event.mouseButton.button == sf::Mouse::Left) {
                    shape.rotate(45.f);
                    spdlog::debug("Форма повернута");
                }
            }
        }

        // Очистка экрана
        window.clear(sf::Color(30, 30, 30));

        // Отрисовка
        window.draw(shape);
        window.draw(text);

        // Отображение
        window.display();
    }

    spdlog::info("Приложение DICE завершает работу...");
    return 0;
}
