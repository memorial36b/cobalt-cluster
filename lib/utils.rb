# Loads Sequel early in code; ensure sqlite3 and sequel gems are added to Gemfile!
require 'sequel'
# Loads Rufus early in code to define scheduler here
require 'rufus-scheduler'

# Module containing constants that multiple crystals need access to
module Constants
  # Database object
  DB = Sequel.sqlite("#{Bot::DATA_PATH}/data.db")
  Bot::BOT.ready do
    # StarDis server constant
    SERVER = Bot::BOT.server(753163835862417480)
  end
  
  # Hardcoded user IDs

  # Owner's (Geechan) user ID
  OWNER_ID = 108144520553578496
  # Cobalt's Dev (CorruptedPhazite) user ID
  COBALT_DEV_ID = [99567651944165376, 220509153985167360, 334094154520854530]
  # Cobalt's Artist (SkeletonOcelot) user ID
  COBALT_ART_ID = 354504581176098816
  # Bounce Lounge Bot user ID
  BOUNCE_LOUNGE_ID = 309018929584537602
  
  # Role IDs

  # ⚖️ Administrators role ID
  ADMINISTRATOR_ROLE_ID = 753163836042903608
  # SVTFOD Team role ID
  SVTFOD_ROLE_ID = 753163836042903607
  # 🎂 Happy Birthday, Staff role ID
  HAPPY_BD_STAFF_ROLE_ID = 753163836042903606
  # 💎 Cobalt role ID
  COBALT_ROLE_ID = 753163836042903605
  # 🚨 Moderators role ID
  MODERATOR_ROLE_ID = 753163836042903604
  # 📧 DM me +chat to contact staff
  DM_ROLE_ID = 753163836042903603
  # MEE6 role ID
  MEE6_ROLE_ID = 754263145639444541
  # 🔇 Muted role ID
  MUTED_ROLE_ID = 753163836042903602
  # 🎂 Happy Birthday, Spong role ID
  HAPPY_BD_ROLE_ID = 753163836042903606
  # Ghastly Green role ID
  GHASTLY_GREEN_ROLE_ID = 753163836022063172
  # Shallow Yellow role ID
  SHALLOW_YELLOW_ROLE_ID = 753163836022063171
  # Obsolete Orange role ID
  OBSOLETE_ORANGE_ROLE_ID = 753163836022063170
  # Breathtaking Blue role ID
  BREATHTAKING_BLUE_ROLE_ID = 753163836022063169
  # Marvelous Magenta role ID
  MARVELOUS_MAGENTA_ROLE_ID = 753163836022063168
  # Lullaby Lavender role ID
  LULLABY_LAVENDER_ROLE_ID = 753163836022063167
  # Retro Red role ID
  RETRO_RED_ROLE_ID = 753163836022063166
  # Whitey White role ID
  WHITEY_WHITE_ROLE_ID = 753163836022063165
  # Override: 💯 Bearer of the Wand role ID
  OVERRIDE_BEARER_OF_THE_WAND_POG_ROLE_ID = 753163836022063164
  # Override: 🌀 Mewman Monarch role ID
  OVERRIDE_MEWMAN_MONARCH_ROLE_ID = 753163836005154896
  # Override: 🧡 Mewman Noble role ID
  OVERRIDE_MEWMAN_NOBLE_ROLE_ID = 753163836005154895
  # Override: 💛 Mewman Knight role ID
  OVERRIDE_MEWMAN_Knight_ROLE_ID = 753163836005154894
  # Override: 💜 Mewman Squire role ID
  OVERRIDE_MEWMAN_SQUIRE_ROLE_ID = 753163836005154893
  # Override: 💙 Mewman Citizen role ID
  OVERRIDE_MEWMAN_CITIZEN_ROLE_ID = 753163836005154892
  # 🎭 Head Creators role ID
  HEAD_CREATOR_ROLE_ID = 753163836005154891
  # 🔷 Cobalt Butterfly (default bot) role ID
  COBALT_BUTTERFLY_ROLE_ID = 753163836005154890
  # 🏆 You're Winner ! role ID
  EVENT_WINNER_ROLE_ID = 753163836005154889
  # ⚔️ Old Captain role ID
  OLD_CAPTAIN_ROLE_ID = 753163836005154888
  # 🔷 Cobalt's Mommy? role ID
  COBALT_MOMMY_ROLE_ID = 753163836005154887
  # 🔷 Cobalt's Artist role ID
  COBALT_ARTIST_ROLE_ID = 753163835975794740
  # 🖼️ Gif Master role ID
  GIF_MASTER_ROLE_ID = 753163835975794739
  # 💯 Bearer of the Wand role ID
  BEARER_OF_THE_WAND_POG_ROLE_ID = 753163835975794738
  # 🎖️Contributor role ID
  CONTRIBUTOR_ROLE_ID = 753163835975794737
  # 🏁 Event Host role ID
  EVENT_HOST_ROLE_ID = 753163835975794736
  # 😉 Emote Provider role ID
  EMOTE_PROVIDER_ROLE_ID = 753163835975794735
  # 🖥️ Bot Maintainer role ID
  BOT_MAINTAINER_ROLE_ID = 753163835975794734
  # 🎥 Movie Host role ID
  MOVIE_HOST_ROLE_ID = 753163835975794733
  # 🛡️ Old Guard role ID
  OLD_GUARD_ROLE_ID = 753163835975794732
  # Subreddit Affiliate role ID
  SUBREDDIT_AFFILIATE_ROLE_ID = 753163835975794731
  # 🎭 Content Creator role ID
  CONTENT_CREATOR_ROLE_ID = 753163835921399928
  # 🎨 Art Creator role ID
  ART_CREATOR_ROLE_ID = 753163835921399927
  # 🎬 Multimedia Creator role ID
  MULTIMEDIA_CREATOR_ROLE_ID = 753163835921399926
  # ✍️ Writing Creator role ID
  WRITING_CREATOR_ROLE_ID = 753163835921399925
  # 💝 Mewman Monarch role ID
  MEWMAN_MONARCH_ROLE_ID = 753163835921399924
  # 🧡 Mewman Noble role ID
  MEWMAN_NOBLE_ROLE_ID = 753163835921399923
  # 💛 Mewman Knight role ID
  MEWMAN_KNIGHT_ROLE_ID = 753163835921399922
  # 💜 Mewman Squire role ID
  MEWMAN_SQUIRE_ROLE_ID = 753163835921399921
  # 💙 Mewman Citizen role ID
  MEWMAN_CITIZEN_ROLE_ID = 753163835921399920
  # ✔️ Verified role ID
  VERIFIED_ROLE_ID = 753163835921399919
  # the all new nissan pathfinder role ID
  THE_ALL_NEW_NISSAN_PATHFINDER_ROLE_ID = 753163835900297225
  # Members role ID
  MEMBER_ROLE_ID = 753163835900297224
  # Art Event role ID
  ART_EVENT_ROLE_ID = 753163835900297223
  # DJ role ID
  DJ_ROLE_ID = 753163835900297222
  # Debate role ID
  DEBATE_ROLE_ID = 753163835900297221
  # Lounge role ID
  LOUNGE_ROLE_ID = 753163835900297220
  # Vent role ID
  VENT_ROLE_ID = 753163835900297219
  # Sandbox role ID
  SANDBOX_ROLE_ID = 753163835900297218
  # Bot Games role ID
  BOT_GAMES_ROLE_ID = 753163835900297217
  # Raffle role ID
  RAFFLE_ROLE_ID = 753163835900297216
  # SVTFOE News role ID
  SVTFOE_NEWS_ROLE_ID = 753163835862417488
  # SVTFOE Leaks role ID
  SVTFOE_LEAKS_ROLE_ID = 753163835862417487
  # Updates role ID
  UPDATE_ROLE_ID = 753163835862417486
  # 🤖 Bots role ID
  BOT_ROLE_ID = 753163835862417485
  # hits controller role ID
  HITS_CONTROLLER_ROLE_ID = 753163835862417484
  # Role Color Test 1 role ID
  ROLE_COLOR_TEST_1_ROLE_ID = 753163835862417483
  # Role Color Test 2 role ID
  ROLE_COLOR_TEST_2_ROLE_ID = 753163835862417482
  # Role Color Test 3 role ID
  ROLE_COLOR_TEST_3_ROLE_ID = 753163835862417481
  # 🔷 Cobalt's Squire role ID
  COBALT_SQUIRE_ROLE_ID = 755020794706264215
  
  # Channel IDs

  # read_me_first channel ID
  READ_ME_FIRST_CHANNEL_ID = 753163836521054271
  # additional_info channel ID
  ADDITIONAL_INFO_CHANNEL_ID = 753163836521054273
  # partners channel ID
  PARTNERS_CHANNEL_ID = 753163836521054274
  # introductions channel ID
  INTRODUCTIONS_CHANNEL_ID = 753163836521054275
  # server_feedback channel ID
  SERVER_FEEDBACK_CHANNEL_ID = 753163836521054276
  # emote_suggestions channel ID
  EMOTE_SUGGESTIONS_CHANNEL_ID = 753163836521054278
  # quoteboard channel ID
  QUOTEBOARD_CHANNEL_ID = 753163836844146769
  # general channel ID
  GENERAL_CHANNEL_ID = 753163836844146770
  # bot_commands channel ID
  BOT_COMMANDS_CHANNEL_ID = 753163836844146773
  # memes channel ID
  MEME_CHANNEL_ID = 753163836844146774
  # svtfoe_discussion channel ID
  SVTFOE_DISCUSSION_ID = 753163836844146776
  # svtfoe_gallery channel ID
  SVTFOE_GALLERY_ID = 753163836844146777
  # original_art channel ID
  ORIGINAL_ART_CHANNEL_ID = 753163837057794170
  # original_content channel ID
  ORIGINAL_CONTENT_CHANNEL_ID = 753163837057794171
  # entertainment channel ID
  ENTERTAINMENT_CHANNEL_ID = 753163837057794172
  # games channel ID
  GAME_CHANNEL_ID = 753163837057794173
  # tech channel ID
  TECH_CHANNEL_ID = 753163837057794174
  # moderation_channel channel ID
  MODERATION_CHANNEL_CHANNEL_ID = 753163837057794176
  # moderation_guidelines channel ID
  MODERATION_GUIDELINES_CHANNEL_ID = 753163837057794177
  # muted_users channel ID
  MUTED_USERS_CHANNEL_ID = 753163837057794178
  # cobalt-reports channel ID
  COBALT_REPORT_CHANNEL_ID = 753163837242605568
  # join_log channel ID
  JOIN_LOG_CHANNEL_ID = 753163837242605570
  # logbook channel ID
  LOGBOOK_CHANNEL_ID = 753163837242605571
  # staff_contact_logs channel ID
  STAFF_CONTACT_LOG_CHANNEL_ID = 753163837242605572
  # vent_space channel ID
  VENT_SPACE_CHANNEL_ID = 753163837703979060
  # debate channel ID
  DEBATE_CHANNEL_ID = 753163837703979061
  # bot_games channel ID
  BOT_GAME_CHANNEL_ID = 753163837703979062
  # alphabet channel ID
  ALPHABET_CHANNEL_ID = 753163837703979064
  # counting channel ID
  COUNTING_CHANNEL_ID = 753163837703979065
  # question_and_answer channel ID
  QUESTION_AND_ANSWER_CHANNEL_ID = 753163837703979066
  # word_association channel ID
  WORD_ASSOCIATION_CHANNEL_ID = 753163837703979067
  # general_vc channel ID
  GENERAL_VC_CHANNEL_ID = 753163838068621403
  # generally_vc channel ID
  GENERALLY_VC_CHANNEL_ID = 753163838068621404
  # music_vc channel ID
  MUSIC_VC_CHANNEL_ID = 753163838068621405
  # gaming_vc channel ID
  GAMING_VC_CHANNEL_ID = 753163838068621406
  # mod_vc channel ID
  MOD_VC_CHANNEL_ID = 753163838068621407
  # head_creator_hq channel ID (this is set to the moderation channel on the test server, though should be set to the channel with the same name on the main server)
  HEAD_CREATOR_HQ_CHANNEL_ID = 753163837057794176

  # Other IDs

  # Role button message ID (reaction roles in #read_me_first)
  ROLE_MESSAGE_ID = 753317076260880416
  # Voice channel IDs with their respective text channel IDs; in the format {voice => text}
  VOICE_TEXT_CHANNELS = {
    387802285733969920 => 307778254431977482, # General
    378857349705760779 => 378857881782583296, # Generally
    307763283677544448 => 307763370486923264, # Music
    307882913708376065 => 307884092513583124, # Gaming
  }.freeze
  # IDs of channels blacklisted from #quoteboard
  QUOTEBOARD_BLACKLIST = [
    307726630061735936, #news
    360720349421109258, #svtfoe_news
    382469794848440330, #vent_space
    418819468412715008  #svtfoe_leaks
  ].freeze
  # Content Creator role IDs
  CREATOR_ROLE_IDS = {
    art: 383960705365311488,
    multimedia: 383961150905122828,
    riting: 383961249899216898
  }.freeze
  # Scheduler constant
  SCHEDULER = Rufus::Scheduler.new

  # IDs of all opt-in roles
  OPT_IN_ROLES = [
    382433569101971456,
    310698748680601611,
    316353444971544577,
    402051258732773377,
    454304307425181696
  ].freeze
