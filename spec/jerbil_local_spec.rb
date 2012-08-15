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
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'jerbil/servers'
require 'jerbil/service'
require 'jerbil/config'
require 'jerbil'
require 'jelly'


conf_file = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/jerbil_local.rb')


describe "A local Jerbil Session" do
  
  before(:all) do
    Jelly::Logger.disable_syslog
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
    @my_session.started.should be_true
    @my_session.registrations.should == 0
    @my_session.service_count.should == 0
    @my_session.local_service_count.should == 0
    @my_session.remote_service_count.should == 0
    @my_session.get_all.should == []
  end

  it "should be easy to add a service" do
    @my_session.register(@my_service)
    @my_session.registrations.should == 1
    @my_session.service_count.should == 1
    @my_session.local_service_count.should == 1
    @my_session.remote_service_count.should == 0
    services = @my_session.get_all(:ignore_access => true)
    services[0].should == @my_service
    service = @my_session.get_local(:ignore_access => true)
    service.should == @my_service
    @my_session.find(:name=>'Another', :ignore_access => true).should == []
    @my_session.remove(@my_service)
  end

  it "should not be possible to register the same service twice" do
    @my_service.should_receive(:connect).and_return(true) # make it appear the service is live
    @my_session.register(@my_service)
    lambda{@my_session.register(@my_service)}.should raise_error{Jerbil::ServiceAlreadyRegistered}
    @my_session.remove(@my_service)
  end

  it "should be easy to remove a service" do
    @my_session.register(@my_service)
    @my_session.remove(@my_service)
    @my_session.service_count.should == 0
  end

  it "should do nothing if you remove an unregistered service" do
    @my_session.register(@my_service)
    @my_session.remove(@a_service)
    @my_session.service_count.should == 1

  end


end
