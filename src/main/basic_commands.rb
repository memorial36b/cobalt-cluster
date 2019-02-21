# Crystal: BasicCommands


# This crystal contains the basic commands of the bot, such as ping and exit.
module Bot::BasicCommands
  extend Discordrb::Commands::CommandContainer
  include Constants
  
  # Ping command
  command :ping do |event|
    ping = event.respond '**P** **O** **N** **G**'
    ping.edit "**P** **O** **N** **G** **|** **#{((Time.now - event.timestamp) * 1000).round}ms**"
    sleep 10
    ping.delete
  end


# Exit command
  command :exit do |event|
    # Breaks unless event user is me (ethane/salmon/410/ink/whatever you call me)
    break unless event.user.id == MY_ID
    event.respond 'Shutting down.'
    exit
  end
end