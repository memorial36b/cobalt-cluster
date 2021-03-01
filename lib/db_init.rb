# This file initializes the database properly if a fresh installation is being run.
# You can also use this file as a way to check the schema, as all dataset structures
# are defined in this file
require 'sequel'

# Database
DB = Sequel.sqlite("#{Bot::DATA_PATH}/data.db")

# Muted users dataset
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
  Integer :channel_id # Channel's ID
  String  :user_id    # User's ID
end

# Quoted messages dataset
DB.create_table? :quoted_messages do
  Integer :id # Message's ID
end

# Birthdays dataset
DB.create_table? :birthdays do
  Integer :id       # User's ID
  String  :birthday # User's birthday, in the form M/D
end

# Birthday messages dataset
DB.create_table? :birthday_messages do
  Integer :channel_id # Message channel's ID
  Integer :id         # Message's ID
end

# Boops dataset
DB.create_table? :boops do
  Integer :id        # Booping user's ID
  Integer :booped_id # Booped user's ID
  Integer :count     # Count of how many times booping user has booped this user
end

# Economy balances data set
DB.create_table? :econ_user_balances do
  primary_key :transaction_id, null: false # Unique auto-incrementing transaction id
  Integer :user_id, null: false            # User's ID
  Integer :timestamp, null: false          # UTC transaction timestamp
  Integer :amount, null: false             # Tranasction amount, how much was earned
end

# Ecnomony permanent balances data set
DB.create_table? :econ_user_perma_balances do
  Integer :user_id, null: false, primary_key: true # User's ID, unique primary key
  Integer :amount, null: false                     # Tranasction amount, how much was earned
end

# Economy last checkin time
DB.create_table? :econ_user_checkin_time do
  Integer :user_id, null: false, primary_key: true # User's ID, unique primary key
  Integer :checkin_timestamp                       # Last checkin UTC timestamp
end

# Economy inventory
DB.create_table? :econ_user_inventory do
  primary_key :entry_id, null: false        # Unique auto-incrementing used for identifying this particular item
  Integer     :owner_user_id, null: false   # User ID of the owner
  Integer     :item_id, null: false         # The unique identifier that determines what item it is
  Integer     :timestamp, null: false       # The utc timestamp of when the itme was purchased/received
  Integer     :expiration, null: true       # Optional expiration timestamp
  Integer     :value, null: false           # The value of the item (in Starbucks) at the time of purchase.
end

# Economy tags
DB.create_table? :econ_user_tags do
  String  :tag_name, null: false, primary_key: true # The name of the tag, must be unique
  Integer :item_entry_id, null: false, unique: true # Associated item entry in econ_user_inventory
  Integer :owner_user_id, null: false               # User ID of the owner
  String  :tag_content, null: false                 # The tag's message content
end

# Economy cutom commands
DB.create_table? :econ_custom_commands do
  String  :command_name, null: false                # The name of the command
  Integer :owner_user_id, null: false               # User ID of the owner
  Integer :item_entry_id, null: false, unique: true # Associated item entry in econ_user_inventory
  String  :command_content, null: false             # The command's message content
  primary_key([:command_name, :owner_user_id])
end

# Economy raffle, each entry is a ticket
DB.create_table? :econ_raffle do
  Integer :user_id, null: false # The user that bought the ticket.
end

# Generic user timezone
DB.create_table? :user_timezone do
  Integer :user_id, null: false, primary_key: true # User's ID, unique primary key
  String  :timezone, null: false                   # User's timezone
  Integer :last_changed, null: false               # Last changed timestamp
end

# User Timezones: Add last changed column
unless DB[:user_timezone].columns.include?(:last_changed)
  DB.alter_table(:user_timezone) do
    add_column :last_changed, Integer, null: false, default: 0 # Add last_changed column
  end
end