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

  # TODO: FINISH THIS! It's very incomplete
  bot.command(:birthday, channels: %w(#bot_commands #moderation_channel)) do |event, *args|
    # If the first argument is set and the birthday date format is valid:
    if args.size >= 2 &&
       args[0].downcase == 'set' &&
       vali_date(args[1])
      # If user is a moderator setting another user's birthday and user is valid
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
          birthdays[event.user.id] = vali_date(args[1].join('/'))
        end

        # Sends confirmation message to event channel
        "#{event.user.mention}, your birthday has been set as **#{vali_date(args[1].join('/')}**."
      end
    elsif args[0].downcase == 'set' && event.user.role?(302641262240989186) && (args[1].split('/').size == 2 && args[1].split('/')[0].to_i > 0 && args[1].split('/')[1].to_i > 0) && bot.get_user(args[2..-1].join(' '))
      user = bot.get_user(args[2..-1].join(' '))
      time = Time.new(2018, args[1].split('/')[0], args[1].split('/')[1])
      birthdays[user.id] = time.strftime('%m/%d')
      "This user's birthday has been set as **#{time.strftime('%B %-d')}**."
    elsif args[0].downcase == 'check' && bot.get_user(args[1..-1].join(' '))
      user = bot.get_user(args[1..-1].join(' '))
      if birthdays[user.id]
        event.channel.send_embed do |embed|
          embed.author = {name: "USER: #{user.on(SERVER).display_name} (#{user.distinct})", icon_url: user.avatar_url}
          embed.description = "#{user.mention}'s birthday is **#{Time.utc(2018, birthdays[user.id].split('/')[0], birthdays[user.id].split('/')[1]).strftime('%B %-d')}**."
          embed.color = 0xFFD700
        end
      else
        event.channel.send_temporary_message('This user has not set their birthday.', 5)
      end
    elsif args[0].downcase == 'next'
      later_birthdays = birthdays.select { |_id, b| b.split('/').join.to_i > Time.utc(Time.now.getgm.year,Time.now.getgm.month,Time.now.getgm.day, 0,05,00).strftime('%m%d').to_i }.sort_by { |_id, b| b.split('/').join.to_i }
      next_birthdays = later_birthdays.select { |_id, b| b == later_birthdays[0][1] }
      event.channel.send_embed do |embed|
        embed.author = {name: 'Birthdays: Next', icon_url: 'https://cdn.discordapp.com/attachments/330586271116165120/427435169826471936/glossaryck_icon.png'}
        embed.description = "**Date:** #{Time.utc(2018, next_birthdays[0][1].split('/')[0], next_birthdays[0][1].split('/')[1]).strftime('%B %-d')}\n\n#{next_birthdays.map { |id, _b| SERVER.member(id) ? "**• #{SERVER.member(id).display_name} (#{bot.user(id).distinct})**" : "**• ID: #{id}**" }.join("\n")}"
        embed.color = 0xFFD700
      end
    elsif args[0].downcase == 'delete' && event.user.role?(302641262240989186) && bot.get_user(args[1..-1].join(' '))
      birthdays.delete(bot.get_user(args[1..-1].join(' ')).id)
      "This user's birthday has been deleted."
    end
  end
end