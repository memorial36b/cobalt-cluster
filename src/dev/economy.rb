# Crystal: Economy
require 'rufus-scheduler'
require 'date'

# This crystal contains Cobalt's economy features (i.e. any features related to Starbucks)
module Bot::Economy
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  extend Convenience
  include Constants
  include DMAction
  
  # Scheduler constant
  SCHEDULER = Rufus::Scheduler.new

  # User last checkin time, used to prevent checkin in more than once a day
  # { user_id, checkin_timestamp }
  USER_CHECKIN_TIME = DB[:econ_user_checkin_time]

  # Each entry represents one raffle ticket for the given user.
  # { user_id }
  RAFFLE_ENTRIES = DB[:econ_raffle]

  # Path to economy data folder
  ECON_DATA_PATH = "#{Bot::DATA_PATH}/economy".freeze

  # How often the raffle occurs.
  # This is a constant because it needs to be consumed by rufus scheduler...
  RAFFLE_FREQUENCY = YAML.load_data!("#{ECON_DATA_PATH}/limits.yml")['raffle_frequency'] 

  # Limits the number of tags used per second
  TAG_BUCKET = Bot::BOT.bucket(
      :tag_spam_filter,
      limit:     1, # count per
      time_span: 2  # seconds
  )

  ##########################
  ##   HELPER FUNCTIONS   ##
  ##########################
  # Are we allowed to call an economy command in this channel?
  def self.call_command?(channel_id)
     return channel_id == BOT_COMMANDS_CHANNEL_ID || channel_id == TEST_TEST_CHANNEL_ID
  end

  # Determine how many Starbucks the user gets for checking in.
  def self.get_user_checkin_value(user_id)
    user = DiscordUser.new(user_id)
    role_yaml_id = nil
    case Convenience::GetHighestLevelRoleId(user)
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
    end

    return Bot::Bank::appraise_item(role_yaml_id)
  end

  # Determine how long the user has to wait until their next checkin.
  # Zero if they can checkin now
  def self.get_time_until_next_checkin(user_id)
    last_checkin = USER_CHECKIN_TIME[user_id: user_id]
    return 0 if last_checkin == nil || last_checkin.first == nil

    last_checkin = last_checkin[:checkin_timestamp]
    last_checkin = Bot::Timezone::timestamp_to_user(user_id, last_checkin)
    today = Bot::Timezone::user_today(user_id)
    return 0 if last_checkin < today

    now = Bot::Timezone::user_now(user_id)
    tomorrow = today + 1
    return tomorrow.to_time.to_i - now.to_time.to_i
  end

  # Determine how long the user has to wait until their next checkin.
  def self.get_time_until_next_checkin_string(user_id)
    seconds = get_time_until_next_checkin(user_id)
    
    return "now" if seconds <= 0

    msg = ""
    if seconds > 60*60
      hours = seconds / (60*60)
      msg = "#{hours}h, " 
      seconds -= (hours*60*60)
    end

    if seconds > 60
      minutes = seconds / 60
      msg += "#{minutes}m, "
      seconds -= (minutes*60)
    end
    
    if seconds > 0  
      msg += "#{seconds}s, "
    end

    return msg[0..-3] # remove trailing ", "
  end

  # Get the role id for the given role item id.
  def self.get_role_for_item_id(role_item_id)
    case role_item_id
    when Bot::Inventory::get_item_id('role_color_ghastly_green')
      role_id = GHASTLY_GREEN_ROLE_ID
    when Bot::Inventory::get_item_id('role_color_obsolete_orange')
      role_id = OBSOLETE_ORANGE_ROLE_ID
    when Bot::Inventory::get_item_id('role_color_breathtaking_blue')
      role_id = BREATHTAKING_BLUE_ROLE_ID
    when Bot::Inventory::get_item_id('role_color_retro_red')
      role_id = RETRO_RED_ROLE_ID
    when Bot::Inventory::get_item_id('role_color_lullaby_lavender')
      role_id = LULLABY_LAVENDER_ROLE_ID
    when Bot::Inventory::get_item_id('role_color_whitey_white')
      role_id = WHITEY_WHITE_ROLE_ID
    when Bot::Inventory::get_item_id('role_color_marvelous_magenta')
      role_id = MARVELOUS_MAGENTA_ROLE_ID
    when Bot::Inventory::get_item_id('role_color_shallow_yellow')
      role_id = SHALLOW_YELLOW_ROLE_ID
    when Bot::Inventory::get_item_id('role_override_citizen')
      role_id = OVERRIDE_MEWMAN_CITIZEN_ROLE_ID
    when Bot::Inventory::get_item_id('role_override_squire')
      role_id = OVERRIDE_MEWMAN_SQUIRE_ROLE_ID
    when Bot::Inventory::get_item_id('role_override_knight')
      role_id = OVERRIDE_MEWMAN_KNIGHT_ROLE_ID
    when Bot::Inventory::get_item_id('role_override_noble')
      role_id = OVERRIDE_MEWMAN_NOBLE_ROLE_ID
    when Bot::Inventory::get_item_id('role_override_monarch')
      role_id = OVERRIDE_MEWMAN_MONARCH_ROLE_ID
    when Bot::Inventory::get_item_id('role_override_bearer')
      role_id = OVERRIDE_BEARER_OF_THE_WAND_POG_ROLE_ID
    else
      raise ArgumentError, "Invalid role received from inventory!"
      return nil
    end

    return role_id
  end

  # Get the user's rented role or nil if they don't have one.
  def self.get_user_rented_role_item(user_id)
    override_role_type = Bot::Inventory::catalog_value('item_type_role_override')
    color_role_type = Bot::Inventory::catalog_value('item_type_role_color')
    roles = Bot::Inventory::get_inventory(user_id, override_role_type)
    roles.push(*Bot::Inventory::get_inventory(user_id, color_role_type))
    return roles.empty? ? nil : roles[0]
  end

  ################################
  ##   RUFUS SCHEDULED EVENTS   ##
  ################################
  SCHEDULER.every '6h' do
    # check for expired balances
    users = Bot::Bank::get_users_with_temp_balance()
    users.each do |user_id|
      Bot::Bank::clean_account(user_id)
    end

    # check for expired roles for each user
    users = Bot::Inventory::get_users_with_inventory()
    users.each do |user_id|
      inventory = Bot::Inventory::get_inventory(user_id)
      next if inventory == nil || inventory.count <= 0 # sanity check, shouldn't be possible

      owner = DiscordUser.new(user_id)
      removed_items = []
      name_override = {} # display a custom item name
      inventory.each do |item|
        # skip if the item doesn't or hasn't expired
        next unless item.expiration != nil && Time.now.to_i >= item.expiration

        # sanity check: owner id matches queried user id
        if user_id != item.owner_user_id
          puts "Item #{item.entry_id} was found during query that stated it was owned by #{user_id} but the item itself had owner #{item.owner_user_id}! This is impossible!"
          next # continue onto valid items
        end

        # determine how much it'll cost to renew
        renewal_cost = Bot::Inventory::get_item_renewal_cost_from_id(item.item_id)
        if renewal_cost == nil
          puts "Item '#{item.ui_name}' (#{item.item_id}) has an expiration but not a renewal cost! This should be impossible!"
          next # continue onto valid items
        end

        # renew if possible, otherwise remove and add to list of removed
        if Bot::Bank::withdraw(owner.id, renewal_cost)
          Bot::Inventory::renew_item(item.entry_id)
        else
          # remove from inventory
          Bot::Inventory::remove_item(item.entry_id)
          removed_items.push(item)

          # perform necessary cleanup now that they don't own it
          case item.item_type
          
          #############################
          ## Roles
          when Bot::Inventory::catalog_value('item_type_role_override'),
               Bot::Inventory::catalog_value('item_type_role_color')
            # remove role if they have it
            role_id = get_role_for_item_id(item.item_id)
            owner.user.remove_role(role_id, "#{owner.mention} could not afford to renew role '#{item.ui_name}'!") if owner.user.role?(role_id)
          
          #############################
          ## Tags
          when Bot::Inventory::catalog_value('item_type_tag')
            tag = Bot::Tags::get_tag_by_item_entry_id(item.entry_id)
            Bot::Tags::remove_tag_by_item_entry_id(item.entry_id) if tag != nil
            name_override[item.entry_id] = tag.tag_name

          #############################
          ## Custom Command
          when Bot::Inventory::catalog_value('item_type_custom_command')
            command = Bot::CustomCommands::get_custom_command_by_item_entry_id(item.entry_id)
            Bot::CustomCommands::remove_custom_command_by_item_entry_id(item.entry_id) if command != nil
            name_override[item.entry_id] = command.command_name
          
          #############################
          ## Error: Unhandled
          else
            puts "Unhandled item type (#{item.item_type}) encountered when removing after failing to renew!"
            next # continue onto valid items
          end
        end
      end

      # send the user a dm letting them know they had subscriptions expire
      if not removed_items.empty?
        owner.user.dm.send_embed do |embed|
          embed.author = {
              name: STRING_BANK_NAME,
              icon_url: IMAGE_BANK
          }

          purchase = pl(removed_items.count, "Purchase")
          embed.color = COLOR_EMBED
          embed.title = "#{purchase} Expired"
          embed.description = "Unfortunately, you could not afford to renew the following so they have been removed!"

          # add a field for each removed item, all inline, it should wrap as necessary
          removed_items.each do |item|
            # get names and clense to avoid message sending errors
            type_ui_name = item.type_ui_name
            type_ui_name = type_ui_name.nil? ? "TYPE NAME NOT FOUND (#{item.item_type})" : type_ui_name

            item_ui_name = item.ui_name
            item_ui_name = item_ui_name.nil? ? "ITEM NAME NOT FOUND (#{item.item_id})" : item_ui_name

            if name_override[item.entry_id] != nil
              item_ui_name = "#{name_override[item.entry_id]}"
            end

            embed.add_field(
              name: type_ui_name,
              value: item_ui_name,
              inline: true
            )
          end         
        end
      end
    end

    # todo: perform any other routine maintenance
  end

  # schedule the raffle every friday at 5PM GMT
  # executes immediately if today is friday past 5PM GMT
  def self.next_friday_at_5pm()
    next_friday = Bot::Timezone::timezone_next_friday('Etc/GMT')
    next_friday_5pm = next_friday.to_time + 17*60*60
    puts "Info: First raffle scheduled for #{next_friday_5pm}\n"
    return next_friday_5pm
  end

  SCHEDULER.every "#{RAFFLE_FREQUENCY}d", :first_at => next_friday_at_5pm() do
    entry_count = RAFFLE_ENTRIES.count
    entry_count = entry_count.nil? ? 0 : entry_count

    # find bot commands channel
    channel = SERVER.channels.find{ |c| c.id == BOT_COMMANDS_CHANNEL_ID }
    next if channel.nil?

    # find raffle role
    raffle_role = SERVER.roles.find{ |r| r.id == RAFFLE_ROLE_ID }

    if entry_count > 0
      # get winner and reward them
      winner_idx = rand(RAFFLE_ENTRIES.count)
      winner_user_id = RAFFLE_ENTRIES.offset(winner_idx).first[:user_id]
      winnings_value = entry_count * Bot::Bank::appraise_item('raffle_win')
      RAFFLE_ENTRIES.delete # delete all entries
      
      winner = DiscordUser.new(winner_user_id)
      Bot::Bank::deposit(winner.id, winnings_value)

      # post results and announce start of next
      raffle_mention = raffle_role.nil? ? "@Raffle" : raffle_role.mention
      cost_per_ticket = Bot::Bank::appraise_item('raffle_buyticket')

      msg = "#{winner.mention} has won the raffle...\n\n" +
        "#{raffle_mention} A new one has begun! Use the command " + 
        "+raffle buyticket [number] (default 1) to purchase raffle " +
        "tickets. Tickets cost #{cost_per_ticket} Starbucks each."

      channel.send_message(msg)

    else
      channel.send_message("**No one entered the raffle. Aww...**")
    end
  end

  ###########################
  ##   STANDARD COMMANDS   ##
  ###########################
  # set the user's timezone
  SETTIMEZONE_COMMAND_NAME = "settimezone"
  SETTIMEZONE_DESCRIPTION = "Set your timezone.\nSee https://en.wikipedia.org/wiki/List_of_tz_database_time_zones for a list of valid values."
  SETTIMEZONE_ARGS = [["timezone_name", String]]
  SETTIMEZONE_REQ_COUNT = 1
  command :settimezone do |event, *args|
    break unless call_command?(event.channel.id)

    # parse args
    opt_defaults = []
    parsed_args = Convenience::ParseArgsAndRespondIfInvalid(
      event,
      SETTIMEZONE_COMMAND_NAME,
      SETTIMEZONE_DESCRIPTION,
      SETTIMEZONE_ARGS,
      SETTIMEZONE_REQ_COUNT,
      opt_defaults,
      args)
    break unless not parsed_args.nil?

    # hack: parsed correctly, include spaces for user friendliness
    cmd_len = SETTIMEZONE_COMMAND_NAME.length
    parsed_args["timezone_name"] = event.message.content[cmd_len + 1..-1].strip()
    parsed_args["timezone_name"].tr_s!(' ', '_')

    next_time_allowed = Bot::Timezone::get_next_time_can_change_timezone(event.user.id)
    if Bot::Timezone::user_now(event.user.id) < next_time_allowed
      event.respond "Sorry, you can't update your timezone until " + 
        "#{next_time_allowed.strftime('%A, %B %d')}."
      break
    end

    timezone_name =  parsed_args["timezone_name"]
    if Bot::Timezone::set_user_timezone(event.user.id, timezone_name)
      event.respond "Timezone set to #{Bot::Timezone::get_user_timezone(event.user.id)}"
    else
      event.respond "Timezone not recognized \"#{timezone_name}\""
    end
  end

  # get the name of user's configured timezone
  command :gettimezone do |event|
    break unless call_command?(event.channel.id)
    event.respond "Your current timezone is \"#{Bot::Timezone::get_user_timezone(event.user.id)}\""
  end

  # display all of the available items for purchase
  command :shop do |event|
    break unless call_command?(event.channel.id)
    
    # enumerate types
    types = { }
    items_of_type = { }
    cur_type = 0x1000
    while (type_name = Bot::Inventory::catalog_value(cur_type)) != nil
      types[cur_type] = type_name
      items_of_type[type_name] = []
      cur_type += 0x1000
    end

    # enumerate items for each type
    types.each do |type_id, type_name|
      item_id = type_id + 1
      while (item_name = Bot::Inventory::catalog_value(item_id)) != nil
        items_of_type[type_name].push(item_name)
        item_id += 1
      end
    end

    event.send_embed do |embed|
      embed.author = {
          name: STRING_BANK_NAME,
          icon_url: IMAGE_BANK
      }

      embed.title = "Cobalt's Shop"
      embed.description = "Hey there, here is where you can find " +
        "information about my shop. You can earn Starbucks to spend here " +
        "by being active on the server and using the checkin command " +
        "once a day. In addition, if you're feeling courageous you can " +
        "try your luck in the raffle.\n\n" +
        "Here is everything currently available in the shop:\n"

      printed_types = Set[]
      types.each do |type_id, type_name|
        # avoid double printing types with shared names
        next if printed_types.include?(type_name)
        printed_types.add(type_name)
        type_cost = Bot::Inventory::get_item_type_value(type_id)
        type_renewal_cost = Bot::Inventory::get_item_type_renewal_cost(type_id)
        type_lifetime = Bot::Inventory::get_item_type_lifetime(type_id)

        # if there are sub-items display the full list
        embed.description += "**#{type_name}**\n"

        cost_str = "#{pl(type_cost, "Starbuck")}"
        unless type_lifetime.nil? or type_renewal_cost.nil?
        cost_str += " + #{pl(type_renewal_cost, "Starbuck")} every #{ple(type_lifetime, "day")}"
        end
        cost_str += "\n"

        embed.description += cost_str
        if not items_of_type[type_name].count == 1
          
          items_of_type[type_name].each do |item_name|
            embed.description += " - #{item_name}\n"
          end
        end
      end

      embed.color = COLOR_EMBED
    end
  end

  # get daily amount
  command :checkin do |event|
    break unless call_command?(event.channel.id)

    # determine if the user can checkin
    user = DiscordUser.new(event.user.id)
    can_checkin = false
    today = Bot::Timezone::user_today(user.id)
    today = Bot::Timezone::user_to_utc(user.id, today).to_time.to_i
    last_checkin_entry = USER_CHECKIN_TIME[user_id: user.id]
    if last_checkin_entry.nil? or 
       last_checkin_entry[:checkin_timestamp] < today
      can_checkin = true
    end

    # clean up for good measure since this will one of be the most performed action
    # note: calling this has no impact on the results of checkin
    Bot::Bank::clean_account(user.id)

    # checkin if they can do that today
    checkin_value = get_user_checkin_value(user.id)
    if can_checkin
      Bot::Bank::deposit(user.id, checkin_value)

      now = Bot::Timezone::utc_now().to_time.to_i
      if last_checkin_entry == nil
        USER_CHECKIN_TIME << {
          user_id: user.id, 
          checkin_timestamp: now
        }
      else
        last_checkin_entry = USER_CHECKIN_TIME.where(user_id: user.id)
        last_checkin_entry.update(checkin_timestamp: now)
      end
    end

    event.send_embed do |embed|
      embed.author = {
          name: STRING_BANK_NAME,
          icon_url: IMAGE_BANK
      }

      embed.thumbnail = {url: user.avatar_url}
      embed.footer = {text: "Use +checkin once a day to earn #{checkin_value} Starbucks"}
      embed.color = COLOR_EMBED

      title = ""
      if user.nickname?
        title = " #{user.nickname} (#{user.full_username}) "
      else
        title = " #{user.full_username} "
      end
      embed.title = title

      # fields depend on whether we've just checked in
      if can_checkin
        embed.image = Discordrb::Webhooks::EmbedImage.new(url: IMAGE_CHECKIN)
        embed.add_field(
          name: 'Checked in for',
          value: "#{checkin_value} Starbucks",
          inline: false
        )
      else
        # row: networth and next checkin time
        # todo: display full networth (+ items value)
        embed.add_field(
            name: 'Networth',
            value: "#{Bot::Bank::get_balance(user.id)} Starbucks",
            inline: true
        )

        embed.add_field(
          name: "Time Until Next Check-in",
          value: get_time_until_next_checkin_string(user.id),
          inline: true
        )
      end
    end
  end

  # display balances
  PROFILE_COMMAND_NAME = "profile"
  PROFILE_DESCRIPTION = "See your economic stats."
  PROFILE_ARGS = [["user", DiscordUser]]
  PROFILE_REQ_COUNT = 0
  command :profile do |event, *args|
    break unless call_command?(event.channel.id)
    
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

    # clean before showing profile
    user = parsed_args["user"]
    Bot::Bank::clean_account(user.id)

    # Sends embed containing user bank profile
    event.send_embed do |embed|
      embed.author = {
          name: STRING_BANK_NAME,
          icon_url: IMAGE_BANK
      }

      embed.thumbnail = {url: user.avatar_url}
      embed.footer = {text: "Use +checkin once a day to earn #{get_user_checkin_value(user.id)} Starbucks"}
      embed.color = COLOR_EMBED

      title = ""
      if user.nickname?
        title = " #{user.nickname} (#{user.full_username}) "
      else
        title = " #{user.full_username} "
      end
      embed.title = title

      # ROW 1: Balances
      # todo display full networth (+ item values)
      embed.add_field(
          name: 'Networth',
          value: "#{Bot::Bank::get_balance(user.id)} Starbucks",
          inline: true
      )

      embed.add_field(
        name: 'At Risk',
        value: "#{Bot::Bank::get_at_risk_balance(user.id)} Starbucks",
        inline: true
      )

      perma_balance = Bot::Bank::get_perm_balance(user.id)
      if perma_balance < 0
        embed.add_field(
          name: "Outstanding Fines",
          value: "#{-perma_balance} Starbucks",
          inline: true
        )
      else
        embed.add_field(
          name: "Non-Expiring",
          value: "#{perma_balance} Starbucks",
          inline: true
        )
      end

      # ROW 2: Time until next checkin
      embed.add_field(
        name: "Time Until Next Check-in",
        value: get_time_until_next_checkin_string(user.id),
        inline: false
      )

      # ROW 3: Roles, Tags, Commands
      rented_role = get_user_rented_role_item(user.id)
      embed.add_field(
        name: rented_role != nil ? rented_role.type_ui_name : "Role",
        value: rented_role != nil ? rented_role.ui_name : "None",
        inline: true
      )

      tag_count = Bot::Tags::get_user_tag_count(user.id)
      embed.add_field(
        name: "Tags",
        value: tag_count,
        inline: true
      )

      command_count = Bot::CustomCommands::get_user_custom_command_count(user.id)
      embed.add_field(
        name: "Commands",
        value: command_count,
        inline: true
      )
    end
  end

  # display leaderboard
  # TODO: bug, results may differ from profile reporting
  RICHEST_COUNT = 10
  command :richest do |event|
    break unless call_command?(event.channel.id)

    # note: timestamp filtering is a rough estimate based on the server's
    # timezone as it would be prohibitively expensive to clean up all entries
    # for all users prior to the query

    # compute when the last monday as a Unix timestmap
    past_monday = Date.today
    wwday = past_monday.cwday - 1
    past_monday = past_monday - wwday

    # compute last timestamp and query for entries that meet this requirement
    # todo: include inventory value in the total networth computation
    last_valid_timestamp = (past_monday - (Bot::Bank::MAX_BALANCE_AGE_DAYS + 1)).to_time.to_i
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
      "ORDER BY networth DESC\n" +
      "LIMIT #{RICHEST_COUNT};"

    richest = DB[sql]
    if richest == nil || richest.first == nil
      event.respond "No one appears to have money! Please give the devs a ring!!"
      break
    end

    top_user_stats = richest.all
    event.send_embed do |embed|
      embed.author = {
          name: "#{STRING_BANK_NAME}: Top 10",
          icon_url: IMAGE_BANK
      }
      embed.thumbnail = {url: IMAGE_RICHEST}
      embed.color = COLOR_EMBED
      embed.footer = {text: "Disclaimer: results may differ slightly from profile."}

      # add top ten uses
      top_names = ""
      top_networths = ""
      (0...top_user_stats.count).each do |n|
        user_stats = top_user_stats[n] 
        user_id = user_stats[:user_id]
        user = DiscordUser.new(user_id)
        networth = user_stats[:networth]

        if user.nickname?
          top_names += "#{n + 1}: #{user.nickname} (#{user.full_username})\n"
        else
          top_names += "#{n + 1}: #{user.full_username}\n"
        end

        top_networths += "#{networth} Starbucks\n"
      end

      embed.add_field(
            name: "Richest",
            value: top_names,
            inline: true
      )

      embed.add_field(
            name: "Networth",
            value: top_networths,
            inline: true
      )
    end
  end

  # transfer money to another account
  TRANSFERMONEY_COMMAND_NAME = "transfermoney"
  TRANSFERMONEY_DESCRIPTION = "Transfer funds to the specified user."
  TRANSFERMONEY_ARGS = [["to_user", DiscordUser], ["amount", Integer]]
  TRANSFERMONEY_REQ_COUNT = 2
  command :transfermoney do |event, *args|
    break unless call_command?(event.channel.id)

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

    from_user_id = event.user.id
    to_user_id = parsed_args["to_user"].id
    amount = parsed_args["amount"]
    if amount <= 0
      event.respond "You can't transfer negative funds!"
      break
    end

    # clean from_user's entries before transfer
    Bot::Bank::clean_account(from_user_id)

    # transfer funds
    if Bot::Bank::withdraw(from_user_id, amount)
      Bot::Bank::deposit(to_user_id, amount)
      event.respond "#{parsed_args["to_user"].mention}, #{event.user.username} has transfered #{amount} Starbucks to your account!"
    else
      event.respond "You have insufficient funds to transfer that much!"
    end
  end

  # rent a new role
  RENTAROLE_COMMAND_NAME = "rentarole"
  RENTAROLE_DESCRIPTION = "Rent the specified role."
  RENTAROLE_ARGS = [["role", String]]
  RENTAROLE_REQ_COUNT = 1
  command :rentarole do |event, *args|
    break unless call_command?(event.channel.id)
    
    opt_defaults = []
    parsed_args = Convenience::ParseArgs(
      RENTAROLE_ARGS,
      RENTAROLE_REQ_COUNT,
      opt_defaults,
      args)
    
    # special rent-a-role info page
    if parsed_args.nil?
      rand_color_role_id = Bot::Inventory::get_item_id('role_color_obsolete_orange')
      color_role_cost = Bot::Bank::appraise_item('rentarole_color')
      override_role_cost = Bot::Bank::appraise_item('rentarole_override')
      renew_frequency = Bot::Inventory::get_item_lifetime_from_id(rand_color_role_id)
      renewal_cost = Bot::Bank::appraise_item('rentarole_maintain')
      
      event.send_embed do |embed|
        embed.author = {
            name: STRING_BANK_NAME,
            icon_url: IMAGE_BANK
        }

        embed.title = "Rent-A-Role"
        embed.description = 
          "You can rent any of the available roles here. You can only " +
          "rent one at a time. You can rent either a color or an override " +
          "role. You can only rent override roles that you meet the level " +
          "requirement for (e.g. Mewman Citizen).\n\n" +
          "Color roles cost #{color_role_cost} Starbucks and override roles cost " +
          "#{override_role_cost} Starbucks. Every #{ple(renew_frequency, "day")} " +
          "you must pay #{renewal_cost} Starbucks to renew your role. If you " +
          "cannot afford it, you will lose it! It's recommended that " +
          "you keep an excess of Starbucks around.\n\n" +
          "You can use +unrentarole to remove a rented role. There is no refund " +
          "for removing a purchased role.\n\n" +
          "The available roles are as follows:\n" +
          "Color: green, orange, blue, red, lavender, white, magenta, yellow\n" +
          "Override: citizen, squire, knight, noble, monarch, bearer"
        
        embed.footer = {text: "Purchase a role with +rentarole [name]"}
        embed.color = COLOR_EMBED
      end
      break # stop processing
    end
    
    Bot::Bank::clean_account(event.user.id)

    # Check to see if the user is already renting a role.
    rented_role = get_user_rented_role_item(event.user.id)
    if rented_role != nil
      event.respond "You already have a rented role!"
      break
    end

    # parse the user's input
    role_item_id = nil
    role_id = nil
    required_role_id = nil
    role_name = parsed_args["role"]
    case role_name.downcase
    when "green", "ghastly_green"
      role_item_id = Bot::Inventory::get_item_id('role_color_ghastly_green')
      role_id = GHASTLY_GREEN_ROLE_ID
    when "orange", "obsolete_orange"
      role_item_id = Bot::Inventory::get_item_id('role_color_obsolete_orange')
      role_id = OBSOLETE_ORANGE_ROLE_ID
    when "blue", "breathtaking_blue"
      role_item_id = Bot::Inventory::get_item_id('role_color_breathtaking_blue')
      role_id = BREATHTAKING_BLUE_ROLE_ID
    when "red", "retro_red"
      role_item_id = Bot::Inventory::get_item_id('role_color_retro_red')
      role_id = RETRO_RED_ROLE_ID
    when "lavender", "lavendar", "lullaby_lavender", "lullaby_lavendar", "purple"
      role_item_id = Bot::Inventory::get_item_id('role_color_lullaby_lavender')
      role_id = LULLABY_LAVENDER_ROLE_ID
    when "white", "white_white"
      role_item_id = Bot::Inventory::get_item_id('role_color_whitey_white')
      role_id = WHITEY_WHITE_ROLE_ID
    when "magenta", "marvelous_magenta", "pink"
      role_item_id = Bot::Inventory::get_item_id('role_color_marvelous_magenta')
      role_id = MARVELOUS_MAGENTA_ROLE_ID
    when "yellow", "shallow_yellow"
      role_item_id = Bot::Inventory::get_item_id('role_color_shallow_yellow')
      role_id = SHALLOW_YELLOW_ROLE_ID
    when "citizen", "override_citizen"
      role_item_id = Bot::Inventory::get_item_id('role_override_citizen')
      role_id = OVERRIDE_MEWMAN_CITIZEN_ROLE_ID
      required_role_id = MEWMAN_CITIZEN_ROLE_ID
    when "squire", "override_squire"
      role_item_id = Bot::Inventory::get_item_id('role_override_squire')
      role_id = OVERRIDE_MEWMAN_SQUIRE_ROLE_ID
      required_role_id = MEWMAN_SQUIRE_ROLE_ID
    when "knight", "override_knight"
      role_item_id = Bot::Inventory::get_item_id('role_override_knight')
      role_id = OVERRIDE_MEWMAN_KNIGHT_ROLE_ID
      required_role_id = MEWMAN_KNIGHT_ROLE_ID
    when "noble", "override_noble"
      role_item_id = Bot::Inventory::get_item_id('role_override_noble')
      role_id = OVERRIDE_MEWMAN_NOBLE_ROLE_ID
      required_role_id = MEWMAN_NOBLE_ROLE_ID
    when "monarch", "override_monarch"
      role_item_id = Bot::Inventory::get_item_id('role_override_monarch')
      role_id = OVERRIDE_MEWMAN_MONARCH_ROLE_ID
      required_role_id = MEWMAN_MONARCH_ROLE_ID
    when "bearer", "bearer_of_the_wand", "override_bearer", "override_bearer_of_the_wand"
      role_item_id = Bot::Inventory::get_item_id('role_override_bearer')
      role_id = OVERRIDE_BEARER_OF_THE_WAND_POG_ROLE_ID
      required_role_id = BEARER_OF_THE_WAND_POG_ROLE_ID
    else 
      event.respond "Sorry, I couldn't find that role."
      break
    end

    # ensure the user meets the requiremetns
    user = DiscordUser.new(event.user.id)
    if required_role_id != nil && not(user.role?(required_role_id))
      event.respond "Sorry, you do not meet the level requirements for that override."
      break
    end

    # attempt to buy role
    role_cost = Bot::Inventory::get_item_value_from_id(role_item_id)
    if not Bot::Bank::withdraw(user.id, role_cost)
      event.respond "Sorry, you can't afford that role."
      break
    end

    # compute expiration date
    now_datetime = Time.now.to_datetime

    # store in inventory
    Bot::Inventory::add_item(user.id, role_item_id)

    # assign role and respond
    user.user.add_role(role_id)
    role_ui_name = Bot::Inventory::get_item_ui_name_from_id(role_item_id)
    event.respond "#{user.mention} you now have the #{role_ui_name} role!"
  end

  # remove rented role
  command :unrentarole do |event, *args|
  	break unless call_command?(event.channel.id)
    
    Bot::Bank::clean_account(event.user.id)
    
    # check if the user is currently renting a role
    rented_role = get_user_rented_role_item(event.user.id)
    if rented_role == nil
      event.respond "You aren't currently renting a role!"
      break
    end

    role_id = get_role_for_item_id(rented_role.item_id)
    user = DiscordUser.new(event.user.id)
    if user.role?(role_id)
      user.user.remove_role(role_id)
    end

    Bot::Inventory::remove_item(rented_role.entry_id)
    event.respond "#{user.mention}, you no longer have the role #{rented_role.ui_name}!"
  end

  # custom tag management
  TAG_COMMAND_NAME = "tag"
  TAG_DESCRIPTION = "Manage custom tags that send a specific message when invoked."
  TAG_ARGS = [["action", String], ["tag_name", String]]
  TAG_REQ_COUNT = 1
  command :tag do |event, *args|
    break unless call_command?(event.channel.id)

    opt_defaults = [""]
    parsed_args = Convenience::ParseArgs(
      TAG_ARGS,
      TAG_REQ_COUNT,
      opt_defaults,
      args)

    if parsed_args.nil?
      event.send_embed do |embed|
        embed.author = {
            name: STRING_BANK_NAME,
            icon_url: IMAGE_BANK
        }

        tag_id = Bot::Inventory::get_item_id('tag')
        tag_cost = Bot::Bank::appraise_item('tag_add')
        tag_renewal_cost = Bot::Bank::appraise_item('tag_maintain')
        tag_lifetime = Bot::Inventory::get_item_lifetime_from_id(tag_id)

        embed.title = "Tags"
        embed.description = 
          "You can buy tags here. Tags are custom messages that are sent " +
          "whenever +tag [name] is called. Anyone can use any tag " +
          "on the server! However, they can only be used in the #bot_commands " +
          "channel.\n\n" +
          "You can create a new tag using +tag add [name]. Your " +
          "tag name can be anything, but it cannot contain spaces. If you want, " +
          "you can edit tags you own using +tag edit [name] and remove them " +
          "using +tag delete [name].\n\n" +
          "Tags cost #{tag_cost} Starbucks upfront and #{tag_renewal_cost} " +
          "Starbucks every #{ple(tag_lifetime, "day")} to keep. If you cannot " +
          "afford to pay, they will be deleted!\n\n" +
          "If you want to search all of the available tags use the +tags " +
          "command. You can optionally specify a user (including yourself) " +
          "to look at tags created by someone in particular."
        
        embed.footer = {text: "Create a tag with +tag add [name]"}
        embed.color = COLOR_EMBED
      end
      break # stop processing
    end

    # assume they're trying to use spacs
    if args.count > TAG_ARGS.count
      event.respond "Sorry, tag names don't support spaces!"
      break
    end

    # clean account before proceeding
    Bot::Bank::clean_account(event.user.id)

    # actions and tag names always parsed in lower case
    action = parsed_args['action'].downcase
    tag_name = parsed_args['tag_name'].downcase

    # shared variables
    tag_content_max_length = Bot::Tags::tag_content_max_length
    tag_config_msg = "What would you like your tag to say? Limited to #{tag_content_max_length} characters."
    tag_config_timeout = Bot::Tags::tag_response_timeout
      
    case action
    #############################
    ## ADD
    when "add"
      tag_name_max_length = Bot::Tags::tag_name_max_length
      if tag_name.length > tag_name_max_length
        event.respond "Sorry, the tag name you gave is too long. Names are limited to #{tag_name_max_length} characters."
        break
      end

      if tag_name.length <= 0
        event.respond "You need to specify a tag name!"
        break
      end

      case  tag_name
      when "add", "delete", "edit"
        event.respond "Sorry, you can't use one of the actions as your tag name!"
        break
      end

      if Bot::Tags::has_tag(tag_name)
        event.respond "Sorry, that tag already exists!"
        break
      end

      # only charge after they create it
      tag_cost = Bot::Bank::appraise_item('tag_add')
      if Bot::Bank::get_balance(event.user.id) < tag_cost
        event.respond "Sorry, you can't afford a new tag!"
        break
      end

      tried_add_tag = Bot::DM::do_action?(event.user.id, DM_ACTION_ADD_TAG) do
        # send a temporary message telling user to check dms
        event.channel.send_temporary_message(
          "#{event.user.mention} check you DMs to setup your tag!",
          30 # seconds
        )

        # dm the user to setup tag
        event.user.dm.send_message(tag_config_msg) # internal issue when calling await! on message
        response = event.user.dm.await!({timeout: tag_config_timeout})

        # check if it timed out
        if response.message == nil || response.message.content.empty?
          event.user.dm.send_message("Sorry, I didn't hear back from you so your request to create a new tag has been cancelled. You have not been charged.")
          break
        end

        user = response.user

        # validate length
        tag_content = response.message.content
        if tag_content.length > tag_content_max_length
          user.dm.send_message("Sorry, your tag message was too long! Please try something shorter.")
          break
        end

        # store tag, charge user
        tag_item = Bot::Inventory::add_item_by_name(user.id, 'tag')
        if tag_item == nil
          user.dm.send_message("Sorry, an unknown error occurred and your tag could not be created. Please contact a developer.")
          break
        end

        if not Bot::Tags::add_tag(tag_name, tag_item.entry_id, user.id, tag_content)
          user.dm.send_message("Sorry, a tag named #{tag_name} was created while you were configuring your tag!")
          Bot::Inventory::remove_item(tag_item.entry_id)
          break
        end

        # double check if they're trying to pulls some shit by having two devices
        if not Bot::Bank::withdraw(user.id, tag_cost)
          # DM them for being a jerk and remove tag
          user.dm.send_message("Sorry, you can't afford a new tag!")
          Bot::Tags::remove_tag_by_item_entry_id(tag_item.entry_id)
          Bot::Inventory::remove_item(tag_item.entry_id)
          break
        end
        
        # all went well!
        event.respond "#{user.mention}, you have created the tag #{tag_name}!"
      end

      unless tried_add_tag
        event.respond "Sorry, you're already performing an action in your DMs!"
      end

    #############################
    ## EDIT
    when "edit"
      if not Bot::Tags::has_tag(tag_name)
        event.respond "Sorry, I couldn't find that tag!"
        break
      end

      # make sure the user owns the tag
      tag = Bot::Tags::get_tag(tag_name)
      if tag == nil || tag.owner_user_id != event.user.id
        event.respone "Sorry, you can only edit tags that you own!"
        break
      end

      # only charge after they edit it
      edit_cost = Bot::Bank::appraise_item('tag_edit')
      if Bot::Bank::get_balance(event.user.id) < edit_cost and edit_cost > 0
        event.respond "Sorry, you can't afford to edit a tag right now!"
        break
      end

      tried_edit_tag = Bot::DM::do_action?(event.user.id, DM_ACTION_EDIT_TAG) do
        # send a temporary message telling user to check dms
        event.channel.send_temporary_message(
          "#{event.user.mention} check you DMs to setup your tag!",
          30 # seconds
        )

        # dm the user to edit tag
        event.user.dm.send_message(tag_config_msg) # internal issue when calling await! on message
        response = event.user.dm.await!({timeout: tag_config_timeout})

        # check if it timed out
        if response.message == nil || response.message.content.empty?
          event.user.dm.send_message("Sorry, I didn't hear back from you so your request to edit a tag has been cancelled. You have not been charged.")
          break
        end

        user = response.user

        # validate length
        tag_content = response.message.content
        if tag_content.length > tag_content_max_length
          user.dm.send_message("Sorry, your tag message was too long! Please try something shorter.")
          break
        end

        # double check if they're trying to pulls some shit by having two devices
        if not Bot::Bank::withdraw(user.id, edit_cost)
          # DM them for being a jerk and remove tag
          user.dm.send_message("Sorry, you can't to edit a tag!")
          break
        end
        
        # update tag, validate
        if not Bot::Tags::edit_tag(tag_name, user.id, tag_content)
          user.dm.send_message("Sorry, an error occurred and #{tag_name} could not be edited!")
          break
        end

        # all went well!
        event.respond "#{user.mention}, you have updated the tag #{tag_name}!"
      end

      unless tried_edit_tag
        event.respond "Sorry, you're already performing an action in your DMs!"
      end

    #############################
    ## DELETE
    when "delete"
      tag = Bot::Tags::get_tag(tag_name)
      if not Bot::Tags::remove_tag(tag_name, event.user.id)
        event.respond "Sorry, I couldn't find that tag or you don't own it!"
        break
      end

      Bot::Inventory::remove_item(tag.item_entry_id)
      event.respond "Tag #{tag_name} has been removed!"

    #############################
    ## DISPLAY TAG
    else # user is trying to invoke a tag!      
      # check that user isn't spamming tags
      if (rate_limit = TAG_BUCKET.rate_limited?(event.user.id))
        event.send_temporary_message("**Tags are on cooldown!** Wait for #{rate_limit.round}s.", 5)
        break # stop processing
      end

      # find tag
      user_tag = Bot::Tags::get_tag(action)
      if user_tag == nil
        event.respond "Sorry, I didn't recognize the tag #{user_tag}"
        break
      end

      # send message
      event.respond user_tag.tag_content
    end
  end

  # tag searching
  TAGS_COMMAND_NAME = "tags"
  TAGS_DESCRIPTION = "Search for tags on the server or owned by a specific user. Specify mine to see yours."
  TAGS_ARGS = [["owner_user", DiscordUser]]
  TAGS_REQ_COUNT = 0
  command :tags do |event, *args|
    break unless call_command?(event.channel.id)
    
    args[0] = event.user.id if args.length > 0 && args[0] == "mine" # special
    opt_defaults = [event.user.id]
    parsed_args = Convenience::ParseArgsAndRespondIfInvalid(
      event,
      TAGS_COMMAND_NAME,
      TAGS_DESCRIPTION,
      TAGS_ARGS,
      TAGS_REQ_COUNT,
      opt_defaults,
      args)
    break unless not parsed_args.nil?

    user = (args.nil? || args.count <= 0) ? nil : parsed_args['owner_user']

    # get dataset
    filtered_data = user.nil? ? 
      Bot::Tags::USER_TAGS :
      Bot::Tags::USER_TAGS.where(owner_user_id: user.id)

    count = filtered_data.count
    count = count.nil? ? 0 : count
    if count <= 0
      event.respond "Sorry, I couldn't find any tags!"
      break
    end

    searched_tags = Bot::DM::do_action?(event.user.id, DM_ACTION_LIST_TAGS) do 
      # generate embed inputs
      if user.nil?
        embed_title       = "Server Tags"
        embed_description = "The server has #{pl(count, "tag")}."
        embed_thumbnail   = { url: SERVER.icon_url }
      elsif user.id == event.user.id # self
        embed_title       = "Your Tags"
        embed_description = "You have #{pl(count, "tag")}."
        embed_thumbnail   = { url: user.avatar_url }
      else
        embed_title       = "#{user.full_username}'s Tags"
        embed_description = "This user has #{pl(count, "tag")}."
        embed_thumbnail   = { url: user.avatar_url }
      end

      # paginate results
      Paginator.new(
        event.user.dm,                                    # channel
        event.user.id,                                    # user_id
        { name: STRING_BANK_NAME, icon_url: IMAGE_BANK }, # embed_author
        embed_title,                                      # embed_title
        embed_description,                                # embed_description
        embed_thumbnail,                                  # embed_thumbnail
        filtered_data,                                    # dataset
        :tag_name,                                        # query_column
        true,                                             # force_queries_lowercase 
        Bot::Tags::TAG_HASH_TO_PAGINATOR_FIELD_LAMBDA     # row_hash_to_field_Lambda
        # initial query: nil
        # results_per_page: default
      ).run()
    end

    unless searched_tags
      event.respond "Sorry, you're already performing an action in your DMs!"
    end
  end

  # custom command mangement
  MYCOM_COMMAND_NAME = "mycom"
  MYCOM_DESCRIPTION = "Manage custom cuommands that send a specific message when invoked."
  MYCOM_ARGS = [["action", String], ["command_name", String]]
  MYCOM_REQ_COUNT = 1
  command :mycom do |event, *args|
    break unless call_command?(event.channel.id)

    opt_defaults = [""]
    parsed_args = Convenience::ParseArgs(
      MYCOM_ARGS,
      MYCOM_REQ_COUNT,
      opt_defaults,
      args)

    if parsed_args.nil?
      event.send_embed do |embed|
        embed.author = {
            name: STRING_BANK_NAME,
            icon_url: IMAGE_BANK
        }

        command_id = Bot::Inventory::get_item_id('custom_command')
        command_cost = Bot::Bank::appraise_item('mycom_add')
        command_renewal_cost = Bot::Bank::appraise_item('mycom_maintain')
        command_lifetime = Bot::Inventory::get_item_lifetime_from_id(command_id)

        embed.title = "Custom Command"
        embed.description = 
          "You can buy custom commands here. Custom commands send custom messages " +
          "when they are called using +command_name. Only you can use your custom " +
          "commands, but they can be used anywhere on the server!\n\n" +
          "You can create a new command using +mycom add [name]. Your command " +
          "name can be anything, but it cannot contain spaces. If you want, you " +
          "can edit your commands using +mycom edit [name] and remove them " +
          "using +mycom delete [name].\n\n" +
          "Custom commands cost #{command_cost} Starbucks upfront and " +
          "#{command_renewal_cost} Starbucks every #{ple(command_lifetime, "day")} " +
          "to keep. If you cannot afford to pay, they will be deleted!\n\n" +
          "If you want to see all of your commands use the +mycom list."
        
        embed.footer = {text: "Create a command with +mycom add [name]"}
        embed.color = COLOR_EMBED
      end

      break # stop processing
    end

    # assume they're trying to use spaces
    if args.count > MYCOM_ARGS.count
      event.respond "Sorry, custom command names don't support spaces!"
      break
    end

    # clean account before proceeding
    Bot::Bank::clean_account(event.user.id)

    # actions and command names always parsed in lower case
    action = parsed_args['action'].downcase
    command_name = parsed_args['command_name'].downcase

    # shared variables
    command_content_max_length = Bot::CustomCommands::custom_command_content_max_length
    command_config_msg = "What would you like your command to say? Limited to #{command_content_max_length} characters."
    command_config_timeout = Bot::CustomCommands::custom_command_response_timeout
    
    case action
    #############################
    ## ADD
    when "add"
      command_name_max_length = Bot::CustomCommands::custom_command_name_max_length
      if command_name.length > command_name_max_length
        event.respond "Sorry, the command name you gave is too long. Names are limited to #{command_name_max_length} characters."
        break
      end

      if command_name.length <= 0
        event.respond "You must specify a command name!"
        break
      end

      unless Bot::BOT.commands[command_name.to_sym] == nil
        event.respond "Sorry, you can't name your custom command after an existing command."
        break
      end

      if Bot::CustomCommands::has_custom_command(command_name, event.user.id)
        event.respond "Sorry, you already have a command with the same name!"
        break
      end

      # only charge after they create it
      command_cost = Bot::Bank::appraise_item('mycom_add')
      if Bot::Bank::get_balance(event.user.id) < command_cost
        event.respond "Sorry, you can't afford a new command!"
        break
      end

      tried_add_command = Bot::DM::do_action?(event.user.id, DM_ACTION_ADD_CUSTOM_COMMAND) do 
        # send a temporary message telling user to check dms
        event.channel.send_temporary_message(
          "#{event.user.mention} check you DMs to setup your command!",
          30 # seconds
        )

        # dm the user to setup command
        event.user.dm.send_message(command_config_msg) # internal issue when calling await! on message
        response = event.user.dm.await!({timeout: command_config_timeout})

        # check if it timed out
        if response.message == nil || response.message.content.empty?
          event.user.dm.send_message("Sorry, I didn't hear back from you so your request to create a new command has been cancelled. You have not been charged.")
          break
        end

        user = response.user

        # validate length
        command_content = response.message.content
        if command_content.length > command_content_max_length
          user.dm.send_message("Sorry, your command message was too long! Please try something shorter.")
          break
        end

        # store command, charge user
        command_item = Bot::Inventory::add_item_by_name(user.id, 'custom_command')
        if command_item == nil
          user.dm.send_message("Sorry, an unknown error occurred and your command could not be created. Please contact a developer.")
          break
        end

        if not Bot::CustomCommands::add_custom_command(command_name, user.id, command_item.entry_id, command_content)
          user.dm.send_message("Sorry, you already created a command named #{command_name}!")
          Bot::Inventory::remove_item(command_item.entry_id)
          break
        end

        # double check if they're trying to pulls some shit by having two devices
        if not Bot::Bank::withdraw(user.id, command_cost)
          # DM them for being a jerk and remove command
          user.dm.send_message("Sorry, you can't afford a new command!")
          Bot::CustomCommands::remove_custom_command_by_item_entry_id(command_item.entry_id)
          Bot::Inventory::remove_item(command_item.entry_id)
          break
        end
        
        # all went well!
        event.respond "#{user.mention}, you have created the command #{command_name}!"
      end
      
      unless tried_add_command
        event.respond "Sorry, you're already performing an action in your DMs!"
      end

    #############################
    ## EDIT
    when "edit"
      if not Bot::CustomCommands::has_custom_command(command_name, event.user.id)
        event.respond "Sorry, I couldn't find that command!"
        break
      end

      # only charge after they edit it
      edit_cost = Bot::Bank::appraise_item('mycom_edit')
      if Bot::Bank::get_balance(event.user.id) < edit_cost and edit_cost > 0
        event.respond "Sorry, you can't afford to edit a command right now!"
        break
      end

      tried_edit_command = Bot::DM::do_action?(event.user.id, DM_ACTION_EDIT_CUSTOM_COMMAND) do 
        # send a temporary message telling user to check dms
        event.channel.send_temporary_message(
          "#{event.user.mention} check you DMs to setup your command!",
          30 # seconds
        )

        # dm the user to edit command
        event.user.dm.send_message(command_config_msg) # internal issue when calling await! on message
        response = event.user.dm.await!({timeout: command_config_timeout})

        # check if it timed out
        if response.message == nil || response.message.content.empty?
          event.user.dm.send_message("Sorry, I didn't hear back from you so your request to edit a command has been cancelled. You have not been charged.")
          break
        end

        user = response.user

        # validate length
        command_content = response.message.content
        if command_content.length > command_content_max_length
          user.dm.send_message("Sorry, your command message was too long! Please try something shorter.")
          break
        end

        # double check if they're trying to pulls some shit by having two devices
        if not Bot::Bank::withdraw(user.id, edit_cost)
          # DM them for being a jerk
          user.dm.send_message("Sorry, you can't to edit a command!")
          break
        end
        
        # update command, validate
        if not Bot::CustomCommands::edit_custom_command(command_name, user.id, command_content)
          user.dm.send_message("Sorry, an error occurred and #{command_name} could not be edited!")
          break
        end

        # all went well!
        event.respond "#{user.mention}, you have updated the command #{command_name}!"
      end

      unless tried_edit_command
        event.respond "Sorry, you're already performing an action in your DMs!"
      end

    #############################
    ## DELETE
    when "delete"
      command = Bot::CustomCommands::get_custom_command(command_name, event.user.id)
      if not Bot::CustomCommands::remove_custom_command(command_name, event.user.id)
        event.respond "Sorry, I couldn't find that command!"
        break
      end

      Bot::Inventory::remove_item(command.item_entry_id)
      event.respond "Command #{command_name} has been removed!"

    #############################
    ## LIST COMMANDS
    when "list"
      commands = Bot::CustomCommands::get_all_user_custom_commands(event.user.id)
      if commands.count <= 0
        event.respond "Sorry, you don't own any commands."
        break
      end

      # paginate results
      searched_commands = Bot::DM::do_action?(event.user.id, DM_ACTION_LIST_CUSTOM_COMMANDS) do 
        filtered_data = Bot::CustomCommands::USER_CUSTOM_COMMANDS
          .where(owner_user_id: event.user.id)
        Paginator.new(
          event.user.dm,                                    # channel
          event.user.id,                                    # user_id
          { name: STRING_BANK_NAME, icon_url: IMAGE_BANK }, # embed_author
          "Your Custom Commands",                           # embed_title
          "You own #{pl(commands.count, "command")}",           # embed_description
          { url: event.user.avatar_url },                   # embed_thumbnail
          filtered_data,                                    # dataset
          :command_name,                                    # query_column
          true,                                             # force_queries_lowercase 
          Bot::CustomCommands::COMMAND_HASH_TO_PAGINATOR_FIELD_LAMBDA # row_hash_to_field_Lambda
          # initial query: nil
          # results_per_page: default
        ).run()
      end

      unless searched_commands
        event.respond "Sorry, you're already performing an action in your DMs!"
      end
    end
  end

  # raffle management
  RAFFLE_COMMAND_NAME = "raffle"
  RAFFLE_DESCRIPTION = "Participate in the raffle."
  RAFFLE_ARGS = [["action", String], ["number_of_tickets", Integer]]
  RAFFLE_REQ_COUNT = 0
  command :raffle do |event, *args|
    break unless call_command?(event.channel.id)
    
    opt_defaults = ["info", 1]
    parsed_args = Convenience::ParseArgsAndRespondIfInvalid(
      event,
      RAFFLE_COMMAND_NAME,
      RAFFLE_DESCRIPTION,
      RAFFLE_ARGS,
      RAFFLE_REQ_COUNT,
      opt_defaults,
      args)
    break unless not parsed_args.nil?

    case parsed_args["action"].downcase
    when 'buyticket', 'buytickets'
      tickets_to_buy = parsed_args["number_of_tickets"]
      if tickets_to_buy <= 0
        event.respond "You can't buy negative tickets!"
        break
      end

      cost_of_tickets = tickets_to_buy * Bot::Bank::appraise_item('raffle_buyticket')
      if not Bot::Bank::withdraw(event.user.id, cost_of_tickets)
        event.respond "You can't afford to buy that many!"
        break
      end

      # add the appropriate number of tickets
      (0...tickets_to_buy).each do |ticket|
        RAFFLE_ENTRIES << { user_id: event.user.id }
      end

      event.respond "#{event.user.mention}, you bought #{pl(tickets_to_buy, "ticket")}."

    when 'reminder', 'remind'
      if event.user.role?(RAFFLE_ROLE_ID)
        event.user.remove_role(RAFFLE_ROLE_ID)
        event.respond "Raffle reminder cleared."
      else
        event.user.add_role(RAFFLE_ROLE_ID)
        event.respond "Raffle reminder set."
      end

    when 'info', 'information'
      cost_of_ticket = Bot::Bank::appraise_item('raffle_buyticket')
      roi_of_ticket = Bot::Bank::appraise_item('raffle_win')

      event.send_embed do |embed|
        embed.author = {
            name: STRING_BANK_NAME,
            icon_url: IMAGE_BANK
        }

        embed.title = "Raffle"
        embed.description = 
          "The raffle is an event that occurs once every Friday at 5:00 PM GMT. " +
          "When it happens, any user that has purchased at least one " +
          "ticket can win! Your odds of winning are directly proportionate to " +
          "how many you bought. Each ticket costs #{cost_of_ticket} Starbucks " +
          "and for every ticket in the pool the winner will receive " +
          "#{roi_of_ticket} Starbucks. If you want a reminder call the command " +
          "+raffle reminder; call it again to remove the reminder. Enter now " +
          "to win big! "
        
        embed.footer = {text: "Purchase tickets with +raffle buyticket [count] (default 1)"}
        embed.color = COLOR_EMBED
      end
    end
  end

  ############################
  ##   MODERATOR COMMANDS   ##
  ############################
  FINE_COMMAND_NAME = "fine"
  FINE_DESCRIPTION = "Fine a user for inappropriate behavior."
  FINE_ARGS = [["user", DiscordUser], ["fine_size", String]]
  FINE_REQ_COUNT = 2
  command :fine do |event, *args|
    break unless call_command?(event.channel.id)
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

    user_id = parsed_args["user"].id
    user_mention = parsed_args["user"].mention
    severity = parsed_args["fine_size"]

    entry_id = "fine_#{severity}"
    fine_size = Bot::Bank::appraise_item(entry_id)
    orig_fine_size = fine_size
    if fine_size == nil
      event.respond "Invalid fine size specified (small, medium, large)."
      break
    end

    # clean before proceeding
    Bot::Bank::clean_account(user_id)

    # deduct fine from bank account balance
    balance = Bot::Bank::get_balance(user_id)
    withdraw_amount = [fine_size, balance].min
    if withdraw_amount > 0
      Bot::Bank::withdraw(user_id, withdraw_amount)
      fine_size -= withdraw_amount
    end

    # deposit rest as negative perma currency
    Bot::Bank::deposit_perm(user_id, -fine_size)

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
    break unless call_command?(event.channel.id)
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
    if Bot::Bank::get_balance(user_id) <= 0
      event.respond "Sorry, you're already broke!"
      next # bail out, this fool broke
    end

  	# completely clear your balances
    Bot::Bank::USER_BALANCES.where{Sequel.&({user_id: user_id}, (amount > 0))}.delete
  	event.respond "#{user_mention} has lost all funds!\nhttps://media1.tenor.com/images/25489503d3a63aa7afbc0217eba128d3/tenor.gif?itemid=8581127"
  end

  # Clear all fines and balances.
  CLEARBALANCES_COMMAND_NAME = "clearbalances"
  CLEARBALANCES_DESCRIPTION = "Clear out your or another user's balance and fines."
  CLEARBALANCES_ARGS = [["user", DiscordUser]]
  CLEARBALANCES_REQ_COUNT = 0
  command :clearbalances do |event, *args|
    break unless call_command?(event.channel.id)
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
    Bot::Bank::USER_BALANCES.where(user_id: user_id).delete
    Bot::Bank::USER_PERMA_BALANCES.where(user_id: user_id).delete
    event.respond "#{user_mention} has had all fines and balances cleared"
  end

  # gives a specified amount of starbucks, devs only
  GIMME_COMMAND_NAME = "gimme"
  GIMME_DESCRIPTION = "Give Starbucks to self or specified user."
  GIMME_ARGS = [["amount", Integer], ["user", DiscordUser], ["type", String]]
  GIMME_REQ_COUNT = 1
  command :gimme do |event, *args|
    break unless call_command?(event.channel.id)
    break unless Convenience::IsUserDev(event.user.id)

    opt_defaults = [event.user.id, "temp"]
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
    username = parsed_args["user"].full_username
    Bot::Bank::clean_account(user_id)

    case type.downcase
    when "perma", "perm", "permanent"
      Bot::Bank::deposit_perm(user_id, amount)
    else
      Bot::Bank::deposit(user_id, amount)
    end
    event.respond "#{username} received #{amount} Starbucks"
  end

  # takes a specified amount of starbucks, devs only
  TAKEIT_COMMAND_NAME = "takeit"
  TAKEIT_DESCRIPTION = "Take Starbucks from self or specified user."
  TAKEIT_ARGS = [["amount", Integer], ["user", DiscordUser]]
  TAKEIT_REQ_COUNT = 1
  command :takeit do |event, *args|
    break unless call_command?(event.channel.id)
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
    Bot::Bank::clean_account(user_id)
    if Bot::Bank::withdraw(user_id, amount)
      event.respond "#{user_mention} lost #{amount} Starbucks"
    else
      event.respond "#{user_mention} does not have at least #{amount} Starbucks"
    end
  end

  # print out the user's debug profile
  DEBUGPROFILE_COMMAND_NAME = "debugprofile"
  DEBUGPROFILE_DESCRIPTION = "Display a debug table of the user's info."
  DEBUGPROFILE_ARGS = [["user", DiscordUser]]
  DEBUGPROFILE_REQ_COUNT = 0
  command :debugprofile do |event, *args|
    break unless call_command?(event.channel.id)
    break unless Convenience::IsUserDev(event.user.id)

    opt_defaults = [event.user.id]
    parsed_args = Convenience::ParseArgsAndRespondIfInvalid(
      event,
      DEBUGPROFILE_COMMAND_NAME,
      DEBUGPROFILE_DESCRIPTION,
      DEBUGPROFILE_ARGS,
      DEBUGPROFILE_REQ_COUNT,
      opt_defaults,
      args)
    break unless not parsed_args.nil? 

    user = parsed_args["user"]
    Bot::Bank::clean_account(user.id)
      
    response = 
      "**User:** #{user.full_username}\n" +
      "**Networth:** #{Bot::Bank::get_balance(user.id)} Starbucks" +
      "\n**Non-Expiring:** #{Bot::Bank::get_perm_balance(user.id)} Starbucks" +
      "\n\n**Table of Temp Balances**"

    user_transactions = Bot::Bank::USER_BALANCES.where{Sequel.&({user_id: user.id}, (amount > 0))}.order(Sequel.asc(:timestamp)).all
    (0...user_transactions.count).each do |n|
      transaction = user_transactions[n]

      amount = transaction[:amount]
      timestamp = transaction[:timestamp]
      response += "\n#{amount} received on #{Bot::Timezone::timestamp_to_user(event.user.id, timestamp)}"
    end

    event.respond response
  end

  # get timestamp of the last time the user checked-in in the caller's local timezone
  LASTCHECKIN_COMMAND_NAME = "lastcheckin"
  LASTCHECKIN_DESCRIPTION = "Get the timestamp for when the specified user can last checked in."
  LASTCHECKIN_ARGS = [["user", DiscordUser]]
  LASTCHECKIN_REQ_COUNT = 0
  command :lastcheckin do |event, *args|
    break unless call_command?(event.channel.id)
    break unless Convenience::IsUserDev(event.user.id)

    opt_defaults = [event.user.id]
    parsed_args = Convenience::ParseArgsAndRespondIfInvalid(
      event,
      LASTCHECKIN_COMMAND_NAME,
      LASTCHECKIN_DESCRIPTION,
      LASTCHECKIN_ARGS,
      LASTCHECKIN_REQ_COUNT,
      opt_defaults,
      args)
    break unless not parsed_args.nil?  

    last_checkin = USER_CHECKIN_TIME[user_id: parsed_args["user"].id]
    if last_checkin.nil?
      event.respond "User hasn't checked in yet"
      break
    end

    last_checkin = last_checkin[:checkin_timestamp]
    last_checkin = Bot::Timezone::timestamp_to_user(event.user.id, last_checkin)
    event.respond "Last checked in at #{last_checkin}"
  end

  # clear last checkin timestamp
  CLEARCHECKIN_COMMAND_NAME = "clearcheckin"
  CLEARCHECKIN_DESCRIPTION = "Clear checkin time."
  CLEARCHECKIN_ARGS = [["user", DiscordUser]]
  CLEARCHECKIN_REQ_COUNT = 0
  command :clearcheckin do |event, *args|
    break unless call_command?(event.channel.id)
    break unless Convenience::IsUserDev(event.user.id)

    opt_defaults = [event.user.id]
    parsed_args = Convenience::ParseArgsAndRespondIfInvalid(
      event,
      CLEARCHECKIN_COMMAND_NAME,
      CLEARCHECKIN_DESCRIPTION,
      CLEARCHECKIN_ARGS,
      CLEARCHECKIN_REQ_COUNT,
      opt_defaults,
      args)
    break unless not parsed_args.nil?  

    USER_CHECKIN_TIME.where(user_id: parsed_args["user"].id).delete
    event.respond "Last checkin time cleared for #{parsed_args["user"].full_username}"
  end

  ADDITEM_COMMAND_NAME = "additem"
  ADDITEM_DESCRIPTION = "Give the user the specified item."
  ADDITEM_ARGS = [["item", String], ["user", DiscordUser]]
  ADDITEM_REQ_COUNT = 1
  command :additem do |event, *args|
    break unless call_command?(event.channel.id)
    break unless Convenience::IsUserDev(event.user.id)

    opt_defaults = [event.user.id]
    parsed_args = Convenience::ParseArgsAndRespondIfInvalid(
      event,
      ADDITEM_COMMAND_NAME,
      ADDITEM_DESCRIPTION,
      ADDITEM_ARGS,
      ADDITEM_REQ_COUNT,
      opt_defaults,
      args)
    break unless not parsed_args.nil?

    item_name = parsed_args["item"]
    if Bot::Inventory::add_item_by_name(parsed_args["user"].id, item_name) != nil
      event.respond "#{item_name} added!"
    else
      event.repond "Item '#{item_name}' not recognized."
    end
  end

  INVENTORY_COMMAND_NAME = "inventory"
  INVENTORY_DESCRIPTION = "Get the user's complete inventory."
  INVENTORY_ARGS = [["user", DiscordUser], ["item_type", Integer]]
  INVENTORY_REQ_COUNT = 0
  command :inventory do |event, *args|
    break unless call_command?(event.channel.id)
    break unless Convenience::IsUserDev(event.user.id)

    opt_defaults = [event.user.id, -1]
    parsed_args = Convenience::ParseArgsAndRespondIfInvalid(
      event,
      INVENTORY_COMMAND_NAME,
      INVENTORY_DESCRIPTION,
      INVENTORY_ARGS,
      INVENTORY_REQ_COUNT,
      opt_defaults,
      args)
    break unless not parsed_args.nil?

    user = parsed_args["user"]
    item_type = parsed_args["item_type"]
    item_type = item_type > 0 ? item_type : nil
    
    items = Bot::Inventory::get_inventory(user.id, item_type)
    value = Bot::Inventory::get_inventory_value(user.id)
    response = "#{user.full_username} inventory valued at #{value} Starbucks\n"
    items.each do |item|
      if item.expiration != nil
        days_to_expiration = (item.expiration - Time.now.to_i)/(24.0*60.0*60.0)
        response += "#{item.ui_name} expires in #{days_to_expiration} days\n"
      else
        response += "#{item.ui_name}\n"
      end
    end
    
    event.respond response
  end

  CLEARINVENTORY_COMMAND_NAME = "clearinventory"
  CLEARINVENTORY_DESCRIPTION = "Get the user's complete inventory."
  CLEARINVENTORY_ARGS = [["user", DiscordUser]]
  CLEARINVENTORY_REQ_COUNT = 0
  command :clearinventory do |event, *args|
    break unless call_command?(event.channel.id)
    break unless Convenience::IsUserDev(event.user.id)

    opt_defaults = [event.user.id]
    parsed_args = Convenience::ParseArgsAndRespondIfInvalid(
      event,
      CLEARINVENTORY_COMMAND_NAME,
      CLEARINVENTORY_DESCRIPTION,
      CLEARINVENTORY_ARGS,
      CLEARINVENTORY_REQ_COUNT,
      opt_defaults,
      args)
    break unless not parsed_args.nil?

    user = parsed_args["user"]
    items = Bot::Inventory::get_inventory(user.id)
    items.each do |item|
      Bot::Inventory::remove_item(item.entry_id)
    end

    event.respond "#{user.full_username}'s inventory was cleared"
  end

  # econ dummy command, does nothing lazy cleanup devs only
  command :econdummy do |event|
    break unless call_command?(event.channel.id)
    break unless Convenience::IsUserDev(event.user.id)

    Bot::Bank::clean_account(event.user.id)
    event.respond "Database cleaned for #{event.user.username}##{event.user.discriminator}"
  end

  command :oodlesoftags do |event|
    break unless call_command?(event.channel.id)
    break unless Convenience::IsUserDev(event.user.id)
    counter = 0
    (100...110).each do |user_id|
      # prevent expiration
      if Bot::Bank::get_balance(user_id) <= 0
        Bot::Bank::deposit(user_id, 10000)
      end

      # add garbage tags
      (0...50).each do |count|
        counter += 1
        tag_name = (0...10).map { (65 + rand(26)).chr }.join
        tag_content = "content #{counter}"
        next if Bot::Tags::has_tag(tag_name)
        
        item = Bot::Inventory::add_item_by_name(user_id, 'tag')
        Bot::Tags::add_tag(tag_name, item.entry_id, user_id, tag_content)
      end
    end

    return "done"
  end

  command :oodlesofcommands do |event|
    break unless call_command?(event.channel.id)
    break unless Convenience::IsUserDev(event.user.id)
    counter = 0
    user_id = event.user.id
    
    # prevent expiration
    if Bot::Bank::get_balance(user_id) <= 10000000
      Bot::Bank::deposit(user_id, 10000000)
    end

    # add garbage tags
    (0...500).each do |count|
      counter += 1
      command_name = (0...10).map { (65 + rand(26)).chr }.join
      command_content = "longer command content is long don't you think? #{counter}"
      next if Bot::CustomCommands::has_custom_command(command_name, user_id)
      
      item = Bot::Inventory::add_item_by_name(user_id, 'custom_command')
      Bot::CustomCommands::add_custom_command(command_name, user_id, item.entry_id, command_content)
    end

    return "done" 
  end
end