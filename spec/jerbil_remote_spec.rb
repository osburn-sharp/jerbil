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
require 'jelly'

log_dir = File.expand_path(File.dirname(__FILE__) + '/../log')
key_file = File.expand_path(File.dirname(__FILE__) + '/../test/private_key_file.asc')

describe "A Jerbil Session" do

  before(:each) do
    me = Socket::gethostname
    local_server = Jerbil::ServerRecord.new(me, 'ABCDE', :dev, 49902)
    @calling_key = 'JKLMNOP'
    @third_key = 'GFHNBDUC'
    @pkey = '123456'
    @calling_server = Jerbil::ServerRecord.new('germanicus.osburn-sharp.ath.cx', @calling_key, :dev, 49902)
    @third_server = Jerbil::ServerRecord.new('antonia.osburn-sharp.ath.cx', @third_key, :dev, 49902)
    my_servers = [local_server, @calling_server]#, @third_server]
    my_options = {:log_dir=>log_dir, :log_level=>:debug, :key_file=>key_file, :environment=>:dev}

    @my_session = Jerbil::Broker.new(local_server, my_servers, my_options, @pkey)
    @my_service = Jerbil::ServiceRecord.new(:rubytest, :dev)
    @remote_host = 'germanicus.osburn-sharp.ath.cx'
    Socket.stub(:gethostname).and_return(@remote_host)
    @a_service = Jerbil::ServiceRecord.new(:rubytest, :test)
    Socket.stub(:gethostname).and_return('antonia.osburn-sharp.ath.cx')
    @b_service = Jerbil::ServiceRecord.new(:rubytest, :prod)
    Socket.unstub(:gethostname)
    Jelly::Logger.disable_syslog
  end

  after(:each) do
    @my_session.close
  end

  it "should be easily created" do
    @my_session.services.should == 0
  end

  it "should be easy to add a remote service" do
    #Syslog.should_receive(:info).once.and_return(true)
    @my_session.register_remote(@calling_key, @my_service)
    @my_session.services.should == 1
  end

  it "should not be possible to register a remote service without a valid server key" do
    #Syslog.should_not_receive(:info)
    lambda{@my_session.register_remote('INVALID', @my_service)}.should raise_error{Jerbil::InvalidServerKey}
  end

  # it "should not be possible to register the same service twice" do
  #   #Syslog.should_receive(:info).once.and_return(true)
  #   @my_session.register_remote(@calling_key, @my_service)
  #   lambda{@my_session.register_remote(@calling_key, @my_service)}.should raise_error{Jerbil::ServiceAlreadyRegistered}
  # end

  it "should be easy to remove a remote service" do
    #Syslog.should_receive(:info).exactly(2).times.and_return(true)
    @my_session.register_remote(@calling_key, @my_service)
    @my_session.remove_remote(@calling_key, @my_service)
    @my_session.services.should == 0
  end

  it "should do nothing if you remove an unregistered remote service" do
    #Syslog.should_receive(:info).exactly(2).times.and_return(true)
    @my_session.register(@my_service)
    @my_session.remove_remote(@calling_key, @a_service)
    @my_session.services.should == 1

  end

  describe "Services" do

    before(:each) do
      #Syslog.should_receive(:info).exactly(3).times.and_return(true)
      @my_session.register(@my_service)
      @my_session.register_remote(@calling_key, @a_service)
      @my_session.register_remote(@calling_key, @b_service)
    end

    it "should be easy to add multiple services" do
      @my_session.services.should == 3
    end

    it "should be possible to find a service by name" do
      services = @my_session.find(:name=>:rubytest)
      services.length.should == 3
      services[0].should == @my_service
    end

    it "should be possible to find a service by env" do
      services = @my_session.find(:env=>:prod)
      services.length.should == 1
      services[0].should == @b_service
      services[0].host.should == 'antonia.osburn-sharp.ath.cx'
    end

    it "should be possible to find a service by env" do
      services = @my_session.find(:env=>:test)
      services.length.should == 1
      services[0].should == @a_service
      services[0].host.should == @remote_host
    end

    it "should not be possible to find a service not registered" do
      services = @my_session.find(:name=>:Bilker)
      services.length.should == 0
    end

    it "should be possible to get a service in one go" do
      my_service = @my_session.get({:name=>:rubytest, :env=>:prod}, true)
      my_service.should be_a_kind_of(Jerbil::ServiceRecord)
      my_service.env.should == :prod

    end
  end


  describe "remote server calls" do

    before(:each) do
      #Syslog.should_receive(:info).exactly(3).times.and_return(true)
      @my_session.register(@my_service)
      @my_session.register_remote(@calling_key, @a_service)
      @my_session.register_remote(@calling_key, @b_service)
    end

    it "should return all locally registered services" do
      local_services = @my_session.get_local_services(@calling_key)
      local_services.length.should == 1
    end

    it "should not be possible to get local services without a valid server key" do
      #Syslog.should_not_receive(:info)
      lambda{@my_session.get_local_services('INVALID')}.should raise_error{Jerbil::InvalidServerKey}
    end

  end

end
