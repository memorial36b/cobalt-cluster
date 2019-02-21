# Crystal: BeepBoop
require 'rufus-scheduler'
ENV['TZ'] = 'GMT'

# Contains the commands that replicate the functionality of BeepBoop.
module Bot::BeepBoop
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  extend Convenience
  include Constants

  # Birthdays dataset
  BIRTHDAYS = DB[:birthdays]
  # Birthday messages dataset
  BIRTHDAY_MESSAGES = DB[:birthday_messages]
  # Boops dataset
  BOOPS = DB[:boops]
  # Couples dataset
  COUPLES = DB[:couples]
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

  module_function

  # Validates the given string as a correct date, returning the month and day integers if it is valid
  # @param  [String]              str the string to be validated, of the format mm/dd
  # @return [Array<Integer>, nil]     the month and day integers, or nil if date is invalid
  def vali_date(str)
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

  # Gets the database entry of a user in the couples dataset; returns nil if user is not married
  # @param  [Integer]                   id the ID of the user to search for
  # @return [Hash<Symbol=>Object>, nil]    the database entry of the user, or nil if not married
  def couple_entry(id)
    COUPLES[spouse1: id] || COUPLES[spouse2: id]
  end

  # Gets the dataset of a user in the greater couples dataset; returns an empty dataset if user
  # is not married
  # @param  [Integer]         id the ID of the user to search for
  # @return [Sequel::Dataset]    the dataset of the user; empty if user is not married
  def couple_dataset(id)
    return COUPLES.where(spouse2: id) if COUPLES.where(spouse1: id).empty?
    COUPLES.where(spouse1: id)
  end

  # Gets the ID of a user's spouse, or nil if the user is not married.
  # @param  [Integer]      id the ID of the user to check the spouse of
  # @return [Integer, nil]    the ID of the user's spouse, or nil if the user is not married
  def spouse_id(id)
    return COUPLES[spouse1: id][:spouse2] if COUPLES[spouse1: id]
    return COUPLES[spouse2: id][:spouse1] if COUPLES[spouse2: id]
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
          (user = SERVER.get_user(args[2..-1].join(' ')))
        # Sets given user's birthday in the database
        BIRTHDAYS.set_new(
            {id:       user.id},
            birthday: vali_date(args[1]).join('/')
        )

        # Sends confirmation message to event channel
        "This user's birthday has been set as **#{Time.new(*[2000] + vali_date(args[1])).strftime('%B %-d')}**."

        # If user is setting their own birthday:
      elsif args.size == 2
        # Sets given user's birthday in the database
        BIRTHDAYS.set_new(
            {id:       event.user.id},
            birthday: vali_date(args[1]).join('/')
        )

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

      # Send embed containing birthday info if user has an entry in the database
      if (entry = BIRTHDAYS[id: user.id])
        event.channel.send_embed do |embed|
          embed.author = {
              name: "USER: #{user.display_name} (#{user.distinct})",
              icon_url: user.avatar_url
          }
          embed.description = "#{user.mention}'s birthday is **#{Time.utc(*[2000] + vali_date(entry[:birthday])).strftime('%B %-d')}**."
          embed.color = 0xFFD700
        end

        # Otherwise, send message saying user hasn't set birthday
      else event.send_temp('This user has not set their birthday.', 5)
      end

      # If user is checking the next birthday:
    elsif args[0].downcase == 'next'
      # Define variable containing the next time every user's birthday will occur (i.e. if a user's birthday has
      # already occurred this year, the time defined will be next year) and sorts it
      upcoming_birthdays = BIRTHDAYS.map do |entry|
        if Time.utc(*[Time.now.year] + vali_date(entry[:birthday])) > Time.now
          [entry[:id], Time.utc(*[Time.now.year] + vali_date(entry[:birthday]))]
        else
          [entry[:id], Time.utc(*[Time.now.year + 1] + vali_date(entry[:birthday]))]
        end
      end
      upcoming_birthdays.sort_by! { |_id, t| t }

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

      # If user wants to delete a birthday, user is a moderator,
      # given user is valid and has an entry in the database delete the birthday
    elsif args[0].downcase == 'delete' &&
        event.user.role?(302641262240989186) &&
        (user = SERVER.get_user(args[1..-1].join(' '))) &&
        BIRTHDAYS[id: user.id]
      BIRTHDAYS.where(id: user.id).delete
      "This user's birthday has been deleted." # confirmation message sent to event channel
    end
  end

  # Cron job that announces birthdays 5 minutes after midnight in GMT
  SCHEDULER.cron '5 0 * * *' do
    # Unpin old birthday messages, delete from data file and remove old birthday roles
    BIRTHDAY_MESSAGES.all { |e| Bot::BOT.channel(e[:channel_id]).load_message(e[:id]).delete }
    BIRTHDAY_MESSAGES.delete
    SERVER.role(BIRTHDAY_ID).members.each { |m| m.remove_role(BIRTHDAY_ID) }

    # Iterates through all users who have a birthday today:
    BIRTHDAYS.all.select { |e| [Time.now.getgm.month, Time.now.getgm.day] == vali_date(e[:birthday]) }.each do |id, d|
      # Skips unless user is present within server
      next unless SERVER.member(id)

      # Gives user birthday role, sends and pins birthday message
      SERVER.member(id).add_role(BIRTHDAY_ID)
      msg = event.respond("**Happy Birthday, #{SERVER.member(id).mention}!**")
      msg.pin

      # Stores message id in birthday message data file
      BIRTHDAY_MESSAGES << {
          channel_id: msg.channel.id,
          id:         msg.id
      }
    end
  end

  # Deletes user from birthday data file if they leave
  member_leave do |event|
    BIRTHDAYS.where(id: event.user.id).delete
  end

  # Boops a user with an optional message
  command(:boop, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event, *args|
    # Breaks unless the mentioned user is valid and the boop message doesn't contain here or everyone pings
    break unless (user = SERVER.get_user(args[0])) &&
        !%w(@here @everyone).any? { |s| args.include? s }

    # If the user has activated the rate limiter bucket (used command within the last 10 seconds), sends temporary
    # cooldown message to event channel
    if (rate_limit = BOOP_BUCKET.rate_limited?(event.user.id))
      event.send_temp("**This command is on cooldown!** Wait for #{rate_limit.round}s.", 5)

    # Otherwise:
    else
      # Adds one to the event user's boop count for the given user in the database
      BOOPS.set_new(
          {
              id:        event.user.id,
              booped_id: user.id
          },
          count:     BOOPS[id: event.user.id, booped_id: user.id] ?
                         BOOPS[id: event.user.id, booped_id: user.id][:count] + 1 : 1
      )

      # Sends boop message to event channel
      event.respond "**#{event.user.name} has booped #{user.name}#{(args.size == 1) ? '!**' : " with the message:** #{args[1..-1].join(' ')}"}\n" +
                        "That's #{pl(BOOPS[id: event.user.id, booped_id: user.id][:count], 'time')} now!"
    end

    nil # returns nil so command doesn't send an extra message
  end

  # Lists a user's boops, ordered by how many times they've booped each person
  command(:listboops, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event, *args|
    # Defines user variable depending on whether any arguments were given
    user = args.empty? ? event.user : SERVER.get_user(args.join(' '))

    # Breaks unless user has an entry in the boop database
    break unless BOOPS[id: user.id]

    # Returns embed containing the top boops
    event.send_embed do |embed|
      embed.author = {
          name: "#{user.display_name} (#{user.distinct}): Top Boop Victims",
          icon_url: 'https://cdn.discordapp.com/attachments/330586271116165120/427435169826471936/glossaryck_icon.png'
      }
      top_booped = BOOPS.where_all(id: user.id).select { |e| SERVER.member(e[:booped_id]) }.sort_by { |e| e[:count] }.reverse[0..9]
      embed.description = top_booped.each_with_index.map do |entry, i|
        booped_user = SERVER.member(entry[:id])
        "**#{booped_user.display_name} (#{booped_user.distinct})** #{pl(entry[:count], 'boop')}"
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
      event.send_temp('You are already in a proposal!', 5)
      break

    # If event user is already married, sends notification message and breaks
    elsif couple_entry(event.user.id)
      event.send_temp('You are already married!', 5)
      break

    # If given user is already in a proposal, sends notification message and breaks
    elsif in_proposal.include? user.id
      event.send_temp('This user is already in a proposal!', 5)
      break

    # If given user is already married, sends notification message and breaks
    elsif couple_entry(user.id)
      event.send_temp('This user is already married!', 5)
      break
    end

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
    in_proposal - [event.user.id, user.id]

    # Cases the response variable
    case response
      # When user accepts the marriage:
    when true
      # Defines a new entry in the database with the couple and their initial karma of 1000
      COUPLES << {
          spouse1: event.user.id,
          spouse2: user.id,
          karma:   1000
      }

      # Sends confirmation message to event channel
      event.respond "**Under the red light of the Blood Moon, the souls of #{event.user.mention} and #{user.mention} are bonded in marriage.**\n" +
                    "**Starting Karma:** 1000"

      # When user denies the marriage, sends refusal message to event channel
    when false then event.respond "**#{user.mention} refuses #{event.user.mention}'s offer of marriage.**"

      # When user doesn't respond, sends notification message to event channel
    when nil then event.respond "**#{user.mention} did not respond in time.**"
    end

    nil # returns nil so command doesn't send an extra message
  end

  # Offers a kiss to a user
  command(:kiss, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event, *args|
    # Sets argument default to user that the event user is married to
    args[0] ||= spouse_id(event.user.id)

    # Defines user variable, breaking unless it is valid and not the same as event user
    break unless (user = SERVER.get_user(args.join(' '))) &&
                 event.user != user

    # If event user is in the middle of a kiss, sends notification message and breaks
    if kissing.include? event.user.id
      event.send_temp('You already have a pending kiss!', 5)
      break

    # If given user is in the middle of a kiss, sends notification message and breaks
    elsif kissing.include? user.id
      event.send_temp('This user already has a pending kiss!', 5)
      break

    # If user has already kissed someone in the last 45 seconds, sends rate limit message and breaks
    elsif (rate_limit = KISS_BUCKET.rate_limited?(event.user.id))
      event.send_temp("**This command is on cooldown!** Wait for #{rate_limit.round}s.", 5)
      break
    end

    # Adds both users' IDs to the tracker variable and sends kiss request message
    kissing.push(event.user.id, user.id)
    event.respond "**#{user.mention}, you have been offered a kiss by #{event.user.mention}.**\n" +
                      "Do you `+agree` or `+refuse`?"

    # Defines variable containing the time at which the kiss request expires
    expiry_time = Time.now + 30

    # If given user is married to event user:
    if spouse_id(event.user.id) == user.id
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
      kissing - [event.user.id, user.id]

      # Cases response variable:
      case response
        # When user agrees to kiss:
      when true
        # Adds 50 to marriage karma in the database
        couple_dataset(user.id).update(karma: couple_entry(user.id)[:karma] + 50)

        # Samples a kiss scenario and gif from their data files and responds in event channel with them
        event.respond(
            "*#{YAML.load_data!("#{BEEP_DATA_PATH}/kiss_scenarios.yml").sample.gsub('[kissee]', user.name).gsub('[kisser]', event.user.name)}*\n" +
            "**Karma:** #{couple_entry(user.id)[:karma]}",
            false, # tts
            {image: {url: YAML.load_data!("#{BEEP_DATA_PATH}/kiss_image_urls.yml").sample}}
        )

        # When user refuses kiss:
      when false
        # Subtracts 50 from marriage karma in the database, equating it to 0 if it were to go below
        couple_dataset(user.id).update(karma: [couple_entry(user.id)[:karma] - 50, 0].max)

        # Sends refusal message to event channel
        event.respond "*#{user.name} refuses #{event.user.name}'s kiss!* Is there couple trouble brewing?\n" +
                      "**Karma:** #{karma[listed_id]}"

        # When user doesn't respond, sends notification message to event channel
      when nil
        event.respond "**#{user.mention} did not respond in time.**"
      end

      # If both users are not married to anyone:
    elsif !(couple_entry(event.user.id) || couple_entry(user.id))
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
      kissing - [event.user.id, user.id]

      # Cases response variable and responds with the message's according action (accepting kiss, refusing kiss,
      # or not responding)
      case response
      when true then event.respond "*#{event.user.name} and #{user.name} share a kiss free of attachments.*"
      when false then event.respond "*#{user.name} refuses to accept #{event.user.name}'s kiss.*"
      when nil then event.respond "**#{user.mention} did not respond in time.**"
      end

      # If either user is married to someone else:
    else
      # Awaits response from given user or event user's spouse in event channel; returns true if user agrees,
      # false if user refuses, :walkin if event user's spouse sends a message in the event channel, or nil
      # if user doesn't respond
      response = loop do
        await_event = if expiry_time - Time.now > 0
                        event.channel.await!(
                            from: [user.id, spouse_id(event.user.id)].compact,
                            timeout: expiry_time - Time.now
                        )
                      end
        break unless await_event
        break :walkin if await_event.author.id == spouse_id(event.user.id)
        case await_event.message.content
        when '+agree' then break true
        when '+refuse' then break false
        end
      end

      # Deletes event and given user from kiss tracker
      kissing - [event.user.id, user.id]

      # Cases response variable:
      case response
        # When user agrees to kiss:
      when true
        # If given user has a spouse that is online:
        if spouse_id(user.id) &&
            SERVER.member(spouse_id(user.id)).status == :online
          # Subtracts 50 from given user's marriage karma in the database, equating it to 0 if it were to go below
          couple_dataset(user.id).update(karma: [couple_entry(user.id)[:karma] - 50, 0].max)

          # Sends cheat message to event channel
          event.respond "#{SERVER.member(spouse_id(user.id)).mention} is horrified to discover #{user.mention} cheating on them!\n" +
                        "**Karma:** #{couple_entry(user.id)[:karma]}"

          # If neither user's spouses witness the kiss, sends confirmation message to event channel
        else
          event.respond "*#{event.user.name} and #{user.name} share an unfaithful, forbidden kiss.*"
        end

        # When user refuses kiss:
      when false
        # If given user has a spouse:
        if couple_entry(user.id)
          # Adds 50 to given user's marriage karma in the database
          couple_dataset(user.id).update(karma: couple_entry(user.id)[:karma] + 50)

          # Sends refusal message to event channel
          event.respond "#{user.name} remains faithful to their spouse, refusing to accept #{event.user.name}'s kiss.\n" +
                        "**Karma:** #{couple_entry(user.id)[:karma]}"

          # Otherwise, sends refusal message to event channel
        else event.respond "*#{user.name} refuses to accept #{event.user.name}'s kiss.*"
        end

        # When event user's spouse walks in on the kiss:
      when :walkin
        # Subtracts 50 from event user's marriage karma, equating it to 0 if it were to go below
        couple_dataset(event.user.id).update(karma: [couple_entry(event.user.id)[:karma] - 50, 0].max)

        # Sends cheat message to event channel
        event.respond "#{SERVER.member(spouse_id(event.user.id)).mention} is horrified to discover #{event.user.mention} cheating on them!\n" +
                      "**Karma:** #{couple_entry(event.user.id)[:karma]}"

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

    # If user is married, sends embed containing spouse's info and karma
    if (spouse_id = spouse_id(user.id))
      event.send_embed do |embed|
        spouse = SERVER.member(spouse_id)
        embed.author = {
            name: "SPOUSE: #{spouse.display_name} (#{spouse.distinct})",
            icon_url: spouse.avatar_url
        }
        embed.description = "**#{user.mention} is married to #{spouse.mention}.**\n" +
            "**Karma:** #{couple_entry(user.id)[:karma]}"
        embed.color = 0xFFD700
      end

    # Otherwise, send not found message to event channel
    else
      event.send_temp('This user is not married!', 5)
    end
  end

  # Lists all couples on the server, sorted by karma
  command(:couples, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event, arg = '1'|
    # Breaks unless index is within the range of 0 to the number of pages in the couples embed
    break unless (0..((COUPLES.all.size - 1) / 10)).include?(index = arg.to_i - 1)

    # Defines variable containing the database entries of the couples sorted by karma and a
    # string array of the couples to be displayed, formatted with position
    sorted_couples = COUPLES.all.sort { |e1, e2| e2[:karma] <=> e1[:karma] }
    displayed_couples = sorted_couples[(index * 10)...((index + 1) * 10)].each_with_index.map do |entry, subindex|
      position = index * 10 + subindex + 1
      spouse1 = Bot::BOT.user(entry[:spouse1])
      spouse2 = Bot::BOT.user(entry[:spouse2])
      karma = entry[:karma]
      "**#{position}.** *#{spouse1.name} & #{spouse2.name}* - **#{karma}** karma"
    end

    # Sends embed containing the given page of the couples karma info
    msg = event.send_embed do |embed|
      embed.author = {
          name: "Couples: List (Page #{arg.to_i}/#{(sorted_couples.size - 1) / 10 + 1})",
          icon_url: 'https://cdn.discordapp.com/attachments/330586271116165120/464455380928299028/avatar.png'
      }
      embed.description = displayed_couples.join("\n")
      embed.color = 0xFFD700
    end

    msg.reaction_controls(event.user, 0..((sorted_couples.size - 1) / 10), 30, index) do |new_index|
      displayed_couples = sorted_couples[(new_index * 10)...((new_index + 1) * 10)].each_with_index.map do |entry, subindex|
        position = new_index * 10 + subindex + 1
        spouse1 = SERVER.member(entry[:spouse1])
        spouse2 = SERVER.member(entry[:spouse2])
        karma = entry[:karma]
        "**#{position}.** *#{spouse1.name} & #{spouse2.name}* - **#{karma}** karma"
      end
      msg.edit(
          '',
          {
              author: {
                  name: "Couples: List (Page #{new_index + 1}/#{(sorted_couples.size - 1) / 10 + 1})",
                  icon_url: 'https://cdn.discordapp.com/attachments/330586271116165120/464455380928299028/avatar.png'
              },
              description: displayed_couples.join("\n"),
              color: 0xFFD700
          }
      )
    end

    nil # returns nil so command doesn't send an extra message
  end

  # Divorces spouse, by mutual agreement
  command(:divorce, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event|
    # Breaks unless user is married and not already in the middle of a divorce
    break unless couple_entry(event.user.id) &&
                 !in_divorce.include?(event.user.id)

    # Gets ID of user's spouse
    spouse_id = spouse_id(event.user.id)

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
    in_divorce - [event.user.id, spouse_id]

    # Cases response variable:
    case response
    # If user accepts divorce:
    when true
      # Gets the ID of the user listed as key in the couple
      listed_id = couples[event.user.id] ? event.user.id : spouse_id

      # Deletes couple entry from database
      couple_dataset(event.user.id).delete

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
    # Breaks unless user is married and not already in the middle of a divorce
    break unless couple_entry(event.user.id) &&
        !in_divorce.include?(event.user.id)

    # If couple has 1000 karma or above, sends refusal message to event channel
    if couple_entry(event.user.id)[:karma] >= 1000
      event.respond "**The Blood Moon observes #{event.user.mention}'s marriage karma and deems it too high to be cleaved.**\n" +
                    "The marriage remains intact."

      # Otherwise:
    else
      # Gets the ID of user's spouse prior to deletion
      spouse_id = spouse_id(event.user.id)

      # Deletes couple from database
      couple_dataset(event.user.id).delete

      # Sends confirmation message to event channel
      event.respond "**The Blood Moon observes #{event.user.mention}'s marriage karma and deems the bond unfit to remain.**\n" +
                    "**The souls of #{event.user.mention} and #{SERVER.member(spouse_id).mention} are cleaved apart.**\n" +
                    "The Blood Moon allows them to seek happiness elsewhere."
    end

    nil # returns nil so command doesn't send an extra message
  end

  command(:moddivorce, channels: [BOT_COMMANDS_ID, MODERATION_CHANNEL_ID]) do |event, *args|
    # Breaks unless user is moderator, given user is valid and married
    break unless event.user.role?(MODERATOR_ID) &&
        (user = SERVER.get_user(args.join(' '))) &&
        couple_entry(user.id)

    # Gets the ID of user's spouse prior to deletion
    spouse_id = spouse_id(user.id)

    # Deletes couple from database
    couple_dataset(user.id).delete

    # Sends notification message to event channel
    "#{user.mention} has been divorced from #{SERVER.member(spouse_id) ? SERVER.member(spouse_id).mention : "user not found (ID #{spouse_id})"}."
  end

  # Deletes couple if either user leaves
  member_leave do |event|
    # Skips unless user was married
    next unless couple_entry(event.user.id)

    # Deletes couple from database
    couple_dataset(event.user.id).delete
  end
end