#!/usr/bin/env ruby
require 'yaml'

# Catch sigterm and handle it gracefully
shut_down = "\nCatch em all another time..."
["INT", "TERM"].each{ |t| Signal.send( :trap, t ) {puts shut_down; exit} }

# Read in the settings file and set some variables
settings      = YAML.load_file( File.expand_path("../config/settings.yml", __FILE__) )
locations     = settings["locations"]
credentials   = settings["credentials"]

# Setup variables to store commands for creating threads
threads, cmds = Array.new, ["grunt build"]

# Setup variables for looping over locations and sequentially using credentials
# found in the 'credentials' block of the settings file.
last          = locations.size - 1
cred_index    = 0

# Loop over locations and build a command for starting up a pokemap server.
# Uses credentials from the settings file, restarting from the beginning when it
# hits the last set of credentials.
locations.each_with_index do |(place, location), index|
  cred_index = 0 if cred_index == credentials.size

  user  = credentials[cred_index]['username']
  pass  = credentials[cred_index]['password']

  # Get the file path to runserver.py, relative to findEmAll.rb. Build the command
  # to run from there.
  file  = "#{File.expand_path( "../runserver.py", __FILE__ )}"
  cmd   = "python #{file} -a ptc -u '#{user}' -p '#{pass}' -l #{location} -st 10 -sd 3"

  # Tack on arguments to the runserver.py command.
  # Need just 1 web server, so only the last location starts one up. Tack on the
  # -cd flag to clear the database when the first server starts.
  cmd << " -ns"        if index != last
  cmd << " -H 0.0.0.0" if index == last
  cmd << " -cd"        if index == 0 # clear db on first start

  # Uncomment to suppress python output
  # cmd << " > /dev/null 2>&1"

  cmds << cmd
  cred_index += 1
end

puts "Looking for Pokemon at: #{locations.keys.join(", ")} \n"

# Start up the commands in their own thread
cmds.each do |cmd|
  Thread.new { system cmd }
  sleep 3
end

# Block until all threads are complete, which will be when we send a sigterm
Process.waitall
