# Crystal: Economy
require 'rufus-scheduler'
ENV['TZ'] = 'GMT'

# This crystal contains Cobalt's economy features (i.e. any features related to Starbucks)
module Bot::Economy
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants
  
  # Path to crystal's data folder
  ECON_DATA_PATH = "#{Bot::DATA_PATH}/economy".freeze
  # Scheduler constant
  SCHEDULER = Rufus::Scheduler.new

  # Profile Command (this currently doesn't do anything)

  command(:profile, channels: [BOT_COMMANDS_CHANNEL_ID, MODERATION_CHANNEL_CHANNEL_ID]) do |event, *args|
    # Sets argument default to event user's mention
    args[0] ||= event.user.mention

    # Breaks unless given user is valid; defines user variable otherwise
    break unless (user = SERVER.get_user(args.join(' ')))
  end
end