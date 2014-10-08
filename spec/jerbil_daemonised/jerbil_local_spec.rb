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
# The purpose of these tests is to check the local interface to a Jerbil Broker only
# 
require 'rubygems'
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'rspec/mocks/standalone'
require 'jerbil/servers'
require 'jerbil/service'
require 'jerbil/config'
require 'jerbil'
require 'jellog'


conf_file = File.expand_path(File.dirname(__FILE__) + '/../../test/conf.d/jerbil_test.rb')


describe "A local Jerbil Session running under a daemon" do
  
  before(:all) do
    Jellog::Logger.disable_syslog
  end

  before(:each) do
    my_conf = Jerbil::Config.new(conf_file)
    test_server = Jerbil::Servers.get_local_server(my_conf[:environment])
    @my_session = test_server.connect
    @start_count = @my_session.service_count
    @registrations = @my_session.registrations
    @my_service = Jerbil::ServiceRecord.new(:rubytest, :dev)
    @a_service = Jerbil::ServiceRecord.new(:rubytest, :test)
  end


  it "should be easily created" do
    expect(@my_session.started).to be_kind_of(Time)
    expect(@my_session.registrations).to eq(@registrations)
    expect(@my_session.service_count).to eq(@start_count)
    expect(@my_session.get_all).to eq([])
  end

  it "should be easy to add a service" do
    @my_session.register(@my_service)
    expect(@my_session.registrations).to eq(@registrations + 1)
    expect(@my_session.service_count).to eq(@start_count + 1)
    services = @my_session.get_all(:ignore_access => true)
    expect(services[0]).to eq(@my_service)
    service = @my_session.get_local(:ignore_access => true)
    expect(service).to eq(@my_service)
    expect(@my_session.find(:name=>'Another', :ignore_access => true)).to eq([])
    @my_session.remove(@my_service)
  end

  # cannot stub on a live server so cannot test registration twice without a live service!

  it "should be easy to remove a service" do
    @my_session.register(@my_service)
    @my_session.remove(@my_service)
    expect(@my_session.service_count).to eq(@start_count)
  end

  it "should do nothing if you remove an unregistered service" do
    @my_session.register(@my_service)
    @my_session.remove(@a_service)
    expect(@my_session.service_count).to eq(@start_count + 1)
    @my_session.remove(@my_service)
  end


end
