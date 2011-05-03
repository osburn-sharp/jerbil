#! /usr/bin/ruby
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
# Template for a supervisor script to stop a Jerbil-based service. Tailor to suit.
# This could be a single program that stops any jerbil service, but its probably
# easier to tailor this script for each service
#
# By default, outputs to stderr, unless quiet is selected. Could add another
# option to output to a file...
#

# require the service itself
require File.expand_path(File.dirname(__FILE__) + '/test_service')
# require the config module
require File.expand_path(File.dirname(__FILE__) + '/test_config')
# and require the version module
require File.expand_path(File.dirname(__FILE__) + '/version')

require 'jerbil/jerbil_service/sclient'
require 'optparse'

config_file = nil # let it be the default
verbose = false
quiet = false

OptionParser.new do |opts|

  opts.banner = "Usage: service-stop [opts]"
  opts.separator ""
  opts.separator " stop the given Jerbil Service"
  opts.separator ""

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

JerbilService::Supervisor.stop(RubyTest) do |rubytest|
  rubytest.verbose if verbose
  rubytest.quiet if quiet
  rubytest.config_file = config_file
end
