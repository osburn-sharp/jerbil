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
require 'jerbil/errors'
require File.expand_path(File.dirname(__FILE__) + '/../test/test_service')
require 'socket'

config_dir = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/')
tconfig = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/test')

describe "Test Service Class for Errors (No Jerbil)" do


  it "should raise error on missing config" do
    jconfig = config_dir + '/config.not.there'
    options = {:log_dir => "/home/robert/dev/projects/jerbil/log", :log_level => :debug, :jerbil_config=>jconfig, :exit_on_stop=>false}
    lambda{TestService.new(options)}.should raise_error(Jerbil::ServiceConfigError)
  end

  it "should raise error on malformed config" do
    jconfig = config_dir + '/malformed'
    options = {:log_dir => "/home/robert/dev/projects/jerbil/log", :log_level => :debug, :jerbil_config=>jconfig, :exit_on_stop=>false}
    lambda{TestService.new(options)}.should raise_error(Jerbil::ServiceConfigError)
  end

  it "should raise error on bad service name" do
    require File.expand_path(File.dirname(__FILE__) + '/../test/bad_test_service')
    jconfig = config_dir + '/jerbil'
    options = {:log_dir => "/home/robert/dev/projects/jerbil/log", :log_level => :debug, :jerbil_config=>jconfig, :exit_on_stop=>false}
    lambda{BadTestService.new(options)}.should raise_error(Jerbil::InvalidService)
  end

  it "should raise error for no Jerbil Server" do
    jconfig = config_dir + '/jerbil'
    options = {:log_dir => "/home/robert/dev/projects/jerbil/log", :log_level => :debug, :jerbil_config=>jconfig, :exit_on_stop=>false}
    lambda{TestService.new(options)}.should raise_error(Jerbil::ServerConnectError)
  end


end