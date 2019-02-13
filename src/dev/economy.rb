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
  # Mewman Citizen role ID
  CITIZEN_ID = 320438721923252225
  # Mewman Noble role ID
  NOBLE_ID = 347071589768101908
  # Mewman Monarch role ID
  MONARCH_ID =  321206686872502274
  # Mewman Alpha role ID
  ALPHA_ID = 440177242589495296
  # 100! role ID
  HUNDRED_ID = 318519367971241984
  # Ghastly Green role ID
  GREEN_ID = 308634210564964353
  # Obsolete Orange role ID
  ORANGE_ID = 434036486808272916
  # Breathtaking Blue role ID
  BLUE_ID = 434036732162211861
  # Lullaby Lavender role ID
  LAVENDER_ID = 434037025663090688
  # Retro Red role ID
  RED_ID = 434040026192543764
  # Whitey White role ID
  WHITE_ID = 436566003896418307
  # Shallow Yellow role ID
  YELLOW_ID = 440174617697583105
  # Marvelous Magenta role ID
  MAGENTA_ID = 440182036800471041
  # Citizen override role ID
  CITIZEN_OVERRIDE_ID = 460505017120587796
  # Noble override role ID
  NOBLE_OVERRIDE_ID = 460505130203217921
  # Monarch override role ID
  MONARCH_OVERRIDE_ID = 460505230128185365
  # Alpha role override ID
  ALPHA_OVERRIDE_ID = 481049629773922304
  # #bot_commands ID
  BOT_COMMANDS_ID = 307726225458331649
  # #moderation_channel ID
  MODERATION_CHANNEL_ID = 330586271116165120

  #

  command(:profile, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event, *args|
    # Sets argument default to event user's mention
    args[0] ||= event.user.mention

    # Breaks unless given user is valid; defines user variable otherwise
    break unless (user = SERVER.get_user(args.join(' ')))
  end
end