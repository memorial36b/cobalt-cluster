# Crystal: BeepBoop
require 'rufus-scheduler'
ENV['TZ'] = 'GMT'

# Contains the commands that replicate the functionality of BeepBoop.
module Bot::BeepBoop
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants
  
  # Rufus scheduler
  SCHEDULER = Rufus::Scheduler.new
  # Path to crystal's data folder
  BEEP_DATA_PATH = "#{Bot::DATA_PATH}/beep_boop"
  # Birthday role ID
  BIRTHDAY_ID = 316477719183491073
  # #general ID
  GENERAL_ID = 297550039125983233
  # #bot_commands ID
  BOT_COMMANDS_ID = 307726225458331649
  # #moderation_channel ID
  MODERATION_CHANNEL_ID = 330586271116165120
  # Bucket for booping users
  BOOP_BUCKET = Bot::BOT.bucket(
    :boop,
    limit: 1,
    time_span: 10
  )
  # Bucket for kissing users
  KISS_BUCKET = Bot::BOT.bucket(
    :kiss,
    limit: 1,
    time_span: 45
  )

  # Validates the given string as a correct date, returning the month and day integers if it is valid
  # @param  [String]              str the string to be validated, of the format mm/dd
  # @return [Array<Integer>, nil]     the month and day integers, or nil if date is invalid
  def self.vali_date(str)
    # Define month and day variables
    month, day = str.split('/').map(&:to_i)

    # Case month variable and return month and day if they are valid
    case month
    when 2 # February (28 days)
      return month, day if (1..28).include? day
    when 4, 6, 9, 11 # April, June, September, November (30 days)
      return month, day if (1..30).include? day
    when 1, 3, 5, 7, 8, 10, 12 # January, March, May, July, August, October, December (31 days)
      return month, day if (1..31).include? day
    end

    # Return nil otherwise
    nil
  end

  # Array of users who are in the middle of a proposal (proposing or being proposed to)
  in_proposal = Array.new
  # Array of users who are in the middle of a kiss
  kissing = Array.new
  # Array of users who are in the middle of a divorce
  in_divorce = Array.new

  # Master birthday command: sets a user's birthday (normal users can set their own, staff can set anyone's),
  # gets a user's birthday, checks what the next birthday is or deletes a birthday
  command(:birthday, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event, *args|
    # Sets argument default to 'check'
    args[0] ||= 'check'

    # If user wants to set birthday and the birthday date format is valid:
    if args.size >= 2 &&
       args[0].downcase == 'set' &&
       vali_date(args[1])
      # If user is a moderator setting another user's birthday and user is valid:
      if args.size >= 3 &&
         event.user.role?(MODERATOR_ID) &&
         SERVER.get_user(args[2..-1].join(' '))
        # Load birthday data from file and set given user's birthday to the given date
        YAML.load_data!("#{BEEP_DATA_PATH}/birthdays.yml") do |birthdays|
          birthdays[SERVER.get_user(args[2..-1].join(' ')).id] = vali_date(args[1]).join('/')
        end

        # Sends confirmation message to event channel
        "This user's birthday has been set as **#{Time.new(*[2000] + vali_date(args[1])).strftime('%B %-d')}**."

      # If user is setting their own birthday:
      elsif args.size == 2
        # Load birthday data from file and set given user's birthday to the given date
        YAML.load_data!("#{BEEP_DATA_PATH}/birthdays.yml") do |birthdays|
          birthdays[event.user.id] = args[1]
        end

        # Sends confirmation message to event channel
        "#{event.user.mention}, your birthday has been set as **#{Time.utc(*[2000] + vali_date(args[1])).strftime('%B %-d')}**."
      end

    # If user is checking a birthday:
    elsif args.size >= 1 &&
          args[0].downcase == 'check'
      # If user wants to check their own birthday, sets user variable equal to event user
      if args.size == 1
        user = event.user

      # If user wants to check another user's birthday and given user is valid, set user variable equal to that user
      elsif args.size >= 2 &&
            (user = SERVER.get_user(args[1..-1].join(' ')))

      # Otherwise, break
      else break
      end

      # Load birthday data from file into variable
      birthdays = YAML.load_data!("#{BEEP_DATA_PATH}/birthdays.yml")

      # Send embed containing birthday info if user has an entry in the birthday data file
      if birthdays[user.id]
        event.channel.send_embed do |embed|
          embed.author = {
              name: "USER: #{user.display_name} (#{user.distinct})",
              icon_url: user.avatar_url
          }
          embed.description = "#{user.mention}'s birthday is **#{Time.utc(*[2000] + vali_date(birthdays[user.id])).strftime('%B %-d')}**."
          embed.color = 0xFFD700
        end

      # Otherwise, send message saying user hasn't set birthday
      else
        event.channel.send_temporary_message('This user has not set their birthday.', 5)
      end

    # If user is checking the next birthday:
    elsif args[0].downcase == 'next'
      # Load birthday data from file into variable
      birthdays = YAML.load_data!("#{BEEP_DATA_PATH}/birthdays.yml")

      # Define variable containing the next time every user's birthday will occur (i.e. if a user's birthday has
      # already occurred this year, the time defined will be next year) and sorts it
      upcoming_birthdays = birthdays.map do |id, d|
        if Time.utc(*[Time.now.year] + vali_date(d)) > Time.now
          [id, Time.utc(*[Time.now.year] + vali_date(d))]
        else
          [id, Time.utc(*[Time.now.year + 1] + vali_date(d))]
        end
      end.sort_by { |_id, t| t }

      # Defines variables containing the date of the next birthday and the users with their birthday on that day
      next_date = upcoming_birthdays[0][1].strftime('%B %-d')
      next_users = upcoming_birthdays.select { |_id, t| t == upcoming_birthdays[0][1] }.map { |id, _t| id }

      # Sends embed containing upcoming birthdays
      event.send_embed do |embed|
        embed.author = {
            name: 'Birthdays: Next',
            icon_url: 'https://cdn.discordapp.com/attachments/330586271116165120/427435169826471936/glossaryck_icon.png'
        }
        embed.description = "**On #{next_date}:**\n" +
                            next_users.reduce('') do |memo, id| # combines IDs into parsed string of usernames
                              user = SERVER.member(id)
                              next memo unless user
                              memo + "\n**• #{user.display_name} (#{user.distinct})**"
                            end
        embed.color = 0xFFD700
      end

    # If user wants to delete a birthday, user is a moderator, given user is valid and has an entry in the birthday
    # file, delete the birthday
    elsif args[0].downcase == 'delete' &&
          event.user.role?(302641262240989186) &&
          (user = SERVER.get_user(args[1..-1].join(' '))) &&
          YAML.load_data!("#{BEEP_DATA_PATH}/birthdays.yml")[user.id]
      YAML.load_data!("#{BEEP_DATA_PATH}/birthdays.yml") { |b| b.delete(user.id) }
      "This user's birthday has been deleted." # confirmation message sent to event channel
    end
  end

  # Cron job that announces birthdays 5 minutes after midnight in GMT
  SCHEDULER.cron '5 0 * * *' do
    # Unpin old birthday messages, delete from data file and remove old birthday roles
    YAML.load_data!("#{BEEP_DATA_PATH}/birthday_messages.yml") do |birthday_messages|
      birthday_messages.each { |id| Bot::BOT.channel(GENERAL_ID).load_message(id).delete }
      birthday_messages.clear
    end
    SERVER.role(BIRTHDAY_ID).members.each { |m| m.remove_role(BIRTHDAY_ID) }

    # Selects all users who have a birthday today:
    YAML.load_data!("#{BEEP_DATA_PATH}/birthdays.yml").select do |id, d|
      [Time.now.month, Time.now.day] == vali_date(d)
    end.each do |id, d|
      # Skips unless user is present within server
      next unless SERVER.member(id)

      # Gives user birthday role, sends and pins birthday message
      SERVER.member(id).add_role(BIRTHDAY_ID)
      msg = event.respond("**Happy Birthday, #{SERVER.member(id).mention}!**")
      msg.pin

      # Stores message id in birthday message data file
      YAML.load_data!("#{BEEP_DATA_PATH}/birthday_messages.yml") { |bm| bm.push(msg.id) }
    end
  end

  # Deletes user from birthday data file if they leave
  member_leave do |event|
    YAML.load_data!("#{BEEP_DATA_PATH}/birthdays.yml") { |b| b.delete(event.user.id) }
  end

  # Boops a user with an optional message
  command(:boop, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event, *args|
    # Breaks unless the mentioned user is valid and the boop message doesn't contain here or everyone pings
    break unless SERVER.get_user(args[0]) &&
                 !%w(@here @everyone).any? { |s| args.include? s }

    # If the user has activated the rate limiter bucket (used command within the last 10 seconds), sends temporary
    # cooldown message to event channel
    if rate_limit = BOOP_BUCKET.rate_limited?(event.user.id)
      event.send_temporary_message(
          "**This command is on cooldown!** Wait for #{rate_limit.round}s.",
          5 # seconds until message is deleted
      )

    # Otherwise:
    else
      # Defines user variable
      user = SERVER.get_user(args[0])

      # Loads boop stats from file
      YAML.load_data!("#{BEEP_DATA_PATH}/boops.yml") do |boops|
        # Adds one to the event user's boop counter for the given user and defines a variable with the new count
        if boops[event.user.id][user.id]
          boops[event.user.id][user.id] += 1
        else
          boops[event.user.id][user.id] = 1
        end
        boop_count = boops[event.user.id][user.id]

        # Sends boop message to event channel
        event.respond "**#{event.user.name} has booped #{user.name}#{(args.size == 1) ? '!**' : " with the message:** #{args[1..-1].join(' ')}"}\n" +
                      "That's #{boop_count} time#{(boop_count == 1) ? nil : 's'} now!"
      end
    end

    nil # returns nil so command doesn't send an extra message
  end

  # Lists a user's boops, ordered by how many times they've booped each person
  command(:listboops, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event, *args|
    # Defines user variable depending on whether any arguments were given and loads boop data from file
    user = args.empty? ? event.user : SERVER.get_user(args.join(' '))
    boops = YAML.load_data!("#{BEEP_DATA_PATH}/boops.yml")

    # Breaks unless user has an entry in the boop variable
    break unless boops[user.id]

    # Returns embed containing the top boops
    event.send_embed do |embed|
      embed.author = {
          name: "#{user.display_name} (#{user.distinct}): Top Boop Victims",
          icon_url: 'https://cdn.discordapp.com/attachments/330586271116165120/427435169826471936/glossaryck_icon.png'
      }

      # Sorts user's boops, selects the users who are present in the server,
      # gets the first 10 and parses it into a formatted string for the embed description
      embed.description = boops[user.id].sort_by { |_id, c| c }
                                        .select { |id, _c| SERVER.member(id)}
                                        .reverse[0..9].each_with_index.map do |(id, count), i|
        booped_user = SERVER.member(id)
        "**#{booped_user.display_name} (#{booped_user.distinct})** #{count} boop#{(count == 1) ? nil : 's'}"
      end.join("\n")
      embed.color = 0xFFD700
    end
  end

  # Hugs one or more users
  command(:hug, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |_event, *args|
    # Breaks if none of the mentioned users are valid
    break if args.none? { |a| Bot::BOT.parse_mention(a) && SERVER.get_user(a) }

    # Defines variable containing all valid mentioned users and a formatted string of the users in the format
    # [username], [username], [username] and [username] (and similar)
    users = args.select { |a| Bot::BOT.parse_mention(a) && SERVER.get_user(a) }.map { |a| SERVER.get_user(a) }
    if users.size == 1
      formatted_users = users[0].name
    else
      formatted_users = "#{users[0..-2].map { |u| u.name }.join(', ')} and #{users[-1].name}"
    end

    # Samples a scenario from the hug data file and replaces [user] with the formatted user string
    "*#{YAML.load_data!("#{BEEP_DATA_PATH}/hug_scenarios.yml").sample.gsub('[user]', formatted_users)}*"
  end

  # Proposes to a user
  command(:propose, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event, *args|
    # Defines user variable and breaks unless user is valid and not the same as the event user
    break unless (user = SERVER.get_user(args.join(' '))) &&
                 event.user != user

    # If event user is already in a proposal, sends notification message and breaks
    if in_proposal.include? event.user.id
      event.send_temporary_message(
        'You are already in a proposal!',
        5 # seconds until message is deleted
      )
      break

    # If given user is already in a proposal, sends notification message and breaks
    elsif in_proposal.include? user.id
      event.send_temporary_message(
        'This user is already in a proposal!',
        5 # seconds until message is deleted
      )
      break
    end

    # Loads couples data from file so it can be modified if a new couple needs to be added
    YAML.load_data!("#{BEEP_DATA_PATH}/couples.yml") do |couples|
      # If neither user is already married:
      if [event.user.id, user.id].none? { |id| couples[id] || couples.has_value?(id) }
        # Adds event and given user's IDs to proposal tracker variable and sends proposal request message
        in_proposal.push(event.user.id, user.id)
        event.respond "**#{user.mention}, #{event.user.mention} would like your hand in marriage.**\n" +
                      "\n" +
                      "Do you accept? Respond with `I do` or `I don't`"

        # Defines variable containing the time at which the proposal request expires
        expiry_time = Time.now + 60

        # Awaits response from given user in event channel, returning true if user accepts, false if user denies,
        # or nil if user does not respond; expires if the expiry time has passed
        response = loop do
          await_event = if expiry_time - Time.now > 0
                          event.channel.await!(
                            from: user.id,
                            timeout: expiry_time - Time.now
                          )
                        end
          break unless await_event
          case await_event.message.content.downcase
          when 'i do' then break true
          when "i don't", 'i dont' then break false
          end
        end

        # Deletes both users' IDs from proposal tracker
        in_proposal.delete_if { |id| [event.user.id, user.id].include? id }

        # Cases the response variable
        case response
        # When user accepts the marriage:
        when true
          # Defines a new couple entry in the couples data file and defines their initial karma entry
          # in the karma data file
          couples[event.user.id] = user.id
          YAML.load_data!("#{BEEP_DATA_PATH}/couples_karma.yml") { |k| k[event.user.id] = 1000 }

          # Sends confirmation message to event channel
          event.respond "**Under the red light of the Blood Moon, the souls of #{event.user.mention} and #{user.mention} are bonded in marriage.**\n" +
                        "**Starting Karma:** 1000"

        # When user denies the marriage, sends refusal message to event channel
        when false then event.respond "**#{user.mention} refuses #{event.user.mention}'s offer of marriage.**"

        # When user doesn't respond, sends notification message to event channel
        when nil then event.respond "**#{user.mention} did not respond in time.**"
        end
      end
    end

    nil # returns nil so command doesn't send an extra message
  end

  # Offers a kiss to a user
  command(:kiss, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event, *args|
    # Loads couples list from file
    couples = YAML.load_data!("#{BEEP_DATA_PATH}/couples.yml")

    # Sets argument default to user that the event user is married to
    args[0] ||= couples[event.user.id] || couples.key(event.user.id)

    # Defines user variable, breaking unless it is valid and not the same as event user
    break unless (user = SERVER.get_user(args.join(' '))) &&
                 event.user != user

    # If event user is in the middle of a kiss, sends notification message and breaks
    if kissing.include? event.user.id
      event.send_temporary_message(
        'You already have a pending kiss!',
        5 # seconds until message is deleted
      )
      break

    # If given user is in the middle of a kiss, sends notification message and breaks
    elsif kissing.include? user.id
      event.send_temporary_message(
          'This user already has a pending kiss!',
          5 # seconds until message is deleted
      )
      break

    # If user has already kissed someone in the last 45 seconds, sends rate limit message and breaks
    elsif (rate_limit = KISS_BUCKET.rate_limited?(event.user.id))
      event.send_temporary_message(
          "**This command is on cooldown!** Wait for #{rate_limit.round}s.",
          5 # seconds until message is deleted
      )
      break
    end

    # Adds event and given user's IDs to the tracker variable and sends kiss request message
    kissing.push(event.user.id, user.id)
    event.respond "**#{user.mention}, you have been offered a kiss by #{event.user.mention}.**\n" +
                  "Do you `+agree` or `+refuse`?"

    # Defines variable containing the time at which the kiss request expires
    expiry_time = Time.now + 30

    # If given user is married to event user:
    if couples[event.user.id] == user.id ||
       couples.key(event.user.id) == user.id
      # Awaits response from given user in event channel, returning true if user agrees, false if user refuses,
      # or nil if user does not respond; expires if the expiry time has passed
      response = loop do
        await_event = if expiry_time - Time.now > 0
                        event.channel.await!(
                          from: user.id,
                          timeout: expiry_time - Time.now
                        )
                      end
        break unless await_event
        case await_event.message.content
        when '+agree' then break true
        when '+refuse' then break false
        end
      end

      # Deletes event and given user from kiss tracker
      kissing.delete_if { |id| [event.user.id, user.id].include? id }

      # Cases response variable:
      case response
      # When user agrees to kiss:
      when true
        # Gets which user in the couple is listed as the key in the karma data file
        listed_id = couples[event.user.id] ? event.user.id : user.id

        # Adds 50 to karma and sends confirmation message
        YAML.load_data!("#{BEEP_DATA_PATH}/couples_karma.yml") do |karma|
          karma[listed_id] += 50
          event.send_message(
            "*#{YAML.load_data!("#{BEEP_DATA_PATH}/kiss_scenarios.yml").sample.gsub('[kissee]', user.name).gsub('[kisser]', event.user.name)}*\n" +
            "**Karma:** #{karma[listed_id]}",
            false, # tts
            {image: {url: YAML.load_data!("#{BEEP_DATA_PATH}/kiss_image_urls.yml").sample}}
          )
        end

      # When user refuses kiss:
      when false
        # Gets which user in the couple is listed as the key in the karma data file
        listed_id = couples[event.user.id] ? event.user.id : user.id

        # Loads karma data from file so it can be modified
        YAML.load_data!("#{BEEP_DATA_PATH}/couples_karma.yml") do |karma|
          # Subtracts 50 from karma, equating it to 0 if it were to go below
          karma[listed_id] = karma[listed_id] > 50 ? karma[listed_id] - 50 : 0

          # Sends refusal message to event channel
          event.respond "*#{user.name} refuses #{event.user.name}'s kiss!* Is there couple trouble brewing?\n" +
                        "**Karma:** #{karma[listed_id]}"
        end

      # When user doesn't respond, sends notification message to event channel
      when nil
        event.respond "**#{user.mention} did not respond in time.**"
      end

    # If neither user is married to anyone:
    elsif !(couples[event.user.id] || couples.has_value?(event.user.id) ||
            couples[user.id] || couples.has_value?(user.id))
      # Awaits response for given user, returning true if user agrees, false if user refuses, or nil
      # if user doesn't respond
      response = loop do
        await_event = if expiry_time - Time.now > 0
                        user.await!(
                            in: event.channel,
                            timeout: expiry_time - Time.now
                        )
                      end
        break unless await_event
        case await_event.message.content
        when '+agree' then break true
        when '+refuse' then break false
        end
      end

      # Deletes event and given user from kiss tracker
      kissing.delete_if { |id| [event.user.id, user.id].include? id }

      # Cases response variable and responds with the message's according action (accepting kiss, refusing kiss,
      # or not responding)
      case response
      when true then event.respond "*#{event.user.name} and #{user.name} share a kiss free of attachments.*"
      when false then event.respond "*#{user.name} refuses to accept #{event.user.name}'s kiss.*"
      when nil then event.respond "**#{user.mention} did not respond in time.**"
      end

    # If either user is married to someone else:
    else
      # Gets ID of event user's spouse
      event_user_spouse_id = couples[event.user.id] || couples.key(event.user.id)

      # Awaits response from given user or event user's spouse in event channel; returns true if user agrees,
      # false if user refuses, :walkin if event user's spouse sends a message in the event channel, or nil
      # if user doesn't respond
      response = loop do
        await_event = if expiry_time - Time.now > 0
                        event.channel.await!(
                            from: [user.id, event_user_spouse_id].compact,
                            timeout: expiry_time - Time.now
                        )
                      end
        break unless await_event
        break :walkin if await_event.author.id == event_user_spouse_id
        case await_event.message.content
        when '+agree' then break true
        when '+refuse' then break false
        end
      end

      # Deletes event and given user from kiss tracker
      kissing.delete_if { |id| [event.user.id, user.id].include? id }

      # Cases response variable:
      case response
      # When user agrees to kiss:
      when true
        # Gets ID of given user's spouse
        given_user_spouse_id = couples[user.id] || couples.key(user.id)

        # If given user has a spouse that is online:
        if SERVER.member(given_user_spouse_id) &&
           SERVER.member(given_user_spouse_id).status == :online
          # Gets which user in the given user's marriage is listed as the key in the karma data file
          listed_id = couples[user.id] ? user.id : given_user_spouse_id

          # Loads karma data from file so it can be modified
          YAML.load_data!("#{BEEP_DATA_PATH}/couples_karma.yml") do |karma|
            # Subtracts 50 from karma, equating it to 0 if it were to go below
            karma[listed_id] = karma[listed_id] > 100 ? karma[listed_id] - 100 : 0

            # Sends cheat message to event channel
            event.respond "#{SERVER.member(given_user_spouse_id).mention} is horrified to discover #{user.mention} cheating on them!\n" +
                          "**Karma:** #{karma[listed_id]}"
          end

        # If neither user's spouses witness the kiss, sends confirmation message to event channel
        else
          event.respond "*#{event.user.name} and #{user.name} share an unfaithful, forbidden kiss.*"
        end

      # When user refuses kiss:
      when false
        # If given user has a spouse:
        if couples[user.id] ||
           couples.has_value?(user.id)
          # Gets which user in the given user's marriage is listed as the key in the karma data file
          listed_id = couples[user.id] ? user.id : couples.key(user.id)

          # Loads karma data from file so it can be modified
          YAML.load_data!("#{BEEP_DATA_PATH}/couples_karma.yml") do |karma|
            # Adds 50 to given user's karma
            karma[listed_id] = karma[listed_id] += 50

            # Sends refusal message to event channel
            event.respond "#{user.name} remains faithful to their spouse, refusing to accept #{event.user.name}'s kiss.\n" +
                          "**Karma:** #{karma[listed_id]}"
          end

        # Otherwise, sends refusal message to event channel
        else
          event.respond "*#{user.name} refuses to accept #{event.user.name}'s kiss.*"
        end

      # When event user's spouse walks in on the kiss:
      when :walkin
        # Gets which user in the event user's marriage is listed as the key in the karma data file
        listed_id = couples[event.user.id] ? event.user.id : event_user_spouse_id

        # Loads karma data from file so it can be modified
        YAML.load_data!("#{BEEP_DATA_PATH}/couples_karma.yml") do |karma|
          # Subtracts 50 from karma, equating it to 0 if it were to go below
          karma[listed_id] = karma[listed_id] > 100 ? karma[listed_id] - 100 : 0

          # Sends cheat message to event channel
          event.respond "#{SERVER.member(event_user_spouse_id).mention} is horrified to discover #{event.user.mention} cheating on them!\n" +
                            "**Karma:** #{karma[listed_id]}"
        end

      # When user doesn't respond, sends notification message to event channel
      when nil then event.respond "**#{user.mention} did not respond in time.**"
      end
    end

    nil # returns nil so command doesn't send an extra message
  end

  # Checks a user's spouse
  command(:spouse, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event, *args|
    # Sets argument default to event user's ID
    args[0] ||= event.user.id

    # Defines user variable, or breaks if user is invalid
    break unless (user = SERVER.get_user(args.join(' ')))

    # Loads couples list from file
    couples = YAML.load_data!("#{BEEP_DATA_PATH}/couples.yml")

    # If user is married, loads karma from file and sends embed containing spouse's info and karma
    if (spouse_id = couples[user.id] || couples.key(user.id))
      karma = YAML.load_data!("#{BEEP_DATA_PATH}/couples_karma.yml")
      listed_id = karma[user.id] ? user.id : spouse_id
      event.send_embed do |embed|
        spouse = SERVER.member(spouse_id)
        embed.author = {
            name: "SPOUSE: #{spouse.display_name} (#{spouse.distinct})",
            icon_url: spouse.avatar_url
        }
        embed.description = "**#{user.mention} is married to #{spouse.mention}.**\n" +
                            "**Karma:** #{karma[listed_id]}"
        embed.color = 0xFFD700
      end

    # Otherwise, send not found message to event channel
    else
      event.send_temporary_message(
          'This user is not married!',
          5 # seconds until message is deleted
      )
    end
  end

  # Lists all couples on the server, sorted by karma
  command(:couples, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event, arg = '1'|
    # Loads couples and karma from file
    couples = YAML.load_data!("#{BEEP_DATA_PATH}/couples.yml")
    karma = YAML.load_data!("#{BEEP_DATA_PATH}/couples_karma.yml")

    # Breaks unless given argument is within the range of 1 to the number of pages in the couples embed
    break unless (1..((couples.size / 10.0).ceil)).include?(arg.to_i)

    # Defines variable containing the page number and an array of the position, listed user and karma of the couples
    # to be displayed on the given page (max 10)
    page = arg.to_i
    displayed_couples = karma.sort_by { |_id, k| -k }[((page - 1) * 10)...(((page - 1) * 10) + 10)]
                             .each_with_index.map { |(id, k), i| [((page - 1) * 10) + i + 1, id, k] }

    # Sends embed containing the given page of the couples karma info
    event.send_embed do |embed|
      embed.author = {
          name: "Couples: List (Page #{page}/#{((couples.size / 10.0).ceil)})",
          icon_url: 'https://cdn.discordapp.com/attachments/330586271116165120/464455380928299028/avatar.png'
      }
      embed.description = displayed_couples.map { |p, id, k| "**#{p}.** *#{SERVER.member(id).name} & #{SERVER.member(couples[id]).name}* - **#{k}** karma" }.join("\n")
      embed.color = 0xFFD700
    end

    nil # returns nil so command doesn't send an extra message
  end

  # Divorces spouse, by mutual agreement
  command(:divorce, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event|
    # Loads couples list from file
    couples = YAML.load_data!("#{BEEP_DATA_PATH}/couples.yml")

    # Breaks unless user is married and not already in the middle of a divorce
    break unless (couples[event.user.id] ||
                 couples.has_value?(event.user.id)) &&
                 !in_divorce.include?(event.user.id)

    # Gets ID of user's spouse
    spouse_id = couples[event.user.id] || couples.key(event.user.id)

    # Adds user and spouse IDs to divorce tracker and sends notification message to event channel
    in_divorce.push(event.user.id, spouse_id)
    event.respond "**#{SERVER.member(spouse_id).mention}, #{event.user.mention} is requesting a divorce.**\n" +
                  "\n" +
                  "Do you accept? Respond with `accept` or `refuse`."

    # Defines variable containing the time at which the divorce request expires
    expiry_time = Time.now + 60

    # Awaits response from spouse in event channel, returning true if user accepts, false if user refuses,
    # or nil if user does not respond; expires if the expiry time has passed
    response = loop do
      await_event = if expiry_time - Time.now > 0
                      event.channel.await!(
                          from: spouse_id,
                          timeout: expiry_time - Time.now
                      )
                    end
      break unless await_event
      case await_event.message.content.downcase
      when 'accept' then break true
      when 'refuse' then break false
      end
    end

    # Deletes user and spouse from divorce tracker
    in_divorce.delete_if { |id| [event.user.id, spouse_id].include? id }

    # Cases response variable:
    case response
    # If user accepts divorce:
    when true
      # Gets the ID of the user listed as key in the couple
      listed_id = couples[event.user.id] ? event.user.id : spouse_id

      # Deletes couple entry from couples and karma data files
      YAML.load_data!("#{BEEP_DATA_PATH}/couples.yml") { |c| c.delete(listed_id) }
      YAML.load_data!("#{BEEP_DATA_PATH}/couples_karma.yml") { |k| k.delete(listed_id) }

      # Sends confirmation message to event channel
      event.respond "**The souls of #{event.user.mention} and #{SERVER.member(spouse_id).mention} are cleaved apart.**\n" +
                    "The Blood Moon allows them to seek happiness elsewhere."

    # If user refuses divorce, send refusal message to event channel
    when false then event.respond "**#{SERVER.member(spouse_id).mention} refuses #{event.user.mention}'s request for divorce.**\n" +
                                  "They remain bonded under the Blood Moon."

    # If user does not respond, send no response message to event channel
    when nil then event.respond "**#{SERVER.member(spouse_id).mention} did not respond in time.**"
    end

    nil # returns nil so command doesn't send an extra message
  end

  # Brings marriage to divorce court, where mutual agreement isn't needed if karma is low enough
  command(:divorcecourt, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event|
    # Loads couples list from file
    couples = YAML.load_data!("#{BEEP_DATA_PATH}/couples.yml")

    # Breaks unless user is married and not already in the middle of a divorce
    break unless couples[event.user.id] ||
                 couples.has_value?(event.user.id)

    # Gets the ID of user's spouse and defines variable containing which user's ID is listed as key
    # in the couples list (and by extension the karma data file)
    spouse_id = couples[event.user.id] || couples.key(event.user.id)
    listed_id = couples[event.user.id] ? event.user.id : spouse_id

    # Loads karma data from file so it can be modified if divorce goes through
    YAML.load_data!("#{BEEP_DATA_PATH}/couples_karma.yml") do |karma|
      # If couple has 1000 karma or above, sends refusal message to event channel
      if karma[listed_id] >= 1000
        event.respond "**The Blood Moon observes #{event.user.mention}'s marriage karma and deems it too high to be cleaved.**\n" +
                      "The marriage remains intact."

      # Otherwise:
      else
        # Deletes couple from couples list and karma data file
        YAML.load_data!("#{BEEP_DATA_PATH}/couples.yml") { |c| c.delete(listed_id) }
        karma.delete(listed_id)

        # Sends confirmation message to event channel
        event.respond "**The Blood Moon observes #{event.user.mention}'s marriage karma and deems the bond unfit to remain.**\n" +
                      "**The souls of #{event.user.mention} and #{SERVER.member(spouse_id).mention} are cleaved apart.**\n" +
                      "The Blood Moon allows them to seek happiness elsewhere."
      end
    end

    nil # returns nil so command doesn't send an extra message
  end

  command(:moddivorce, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event, *args|
    # Loads couples list from data file and defines user variable
    couples = YAML.load_data!("#{BEEP_DATA_PATH}/couples.yml")
    user = SERVER.get_user(args.join(' '))

    # Breaks unless user is moderator, given user is valid and married
    break unless event.user.role?(MODERATOR_ID) &&
                 user &&
                 (couples[user.id] ||
                  couples.key(user.id))

    # Gets the ID of user's spouse and defines variable containing which user's ID is listed as key
    # in the couples list (and by extension the karma data file)
    spouse_id = couples[user.id] || couples.key(user.id)
    listed_id = couples[user.id] ? user.id : spouse_id

    # Deletes couple from couples list and karma data file
    YAML.load_data!("#{BEEP_DATA_PATH}/couples.yml") { |c| c.delete(listed_id) }
    YAML.load_data!("#{BEEP_DATA_PATH}/couples_karma.yml") { |k| k.delete(listed_id) }

    # Sends notification message to event channel
    "#{user.mention} has been divorced from #{SERVER.member(spouse_id).mention}."
  end

  # Deletes couple if either user leaves
  member_leave do |event|
    # Loads couple list from file
    couples = YAML.load_data!("#{BEEP_DATA_PATH}/couples.yml")

    # Skips unless user was married
    next unless couples[event.user.id] ||
                couples.key(event.user.id)

    # Defines variable containing which user's ID is listed as key in the couples list
    # (and by extension the karma data file)
    listed_id = couples[event.user.id] ? event.user.id : couples.key(event.user.id)

    # Deletes couple from couples list and karma data file
    YAML.load_data!("#{BEEP_DATA_PATH}/couples.yml") { |c| c.delete(listed_id) }
    YAML.load_data!("#{BEEP_DATA_PATH}/couples_karma.yml") { |k| k.delete(listed_id) }
  end
end