# Crystal: Moderation
require 'rufus-scheduler'
ENV['TZ'] = 'GMT'
require 'securerandom'


# This crystal contains Cobalt's moderation commands, such as punishment, mute, banning, and
# channel blocking.
module Bot::Moderation
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  extend Convenience
  include Constants

  # Muted users dataset
  MUTED_USERS = DB[:muted_users]
  # Muted channels dataset
  MUTED_CHANNELS = DB[:muted_channels]
  # Points dataset
  POINTS = DB[:points]
  # Channel blocks dataset
  CHANNEL_BLOCKS = DB[:channel_blocks]
  # Path to crystal's data folder
  MOD_DATA_PATH = "#{Bot::DATA_PATH}/moderation".freeze
  # Value for two weeks of time in seconds
  TWO_WEEKS = 1209600
  # IDs of all opt-in roles
  OPT_IN_ROLES = [
    382433569101971456,
    310698748680601611,
    316353444971544577,
    402051258732773377,
    454304307425181696
  ].freeze
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

  # Loads mute info from database and schedules Rufus jobs for all entries; as it uses some Discord
  # API methods, it only executes upon receiving READY packet
  ready do
    # Schedules Rufus job to unmute user for all muted users
    MUTED_USERS.all do |entry|
      # Defines variables for user, mute end time, reason, and user's opt-in roles
      user = SERVER.member(entry[:id])
      mute_end_time = Time.at(entry[:end_time])
      reason = entry[:reason]
      opt_in_roles = entry[:opt_in_roles].split(',')

      # Skips if user is muted due to being on trial for ban
      next if entry[:trial?]

      # Schedules a Rufus job to unmute the user and stores it in the mute_jobs hash
      mute_jobs[user.id] = SCHEDULER.schedule_at mute_end_time do
        # Deletes user entry from database and job hash
        MUTED_USERS.where(id: user.id).delete
        mute_jobs.delete(user.id)

        # Unmutes user by removing Muted role and re-adding Member and opt-in roles
        begin
          user.modify_roles(
            [MEMBER_ROLE_ID] + user_opt_in_roles, # add Member and opt-in roles
            MUTED_ROLE_ID, # remove Muted
            "Unmute" # audit log reason
          )
        rescue StandardError => e
          puts "Exception raised when modifying a user's roles -- most likely user left the server"
        end 
      end
    end

    # Schedules Rufus job to unmute channel for all muted channels
    MUTED_CHANNELS.all do |entry|
      # Defines variables for channel, mute end time, reason, and permissions for Member role in channel
      channel = Bot::BOT.channel(entry[:id])
      mute_end_time = Time.at(entry[:end_time])
      reason = entry[:reason]
      permissions = channel.permission_overwrites[MEMBER_ROLE_ID]

      # Schedules a Rufus job to unmute the channel and stores it in the mute_jobs hash
      mute_jobs[channel.id] = SCHEDULER.schedule_at mute_end_time do
        # Deletes channel entry from database and job hash
        MUTED_CHANNELS.where(id: channel.id).delete
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
    end
  end


  # 12h cron job that selects database entries whose decay time has passed and decreases their points accordingly
  SCHEDULER.cron '0 */12 * * *' do
    # Selects database entries whose decay time has passed
    POINTS.all.select { |e| Time.now.to_i > e[:decay_time] }.each do |entry|
      # Removes a point and updates decay time
      POINTS.where(id: entry[:id]).where(:decay_time).update(
          points:     entry[:points] - 1,
          decay_time: entry[:decay_time] + TWO_WEEKS
      )
    end

    # Removes all database entries whose points have reached 0
    POINTS.where(points: 0).delete
  end

  
  # Master punish command; automatically decides punishment based on severity and existing points
  command :punish do |event, *args|
    # Breaks unless user is a moderator or HC, the user being punished is valid, and a reason is given
    break unless (event.user.role?(MODERATOR_ROLE_ID) ||
                  event.user.role?(HEAD_CREATOR_ROLE_ID)) &&
                 SERVER.get_user(args[0]) && # valid user
                 args.size >= 2 # reason
    
    # Defines user and reason variables
    user = SERVER.get_user(args[0])
    reason = args[1..-1].join(' ')
    
    # If user is a moderator with full punishment powers:
    if event.user.role?(MODERATOR_ROLE_ID)
      # Sends header
      Bot::BOT.send_message(
        MODERATION_CHANNEL_CHANNEL_ID, 
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
        await_event = event.user.await!(in: MODERATION_CHANNEL_CHANNEL_ID)
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
            MODERATION_CHANNEL_CHANNEL_ID,
            'Not a valid point value.'
          )
        end
      end

    # If user is a Head Creator with only minor punishment powers:
    elsif event.user.role?(HEAD_CREATOR_ROLE_ID)
      # Header
      Bot::BOT.send_message(
        HEAD_CREATOR_HQ_CHANNEL_ID, 
        "#{event.user.mention}, **how many points would you like to add to user #{user.display_name} (#{user.distinct})?**\n" +
        "You can add 1-3 points.\n" +
        "Respond with `cancel` to cancel."
      )

      # Defines variable for points to be added to user; loops until value is valid point value, or 
      # nil if user wants to cancel
      added_points = loop do
        await_event = event.user.await!(channel: HEAD_CREATOR_HQ_CHANNEL_ID)
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
            HEAD_CREATOR_HQ_CHANNEL_ID,
            'Not a valid point value.'
          )
        end
      end
    end

    # If user has entered a point value for the punishment:
    if added_points
      # Defines variable containing user's total points after adding given number of points
      if POINTS[id: user.id]
        total_points = POINTS[id: user.id][:points] + added_points
      else
        total_points = added_points
      end

      # If a minor punishment was chosen:
      if (1..3).include?(added_points)
        # Tier 1: Warning
        if (0..4).include?(total_points)
          # Sends confirmation message to event channel
          event.respond(
              "#{user.mention}, **you have received a warning for:** #{reason}.\n" +
              "**Points have been added to your server score. Repeated infractions will lead to harsher punishments.**"
          )

          # Sends log message to log channel
          Bot::BOT.channel(COBALT_REPORT_CHANNEL_ID).send_embed do |embed|
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

          # Updates database with the new data
          POINTS.set_new(
              {id: user.id},
              points:     total_points,
              decay_time: (Time.now + TWO_WEEKS).to_i,
              reason:     "Warning - #{reason}"
          )

        # Tier 2: 30 minute mute
        elsif (5..9).include?(total_points)
          # Executes mute
          Bot::BOT.execute_command(:mute, event, args.insert(1, '30m'))

          # Sends notification DM to user
          user.dm(
              "**#{user.distinct}, you have been muted for 30 minutes.** Your new point total is: **#{total_points}** points.\n" +
              "**Reason:** #{reason}"
          )

          # Updates database with the new data
          POINTS.set_new(
              {id: user.id},
              points:     total_points,
              decay_time: (Time.now + TWO_WEEKS).to_i,
              reason:     "30m mute - #{reason}"
          )

        # Tier 3: 1 hour mute
        elsif (10..14).include?(total_points)
          # Executes mute
          Bot::BOT.execute_command(:mute, event, args.insert(1, '1h'))

          # Sends notification DM to user
          user.dm(
              "**#{user.distinct}, you have been muted for 1 hour.** Your new point total is: **#{total_points}** points.\n" +
              "**Reason:** #{reason}"
          )

          # Updates database with the new data
          POINTS.set_new(
              {id: user.id},
              points:     total_points,
              decay_time: (Time.now + TWO_WEEKS).to_i,
              reason:     "1h mute - #{reason}"
          )

        # Tier 4: 2 hour mute
        elsif (15..19).include?(total_points)
          # Executes mute
          Bot::BOT.execute_command(:mute, event, args.insert(1, '2h'))

          # Sends notification DM to user
          user.dm(
              "**#{user.distinct}, you have been muted for 2 hours.** Your new point total is: **#{total_points}** points.\n" +
              "**Reason:** #{reason}"
          )

          # Updates database with the new data
          POINTS.set_new(
              {id: user.id},
              points:     total_points,
              decay_time: (Time.now + TWO_WEEKS).to_i,
              reason:     "2h mute - #{reason}"
          )

        # Tier 5: Ban
        else
          # Sends notification DM to user (sent before the ban so the bot can still DM the user)
          user.dm(
              "**#{user.distinct}, you have passed the point threshold for a ban.**\n" +
              "**Reason:** #{reason}\n" +
              "\n" +
              "If you would like to appeal your ban, send a DM to an administrator: #{SERVER.role(ADMINISTRATOR_ROLE_ID).users.map { |u| "**#{u.distinct}**" }.join(', ')}."
          )

          # Executes ban
          Bot::BOT.execute_command(:ban, event, args)

          # Sends notification message to moderation channel
          Bot::BOT.send_message(
              MODERATION_CHANNEL_CHANNEL_ID, 
              "@everyone **User #{user.mention} has been #{event.user.role?(ADMINISTRATOR_ROLE_ID) ? 'banned' : 'put on trial for ban'} after receiving 20 points.**"
          )
        end

      # If a major punishment was chosen:
      elsif (5..7).include?(added_points)
        # Tier 1: 3 hour mute
        if (5..9).include?(total_points)
          # Executes mute
          Bot::BOT.execute_command(:mute, event, args.insert(1, '3h'))

          # Sends notification DM to user
          user.dm(
              "**#{user.distinct}, you have been muted for 3 hours.** Your new point total is: **#{total_points}** points.\n" +
              "**Reason:** #{reason}"
          )

          # Updates database with the new data
          POINTS.set_new(
              {id: user.id},
              points:     total_points,
              decay_time: (Time.now + TWO_WEEKS).to_i,
              reason:     "3h mute - #{reason}"
          )

        # Tier 2: 6 hour mute
        elsif (10..14).include?(total_points)
          # Executes mute
          Bot::BOT.execute_command(:mute, event, args.insert(1, '6h'))

          # Sends notification DM to user
          user.dm(
              "**#{user.distinct}, you have been muted for 6 hours.** Your new point total is: **#{total_points}** points.\n" +
              "**Reason:** #{reason}"
          )

          # Updates database with the new data
          POINTS.set_new(
              {id: user.id},
              points:     total_points,
              decay_time: (Time.now + TWO_WEEKS).to_i,
              reason:     "6h mute - #{reason}"
          )

        # Tier 3: 12 hour mute
        elsif (15..19).include?(total_points)
          # Executes mute
          Bot::BOT.execute_command(:mute, event, args.insert(1, '12h'))

          # Sends notification DM to user
          user.dm(
              "**#{user.distinct}, you have been muted for 12 hours.** Your new point total is: **#{total_points}** points.\n" +
              "**Reason:** #{reason}"
          )

          # Updates database with the new data
          POINTS.set_new(
              {id: user.id},
              points:     total_points,
              decay_time: (Time.now + TWO_WEEKS).to_i,
              reason:     "12h mute - #{reason}"
          )

        # Tier 4: Ban
        else
          # Sends notification DM to user (sent before the ban so the bot can still DM the user)
          user.dm(
              "**#{user.distinct}, you have passed the point threshold for a ban.**\n" +
              "**Reason:** #{reason}\n" +
              "\n" +
              "If you would like to appeal your ban, send a DM to an administrator: #{SERVER.role(ADMINISTRATOR_ROLE_ID).users.map { |u| "**#{u.distinct}**" }.join(', ')}."
          )

          # Executes ban
          Bot::BOT.execute_command(:ban, event, args)

          # Sends notification message to moderation channel
          Bot::BOT.send_message(
              MODERATION_CHANNEL_CHANNEL_ID, 
              "@everyone **User #{user.mention} has been #{event.user.role?(ADMINISTRATOR_ROLE_ID) ? 'banned' : 'put on trial for ban'} after receiving 20 points.**"
          )
        end

      # If a critical punishment was chosen:
      else
        # Tier 1: 24 hour/1 day mute
        if (10..14).include?(total_points)
          # Executes mute
          time = %w(24h 1d) # picks one of two different time formats, just for fun
          Bot::BOT.execute_command(:mute, event, args.insert(1, time))

          # Sends notification dm to user
          user.dm(
              "**#{user.distinct}, you have been muted for #{time == '24h' ? '24 hours' : '1 day'}.** Your new point total is: **#{total_points}** points.\n" +
              "**Reason:** #{reason}"
          )

          # Updates database with the new data
          POINTS.set_new(
              {id: user.id},
              points:     total_points,
              decay_time: (Time.now + TWO_WEEKS).to_i,
              reason:     "#{time} mute - #{reason}"
          )

        # Tier 2: 2 day mute
        elsif (15..19).include?(total_points)
          # Executes mute
          Bot::BOT.execute_command(:mute, event, args.insert(1, '2d'))

          # Sends notification DM to user
          user.dm(
              "**#{user.distinct}, you have been muted for 2 days.** Your new point total is: **#{total_points}** points.\n" +
              "**Reason:** #{reason}"
          )

          # Updates database with the new data
          POINTS.set_new(
              {id: user.id},
              points:     total_points,
              decay_time: (Time.now + TWO_WEEKS).to_i,
              reason:     "2d mute - #{reason}"
          )

        # Tier 3: Ban
        else
          # Sends notification DM to user (sent before the ban so the bot can still DM the user)
          user.dm(
              "**#{user.distinct}, you have passed the point threshold for a ban.**\n" +
              "**Reason:** #{reason}\n" +
              "\n" +
              "If you would like to appeal your ban, send a DM to an administrator: #{SERVER.role(ADMINISTRATOR_ROLE_ID).users.map { |u| "**#{u.distinct}**" }.join(', ')}."
          )

          # Executes ban
          Bot::BOT.execute_command(:ban, event, args)

          # Sends notification message to moderation channel
          Bot::BOT.send_message(
              MODERATION_CHANNEL_CHANNEL_ID,
              "@everyone **User #{user.mention} has been #{event.user.role?(ADMINISTRATOR_ROLE_ID) ? 'banned' : 'put on trial for ban'} after receiving 20 points.**"
          )
        end
      end

      # Untracks user if they were a Head Creator punishing
      head_creator_punishing.delete(event.user.id)

    # If user canceled punishment:
    else
      # Sends cancellation message to channel dependent on whether they are staff or a HC
      Bot::BOT.send_message(
          event.user.role?(MODERATOR_ROLE_ID) ? MODERATION_CHANNEL_CHANNEL_ID : HEAD_CREATOR_HQ_CHANNEL_ID,
          '**The punishment has been canceled.**'
      )
    end

    nil # returns nil so command doesn't send an extra message
  end


  # Command to check points; usable by user in #bot_commands for their own points 
  # or staff in #moderation_channel to get anyone's
  command :points do |event, *args|
    # If user is using command in #bot_commands:
    if event.channel.id == BOT_COMMANDS_CHANNEL_ID
      # Defines variable containing user points; set to 0 if no user entry is found in points data
      user_points = POINTS[id: event.user.id] ? POINTS[ID: event.user.id][:points] : 0

      # Sends dm to user
      event.user.dm(
        "**#{event.user.distinct}, you have: #{user_points} points.**\n" +
        "*This is an automated message. Do not reply.*"
      )

    # If user is a moderator and using the command in #moderation_channel:
    elsif event.user.role?(MODERATOR_ROLE_ID) && event.channel.id == MODERATION_CHANNEL_CHANNEL_ID
      # +points without arguments, returns text file of all points
      if args.empty?
        # Fetches entries from database, and formats it into an array of strings
        formatted_points = POINTS.all.select { |e| Bot::BOT.user(e[:id]) }.map do |entry|
          "#{Bot::BOT.user(entry[:id]).distinct} • Points: #{entry[:points]}\n" +
          "Last punishment: #{entry[:reason]}\n" +
          "Date of next decay: #{entry[:decay_time] ? Time.at(entry[:decay_time]).strftime('%B %-d, %Y') : 'N/A'}"
        end

        # Joins the array of formatted strings and writes it to file
        File.open("#{MOD_DATA_PATH}/points.txt", 'w') do |file|
          file.write(
              "All user points:\n" +
              "\n" +
              formatted_points.join("\n--------------------\n")
          )
        end

        # Uploads file
        event << "**All users' points:**"
        event.attach_file(File.open("#{MOD_DATA_PATH}/points.txt"))

      # +points with arguments
      else
        # Adding points to user
        if args[0].downcase == 'add' &&
           args.size >= 3 && # ensures point value and user are present
           args[1].to_i > 0 && # ensures at least 1 point is to be added
           (user = SERVER.get_user(args[2..-1].join(' '))) &&
          # Defines variable containing points to be added
          added_points = args[1].to_i

          # Updates point data in database, and sets decay time and reason if user doesn't already have points
          POINTS.set_new(
              {id: user.id},
              points:     added_points,
              decay_time: POINTS[id: user.id] ? POINTS[id: user.id][:decay_time] : (Time.now + TWO_WEEKS).to_i,
              reason:     'N/A - Points added manually'
          )

          # Sends confirmation message and dms user
          event.respond "**Added #{pl(added_points, 'point')} to user #{user.distinct}.**"
          user.pm "**#{user.distinct}, a moderator has added some points to you.** You now have **#{pl(POINTS[id: user.id][:points], 'point')}**."

        # Removing points from user
        elsif args[0].downcase == 'remove' &&
              args.size >= 3 && # ensures 'add' arg, point value and user are present
              args[1].to_i > 0 && # ensures points to add is valid
              (user = SERVER.get_user(args[2..-1].join(' '))) &&
              POINTS[id: user.id] # ensures entry exists in database

          # Defines variable containing points to be removed
          removed_points = args[1].to_i

          # Updates point data in database, setting points to 0 if removed points would make it go negative
          POINTS.where(id: user.id).update(points: [POINTS[id: user.id][:points] - removed_points, 0].max)

          # Sends confirmation message and dms user
          event.respond "**Removed #{pl(removed_points, 'point')} from user #{user.distinct}.**" # confirmation message
          user.pm "**#{user.distinct}, a moderator has removed some points from you.** You now have **#{pl(POINTS[id: user.id][:points], 'point')}**." # notification pm

          # Deletes entry if user now has 0 points
          POINTS.where(points: 0).delete

        # If user is setting a point decay option:
        elsif args[0].downcase == 'decay' &&
              args.size >= 3 && # ensures decay subargument and user exists
              (user = SERVER.get_user(args[2..-1].join(' '))) && # ensures user is valid
              POINTS[id: user.id] # ensures user has entry in points variable
          # If user is resetting next decay time to two weeks from now:
          if args[1].downcase == 'reset'
            POINTS.where(id: user.id).update(decay_time: Time.now.to_i + TWO_WEEKS)
            event.respond "**Set next point decay time for user #{user.distinct} to two weeks from now.**"

          # If user is turning off decay:
          elsif args[1].downcase == 'off'
            POINTS.where(id: user.id).update(decay_time: nil)
            event.respond "**Turned off point decay for user #{user.distinct}**."
          end

        # Checking points of a user
        elsif (user = SERVER.get_user(args.join(' ')))
          # Defines variables containing the user's points, time of the next point decay and
          # reason for last punishment, using default values if no user entry exists within
          # the database
          if POINTS[id: user.id]
            points = POINTS[id: user.id][:points]
            decay_time = POINTS[id: user.id][:decay_time] ? Time.at(POINTS[id: user.id][:decay_time]) : nil
            reason = POINTS[id: user.id][:reason]
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
                                "**Date of next decay:** #{decay_time ? decay_time.strftime('%B %-d, %Y') : 'N/A'}"
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
    break unless (event.user.role?(MODERATOR_ROLE_ID) ||
                  head_creator_punishing.include?(event.user.id)) &&
                 args.size >= 2 &&
                 (SERVER.get_user(args[0]) || args[0] == 'channel') &&  # user or channel
                 args[1].to_sec > 0 # valid length of time

    # Defines the time at which the mute ends
    end_time = Time.now + args[1].to_sec

    # If user is muting a channel:
    if args[0] == 'channel' # preferred to muting user, so users can't nickname themselves 'channel'
      # Breaks if no reason is given
      break unless args.size >= 3

      # Defines channel variable, reason for mute, and the Member role's 
      # permissions in the event channel
      channel = event.channel
      reason = args[2..-1].join(' ')
      permissions = channel.permission_overwrites[MEMBER_ROLE_ID] || Discordrb::Overwrite.new(MEMBER_ROLE_ID, type: :role)

      # Denies the permission to send messages for the Member role in the event channel
      permissions.allow.can_send_messages = false
      permissions.deny.can_send_messages = true
      channel.define_overwrite(
        permissions,
        reason: "Channel mute -- reason: #{reason}" # audit log reason
      )

      # Sends confirmation message to event channel
      channel.send_message(
        "**Muted channel for #{args[1].scan(/[1-9]\d*[smhd]/i).join}.**\n" +
        "**Reason:** #{reason}", 
        false, # tts
        {image: {url: 'https://cdn.discordapp.com/attachments/753161182441111624/754969825981366312/cobalt_banhammer.gif'}}
      )

      # Sends log message to log channel
      Bot::BOT.send_message(
        COBALT_REPORT_CHANNEL_ID,
        ":x: **CHANNEL MUTE**\n" + 
        "**#{event.user.distinct}:** Muted #{channel.mention} for **#{args[1].to_sec.to_dhms}**.\n" +
        "**Reason:** #{reason}"
      )

      # Stores mute info in the database
      MUTED_CHANNELS.set_new(
          {id:       channel.id},
           end_time: end_time,
           reason:   reason
      )

      # Schedules a Rufus job to unmute the channel and stores it in the mute_jobs hash,
      # unscheduling any previous mutes on this channel
      mute_jobs[channel.id].unschedule if mute_jobs[channel.id]
      mute_jobs[channel.id] = SCHEDULER.schedule_at end_time do
        # Deletes channel entry from database and job hash
        MUTED_CHANNELS.where(id: channel.id).delete
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
      opt_in_roles = OPT_IN_ROLES.select { |id| user.role?(id) }

      # Mutes user by adding Muted role and removing Member and opt-in roles
      user.modify_roles(
        MUTED_ROLE_ID, # add Muted
        [MEMBER_ROLE_ID] + opt_in_roles, # remove Member and opt-in roles
        "Mute -- reason: #{reason}" # audit log reason
      )

      # If the mute length is less than 10 minutes:
      if mute_length < 600
        # Sends only confirmation message
        event.respond( # confirmation message sent to event channel
          "**Muted #{user.distinct} for #{args[1].to_sec.to_dhms}.**",
          false, # tts
          {image: {url: 'https://cdn.discordapp.com/attachments/753161182441111624/754969825981366312/cobalt_banhammer.gif'}}
        )

      # If the mute length is between 10 and 30 minutes
      # Note: This is inclusive of 10 minutes, but exclusive of 30 minutes
      elsif (600...1800).include? mute_length
        # Sends confirmation message and simpler log message (no identifier or embed)
        event.respond( # confirmation message sent to event channel
          "**Muted #{user.display_name} for #{args[1].to_sec.to_dhms}.**\n" +
          "**Reason:** #{reason}", 
          false, # tts
          {image: {url: 'https://cdn.discordapp.com/attachments/753161182441111624/754969825981366312/cobalt_banhammer.gif'}}
        )
        Bot::BOT.send_message( # log message
          COBALT_REPORT_CHANNEL_ID, 
          ":mute: **MUTE**\n" +
          "**#{event.user.distinct}: Muted #{user.mention} for #{args[1].to_sec.to_dhms}** in channel #{event.channel.mention}\n" +
          "**Reason:** #{reason}"
        )

      # If the mute length is 30 minutes or above:
      else
        # Sends confirmation message and full log message
        identifier = SecureRandom.hex(4)
        event.respond( # confirmation message with identifier sent to event channel
          "• **ID**`#{identifier}`\n" +
          "**Muted #{user.display_name} for #{args[1].to_sec.to_dhms}.**\n" +
          "**Reason:** #{reason}", 
          false, # tts
          {image: {url: 'https://cdn.discordapp.com/attachments/753161182441111624/754969825981366312/cobalt_banhammer.gif'}}
        )
        Bot::BOT.send_message( # full log message with identifier
          COBALT_REPORT_CHANNEL_ID, 
          "**ID:** `#{identifier}`", 
          false, # tts
          {
            author: {
              name: "MUTE | User: #{user.display_name} (#{user.distinct})", 
              icon_url: user.avatar_url
            },
            description: "**#{user.mention} muted for #{args[1].to_sec.to_dhms}** in channel #{event.channel.mention}.\n" +
                         "• **Reason:** #{reason}\n" +
                         "\n" +
                         "**Muted by:** #{event.user.distinct}",
            thumbnail: {url: 'https://emojipedia-us.s3.amazonaws.com/thumbs/160/twitter/103/speaker-with-cancellation-stroke_1f507.png'},
            color: 0xFFD700
          }
        )
      end

      # Stores mute info in database
      MUTED_USERS.set_new(
          {id:           user.id},
           end_time:     end_time.to_i,
           trial?:       false,
           reason:       reason,
           opt_in_roles: opt_in_roles.join(',')
      )

      # Schedules a Rufus job to unmute the user and stores it in the mute_jobs hash,
      # unscheduling any previous mutes on this user
      mute_jobs[user.id].unschedule if mute_jobs[user.id]
      mute_jobs[user.id] = SCHEDULER.schedule_at end_time do
        # Deletes user entry from database and job hash
        MUTED_USERS.where(id: user.id).delete
        mute_jobs.delete(user.id)

        # Unmutes user by removing Muted role and re-adding Member and opt-in roles
        begin
          user.modify_roles(
            [MEMBER_ROLE_ID] + opt_in_roles, # add Member and opt-in roles
            MUTED_ROLE_ID, # remove Muted
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
    break unless event.user.role?(MODERATOR_ROLE_ID) &&
                 args.size >= 1 &&
                 ((user = SERVER.get_user(args.join(' '))) ||
                  args[0] == 'channel')
    
    # If user is unmuting a channel:
    if args[0] == 'channel' # preferred to unmuting user, so users can't nickname themselves 'channel'
      # Breaks unless the channel is muted
      break unless MUTED_CHANNELS[id: event.channel.id]

      # Defines the Member role's permissions in the event channel
      permissions = event.channel.permission_overwrites[MEMBER_ROLE_ID] || Discordrb::Overwrite.new(MEMBER_ROLE_ID, type: :role)

      # Unschedules unmute job and deletes channel entry from database and job hash
      mute_jobs[event.channel.id].unschedule
      MUTED_CHANNELS.where(id: event.channel.id).delete
      mute_jobs.delete(event.channel.id)

      # Neutralizes the permission to send messages for the Member role in the event channel
      permissions.deny.can_send_messages = false
      event.channel.define_overwrite(
        permissions,
        reason: 'Channel unmute' # audit log reason
      )

      # Sends confirmation message
      channel.send_message('**Channel unmuted.**') # confirmation message sent to event channel
    
    # If user is unmuting another user:
    else
      # Breaks unless the user is muted
      break unless MUTED_USERS[id: user.id]

      # If user is muted due to being on trial for a ban:
      if MUTED_USERS[id: user.id][:trial?]
        event << 'That user is on trial for ban and cannot be unmuted.'
        break
      end

      # Defines array of IDs of user's opt-in roles
      opt_in_roles = MUTED_USERS[id: user.id][:opt_in_roles].split(',')
      
      # Unschedules unmute job and deletes user entry from data file and job hash
      mute_jobs[user.id].unschedule # unschedules unmute job
      MUTED_USERS.where(id: user.id).delete
      mute_jobs.delete(user.id)

      # Unmutes user by removing Muted role and re-adding Member and opt-in roles
      user.modify_roles(
        [MEMBER_ROLE_ID] + opt_in_roles, # add Member and opt-in roles
        MUTED_ROLE_ID, # remove Muted
        "Unmute" # audit log reason
      )

      # Sends confirmation message
      event.send_message('**Unmuted this user.**') # confirmation message sent to event channel
    end

    nil # returns nil so command doesn't send an extra message
  end


  # Displays muted users or channels
  command :muted, channels: [MODERATION_CHANNEL_CHANNEL_ID, MUTED_USERS_CHANNEL_ID] do |event, arg = 'users'|
    # If user wants to display muted users:
    if arg.downcase == 'users'
      # If no users are muted, send notification message
      if MUTED_USERS.empty?
        event.respond 'No users are muted.'
      
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
          MUTED_USERS.all do |entry|
            # Defines user variable and string displaying how much time is left in user's mute
            user = SERVER.member(entry[:id])
            time_remaining = entry[:trial?] ? 'On trial for ban.' : (entry[:end_time] - Time.now.to_i).to_dhms

            # Adds field to embed with the muted user and their info
            embed.add_field(
              name: user ? user.distinct : "ID: #{entry[:id]}",
              value: "**Time remaining:** #{time_remaining}\n" + 
                     "**Reason:** #{entry[:reason]}",
              inline: true
            )
          end
        end
      end
    
    # If user wants to display muted channels:
    elsif arg.downcase == 'channels'
      # If no channels are muted, send notification message
      if MUTED_CHANNELS.empty?
        event.respond 'No channels are muted.'

      # If channels are muted
      else
        event.send_embed do |embed|
          embed.author = {
            name: 'Muted: Users', 
            icon_url: 'https://cdn.discordapp.com/attachments/330586271116165120/427435169826471936/glossaryck_icon.png'
          }
          embed.color = 0xFFD700

          # Iterates through every muted channel and adds field for each
          MUTED_CHANNELS.all do |entry|
            embed.add_field(
              name: "##{Bot::BOT.channel(entry[:id]).name}",
              value: "**Time remaining:** #{(entry[:end_time] - Time.now.to_i).to_dhms}\n" +
                     "**Reason:** #{entry[:reason]}",
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
      event << '👌'
      break
    end

    # Breaks unless user is either a moderator or a punishing Head Creator, a valid user and reason is given
    break unless (event.user.role?(MODERATOR_ROLE_ID) ||
                  head_creator_punishing.include?(event.user.id)) &&
                 args.size >= 2 &&
                 (user = SERVER.get_user(args[0]))
    
    # Defines reason variable
    reason = args[1..-1].join(' ')

    # Prompts user for how many days of messages from the user that should be deleted, and defines
    # variable for it
    event.respond "**#{event.user.mention}, how many days of messages would you like to delete?**\n" +
                  "Replying without a number defaults to 0."
    response = event.message.await!
    ban_days = response.message.content.to_i

    # Unschedules mute job and deletes from hash if user is currently muted
    if MUTED_USERS[id: user.id]
      mute_jobs[user.id].unschedule
      mute_jobs.delete(user.id)  
    end

    # If user is an administrator, and can immediately ban:
    if event.user.role?(ADMINISTRATOR_ROLE_ID) # administrator is preferred as administrators also have moderator role
      # Deletes user entry from database
      MUTED_USERS.where(id: user.id).delete
      POINTS.where(id: user.id).delete

      # Bans user
      SERVER.ban(
        user, ban_days,
        reason: "Ban -- reason: #{reason} (#{ban_days} days of messages deleted)" # audit log reason
      )

      # Sends confirmation message with identifier to event channel
      identifier = SecureRandom.hex(4)
      event.send_message(
        "• **ID** `#{identifier}`\n" + 
        "**User #{user.distinct} banned from server.**\n" +
        "• **Reason:** #{reason}", 
        false, # tts
        {image: {url: 'https://cdn.discordapp.com/attachments/753161182441111624/754969825981366312/cobalt_banhammer.gif'}}
      )

      # Sends log message with identifier to log channel
      Bot::BOT.send_message(
        COBALT_REPORT_CHANNEL_ID, 
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
    elsif (event.user.role?(MODERATOR_ROLE_ID) ||
           head_creator_punishing.include?(event.user.id))
      # Defines array of IDs of user's opt-in roles
      opt_in_roles = OPT_IN_ROLES.select { |id| user.role?(id) }
      
      # Mutes user by adding Muted role and removing Member and opt-in roles
      user.modify_roles(
        MUTED_ROLE_ID, # add Muted
        [MEMBER_ROLE_ID] + opt_in_roles, # remove Member and opt-in roles
        "Mute -- reason: #{reason}" # audit log reason
      )

      # Sets user entry in database
      MUTED_USERS.set_new(
          {id:           user.id},
           end_time:     0,
           trial?:       true,
           reason:       reason,
           opt_in_roles: opt_in_roles.join(',')
      )

      # Sends confirmation message with identifier to event channel
      identifier = SecureRandom.hex(4)
      event.send_message( # trial confirmation message with identifier sent to event channel
        "• **ID** `#{identifier}`\n" +
        "**User #{user.distinct} muted and put on trial for ban.**\n" +
        "**Reason:** #{reason}",
        false, # tts
        {image: {url: 'https://cdn.discordapp.com/attachments/753161182441111624/754969825981366312/cobalt_banhammer.gif'}}
      )

      # Sends log message with identifier to log channel and adds approve/deny buttons
      msg = Bot::BOT.send_message(
        COBALT_REPORT_CHANNEL_ID, 
        "@here **| ID:** `#{identifier}`",
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
          {channel: COBALT_REPORT_CHANNEL_ID}
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
               event.user.role?(ADMINISTRATOR_ROLE_ID))
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

        # Deletes user entry from database
        MUTED_USERS.where(id: user.id).delete
        POINTS.where(id: user.id).delete

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
            [MEMBER_ROLE_ID] + opt_in_roles, # add Member and opt-in roles
            MUTED_ROLE_ID, # remove Muted
            "Unmute" # audit log reason
          )
        rescue StandardError => e
          puts "Exception raised when modifying a user's roles -- most likely user left the server"
        end

        # Deletes user entry from database
        MUTED_USERS.where(id: user.id).delete

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
    # Breaks unless user is a moderator or HC, the user is valid and not already blocked, and a reason is given
    break unless (event.user.role?(MODERATOR_ROLE_ID) ||
                  event.user.role?(HEAD_CREATOR_ROLE_ID)) &&
                 args.size >= 2 &&
                 (user = SERVER.get_user(args[0])) &&
                 !CHANNEL_BLOCKS[channel_id: event.channel.id, user_id: user.id]

    # Defines reason variable and user's permissions in the event channel
    reason = args[1..-1].join(' ')
    permissions = event.channel.permission_overwrites[user.id] || Discordrb::Overwrite.new(user)

    # Denies user's perms to read messages in event channel
    permissions.allow.can_read_messages = false
    permissions.deny.can_read_messages = true
    event.channel.define_overwrite(
      permissions,
      reason: "Block -- reason: #{reason}" # audit log reason
    )

    # Adds channel block entry to database and updates user's points
    CHANNEL_BLOCKS << {
        channel_id: event.channel.id,
        user_id:    user.id
    }
    POINTS.set_new(
        {id:         user.id},
         points:     (entry = POINTS[id: user.id]) ? entry[:points] + 2 : 2,
         decay_time: (Time.now + TWO_WEEKS).to_i,
         reason:     "2d mute - #{reason}"
    )

    # Sends confirmation message to event channel
    event.respond(
      "**Blocked #{user.distinct} from channel.**\n" +
      "**Reason:** #{reason}"
    )

    # Sends notification DM to user
    user.dm(
      "**#{user.distinct}, you have been blocked from channel ##{event.channel.name}.** Your new point total is: **#{POINTS[id: user.id][:points]}** points.\n" +
      "**Reason:** #{reason}"
    )

    # Sends log message to log channel
    Bot::BOT.send_message(
      COBALT_REPORT_CHANNEL_ID, 
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
    # Breaks unless user is moderator or HC, the given user is valid and is blocked from the event channel
    break unless (event.user.role?(MODERATOR_ROLE_ID) ||
                  event.user.role?(HEAD_CREATOR_ROLE_ID)) &&
                 (user = SERVER.get_user(args.join(' '))) &&
                 CHANNEL_BLOCKS[channel_id: event.channel.id, user_id: user.id]
    
    # Defines user variable and gets user's permissions in the event channel
    permissions = event.channel.permission_overwrites[user.id]

    # Neutralizes user's perms to read messages in event channel
    permissions.allow.can_read_messages = false
    permissions.deny.can_read_messages = false
    event.channel.define_overwrite(
      permissions,
      reason: "Unblock" # audit log reason
    )

    # Deletes channel block entry in the database
    CHANNEL_BLOCKS.where(
        channel_id: event.channel.id,
        user_id:    user.id
    ).delete

    # Sends confirmation message to event channel
    event.respond "**Unblocked #{user.distinct} from channel.**"

    # Sends log message to log channel
    Bot::BOT.send_message(
      COBALT_REPORT_CHANNEL_ID, 
      ":o: **UNBLOCK**\n" + "
      **#{event.user.distinct}: Unblocked #{user.mention} from channel #{event.channel.mention}**"
    )

    nil # returns nil so command doesn't send an extra message
  end


  # Lists all channel blocks
  command :blocks do |event|
    # Breaks unless user is moderator
    break unless event.user.role?(MODERATOR_ROLE_ID)

    # Sends embed to channel displaying blocks
    event.send_embed do |embed|
      embed.author = {
        name: 'Channel Blocks', 
        icon_url: 'https://cdn.discordapp.com/attachments/330586271116165120/427435169826471936/glossaryck_icon.png'
      }

      # Iterates through all unique channel IDs in the channel block database and adds field for all of them,
      # provided at least one user within the channel is still present within the server
      CHANNEL_BLOCKS.map(:channel_id).uniq.each do |channel_id|
        blocked_users = CHANNEL_BLOCKS.where(channel_id: channel_id).map(:user_id)
        blocked_users.map! { |uid| Bot::BOT.user(uid) }.compact!
        next if blocked_users.empty? || !Bot::BOT.channel(channel_id)
        embed.add_field(
          name: "##{Bot::BOT.channel(channel_id).name}",
          value: blocked_users.map { |u| "• **#{u.distinct}**" }.join("\n")
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

    # Defines user variable
    user = event.user.on(SERVER)

    # If user entry exists in the muted dataset in the database, gives user Muted role
    if MUTED_USERS[id: user.id]
      user.add_role(MUTED_ROLE_ID)
    end
    
    # Denies read message perms for channels user is blocked from, if any
    if CHANNEL_BLOCKS.all.any? { |e| e[:blocked_users].include? user.id.to_s }
      # Defines array containing the database entries of all channels user is blocked from,
      # and new universal permission object for user
      entries = CHANNEL_BLOCKS.all.select { |e| e[:blocked_users].include? user.id.to_s }
      permissions = Discordrb::Overwrite.new(user.id, type: :user)

      # Denies read message permissions for universal object
      permissions.allow.can_read_messages = false
      permissions.deny.can_read_messages = true

      # Iterates through array of channel IDs and edits permissions to deny user from all of them
      entries.each { |e| Bot::BOT.channel(e[:id]).define_overwrite(permissions) }
    end
  end


  # Spam protection; deletes messages if user sends too many too fast
  message do |event|
    # Skips unless the channel is not #bot_games and a user has triggered the spam filter
    next unless (event.channel.id != BOT_GAME_CHANNEL_ID) && SPAM_FILTER_BUCKET.rate_limited?(event.user.id)

    # Resets spam filter bucket for user before deleting messages, so it isn't rate limited
    SPAM_FILTER_BUCKET.reset(event.user.id)

    # Gets the user's message history in the event channel and deletes it
    user_messages = event.channel.history(50).select { |m| m.author == event.user }[0..4]
    event.channel.delete_messages(user_messages)
  end


  # Blacklist; deletes message if it contains a blacklisted word
  message do |event|
    # Skips if message is in #moderation_channel, user is moderator, user is Owner, or user has COBALT'S MOMMY Role (this exception only exists so it's possible to promote the test server in the future)
    next if event.channel.id == MODERATION_CHANNEL_CHANNEL_ID || event.user.role?(COBALT_MOMMY_ROLE_ID) || event.user.id == OWNER_ID || event.user.role?(COBALT_MOMMY_ROLE_ID)

    # Deletes message if any word from the blacklist is present within the message content
    if YAML.load_data!("#{MOD_DATA_PATH}/blacklist.yml").any? { |w| event.message.content.downcase.include? w }
      event.message.delete
    end
  end

  # Prunes messages from channel
  command :prune do |event, arg|
    # Breaks unless user is moderator and the messages to delete is between 2 and 100
    break unless event.user.role?(MODERATOR_ROLE_ID) &&
                 (2..100).include?(arg.to_i)

    # Deletes calling message, then prunes given number of messages from event channel
    event.message.delete
    event.channel.prune(arg.to_i)

    # Sends temporary confirmation message
    event.send_temp(
      "Deleted **#{arg.to_i}** messages.",
      3 # seconds that the message lasts
    )
  end
end