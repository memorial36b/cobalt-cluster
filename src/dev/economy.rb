# Crystal: Economy
require 'rufus-scheduler'
ENV['TZ'] = 'GMT'

# This crystal contains Cobalt's economy features (i.e. any features related to Starbucks)
module Bot::Economy
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants
  
  # User balances dataset
  # { user_id, transaction_utc_timestamp, transation }
  USER_BALANCES = DB[:econ_user_balances]

  # User timezones dataset
  # { user_id, user_timezone }
  USER_TIME_ZONE = DB[:econ_user_time_zones]

  # Path to crystal's data folder
  ECON_DATA_PATH = "#{Bot::DATA_PATH}/economy".freeze
  
  ## Scheduler constant
  #SCHEDULER = Rufus::Scheduler.new

  # Profile Command (this currently doesn't do anything)

  #command(:profile, channels: [BOT_COMMANDS_CHANNEL_ID, MODERATION_CHANNEL_CHANNEL_ID]) do |event, *args|
  #  # Sets argument default to event user's mention
  #  args[0] ||= event.user.mention
  #
  #  # Breaks unless given user is valid; defines user variable otherwise
  #  break unless (user = SERVER.get_user(args.join(' ')))
  #end

  ###########################
  ##   STANDARD COMMANDS   ##
  ###########################

  # get daily amount
  command :checkin do |event|
  	puts "checkin"
  	#member
  	#citizen
  	#noble
  	#monarch
  	#alpha
  end

  # display balances
  command :profile do |event|
  	puts "profile"
  end

  # display leaderboard
  command :richest do |event|
  	puts "richest"
  end

  # transfer money to another account
  command :transfermoney do |event|
  	puts "transfermoney"
  end

  # rent a new role
  command :rentarole do |event|
  	puts "rentarole"
  	#initial
  	#maintain
  	#override
  end

  # remove rented role
  command :unrentarole do |event|
  	puts "unrentarole"
  end

  # custom tag management
  command :tag do |event|
  	puts "tag"
  	#add
  	#delete
  	#edit
  end

  # custom command mangement
  command :myconn do |event|
  	puts "myconn"
  	#set
  	#delete
  	#edit
  end

  ############################
  ##   MODERATOR COMMANDS   ##
  ############################
  command :fine do |event|
  	puts "fine"
  	#basic
  	#moderate
  	#extreme
  end

  ############################
  ##   DEVELOPER COMMANDS   ##
  ############################

  # takes user's entire balance, displays gif, devs only
  command :shutupandtakemymoney do |event|
  	puts "shutupandtakemymoney"
  end

  # gives a specified amount of starbucks, devs only
  command :gimme do |event|
  	puts "gimme"
  end

  # takes a specified amount of starbucks, devs only
  command :takeit do |event|
  	puts "takeit"
  end

  # econ dummy command, does nothing lazy cleanup devs only
  command :econdummy do |event|
  	puts "econdummy"
  end
end