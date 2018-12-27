# Crystal: Miscellaneous


# This command contains Cobalt's miscellaneous features that don't really fit in anywhere else.
module Bot::Miscellaneous
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Convenience

  # Path to crystal's data folder
  MISC_DATA_PATH = "#{Bot::DATA_PATH}/miscellaneous"
  # Voice channel IDs with their respective text channel IDs; in the format {voice => text}
  VOICE_TEXT_CHANNELS = {
    387802285733969920 => 307778254431977482, # General
    378857349705760779 => 378857881782583296, # Generally
    307763283677544448 => 307763370486923264, # Music
    307882913708376065 => 307884092513583124, # Gaming
    307747884823085056 => 307879429009309696  # Watchalongs
  }
  
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
    # Defines variable containing the text at the end of the bean message, depending on if
    # arguments were given or not
    extra_text = args.empty? ? '.' : " for #{args[1..-1].join(' ')}."

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
  command :quality, channels: ['#svtfoe_discussion'] do |event|
    # Breaks unless user is moderator
    break unless event.user.role?(MODERATOR_ID)

    # Sends gif
    event.channel.send_file(File.open("#{MISC_DATA_PATH}/quality.gif"))
  end
end