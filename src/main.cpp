#include <stdexcept>
#include <string>

#include "app/AppConfig.hpp"
#include "app/Application.hpp"
#include <spdlog/spdlog.h>

int main(int argc, char* argv[]) {
    spdlog::set_level(spdlog::level::info);

    std::string startScene;
    dice::AppConfig networkOverride;

    // NOLINTNEXTLINE(cppcoreguidelines-pro-bounds-pointer-arithmetic)
    for (int i = 1; i < argc; ++i) {
        // NOLINTNEXTLINE(cppcoreguidelines-pro-bounds-pointer-arithmetic)
        std::string arg = argv[i];

        if (arg == "--host" && i + 1 < argc) {
            networkOverride.networkRole = "host";
            // NOLINTNEXTLINE(cppcoreguidelines-pro-bounds-pointer-arithmetic)
            networkOverride.networkPort = static_cast<uint16_t>(std::stoi(argv[++i]));
        } else if (arg == "--join" && i + 1 < argc) {
            // NOLINTNEXTLINE(cppcoreguidelines-pro-bounds-pointer-arithmetic)
            std::string addr = argv[++i];
            const auto colon = addr.find(':');
            if (colon == std::string::npos) {
                spdlog::error("--join requires IP:PORT format");
                return 1;
            }
            networkOverride.networkRole = "client";
            networkOverride.networkHost = addr.substr(0, colon);
            networkOverride.networkPort = static_cast<uint16_t>(std::stoi(addr.substr(colon + 1)));
        } else if (arg.empty() || arg[0] != '-') {
            startScene = arg;
        }
    }

    try {
        dice::Application app;
        app.run(startScene, networkOverride);
    } catch (const std::exception& e) {
        spdlog::critical("Unhandled exception: {}", e.what());
        return 1;
    }

    return 0;
}
