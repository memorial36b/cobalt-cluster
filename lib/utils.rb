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
    SERVER = Bot::BOT.server(297550039125983233)
  end
  # My user ID
  MY_ID = 220509153985167360
  # Member role ID
  MEMBER_ID = 308992021664759809
  # Moderator role ID
  MODERATOR_ID = 302641262240989186
  # Administrator role ID
  ADMINISTRATOR_ID = 302641256100659200
  # Scheduler constant
  SCHEDULER = Rufus::Scheduler.new
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