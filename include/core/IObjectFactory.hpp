#ifndef DICE_IOBJECT_FACTORY_HPP
#define DICE_IOBJECT_FACTORY_HPP

#include <memory>
#include <string>

#include "core/GameObject.hpp"

namespace dice::core {

enum class ObjectType {
    GameObject,
    Chip,
    Card,
};

inline ObjectType objectTypeFromString(const std::string& s) {
    if (s == "Chip")       return ObjectType::Chip;
    if (s == "Card")       return ObjectType::Card;
    return ObjectType::GameObject;
}

class IObjectFactory {
public:
    virtual ~IObjectFactory() = default;
    virtual std::shared_ptr<GameObject>
    create(ObjectType type, const std::string& id, const std::string& name) = 0;
};

class GameObjectFactory : public IObjectFactory {
public:
    std::shared_ptr<GameObject>
    create(ObjectType, const std::string& id, const std::string& name) override {
        return std::make_shared<GameObject>(id, name);
    }
};

} // namespace dice::core

#endif // DICE_IOBJECT_FACTORY_HPP
