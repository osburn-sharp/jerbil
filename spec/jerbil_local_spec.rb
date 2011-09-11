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
require 'jerbil'
require 'socket'
require 'syslog'

log_dir = File.expand_path(File.dirname(__FILE__) + '/../log')
key_file = File.expand_path(File.dirname(__FILE__) + '/../test/private_key_file.asc')

describe "A Jerbil Session" do

  before(:each) do
    me = Socket::gethostname
    my_server = Jerbil::ServerRecord.new(me, 'ABCDE', 49902)
    my_servers = [my_server]
    my_options = {:logdir=>log_dir, :level=>:debug, :environment=>:dev}
    pkey = "ABCDEFG"

    @my_session = Jerbil::Broker.new(my_server, my_servers, my_options, pkey)
    @my_service = Jerbil::ServiceRecord.new(:rubytest, :dev)
    @a_service = Jerbil::ServiceRecord.new(:rubytest, :test)
    @b_service = Jerbil::ServiceRecord.new(:rubytest, :prod)
  end

  after(:each) do
    @my_session.close
  end

  it "should be easily created" do
    @my_session.services.should == 0
  end

  it "should be easy to add a service" do
    Syslog.should_receive(:info).once.and_return(true)
    @my_session.register(@my_service)
    @my_session.services.should == 1
  end

  it "should not be possible to register the same service twice" do
    Syslog.should_receive(:info).once.and_return(true)
    @my_service.should_receive(:connect).and_return(true) # make it appear the service is live
    @my_session.register(@my_service)
    lambda{@my_session.register(@my_service)}.should raise_error{Jerbil::ServiceAlreadyRegistered}
  end

  it "should be easy to remove a service" do
    Syslog.should_receive(:info).exactly(2).times.and_return(true)
    @my_session.register(@my_service)
    @my_session.remove(@my_service)
    @my_session.services.should == 0
  end

  it "should do nothing if you remove an unregistered service" do
    Syslog.should_receive(:info).exactly(1).times.and_return(true)
    @my_session.register(@my_service)
    @my_session.remove(@a_service)
    @my_session.services.should == 1

  end

  describe "Services" do

    before(:each) do
      Syslog.should_receive(:info).exactly(3).times.and_return(true)
      @my_session.register(@my_service)
      @my_session.register(@a_service)
      @my_session.register(@b_service)
    end

    it "should be easy to add multiple services" do
      @my_session.services.should == 3
    end

    it "should be possible to find a service by name" do
      services = @my_session.find(:name=>:rubytest)
      services.length.should == 3
      services[0].should == @my_service
    end

    it "should be possible to find a service by pid" do
      services = @my_session.find(:env=>:prod)
      services.length.should == 1
      services[0].should == @b_service
    end

    it "should not be possible to find a service not registered" do
      services = @my_session.find(:name=>:Bilker)
      services.length.should == 0
    end

    it "should be possible to get a service in one go" do
      my_service = @my_session.get({:name=>:rubytest}, true)
      my_service.should be_a_kind_of(Jerbil::ServiceRecord)
      my_service.env.should == :dev

    end

  end
end
