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

#
# Test version of Jerbil Server
#

require 'jerbil'
require 'jerbil/server'
require 'jerbil/config'
require 'jelly'
require 'jeckyl'
require 'socket'
require 'drb'


hostname = Socket.gethostname
my_self = Jerbil::ServerRecord.new(hostname, 'ABCDE')
#another = Jerbil::Server.new('antonia', 'JKLMNOP')
#servers = [my_self, another]

config_file = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/jerbil')

options = Jerbil::Config.new(config_file)
puts options.inspect

servers = options.delete(:servers)

# prevent the server from generating syslogs
Jelly.disable_syslog

$SAFE = 1 # using DRb, so prevent anything nasty

jerbild = Jerbil.new(my_self, servers, options)

DRb.start_service(my_self.drb_address, jerbild)

puts "Started Jerbil Test Server in foreground. Please wait"

DRb.thread.join
