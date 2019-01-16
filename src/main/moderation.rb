# Crystal: Moderation
require 'rufus-scheduler'
ENV['TZ'] = 'GMT'
require 'securerandom'


# This crystal contains Cobalt's moderation commands, such as punishment, mute, banning, and
# channel blocking.
module Bot::Moderation
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  # Scheduler constant
  SCHEDULER = Rufus::Scheduler.new
  # Path to crystal's data folder
  MOD_DATA_PATH = "#{Bot::DATA_PATH}/moderation".freeze
  # Value for two weeks of time in seconds
  TWO_WEEKS = 1209600
  # Muted role ID
  MUTED_ID = 307755803128102914
  # Head Creator role ID
  HEAD_CREATOR_ID = 338673551445852162
  # IDs of all opt-in roles
  OPT_IN_ROLES = [
    382433569101971456,
    310698748680601611,
    316353444971544577,
    402051258732773377,
    454304307425181696
  ].freeze
  # Bounce Lounge bot ID
  BOUNCE_LOUNGE_ID = 309018929584537602
  # #welcome channel ID
  WELCOME_ID = 339122866446401537
  # #bot_commands channel ID
  BOT_COMMANDS_ID = 307726225458331649
  # #muted_users channel ID
  MUTED_USERS_ID = 308065793906704384
  # #moderation_channel channel ID
  MODERATION_CHANNEL_ID = 330586271116165120
  # #head_creator_hq channel ID
  HEAD_CREATOR_HQ_ID = 338689508046274561
  # #cobalt_reports channel ID
  COBALT_REPORTS_ID = 307755696198385666
  # #bot_games channel ID
  BOT_GAMES_ID = 402050178753757185
  # Defines a bucket for the spam filter; triggers if user sends 5 or more messages in 4 seconds
  SPAM_FILTER_BUCKET = Bot::BOT.bucket(
      :spam_filter,
      limit: 4,
      time_span: 4
  )


  # Array used to track when Head Creators are punishing; required so they are able to
  # (indirectly) execute the mute or ban commands
  head_creator_punishing = Array.new
  # Hash that stores Rufus job ID for each mute; this stores both user and channel mutes as
  # users and channels can never share IDs anyway
  mute_jobs = Hash.new
  # Array used to track if a user has triggered the spam filter
  spam_filter_triggered = Array.new


  # Loads mute info from file and schedules Rufus jobs for all entries; as it uses some Discord
  # API methods, it only executes upon receiving READY packet
  ready do
    # Defines variables containing muted users and channels
    muted_users = YAML.load_data! "#{MOD_DATA_PATH}/muted_users.yml"
    muted_channels = YAML.load_data! "#{MOD_DATA_PATH}/muted_channels.yml"

    # Schedules Rufus job to unmute user for all muted users
    muted_users.each do |id, (mute_end_time, reason, user_opt_in_roles)|
      # Skips if user is muted due to being on trial for ban
      next if mute_end_time == :trial

      # Defines user variable
      user = SERVER.member(id)

      # Schedules a Rufus job to unmute the user and stores it in the mute_jobs hash
      mute_jobs[id] = SCHEDULER.schedule_at mute_end_time do
        # Deletes user entry from data file and job hash
        YAML.load_data!("#{MOD_DATA_PATH}/muted_users.yml") do |users|
          users.delete(id)
        end
        mute_jobs.delete(id)

        # Unmutes user by removing Muted role and re-adding Member and opt-in roles
        begin
          user.modify_roles(
            [MEMBER_ID] + user_opt_in_roles, # add Member and opt-in roles
            MUTED_ID, # remove Muted
            "Unmute" # audit log reason
          )
        rescue StandardError => e
          puts "Exception raised when modifying a user's roles -- most likely user left the server"
        end 
      end
    end

    # Schedules Rufus job to unmute channel for all muted channels
    muted_channels.each do |id, (mute_end_time, reason)|
      # Defines channel variable and gets permission object for Member role in channel
      channel = Bot::BOT.channel(id)
      permissions = channel.permission_overwrites[MEMBER_ID]

      # Schedules a Rufus job to unmute the channel and stores it in the mute_jobs hash
      mute_jobs[id] = SCHEDULER.schedule_at mute_end_time do
        # Deletes channel entry from data file and job hash
        YAML.load_data!("#{MOD_DATA_PATH}/muted_channels.yml") do |channels|
          channels.delete(id)
        end
        mute_jobs.delete(id)

        # Neutralizes the permission to send messages for the Member role in the event channel
        permissions.deny.can_send_messages = false
        channel.define_overwrite(
          permissions,
          reason: 'Channel unmute' # audit log reason
        )

        # Sends confirmation message
        channel.send_message('**Channel unmuted.**') # confirmation message sent to event channel
      end
    end
  end


  # 12h cron job that iterates through points data file and removes one point if past decay time,
  # updating file accordingly
  SCHEDULER.cron '0 */12 * * *' do
    YAML.load_data!("#{MOD_DATA_PATH}/points.yml") do |points|
      # Removes one point from all entries where the decay time has passed
      points.each do |id, data|
        # Skips if time does not exist
        next unless data[1]

        # Skips unless current time is greater than decay time
        next unless Time.now > data[1]
        
        # Removes a point and updates decay time
        data[0] -= 1
        data[1] += TWO_WEEKS
      end

      # Deletes all entries where the points have reached 0
      points.delete_if { |_i, d| d[0] == 0 }
    end
  end

  
  # Master punish command; automatically decides punishment based on severity and existing points
  command :punish do |event, *args|
    # Breaks unless user is a moderator or HC, the user being punished is valid, and a reason is given
    break unless (event.user.role?(MODERATOR_ID) ||
                  event.user.role?(HEAD_CREATOR_ID)) &&
                 SERVER.get_user(args[0]) && # valid user
                 args.size >= 2 # reason
    
    # Defines user and reason variables
    user = SERVER.get_user(args[0])
    reason = args[1..-1].join(' ')
    
    # If user is a moderator with full punishment powers:
    if event.user.role?(MODERATOR_ID)
      # Header
      Bot::BOT.send_message(
        MODERATION_CHANNEL_ID, 
        "#{event.user.mention}, **how many points would you like to add to user #{user.display_name} (#{user.distinct})? Guidelines as follows:**\n" +
        "**Minor:** 1-3 points\n" +
        "**Major:** 5-7 points\n" +
        "**Critical:** 10-12 points\n" +
        "**Reply below with your value.** Respond with `cancel` to cancel."
      )

      # Defines variable for points to be added to user; loops until value is valid point value, or 
      # nil if user wants to cancel
      added_points = loop do
        # Creates an await for a message from the event user in the event channel, and defines
        # variable containing the await message's content
        await_event = event.message.await!
        await_content = await_event.message.content

        # If user wants to cancel punishment:
        if await_content.downcase == 'cancel'
          break nil

        # If user enters a valid point value:
        elsif (1..3).include?(await_content.to_i) || # minor punishment
              (5..7).include?(await_content.to_i) || # major punishment
              (10..12).include?(await_content.to_i) # critical punishment
          break await_content.to_i

        # If user enters an invalid point value:
        else
          Bot::BOT.send_message(
            MODERATION_CHANNEL_ID,
            'Not a valid point value.'
          )
        end
      end

    # If user is a Head Creator with only minor punishment powers:
    elsif event.user.role?(HEAD_CREATOR_ID)
      # Header
      Bot::BOT.send_message(
        HEAD_CREATOR_HQ_ID, 
        "#{event.user.mention}, **how many points would you like to add to user #{user.display_name} (#{user.distinct})?**\n" +
        "You can add 1-3 points.\n" +
        "Respond with `cancel` to cancel."
      )

      # Defines variable for points to be added to user; loops until value is valid point value, or 
      # nil if user wants to cancel
      added_points = loop do
        await_event = event.message.await!
        await_content = await_event.message.content
        
        # If user wants to cancel punishment:
        if await_content.downcase == 'cancel'
          break nil

        # If user enters a valid point value:
        elsif (1..3).include?(await_content.to_i) # minor punishment
          head_creator_punishing.push(event.user.id) # tracks this HC, so they are able to punish
          break await_content.to_i

        # If user enters an invalid point value:
        else
          Bot::BOT.send_message(
            HEAD_CREATOR_HQ_ID,
            'Not a valid point value.'
          )
        end
      end
    end

    # If user has entered a point value for the punishment:
    if added_points
      # Loads point data from file, so it can be read and modified
      YAML.load_data!("#{MOD_DATA_PATH}/points.yml") do |points|
        # Defines variable containing user's total points after adding given number of points
        if points.has_key? user.id
          total_points = points[user.id][0] + added_points
        else
          total_points = added_points
        end

        # If a minor punishment was chosen:
        if (1..3).include?(added_points)
          # Tier 1: Warning
          if (0..4).include?(total_points)
            # Sends confirmation message and logs action
            event.send_message( # warning message in event channel
              "#{user.mention}, **you have received a warning for:** #{reason}.\n" +
              "**Points have been added to your server score. Repeated infractions will lead to harsher punishments.**"
            )
            Bot::BOT.channel(COBALT_REPORTS_ID).send_embed do |embed| # log message
              embed.author = {
                name: "WARNING | User: #{user.display_name} (#{user.distinct})", 
                icon_url: user.avatar_url
              }
              embed.description = "**#{user.mention} given a warning** in channel #{event.channel.mention}.\n" +
                                  "• **Reason:** #{reason}\n" +
                                  "\n" +
                                  "**Warned by:** #{event.user.distinct}"
              embed.thumbnail = {url: 'https://emojipedia-us.s3.amazonaws.com/thumbs/120/twitter/131/heavy-exclamation-mark-symbol_2757.png'}
              embed.color = 0xFFD700
            end

            # Sets user entry in the points variable equal to the new data
            points[user.id] = [
              total_points,
              Time.now + TWO_WEEKS, # decay time
              "Warning - #{reason}"
            ]

          # Tier 2: 30 minute mute
          elsif (5..9).include?(total_points)
            # Executes mute and informs user
            Bot::BOT.execute_command(:mute, event, args.insert(1, '30m'))
            user.dm( # confirmation dm sent to user
              "**#{user.distinct}, you have been muted for 30m.** Your new point total is: **#{total_points}** points.\n" +
              "**Reason:** #{reason}"
            )

            # Sets user entry in the points variable equal to the new data
            points[user.id] = [
              total_points,
              Time.now + TWO_WEEKS, # decay time
              "30m mute - #{reason}"
            ]

          # Tier 3: 1 hour mute
          elsif (10..14).include?(total_points)
            # Executes mute and informs user
            Bot::BOT.execute_command(:mute, event, args.insert(1, '1h'))
            user.dm( # confirmation dm sent to user
              "**#{user.distinct}, you have been muted for 1h.** Your new point total is: **#{total_points}** points.\n" +
              "**Reason:** #{reason}"
            )

            # Sets user entry in the points variable equal to the new data
            points[user.id] = [
              total_points,
              Time.now + TWO_WEEKS, # decay time
              "1h mute - #{reason}"
            ]

          # Tier 4: 2 hour mute
          elsif (15..19).include?(total_points)
            # Executes mute and informs user
            Bot::BOT.execute_command(:mute, event, args.insert(1, '2h'))
            user.dm( # confirmation dm sent to user
              "**#{user.distinct}, you have been muted for 2h.** Your new point total is: **#{total_points}** points.\n" +
              "**Reason:** #{reason}"
            )

            # Sets user entry in the points variable equal to the new data
            points[user.id] = [
              total_points,
              Time.now + TWO_WEEKS, # decay time
              "2h mute - #{reason}"
            ]

          # Tier 5: Ban
          else
            # Executes ban, informs user and logs action
            user.dm( # confirmation dm sent to user; sent before ban so it doesn't prevent the dm
              "**#{user.distinct}, you have passed the point threshold for a ban.**\n" +
              "**Reason:** #{reason}\n" +
              "\n" +
              "If you would like to appeal your ban, send a DM to an administrator: #{SERVER.role(ADMINISTRATOR_ID).users.map { |u| "**#{u.distinct}**" }.join(', ')}."
            )
            Bot::BOT.execute_command(:ban, event, args) # executes ban command
            Bot::BOT.send_message( # notification message sent in #moderation_channel
              MODERATION_CHANNEL_ID, 
              "@everyone **User #{user.mention} has been #{event.user.role?(ADMINISTRATOR_ID) ? 'banned' : 'put on trial for ban'} after receiving 20 points.**"
            )
          end

        # If a major punishment was chosen:
        elsif (5..7).include?(added_points)
          # Tier 1: 3 hour mute
          if (5..9).include?(total_points)
            # Executes mute and informs user
            Bot::BOT.execute_command(:mute, event, args.insert(1, '3h'))
            user.dm( # confirmation dm sent to user
              "**#{user.distinct}, you have been muted for 3h.** Your new point total is: **#{total_points}** points.\n" +
              "**Reason:** #{reason}"
            )

            # Sets user entry in the points variable equal to the new data
            points[user.id] = [
              total_points,
              Time.now + TWO_WEEKS, # decay time
              "3h mute - #{reason}"
            ]

          # Tier 2: 6 hour mute
          elsif (10..14).include?(total_points)
            # Executes mute and informs user
            Bot::BOT.execute_command(:mute, event, args.insert(1, '6h'))
            user.dm( # confirmation dm sent to user
              "**#{user.distinct}, you have been muted for 6h.** Your new point total is: **#{total_points}** points.\n" +
              "**Reason:** #{reason}"
            )

            # Sets user entry in the points variable equal to the new data
            points[user.id] = [
              total_points,
              Time.now + TWO_WEEKS, # decay time
              "6h mute - #{reason}"
            ]

          # Tier 3: 12 hour mute
          elsif (15..19).include?(total_points)
            # Executes mute and informs user
            Bot::BOT.execute_command(:mute, event, args.insert(1, '3h'))
            user.dm( # confirmation dm sent to user
              "**#{user.distinct}, you have been muted for 3h.** Your new point total is: **#{total_points}** points.\n" +
              "**Reason:** #{reason}"
            )

            # Sets user entry in the points variable equal to the new data
            points[user.id] = [
              total_points,
              Time.now + TWO_WEEKS, # decay time
              "12h mute - #{reason}"
            ]

          # Tier 4: Ban
          else
            # Executes ban, informs user and logs action
            user.dm( # confirmation dm sent to user; sent before ban so it doesn't prevent the dm
              "**#{user.distinct}, you have passed the point threshold for a ban.**\n" +
              "**Reason:** #{reason}\n" +
              "\n" +
              "If you would like to appeal your ban, send a DM to an administrator: #{SERVER.role(ADMINISTRATOR_ID).users.map { |u| "**#{u.distinct}**" }.join(', ')}."
            )
            Bot::BOT.execute_command(:ban, event, args) # executes ban command
            Bot::BOT.send_message( # notification message sent in #moderation_channel
              MODERATION_CHANNEL_ID, 
              "@everyone **User #{user.mention} has been #{event.user.role?(ADMINISTRATOR_ID) ? 'banned' : 'put on trial for ban'} after receiving 20 points.**"
            )
          end

        # If a critical punishment was chosen:
        else
          # Tier 1: 24 hour/1 day mute
          if (10..14).include?(total_points)
            # Executes mute and informs user
            time = %w(24h 1d) # picks one of two different time formats, just for fun
            Bot::BOT.execute_command(:mute, event, args.insert(1, time))
            user.dm( # confirmation dm sent to user
              "**#{user.distinct}, you have been muted for #{time}.** Your new point total is: **#{total_points}** points.\n" +
              "**Reason:** #{reason}"
            )

            # Sets user entry in the points variable equal to the new data
            points[user.id] = [
              total_points,
              Time.now + TWO_WEEKS, # decay time
              "#{time} mute - #{reason}"
            ]

          # Tier 2: 2 day mute
          elsif (15..19).include?(total_points)
            # Executes mute and informs user
            Bot::BOT.execute_command(:mute, event, args.insert(1, '2d'))
            user.dm( # confirmation dm sent to user
              "**#{user.distinct}, you have been muted for 2d.** Your new point total is: **#{total_points}** points.\n" +
              "**Reason:** #{reason}"
            )

            # Sets user entry in the points variable equal to the new data
            points[user.id] = [
              total_points,
              Time.now + TWO_WEEKS, # decay time
              "2d mute - #{reason}"
            ]

          # Tier 3: Ban
          else
            # Executes ban, informs user and logs action
            user.dm( # confirmation dm sent to user; sent before ban so it doesn't prevent the dm
              "**#{user.distinct}, you have passed the point threshold for a ban.**\n" +
              "**Reason:** #{reason}\n" +
              "\n" +
              "If you would like to appeal your ban, send a DM to an administrator: #{SERVER.role(ADMINISTRATOR_ID).users.map { |u| "**#{u.distinct}**" }.join(', ')}."
            )
            Bot::BOT.execute_command(:ban, event, args) # executes ban command
            Bot::BOT.send_message( # notification message sent in #moderation_channel
              MODERATION_CHANNEL_ID, 
              "@everyone **User #{user.mention} has been #{event.user.role?(ADMINISTRATOR_ID) ? 'banned' : 'put on trial for ban'} after receiving 20 points.**"
            )
          end
        end

        # Untracks user if they were a Head Creator punishing
        head_creator_punishing.delete(event.user.id)
      end

    # If user canceled punishment:
    else
      # Sends cancellation message to channel dependent on whether they are staff or a HC
      if event.user.role?(MODERATOR_ID)
        Bot::BOT.send_message(
          MODERATION_CHANNEL_ID,
          '**The punishment has been canceled.**'
        )
      elsif event.user.role?(HEAD_CREATOR_ID)
        Bot::BOT.send_message(
          HEAD_CREATOR_HQ_ID,
          '**The punishment has been canceled.**'
        )  
      end
    end

    nil # returns nil so command doesn't send an extra message
  end


  # Command to check points; usable by user in #bot_commands for their own points 
  # or staff in #moderation_channel to get anyone's
  command :points do |event, *args|
    # If user is using command in #bot_commands:
    if event.channel.id == BOT_COMMANDS_ID
      # Defines variable containing user points; set to 0 if no user entry is found in points data
      points = YAML.load_data! "#{MOD_DATA_PATH}/points.yml"
      user_points = points[event.user.id] ? points[event.user.id][0] : 0

      # Sends dm to user
      event.user.dm(
        "**#{event.user.distinct}, you have: #{user_points} points.**\n" +
        "*This is an automated message. Do not reply.*"
      )

    # If user is a moderator and using the command in #moderation_channel:
    elsif event.user.role?(MODERATOR_ID) && event.channel.id == MODERATION_CHANNEL_ID
      # +points without arguments, returns text file of all points
      if args.empty?
        # Loads data from file into variable, and formats into array of strings
        points = YAML.load_data! "#{MOD_DATA_PATH}/points.txt"
        formatted_points = points.map do |id, (user_points, next_decay, reason)|
          # Skips unless user exists in server (has not left it)
          next unless SERVER.get_user(id)

          "#{SERVER.get_user(id).distinct} • Points: #{user_points}\n" +
          "Last punishment: #{reason}\n" +
          "Date of next decay: #{next_decay.strftime('%B %-d, %Y')}"
        end.compact

        # Joins the array of formatted strings and writes it to file
        f = File.open("#{MOD_DATA_PATH}/points.txt", 'w')
        f.write(
          "All user points:\n" +
          "\n" +
          points_text.join("\n--------------------\n")
        )
        f.close

        # Uploads file
        event.channel.send_file(
          File.open("#{MOD_DATA_PATH}/points.txt"), 
          caption: "**All users' points:**"
        )

      # +points with arguments
      else
        # Adding points to user
        if args[0].downcase == 'add' &&
           args.size >= 3 && # ensures point value and user are present
           args[1].to_i > 0 && # ensures at least 1 point is to be added
           SERVER.get_user(args[2..-1].join(' '))
          
          # Defines user variable and points to be added
          user = SERVER.get_user(args[2..-1].join(' '))
          added_points = args[1].to_i

          # Loads points data from file to be accessed and modified
          YAML.load_data!("#{MOD_DATA_PATH}/points.yml") do |points|
            # Updates point data, and sets decay time and reason if user doesn't already have points
            if points[user.id]
              points[user.id][0] += added_points
            else
              points[user.id] = [
                added_points, 
                Time.now + TWO_WEEKS, # decay time
                'N/A - Points added manually' # reason
              ]
            end

            # Sends confirmation message and dms user
            event.send_message "**Added #{added_points} point#{added_points > 1 ? 's' : nil} to user #{user.distinct}.**" # confirmation message sent to event channel
            user.pm "**#{user.distinct}, a moderator has added some points to you.** You now have **#{points[user.id][0]} point#{points[user.id][0] == 1 ? nil : 's'}**." # notification dm sent to user
          end

        # Removing points from user
        elsif args[0].downcase == 'remove' &&
              args.size >= 3 && # ensures 'add' arg, point value and user are present
              args[1].to_i > 0 && # ensures points to add is valid
              SERVER.get_user(args[2..-1].join(' '))

          # Defines user variable and points to be added
          user = SERVER.get_user(args[2..-1].join(' '))
          removed_points = args[1].to_i

          # Loads points data from file to be accessed and modified
          YAML.load_data!("#{MOD_DATA_PATH}/points.yml") do |points|
            next unless points[user.id] # skips if user does not already have points

            # Updates point data  
            points[user.id][0] -= removed_points
            points[user.id][0] = 0 if points[user.id][0] < 0

            # Sends confirmation message and dms user
            event.send_message "**Removed #{removed_points} point#{removed_points > 1 ? 's' : nil} from user #{user.distinct}.**" # confirmation message
            user.pm "**#{user.distinct}, a moderator has removed some points from you.** You now have **#{points[user.id][0]} point#{points[user.id][0] == 1 ? nil : 's'}**." # notification pm

            # Deletes entry if user now has 0 points
            points.delete_if { |_id, d| d[0] == 0 }
          end

        # Checking points of a user
        elsif SERVER.get_user(args.join(' '))
          # Defines variables for user, their points, time object of their next decay, and last punishment reason
          user = SERVER.get_user(args.join(' '))
          if YAML.load_data!("#{MOD_DATA_PATH}/points.yml").has_key?(user.id)
            points, next_decay, reason = YAML.load_data!("#{MOD_DATA_PATH}/points.yml")[user.id]
          else
            points = 0
            next_decay = nil
            reason = 'N/A'
          end

          # Sends embed containing this info
          event.send_embed do |embed|
            embed.author = {
              name: "POINTS | User: #{user.display_name} (#{user.distinct})", 
              icon_url: user.avatar_url
            }
            embed.description = "**Points:** #{points}\n" +
                                "**Last punishment:** #{reason}\n" +
                                "**Date of next decay:** #{next_decay ? next_decay.strftime('%B %-d, %Y') : 'N/A'}"
            embed.color = 0xFFD700
          end
        end
      end
    end

    nil # returns nil so command doesn't send an extra message
  end


  # Mutes user or channel
  command :mute do |event, *args|
    # Breaks unless user is a moderator or a Head Creator punishing through +punish, the first
    # argument is a valid user or 'channel' exactly, and the mute length is a valid length of time
    break unless (event.user.role?(MODERATOR_ID) ||
                  head_creator_punishing.include?(event.user.id)) &&
                 args.size >= 2 &&
                 (SERVER.get_user(args[0]) || args[0] == 'channel') &&  # user or channel
                 args[1].to_sec > 0 # valid length of time

    # Defines the time at which the mute ends
    mute_end_time = Time.now.getgm + args[1].to_sec

    # If user is muting a channel:
    if args[0] == 'channel' # preferred to muting user, so users can't nickname themselves 'channel'
      # Breaks if no reason is given
      break unless args.size >= 3

      # Defines channel variable, reason for mute, and the Member role's 
      # permissions in the event channel
      channel = event.channel
      reason = args[2..-1].join(' ')
      permissions = channel.permission_overwrites[MEMBER_ID] || Discordrb::Overwrite.new(MEMBER_ID, type: :role)

      # Denies the permission to send messages for the Member role in the event channel
      permissions.allow.can_send_messages = false
      permissions.deny.can_send_messages = true
      channel.define_overwrite(
        permissions,
        reason: "Channel mute -- reason: #{reason}" # audit log reason
      )

      # Sends confirmation message and logs action
      channel.send_message( # confirmation message sent to event channel
        "**Muted channel for #{args[1].scan(/[1-9]\d*[smhd]/i).join}.**\n" +
        "**Reason:** #{reason}", 
        false, # tts
        {image: {url: 'http://i67.tinypic.com/30moi1g.gif'}}
      )
      Bot::BOT.send_message( # log message
        COBALT_REPORTS_ID,
        ":x: **CHANNEL MUTE**\n" + 
        "**#{event.user.distinct}:** Muted #{channel.mention} for **#{args[1].scan(/[1-9]\d*[smhd]/i).join}**.\n" + 
        "**Reason:** #{reason}"
      )

      # Stores mute info in the muted_channels data file
      YAML.load_data!("#{MOD_DATA_PATH}/muted_channels.yml") do |channels|
        channels[channel.id] = [mute_end_time, reason]
      end

      # Schedules a Rufus job to unmute the channel and stores it in the mute_jobs hash,
      # unscheduling any previous mutes on this channel
      mute_jobs[channel.id].unschedule if mute_jobs[channel.id]
      mute_jobs[channel.id] = SCHEDULER.schedule_at mute_end_time do
        # Deletes channel entry from data file and job hash
        YAML.load_data!("#{MOD_DATA_PATH}/muted_channels.yml") do |channels|
          channels.delete(channel.id)
        end
        mute_jobs.delete(channel.id)

        # Neutralizes the permission to send messages for the Member role in the event channel
        permissions.deny.can_send_messages = false
        channel.define_overwrite(
          permissions,
          reason: 'Channel unmute' # audit log reason
        )

        # Sends confirmation message
        channel.send_message('**Channel unmuted.**') # confirmation message sent to event channel
      end
    
    # If user is muting another user:
    else
      # Breaks if mute length is 10 minutes or higher without a given reason
      break if args[1].to_sec >= 600 && 
               args.size < 3 # reason
      
      # Defines the length of the mute in seconds, the user being muted, the reason for mute,
      # and an array of IDs of opt-in role that the user has
      mute_length = args[1].to_sec
      user = SERVER.get_user(args[0])
      reason = args[1].to_sec >= 600 ? args[2..-1].join(' ') : 'N/A'
      user_opt_in_roles = OPT_IN_ROLES.select { |id| user.role?(id) }

      # Mutes user by adding Muted role and removing Member and opt-in roles
      user.modify_roles(
        MUTED_ID, # add Muted
        [MEMBER_ID] + user_opt_in_roles, # remove Member and opt-in roles
        "Mute -- reason: #{reason}" # audit log reason
      )

      # If the mute length is less than 10 minutes:
      if mute_length < 600
        # Sends only confirmation message
        event.send_message( # confirmation message sent to event channel
          "**Muted #{user.distinct} for #{args[1].scan(/[1-9]\d*[smhd]/i).join}.**", 
          false, # tts
          {image: {url: 'http://i67.tinypic.com/30moi1g.gif'}}
        )

      # If the mute length is between 10 and 30 minutes
      # Note: This is inclusive of 10 minutes, but exclusive of 30 minutes
      elsif (600...1800).include? mute_length
        # Sends confirmation message and simpler log message (no identifier or embed)
        event.send_message( # confirmation message sent to event channel
          "**Muted #{user.display_name} for #{args[1].scan(/[1-9]\d*[smhd]/i).join}.**\n" +
          "**Reason:** #{reason}", 
          false, # tts
          {image: {url: 'http://i67.tinypic.com/30moi1g.gif'}}
        )
        Bot::BOT.send_message( # log message
          COBALT_REPORTS_ID, 
          ":mute: **MUTE**\n" +
          "**#{event.user.distinct}: Muted #{user.mention} for #{args[1].scan(/[1-9]\d*[smhd]/i).join}** in channel #{event.channel.mention}\n" +
          "**Reason:** #{reason}"
        )

      # If the mute length is 30 minutes or above:
      else
        # Sends confirmation message and full log message
        identifier = SecureRandom.hex(4)
        event.send_message( # confirmation message with identifier sent to event channel
          "• **ID**`#{identifier}`\n" +
          "**Muted #{user.display_name} for #{args[1].scan(/[1-9]\d*[smhd]/i).join}.**\n" +
          "**Reason:** #{reason}", 
          false, # tts
          {image: {url: 'http://i67.tinypic.com/30moi1g.gif'}}
        )
        Bot::BOT.send_message( # full log message with identifier
          COBALT_REPORTS_ID, 
          "**ID:** `#{identifier}`", 
          false, # tts
          {
            author: {
              name: "MUTE | User: #{user.display_name} (#{user.distinct})", 
              icon_url: user.avatar_url
            },
            description: "**#{user.mention} muted for #{args[1].scan(/[1-9]\d*[smhd]/i).join}** in channel #{event.channel.mention}.\n" +
                         "• **Reason:** #{reason}\n" +
                         "\n" +
                         "**Muted by:** #{event.user.distinct}",
            thumbnail: {url: 'https://emojipedia-us.s3.amazonaws.com/thumbs/160/twitter/103/speaker-with-cancellation-stroke_1f507.png'},
            color: 0xFFD700
          }
        )
      end

      # Stores mute info in muted_users data file
      YAML.load_data!("#{MOD_DATA_PATH}/muted_users.yml") do |users|
        users[user.id] = [mute_end_time, reason, user_opt_in_roles]
      end

      # Schedules a Rufus job to unmute the user and stores it in the mute_jobs hash,
      # unscheduling any previous mutes on this user
      mute_jobs[user.id].unschedule if mute_jobs[user.id]
      mute_jobs[user.id] = SCHEDULER.schedule_at mute_end_time do
        # Deletes user entry from data file and job hash
        YAML.load_data!("#{MOD_DATA_PATH}/muted_users.yml") do |users|
          users.delete(user.id)
        end
        mute_jobs.delete(user.id)

        # Unmutes user by removing Muted role and re-adding Member and opt-in roles
        begin
          user.modify_roles(
            [MEMBER_ID] + user_opt_in_roles, # add Member and opt-in roles
            MUTED_ID, # remove Muted
            "Unmute" # audit log reason
          )
        rescue StandardError => e
          puts "Exception raised when modifying a user's roles -- most likely user left the server"
        end 
      end
    end

    nil # returns nil so command doesn't send an extra message
  end


  # Unmutes user or channel
  command :unmute do |event, *args|
    # Breaks unless user is a moderator and the first argument is a valid user or 'channel' exactly
    break unless event.user.role?(MODERATOR_ID) &&
                 args.size >= 1 &&
                 (SERVER.get_user(args.join(' ')) || args[0] == 'channel')
    
    # If user is unmuting a channel:
    if args[0] == 'channel' # preferred to unmuting user, so users can't nickname themselves 'channel'
      # Breaks unless the channel is muted
      break unless YAML.load_data!("#{MOD_DATA_PATH}/muted_channels.yml").has_key? event.channel.id

      # Defines channel variable and the Member role's permissions in the event channel
      channel = event.channel
      if channel.permission_overwrites[MEMBER_ID]
        permissions = channel.permission_overwrites[MEMBER_ID] # gets initial permission overwrite object of Member role for channel
      else
        permissions = Discordrb::Overwrite.new(MEMBER_ID, type: :role) # initializes empty permission overwrite object of Member role for channel
      end

      # Unschedules unmute job and deletes channel entry from data file and job hash
      mute_jobs[channel.id].unschedule
      YAML.load_data!("#{MOD_DATA_PATH}/muted_channels.yml") do |channels|
        channels.delete(channel.id)
      end
      mute_jobs.delete(channel.id)

      # Neutralizes the permission to send messages for the Member role in the event channel
      permissions.deny.can_send_messages = false
      channel.define_overwrite(
        permissions,
        reason: 'Channel unmute' # audit log reason
      )

      # Sends confirmation message
      channel.send_message('**Channel unmuted.**') # confirmation message sent to event channel
    
    # If user is unmuting another user:
    else
      # Breaks unless the user is muted
      break unless YAML.load_data!("#{MOD_DATA_PATH}/muted_users.yml").has_key? SERVER.get_user(args.join(' ')).id

      # If user is muted due to being on trial for a ban:
      if YAML.load_data!("#{MOD_DATA_PATH}/muted_users.yml")[SERVER.get_user(args.join(' ')).id][0] == :trial
        event.send_message 'That user is on trial for ban and cannot be unmuted.'
        break
      end

      # Defines user variable and array of IDs of user's opt-in roles
      user = SERVER.get_user(args.join(' '))
      user_opt_in_roles = YAML.load_data!("#{MOD_DATA_PATH}/muted_users.yml")[user.id][2]
      
      # Unschedules unmute job and deletes user entry from data file and job hash
      mute_jobs[user.id].unschedule # unschedules unmute job
      YAML.load_data!("#{MOD_DATA_PATH}/muted_users.yml") do |users|
        users.delete(user.id)
      end
      mute_jobs.delete(user.id)

      # Unmutes user by removing Muted role and re-adding Member and opt-in roles
      user.modify_roles(
        [MEMBER_ID] + user_opt_in_roles, # add Member and opt-in roles
        MUTED_ID, # remove Muted
        "Unmute" # audit log reason
      )

      # Sends confirmation message
      event.send_message('**Unmuted this user.**') # confirmation message sent to event channel
    end

    nil # returns nil so command doesn't send an extra message
  end


  # Displays muted users or channels
  command :muted, channels: [MODERATION_CHANNEL_ID, MUTED_USERS_ID] do |event, arg = 'users'|
    # If user wants to display muted users:
    if arg.downcase == 'users'
      # Defines variable containing data from data file
      muted = YAML.load_data!("#{MOD_DATA_PATH}/muted_users.yml")
      
      # If no users are muted:
      if muted.empty?
        event.send_message 'No users are muted.' 
      
      # If users are muted:
      else
        # Sends embed displaying info of all muted users
        event.send_embed do |embed|
          embed.author = {
            name: 'Muted: Users', 
            icon_url: 'https://cdn.discordapp.com/attachments/330586271116165120/427435169826471936/glossaryck_icon.png'
          }
          embed.color = 0xFFD700

          # Iterates through every muted user and adds field for each
          muted.each do |id, (mute_end_time, reason, _user_opt_in_roles)|
            # Defines user variable and string displaying how much time is left in user's mute
            user = SERVER.get_user(id.to_s)
            if mute_end_time == :trial
              time_remaining = 'On trial for ban.'
            else
              time_remaining = (mute_end_time - Time.now).round.to_dhms
            end
            
            # Adds field to embed with the muted user and their info
            embed.add_field(
              name: user ? user.distinct : "ID: #{id}", 
              value: "**Time remaining:** #{time_remaining}\n" + 
                     "**Reason:** #{reason}", 
              inline: true
            )
          end
        end
      end
    
    # If user wants to display muted channels:
    elsif arg.downcase == 'channels'
      # Defines variable containing data from data file
      muted = YAML.load_data! "#{MOD_DATA_PATH}/muted_channels.yml"
      
      # If no channels are muted:
      if muted.empty?
        event.send_message 'No channels are muted.' 

      # If channels are muted
      else
        event.send_embed do |embed|
          embed.author = {
            name: 'Muted: Users', 
            icon_url: 'https://cdn.discordapp.com/attachments/330586271116165120/427435169826471936/glossaryck_icon.png'
          }
          embed.color = 0xFFD700

          # Iterates through every muted channel and adds field for each
          muted.each do |id, (mute_end_time, reason)|
            # Adds field to embed with the muted channel and their info
            embed.add_field(
              name: "##{Bot::BOT.channel(id).name}", 
              value: "**Time remaining:** #{(mute_end_time - Time.now).round.to_dhms}\n" +
                     "**Reason:** #{reason}", 
              inline: true
            )
          end
        end
      end
    end

    nil # returns nil so command doesn't send an extra message
  end


  # Bans user; works differently for administrators and moderators. Administrators can ban
  # immediately, while moderators must have approval from another staff member
  command :ban do |event, *args|
    # If user wants to ban brum:
    if args[0] == 'brum'
      event.respond [0x1F44C].pack('U*')
      break
    end

    # Breaks unless user is either a moderator or a punishing Head Creator, a valid user and reason is given
    break unless (event.user.role?(MODERATOR_ID) ||
                  head_creator_punishing.include?(event.user.id)) &&
                 args.size >= 2 &&
                 SERVER.get_user(args[0])
    
    # Defines user and reason variable
    user = SERVER.get_user(args[0])
    reason = args[1..-1].join(' ')

    # Prompts user for how many days of messages from the user that should be deleted, and defines
    # variable for it
    event.send_message "**#{event.user.mention}, how many days of messages would you like to delete?**\n" +
                       "Replying without a number defaults to 0."
    response = event.message.await!
    ban_days = response.message.content.to_i

    # Unschedules mute job and deletes from hash if user is currently muted
    if YAML.load_data!("#{MOD_DATA_PATH}/muted_users.yml").has_key? user.id
      mute_jobs[user.id].unschedule
      mute_jobs.delete(user.id)  
    end

    # If user is an administrator, and can immediately ban:
    if event.user.role?(ADMINISTRATOR_ID) # administrator is preferred as administrators also have moderator role
      # Deletes user entry from mute data file
      YAML.load_data!("#{MOD_DATA_PATH}/muted_users.yml") do |users|
        users.delete(user.id)
      end

      # Bans user
      SERVER.ban(
        user, ban_days,
        reason: "Ban -- reason: #{reason} (#{ban_days} days of messages deleted)" # audit log reason
      )

      # Deletes user entry from points data file
      YAML.load_data!("#{MOD_DATA_PATH}/points.yml") do |points|
        points.delete(user.id)
      end

      # Sends confirmation message and logs action
      identifier = SecureRandom.hex(4)
      event.send_message( # confirmation message with identifier sent to event channel
        "• **ID** `#{identifier}`\n" + 
        "**User #{user.distinct} banned from server.**\n" +
        "• **Reason:** #{reason}", 
        false, # tts
        {image: {url: 'http://i67.tinypic.com/30moi1g.gif'}}
      )
      Bot::BOT.send_message( # log message with identifier
        COBALT_REPORTS_ID, 
        "**ID:** `#{identifier}`", 
        false, # tts
        {
          author: {
            name: "BAN | User: #{user.display_name} (#{user.distinct})",
            icon_url: user.avatar_url
          },
          description: "**#{user.mention} banned from server** in channel #{event.channel.mention}. (#{ban_days} days of messages deleted)\n" +
                       "**Reason:** #{reason}" +
                       "\n" +
                       "**Banned by:** #{event.user.distinct}",
          thumbnail: {url: 'https://emojipedia-us.s3.amazonaws.com/thumbs/120/twitter/103/hammer_1f528.png'},
          color: 0xFFD700
        }
      )

    # if user is a moderator or punishing HC, needing a second opinion to ban:
    elsif (event.user.role?(MODERATOR_ID) ||
           head_creator_punishing.include?(event.user.id))
      # Defines array of IDs of user's opt-in roles
      user_opt_in_roles = OPT_IN_ROLES.select { |id| user.role?(id) }
      
      # Mutes user by adding Muted role and removing Member and opt-in roles
      user.modify_roles(
        MUTED_ID, # add Muted
        [MEMBER_ID] + user_opt_in_roles, # remove Member and opt-in roles
        "Mute -- reason: #{reason}" # audit log reason
      )
      YAML.load_data!("#{MOD_DATA_PATH}/muted_users.yml") do |users|
        users[user.id] = [:trial, reason, user_opt_in_roles]
      end

      # Sends confirmation message and logs action, adding approve/deny buttons to log message
      identifier = SecureRandom.hex(4)
      event.send_message( # trial confirmation message with identifier sent to event channel
        "• **ID** `#{identifier}`\n" +
        "**User #{user.distinct} muted and put on trial for ban.**\n" +
        "**Reason:** #{reason}",
        false, # tts
        {image: {url: 'http://i67.tinypic.com/30moi1g.gif'}}
      )
      msg = Bot::BOT.send_message( # trial log message
        COBALT_REPORTS_ID, 
        "@ here **| ID:** `#{identifier}`",
        false, # tts
        {
          author: {
            name: "TRIAL BAN | On Trial: #{user.display_name} (#{user.distinct})",
            icon_url: user.avatar_url
          },
          description: "**#{user.mention} put on trial for ban** in channel #{event.channel.mention}. (#{ban_days} days of messages deleted)\n" +
                       "• **Reason:** #{reason}\n" +
                       "\n" +
                       "**Tried by:** #{event.user.distinct}",
          footer: {text: 'React to this message accordingly with your approval or rejection. Only administrators or the trial filer can veto bans.'},
          thumbnail: {url: 'https://emojipedia-us.s3.amazonaws.com/thumbs/120/twitter/103/hammer_1f528.png'},
          color: 0xFFD700
        }
      )
      msg.react [0x2705].pack('U*') # react with check mark (approval button)
      msg.react [0x274C].pack('U*') # react with x (rejection button)

      # Creates await for button presses, and defines variables containing whether ban was approved 
      # or denied and which user approved/denied it
      approval, second_user = loop do
        # Creates reaction await which detects when one of the buttons has been pressed
        await_event = Bot::BOT.add_await!(
          Discordrb::Events::ReactionAddEvent, # event type
          {channel: COBALT_REPORTS_ID}
        )

        # If approval button is pressed and the user who reacted is not the same user who
        # initiated the trial:
        if await_event.emoji.name == [0x2705].pack('U*') &&
          await_event.user != event.user
          break [true, await_event.user]
        
        # If rejection button is pressed and the user who reacted is either the same user
        # who initiated the trial or an administrator:
        elsif await_event.emoji.name == [0x274C].pack('U*') &&
              (await_event.user == event.user ||
               event.user.role?(ADMINISTRATOR_ID))
          break [false, await_event.user]
        end
      end

      # Removes buttons, so they cannot be pressed
      msg.delete_all_reactions

      # If the ban was approved:
      if approval
        # Bans user
        SERVER.ban(
          user, ban_days,
          reason: "Ban -- reason: #{reason} (#{ban_days} days of messages deleted)" # audit log reason
        )

        # Deletes user entry from mute and points data file
        YAML.load_data!("#{MOD_DATA_PATH}/muted_users.yml") do |muted_users|
          muted_users.delete(user.id)
        end
        YAML.load_data!("#{MOD_DATA_PATH}/points.yml") do |points|
          points.delete(user.id)
        end

        # Edits log message to reflect ban approval
        msg.edit(
          msg.content, # keeps the identifier
          {
            author: {
              name: "TRIAL BAN | Banned User: #{user.display_name} (#{user.distinct})",
              icon_url: user.avatar_url
            },
            description: "**#{user.mention} tried and approved for ban** in channel #{event.channel.mention}. (#{ban_days} days of messages deleted)\n" +
                         "**Reason:** #{reason}\n" +
                         "\n" +
                         "**Approved by:** #{event.user.distinct}, #{second_user.distinct}",
            thumbnail: {url: 'https://emojipedia-us.s3.amazonaws.com/thumbs/120/twitter/103/hammer_1f528.png'},
            color: 0xFFD700
          }
        )
      
      # If the ban was rejected:
      else
        # Unmutes user by removing Muted role and re-adding Member and opt-in roles
        begin
          user.modify_roles(
            [MEMBER_ID] + user_opt_in_roles, # add Member and opt-in roles
            MUTED_ID, # remove Muted
            "Unmute" # audit log reason
          )
        rescue StandardError => e
          puts "Exception raised when modifying a user's roles -- most likely user left the server"
        end

        # Deletes user entry from muted data file
        YAML.load_data!("#{MOD_DATA_PATH}/muted_users.yml") do |users|
          users.delete(user.id)
        end

        # Edits log message to reflect ban rejection
        msg.edit(
          msg.content, # keeps the identifier
          {
            author: {
              name: "TRIAL BAN | User: #{user.display_name} (#{user.distinct})"
            },
            description: "**#{user.mention} tried and denied for ban** in channel #{event.channel.mention}.\n" +
                         "**Reason for trial:** #{reason}\n" +
                         "\n" +
                         "**Filed by:** #{event.user.distinct}\n**Denied by:** #{second_user.distinct}",
            thumbnail: {url: 'https://emojipedia-us.s3.amazonaws.com/thumbs/120/twitter/103/hammer_1f528.png'},
            color: 0xFFD700,
          }
        )
      end
    end

    nil # returns nil so command doesn't send an extra message
  end


  # Blocks user from channel
  command :block do |event, *args|
    # Breaks unless user is a moderator or HC, the user is valid and a reason is given
    break unless (event.user.role?(MODERATOR_ID) ||
                  event.user.role?(HEAD_CREATOR_ID)) &&
                 args.size >= 2 &&
                 SERVER.get_user(args[0])

    # Defines user and reason variables and gets user's permissions in the event channel
    user = SERVER.get_user(args[0])
    reason = args[1..-1].join(' ')
    permissions = event.channel.permission_overwrites[user.id] || Discordrb::Overwrite.new(user)

    # Denies user's perms to read messages in event channel
    permissions.allow.can_read_messages = false
    permissions.deny.can_read_messages = true
    event.channel.define_overwrite(
      permissions,
      reason: "Block -- reason: #{reason}" # audit log reason
    )

    # Updates channel entry in block data file, and user entry in points data file
    YAML.load_data!("#{MOD_DATA_PATH}/channel_blocks.yml") do |blocks|
      blocks.default_proc = proc { |k, v| k[v] = [] } # defines default so if/else isn't needed
      blocks[event.channel.id].push(user.id)
    end
    YAML.load_data!("#{MOD_DATA_PATH}/channel_blocks.yml") do |points|
      if points[user.id]
        points[user.id][0] += 2
        points[user.id][1] = Time.now + TWO_WEEKS
        points[user.id][2] = "Block - #{reason}"
      else
        points[user.id] = [
          2,
          Time.now + TWO_WEEKS,
          "Block - #{reason}"
        ]
      end
    end

    # Sends confirmation message, dms user and logs action
    event.respond( # confirmation message sent to event channel
      "**Blocked #{user.distinct} from channel.**\n" +
      "**Reason:** #{reason}"
    )
    user.dm( # notification dm sent to user
      "**#{user.distinct}, you have been blocked from channel ##{event.channel.name}.** Your new point total is: **#{YAML.load_data!("#{MOD_DATA_PATH}/channel_blocks.yml")[user.id][0]}** points.\n" +
      "**Reason:** #{reason}"
    )
    Bot::BOT.send_message( # log message
      COBALT_REPORTS_ID, 
      ":no_entry: **BLOCK**\n" + 
      "**#{event.user.distinct}: Blocked #{user.mention} from channel #{event.channel.mention}**.\n" +
      "**Reason:** #{reason}\n" +
      "\n" +
      "**2** points have been added to this user."
    )
    
    nil # returns nil so command doesn't send an extra message
  end


  # Unblocks user from channel
  command :unblock do |event, *args|
    # Breaks unless user is moderator or HC and the given user is valid
    break unless (event.user.role?(MODERATOR_ID) ||
                  event.user.role?(HEAD_CREATOR_ID)) &&
                 SERVER.get_user(args.join(' '))
    
    # Defines user variable and gets user's permissions in the event channel
    user = SERVER.get_user(args.join(' '))
    permissions = event.channel.permission_overwrites[user.id]

    # Neutralizes user's perms to read messages in event channel
    permissions.allow.can_read_messages = false
    permissions.deny.can_read_messages = false
    event.channel.define_overwrite(
      permissions,
      reason: "Unblock" # audit log reason
    )

    # Updates channel entry in block data file
    YAML.load_data!("#{MOD_DATA_PATH}/channel_blocks.yml") do |blocks|
      blocks[event.channel.id].delete(event.user.id)
      blocks.delete_if { |_id, u| u.empty? } # deletes channel if array is empty (no users are blocked)
    end

    # Sends confirmation message and logs action
    event.respond "**Unblocked #{user.distinct} from channel.**" # confirmation message sent to event channel
    Bot::BOT.send_message( # log message
      COBALT_REPORTS_ID, 
      ":o: **UNBLOCK**\n" + "
      **#{event.user.distinct}: Unblocked #{user.mention} from channel #{event.channel.mention}**"
    )

    nil # returns nil so command doesn't send an extra message
  end


  # Lists all channel blocks
  command :blocks do |event|
    # Breaks unless user is moderator
    break unless event.user.role(MODERATOR_ID)

    # Defines variable containing data from block data file
    blocks = YAML.load_data! "#{MOD_DATA_PATH}/channel_blocks.yml"

    # Sends embed to channel displaying blocks
    event.send_embed do |embed|
      embed.author = {
        name: 'Channel Blocks', 
        icon_url: 'https://cdn.discordapp.com/attachments/330586271116165120/427435169826471936/glossaryck_icon.png'
      }
      # Iterates through blocks hash, adding field for each channel
      blocks.each do |id, users|
        # Skips unless at least one user blocked from channel is still present on server
        next unless users.any? { |user_id| SERVER.member(user_id) }

        embed.add_field(
          name: "##{Bot::BOT.channel(id).name}",
          value: users.map { |uid| SERVER.member(uid) ? "• **SERVER.member(user_id).distinct**" : nil }.compact.join("\n")
        )
      end
      embed.color = 0xFFD700
    end

    nil # returns nil so command doesn't send an extra message
  end


  # Manages logic when user joins the server
  member_join do |event|
    # Breaks unless the event comes from SVTFOD (i.e. a user has joined SVTFOD)
    next unless event.server == SERVER

    # Defines user variable and loads mute and block data from file
    user = event.user.on(SERVER)
    muted = YAML.load_data! "#{MOD_DATA_PATH}/muted_users.yml"
    blocks = YAML.load_data! "#{MOD_DATA_PATH}/channel_blocks.yml"

    # Denies read message perms for user in #welcome (this is necessary as when the bot is down, 
    # any user that joins is able to talk in #welcome to ask a staff member for the Member role)
    Bot::BOT.channel(WELCOME_ID).define_overwrite(user, 0, 1024) # uses permission bits for simplicity

    # If user entry exists in muted hash, gives user Muted role
    if muted[user.id]
      user.add_role(MUTED_ID)
    
    # Otherwise, schedules  Rufus job to delete user overwrite from #welcome and add Member role after 5m
    else
      SCHEDULER.in '5m' do
        Bot::BOT.channel(WELCOME_ID).delete_overwrite(user)
        user.add_role(MEMBER_ID)
      end
    end
    
    # Denies read message perms for channels user is blocked from, if any
    if blocks.values.any? { |u| u.include? user.id }
      # Defines array containing the IDs of all channels user is blocked from, 
      # and new universal permission object for user
      ids = blocks.keys.select { |id| blocks[id].include? user.id }
      permissions = Discordrb::Overwrite.new(user.id, type: :user)

      # Denies read message permissions for universal object
      permissions.allow.can_read_messages = false
      permissions.deny.can_read_messages = true

      # Iterates through array of channel IDs and edits permissions to deny user from all of them
      ids.each { |id| Bot::BOT.channel(id).define_overwrite(permissions) }
    end
  end


  # Spam protection; deletes messages if user sends too many too fast
  message do |event|
    # Skips unless the channel is not #bot_games and a user has triggered the spam filter
    next unless (event.channel.id != BOT_GAMES_ID) && SPAM_FILTER_BUCKET.rate_limited?(event.user.id)

    # Resets spam filter bucket for user before deleting messages, so it isn't rate limited
    SPAM_FILTER_BUCKET.reset(event.user.id)

    # Gets the user's message history in the event channel and deletes it
    user_messages = event.channel.history(50).select { |m| m.author == event.user }[5]
    event.channel.delete_messages(user_messages)
  end


  # Blacklist; deletes message if it contains a blacklisted word
  message do |event|
    # Skips if message is in #moderation_channel or user is moderator
    next if event.channel.id == MODERATION_CHANNEL_ID || event.user.role?(MODERATOR_ID)

    # Deletes message if any word from the blacklist is present within the message content
    if YAML.load_data!("#{MOD_DATA_PATH}/blacklist.yml").any? { |w| event.message.content.downcase.include? w }
      event.message.delete
    end
  end

  # Prunes messages from channel
  command :prune do |event, arg|
    # Breaks unless user is moderator and the messages to delete is between 2 and 100
    break unless event.user.role?(MODERATOR_ID) &&
                 (2..100).include?(arg.to_i)

    # Deletes calling message, then prunes given number of messages from event channel
    event.message.delete
    event.channel.prune(arg.to_i)

    # Sends temporary confirmation message
    event.send_temporary_message(
      "Deleted **#{arg.to_i}** messages.",
      3 # seconds that the message lasts
    )
  end
end