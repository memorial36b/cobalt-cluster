#!/usr/bin/env ruby

system("cd src; bundle install")

system("cd src; ruby bot.rb #{ARGV.join(' ')}")