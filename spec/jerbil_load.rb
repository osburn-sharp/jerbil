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
require 'jerbil/server'
require 'jerbil/service'
require 'jerbil/config'
require 'jerbil'
require 'jellog'
require 'socket'
require 'syslog'
require 'drb'


config = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/jerbil.conf')

describe "Jerbil to Jerbil tests" do

  before(:all) do
    @options = Jerbil::Config.new(config)
    @servers = @options.delete(:servers)
    @env = @options[:environment]
    @local = Jerbil::ServerRecord.get_local_server(@servers, @env)

    @a_service = Jerbil::ServiceRecord.new(:rubytest, :test)
    @b_service = Jerbil::ServiceRecord.new(:rubytest, :prod)
    @remote_jerbil = @local.connect
    @remote_jerbil.register(@a_service)
    @remote_jerbil.register(@b_service)
  end

  it "should be easy to configure a live server" do
    @remote_jerbil.services.should == 2
  end


end
