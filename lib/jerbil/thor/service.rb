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

class Service < Thor

  default_task :list
  class_option :verbose, :default=>false, :aliases=>'-V', :desc=>'print more information'
  class_option :verify, :aliases=>'-v', :desc=>'check the service is running'
  class_option :config, :aliases=>'-c', :desc=>'use the given config file'

  desc "list", "List services"
  def list
    config = Jerbil.get_config(options[:config])
    local = Jerbil::Servers.get_local_server(config[:environment])
    services = []
    begin
      jerbs = local.connect
      services = jerbs.get_all(true) # ignore this access
    rescue
      puts "Failed to connect to the local Jerbil server".red.bold
      return
    end
    puts "There are #{services.length} services registered with Jerbil:"
    services.each do |s|
      puts "  #{s.name}[:#{s.env}]@#{s.host}:#{s.port}".cyan
      puts "    started at: #{s.registered_at.strftime('%d/%m/%y %H:%M')}" if options[:verbose]
      puts "    accessed #{s.access_count.to_s} times, last time at: #{s.accessed_at.strftime('%d/%m/%y %H:%M')}" if options[:verbose]
      if options[:verify] then
        if jerbs.service_missing?(s) then
          puts "  #{s.ident} has failed and should be removed".red
        else
          puts "  #{s.ident} responded".green
        end
      end
    end
  end

  desc "verify", "Verify that services are running"
  def verify
    config = Jerbil.get_config(options[:config])
    local = Jerbil.get_local_server(options[:config])
    services = []
    begin
      jerbs = local.connect
      services = jerbs.get_all(true) # ignore this access
    rescue
      puts "Failed to connect to the local Jerbil server".red.bold
    end
    puts "Checking #{services.length} services registered with Jerbil:"
    services.each do |s|
      if jerbs.service_missing?(s) then
        puts "  #{s.ident} has failed and should be removed".red
      else
        puts "  #{s.ident} responded".green
      end
    end
  end

end
