# Crystal: Miscellaneous


# This command contains Cobalt's miscellaneous features that don't really fit in anywhere else.
module Bot::Miscellaneous
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  # Path to crystal's data folder
  MISC_DATA_PATH = "#{Bot::DATA_PATH}/miscellaneous".freeze
  # Voice channel IDs with their respective text channel IDs; in the format {voice => text}
  VOICE_TEXT_CHANNELS = {
      387802285733969920 => 307778254431977482, # General
      378857349705760779 => 378857881782583296, # Generally
      307763283677544448 => 307763370486923264, # Music
      307882913708376065 => 307884092513583124, # Gaming
      307747884823085056 => 307879429009309696  # Watchalongs
  }.freeze
  # Role button message ID
  ROLE_MESSAGE_ID = 439778623965233152
  # Updates role ID
  UPDATES_ID = 386083829699575809
  # SVTFOE News role ID
  SVTFOE_NEWS_ID = 411199894850764811
  # SVTFOE Leaks role ID
  SVTFOE_LEAKS_ID = 418824910597521419
  # Bot Games role ID
  BOT_GAMES_ID = 402051258732773377
  # Vent role ID
  VENT_ID = 382433569101971456
  # Debate role ID
  DEBATE_ID = 316353444971544577
  # Sandbox role ID
  SANDBOX_ID = 454304307425181696
  # #cobalt_reports ID
  COBALT_REPORTS_ID = 307755696198385666
  # #quoteboard ID
  QUOTEBOARD_ID = 348001214698487809
  # IDs of channels blacklisted from #quoteboard
  QUOTEBOARD_BLACKLIST = [
      307726630061735936, # #news
      360720349421109258, # #svtfoe_news
      382469794848440330, # #vent_space
      418819468412715008  # #svtfoe_leaks
  ].freeze
  # Head Creator role ID
  HEAD_CREATOR_ID = 338673551445852162
  # Content Creator role IDs
  CREATOR_ROLE_IDS = {
    art: 383960705365311488,
    multimedia: 383961150905122828,
    writing: 383961249899216898
  }.freeze

  # Tracker for whether a message has been quoted to #quoteboard recently
  qb_recent = false
  
  # Voice text channel management; detects when user has joined a voice channel that has a
  # corresponding text channel and makes its text channel visible to user
  voice_state_update do |event|
    # Skips if user is Bounce Lounge (the music bot)
    next if event.user.id == BOUNCE_LOUNGE_ID

    # Unless user just left a voice channel or updated their voice status (e.g. muted, unmuted,
    # deafened, undeafened), delete permission overwrites for event user in all voice text channels
    unless event.channel.nil? ||
           event.channel == event.old_channel
      VOICE_TEXT_CHANNELS.values.each { |id| Bot::BOT.channel(id).delete_overwrite(event.user.id) }
    end

    # If user has just joined/switched to a voice channel that has a corresponding text channel, 
    # allows read message perms for the corresponding text channel and sends temporary notification
    # message in the channel
    if event.channel &&
       (event.channel != event.old_channel) &&
       VOICE_TEXT_CHANNELS.has_key?(event.channel.id)
      text_channel = Bot::BOT.channel(VOICE_TEXT_CHATS[event.channel.id])
      text_channel.define_overwrite(event.user, 1024, 0) # uses permission bits for simplicity's sake
      text_channel.send_temporary_message(
        "**#{event.user.mention}, welcome to #{text_channel.mention}.** This is the text channel for the voice channel you're connected to.", 
        10 # seconds that the message lasts
      )
    end
  end

  # Beans a user
  command :bean do |event, *args|
    # Sets first arg to have empty string if not already defined
    args[0] ||= ''

    # Defines variable containing the text at the end of the bean message, depending on if
    # arguments were given or not
    extra_text = args[1..-1].empty? ? '.' : " for #{args[1..-1].join(' ')}."

    # If the mentioned user is valid and user is a moderator, correctly beans user
    if SERVER.get_user(args[0]) && event.user.role?(MODERATOR_ID)
      "#{SERVER.get_user(args[0]).mention} has been **beaned** from the server#{extra_text}"

    # Otherwise, turns on the event user and beans them
    else
      "Cobalt turns on #{event.user.mention} and **beans** them from the server."
    end
  end

  # Makes bot say something
  command :say do |event|
    # Breaks unless user is me (ethane) or SkeletonOcelot
    break unless event.user.id == MY_ID || event.user.id == 354504581176098816

    # Deletes event message and responds with the content of it, deleting the command call
    event.message.delete
    event.message.content[5..-1]
  end

  # Sends 'quality svtfoe discussion' gif in the #svtfoe_discussion channel
  command :quality, channels: %w(#svtfoe_discussion) do |event|
    # Breaks unless user is moderator
    break unless event.user.role?(MODERATOR_ID)

    # Sends gif
    event.channel.send_file(File.open("#{MISC_DATA_PATH}/quality.gif"))
  end

  # Adds role when user presses its reaction button
  reaction_add do |event|
    # Skips unless the message ID is equal to the role button message's ID and user has Member role
    next unless event.message.id == ROLE_MESSAGE_ID &&
                event.user.role?(MEMBER_ID)

    # Cases reaction emoji and gives user correct role accordingly
    case event.emoji.name
    when '🔔'
      event.user.add_role(UPDATES_ID)
    when '🌟'
      event.user.add_role(SVTFOE_NEWS_ID)
    when '🚰'
      event.user.add_role(SVTFOE_LEAKS_ID)
    when '🎮'
      event.user.add_role(BOT_GAMES_ID)
    when '💭'
      event.user.add_role(VENT_ID)
    when '🗣'
      event.user.add_role(DEBATE_ID)
    when '🎲'
      event.user.add_role(SANDBOX_ID)
    end
  end

  # Removes role when user depresses its reaction button
  reaction_remove do |event|
    # Skips unless the message ID is equal to the role button message's ID and user has Member role
    next unless event.message.id == ROLE_MESSAGE_ID &&
        event.user.role?(MEMBER_ID)

    # Cases reaction emoji and removes correct role from user accordingly
    case event.emoji.name
    when '🔔'
      event.user.remove_role(UPDATES_ID)
    when '🌟'
      event.user.remove_role(SVTFOE_NEWS_ID)
    when '🚰'
      event.user.remove_role(SVTFOE_LEAKS_ID)
    when '🎮'
      event.user.remove_role(BOT_GAMES_ID)
    when '💭'
      event.user.remove_role(VENT_ID)
    when '🗣'
      event.user.remove_role(DEBATE_ID)
    when '🎲'
      event.user.remove_role(SANDBOX_ID)
    end
  end

  # Displays server info
  command(:serverinfo, channels: %w(#bot_commands #moderation_channel)) do |event|
    # Sends embed containing server info
    event.send_embed do |embed|
      embed.author = {
          name: "SERVER: #{SERVER.name}",
          icon_url: 'https://cdn.discordapp.com/attachments/330586271116165120/427435169826471936/glossaryck_icon.png'
      }
      embed.thumbnail = {url: SERVER.icon_url}
      embed.add_field(
          name: 'Owner',
          value: SERVER.owner.distinct + "\n⠀",
          inline: true
      )
      embed.add_field(
          name: 'Region',
          value: SERVER.region_id + "\n⠀",
          inline: true
      )
      embed.add_field(
          name: 'Numerics',
          value: "**Members: #{SERVER.member_count}**\n" +
                 "├ Humans: **#{SERVER.members.count { |u| !u.bot_account? }}**\n" +
                 "├ Bots: **#{SERVER.members.count { |u| u.bot_account? }}**\n" +
                 "└ Online: **#{SERVER.online_members.size}**\n" +
                 "\n" +
                 "**Emotes: #{SERVER.emoji.length}**",
          inline: true
      )
      embed.add_field(
          name: '⠀',
          value: "**Channels: #{SERVER.channels.size}**\n" +
                 "├ Text: **#{SERVER.text_channels.size}**\n" +
                 "├ Voice: **#{SERVER.voice_channels.size}**\n" +
                 "└ Categories: **#{SERVER.categories.size}**\n" +
                 "\n" +
                 "**Roles: #{SERVER.roles.size}**",
          inline: true
      )
      embed.footer = {text: "ID: 297550039125983233 • Founded on April 28, 2017"}
      embed.color = 0xFFD700
    end
  end

  # Displays a user's info
  command([:userinfo, :who, :whois], channels: %w(#bot_commands #moderation_channel)) do |event, *args|
    # Sets argument to event user's ID if no arguments are given
    args[0] ||= event.user.id

    # Breaks unless user is valid
    break unless SERVER.get_user(args.join(' '))

    # Defines user variable
    user =  SERVER.get_user(args.join(' '))

    # Sends embed containing user info
    event.send_embed do |embed|
      embed.author = {
          name: "USER: #{user.display_name} (#{user.distinct})",
          icon_url: 'https://cdn.discordapp.com/attachments/330586271116165120/427435169826471936/glossaryck_icon.png'
      }
      embed.thumbnail = {url: user.avatar_url}
      embed.add_field(
          name: 'Status',
          value: user.status.to_s,
          inline: true
      )
      embed.add_field(
          name: 'Playing',
          value: (user.game || 'None'),
          inline: true
      )
      embed.add_field(
          name: 'Joined Server',
          value: user.joined_at.strftime('%B %-d, %Y'),
          inline: true
      ) if user.joined_at
      embed.add_field(
          name: 'Role Info',
          value: "**Roles: #{user.roles.size}**\n" +
                 "├ Highest: **#{user.highest_role ? user.highest_role.name.encode(Encoding.find('ASCII'), replace: '').strip : 'None'}**\n" +
                 "├ Color: **#{user.color_role ? user.color_role.name.encode(Encoding.find('ASCII'), replace: '').strip : 'None'}**\n" +
                 "└ Hoisted: **#{user.hoist_role ? user.hoist_role.name.encode(Encoding.find('ASCII'), replace: '').strip : 'None'}**",
          inline: true
      )
      embed.footer = {text: "ID #{user.id} • Joined Discord on #{user.creation_time.strftime('%b %-d, %Y')}"}
      embed.color = user.color_role.color.combined if user.color_role
    end
  end

  # Reports a user
  command :report do |event, *args|
    # Breaks unless user and reason are given and user is valid
    break unless args.size >= 2 &&
                 SERVER.get_user(args[0])

    # Defines user variable and an identifier
    user = SERVER.get_user(args[0])
    identifier = SecureRandom.hex.slice(0..7)

    # Sends report and confirmation message
    Bot::BOT.send_message( # report message sent to #cobalt_reports
      COBALT_REPORTS_ID,
      "@here **ID:** `#{identifier}`",
      false, # tts
      {
        author: {
          name: "REPORT | User: #{user.display_name} (#{user.distinct})",
          icon_url: user.avatar_url
        },
        description: "**User #{user.mention} reported** in channel #{event.channel.mention}.\n" +
                     "• **Reason:** #{args[1...args.size].join(' ')}\n" +
                     "\n" +
                     "**Filed by:** #{event.user.distinct}",
        thumbnail: {url: 'https://emojipedia-us.s3.amazonaws.com/thumbs/120/twitter/103/right-pointing-magnifying-glass_1f50e.png'},
        color: 0xFFD700
      }
    )
    event.respond "• **ID** `#{identifier}`\n" + # confirmation message sent to event channel
                  "**User #{user.distinct} has been reported.**\n" +
                  "**Reason:** #{args[1..-1].join(' ')}"
  end

  # Allows mods to ping a role without needing to deal with mentionable permissions
  command :roleping do |event, arg = ''|
    # Break unless user is moderator
    break unless event.user.role?(MODERATOR_ID)

    # Delete event message
    event.message.delete

    # Cases argument and defines role variable accordingly (or breaks if invalid argument)
    case arg.downcase
    when 'updates'
      role = SERVER.role(UPDATES_ID)
    when 'svtfoe', 'svtfoenews', 'starnews'
      role = SERVER.role(SVTFOE_NEWS_ID)
    when 'leaks', 'svtfoeleaks', 'starleaks'
      role = SERVER.role(SVTFOE_LEAKS_ID)
    else
      break
    end

    # Mentions role
    role.mentionable = true
    event.respond "#{role.mention} ⬆️"
    role.mentionable = false

    nil # returns nil so command doesn't send an extra message
  end

  # Sends a message to #quoteboard when it gets enough cams
  reaction_add(emoji: '📷') do |event|
    # Skips if message has not reached required cam reacts to be quoted, if it is within a blacklisted channel,
    # if it has been quoted already, or if another message has been quoted within the last 30 seconds already
    next if event.message.reactions['📷'].count != (YAML.load_data!("#{MISC_DATA_PATH}/qb_camera_count.yml")[event.channel.id] || 7) ||
            QUOTEBOARD_BLACKLIST.include?(event.channel.id) ||
            YAML.load_data!("#{MISC_DATA_PATH}/qb_messages.yml").include?(event.message.id)
            qb_recent

    # Push the message ID to the quoteboard messages data file
    YAML.load_data!("#{MISC_DATA_PATH}/qb_messages.yml") { |m| m.push(event.message.id) }

    # Deletes all message reactions
    event.message.delete_all_reactions

    # Sends embed to #quoteboard displaying message
    Bot::BOT.channel(348001214698487809).send_embed do |embed|
      embed.author = {
          name: "#{event.message.author.display_name} (#{event.message.author.distinct})",
          icon_url: event.message.author.avatar_url
      }
      embed.color = 0xFFD700
      embed.description = event.message.content

      # Add embed image only if original message contains an image
      unless event.message.attachments == []
        embed.image = Discordrb::Webhooks::EmbedImage.new(url: event.message.attachments[0].url)
      end

      embed.timestamp = event.message.timestamp.getgm
      embed.footer = {text: "##{event.message.channel.name}"}
    end

    # Sets recent quote tracker to true, and schedules it to be set back to false in 5 minutes
    qb_recent = true
    scheduler.in '30s' do
      qb_recent = false
    end
  end

  # Randomly chooses from given options
  command(:spinner, channels: %w(#bot_commands #moderation_channel)) do |event, *args|
    # Breaks unless at least one option is given and arguments do not contain @here or @everyone pings
    break unless args[0] &&
                 %w(@here @everyone).none? { |s| event.message.content.include? s }

    # Randomly select an option after 2 seconds
    msg = event.respond '**Spinning the spinner...**'
    sleep 2
    msg.edit "The spinner lands on: **#{args.join(' ').split(' | ').sample}**"
  end

  # Gives/removes Content Creator role to/from users
  command(:creator, channels: %w(#head_creator_hq)) do |event, *args|
    # Breaks unless user is moderator or Head Creator, give/remove, content creator role and user are given, and both
    # content creator role and user are valid
    break unless (event.user.role?(MODERATOR_ID) ||
                  event.user.role?(HEAD_CREATOR_ID)) &&
                  args.size >= 3 &&
                  %w(art multimedia writing).include?(args[1].downcase) &&
                  SERVER.get_user(args[2..-1].join(' '))

    # If first argument is 'give', gives user the desired Content Creator role
    if args[0] == 'give'
      SERVER.get_user(args[2..-1].join(' ')).add_role(CREATOR_ROLE_IDS[args[1].downcase.to_sym])
      "**Given user Content Creator for #{args[1].downcase}.**" # confirmation message sent to event channel

    # If first argument is 'remove', removes desired Content Creator role from user
    elsif args[0] == 'remove'
      SERVER.get_user(args[2..-1].join(' ')).remove_role(CREATOR_ROLE_IDS[args[1].downcase.to_sym])
      "**Removed Content Creator for #{args[1].downcase} from user.**" # confirmation message sent to event channel
    end
  end

  # Evaluates Ruby code
  command :eval do |event|
    # Breaks unless user is me (ethane)
    break unless event.user.id == MY_ID
    begin
      "**Returns:** `#{eval event.message.content.sub('+eval ', '')}`"
    rescue => e
      "**Error!** Message:\n" +
      "```\n" +
      "#{e}```"
    end
  end
end