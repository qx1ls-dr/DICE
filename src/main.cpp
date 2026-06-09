#include "app/AppConfig.hpp"
#include "app/Application.hpp"
#include <spdlog/spdlog.h>
#include <stdexcept>
#include <string>

namespace {
uint16_t parsePort(const std::string& s) {
    int port;
    try {
        port = std::stoi(s);
    } catch (...) {
        throw std::invalid_argument("invalid port: '" + s + "'");
    }
    if (port <= 0 || port > 65535) {
        throw std::invalid_argument("port out of range: " + s);
    }
    return static_cast<uint16_t>(port);
}
} // namespace

int main(int argc, char* argv[]) {
    spdlog::set_level(spdlog::level::info);

    std::string startScene;
    dice::AppConfig networkOverride;

    try {
        // NOLINTNEXTLINE(cppcoreguidelines-pro-bounds-pointer-arithmetic)
        for (int i = 1; i < argc; ++i) {
            // NOLINTNEXTLINE(cppcoreguidelines-pro-bounds-pointer-arithmetic)
            std::string arg = argv[i];

            if (arg == "--host" && i + 1 < argc) {
                networkOverride.networkRole = "host";
                // NOLINTNEXTLINE(cppcoreguidelines-pro-bounds-pointer-arithmetic)
                networkOverride.networkPort = parsePort(argv[++i]);
            } else if (arg == "--join" && i + 1 < argc) {
                // NOLINTNEXTLINE(cppcoreguidelines-pro-bounds-pointer-arithmetic)
                std::string addr = argv[++i];
                const auto colon = addr.find(':');
                if (colon == std::string::npos || colon == 0) {
                    spdlog::error("--join requires IP:PORT format");
                    return 1;
                }
                networkOverride.networkRole = "client";
                networkOverride.networkHost = addr.substr(0, colon);
                networkOverride.networkPort = parsePort(addr.substr(colon + 1));
            } else if (arg.empty() || arg[0] != '-') {
                startScene = arg;
            }
        }
    } catch (const std::invalid_argument& e) {
        spdlog::error("Invalid argument: {}", e.what());
        return 1;
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
