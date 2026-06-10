#include "network/HostServer.hpp"

#include <random>

#include "network/SocketUtils.hpp"
#include <spdlog/spdlog.h>

namespace dice::network {

HostServer::HostServer(core::Model&                model,
                       core::ActionManager&        action_manager,
                       scripting::LuaScriptEngine& lua)
    : model_(model), actionManager_(action_manager), lua_(lua)
    , actionValidator_(
          std::make_unique<core::ActionValidator>(model_, actionManager_, lua_, modelMutex_)) {}

HostServer::~HostServer() {
    stop();
}

bool HostServer::start(uint16_t port) {
    if (isRunning_) {
        spdlog::warn("Server already running");
        return false;
    }

    port_ = port;

    if (listener_.listen(port_) != sf::Socket::Done) {
        spdlog::error("Failed to listen on port {}", port_);
        return false;
    }

    listener_.setBlocking(false);
    isRunning_  = true;
    gameStarted_ = false;

    actionValidator_->setOnAccepted(
        [this](const core::Action& action) {
            std::visit([&](const auto& variant) {
                using T = std::decay_t<decltype(variant)>;
                if constexpr (std::is_same_v<T, core::MoveObjectAction>) {
                    const auto& mv = variant;
                    broadcast(NetworkMessage::createMoveObject(
                        mv.getObjectId(), mv.getNewPos().x, mv.getNewPos().y));
                } else {
                    // GameAction: broadcast the event, then snapshot so
                    // Lua side-effects (state changes) are synced too
                    const auto& ga = static_cast<const core::GameAction&>(variant);
                    const std::string objId =
                        ga.payload.value("object_id", std::string{});
                    if (!objId.empty()) {
                        broadcast(NetworkMessage::createEvent(objId, ga.actionType));
                    }
                    broadcastSnapshot();
                }
            }, action.data);
        });
    actionValidator_->setOnRejected(
        [this](const core::Action& action, const std::string& reason) {
            auto rejectMsg = NetworkMessage::createActionRejected(reason);
            sendToClient(action.fromPlayerId, rejectMsg);
        });
    actionValidator_->setOnUndoApplied([this]() { broadcastSnapshot(); });
    actionValidator_->start();

    lastPingTime_      = std::chrono::steady_clock::now();
    lastBroadcastTime_ = std::chrono::steady_clock::now();

    serverThread_ = std::thread(&HostServer::serverLoop, this);

    spdlog::info("Server started on port {}", port_);
    spdlog::info("Local IP: {}", getLocalIp());

    return true;
}

void HostServer::stop() {
    if (!isRunning_) {
        return;
    }
    isRunning_ = false;
    if (actionValidator_) {
        actionValidator_->stop();
    }
    listener_.close();
    {
        const std::lock_guard<std::mutex> lock(clientsMutex_);
        for (auto& [id, ctx] : clients_) {
            if (ctx->socket) {
                ctx->socket->disconnect();
            }
        }
        clients_.clear();
    }
    if (serverThread_.joinable()) {
        serverThread_.join();
    }

    spdlog::info("Server stopped");
}

void HostServer::serverLoop() {
    while (isRunning_) {
        acceptNewClients();

        std::vector<std::string> clientsCopy;
        {
            const std::lock_guard<std::mutex> lock(clientsMutex_);
            for (const auto& [id, ctx] : clients_) {
                clientsCopy.push_back(id);
            }
        }

        for (const auto& id : clientsCopy) {
            receiveFromClient(id);
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
}

void HostServer::acceptNewClients() {
    auto client = std::make_unique<sf::TcpSocket>();

    if (listener_.accept(*client) == sf::Socket::Done) {
        client->setBlocking(false);

        const std::string clientId = generateId();

        auto ctx          = std::make_shared<ClientContext>();
        ctx->socket       = std::move(client);
        ctx->info.setId(clientId);
        ctx->info.setName("Player_" + std::to_string(clients_.size() + 1));
        ctx->info.setIp(ctx->socket->getRemoteAddress().toString());
        ctx->info.setPort(ctx->socket->getRemotePort());
        ctx->info.setStatus(PlayerStatus::Connecting);
        ctx->info.touchPing();

        {
            const std::lock_guard<std::mutex> lock(clientsMutex_);
            clients_[ctx->info.getId()] = ctx;
        }

        spdlog::info("New client connected: {} ({})", ctx->info.getName(), ctx->info.getIp());

        if (onClientJoined_) {
            onClientJoined_(ctx->info);
        }
    }
}

void HostServer::receiveFromClient(const std::string& client_id) {
    std::shared_ptr<ClientContext> ctx;
    {
        const std::lock_guard<std::mutex> lock(clientsMutex_);
        auto it = clients_.find(client_id);
        if (it == clients_.end()) {
            return;
        }
        ctx = it->second;
    }

    std::vector<uint8_t> chunk(65536);
    std::size_t received = 0;

    if (ctx->socket->receive(chunk.data(), chunk.size(), received) == sf::Socket::Done) {
        chunk.resize(received);
        ctx->receiveBuffer.append(chunk);

        while (auto msg = ctx->receiveBuffer.extract()) {
            msg->fromId = client_id;

            spdlog::debug("Received: {}", msg->toString());

            {
                const std::lock_guard<std::mutex> lock(clientsMutex_);
                if (auto it = clients_.find(client_id); it != clients_.end()) {
                    it->second->info.touchPing();
                }
            }

            switch (msg->type) {
                case MessageType::Handshake:   handleHandshake(*msg);   break;
                case MessageType::PlayerReady: handlePlayerReady(*msg); break;
                case MessageType::Event:       handleEvent(*msg);       break;
                case MessageType::MoveObject:  handleMoveObject(*msg);  break;
                case MessageType::UndoRequest: handleUndo(*msg);        break;
                case MessageType::Chat:        handleChat(*msg);        break;
                case MessageType::Ping:        handlePing(*msg);        break;
                case MessageType::Disconnect:  removeClient(client_id); break;
                default:
                    spdlog::warn("Unknown message type from {}: {}",
                                 client_id, static_cast<int>(msg->type));
                    break;
            }
        }
    }
}

void HostServer::handleHandshake(const NetworkMessage& msg) {
    const std::string playerName = msg.data.value("playerName", "Unknown");

    {
        const std::lock_guard<std::mutex> lock(clientsMutex_);
        auto it = clients_.find(msg.fromId);
        if (it != clients_.end()) {
            it->second->info.setName(playerName);
            it->second->info.setStatus(PlayerStatus::Connected);
        }
    }

    spdlog::info("Player {} connected as {}", msg.fromId, playerName);

    auto ack = NetworkMessage::createHandshakeAck(msg.fromId, gameStarted_);
    sendToClient(msg.fromId, ack);

    auto joined = NetworkMessage::createPlayerJoined(msg.fromId, playerName);
    broadcast(joined, msg.fromId);

    if (gameStarted_) {
        nlohmann::json state;
        {
            const std::lock_guard<std::mutex> modelLock(modelMutex_);
            state = model_.toJson();
        }
        auto snapshot = NetworkMessage::createSnapshot(state);
        sendToClient(msg.fromId, snapshot);
    }
}

void HostServer::handlePlayerReady(const NetworkMessage& msg) {
    {
        const std::lock_guard<std::mutex> lock(clientsMutex_);
        auto it = clients_.find(msg.fromId);
        if (it != clients_.end()) {
            it->second->info.setStatus(PlayerStatus::Ready);
            spdlog::info("Player {} is ready", it->second->info.getName());
        }
    }

    auto readyMsg = NetworkMessage::createPlayerReady(msg.fromId);
    broadcast(readyMsg);

    if (onClientReady_) {
        onClientReady_(msg.fromId);
    }
}

void HostServer::handleEvent(const NetworkMessage& msg) {
    if (!gameStarted_) {
        spdlog::warn("Event received but game not started");
        return;
    }

    const std::string objectId  = msg.data.value("object_id", "");
    const std::string eventName = msg.data.value("event", "");

    if (!isEventAllowedForClient(eventName)) {
        spdlog::warn("Client {} tried to call forbidden event: {}", msg.fromId, eventName);
        auto reject = NetworkMessage::createActionRejected("Event not allowed: " + eventName);
        sendToClient(msg.fromId, reject);
        return;
    }

    spdlog::info("Event from {}: {} on {}", msg.fromId, eventName, objectId);

    // Build payload: object_id + all custom properties of the target object.
    // This lets validate_action / apply_action read e.g. payload.player
    // without having to look the object up themselves.
    nlohmann::json payload = {{"object_id", objectId}};
    {
        const std::lock_guard<std::mutex> modelLock(modelMutex_);
        auto obj = model_.getObject(objectId);
        if (!obj) {
            spdlog::warn("Event target object not found: {}", objectId);
            auto reject = NetworkMessage::createActionRejected("Object not found: " + objectId);
            sendToClient(msg.fromId, reject);
            return;
        }
        for (const auto& [k, v] : obj->getProperties()) {
            payload[k] = v;
        }
    }

    core::Action action;
    action.fromPlayerId = msg.fromId;
    action.sequenceId   = nextActionSeq_++;
    action.data         = core::GameAction{
        .actionType = eventName,
        .payload    = std::move(payload),
    };
    actionValidator_->enqueue(std::move(action));
}

void HostServer::handleMoveObject(const NetworkMessage& msg) {
    if (!gameStarted_) {
        spdlog::warn("MoveObject received but game not started");
        return;
    }

    const std::string objectId = msg.data.value("objectId", "");
    const float x = msg.data.value("x", 0.0F);
    const float y = msg.data.value("y", 0.0F);

    spdlog::info("MoveObject from {}: {} to ({}, {})", msg.fromId, objectId, x, y);

    core::Action action;
    action.fromPlayerId = msg.fromId;
    action.sequenceId   = nextActionSeq_++;
    action.data         = core::MoveObjectAction(objectId, sf::Vector2f(x, y));
    actionValidator_->enqueue(std::move(action));
}

void HostServer::handleUndo(const NetworkMessage& msg) {
    if (!gameStarted_) {
        spdlog::warn("UndoRequest received but game not started");
        return;
    }

    const uint32_t targetSeq = msg.data.value("targetSeq", 0U);
    spdlog::info("UndoRequest from {} (targetSeq={})", msg.fromId, targetSeq);
    actionValidator_->receiveUndoVote(msg.fromId, targetSeq);
}

void HostServer::handleChat(const NetworkMessage& msg) {
    const std::string text = msg.data.value("text", "");
    spdlog::info("Chat from {}: {}", msg.fromId, text);

    broadcast(msg);

    if (onChatReceived_) {
        onChatReceived_(msg.fromId, text);
    }
}

void HostServer::handlePing(const NetworkMessage& msg) {
    auto pong = NetworkMessage::createPong();
    sendToClient(msg.fromId, pong);

    const std::lock_guard<std::mutex> lock(clientsMutex_);
    auto it = clients_.find(msg.fromId);
    if (it != clients_.end()) {
        it->second->info.touchPing();
    }
}

bool HostServer::isEventAllowedForClient(const std::string& event_name) const {
    return allowedEvents_.contains(event_name);
}

void HostServer::sendToClient(const std::string& client_id, const NetworkMessage& msg) {
    std::shared_ptr<ClientContext> ctx;
    {
        const std::lock_guard<std::mutex> lock(clientsMutex_);
        auto it = clients_.find(client_id);
        if (it == clients_.end()) {
            return;
        }
        ctx = it->second;
    }

    auto data   = msg.serialize();
    auto status = sendAll(*ctx->socket, data);
    if (status != sf::Socket::Done) {
        spdlog::warn("Failed to send to client {}, status: {}", client_id, static_cast<int>(status));
    }
}

void HostServer::broadcast(const NetworkMessage& msg, const std::string& exclude_id) {
    auto data = msg.serialize();

    const std::lock_guard<std::mutex> lock(clientsMutex_);
    for (const auto& [id, ctx] : clients_) {
        if (id == exclude_id) {
            continue;
        }
        auto status = sendAll(*ctx->socket, data);
        if (status != sf::Socket::Done) {
            spdlog::warn("Broadcast failed for client {}, status: {}", id, static_cast<int>(status));
        }
    }
}

void HostServer::removeClient(const std::string& client_id) {
    std::shared_ptr<ClientContext> ctx;
    {
        const std::lock_guard<std::mutex> lock(clientsMutex_);
        auto it = clients_.find(client_id);
        if (it != clients_.end()) {
            ctx = it->second;
            clients_.erase(it);
        }
    }

    if (ctx) {
        spdlog::info("Client disconnected: {}", ctx->info.getName());

        auto left = NetworkMessage::createPlayerLeft(client_id);
        broadcast(left);

        if (onClientLeft_) {
            onClientLeft_(client_id);
        }
    }
}

void HostServer::update() {
    const auto  now     = std::chrono::steady_clock::now();
    const float elapsed = std::chrono::duration<float>(now - lastPingTime_).count();

    if (elapsed >= pingInterval_) {
        auto ping = NetworkMessage::createPing();
        broadcast(ping);
        lastPingTime_ = now;
    }

    checkTimeouts();

    if (gameStarted_) {
        const float snapshotElapsed =
            std::chrono::duration<float>(now - lastBroadcastTime_).count();
        if (snapshotElapsed >= broadcastInterval_) {
            broadcastSnapshot();
            lastBroadcastTime_ = now;
        }
    }
}

void HostServer::checkTimeouts() {
    const auto now = std::chrono::steady_clock::now();
    std::vector<std::string> timedOut;

    {
        const std::lock_guard<std::mutex> lock(clientsMutex_);
        for (const auto& [id, ctx] : clients_) {
            const float elapsed =
                std::chrono::duration<float>(now - ctx->info.getLastPing()).count();
            if (elapsed > timeoutInterval_) {
                timedOut.push_back(id);
            }
        }
    }

    for (const auto& id : timedOut) {
        spdlog::warn("Client {} timed out", id);
        removeClient(id);
    }
}

void HostServer::broadcastEvent(const std::string& object_id, const std::string& event_name) {
    broadcast(NetworkMessage::createEvent(object_id, event_name));
}

void HostServer::broadcastMoveObject(const std::string& object_id, float x, float y) {
    broadcast(NetworkMessage::createMoveObject(object_id, x, y));
}

void HostServer::broadcastSnapshot() {
    nlohmann::json state;
    {
        const std::lock_guard<std::mutex> modelLock(modelMutex_);
        state = model_.toJson();
    }
    broadcast(NetworkMessage::createSnapshot(state));
}

void HostServer::startGame() {
    if (gameStarted_) {
        return;
    }
    gameStarted_ = true;

    auto startMsg = NetworkMessage::createStartGame();
    broadcast(startMsg);

    broadcastSnapshot();

    if (onGameStarted_) {
        onGameStarted_();
    }

    spdlog::info("Game started!");
}

void HostServer::kickClient(const std::string& client_id) {
    auto kick = NetworkMessage::createDisconnect("Kicked by host");
    sendToClient(client_id, kick);
    removeClient(client_id);
}

void HostServer::sendChat(const std::string& text) {
    auto chat = NetworkMessage::createChat(text);
    broadcast(chat);
}

std::string HostServer::getLocalIp() {
    return sf::IpAddress::getLocalAddress().toString();
}

std::vector<ClientInfo> HostServer::getClients() const {
    const std::lock_guard<std::mutex> lock(clientsMutex_);
    std::vector<ClientInfo> result;
    result.reserve(clients_.size());
    for (const auto& [id, ctx] : clients_) {
        result.push_back(ctx->info);
    }
    return result;
}

std::string HostServer::generateId() {
    static std::random_device rd;
    static std::mt19937 gen(rd());
    static std::mutex genMutex;
    static std::uniform_int_distribution<int> dis(0, 15);

    const std::lock_guard<std::mutex> lock(genMutex);
    const std::string hex = "0123456789abcdef";
    std::string id = "client_";
    id.reserve(id.size() + 16);
    for (int i = 0; i < 16; ++i) {
        id += hex[static_cast<std::size_t>(dis(gen))];
    }
    return id;
}

void HostServer::setOnClientJoined(std::function<void(const ClientInfo&)> handler) {
    onClientJoined_ = std::move(handler);
}

void HostServer::setOnClientLeft(std::function<void(const std::string&)> handler) {
    onClientLeft_ = std::move(handler);
}

void HostServer::setOnClientReady(std::function<void(const std::string&)> handler) {
    onClientReady_ = std::move(handler);
}

void HostServer::setOnGameStarted(std::function<void()> handler) {
    onGameStarted_ = std::move(handler);
}

void HostServer::setOnChatReceived(
    std::function<void(const std::string&, const std::string&)> handler) {
    onChatReceived_ = std::move(handler);
}

} // namespace dice::network
