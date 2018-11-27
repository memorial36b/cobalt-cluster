#!/usr/bin/env ruby

require 'erb'

class String
  # Converts strings of CamelCase format to snake_case format; clone of 
  # the Rails ActiveSupport underscore method, with edits as per StackOverflow
  def snakeize
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("- ", "_").
    downcase
  end
end

# This program automatically generates a crystal starter with the name given as the
# command line argument when running this program. The generated starter is placed 
# in the dev directory.

if ARGV.empty?
  raise 'Crystal name not found!'
  exit(false)
end

renderer = ERB.new(File.read('crystal_template.erb'))

crystal_name = ARGV[0]
file_name = "#{crystal_name.snakeize}.rb"

File.open("dev/#{file_name}", 'w') do |file|
  file.write(renderer.result)
end

puts "Generated new crystal #{crystal_name} at file dev/#{file_name}"