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
  # { user_id, timezone }
  USER_TIMEZONE = DB[:user_timezone]

  # Get the user's timezone.
  # @param [Integer] user_id user id
  # @return [TZInfo::Timezone] timezone, default: UTC-0
  def GetUserTimezone(user_id)
    user_timezone = USER_TIMEZONE[user_id: user_id]
    return TZInfo::Timezone.get('Etc/UTC') if user_timezone == nil

    begin
      user_timezone = user_timezone[:timezone]
      user_timezone = user_timezone.nil? ? "NULL" : user_timezone
      return TZInfo::Timezone.get(user_timezone)
    rescue => e
      return TzInfo::Timezone.get('Etc/UTC') if tz == nil
    end
  end

  # Set the user's timezone.
  # @param [Integer] user_id       user id
  # @param [String]  timezone_name time zone identifier
  # @return [bool] Could the timezone be set?
  def SetUserTimezone(user_id, timezone_name)
  	# validate
	  begin
      tz = TZInfo::Timezone.get(timezone_name)
    rescue => e
      return false
    end

    # store in database
    user_timezone = USER_TIMEZONE[user_id: user_id]
  	if user_timezone == nil
      USER_TIMEZONE << { user_id: user_id, timezone: timezone_name }
    else
      user_timezone = USER_TIMEZONE.where(user_id: user_id)
      user_timezone.update(timezone: timezone_name)
    end
  	
  	return true  
  end

  # Get a DateTime representation of the utc timestamp in the user's local timezone.
  # @param [Integer] user_id   user id
  # @param [Integer] timestamp Unix timestamp
  # @return [DateTime] datetime in user's local timezone
  def GetTimestampInUserLocal(user_id, timestamp)
    tz = GetUserTimezone(user_id)
    timestamp = TZInfo::Timestamp.utc(timestamp)
    return tz.utc_to_local(timestamp).to_datetime
  end

  # Get the DateTime of now in the user's timezone.
  # @param [Integer] user_id  user id
  # @return [DateTime] now in user's local timezone 
  def GetUserNow(user_id)
    tz = GetUserTimezone(user_id)
    return tz.now.to_datetime
  end

  # Get the DateTime of today (start of day) in the user's timezone.
  # @param [Integer] user_id  user id
  # @return [DateTime] today in user's local timezone 
  def GetUserToday(user_id)
    today = GetUserNow(user_id)

    # strip hours, minutes, seconds, fractional seconds
    day_offset = 
      (today.hour) / 24.0 + 
      (today.min / (24.0 * 60.0)) +
      (today.sec / (24.0 * 60.0 * 60.0))
      (today.second_fraction / (24.0 * 60.0 * 60.0))
    today -= day_offset

    return today
  end

  # Get the DateTime of the past monday (start of day) in the user's timezone.
  # @param [Integer] user_id  user id
  # @return [DateTime] past monday in user's local timezone
  # Note: Returns today if today is monday. 
  def GetUserPastMonday(user_id)
    today = GetUserToday(user_id)
    wwday = today.cwday - 1
    return today - wwday
  end

  # Get today in the specified timezone.
  # @param [String] timezone_name the timezone name
  # @return [DateTime] Today at 5:00 PM in the specified timezone.
  def GetTodayInTimezone(timezone_name)
    tz = TZInfo::Timezone.get(timezone_name)

    # strip hours, minutes, seconds, fractional seconds
    today = tz.now.to_datetime
    day_offset = 
      (today.hour) / 24.0 + 
      (today.min / (24.0 * 60.0)) +
      (today.sec / (24.0 * 60.0 * 60.0))
      (today.second_fraction / (24.0 * 60.0 * 60.0))
    today -= day_offset

    return today
  end
end