# Crystal: Economy
require 'rufus-scheduler'
ENV['TZ'] = 'GMT'

# This crystal contains Cobalt's economy features (i.e. any features related to Starbucks)
module Bot::Economy
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants
  
  # Permanent user balances, one entry per user, negative => fines
  # { user_id, amount }
  USER_PERMA_BALANCES = DB[:econ_user_perma_balances]
  
  # User balances table, these balances expire on a rolling basis
  # { transaction_id, user_id, timestamp, amount }
  USER_BALANCES = DB[:econ_user_balances]

  # User timezones dataset
  # { user_id, timezone }
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
  ##########################
  ##   HELPER FUNCTIONS   ##
  ##########################
  def self.IsDev(user_id)
    return user_id == OWNER_ID || COBALT_DEV_ID.include?(user_id)
  end

  # Check for and remove any and all expired points.
  def self.CleanupDatabase(user_id)
    # todo: remove all expired balances
  end

  # Gets the user's current balance. Assumes database is clean.
  def self.GetBalance(user_id)
    # todo: outer join of USER_BALANCES and USER_PERMA_BALANCES
    # 
    # e.g.
    #SELECT Orders.OrderID, Customers.CustomerName, Orders.OrderDate
    #FROM Orders
    #OUTER JOIN Customers ON Orders.CustomerID=Customers.CustomerID;

    balance = USER_BALANCES.where(user_id: user_id).sum(:amount)
    if balance == nil 
      balance = 0
    end
    return balance
  end
  
  def self.Deposit(user_id, amount)
    if amount < 0
      return false
    end

    timestamp = Time.now.to_i
    USER_BALANCES << { user_id: user_id, timestamp: timestamp, amount: amount }
    return true
  end

  # Attempt to withdraw the specified amount, return success. Assumes database is clean.
  def self.Withdraw(user_id, amount)
    if GetBalance(user_id) < amount || amount < 0
      return false
    end

    # get all transactions ordered by time for user that are net positive
    user_transactions = USER_BALANCES.where{Sequel.&({user_id: user_id}, (amount > 0))}.order(Sequel.asc(:timestamp))
    delete_count = 0
    while amount > 0 do
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

    return true
  end

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
  command :profile do |event, arg =''|
    # parse user id
    user_id = nil
    if arg == ''
    	user_id = event.user.id
    else
      begin
        user_id = Integer(arg)
      rescue
        event.respond "Sorry I didn't get that."
        next # bail out, couldn't parse int
      end
    end

    CleanupDatabase(user_id)
    balance = GetBalance(user_id)
    response ="Your balance is #{balance} Starbucks"

    user_transactions = USER_BALANCES.where{Sequel.&({user_id: user_id}, (amount > 0))}.order(Sequel.asc(:timestamp))
    (0..(user_transactions.count - 1)).each do |n|
      transaction = user_transactions.offset(n)

      amount = transaction.get(:amount)
      timestamp = transaction.get(:timestamp)
      response += "\n#{amount} received on #{timestamp}"
    end

    event.respond response
  end

  # display leaderboard
  command :richest do |event|
    # note: need to filter by valid range, this will likely need to 
    # be a rough estimate, since it may not be possible to factor in
    # every user's individual time zones

    # note 2: need to join perma and regular
    # 
    # e.g.
    #SELECT Orders.OrderID, Customers.CustomerName, Orders.OrderDate
    #FROM Orders
    #OUTER JOIN Customers ON Orders.CustomerID=Customers.CustomerID;

    # note 3: we'll do a rough estimate on this exluding timezones
    #
    # EXAMPLE
    # SELECT AccountNumber, 
    #    Bill, 
    #    BillDate, 
    #    SUM(Bill) over (partition by accountNumber) as account_total
    # FROM Table1
    # order by AccountNumber, BillDate;
    
  	puts "richest"
  end

  # transfer money to another account
  command :transfermoney do |event|
    from_user_id = event.user.id
    CleanupDatabase(from_user_id)

  	puts "transfermoney"
  end

  # rent a new role
  command :rentarole do |event|
    CleanupDatabase(event.user.id)

  	puts "rentarole
 " 	#initial
  	#maintain
  	#override
  end

  # remove rented role
  command :unrentarole do |event|
  	CleanupDatabase(event.user.id)
    
    puts "unrentarole"
  end

  # custom tag management
  command :tag do |event|
  	CleanupDatabase(event.user.id)
    
    puts "tag"
  	#add
  	#delete
  	#edit
  end

  # custom command mangement
  command :myconn do |event|
  	CleanupDatabase(event.user.id)
    
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
    break unless IsDev(event.user.id)

    # no need to clean because we're going to clear all of their balance
    if GetBalance(event.user.id) <= 0
      event.respond "Sorry, you're already broke!"
      next # bail out, this fool broke
    end

  	# completely clear your balances
    USER_BALANCES.where(user_id: event.user.id).delete
  	event.respond "https://media1.tenor.com/images/25489503d3a63aa7afbc0217eba128d3/tenor.gif?itemid=8581127"
    puts "shutupandtakemymoney"
  end

  # gives a specified amount of starbucks, devs only
  command :gimme do |event, arg =''|
    break unless IsDev(event.user.id)

  	amount = 0
    begin
      amount = Integer(arg)
    rescue
      event.respond "Sorry I didn't get that."
      break # bail out, couldn't parse int
    end

    if amount < 0
      event.respond "Sorry I can't give negative Starbucks."
      break # bail out, invalid amount
    end 

    user_id = event.user.id
    CleanupDatabase(user_id)

    Deposit(user_id, amount)
    event.respond "#{amount} Starbucks received"
    puts "gimme #{user_id}: #{amount} Starbucks" 
  end

  # takes a specified amount of starbucks, devs only
  command :takeit do |event, arg =''|
    break unless IsDev(event.user.id)

    # parse amount input
    amount = 0
    begin
      amount = Integer(arg)
    rescue
      event.respond "Sorry I didn't get that."
      break # bail out, couldn't parse int
    end

    if amount < 0
      event.respond "Sorry I can't take negative Starbucks."
      break # bail out, invalid amount
    end 

    # attempt to withdraw
    user_id = event.user.id
    CleanupDatabase(user_id)
    if Withdraw(user_id, amount)
      event.respond "#{amount} Starbucks removed"
      puts "takeit #{user_id}): #{amount} Starbucks" 
    else
      event.respond "You do not have at least #{amount} Starbucks"
    end
  end

  # econ dummy command, does nothing lazy cleanup devs only
  command :econdummy do |event|
    break unless IsDev(event.user.id)

    CleanupDatabase(user_id)    
  	puts "econdummy"
  end
end