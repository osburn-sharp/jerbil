#! /usr/bin/ruby
#
# Description
#
# Author:: Robert Sharp
# Copyright:: Copyright (c) 2010 Robert Sharp
# License:: Open Software Licence v3.0
#
# This software is licensed for use under the Open Software Licence v. 3.0
# The terms of this licence can be found at http://www.opensource.org/licenses/osl-3.0.php
# and in the file copyright.txt. Under the terms of this licence, all derivative works
# must themselves be licensed under the Open Software Licence v. 3.0
# 
#
require 'rubygems'
root_dir = File.expand_path('..', File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(root_dir, 'lib'))
$LOAD_PATH.unshift(File.join(root_dir, 'test', 'lib'))



require 'jerbil/jerbil_service/sclient'
require 'jerbil/jerbil_service/utils'
require 'optparse'

config_file = nil # let it be the default
daemonize = true
log_to_syslog = true
verbose = true
quiet = false
my_service = nil

OptionParser.new do |opts|

  opts.banner = "Usage: jerbild [opts]"
  opts.separator ""
  opts.separator " start the Jerbil Daemon"
  opts.separator ""
  
  opts.on("-s", "--service [name]", String, "start the given service") do |name|
    my_service = name
  end

  opts.on("-n", "--no-daemon", "Do not daemonize") do
    daemonize = false
  end

  opts.on("-S", "--no-syslog", "Do not log to syslog") do
    log_to_syslog = false
  end

  opts.on("-c", "--config [file]", String, "use this config file to find Jerbil" ) do |cfile|
    if FileTest.readable?(cfile) then
      config_file = cfile
    else
      puts "Config file cannot be read."
      exit 1
    end
  end

  opts.on("-V", "--verbose", "output more information about what is going on ") do
    verbose = true
  end

  opts.on("-q", "--quiet", "output nothing") do
    quiet = true
  end

  opts.on("-h", "--help", "Provide Help") do |h|
    opts.separator ""
    puts opts
    exit 0
  end

end.parse!

unless my_service
  puts "Error: You must provide a service (-s name)"
  exit 1
else
  service_name = JerbilService::Utils.classify(my_service)
  require "#{my_service}"
  require "#{my_service}/config"
  require "#{my_service}/version"
  the_service = Module.const_get(service_name)
end

JerbilService::Supervisor.new(the_service) do |rubytest|
  rubytest.no_daemon unless daemonize
  rubytest.quiet if quiet
  rubytest.verbose if verbose
  rubytest.no_syslog unless log_to_syslog
  rubytest.config_file = config_file
end
