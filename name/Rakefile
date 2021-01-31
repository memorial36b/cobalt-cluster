require 'erb'
require 'fileutils'

task :default => ['run:main']

desc 'Install dependencies with bundle install command'
task :dependencies do
  unless system('bundle check')
    puts "(Don't worry, cluster will handle this right now)"
    system("bundle install")
  end
end

namespace :run do
  desc 'Run the bot with the main crystals'
  task :main => ['dependencies'] do |event|
    # Changes directory to src
    Dir.chdir('src') do
      # Runs the main bot script with main argument
      system("ruby bot.rb main")
    end
  end

  desc 'Run the bot with the dev crystals'
  task :dev => ['dependencies'] do |event|
    # Changes directory to src
    Dir.chdir('src') do
      # Runs the main bot script with dev argument
      system("ruby bot.rb dev")
    end
  end

  desc 'Run the bot with all crystals (main and dev)'
  task :all => ['dependencies'] do |event|
    # Changes directory to src
    Dir.chdir('src') do
      # Runs the main bot script with main and dev argument
      system("ruby bot.rb main dev")
    end
  end
end

desc 'Remove git repository files'
task :remove_git do |event|
  FileUtils.remove_dir('.git') if Dir.exist? '.git'
  FileUtils.remove('.gitignore') if File.exist? '.gitignore'
  puts 'Removed repository files.'
end

desc 'Generate a new crystal in the src/dev folder (argument: crystal name in CamelCase)'
task :generate, [:CrystalName] do |event, args|
  args.with_defaults(:CrystalName => 'DefaultCrystal')

  # Defines renderer, crystal name and file name (crystal name converted from CamelCase to snake_case)
  renderer = ERB.new(File.read('src/crystal_template.erb'))
  crystal_name = args.CrystalName
  file_name = crystal_name.gsub(/::/, '/').gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
              gsub(/([a-z\d])([A-Z])/,'\1_\2').tr("- ", "_").downcase + ".rb"

  # Writes the filled crystal template to the file with the given name in src/dev
  File.open("src/dev/#{file_name}", 'w') do |file|
    file.write(renderer.result(binding))
  end

  # Outputs result to console
  puts "Generated new crystal #{crystal_name}, file src/dev/#{file_name}"
end