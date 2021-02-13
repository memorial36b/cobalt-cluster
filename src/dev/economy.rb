# Crystal: Economy
require 'rufus-scheduler'
require 'date'
ENV['TZ'] = 'GMT'

# This crystal contains Cobalt's economy features (i.e. any features related to Starbucks)
module Bot::Economy
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants
  include Convenience
  
  # Permanent user balances, one entry per user, negative => fines
  # { user_id, amount }
  USER_PERMA_BALANCES = DB[:econ_user_perma_balances]
  
  # User balances table, these balances expire on a rolling basis
  # { transaction_id, user_id, timestamp, amount }
  USER_BALANCES = DB[:econ_user_balances]

  # User last checkin time, used to prevent checkin in more than once a day.
  # { user_id, checkin_timestamp }
  USER_CHECKIN_TIME = DB[:econ_user_checkin_time]

  # User timezones dataset
  # { user_id, timezone }
  USER_TIME_ZONE = DB[:econ_user_time_zones]

  # Path to crystal's data folder
  ECON_DATA_PATH = "#{Bot::DATA_PATH}/economy".freeze
  
  # Scheduler constant
  SCHEDULER = Rufus::Scheduler.new

  ##########################
  ##   HELPER FUNCTIONS   ##
  ##########################
  # Get the last Monday since this date.
  # If it is Monday, this returns the input.
  def self.GetLastMonday(date)
    # use the work week instead of the biblical week
    wwday = date.cwday - 1
    return date - wwday
  end

  # Get the last timestamp that temporary transactions would
  # be valid on. Anything older should be purched.
  def self.GetLastValidTimestamp()
    past_monday = GetLastMonday(Date.today)
    return ( past_monday - 28 ).to_time.to_i
  end

  # Check for and remove any and all expired points.
  def self.CleanupDatabase(user_id)
    # todo: remove all expired balances
  end

  # Gets the user's current balance. Assumes database is clean.
  def self.GetBalance(user_id)
    sql = 
      "SELECT user_id, SUM(amount) total\n" +
      "FROM\n" + 
      "(\n" +
      "  SELECT user_id, amount FROM econ_user_balances\n" +
      "  WHERE user_id = #{user_id}\n" +
      "  UNION ALL\n" +
      "  SELECT user_id, amount FROM econ_user_perma_balances\n" +
      "  WHERE user_id = #{user_id}\n" +
      ") s\n" +
      "GROUP BY user_id;"

    balance = DB[sql]
    if(balance == nil || balance.first == nil)
      balance = 0
    else
      balance = balance.first[:total]
    end

    return balance
  end

  # Gets the user's permanent balance.
  def self.GetPermaBalance(user_id)
    balance = USER_PERMA_BALANCES.where(user_id: user_id).sum(:amount)
    if(balance == nil)
      balance = 0
    end
    return balance
  end
  
  # Deposit money to perma if fines exist then to temp balances, cannot be negative!
  def self.Deposit(user_id, amount)
    if amount < 0
      return false
    end

    # pay off fines first if user has any
    perma_balance = USER_PERMA_BALANCES.where(user_id: user_id)
    if perma_balance.first != nil && perma_balance.first[:amount] < 0
      new_fine_balance = [0, perma_balance.first[:amount] + amount].min
      amount = [0, amount + perma_balance.first[:amount]].max

      perma_balance.update(amount: new_fine_balance)
    end

    # deposit remainder
    if amount > 0
      timestamp = Time.now.to_i
      USER_BALANCES << { user_id: user_id, timestamp: timestamp, amount: amount }
    end

    return true
  end

  # Deposit money to perma, can also be used for fines (negative)!
  def self.DepositPerma(user_id, amount)
    if USER_PERMA_BALANCES[user_id: user_id]
      perma_balance = USER_PERMA_BALANCES.where(user_id: user_id)
      perma_balance.update(amount: perma_balance.first[:amount] + amount)
    else
      USER_PERMA_BALANCES <<{ user_id: user_id, amount: amount }
    end

    return true
  end

  # Attempt to withdraw the specified amount, return success. Assumes database is clean.
  def self.Withdraw(user_id, amount)
    if GetBalance(user_id) < amount || amount < 0
      return false
    end

    # iterate through balances and remove until amount is withdrawn
    user_transactions = USER_BALANCES.where{Sequel.&({user_id: user_id}, (amount > 0))}.order(Sequel.asc(:timestamp))
    while amount > 0 and user_transactions.count > 0 do
      transaction = user_transactions.first
      transaction_id = transaction[:transaction_id]
      old_amount = transaction[:amount]
      if old_amount > amount
        old_amount -= amount
        user_transactions.where(transaction_id: transaction_id).update(amount: old_amount)
        amount = 0
      else
        amount -= old_amount
        user_transactions.where(transaction_id: transaction_id).delete
      end
    end

    # remove remaining balance from permanent balances
    if amount > 0
      user_entry = USER_PERMA_BALANCES.where(user_id: user_id)
      user_entry.update(amount: user_entry.first[:amount] - amount)
    end

    return true
  end

  ###########################
  ##   STANDARD COMMANDS   ##
  ###########################

  # get daily amount
  command :checkin do |event|
    # if user already checked in today, ignore
    # TODO: utlize user's local time zone for today/yesterday comparison
    last_timestamp = USER_CHECKIN_TIME[user_id: event.user.id]
    if last_timestamp != nil
      last_timestamp = last_timestamp[:checkin_timestamp]
      last_date = Time.at(last_timestamp).to_datetime()
      today_date = Date.today()
      if last_date > today_date
        event.respond "Sorry! You already checked in today!"
        break
      end
    end

    role_yaml_id = nil
    case Convenience::GetHighestLevelRoleId(event.user)
    when BEARER_OF_THE_WAND_POG_ROLE_ID
      role_yaml_id = "checkin_bearer"
    when MEWMAN_MONARCH_ROLE_ID
      role_yaml_id = "checkin_monarch"
    when MEWMAN_NOBLE_ROLE_ID
      role_yaml_id = "checkin_noble"
    when MEWMAN_KNIGHT_ROLE_ID
      role_yaml_id = "checkin_knight"
    when MEWMAN_SQUIRE_ROLE_ID
      role_yaml_id  = "checkin_squire"
    when MEWMAN_CITIZEN_ROLE_ID
      role_yaml_id = "checkin_citizen"
    when VERIFIED_ROLE_ID
      role_yaml_id = "checkin_verified"
    when INVALID_ROLE_ID
      role_yaml_id = "checkin_new"    
    end

    if role_yaml_id == nil
      raise RuntimeError, "Unexpected role ID received, there may be a new role that needs to be accounted for by checkin!"
      break
    end

    points_yaml = YAML.load_data!("#{ECON_DATA_PATH}/point_values.yml")
    checkin_value = points_yaml[role_yaml_id]
    Deposit(event.user.id, checkin_value)
    if last_timestamp == nil
      USER_CHECKIN_TIME << { user_id: event.user.id, checkin_timestamp: Time.now.to_i }
    else
      last_timestamp = USER_CHECKIN_TIME.where(user_id: event.user.id)
      last_timestamp.update(checkin_timestamp: Time.now.to_i)
    end
    event.respond "You checked in and got #{checkin_value} Starbucks!"
  end

  # display balances
  PROFILE_COMMAND_NAME = "profile"
  PROFILE_DESCRIPTION = "See your economic stats."
  PROFILE_ARGS = [["user", DiscordUser]]
  PROFILE_REQ_COUNT = 0
  command :profile do |event, *args|
    # parse args
    opt_defaults = [event.user.id]
    parsed_args = Convenience::ParseArgsAndRespondIfInvalid(
      event,
      PROFILE_COMMAND_NAME,
      PROFILE_DESCRIPTION,
      PROFILE_ARGS,
      PROFILE_REQ_COUNT,
      opt_defaults,
      args)
    break unless not parsed_args.nil? 

    user_id = parsed_args["user"].id
    user_mention = parsed_args["user"].mention
    CleanupDatabase(user_id)
    perma_balance = GetPermaBalance(user_id)
    balance = GetBalance(user_id)

    # build response
    response = "#{user_mention}" +
      "\nYour total balance is #{balance} Starbucks" +
      "\nYou have #{perma_balance} non-expiring Starbucks"

    user_transactions = USER_BALANCES.where{Sequel.&({user_id: user_id}, (amount > 0))}.order(Sequel.asc(:timestamp)).all
    (0...user_transactions.count).each do |n|
      transaction = user_transactions[n]

      amount = transaction[:amount]
      timestamp = transaction[:timestamp]
      response += "\n#{amount} received on #{Time.at(timestamp).to_datetime}"
    end

    event.respond response
  end

  # display leaderboard
  command :richest do |event|
    # note: need to filter by valid range, this will likely need to 
    # be a rough estimate, since it may not be possible to factor in
    # every user's individual time zones
    last_valid_timestamp = GetLastValidTimestamp()
    sql =
      "SELECT user_id, SUM(amount) networth\n" +
      "FROM\n" + 
      "(\n" +
      "  SELECT user_id, amount FROM econ_user_balances\n" +
      "  WHERE timestamp >= #{last_valid_timestamp}\n" +
      "  UNION ALL\n" +
      "  SELECT user_id, amount FROM econ_user_perma_balances\n" +
      ") s\n" +
      "GROUP BY user_id\n" +
      "ORDER BY networth DESC;"

    richest = DB[sql]
    if richest == nil || richest.first == nil
      event.respond "No one appears to have money! Please give the devs a ring!!"
      break
    end

    # TODO: Create a nicer looking embed!
    all_user_stats = richest.all
    response = "============== Richest ==============\n"
    count = [5, all_user_stats.count].min
    (0...count).each do |n|
      user_stats = all_user_stats[n] 
      user_id = user_stats[:user_id]
      user = DiscordUser.new(user_id)

      networth = user_stats[:networth]
      response += "#{user.user.username}\t\t\t\t\t\t\t\t#{networth} Starbucks\n"
    end

    event.respond response
  end

  # transfer money to another account
  TRANSFERMONEY_COMMAND_NAME = "transfermoney"
  TRANSFERMONEY_DESCRIPTION = "Transfer funds to the specified user."
  TRANSFERMONEY_ARGS = [["to_user", DiscordUser], ["amount", Integer]]
  TRANSFERMONEY_REQ_COUNT = 2
  command :transfermoney do |event, *args|
    opt_defaults = []
    parsed_args = Convenience::ParseArgsAndRespondIfInvalid(
      event,
      TRANSFERMONEY_COMMAND_NAME,
      TRANSFERMONEY_DESCRIPTION,
      TRANSFERMONEY_ARGS,
      TRANSFERMONEY_REQ_COUNT,
      opt_defaults,
      args)
    break unless not parsed_args.nil?  

    CleanupDatabase(event.user.id)

    from_user_id = event.user.id
    to_user_id = parsed_args["to_user"].id
    amount = parsed_args["amount"]
    if amount <= 0
      event.respond "You can't transfer negative funds!"
      break
    end

    if Withdraw(from_user_id, amount)
      Deposit(to_user_id, amount)
      event.respond "#{parsed_args["to_user"].mention}, #{event.user.username} has transfered #{amount} Starbucks to your account!"
    else
      event.respond "You have insufficient funds to transfer that much!"
    end
  end

  # rent a new role
  command :rentarole do |event, *args|
    CleanupDatabase(event.user.id)

  	puts "rentarole
 " 	#initial
  	#maintain
  	#override
  end

  # remove rented role
  command :unrentarole do |event, *args|
  	CleanupDatabase(event.user.id)
    
    puts "unrentarole"
  end

  # custom tag management
  command :tag do |event, *args|
  	CleanupDatabase(event.user.id)
    
    puts "tag"
  	#add
  	#delete
  	#edit
  end

  # custom command mangement
  command :myconn do |event, *args|
  	CleanupDatabase(event.user.id)
    
    puts "myconn"
  	#set
  	#delete
  	#edit
  end

  ############################
  ##   MODERATOR COMMANDS   ##
  ############################
  FINE_COMMAND_NAME = "fine"
  FINE_DESCRIPTION = "Fine a user for inappropriate behavior."
  FINE_ARGS = [["user", DiscordUser], ["fine_size", String]]
  FINE_REQ_COUNT = 2
  command :fine do |event, *args|
    break unless (Convenience.IsUserDev(event.user.id) ||
                  event.user.role?(MODERATOR_ROLE_ID) ||
                  event.user.role?(HEAD_CREATOR_ROLE_ID))

    opt_defaults = []
    parsed_args = Convenience::ParseArgsAndRespondIfInvalid(
      event,
      FINE_COMMAND_NAME,
      FINE_DESCRIPTION,
      FINE_ARGS,
      FINE_REQ_COUNT,
      opt_defaults,
      args)
    break unless not parsed_args.nil?  

    points_yaml = YAML.load_data!("#{ECON_DATA_PATH}/point_values.yml")
    user_id = parsed_args["user"].id
    user_mention = parsed_args["user"].mention
    severity = parsed_args["fine_size"]

    entry_id = "fine_#{severity}"
    fine_size = points_yaml[entry_id]
    orig_fine_size = fine_size
    if fine_size == nil
      event.respond "Invalid fine size specified (small, medium, large)."
      break
    end

    # deduct fine from bank account balance
    balance = GetBalance(user_id)
    withdraw_amount = [fine_size, balance].min
    if withdraw_amount > 0
      Withdraw(user_id, withdraw_amount)
      fine_size -= withdraw_amount
    end

    # deposit rest as negative perma currency
    DepositPerma(user_id, -fine_size)

    mod_mention = DiscordUser.new(event.user.id).mention
    event.respond "#{user_mention} has been fined #{orig_fine_size} by #{mod_mention}"
  end

  ############################
  ##   DEVELOPER COMMANDS   ##
  ############################

  # Takes user's entire (positive) balance, displays gif, devs only
  SHUTUPANDTAKEMYMONEY_COMMAND_NAME = "shutupandtakemymoney"
  SHUTUPANDTAKEMYMONEY_DESCRIPTION = "Clear out your or another user's balance."
  SHUTUPANDTAKEMYMONEY_ARGS = [["user", DiscordUser]]
  SHUTUPANDTAKEMYMONEY_REQ_COUNT = 0
  command :shutupandtakemymoney do |event, *args|
    break unless Convenience::IsUserDev(event.user.id)

    opt_defaults = [event.user.id]
    parsed_args = Convenience::ParseArgsAndRespondIfInvalid(
      event,
      SHUTUPANDTAKEMYMONEY_COMMAND_NAME,
      SHUTUPANDTAKEMYMONEY_DESCRIPTION,
      SHUTUPANDTAKEMYMONEY_ARGS,
      SHUTUPANDTAKEMYMONEY_REQ_COUNT,
      opt_defaults,
      args)
    break unless not parsed_args.nil?  

    # no need to clean because we're going to clear all of their balance
    user_id = parsed_args["user"].id
    user_mention = parsed_args["user"].mention
    if GetBalance(user_id) <= 0
      event.respond "Sorry, you're already broke!"
      next # bail out, this fool broke
    end

  	# completely clear your balances
    USER_BALANCES.where{Sequel.&({user_id: user_id}, (amount > 0))}.delete
  	event.respond "#{user_mention} has lost all funds!\nhttps://media1.tenor.com/images/25489503d3a63aa7afbc0217eba128d3/tenor.gif?itemid=8581127"
  end

  # Clear all fines and balances.
  CLEARBALANCES_COMMAND_NAME = "clearbalances"
  CLEARBALANCES_DESCRIPTION = "Clear out your or another user's balance and fines."
  CLEARBALANCES_ARGS = [["user", DiscordUser]]
  CLEARBALANCES_REQ_COUNT = 0
  command :clearbalances do |event, *args|
    break unless Convenience::IsUserDev(event.user.id)

    opt_defaults = [event.user.id]
    parsed_args = Convenience::ParseArgsAndRespondIfInvalid(
      event,
      CLEARBALANCES_COMMAND_NAME,
      CLEARBALANCES_DESCRIPTION,
      CLEARBALANCES_ARGS,
      CLEARBALANCES_REQ_COUNT,
      opt_defaults,
      args)
    break unless not parsed_args.nil?  

    # no need to clean because we're going to clear all of their balance
    user_id = parsed_args["user"].id
    user_mention = parsed_args["user"].mention

    # completely clear your balances
    USER_BALANCES.where(user_id: user_id).delete
    USER_PERMA_BALANCES.where(user_id: user_id).delete
    event.respond "#{user_mention} has had all fines and balances cleared"
  end

  # gives a specified amount of starbucks, devs only
  GIMME_COMMAND_NAME = "gimme"
  GIMME_DESCRIPTION = "Give Starbucks to self or specified user."
  GIMME_ARGS = [["amount", Integer], ["type", String], ["user", DiscordUser]]
  GIMME_REQ_COUNT = 1
  command :gimme do |event, *args|
    break unless Convenience::IsUserDev(event.user.id)

    opt_defaults = ["temp", event.user.id]
    parsed_args = Convenience::ParseArgsAndRespondIfInvalid(
      event,
      GIMME_COMMAND_NAME,
      GIMME_DESCRIPTION,
      GIMME_ARGS,
      GIMME_REQ_COUNT,
      opt_defaults,
      args)
    break unless not parsed_args.nil?  

    type = parsed_args["type"]
    amount = parsed_args["amount"]
    user_id = parsed_args["user"].id
    user_mention = parsed_args["user"].mention
    CleanupDatabase(user_id)

    if type.downcase == "perma"
      DepositPerma(user_id, amount)
    else
      Deposit(user_id, amount)
    end

    event.respond "#{user_mention} received #{amount} Starbucks"
  end

  # takes a specified amount of starbucks, devs only
  TAKEIT_COMMAND_NAME = "takeit"
  TAKEIT_DESCRIPTION = "Take Starbucks from self or specified user."
  TAKEIT_ARGS = [["amount", Integer], ["user", DiscordUser]]
  TAKEIT_REQ_COUNT = 1
  command :takeit do |event, *args|
    break unless Convenience::IsUserDev(event.user.id)

    opt_defaults = [event.user.id]
    parsed_args = Convenience::ParseArgsAndRespondIfInvalid(
      event,
      TAKEIT_COMMAND_NAME,
      TAKEIT_DESCRIPTION,
      TAKEIT_ARGS,
      TAKEIT_REQ_COUNT,
      opt_defaults,
      args)
    break unless not parsed_args.nil?  

    # attempt to withdraw
    amount = parsed_args["amount"]
    user_id = parsed_args["user"].id
    user_mention = parsed_args["user"].mention
    CleanupDatabase(user_id)
    if Withdraw(user_id, amount)
      event.respond "#{user_mention} lost #{amount} Starbucks"
    else
      event.respond "#{user_mention} does not have at least #{amount} Starbucks"
    end
  end

  # econ dummy command, does nothing lazy cleanup devs only
  command :econdummy do |event|
    break unless Convenience::IsUserDev(event.user.id)

    CleanupDatabase(user_id)    
  	puts "econdummy"
  end
end