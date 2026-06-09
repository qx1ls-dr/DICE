#include "network/NetworkMessage.hpp"
#include <gtest/gtest.h>

using namespace dice::network;

TEST(NetworkMessageTest, CreateStateHasCorrectType) {
    auto msg = NetworkMessage::createState("{\"score\":42}");
    EXPECT_EQ(msg.type, MessageType::State);
}

TEST(NetworkMessageTest, CreateStatePayloadRoundtrip) {
    const std::string payload = R"({"scores":[5,10],"currentPlayer":2})";
    auto msg = NetworkMessage::createState(payload);
    EXPECT_EQ(msg.data.value("payload", ""), payload);
}

TEST(NetworkMessageTest, StateSerializeDeserializeRoundtrip) {
    const std::string payload = R"({"x":1})";
    auto original = NetworkMessage::createState(payload);
    auto bytes = original.serialize();
    auto restored = NetworkMessage::deserialize(bytes);
    EXPECT_EQ(restored.type, MessageType::State);
    EXPECT_EQ(restored.data.value("payload", ""), payload);
}
