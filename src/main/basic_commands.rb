# Crystal: BasicCommands
require 'open3'

# This crystal contains the basic commands of the bot, such as ping and exit.
module Bot::BasicCommands
  extend Discordrb::Commands::CommandContainer
  include Constants

  # Ping command
  command :ping do |event|
    break unless event.user.id == OWNER_ID || COBALT_DEV_ID.include?(event.user.id) || event.user.role?(COBALT_MOMMY_ROLE_ID) || event.user.role?(MODERATOR_ROLE_ID)
    ping = event.respond '**P** **O** **N** **G**'
    ping.edit "**P** **O** **N** **G** **|** **#{(Time.now - event.timestamp)*100}ms**"
    sleep 10
    ping.delete
  end

  # Build Version command - Should be in this format: Build MM/DD/YYYY - Revision X (revision number should start at 0)
  command :build do |event|
    break unless event.user.id == OWNER_ID || COBALT_DEV_ID.include?(event.user.id) || event.user.role?(COBALT_MOMMY_ROLE_ID)

    # Checking various parameters about the current local and remote instance of Cobalt. err and status are not used but are required to keep the output clean. Refer to https://git-scm.com/docs/git-show for documentation on --format. strip! removes the preceding and trailing whitespace.

    commit_hash, err, status = Open3.capture3("git show --quiet --format=format:%h")
    commit_hash.strip!
    commit_hash_full, err, status = Open3.capture3("git show --quiet --format=format:%H")
    commit_hash_full.strip!
    author_name, err, status = Open3.capture3("git show --quiet --format=format:%an")
    author_name.strip!
    author_date, err, status = Open3.capture3("git show --quiet --format=format:%ad")
    author_date.strip!
    commit_subject, err, status = Open3.capture3("git show --quiet --format=format:%s")
    commit_subject.strip!
    current_branch, err, status = Open3.capture3("git branch --show-current")
    current_branch.strip!
    last_pull_attempted, err, status = Open3.capture3("stat -c %y ../.git/FETCH_HEAD")
    last_pull_attempted.strip!
    remote_repo_url, err, status = Open3.capture3("git remote get-url origin")
    remote_repo_url.strip!

    # Check to see if any generated files exist in /src/ These generated files indicate what mode Cobalt is being run on as well as if the auto-updater script is present and being utilized. Mode indicators are deleted & generated in Rakefile. Auto-updater indicators are generated in the auto-updater script and deleted only when the +exit command is used. Also checks which crystals should be loaded per the run mode

    if File.exist? 'Main.txt'
      run_mode = File.basename("Main.txt", ".txt")
      active_crystals = Dir["../src/main/*.rb"]
    elsif File.exist? 'Dev.txt'
      run_mode = File.basename("Dev.txt", ".txt")
      active_crystals_a1 = Dir["../src/dev/*.rb"]
      active_crystals_a2 = Dir["../src/helper/*.rb"]
      active_crystals = active_crystals_a1 + active_crystals_a2
    elsif File.exist? 'All.txt'
      run_mode = File.basename("All.txt", ".txt")
      active_crystals_a1 = Dir["../src/main/*.rb"]
      active_crystals_a2 = Dir["../src/dev/*.rb"]
      active_crystals_a3 = Dir["../src/helper/*.rb"]
      active_crystals = active_crystals_a1 + active_crystals_a2 + active_crystals_a3

    end

    if File.exist? "Updater-Enabled.txt"
      auto_updater_enabled = "Yes"
    else
      auto_updater_enabled = "No"
    end

    # Checks to see if Update_Check_Frequency.txt exists in /scr/ as well as reading the contents of the file. This file is generated via the auto-updater script at startup and is only deleted if +exit is used

    if File.exist? "Update_Check_Frequency.txt"
      file = File.open("Update_Check_Frequency.txt")
      auto_updater_frequency = "#{file.read} Minute(s)"
    else
      auto_updater_frequency = "Updater Disabled"
    end

    # Sends an embed with human-readable build and instance information. While most fields are present, some haven't been implemented yet and will be blank

    event.send_embed do |embed|

      embed.color = 0x65DDB7

      embed.author = {
          name: "Current Cobalt Build Info",
          url: "https://github.com/hecksalmonids/cobalt-cluster/tree/#{current_branch}",
          icon_url: 'https://cdn.discordapp.com/attachments/753163837057794176/805998319251882034/467450365055336448.png'
      }
      embed.thumbnail = {
          url: "https://cdn.discordapp.com/attachments/804750275793518603/819294692608442418/cobalt_icon_2.png"}

      embed.add_field(
          name: "Parameters",
          value: "Repo: [hecksalmonids/cobalt-cluster](#{remote_repo_url})
                  Branch: [#{current_branch}](https://github.com/hecksalmonids/cobalt-cluster/tree/#{current_branch})
                  Run Mode: #{run_mode}
                  Auto-Updater Present: #{auto_updater_enabled}
                  Crystals Loaded: \n```#{active_crystals}```"
      )

      embed.add_field(
          name: "Current Version",
          value: "Commit: [#{commit_hash}](https://github.com/hecksalmonids/cobalt-cluster/commit/#{commit_hash_full})
                  Commit Author: [#{author_name}](https://github.com/#{author_name})
                  Commit Date: #{author_date}
                  Last Update Attempt: #{last_pull_attempted}
                  Update Check Frequency: #{auto_updater_frequency}
                  Time Until Next Update Check:"
      )
    end
  end

  # Test Server Invte Command - Enables sending a link in chat to the Cobalt test server
  command :testserver do |event|
    break unless event.user.id == OWNER_ID || COBALT_DEV_ID.include?(event.user.id)
    ping = event.respond "Ask Phazite for test server link (unless you're Phazite)"
    sleep 10
    ping.delete
  end

  # Ded Chat Command
  command :ded do |event|
    break unless event.user.id == OWNER_ID || COBALT_DEV_ID.include?(event.user.id)
    ping = event.respond "https://tenor.com/view/the-dancing-dorito-irevive-this-chat-dance-gif-14308244"
  end


# Exit command
  command :exit do |event|
    # Breaks unless event user is Owner or Dev
    break unless event.user.id == OWNER_ID || COBALT_DEV_ID.include?(event.user.id)
    event.respond 'Shutting down.'
    # Deletes various status indicator files used by +build
    FileUtils.remove('Main.txt') if File.exist? 'Main.txt'
    FileUtils.remove('Dev.txt') if File.exist? 'Dev.txt'
    FileUtils.remove('All.txt') if File.exist? 'All.txt'
    FileUtils.remove('Updater-Enabled.txt') if File.exist? 'Updater-Enabled.txt'
    FileUtils.remove('Update_Check_Frequency.txt') if File.exist? 'Update_Check_Frequency.txt'
    exit
  end
end