end

# Methods for convenience:

# Module containing convenience methods (and companion variables/constants) that aren't instance/class methods
module Convenience
  module_function

  # Rudimentary pluralize; returns pluralized str with added 's' only if the given int is not 1
  # @param  [Integer] int the integer to test
  # @param  [String]  str the string to pluralize
  # @return [String]  singular form (i.e. 1 squid) if int is 1, plural form (8 squids) otherwise
  def plural(int, str)
    return "#{int} #{str}s" unless int == 1
    "#{int} #{str}"
  end
  alias_method(:pl, :plural)
end

# YAML module from base Ruby
module YAML
  # Loads data from the YAML file at the given path, and yields the data to a block; after
  # block execution, writes the modified data to the file
  # NOTE: This only works for mutable data types; you must directly modify the block variable,
  # you cannot simply set it equal to another value!
  # @param      path [String] the path to the YAML file
  # @yieldparam data [Object] the data in the YAML file
  # @return          [void]   if a block was provided (as all processing is handled within block)
  # @return          [Object] if no block was provided; returns the data in the YAML file
  def self.load_data!(path, &block)
    data = YAML.load_file(path)
    if block_given?
      yield data
      File.open(path, 'w') { |f| YAML.dump(data, f) }
      nil
    else
      data
    end
  end
