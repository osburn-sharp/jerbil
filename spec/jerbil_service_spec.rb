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

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'jerbil/jerbil_service_class'
require File.expand_path(File.dirname(__FILE__) + '/../test/test_service')
require 'socket'

jconfig = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/jerbil')
tconfig = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/test')

describe "Test Service Class" do



  it "should start and stop OK" do
    tservice = TestService.new(:log_dir => "/home/robert/dev/projects/jerbil/log", :log_level => :debug, :jerbil_config=>jconfig, :exit_on_stop=>false)
    tservice.action.should == "Hello"
    service = tservice.my_service
    #service.stop(false) # make sure you do not kill anything
  end


end