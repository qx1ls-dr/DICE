#include <fstream>

#include <SFML/Graphics.hpp>

#include "core/GameObject.hpp"
#include <gtest/gtest.h>

using namespace dice::core;

class GameObjectTest : public ::testing::Test {
protected:
    void SetUp() override {
        texture_.create(64, 64);

        sf::Uint8* pixels = new sf::Uint8[64 * 64 * 4];
        for (int i = 0; i < 64 * 64 * 4; i += 4) {
            pixels[i] = 255;
            pixels[i + 1] = 0;
            pixels[i + 2] = 0;
            pixels[i + 3] = 255;
        }
        texture_.update(pixels);
        delete[] pixels;
    }

    sf::Texture texture_;
};

// ========== Constructor tests ==========

TEST_F(GameObjectTest, DefaultConstructor) {
    GameObject obj;

    EXPECT_EQ(obj.getId(), "");
    EXPECT_EQ(obj.getName(), "Unnamed");
    EXPECT_EQ(obj.getType(), "generic");
    EXPECT_TRUE(obj.isActive());
    EXPECT_TRUE(obj.isVisible());
    EXPECT_TRUE(obj.isDraggable());
    EXPECT_EQ(obj.getZOrder(), 0);
}

TEST_F(GameObjectTest, ParameterizedConstructor) {
    GameObject obj("chip_1", "Red Chip");

    EXPECT_EQ(obj.getId(), "chip_1");
    EXPECT_EQ(obj.getName(), "Red Chip");
    EXPECT_EQ(obj.getType(), "generic");
}

// ========== Metadata tests ==========

TEST_F(GameObjectTest, SettersAndGetters) {
    GameObject obj;

    obj.setId("test_id");
    obj.setName("Test Object");
    obj.setType("chip");
    obj.setDescription("This is a test object");

    EXPECT_EQ(obj.getId(), "test_id");
    EXPECT_EQ(obj.getName(), "Test Object");
    EXPECT_EQ(obj.getType(), "chip");
    EXPECT_EQ(obj.getDescription(), "This is a test object");
}

TEST_F(GameObjectTest, TagManagement) {
    GameObject obj;

    obj.addTag("player1");
    obj.addTag("movable");

    EXPECT_TRUE(obj.hasTag("player1"));
    EXPECT_TRUE(obj.hasTag("movable"));
    EXPECT_FALSE(obj.hasTag("nonexistent"));

    auto tags = obj.getTags();
    EXPECT_EQ(tags.size(), 2);

    obj.removeTag("player1");
    EXPECT_FALSE(obj.hasTag("player1"));
    EXPECT_TRUE(obj.hasTag("movable"));

    obj.addTag("movable");
    EXPECT_EQ(obj.getTags().size(), 1);
}

// ========== Visual representation tests ==========

TEST_F(GameObjectTest, TextureAndColor) {
    GameObject obj;

    obj.setTexture(&texture_);
    EXPECT_EQ(obj.getSprite().getTexture(), &texture_);

    obj.setColor(sf::Color::Blue);
    EXPECT_EQ(obj.getColor(), sf::Color::Blue);
}

TEST_F(GameObjectTest, ZOrderManagement) {
    GameObject obj;

    obj.setZOrder(5);
    EXPECT_EQ(obj.getZOrder(), 5);

    obj.moveUp();
    EXPECT_EQ(obj.getZOrder(), 6);

    obj.moveDown();
    obj.moveDown();
    EXPECT_EQ(obj.getZOrder(), 4);
}

// ========== Transformation Tests ==========

TEST_F(GameObjectTest, Transformations) {
    GameObject obj;
    obj.setTexture(&texture_);

    obj.setPosition(100.f, 200.f);
    auto pos = obj.getPosition();
    EXPECT_FLOAT_EQ(pos.x, 100.f);
    EXPECT_FLOAT_EQ(pos.y, 200.f);

    obj.setRotation(45.f);
    EXPECT_FLOAT_EQ(obj.getRotation(), 45.f);

    obj.setScale(2.f, 2.f);
    auto scale = obj.getScale();
    EXPECT_FLOAT_EQ(scale.x, 2.f);
    EXPECT_FLOAT_EQ(scale.y, 2.f);
}

// ========== Collision tests ==========

TEST_F(GameObjectTest, BoundsAndContains) {
    GameObject obj;
    obj.setTexture(&texture_);
    obj.setPosition(100.f, 100.f);

    auto bounds = obj.getGlobalBounds();
    EXPECT_GT(bounds.width, 0.f);
    EXPECT_GT(bounds.height, 0.f);

    EXPECT_TRUE(obj.contains(sf::Vector2f(100.f, 100.f)));
    EXPECT_FALSE(obj.contains(sf::Vector2f(1000.f, 1000.f)));
}

TEST_F(GameObjectTest, Intersection) {
    GameObject obj1, obj2;
    obj1.setTexture(&texture_);
    obj2.setTexture(&texture_);

    obj1.setPosition(100.f, 100.f);
    obj2.setPosition(200.f, 200.f);

    EXPECT_FALSE(obj1.intersects(obj2));

    obj2.setPosition(110.f, 110.f);

    EXPECT_TRUE(obj1.intersects(obj2));
}

// ========== Hierarchy Tests ==========

