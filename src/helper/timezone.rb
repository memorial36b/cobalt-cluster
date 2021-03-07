# Module: Timezone
require 'tzinfo'
require 'date'

# Helper functions for timezone conversion and user timezone management.
# Note: Not defined in lib because DB must already be init'ed.
module Bot::Timezone
  include Constants
  include Convenience

  module_function
  
  # User timezones dataset
  # { user_id, timezone, last_changed }
  USER_TIMEZONE = DB[:user_timezone]

  # How long a user must wait before swapping timezones (in days)
  TIMEZONE_CHANGE_TIMEOUT = 7

  # Get the user's timezone.
  # @param [Integer] user_id user id
  # @return [TZInfo::Timezone] timezone, default: UTC-0
  def get_user_timezone(user_id)
    user_timezone = USER_TIMEZONE[user_id: user_id]
    return TZInfo::Timezone.get('Etc/UTC') if user_timezone == nil

    begin
      user_timezone = user_timezone[:timezone]
      user_timezone = user_timezone.nil? ? "NULL" : user_timezone
      return TZInfo::Timezone.get(user_timezone)
    rescue => e
      return TzInfo::Timezone.get('Etc/UTC')
    end
  end

  # Set the user's timezone.
  # @param [Integer] user_id       user id
  # @param [String]  timezone_name time zone identifier
  # @return [bool] Could the timezone be set?
  def set_user_timezone(user_id, timezone_name)
  	# validate
	  begin
      tz = TZInfo::Timezone.get(timezone_name)
    rescue => e
      return false
    end

    # store in database
    user_timezone = USER_TIMEZONE[user_id: user_id]
  	if user_timezone.nil?
      USER_TIMEZONE << {
        user_id: user_id, 
        timezone: timezone_name, 
        last_changed: utc_now.to_time.to_i
      }
    else
      # make sure they're not trying to play the system
      now = user_now(user_id)
      next_change =  get_next_time_can_change_timezone(user_id)
      return false if now < next_change

      user_timezone = USER_TIMEZONE.where(user_id: user_id)
      user_timezone.update(timezone: timezone_name)
      user_timezone.update(last_changed: utc_now.to_time.to_i)
    end
  	
  	return true  
  end

  # Get the next datetime the user can change their timezone. 
  # @param [Integer] user_id   user id
  # @return [DateTime] The next time they can modify their timezone.
  def get_next_time_can_change_timezone(user_id)
    user_timezone = USER_TIMEZONE[user_id: user_id]
    return utc_now() if user_timezone.nil? # no info, can change now
    
    last_time = user_timezone[:last_changed]
    last_time = timestamp_to_user(user_id, last_time)
    next_time = last_time + TIMEZONE_CHANGE_TIMEOUT
    return trim_to_start_of_day(next_time)
  end

  # Get a DateTime representation of the utc timestamp in the user's local timezone.
  # @param [Integer] user_id   user id
  # @param [Integer] timestamp Unix timestamp
  # @return [DateTime] datetime in user's local timezone
  def timestamp_to_user(user_id, timestamp)
    tz = get_user_timezone(user_id)
    timestamp = TZInfo::Timestamp.utc(timestamp)
    return tz.utc_to_local(timestamp).to_datetime
  end

  # Get a utc+0 for the given datetime for a user's timezone.
  # @param [DateTime] datetime DateTime in a specified timezone
  # @return [DateTime] utc+0 DateTime
  def user_to_utc(user_id, datetime)
    tz = get_user_timezone(user_id)
    return tz.local_to_utc(datetime)
  end

  # Get the DateTime of now in the user's timezone.
  # @param [Integer] user_id  user id
  # @return [DateTime] now in user's local timezone 
  def user_now(user_id)
    tz = get_user_timezone(user_id)
    return tz.now.to_datetime
  end

  # Get the DateTime of now in the utc+0 time zone.
  # @return [DateTime] now in utc+0
  def utc_now()
    tz = TZInfo::Timezone.get('Etc/UTC')
    tz.now.to_datetime
  end

  # Get the DateTime of today (start of day) in the user's timezone.
  # @param [Integer] user_id  user id
  # @return [DateTime] today in user's local timezone 
  def user_today(user_id)
    today = user_now(user_id)
    today = trim_to_start_of_day(today)
    return today
  end

  # Get the DateTime of tomorrow (start of day) in the user's timezone.
  # @param [Integer] user_id  user id
  # @return [DateTime] tomorrow in user's local timezone 
  def user_tomorrow(user_id)
    return user_today(user_id) + 1
  end

  # Get the DateTime of the past monday (start of day) in the user's timezone.
  # @param [Integer] user_id  user id
  # @return [DateTime] past monday in user's local timezone
  # Note: Returns today if today is monday. 
  def user_past_monday(user_id)
    today = user_today(user_id)
    wwday = today.cwday - 1
    return today - wwday
  end

  # Get today in the specified timezone.
  # @param [String] timezone_name the timezone name
  # @return [DateTime] Start of today in the specified timezone.
  def timezone_today(timezone_name)
    tz = TZInfo::Timezone.get(timezone_name)
    today = tz.now.to_datetime
    return trim_to_start_of_day(today)
  end

  # Get the next Friday in the specified timezone.
  # @param [String] timezone_name the timezone name
  # @return [DateTime] Next friday or today if today is Friday.
  def timezone_next_friday(timezone_name)
    tz = TZInfo::Timezone.get(timezone_name)
    today = trim_to_start_of_day(tz.now.to_datetime)
    offset = 5 - today.cwday
    offset += 7 if offset < 0 # role to next week
    return today + offset
  end

  # Push the datetime up to the start of the day.
  # @param [DateTime] datetime The datetime to trim.
  # @param [DateTime] The start of the day.
  def trim_to_start_of_day(datetime)
    # strip hours, minutes, seconds, fractional seconds
    day_offset = 
      (datetime.hour) / 24.0 + 
      (datetime.min / (24.0 * 60.0)) +
      (datetime.sec / (24.0 * 60.0 * 60.0))
      (datetime.second_fraction / (24.0 * 60.0 * 60.0))
    return datetime - day_offset
  end
end