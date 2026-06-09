#include "app/Application.hpp"
#include <spdlog/spdlog.h>

// Usage:
//   dice                              — singleplayer, reads game.json
//   dice <scene>                      — singleplayer, specific scene
//   dice --config game_host.json      — host, reads game_host.json
//   dice --config game_client.json    — client, reads game_client.json

int main(int argc, char* argv[]) {
    spdlog::set_level(spdlog::level::info);

    std::string startScene;
    std::string configPath = "game.json";

    for (int i = 1; i < argc; ++i) {
        // NOLINTNEXTLINE(cppcoreguidelines-pro-bounds-pointer-arithmetic)
        std::string arg = argv[i];
        if (arg == "--config" && i + 1 < argc) {
            // NOLINTNEXTLINE(cppcoreguidelines-pro-bounds-pointer-arithmetic)
            configPath = argv[++i];
        } else {
            startScene = arg;
        }
    }

    try {
        dice::Application app(configPath);
        app.run(startScene);
    } catch (const std::exception& e) {
        spdlog::critical("Unhandled exception: {}", e.what());
        return 1;
    }

    return 0;
}