end

# Server class from discordrb
class Discordrb::Server
  # Gets a member from a given string, either user ID, user mention, distinct (username#discrim),
  # nickname, or username on the given server; options earlier in the list take precedence (i.e.
  # someone with the username GeneticallyEngineeredInklings will be retrieved over a member
  # with that as a nickname) and in the case of nicknames and usernames, it checks for the beginning
  # of the name (i.e. the full username or nickname is not required)
  #
  # @param  str [String]            the string to match to a member
  # @return     [Discordrb::Member] the member that matches the string, as detailed above; or nil if none found
  def get_user(str)
    return self.member(str.scan(/\d/).join.to_i) if self.member(str.scan(/\d/).join.to_i)
    members = self.members
    members.find { |m| m.distinct.downcase == str.downcase } ||
    members.find { |m| str.size >= 3 && m.display_name.downcase.start_with?(str.downcase) } ||
    members.find { |m| str.size >= 3 && m.name.downcase.start_with?(str.downcase) } ||
    members.find { |m| str.size >= 3 && m.display_name.downcase.include?(str.downcase) } ||
    members.find { |m| str.size >= 3 && m.name.downcase.include?(str.downcase) }
  end
end

# Message class from discordrb
class Discordrb::Message
  # Reaction control buttons, in order
  REACTION_CONTROL_BUTTONS = ['⏮', '◀', '⏹', '▶', '⏭']

  # Reacts to the message with reaction controls. Keeps track of an index that is yielded as a parameter to the given
  # block, which is executed each time the given user presses a reaction control button. The index cannot be outside
  # the given range. Accepts an optional timeout, calculated from the last time the user pressed a reaction button.
  # Additionally accepts an optional starting index (if not provided, defaults to the start of the given range).
  # This is a blocking function -- if user presses the stop button or if the timeout expires, all reactions are
  # deleted and the thread unblocks.
  # @param [User]           user           the user who these reaction controls pertain to
  # @param [Range]          index_range    the range that the given index is allowed to be
  # @param [Integer, Float] timeout        the length, in seconds, of the timeout
  #                                         (after these many seconds the controls are deleted)
  # @param [Integer]        starting_index the initial index
  #
  # For block { |index| ... }
  # @yield                      The given block is executed every time a reaction button (other than stop) is pressed.
  # @yieldparam [Integer] index the current index
  def reaction_controls(user, index_range, timeout = nil, starting_index = index_range.first, &block)
    raise NoPermissionError, "This message wasn't sent by the current bot!" unless self.from_bot?
    raise ArgumentError, 'The starting index must be within the given range!' unless index_range.include?(starting_index)

    # Reacts to self with each reaction button
    REACTION_CONTROL_BUTTONS.each { |s| self.react_unsafe(s) }

    # Defines index variable
    index = starting_index

    # Loops until stop button is pressed or timeout has passed
    loop do
      # Defines time when the controls should expire (timeout is measured from the time of the last press)
      expiry_time = timeout ? Time.now + timeout : nil

      # Awaits reaction from user and returns response (:first, :back, :forward, :last, or nil if stopped/timed out)
      response = loop do
        await_timeout = expiry_time - Time.now
        await_event = @bot.add_await!(Discordrb::Events::ReactionAddEvent,
                                      emoji: REACTION_CONTROL_BUTTONS,
                                      channel: self.channel,
                                      timeout: await_timeout)

        break nil unless await_event
        next unless await_event.message == self &&
            await_event.user == user
        break nil if await_event.emoji.name == '⏹'
        break await_event.emoji.name
      end

      # Cases response variable and changes the index accordingly (validating that it is within the
      # given index range), yielding to the given block with the index if it is changed;
      # removes all reactions and breaks loop if response is nil
      case response
      when '⏮'
        unless index_range.first == index
          index = index_range.first
          yield index
        end
        self.delete_reaction_unsafe(user, '⏮')
      when '◀'
        if index_range.include?(index - 1)
          index -= 1
          yield index
        end
        self.delete_reaction_unsafe(user, '◀')
      when '▶'
        if index_range.include?(index + 1)
          index += 1
          yield index
        end
        self.delete_reaction_unsafe(user, '▶')
      when '⏭'
        unless index_range.last == index
          index = index_range.last
          yield index
        end
        self.delete_reaction_unsafe(user, '⏭')
      when nil
        self.delete_all_reactions_unsafe
        break
      end
    end
  end

  # Alternative to the default `Message#create_reaction` method that allows for a custom rate limit to be set; unsafe,
  # as it can be set lower to the Discord minimum of 1/0.25
  # @param [String, #to_reaction] reaction   the `Emoji` object or unicode emoji to react with
  # @param [Integer, Float]       rate_limit the length of time to set as the rate limit
  def create_reaction_unsafe(reaction, rate_limit = 0.25)
    reaction = reaction.to_reaction if reaction.respond_to?(:to_reaction)
    encoded_reaction = URI.encode(reaction) unless reaction.ascii_only?
    RestClient.put(
        "#{Discordrb::API.api_base}/channels/#{self.channel.id}/messages/#{self.id}/reactions/#{encoded_reaction}/@me",
        nil, # empty payload
        Authorization: @bot.token
    )
    sleep rate_limit
  end
  alias_method :react_unsafe, :create_reaction_unsafe

  # Alternative to the default `Message#delete_reaction` method that allows for a custom rate limit to be set; unsafe,
  # as it can be set lower to the Discord minimum of 1/0.25
  # @param [User]                 user       the user whose reaction to remove
  # @param [String, #to_reaction] reaction   the `Emoji` object or unicode emoji to remove the reaction of
  # @param [Integer, Float]       rate_limit the length of time to set as the rate limit
  def delete_reaction_unsafe(user, reaction, rate_limit = 0.25)
    reaction = reaction.to_reaction if reaction.respond_to?(:to_reaction)
    encoded_reaction = URI.encode(reaction) unless reaction.ascii_only?
    RestClient.delete(
        "#{Discordrb::API.api_base}/channels/#{self.channel.id}/messages/#{self.id}/reactions/#{encoded_reaction}/#{user.id}",
        Authorization: @bot.token
    )
    sleep rate_limit
  end

  # Alternative to the default `Message#delete_all_reactions` method that allows for a custom rate limit to be set; unsafe,
  # as it can be set lower to the Discord minimum of 1/0.25
  # @param [Integer, Float] rate_limit the length of time to set as the rate limit
  def delete_all_reactions_unsafe(rate_limit = 0.25)
    RestClient.delete(
        "#{Discordrb::API.api_base}/channels/#{self.channel.id}/messages/#{self.id}/reactions",
        Authorization: @bot.token
    )
    sleep rate_limit
  end
