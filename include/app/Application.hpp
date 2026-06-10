#ifndef DICE_APP_APPLICATION_HPP
#define DICE_APP_APPLICATION_HPP

#include <memory>
#include <string>

#include <SFML/Graphics.hpp>

#include "app/AppConfig.hpp"
#include "controller/Controller.hpp"
#include "core/ActionManager.hpp"
#include "core/Model.hpp"
#include "core/ResourceManager.hpp"
#include "network/NetworkManager.hpp"
#include "scripting/LuaScriptEngine.hpp"
#include "ui/View.hpp"

namespace dice {

class Application {
public:
    explicit Application(const std::string& config_path = "game.json");
    ~Application();

    Application(const Application&) = delete;
    Application& operator=(const Application&) = delete;
    Application(Application&&) = delete;
    Application& operator=(Application&&) = delete;

    void run(const std::string& start_scene = {});

private:
    bool init(const std::string& start_scene);
    void handleEvents();
    void update(float dt);
    void render();
    void shutdown();

    std::string configPath_;
    AppConfig config_;
    sf::RenderWindow window_;

    core::ResourceManager<sf::Texture> textures_;
    core::ResourceManager<sf::Font> fonts_;

    core::Model model_;
    core::ActionManager actionManager_;
    view::View view_;
    scripting::LuaScriptEngine lua_;
    controller::Controller controller_;
    network::NetworkManager networkManager_;

    bool running_ = false;
    sf::Clock clock_;
};

} // namespace dice

#endif
