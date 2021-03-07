# Crystal: Economy Earning
require 'rufus-scheduler'
require 'set'
require 'uri'

# This crystal contains the portion of Cobalt's economy features that handle awarding points for activity.
# Note: This is separate due to the expectation that it will also be extremely large.
module Bot::EconomyPassive
  extend Discordrb::EventContainer
  extend Convenience
  include Constants

  # Scheduler constant
  SCHEDULER = Rufus::Scheduler.new

  # Path to economy data folder
  ECON_DATA_PATH = "#{Bot::DATA_PATH}/economy".freeze

  # Thread coordination
  DATA_LOCK = Mutex.new

  # Channels that don't earn points
  IGNORED_CHANNELS = [
    # text
    READ_ME_FIRST_CHANNEL_ID,
    ADDITIONAL_INFO_CHANNEL_ID,
    PARTNERS_CHANNEL_ID,
    QUOTEBOARD_CHANNEL_ID,
    BOT_COMMANDS_CHANNEL_ID,

    # voice
    MOD_VC_CHANNEL_ID,
    MUSIC_VC_CHANNEL_ID
  ].freeze

  # The minimum number of people actively voice chat required to earn points.
  MIN_VOICE_CONNECTED = 2

  #################
  ##   EVENTS    ##
  #################

  # Message event handler
  @@sent_messages = {} # map of channels to users participating
  @@message_bonus = {} # map of special message bonuses
  message do |event|
    next unless event.server == SERVER
    next if event.channel == nil || IGNORED_CHANNELS.include?(event.channel.id)
    next if event.user == nil

    # general chat awarding
    DATA_LOCK.synchronize do
      # add to sent messages
      if @@sent_messages[event.channel.id] == nil
        @@sent_messages[event.channel.id] = Set[]
      end

      @@sent_messages[event.channel.id].add(event.user.id)

      # queue up any necessary bonuses
      new_bonus = get_bonus_reward(event.user.id, event.channel.id, event.message)
      if not @@message_bonus[event.user.id].nil?
        old_bonus = @@message_bonus[event.user.id]
        @@message_bonus[event.user.id] = max(old_bonus, new_bonus)
      elsif new_bonus > 0
        @@message_bonus[event.user.id] = new_bonus
      end
    end
  end

  # Voice handler
  @@voice_connected = {} # map of channels to users participating
  voice_state_update do |event|
    next unless event.server == SERVER
    next if event.channel != nil && IGNORED_CHANNELS.include?(event.channel.id)

    DATA_LOCK.synchronize do
      # create necessary sets
      if event.old_channel != nil && @@voice_connected[event.old_channel.id] == nil
        @@voice_connected[event.old_channel.id] = Set[]
      end
      if event.channel != nil && @@voice_connected[event.channel.id] == nil
        @@voice_connected[event.channel.id] = Set[]
      end

      # user disconnected
      if event.channel == nil && event.old_channel != nil
        @@voice_connected[event.old_channel.id].delete(event.user.id)
        next # done processing
      end
      
      # safely handle weird states
      next unless event.channel != nil || event.user == nil
      
      # user switched channels
      if event.old_channel != nil and event.channel != event.old_channel
        @@voice_connected[event.old_channel.id].delete(event.user.id)
        # continue on
      end

      # remove users that have deafened themselves
      if event.deaf || event.self_deaf
        @@voice_connected[event.channel.id].delete(event.user.id)
        next # done processing
      end
      
      # user is connected and not deafened, let them gain points
      @@voice_connected[event.channel.id].add(event.user.id)
    end
  end

  ################################
  ##   RUFUS SCHEDULED EVENTS   ##
  ################################
  SCHEDULER.every '1m' do
    DATA_LOCK.synchronize do
      # reward points for voice chat, can only earn points from one channel
      voice_earned = {}
      @@voice_connected.each do |channel_id, connected|
        next unless connected.count >= MIN_VOICE_CONNECTED

        # reward points to all users connected
        connected.each do |user_id|
          cur_value = voice_earned[user_id]
          cur_value = 0 if cur_value == nil

          new_value = get_voice_reward(channel_id)
          voice_earned[user_id] = max(cur_value, new_value)
        end
      end

      # award points to each user participating in voice
      voice_earned.each do |user, earnings|
        Bot::Bank::deposit(user, earnings)
      end

      # users earn points from the highest valued chat
      chat_earned = {}
      @@sent_messages.each do |channel_id, users|
        next if users.empty?

        # reward max message value points to each user
        users.each do |user_id|
          cur_value = chat_earned[user_id]
          cur_value = 0 if cur_value == nil

          new_value = get_chat_reward(channel_id)
          chat_earned[user_id] = max(cur_value, new_value)
        end
      end

      # award points to each user participating in chat
      chat_earned.each do |user, earnings|
        Bot::Bank::deposit(user, earnings)
      end

      # clear message values, will be repopulated
      @@sent_messages.clear()

      # reward bonuses
      @@message_bonus.each do |user, bonus|
        Bot::Bank::deposit(user, bonus)
      end

      # clear bonuses, will be repopulated
      @@message_bonus.clear()
    end
  end

  ##########################
  ##   HELPER FUNCTIONS   ##
  ##########################
  module_function
  
  # Get the Starbucks value for the specified action.
  # @param [String] action_name The action's name.
  # @return [Integer] Startbucks earned by the action. 
  def get_action_earnings(action_name)
    points_yaml = YAML.load_data!("#{ECON_DATA_PATH}/point_values.yml")
    return points_yaml[action_name]
  end

  # Get the reward value for voice activity in the specified channel.
  # @param [Integer] channel_id The channel the user is connected to.
  # @return [Integer] The points earned by the activity.
  def get_voice_reward(channel_id)
    reward = get_action_earnings('activity_voice_chat')
    return reward.nil? ? 0 : reward
  end

  # Get the reward value for chatting in the specified channel.
  # @param [Integer] channel_id The channel id the activity occurred on.
  # @param [Integer] user_id    The user's id.
  # @param [Integer] is_voice   Is this a voice channel?
  # @return [Integer] The points earned by the activity.
  def get_chat_reward(channel_id)
    reward = nil

    case channel_id
    when SVTFOE_DISCUSSION_ID
      reward = get_action_earnings('activity_starvs_discussion')
    else
      reward = get_action_earnings('activity_text_chat')
    end

    return reward.nil? ? 0 : reward
  end

  # Give the bonus reward for special channels if the message meets the
  # channel's criteria.
  # @param [Integer] user_id            The user to reward.
  # @param [Integer] channel_id         The channel the message was sent on.
  # @param [Discordrb::Message] message The message.
  def get_bonus_reward(user_id, channel_id, message)
    reward = 0

    case channel_id
    when SVTFOE_GALLERY_ID
      reward = get_action_earnings('activity_share_gallery') if
        image?(message) or link?(message)
    when ORIGINAL_ART_CHANNEL_ID
      reward = get_action_earnings('activity_share_art') if
        image?(message) or link?(message)
    when ORIGINAL_CONTENT_CHANNEL_ID
      reward = get_action_earnings('activity_share_content') if
        image?(message) or link?(message)
    end

    return reward.nil? ? 0 : reward
  end

  # Check if a message has an image attachment.
  # @param [Discordrb::Message] message The message.
  # @return [bool] Has message?
  def image?(message)
    # if message has image award bonus Starbucks
    return false if message.nil? or message.attachments.nil?

    has_image = false
    message.attachments.each do |attachment|
      has_image = attachment.image?
      break if has_image
    end

    return has_image
  end

  # Check if a message has a link.
  # @param [Discordrb::Message] message The message.
  # @return [bool] Has link?
  def link?(message)
    return false if message.nil? or message.content.nil?
    return message.content =~ /#{URI::regexp(['http', 'https'])}/
  end
end