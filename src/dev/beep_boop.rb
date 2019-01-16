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

  bot.command(:birthday, channels: %w(#bot_commands #moderation_channel)) do |event, *args|
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
          birthdays[SERVER.get_user(args[2..-1].join(' ')).id] = vali_date(args[1].join('/'))
        end

        # Sends confirmation message to event channel
        "This user's birthday has been set as **#{vali_date(args[1].join('/')}**."

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
            SERVER.get_user(args[1..-1].join(' '))
        user = SERVER.get_user(args[1..-1].join(' '))
      # Otherwise, break
      else
        break
      end

      # Load birthday data from file into variable
      birthdays = YAML.load_data!("#{BEEP_DATA_PATH}/birthdays.yml")

      # Send embed containing birthday info if user has an entry in the birthday data file
      if birthdays[user.id]
        event.channel.send_embed do |embed|
          embed.author = {name: "USER: #{user.display_name} (#{user.distinct})", icon_url: user.avatar_url}
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

      # Define variable containing the nearest upcoming birthday(s)
      future_birthdays = birthdays.select { |_id, d| Time.utc(*[2000] + vali_date(d)) > Time.now }.sort_by { |_id, d| Time.utc(*[2000] + vali_date(d)) }
      upcoming_birthdays = future_birthdays.select { |_id, b| b == future_birthdays[0][1] }.to_h

      # Sends embed containing upcoming birthdays
      event.send_embed do |embed|
        embed.author = {
            name: 'Birthdays: Next',
            icon_url: 'https://cdn.discordapp.com/attachments/330586271116165120/427435169826471936/glossaryck_icon.png'
        }
        embed.description = "**On #{Time.utc(*[2000] * vali_date(upcoming_birthdays.values[0])).strftime('%B %-d')}**\n" +
                            "\n" +
                            upcoming_birthdays.keys.reduce do |memo, id| # combines IDs into parsed string of usernames
                              user = SERVER.member(id)
                              next memo unless SERVER.member(id)
                              "\n**• #{user.display_name} (#{user.distinct})**"
                            end
        embed.color = 0xFFD700
      end

    # If user wants to delete a birthday, user is a moderator, given user is valid and has an entry in the birthday
    # file, delete the birthday
    elsif args[0].downcase == 'delete' &&
          event.user.role?(302641262240989186) &&
          SERVER.get_user(args[1..-1].join(' ')) &&
          YAML.load_data!("#{BEEP_DATA_PATH}/birthdays.yml")[SERVER.get_user(args[1..-1].join(' ')).id]
      YAML.load_data!("#{BEEP_DATA_PATH}/birthdays.yml").delete(bot.get_user(args[1..-1].join(' ')).id)
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
end