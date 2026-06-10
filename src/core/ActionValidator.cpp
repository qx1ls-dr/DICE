#include "core/ActionValidator.hpp"

#include "scripting/LuaScriptEngine.hpp"
#include <spdlog/spdlog.h>

namespace dice::core {

// ---------------------------------------------------------------------------
// Lua function names that a game must define for GameAction
// ---------------------------------------------------------------------------

/// function validate_action(player_id: string, action_type: string, payload: table) -> bool, string
///   Returns true if the action is allowed, or false and a reason if not.
///   Called BEFORE the game state is modified.
static constexpr const char* LUA_VALIDATE = "validate_action";

/// function apply_action(player_id: string, action_type: string, payload: table)
///   Applies the action to the game state. Called ONLY if validate_action returned true.
static constexpr const char* LUA_APPLY = "apply_action";

/// function on_undo(snapshot_index: int)
///   Called after the engine restores a snapshot.
///   snapshot_index is how many steps back were taken (always >= 1).
///   Optional function — undo still happens even if not defined.
static constexpr const char* LUA_ON_UNDO = "on_undo";

// ---------------------------------------------------------------------------

ActionValidator::ActionValidator(Model&                     model,
                                 ActionManager&             action_manager,
                                 scripting::LuaScriptEngine& lua,
                                 std::mutex&                model_mutex)
    : model_(model), actionManager_(action_manager), lua_(lua), modelMutex_(model_mutex) {}

ActionValidator::~ActionValidator() {
    stop();
}

void ActionValidator::start() {
    if (running_) {
        return;
    }
    running_ = true;
    worker_  = std::thread(&ActionValidator::workerLoop, this);
    spdlog::info("ActionValidator: started");
}

void ActionValidator::stop() {
    if (!running_) {
        return;
    }
    running_ = false;
    cv_.notify_all();
    if (worker_.joinable()) {
        worker_.join();
    }
    spdlog::info("ActionValidator: stopped");
}

void ActionValidator::enqueue(Action action) {
    {
        const std::lock_guard<std::mutex> lk(queueMutex_);
        queue_.push(std::move(action));
    }
    cv_.notify_one();
}

size_t ActionValidator::pendingCount() const {
    const std::lock_guard<std::mutex> lk(queueMutex_);
    return queue_.size();
}

// ---------------------------------------------------------------------------
// Worker loop
// ---------------------------------------------------------------------------

void ActionValidator::workerLoop() {
    while (running_) {
        Action action;

        {
            std::unique_lock<std::mutex> lk(queueMutex_);
            cv_.wait(lk, [this] { return !queue_.empty() || !running_; });
            if (!running_ && queue_.empty()) {
                break;
            }
            action = std::move(queue_.front());
            queue_.pop();
        }

        const ValidationResult result = processAction(action);

        if (result == ValidationResult::Accept) {
            lastSeq_.store(action.sequenceId);
            clearUndoVoting();
            if (onAccepted_) {
                onAccepted_(action);
            }
        } else {
            const std::string reason =
                result == ValidationResult::Reject ? "Rejected by game rules" : "Internal error";
            spdlog::warn("ActionValidator: action seq={} from='{}' -> {}",
                         action.sequenceId,
                         action.fromPlayerId,
                         reason);
            if (onRejected_) {
                onRejected_(action, reason);
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Core validation dispatch
// ---------------------------------------------------------------------------

ValidationResult ActionValidator::processAction(const Action& action) {
    return std::visit(
        [&](const auto& variant) -> ValidationResult {
            using T = std::decay_t<decltype(variant)>;
            if constexpr (std::is_same_v<T, MoveObjectAction>) {
                return processMoveObject(variant, action.fromPlayerId);
            } else {
                return processGameAction(variant, action.fromPlayerId);
            }
        },
        action.data);
}

// ---------------------------------------------------------------------------
// MoveObjectAction — validation by C++
// ---------------------------------------------------------------------------

ValidationResult ActionValidator::processMoveObject(const MoveObjectAction& mv,
                                                    const std::string&      from_player) {
    if (!mv.canExecute(model_)) {
        spdlog::warn("ActionValidator: MoveObject rejected — '{}' is not draggable or not found",
                     mv.getObjectId());
        return ValidationResult::Reject;
    }

    const std::lock_guard<std::mutex> lock(modelMutex_);
    actionManager_.saveSnapshot(model_);
    mv.execute(model_);

    spdlog::debug(
        "ActionValidator: MoveObject accepted — '{}' by '{}'", mv.getObjectId(), from_player);
    return ValidationResult::Accept;
}

// ---------------------------------------------------------------------------
// GameAction — validation by Lua
//
// Contract for the game script (Lua):
//
//   -- Required function: check whether an action is allowed
//   -- Returns: true        — action is permitted
//   --          false, "reason"  — action is forbidden
//   function validate_action(player_id, action_type, payload)
//       ...
//       return true
//       -- or
//       return false, "not your turn"
//   end
//
//   -- Required function: apply the action to the game state
//   -- Called only if validate_action returned true
//   function apply_action(player_id, action_type, payload)
//       ...
//   end
//
//   -- Optional function: reaction to an undo
//   function on_undo(steps_back)
//       ...
//   end
//
// payload is passed as a Lua table (JSON -> sol::table conversion
// is done by jsonToLua below).
// ---------------------------------------------------------------------------

// Helper: iteratively converts nlohmann::json into a sol::object.
// Uses an explicit stack to avoid recursion (misc-no-recursion).
// NOLINTNEXTLINE(misc-no-recursion) — false positive, stack-based iteration
static sol::object jsonToLua(const nlohmann::json& j, sol::state& lua) { // NOLINT(misc-no-recursion)
    if (j.is_null())             { return sol::make_object(lua, sol::lua_nil); }
    if (j.is_boolean())          { return sol::make_object(lua, j.get<bool>()); }
    if (j.is_number_integer())   { return sol::make_object(lua, j.get<long long>()); }
    if (j.is_number_float())     { return sol::make_object(lua, j.get<double>()); }
    if (j.is_string())           { return sol::make_object(lua, j.get<std::string>()); }
    if (j.is_array()) {
        sol::table t = lua.create_table();
        int idx = 1;
        for (const auto& el : j) {
            t[idx++] = jsonToLua(el, lua); // NOLINT(misc-no-recursion)
        }
        return t;
    }
    if (j.is_object()) {
        sol::table t = lua.create_table();
        for (const auto& [k, v] : j.items()) {
            t[k] = jsonToLua(v, lua); // NOLINT(misc-no-recursion)
        }
        return t;
    }
    return sol::make_object(lua, sol::lua_nil);
}

ValidationResult ActionValidator::processGameAction(const GameAction&  ga,
                                                    const std::string& from_player) {
    const std::lock_guard<std::mutex> lock(modelMutex_);

    // -- 1. Check whether validate_action is defined in Lua -----------
    if (!lua_.hasGlobalVariable(LUA_VALIDATE)) {
        // If the game did not define validate_action, accept everything
        // (for backward compatibility with simple scenes)
        spdlog::debug("ActionValidator: no '{}' defined — auto-accepting", LUA_VALIDATE);
        // But apply_action is always needed
        if (lua_.hasGlobalVariable(LUA_APPLY)) {
            actionManager_.saveSnapshot(model_);
            lua_.callGlobal(LUA_APPLY, from_player, ga.actionType,
                            jsonToLua(ga.payload, lua_.getRawState()));
        }
        return ValidationResult::Accept;
    }

    // -- 2. Call validate_action ------------------------------------
    bool allowed = false;
    std::string rejectReason;
    {
        auto result = lua_.callGlobalRet<bool, std::string>(
            LUA_VALIDATE, from_player, ga.actionType,
            jsonToLua(ga.payload, lua_.getRawState()));
        if (!result) {
            return ValidationResult::Error;
        }
        auto [ok, reason] = *result;
        allowed      = ok;
        rejectReason = std::move(reason);
    }

    if (!allowed) {
        spdlog::info("ActionValidator: GameAction '{}' from '{}' REJECTED: {}",
                     ga.actionType,
                     from_player,
                     rejectReason.empty() ? "no reason given" : rejectReason);
        return ValidationResult::Reject;
    }

    // -- 3. Save the snapshot and apply action ---------------------
    actionManager_.saveSnapshot(model_);

    if (lua_.hasGlobalVariable(LUA_APPLY)) {
        lua_.callGlobal(LUA_APPLY, from_player, ga.actionType,
                        jsonToLua(ga.payload, lua_.getRawState()));
    } else {
        spdlog::warn("ActionValidator: '{}' missing — action accepted but not applied", LUA_APPLY);
    }

    spdlog::debug("ActionValidator: GameAction '{}' from '{}' ACCEPTED", ga.actionType, from_player);
    return ValidationResult::Accept;
}

// ---------------------------------------------------------------------------
// Undo by consensus
// ---------------------------------------------------------------------------

void ActionValidator::receiveUndoVote(const std::string& player_id, uint32_t target_seq) {
    const std::lock_guard<std::mutex> lk(undoMutex_);

    if (!pendingUndo_) {
        pendingUndo_ = std::make_unique<UndoRequest>();
        pendingUndo_->requesterId = player_id;
        pendingUndo_->targetSeq   = target_seq;
        spdlog::info("ActionValidator: undo request started by '{}'", player_id);
    }

    pendingUndo_->votes.insert(player_id);
    spdlog::info("ActionValidator: undo vote from '{}' ({}/{})",
                 player_id,
                 pendingUndo_->votes.size(),
                 undoQuorum_);

    tryPerformUndo();
}

void ActionValidator::clearUndoVoting() {
    const std::lock_guard<std::mutex> lk(undoMutex_);
    pendingUndo_.reset();
}

void ActionValidator::tryPerformUndo() {
    // Called with undoMutex_ held
    if (!pendingUndo_) {
        return;
    }
    const size_t needed = undoQuorum_ == 0 ? 1 : undoQuorum_;
    if (pendingUndo_->votes.size() < needed) {
        return;
    }

    if (!actionManager_.canUndo()) {
        spdlog::warn("ActionValidator: undo requested but nothing to undo");
        pendingUndo_.reset();
        return;
    }

    const std::lock_guard<std::mutex> modelLock(modelMutex_);

    // Determine how many steps to roll back
    int steps = 1;
    if (pendingUndo_->targetSeq > 0 && lastSeq_ > pendingUndo_->targetSeq) {
        steps = static_cast<int>(lastSeq_ - pendingUndo_->targetSeq);
    }

    for (int i = 0; i < steps && actionManager_.canUndo(); ++i) {
        actionManager_.undo(model_);
    }

    spdlog::info("ActionValidator: undo performed ({} steps)", steps);

    if (lua_.hasGlobalVariable(LUA_ON_UNDO)) {
        lua_.callGlobal(LUA_ON_UNDO, steps);
    }

    pendingUndo_.reset();

    if (onUndoApplied_) {
        onUndoApplied_();
    }
}

} // namespace dice::core
