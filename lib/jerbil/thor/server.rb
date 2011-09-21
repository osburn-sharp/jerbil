#
#
# = Title
#
# == SubTitle
#
# Author:: Robert Sharp
# Copyright:: Copyright (c) 2011 Robert Sharp
# License:: Open Software Licence v3.0
#
# This software is licensed for use under the Open Software Licence v. 3.0
# The terms of this licence can be found at http://www.opensource.org/licenses/osl-3.0.php
# and in the file copyright.txt. Under the terms of this licence, all derivative works
# must themselves be licensed under the Open Software Licence v. 3.0
#
# 
#

# define subcommands relating to Jerbil Servers
class Server < Thor

  default_task :local
  class_option :config, :aliases=>'-c', :desc=>'use the given config file'

  desc "local", "display information about the local jerbil server"
  def local
    config = Jerbil.get_config(options[:config])
    local = Jerbil.get_local_server(options[:config])
    puts "Checking for local Jerbil server"
    begin
      jerbs = local.connect
      started = jerbs.started
      puts "  Jerbil server found, version: #{jerbs.version}".green
      puts "  Server has been up since #{started.strftime('%d %b %Y at %H:%M')}"
      puts "  and has had #{jerbs.registrations.to_s} registrations"
    rescue Exception => err
      puts "  Server did not respond: #{err.message}".red.bold
    end

  end
  
  desc "list", "list information about the network's Jerbil servers"
  def list
    config = Jerbil.get_config(options[:config])
    puts "Jerbil is configured with the following servers:"
    config[:servers].each do |server|
      puts "  #{server.fqdn}, key: [#{server.key}]".cyan
    end
  
  end
  
  desc "check", "check servers"
  def check

    config = Jerbil.get_config(options[:config])
    puts "Jerbil server status is:"
  
    config[:servers].each do |server|
      connect = false
      version = "0"
      begin
        jerbs = server.connect
        jerbs.verify
        connect = true
        version = jerbs.version
      rescue
        # do nothing
      end
      if connect then
        puts "   #{server.fqdn}: #{version}".cyan
      else
        puts "   #{server.fqdn}: no response".yellow
      end
    end
  end
end
