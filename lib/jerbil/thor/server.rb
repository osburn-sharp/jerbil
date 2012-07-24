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
  class_option :config, :aliases=>'-c', :desc=>'use the given config file', :default=>'/etc/jermine/jerbil-client.rb'
  class_option :verify, :aliases=>'-v', :desc=>'check the server is running'

  desc "local", "display information about the local jerbil server"
  def local
    config = Jerbil.get_config(options[:config])
    local = Jerbil::Servers.get_local_server(config[:environment])
    puts "Checking for local Jerbil server running in env: #{config[:environment]}"
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
    local = Jerbil::Servers.get_local_server(config[:environment])
    puts "Checking for Jerbil servers running in env: #{config[:environment]}"
    begin
      jerbs = local.connect
      remotes = jerbs.remote_servers
      remotes.each do |remote|
        if options[:verify] then
          begin
            remote.connect.verify
            puts "  #{remote.ident}".green
          rescue
            puts "  #{remote.ident}".red
          end
        else
          puts "  #{remote.ident}".cyan
        end
      end
    rescue Exception => err
      puts "  Server did not respond: #{err.message}".red.bold
    end
  
  end
  
  desc "secret", "generate a secret key for a new installation"
  def secret
    key = Digest::SHA1.hexdigest(Time.now.to_s + rand(12341234).to_s)
    puts 'secret "' + key + '"'
  end
  

end