TEST_F(GameObjectTest, ParentChildRelationship) {
    auto parent = std::make_shared<GameObject>("parent", "Parent");
    auto child1 = std::make_shared<GameObject>("child1", "Child 1");
    auto child2 = std::make_shared<GameObject>("child2", "Child 2");

    parent->addChild(child1);
    parent->addChild(child2);

    EXPECT_EQ(parent->getChildren().size(), 2);
    EXPECT_EQ(child1->getParent(), parent.get());
    EXPECT_EQ(child2->getParent(), parent.get());

    auto retrieved = parent->getChild("child1");
    EXPECT_NE(retrieved, nullptr);
    EXPECT_EQ(retrieved->getId(), "child1");

    parent->removeChild("child1");
    EXPECT_EQ(parent->getChildren().size(), 1);
    EXPECT_EQ(child1->getParent(), nullptr);
}

// TEST_F(GameObjectTest, ChildDuplicatePrevention) {
//     auto parent = std::make_shared<GameObject>("parent", "Parent");
//     auto child = std::make_shared<GameObject>("child", "Child");

//     parent->addChild(child);
//     parent->addChild(child);

//     EXPECT_EQ(parent->getChildren().size(), 1);
// }

// ========== Status Tests ==========

TEST_F(GameObjectTest, StateManagement) {
    GameObject obj;

    EXPECT_TRUE(obj.isActive());
    obj.setActive(false);
    EXPECT_FALSE(obj.isActive());

    EXPECT_TRUE(obj.isVisible());
    obj.setVisible(false);
    EXPECT_FALSE(obj.isVisible());

    EXPECT_TRUE(obj.isDraggable());
    obj.setDraggable(false);
    EXPECT_FALSE(obj.isDraggable());
}

// ========== Custom property tests ==========

TEST_F(GameObjectTest, CustomProperties) {
    GameObject obj;

    obj.setProperty("health", 100);
    EXPECT_EQ(obj.getProperty<int>("health"), 100);

    obj.setProperty("owner", std::string("Player 1"));
    EXPECT_EQ(obj.getProperty<std::string>("owner"), "Player 1");

    obj.setProperty("speed", 2.5);
    EXPECT_DOUBLE_EQ(obj.getProperty<double>("speed"), 2.5);

    EXPECT_TRUE(obj.hasProperty("health"));
    EXPECT_FALSE(obj.hasProperty("nonexistent"));

    EXPECT_EQ(obj.getProperty<int>("nonexistent", 42), 42);
}

// ========== Serialization Tests ==========

TEST_F(GameObjectTest, JsonSerialization) {
    GameObject original("chip_1", "Red Chip");
    original.setType("chip");
    original.setDescription("A red playing chip");
    original.addTag("player1");
    original.addTag("movable");
    original.setPosition(100.f, 200.f);
    original.setRotation(45.f);
    original.setZOrder(5);
    original.setProperty("value", 10);
    original.setLuaScript("scripts/chip.lua");

    nlohmann::json json = original.toJson();

    EXPECT_EQ(json["id"], "chip_1");
    EXPECT_EQ(json["name"], "Red Chip");
    EXPECT_EQ(json["type"], "chip");
    EXPECT_EQ(json["zOrder"], 5);
    EXPECT_EQ(json["luaScript"], "scripts/chip.lua");

    GameObject loaded;
    loaded.fromJson(json);

    EXPECT_EQ(loaded.getId(), "chip_1");
    EXPECT_EQ(loaded.getName(), "Red Chip");
    EXPECT_EQ(loaded.getType(), "chip");
    EXPECT_EQ(loaded.getDescription(), "A red playing chip");
    EXPECT_TRUE(loaded.hasTag("player1"));
    EXPECT_TRUE(loaded.hasTag("movable"));
    EXPECT_FLOAT_EQ(loaded.getPosition().x, 100.f);
    EXPECT_FLOAT_EQ(loaded.getPosition().y, 200.f);
    EXPECT_FLOAT_EQ(loaded.getRotation(), 45.f);
    EXPECT_EQ(loaded.getZOrder(), 5);
    EXPECT_EQ(loaded.getProperty<int>("value"), 10);
    EXPECT_EQ(loaded.getLuaScript(), "scripts/chip.lua");
}

TEST_F(GameObjectTest, JsonWithChildren) {
    auto parent = std::make_shared<GameObject>("parent", "Parent");
    auto child = std::make_shared<GameObject>("child", "Child");

    child->setPosition(10.f, 20.f);
    parent->addChild(child);


    nlohmann::json json = parent->toJson();

    EXPECT_TRUE(json.contains("children"));
    EXPECT_EQ(json["children"].size(), 1);
    EXPECT_EQ(json["children"][0]["id"], "child");
}

TEST_F(GameObjectTest, SaveAndLoadFromFile) {
    GameObject original("test_obj", "Test Object");
    original.setType("test");
    original.setPosition(50.f, 75.f);
    original.setProperty("score", 100);

    std::string filename = "/tmp/test_gameobject.json";
    {
        std::ofstream file(filename);
        nlohmann::json json = original.toJson();
        file << json.dump(2);
    }

    GameObject loaded;
    {
        std::ifstream file(filename);
        nlohmann::json json;
        file >> json;
        loaded.fromJson(json);
    }

    EXPECT_EQ(loaded.getId(), "test_obj");
    EXPECT_EQ(loaded.getName(), "Test Object");
    EXPECT_EQ(loaded.getType(), "test");
    EXPECT_EQ(loaded.getProperty<int>("score"), 100);
}

// ========== Upgrade Tests ==========

TEST_F(GameObjectTest, UpdateWithChildren) {
    auto parent = std::make_shared<GameObject>("parent", "Parent");
    auto activeChild = std::make_shared<GameObject>("active", "Active");
    auto inactiveChild = std::make_shared<GameObject>("inactive", "Inactive");

    inactiveChild->setActive(false);

    parent->addChild(activeChild);
    parent->addChild(inactiveChild);

    parent->update(0.016f);

    EXPECT_TRUE(parent->isActive());
}
