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
require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))
require 'jerbil/servers'
require 'jerbil/service'
require 'jerbil/config'
require 'jerbil'
require 'jellog'


conf_file = File.expand_path(File.join(File.dirname(File.dirname(__FILE__)), 'test', 'conf.d','jerbil_local.rb'))


describe "A local Jerbil Session" do
  
  before(:all) do
    Jellog::Logger.disable_syslog
    @pkey = "ABCDEFG"
    my_conf = Jerbil::Config.new(conf_file)
    #puts my_conf.inspect
    @my_session = Jerbil::Broker.new(my_conf, @pkey)
  end

  before(:each) do

    @my_service = Jerbil::ServiceRecord.new(:rubytest, :dev)
    @a_service = Jerbil::ServiceRecord.new(:rubytest, :test)
  end

  after(:all) do
    @my_session.stop(@pkey)
  end

  it "should be easily created" do
    expect(@my_session.started).to be_kind_of(Time)
    expect(@my_session.registrations).to eq(0)
    expect(@my_session.service_count).to eq(0)
    expect(@my_session.local_service_count).to eq(0)
    expect(@my_session.remote_service_count).to eq(0)
    expect(@my_session.get_all).to eq([])
  end

  it "should be easy to add a service" do
    @my_session.register(@my_service)
    expect(@my_session.registrations).to eq(1)
    expect(@my_session.service_count).to eq(1)
    expect(@my_session.local_service_count).to eq(1)
    expect(@my_session.remote_service_count).to eq(0)
    services = @my_session.get_all(:ignore_access => true)
    expect(services[0]).to eq(@my_service)
    service = @my_session.get_local(:ignore_access => true)
    expect(service).to eq(@my_service)
    expect(@my_session.find(:name=>'Another', :ignore_access => true)).to eq([])
    @my_session.remove(@my_service)
  end

  it "should not be possible to register the same service twice" do
    allow(@my_service).to receive_messages(connect:true) # make it appear the service is live
    @my_session.register(@my_service)
    expect {@my_session.register(@my_service)}.to raise_error{Jerbil::ServiceAlreadyRegistered}
    @my_session.remove(@my_service)
  end

  it "should be easy to remove a service" do
    @my_session.register(@my_service)
    @my_session.remove(@my_service)
    expect(@my_session.service_count).to eq(0)
  end

  it "should do nothing if you remove an unregistered service" do
    @my_session.register(@my_service)
    @my_session.remove(@a_service)
    expect(@my_session.service_count).to eq(1)

  end


end
