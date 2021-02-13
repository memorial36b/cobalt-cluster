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
end