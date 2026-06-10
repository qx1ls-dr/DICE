#ifndef DICE_ACTION_HPP
#define DICE_ACTION_HPP

#include <cstdint>
#include <string>
#include <variant>

#include <SFML/System/Vector2.hpp>
#include <nlohmann/json.hpp>

namespace dice::core {

class Model;

class MoveObjectAction {
public:
    MoveObjectAction() = default;
    MoveObjectAction(std::string object_id, sf::Vector2f new_pos);

    bool execute(Model& model) const;
    [[nodiscard]] bool canExecute(const Model& model) const;

    [[nodiscard]] const std::string& getObjectId() const {
        return objectId_;
    }
    [[nodiscard]] const sf::Vector2f& getNewPos() const {
        return newPos_;
    }

private:
    std::string objectId_;
    sf::Vector2f newPos_;
};

struct GameAction {
    std::string actionType;
    nlohmann::json payload;
};

struct Action {
    uint32_t sequenceId = 0;
    std::string fromPlayerId;
    std::variant<MoveObjectAction, GameAction> data;
};

} // namespace dice::core

#endif
