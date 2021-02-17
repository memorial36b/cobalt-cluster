# Crystal: Custom Commands

# Friendly wrapper for command entries.
class CustomCommand
  # Construct a new CustomCommand.
  def initialize(hash)
    @command_name    = hash[:command_name]
    @owner_user_id   = hash[:owner_user_id]
    @item_entry_id   = hash[:item_entry_id]
    @command_content = hash[:command_content]
  end

  # Get the command's name/invocation identifier.
  def command_name
    return @command_name
  end

  # Get the command's owner's user id.
  def owner_user_id
    return @owner_user_id
  end

  # Get the item entry id.
  def item_entry_id
    return @item_entry_id
  end

  # Get the command's message content.
  def command_content
    return @command_content
  end
end

# Helper functions for custom command management
# Commands of duplicate names can exit, but the implementation will differ user to user.
# Handles processing custom command calls
module Bot::CustomCommands
  extend Discordrb::EventContainer
  extend Convenience
  include Constants
    
  # User created custom commands
  # { command_name, owner_user_id, item_entry_id, command_content }
  USER_CUSTOM_COMMANDS = DB[:econ_custom_commands]

  # Path to economy data folder
  ECON_DATA_PATH = "#{Bot::DATA_PATH}/economy".freeze

  # Limits the number of custom commands per second
  CUSTOM_COMMAND_BUCKET = Bot::BOT.bucket(
      :custom_command_spam_filter,
      limit:     1, # count per
      time_span: 2  # seconds
  )

  # Converts command hashes to paginator fields. 
  COMMAND_HASH_TO_PAGINATOR_FIELD_LAMBDA = lambda do |hash|
    field_name  = hash[:command_name] 
    field_value = hash[:command_content]

    field_name = "_ERROR_" if field_name.nil? or field_name.empty?
    field_value = "_ERROR_" if field_value.nil? or field_value.empty?

    return PaginatorField.new(field_name, field_value)
  end

  #################
  ##   EVENTS    ##
  #################

  # Message event handler
  message do |event|
    # Breaks unless the event comes from SVTFOD and this is a normal message event
    next unless event.server == SERVER
    next unless event.class == Discordrb::Events::MessageEvent
    next unless event.message != nil

    # check that it's a command
    command_prefix = Bot::BOT.prefix
    if command_prefix.class == Array
        found = false
        command_prefix.each do |prefix|
            found |= event.message.content.start_with?(prefix)
            if found
                command_prefix = prefix
                break
            end
        end

        # not in the array
        next unless found
    else
        next unless event.message.content.start_with?(command_prefix)
    end

    # compute command name, check if it exists
    command_name = event.message.content[command_prefix.length..-1].downcase
    next if command_name =~ /\s/ # no custom commands can have parameters or spaces
    next unless Bot::BOT.commands[command_name.to_sym] == nil

    # check that user isn't spamming custom commands
    if (rate_limit = CUSTOM_COMMAND_BUCKET.rate_limited?(event.user.id))
      event.send_temporary_message("**Custom commands are on cooldown!** Wait for #{rate_limit.round}s.", 5)
      next # stop processing
    end

    # get and "execute" command
    command = GetCustomCommand(command_name, event.user.id)
    next if command == nil
    event.respond command.command_content
  end

  ##########################
  ##   HELPER FUNCTIONS   ##
  ##########################

  module_function

  # Get the max custom command name length.
  # @return [Integer] max custom command name length
  def GetMaxCustomCommandNameLength()
    limits_yaml = YAML.load_data!("#{ECON_DATA_PATH}/limits.yml")
    return limits_yaml['custom_command_name_max_length']
  end 

  # Get max custom command content length.
  # @return [Integer] max custom command content length
  def GetMaxCustomCommandContentLength()
    limits_yaml = YAML.load_data!("#{ECON_DATA_PATH}/limits.yml")
    return limits_yaml['custom_command_content_max_length']
  end

  # Get how long to wait in seconds before the configuration message times out.
  # @return [Integer] number of seconds to wait before timing out.
  def GetCustomCommandResponseTimeout()
    limits_yaml = YAML.load_data!("#{ECON_DATA_PATH}/limits.yml")
    return limits_yaml['custom_command_response_timeout']
  end

  # Add a custom command.
  # @param [String]  command_name    the name used to invoke the command
  # @param [Integer] owner_user_id   owner user's id
  # @param [Integer] item_entry_id   unique identifier of the associated item.
  # @param [String]  command_content the message to send when invoked
  # @return [bool] Success? Returns false if command already exists or name/content is too long.
  # Note: Must link to a created item.
  def AddCustomCommand(command_name, owner_user_id, item_entry_id, command_content)
    command_name = command_name.downcase # enforce lowercase command naems
    return false if command_name.length <= 0 or command_name.length > GetMaxCustomCommandNameLength() or command_content.length > GetMaxCustomCommandContentLength()
    return false if command_name =~ /\s/ # no spaces allowed
    return false if USER_CUSTOM_COMMANDS.where{Sequel.&({command_name: command_name}, {owner_user_id: owner_user_id})}.count() > 0

    
    # will raise error on invalid content
    USER_CUSTOM_COMMANDS << { command_name: command_name, owner_user_id: owner_user_id, item_entry_id: item_entry_id, command_content: command_content }
    return true
  end


  # Edit the specified custom command's content.
  # @param [String]  command_name        custom command's name
  # @param [Integer] owner_user_id       custom command owner's id
  # @param [String]  new_command_content new custom command content
  # @return [bool] Success? Returns false if not found
  def EditCustomCommand(command_name, owner_user_id, new_command_content)
    return false if new_command_content.length > GetMaxCustomCommandContentLength()
    commands = USER_CUSTOM_COMMANDS.where{Sequel.&({owner_user_id: owner_user_id}, {command_name: command_name})}
    return false if commands.count() <= 0

    commands.update(command_content: new_command_content)
    return true
  end

  # Remove the custom command with the given name
  # @param [String]  command_name  custom command's unique name
  # @param [Integer] owner_user_id custom command's owner's id
  # @return [bool] Success? Returns false if not found
  def RemoveCustomCommand(command_name, owner_user_id)
    commands = USER_CUSTOM_COMMANDS.where{Sequel.&({command_name: command_name}, {owner_user_id: owner_user_id})}
    return false if commands.count() <= 0

    commands.delete
    return true
  end

  # Remove the custom command associated with the given item_entry_id.
  # @param [Integer] item_entry_id associated item entry id
  # @return [bool] Success? Returns false if not found
  def RemoveCustomCommandByItemEntryID(item_entry_id)
    commands = USER_CUSTOM_COMMANDS.where(item_entry_id: item_entry_id)
    return false if commands == nil || commands.count <= 0

    commands.delete
    return true
  end

  # Check if a custom command with the specified name exists.
  # @param [String] command_name   custom command name
  # @param [Integer] owner_user_id custom command's owner's id
  # @return [bool] does the custom command exist?
  def HasCustomCommand(command_name, owner_user_id)
    command = USER_CUSTOM_COMMANDS[command_name: command_name, owner_user_id: owner_user_id]
    return command != nil
  end

  # Get custom command with the specified name.
  # @param [String] command_name custom command name
  # @param [Integer] owner_user_id custom command's owner's id
  # @return [CustomCommand] The custom command or nil if not found.
  def GetCustomCommand(command_name, owner_user_id)
    command = USER_CUSTOM_COMMANDS[command_name: command_name, owner_user_id: owner_user_id]
    return nil if command == nil

    # create custom command
    return CustomCommand.new(command)
  end

  # Get a custom command by its associated item.
  # @param [Integer] item_entry_id item's unique idenifier.
  # @return [CustomCommand] The custom command or nil if not found.
  def GetCustomCommandByItemEntryID(item_entry_id)
    command = USER_CUSTOM_COMMANDS[item_entry_id: item_entry_id]
    return nil if command == nil

    # create custom command
    return CustomCommand.new(command)
  end

  # Get the number of commands owned by the specified user.
  # @param [Integer] owner_user_id the user to filter by
  # @return [Integer] The number of commands the users owns
  def GetUserCustomCommandCount(owner_user_id)
    count = USER_CUSTOM_COMMANDS.where(owner_user_id: owner_user_id).count
    return count.nil? ? 0 : count
  end

  # Get all of the custom commands owned by the specified user.
  # @param [Integer] owner_user_id the user to filter by
  # @return [Array<CustomCommand>] All custom commands owned by the specified user
  def GetAllUserCustomCommands(owner_user_id)
    command_hashes = USER_CUSTOM_COMMANDS.where(owner_user_id: owner_user_id).order(:command_name).all

    commands = []
    command_hashes.each do |command|
      commands.push(CustomCommand.new(command))
    end

    return commands
  end
end
