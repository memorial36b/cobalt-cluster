# Crystal: BasicCommands


# This crystal contains the basic commands of the bot, such as ping and exit.
module Bot::BasicCommands
  extend Discordrb::Commands::CommandContainer
  include Constants
  
  # Ping command
  command :ping do |event|
    break unless event.user.id == OWNER_ID || event.user.role?(COBALT_MOMMY_ROLE_ID) || event.user.role?(MODERATOR_ROLE_ID)
    ping = event.respond '**P** **O** **N** **G**'
    ping.edit "**P** **O** **N** **G** **|** **#{(Time.now - event.timestamp)*1000}ms**"
    sleep 10
    ping.delete
  end

  # Build Version command - Should be in this format: Build MM/DD/YYYY - Revision X (revision number should start at 0)
  command :build do |event|
    break unless event.user.id == OWNER_ID || event.user.id == COBALT_DEV_ID || event.user.role?(COBALT_MOMMY_ROLE_ID)
    ping = event.respond "Build 10/21/2020 - Revision 1"
    sleep 10
    ping.delete
  end

  # Build Version command - Should be in this format: Build MM/DD/YYYY - Revision X (revision number should start at 0)
  command :testserver do |event|
    break unless event.user.id == OWNER_ID || event.user.id == COBALT_DEV_ID
    ping = event.respond "https://discord.gg/PHHXXs7 This message will self-destruct in 10 seconds"
    sleep 10
    ping.delete
  end


# Exit command
  command :exit do |event|
    # Breaks unless event user is Owner (or Dev for testing, this should be removed in the live version)
    break unless event.user.id == OWNER_ID || event.user.id == COBALT_DEV_ID
    event.respond 'Shutting down.'
    exit
  end
end