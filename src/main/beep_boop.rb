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
  # Rufus scheduler
  SCHEDULER = Rufus::Scheduler.new
  # Path to crystal's data folder
  BEEP_DATA_PATH = "#{Bot::DATA_PATH}/beep_boop"
  # Bucket for booping users
  BOOP_BUCKET = Bot::BOT.bucket(
      :boop,
      limit: 1,
      time_span: 10
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

  # Master birthday command: sets a user's birthday (normal users can set their own, staff can set anyone's),
  # gets a user's birthday, checks what the next birthday is or deletes a birthday
  command(:birthday, channels: [BOT_COMMANDS_CHANNEL_ID, MODERATION_CHANNEL_CHANNEL_ID]) do |event, *args|
    # Sets argument default to 'check'
    args[0] ||= 'check'

    # If user wants to set birthday and the birthday date format is valid:
    if args.size >= 2 &&
        args[0].downcase == 'set' &&
        vali_date(args[1])
      # If user is a moderator setting another user's birthday and user is valid:
      if args.size >= 3 &&
          event.user.role?(MODERATOR_ROLE_ID) &&
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
        (event.user.role?(MODERATOR_ROLE_ID) || BIRTHDAYS[id: user.id]) &&
        (user = SERVER.get_user(args[1..-1].join(' ')))
      BIRTHDAYS.where(id: user.id).delete
      "This user's birthday has been deleted." # confirmation message sent to event channel
    end
  end

  # Cron job that announces birthdays 5 minutes after midnight in GMT
  SCHEDULER.cron '5 0 * * *' do
    # Unpin old birthday messages, delete from data file and remove old birthday roles
    BIRTHDAY_MESSAGES.all { |e| Bot::BOT.channel(e[:channel_id]).load_message(e[:id]).delete }
    BIRTHDAY_MESSAGES.delete
    SERVER.role(HAPPY_BD_ROLE_ID).members.each { |m| m.remove_role(HAPPY_BD_ROLE_ID) }

    # Iterates through all users who have a birthday today:
    BIRTHDAYS.all.select { |e| [Time.now.getgm.month, Time.now.getgm.day] == vali_date(e[:birthday]) }.each do |id, d|
      # Skips unless user is present within server
      next unless SERVER.member(id)

      # Gives user birthday role, sends and pins birthday message
      SERVER.member(id).add_role(HAPPY_BD_ROLE_ID)
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
  command(:boop, channels: [BOT_COMMANDS_CHANNEL_ID, MODERATION_CHANNEL_CHANNEL_ID]) do |event, *args|
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
  command(:listboops, channels: [BOT_COMMANDS_CHANNEL_ID, MODERATION_CHANNEL_CHANNEL_ID]) do |event, *args|
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
  command(:hug, channels: [BOT_COMMANDS_CHANNEL_ID, MODERATION_CHANNEL_CHANNEL_ID, VENT_SPACE_CHANNEL_ID, GENERAL_CHANNEL_ID]) do |_event, *args|
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
end