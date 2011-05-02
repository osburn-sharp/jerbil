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
require 'jerbil/errors'
require 'jerbil/jerbil_service/base'
require 'jerbil'
require File.expand_path(File.dirname(__FILE__) + '/../test/test_service')
require 'socket'

config_dir = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/')
tconfig = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/test')

describe "Test Service Class for Errors (No Jerbil)" do

  before(:each) do
    @pkey = "ABCDEF"
    jerbil_test = get_test_jerbil
    Jerbil.stub(:get_local_server).and_return(jerbil_test)

  end


  it "should raise error on bad service name" do
    require File.expand_path(File.dirname(__FILE__) + '/../test/bad_test_service')
    jconfig = config_dir + '/jerbil'
    options = {:log_dir => "/home/robert/dev/projects/jerbil/log", :log_level => :debug, :jerbil_config=>jconfig, :exit_on_stop=>false}
    lambda{BadTestService.new(@pkey, options)}.should raise_error(Jerbil::InvalidService)
  end

  it "should raise error for no Jerbil Server" do
    jconfig = config_dir + '/jerbil'
    options = {:log_dir => "/home/robert/dev/projects/jerbil/log", :log_level => :debug, :jerbil_config=>jconfig, :exit_on_stop=>false}
    Jerbil.unstub(:get_local_server)
    lambda{TestService.new(@pkey, options)}.should raise_error(Jerbil::ServerConnectError)
  end


end

def get_test_jerbil
  config_file = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/jerbil.conf')
  config = Jerbil.get_config(config_file)
  return Jerbil.get_local_server(config)
end