end

# Commands module from discordrb
module Discordrb::Commands
  # Bucket class from discordrb
  class Bucket
    # Resets the number of requests by a thing
    # @param [#resolve_key, Integer, Symbol] thing the thing to be rate limited.
    def reset(thing)
      # Resolves key and deletes its entry in the bucket hash
      key = resolve_key thing
      @bucket.delete(key)
    end
  end

  # RateLimiter class from discordrb
  module RateLimiter
    # Resets the number of requests by a thing
    # @param [Symbol]                        key   the bucket to perform the rate limit request for.
    # @param [#resolve_key, Integer, Symbol] thing the thing to be rate limited.
    def reset(key, thing)
      # Do nothing unless the bucket actually exists
      if @buckets && @buckets[key]
        # Execute reset method
        @buckets[:key].reset(thing)
      end
    end
  end
end

# Integer class from base Ruby
class Integer
  # Converts self, as a length of time in seconds, into a string that describes its length (i.e. 3 hours,
  # 4 minutes and 5 seconds, etc.)
  # @param  [Integer] secs the number of seconds to convert
  # @return [String]       the length of time described
  def to_dhms
    dhms = ([self / 86400] + Time.at(self).utc.strftime('%H|%M|%S').split("|").map(&:to_i)).zip(['day', 'hour', 'minute', 'second'])
    dhms.shift while dhms[0][0] == 0
    dhms.pop while dhms[-1][0] == 0
    dhms.map! { |(v, s)| "#{v} #{s}#{v == 1 ? nil : 's'}" }
    return dhms[0] if dhms.size == 1
    "#{dhms[0..-2].join(', ')} and #{dhms[-1]}"
  end
