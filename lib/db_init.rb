# This file initializes the database properly if a fresh installation is being run.
# You can also use this file as a way to check the schema, as all dataset structures
# are defined in this file
require 'sequel'

# Database
DB = Sequel.sqlite("#{Bot::DATA_PATH}/data.db")

# Muted users dataset\
DB.create_table? :muted_users do
  Integer   :id           # User's ID
  Integer   :end_time     # Time when the mute ends, as a Unix timestamp
  TrueClass :trial?       # Whether this user is muted due to being on trial for ban
  String    :reason       # Reason for mute
  String    :opt_in_roles # IDs of user's opt-in roles prior to mute, as comma-separated string
end

# Muted channels dataset
DB.create_table? :muted_channels do
  Integer :id       # Channel's ID
  Integer :end_time # Time when the mute ends, as a Unix timestamp
  String  :reason   # Reason for mute
end

# Points dataset
DB.create_table? :points do
  Integer :id         # User's ID
  Integer :points     # Number of points user has
  Integer :decay_time # Time at which a point decay occurs
  String  :reason     # Reason for the last addition of points
end

# Channel blocks dataset
DB.create_table? :channel_blocks do
  Integer :id            # Channel's ID
  String  :blocked_users # IDs of all users blocked from the channel, as comma-separated string
end