# Cluster: src

This folder contains:
* the `dev` folder, which contains all crystals currently in development
* the `main` folder, which contains all crystals to be loaded by default
* `bot.rb`, the main program which loads all the dependencies and crystals as desired
* `crystal_template.erb`, an ERB template used to generate new crystals through the Rake `:generate` task
* the program's `Gemfile`

Ensure that the bundler gem is installed!