end

# String class from base Ruby
class String
  # Parses the string at `self` with the valid time formatting "<number>[d,h,m,s]", repeating
  # (i.e "5d", "4h50m", "2h30m5s"), and returns integer representing that length of time
  # in seconds
  #
  # @return [Integer] the number of time in seconds; 0 if invalid string format
  def to_sec
    time_ary = self.scan(/[1-9]\d*[smhd]/i)
    sec = 0
    time_ary.each do |str|
      sec += str.to_i if str[-1].downcase == 's'
      sec += str.to_i * 60 if str[-1].downcase == 'm'
      sec += str.to_i * 3600 if str[-1].downcase == 'h'
      sec += str.to_i * 86400 if str[-1].downcase == 'd'
    end
    sec
  end
end

# Dataset class from Sequel
class Sequel::SQLite::Dataset
  # Updates the dataset with the conditions in `cond` to the data given in `data` if entries with the
  # conditions in `cond` exist; otherwise, inserts an entry into the dataset with the combined hash
  # of `cond` and `data`
  # @param [Hash] cond the data to query the dataset if entries exist that match it
  # @param [Hash] data the data to update the queried entries with
  def set_new(cond, data)
    if self[cond]
      self.where(cond).update(data)
    else
      self << cond.merge(data)
    end
    nil
  end
end
