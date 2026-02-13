#ifndef DICE_CHIP_HPP
#define DICE_CHIP_HPP

#include "core/GameObject.hpp"

namespace dice {
namespace components {

class Chip : public core::GameObject {
public:
    Chip(const std::string& id, const std::string& name);

    void setPlayer(int playerNum);
    int getPlayer() const;

    nlohmann::json toJson() const override;
    void fromJson(const nlohmann::json& json) override;

private:
    int playerNum_;
};

} // namespace components
} // namespace dice

#endif