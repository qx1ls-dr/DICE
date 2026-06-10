#ifndef DICE_ACTION_VALIDATOR_HPP
#define DICE_ACTION_VALIDATOR_HPP

#include <atomic>
#include <condition_variable>
#include <functional>
#include <mutex>
#include <queue>
#include <string>
#include <thread>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include <nlohmann/json.hpp>

#include "core/Action.hpp"
#include "core/ActionManager.hpp"
#include "core/Model.hpp"

namespace dice::scripting {
class LuaScriptEngine;
} // namespace dice::scripting

namespace dice::core {

// ---------------------------------------------------------------------------
// Validation result for a single action
// ---------------------------------------------------------------------------

enum class ValidationResult : uint8_t {
    Accept, ///< Action accepted and state updated
    Reject, ///< Action rejected (Lua returned false from validate_action)
    Error,  ///< Internal error (missing object, missing function, etc.)
};

// ---------------------------------------------------------------------------
// Undo request (consensus voting)
// ---------------------------------------------------------------------------

struct UndoRequest {
    std::string requesterId;               ///< who requested it
    uint32_t targetSeq = 0;                ///< sequence to roll back to (0 = last)
    std::unordered_set<std::string> votes; ///< players who voted yes
};

// ---------------------------------------------------------------------------
// ActionValidator
//
// Runs in a separate host thread.
// Pipeline:
//   1. Client -> NetworkMessage::Action -> host enqueues via enqueue()
//   2. Worker thread dequeues Action and calls processAction()
//   3. processAction():
//      a. For MoveObjectAction — canExecute() / execute()
//      b. For GameAction       — calls Lua validate_action() / apply_action()
//   4. On success calls onAccepted_ (host sends Snapshot)
//   5. On rejection calls onRejected_ (host sends ActionRejected to client)
//
// Undo (undo by consensus):
//   1. Client sends UndoRequest
//   2. Host calls receiveUndoVote()
//   3. When enough votes are collected, performUndo() is called
//      and onAccepted_ is triggered (with undo notification)
// ---------------------------------------------------------------------------

class ActionValidator {
public:
    ActionValidator(Model& model,
                    ActionManager& actionManager,
                    scripting::LuaScriptEngine& lua,
                    std::mutex& modelMutex);
    ~ActionValidator();

    ActionValidator(const ActionValidator&) = delete;
    ActionValidator(ActionValidator&&) = delete;
    ActionValidator& operator=(const ActionValidator&) = delete;
    ActionValidator& operator=(ActionValidator&&) = delete;

    // -- Lifecycle ---------------------------------------------------------

    void start();
    void stop();
    bool isRunning() const {
        return running_;
    }

    // -- Enqueue -----------------------------------------------------------

    /// Enqueue an action (called from the host network thread)
    void enqueue(Action action);

    // -- Undo by consensus -------------------------------------------------

    /// Number of player votes required to approve an undo.
    /// Default = 0, meaning anyone can undo.
    /// Set to total player count for unanimous approval.
    void setUndoQuorum(size_t quorum) {
        undoQuorum_ = quorum;
    }

    /// Called when a client sends an undo request or vote.
    /// playerId   ID of the voting client
    /// targetSeq  action sequence to roll back to (0 = last)
    void receiveUndoVote(const std::string& playerId, uint32_t targetSeq = 0);

    /// Clear any pending undo vote (for example after a new accepted action)
    void clearUndoVoting();

    // -- Callbacks (called from the worker thread) -------------------------

    /// Action accepted: host should broadcast a Snapshot
    void setOnAccepted(std::function<void(const Action&)> cb) {
        onAccepted_ = std::move(cb);
    }

    /// Action rejected: host should notify the client
    void setOnRejected(std::function<void(const Action&, const std::string& reason)> cb) {
        onRejected_ = std::move(cb);
    }

    /// Undo applied: host should broadcast a Snapshot
    void setOnUndoApplied(std::function<void()> cb) {
        onUndoApplied_ = std::move(cb);
    }

    // -- Stats (thread-safe) -----------------------------------------------

    size_t pendingCount() const;
    uint32_t lastProcessedSeq() const {
        return lastSeq_;
    }

private:
    // -- Worker loop -------------------------------------------------------

    void workerLoop();
    ValidationResult processAction(const Action& action);

    ValidationResult processMoveObject(const MoveObjectAction& mv, const std::string& fromPlayer);
    ValidationResult processGameAction(const GameAction& ga, const std::string& fromPlayer);

    // -- Undo internals ----------------------------------------------------

    void tryPerformUndo();

    // -- Fields ------------------------------------------------------------

    Model& model_;
    ActionManager& actionManager_;
    scripting::LuaScriptEngine& lua_;
    std::mutex& modelMutex_;

    std::queue<Action> queue_;
    mutable std::mutex queueMutex_;
    std::condition_variable cv_;

    std::atomic<bool> running_{false};
    std::thread worker_;

    std::atomic<uint32_t> lastSeq_{0};
    size_t undoQuorum_{0};

    std::unique_ptr<UndoRequest> pendingUndo_;
    std::mutex undoMutex_;

    std::function<void(const Action&)> onAccepted_;
    std::function<void(const Action&, const std::string& reason)> onRejected_;
    std::function<void()> onUndoApplied_;
};

} // namespace dice::core

#endif // DICE_ACTION_VALIDATOR_HPP