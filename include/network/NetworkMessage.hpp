#ifndef DICE_NETWORK_NETWORK_MESSAGE_HPP
#define DICE_NETWORK_NETWORK_MESSAGE_HPP

#include <chrono>
#include <cstdint>
#include <functional>
#include <optional>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

namespace dice::network {

enum class MessageType : uint8_t {
    Handshake = 0,
    HandshakeAck,
    Ping,
    Pong,
    Disconnect,

    PlayerJoined,
    PlayerLeft,
    PlayerReady,
    StartGame,

    Snapshot,
    Event,
    MoveObject,
    ActionRejected,
    UndoRequest,
    Chat,
    Invalid = 255
};

enum class PlayerStatus : uint8_t { Connecting = 0, Connected, Ready, InGame, Disconnected };

// All members are private; use accessors or aggregate-initialise via the
// static factory helpers below.
class ClientInfo {
public:
    ClientInfo() = default;
    ClientInfo(std::string id,
               std::string name,
               std::string ip,
               uint16_t    port,
               PlayerStatus status = PlayerStatus::Connecting)
        : id_(std::move(id))
        , name_(std::move(name))
        , ip_(std::move(ip))
        , port_(port)
        , status_(status)
        , lastPing_(std::chrono::steady_clock::now()) {}

    [[nodiscard]] const std::string& getId()   const { return id_; }
    [[nodiscard]] const std::string& getName() const { return name_; }
    [[nodiscard]] const std::string& getIp()   const { return ip_; }
    [[nodiscard]] uint16_t           getPort() const { return port_; }
    [[nodiscard]] PlayerStatus       getStatus() const { return status_; }
    [[nodiscard]] std::chrono::steady_clock::time_point getLastPing() const { return lastPing_; }
    [[nodiscard]] const std::string& getScriptsVersion() const { return scriptsVersion_; }

    void setId(std::string v)              { id_   = std::move(v); }
    void setName(std::string v)            { name_ = std::move(v); }
    void setIp(std::string v)              { ip_   = std::move(v); }
    void setPort(uint16_t v)               { port_ = v; }
    void setStatus(PlayerStatus v)         { status_ = v; }
    void setLastPing(std::chrono::steady_clock::time_point v) { lastPing_ = v; }
    void setScriptsVersion(std::string v)  { scriptsVersion_ = std::move(v); }
    void touchPing()                       { lastPing_ = std::chrono::steady_clock::now(); }

    [[nodiscard]] std::string toString() const {
        return name_ + " (" + ip_ + ":" + std::to_string(port_) + ")";
    }

private:
    std::string  id_;
    std::string  name_;
    std::string  ip_;
    uint16_t     port_   = 0;
    PlayerStatus status_ = PlayerStatus::Connecting;
    std::chrono::steady_clock::time_point lastPing_;
    std::string  scriptsVersion_;
};

struct NetworkMessage {
    MessageType    type       = MessageType::Invalid;
    uint32_t       sequenceId = 0;
    uint64_t       timestamp  = 0;
    std::string    fromId;
    nlohmann::json data;

    [[nodiscard]] std::vector<uint8_t> serialize() const;

    static NetworkMessage deserialize(const std::vector<uint8_t>& data);

    static NetworkMessage createHandshake(const std::string& player_name);
    static NetworkMessage createHandshakeAck(const std::string& client_id, bool game_started);
    static NetworkMessage createPlayerReady(const std::string& player_id);
    static NetworkMessage createStartGame();
    static NetworkMessage createSnapshot(const nlohmann::json& state);
    static NetworkMessage createEvent(const std::string& object_id, const std::string& event_name);
    static NetworkMessage createMoveObject(const std::string& object_id, float x, float y);
    static NetworkMessage createActionRejected(const std::string& reason);
    static NetworkMessage createUndoRequest(uint32_t target_seq = 0);
    static NetworkMessage createChat(const std::string& text);
    static NetworkMessage createPing();
    static NetworkMessage createPong();
    static NetworkMessage createPlayerJoined(const std::string& player_id,
                                             const std::string& player_name);
    static NetworkMessage createPlayerLeft(const std::string& player_id);
    static NetworkMessage createDisconnect(const std::string& reason = "");

    [[nodiscard]] bool        isValid()   const;
    [[nodiscard]] std::string toString() const;
};

class MessageBuffer {
public:
    void append(const std::vector<uint8_t>& data) {
        buffer_.insert(buffer_.end(), data.begin(), data.end());
    }

    void append(const uint8_t* data, size_t size) {
        buffer_.insert(buffer_.end(), data, data + size);
    }

    std::optional<NetworkMessage> extract() {
        if (buffer_.size() < 4) {
            return std::nullopt;
        }

        uint32_t msgLength =
            (static_cast<uint32_t>(buffer_[0]) << 24) | (static_cast<uint32_t>(buffer_[1]) << 16) |
            (static_cast<uint32_t>(buffer_[2]) << 8)  |  static_cast<uint32_t>(buffer_[3]);

        if (buffer_.size() < 4 + msgLength) {
            return std::nullopt;
        }

        std::string jsonStr(buffer_.begin() + 4, buffer_.begin() + 4 + msgLength);
        buffer_.erase(buffer_.begin(), buffer_.begin() + 4 + msgLength);

        std::vector<uint8_t> jsonData(jsonStr.begin(), jsonStr.end());
        return NetworkMessage::deserialize(jsonData);
    }

    void   clear() { buffer_.clear(); }
    [[nodiscard]] bool   empty() const { return buffer_.empty(); }
    [[nodiscard]] size_t size()  const { return buffer_.size(); }

private:
    std::vector<uint8_t> buffer_;
};

} // namespace dice::network

#endif
