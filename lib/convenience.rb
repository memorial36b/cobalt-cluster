require 'yaml'

module Convenience
  # StarDis server object
  SERVER = Bot::BOT.ready { Bot::BOT.server(297550039125983233) }
  # My user ID
  MY_ID = 220509153985167360
  # Member role ID
  MEMBER_ID = 308992021664759809
  # Moderator role ID
  MODERATOR_ID = 302641262240989186
  # Administrator role ID
  ADMINISTRATOR_ID = 302641256100659200

  # YAML module imported from base Ruby
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

  # Server class imported from Discordrb module; adds method 
  # getting user from ID, mention or username
  class Discordrb::Server
    # Gets a member from a given string, either user ID, user mention, distinct (username#discrim), 
    # username, or nickname on the given server; options earlier in the list take precedence (i.e. 
    # someone with the username GeneticallyEngineeredInklings will be retrieved over a member
    # with that as a nickname)
    #
    # @param  str [String]            the string to match to a member
    # @return     [Discordrb::Member] the member that matches the string, as detailed above; or nil if none found
    def get_user(str)
      self.members # recaches members
      if self.member(str.scan(/\d/).join.to_i)
        self.member(str.scan(/\d/).join.to_i)
      elsif self.members.find { |m| m.distinct.downcase == str.downcase }
        self.members.find { |m| m.distinct.downcase == str.downcase }
      elsif self.members.find { |m| m.name.downcase == str.downcase }
        self.members.find { |m| m.name.downcase == str.downcase }
      elsif self.members.find { |m| m.display_name.downcase == str.downcase }
        self.members.find { |m| m.display_name.downcase == str.downcase }
      else
        nil
      end
    end
  end

    # Integer class imported from base Ruby
    class Integer
      # Takes `self` as a length of time in seconds and returns string of that time converted to
      # days, hours, minutes and seconds
      #
      # @return [String] length of time in d, h, m, s format
      def to_dhms
        if self < 60
          "#{self % 60}s"
        elsif self < 3600
          "#{(self / 60).floor}m, #{self % 60}s"
        elsif self < 86400
          "#{(self / 3600).floor}h, #{((self % 3600) / 60).floor}m, #{self % 60}s"
        else
          "#{(self / 86400).floor}d, #{((self % 86400) / 3600).floor}h, #{((self % 3600) / 60).floor}m, #{self % 60}s"
        end
      end
    end

    # String class imported from base Ruby
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
  end