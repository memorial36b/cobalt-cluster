# Module: DM

# Enumeration: Defines possible DM actions, include to use directly.
module DMAction
  DM_ACTION_NONE                 = 0
  DM_REPORT                      = 1
  DM_ACTION_ADD_TAG              = 2
  DM_ACTION_EDIT_TAG             = 3
  DM_ACTION_LIST_TAGS            = 4
  DM_ACTION_ADD_CUSTOM_COMMAND   = 5
  DM_ACTION_EDIT_CUSTOM_COMMAND  = 6
  DM_ACTION_LIST_CUSTOM_COMMANDS = 7
end

# Helper functions managing which action a user is currently performing
# in their DMs. This can be used to prevent overlapping commands.
module Bot::DM
  include DMAction

  # Thread coordination
  DATA_LOCK = Mutex.new

  # Map of users to their current action.
  # A user can only be performing one DM action at a time.
  @@user_dm_actions = {}

  module_function

  # Set a user's current action, perform a block if set, then clear
  # the current action.
  # @param [Integer] user_id the user
  # @param [DMAction] action the action
  # @return [bool] Was the block (action) performed?
  def do_action?(user_id, action)
    did_action = false
    if set_action?(user_id, action)
      yield
      
      was_cleared = clear_action?(user_id, action)
      throw RuntimeError, "Failed to clear action!" unless was_cleared

      did_action = true
    end

    return did_action
  end

  # Set the user's current action.
  # @param [Integer] user_id the user
  # @param [DMAction] action the action
  # @return [bool] Could action be set? Fails if already set. 
  def set_action?(user_id, action)
    was_set = false
    DATA_LOCK.synchronize do
      if @@user_dm_actions[user_id].nil?
        @@user_dm_actions[user_id] = action
        was_set = true
      end
    end

    return was_set
  end

  # Get the user's current action.
  # @param [Integer] user_id the user
  # @return [DMAction] The user's current DM action.
  def action(user_id)
    action = nil
    DATA_LOCK.synchronize do
      action = @@user_dm_actions[user_id]
    end
    return action.nil? ? DM_ACTION_NONE : action
  end

  # Check if the user has a current action.
  # @return [bool] Is the user performing an action?
  def action?(user_id)
    return action(user_id) == DM_ACTION_NONE
  end

  # Clear users action if it's current the specified one.
  # @param [Integer] user_id the user
  # @param [DMAction] action the action
  # @return Was it cleared?
  def clear_action?(user_id, action)
    was_cleared = false
    DATA_LOCK.synchronize do
      if @@user_dm_actions[user_id] == action
        @@user_dm_actions.delete(user_id)
        was_cleared = true
      end
    end

    return was_cleared
  end
end