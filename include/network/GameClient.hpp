#ifndef DICE_NETWORK_GAME_CLIENT_HPP
#define DICE_NETWORK_GAME_CLIENT_HPP

#include <atomic>
#include <functional>
#include <memory>
#include <mutex>
#include <thread>
#include <unordered_map>

#include <SFML/Network.hpp>

#include "core/Action.hpp"
#include "core/ActionManager.hpp"
#include "core/Model.hpp"
#include "network/NetworkMessage.hpp"
#include "scripting/LuaScriptEngine.hpp"

namespace dice::network {

class GameClient {
public:
    GameClient();
    ~GameClient();

    GameClient(const GameClient&)            = delete;
    GameClient& operator=(const GameClient&) = delete;
    GameClient(GameClient&&)                 = delete;
    GameClient& operator=(GameClient&&)      = delete;

    bool connect(const std::string& host_ip, uint16_t port, const std::string& player_name);
    void disconnect();

    [[nodiscard]] bool isConnected()   const { return isConnected_; }
    [[nodiscard]] bool isGameStarted() const { return gameStarted_; }

    [[nodiscard]] std::string getClientId() const { return clientId_; }

    void sendEvent(const std::string& object_id, const std::string& event_name);
    void sendMoveObject(const std::string& object_id, float x, float y);
    void sendUndo(uint32_t target_seq = 0);
    void sendReady();
    void sendChat(const std::string& text);

    void update();

    void setModel(core::Model* model)                      { model_         = model; }
    void setActionManager(core::ActionManager* action_manager) { actionManager_ = action_manager; }
    void setLuaEngine(scripting::LuaScriptEngine* lua)     { lua_           = lua; }

    void setOnConnected(std::function<void(const std::string&)> handler);
    void setOnDisconnected(std::function<void()> handler);
    void setOnPlayerJoined(std::function<void(const ClientInfo&)> handler);
    void setOnPlayerLeft(std::function<void(const std::string&)> handler);
    void setOnPlayerReady(std::function<void(const std::string&)> handler);
    void setOnGameStarted(std::function<void()> handler);
    void setOnChatReceived(
        std::function<void(const std::string& from_id, const std::string& text)> handler);
    void setOnActionRejected(std::function<void(const std::string& reason)> handler);

private:
    void receiveLoop();
    void handleMessage(const NetworkMessage& msg);
    void send(const NetworkMessage& msg);

    void applyEvent(const std::string& object_id, const std::string& event_name);
    void applyMoveObject(const std::string& object_id, float x, float y);
    void applySnapshot(const nlohmann::json& state);

    MessageBuffer receiveBuffer_;

    sf::TcpSocket  socket_;
    std::mutex     socketMutex_;
    std::string    clientId_;
    std::mutex     clientIdMutex_;
    std::string    serverIp_;
    uint16_t       serverPort_ = 0;

    std::atomic<bool> isConnected_{false};
    std::atomic<bool> gameStarted_{false};
    std::chrono::steady_clock::time_point lastPingTime_;

    std::thread       receiveThread_;
    std::atomic<bool> running_{false};

    core::Model*                model_          = nullptr;
    core::ActionManager*        actionManager_  = nullptr;
    scripting::LuaScriptEngine* lua_            = nullptr;

    std::function<void(const std::string&)>              onConnected_;
    std::function<void()>                                onDisconnected_;
    std::function<void(const ClientInfo&)>               onPlayerJoined_;
    std::function<void(const std::string&)>              onPlayerLeft_;
    std::function<void(const std::string&)>              onPlayerReady_;
    std::function<void()>                                onGameStarted_;
    std::function<void(const std::string&, const std::string&)> onChatReceived_;
    std::function<void(const std::string&)>              onActionRejected_;
};

} // namespace dice::network

#endif
