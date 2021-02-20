# Required gems for the base bot
# NOTE: Ensure the bundler gem is installed!
require 'bundler/setup'
require 'discordrb'
require 'yaml'

# The main bot
# All individual crystals will be submodules of this; this gives them access to the main 
# bot object through a constant, as well as a constant containing the path to the data folder
module Bot
  # Loads config file into struct and parses info into a format readable by CommandBot constructor
  config = OpenStruct.new(YAML.load_file '../config.yml')
  config.client_id = config.id
  config.delete_field(:id)
  config.type = (config.type == 'user') ? :user : :bot
  config.parse_self = !!config.react_to_self
  config.delete_field(:react_to_self)
  config.help_command = config.help_alias || false
  config.delete_field(:help_alias)
  config.spaces_allowed = config.spaces_allowed.class == TrueClass
  config.webhook_commands = config.react_to_webhooks.class == TrueClass
  config.delete_field(:react_to_webhooks)
  config.ignore_bots = !config.react_to_bots
  config.log_mode = (%w(debug verbose normal quiet silent).include? config.log_mode) ? config.log_mode.to_sym : :normal
  config.fancy_log = config.fancy_log.class == TrueClass
  config.suppress_ready = !config.log_ready
  config.delete_field(:log_ready)
  config.redact_token = !(config.log_token.class == TrueClass)
  config.delete_field(:log_token)
  # Game is stored in a separate variable as it is not a bot attribute
  game = config.game
  config.delete_field(:game)
  # Cleans up config struct by deleting all nil entries
  config = OpenStruct.new(config.to_h.reject { |_a, v| v.nil? })

  puts '==CLUSTER: A Clunky Modular Ruby Bot Framework=='

  # Prints an error message to console for any missing required components and exits
  if config.client_id.nil?
    puts '- ERROR: Client ID not found in config.yml'
  end
  if config.token.nil?
    puts '- ERROR: Token not found in config.yml'
  end
  if config.prefix.empty?
    puts '- ERROR: Command prefix not found in config.yml'
  end
  if config.client_id.nil? || config.token.nil? || config.prefix.empty?
    puts 'Exiting.'
    exit(false)
  end

  puts 'Initializing the bot object...'

  # Creates the bot object using the config attributes; this is a constant 
  # in order to make it accessible by crystals
  BOT = Discordrb::Commands::CommandBot.new(config.to_h)

  # Sets bot's playing game
  BOT.ready { BOT.game = game.to_s }

  puts 'Done.'

  # Full path string for the crystal data folder (data in parent)
  DATA_PATH = File.expand_path('../data')

  puts 'Loading additional libraries...'

  # Loads files from lib directory in parent
  Dir['../lib/*.rb'].each do |path| 
    load path
    puts "+ Loaded file #{path[3..-1]}"
  end
  
  # load helper modules that require db after lib is loaded
  Dir['helper/*.rb'].each do |path| 
    load path
    puts "+ Loaded file #{path[3..-1]}"
  end

  puts 'Done.'

  # Loads a crystal from the given file and includes the module into the bot's container.
  # 
  # @param file [File] the file to load the crystal from. Filename must be the crystal 
  #                    name in snake case, or this will not work! (The crystal template generator
  #                    will do this automatically.)
  def self.load_crystal(file_path)
    module_name = File.basename(file_path, '.*').split('_').map(&:capitalize).join
    load file_path
    BOT.include! self.const_get(module_name)
    puts "+ Loaded crystal #{module_name}"
  end

  # Loads crystals depending on command line flags.
  # If 'main' is provided, all main crystals are loaded. If 'dev' is provided, all development crystals are loaded.
  if ARGV.include? 'main'
    puts 'Loading main crystals...'
    Dir['main/*.rb'].each do |file|
      load_crystal(file)
    end
    puts 'Done.'
  end
  if ARGV.include? 'dev'
    puts 'Loading dev crystals'
    Dir['dev/*.rb'].each do |file|
      load_crystal(file)
    end
    puts 'Done.'
  end

  puts "Starting bot with logging mode #{config.log_mode.to_s}..."
  BOT.ready { puts 'Bot started!' }

  unless ARGV.include? 'dryrun' # we don't actually run in dry run mode
    # After loading all desired crystals, runs the bot
    BOT.run
  else
    puts 'dryrun complete'
  end
end