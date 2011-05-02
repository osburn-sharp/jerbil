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
require 'jerbil'
require 'jerbil/server'
require 'socket'
require 'drb'

hostname = Socket.gethostname
my_self = Jerbil::ServerRecord.new(hostname, 'ABCDE')

DRb.start_service
jerbild = DRbObject.new(nil, my_self.drb_address)

key_file = File.expand_path(File.dirname(__FILE__) + '/../test/private_key_file.asc')
my_key = File.readlines(key_file).join('')

puts "Stopping Jerbil Test Server"

begin
  jerbild.stop(my_key)
rescue DRb::DRbConnError
  #ignore it
end

puts "Am I still here? Bye"