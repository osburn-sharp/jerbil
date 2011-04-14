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
# replace this to point to your config class
# require 'my_jeckyl_configurator'
require 'jerbil/config'
require 'jeckyl/errors'

config_file = File.expand_path(ARGV[0])

unless FileTest.readable?(config_file) then
  puts "Cannot open config file: #{config_file}"
  exit 0
end

puts "Checking: #{config_file}"

conf_ok = Jerbil::Config.check_config(config_file)

if conf_ok then
  puts "Config Syntax is OK"
else
  puts "Failed. Please check you configurator or config file"
end