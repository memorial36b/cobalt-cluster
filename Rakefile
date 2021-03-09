require 'erb'
require 'fileutils'

# handles running commands
class CommandRunner
  # create a new command runner
  def initializer()
    @cur_cmd_pid = nil
    ObjectSpace.define_finalizer(self, method(:finalize))
  end

  # kill zombie processes
  def finalize(object_id)
    kill_cmd()
  end

  # run a new command
  def run_cmd(command)
    @cur_cmd_pid = Process.spawn(command)
    _, status = Process.wait2(@cur_cmd_pid)
    raise RuntimeError, "Cmd failed to terminate (pid: #{@cur_cmd_pid})" unless status.exited?
    @cur_cmd_pid = nil # it ded fam

    # mimic system() return value
    return status.exited?
  end

  # kill the currently executing command
  def kill_cmd()
    pid = @cur_cmd_pid # avoid multi-threaded shenanies
    unless pid.nil?
      begin
        Process.kill('INT', pid)
      rescue Errno::ESRCH, RangeError
        puts "WARNING: Could find cmd (pid #{pid}) to kill it"
      rescue Errno::EPERM
        puts "ERROR: Insufficient permissions to kill (pid #{pid})"
      end

      begin
        # wait on pid, raise error if failed
        _, status = Process.wait2(pid)
      rescue SystemCallError
        # no child process with pid found, report
        puts "WARNING: There are no child processes (tried pid: #{pid})"
      end
    end
  end
end

# global command manager
CMD_RUNNER = CommandRunner.new()

# catches sigint (CTRL+C), kills current and bail
Signal.trap('INT') do
  print "INFO: Rake SIGINT terminated, exiting...\n"
  CMD_RUNNER.kill_cmd()
  exit -1
end

task :default => ['run:main']

desc 'Install dependencies with bundle install command'
task :dependencies do
  unless CMD_RUNNER.run_cmd('bundle check')
    puts "(Don't worry, cluster will handle this right now)"
    CMD_RUNNER.run_cmd("bundle install")
  end
end

namespace :run do
  desc 'Run the bot with the main crystals'
  task :main => ['dependencies'] do |event|
    # Changes directory to src
    Dir.chdir('src') do
      # Runs the main bot script with main argument
      CMD_RUNNER.run_cmd("ruby bot.rb main")
    end
  end

  desc 'Run the bot with the dev crystals'
  task :dev => ['dependencies'] do |event|
    # Changes directory to src
    Dir.chdir('src') do
      # Runs the main bot script with dev argument
      CMD_RUNNER.run_cmd("ruby bot.rb dev")
    end
  end

  desc 'Run the bot with all crystals (main and dev)'
  task :all => ['dependencies'] do |event|
    # Changes directory to src
    Dir.chdir('src') do
      # Runs the main bot script with main and dev argument
      CMD_RUNNER.run_cmd("ruby bot.rb main dev")
    end
  end

  desc 'Do a dry run of the bot with the main crystals'
  task :dryrunmain => ['dependencies'] do |event|
    # Changes director to src
    Dir.chdir('src') do
      # Runs the main bot script with main and dev argument
      CMD_RUNNER.run_cmd("ruby bot.rb main dryrun")
    end
  end

  desc 'Do a dry run of the bot with the dev crystals'
  task :dryrundev => ['dependencies'] do |event|
    # Changes director to src
    Dir.chdir('src') do
      # Runs the main bot script with main and dev argument
      CMD_RUNNER.run_cmd("ruby bot.rb main dev dryrun")
    end
  end

  desc 'Do a dry run of the bot with all of the crystals (main and dev)'
  task :dryrunall => ['dependencies'] do |event|
    # Changes director to src
    Dir.chdir('src') do
      # Runs the main bot script with main and dev argument
      CMD_RUNNER.run_cmd("ruby bot.rb main dev dryrun")
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