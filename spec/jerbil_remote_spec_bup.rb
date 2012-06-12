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
require 'jerbil/servers'
require 'jerbil/service'
require 'jerbil/config'
require 'jerbil'
require 'socket'
require 'syslog'
require 'jelly'
require 'rspec/mocks/standalone'

conf_file = File.expand_path(File.dirname(__FILE__) + '/../test/conf.d/jerbil_local.rb')

log_dir = File.expand_path(File.dirname(__FILE__) + '/../log')
key_file = File.expand_path(File.dirname(__FILE__) + '/../test/private_key_file.asc')

describe "A Jerbil Session" do

  before(:all) do |variable|
    @calling_key = 'JKLMNOP'
    @third_key = 'GFHNBDUC'
    @pkey = '123456'
    @calling_server = Jerbil::Servers.new('germanicus.osburn-sharp.ath.cx', @calling_key, :dev, 49902)
    @third_server = Jerbil::Servers.new('antonia.osburn-sharp.ath.cx', @third_key, :dev, 49902)  
    @my_service = Jerbil::ServiceRecord.new(:rubytest, :dev)
    @my_conf = Jerbil::Config.new(conf_file)
    @secret = @my_conf[:secret]
    @env = @my_conf[:environment]

    @my_session = Jerbil::Broker.new(@my_conf, @pkey)

    @remote_host = 'germanicus.osburn-sharp.ath.cx'
    Socket.stub(:gethostname).and_return(@remote_host)
    @a_service = Jerbil::ServiceRecord.new(:rubytest, :test)
    Socket.stub(:gethostname).and_return('antonia.osburn-sharp.ath.cx')
    @b_service = Jerbil::ServiceRecord.new(:rubytest, :prod)
    Socket.unstub(:gethostname)
    Jelly::Logger.disable_syslog
  end

  after(:all) do
    @my_session.stop(@pkey)
  end

  it "should be easily created" do
    @my_session.service_count.should == 0
  end

  it "should be easy to add a remote service" do
    rkey = @my_session.register_server(@calling_server, @secret, @env)
    @my_session.register_remote(rkey, @a_service)
    @my_session.service_count.should == 1
    @my_session.remote_service_count.should == 1
    @my_session.detach_server(rkey, @calling_server)
    @my_session.service_count.should == 0
  end

  it "should not be possible to register a remote server without a valid secret" do
    #Syslog.should_not_receive(:info)
    lambda{@my_session.register_server(@calling_server, 'INVALID', @env)}.should raise_error{Jerbil::JerbilAuthenticationError}
  end

  it "should not be possible to register a remote service without a valid key" do
    rkey = @my_session.register_server(@calling_server, @secret, @env)
    lambda{@my_session.register_remote('INVALID', @a_service)}.should raise_error{Jerbil::InvalidServerKey}
    @my_session.detach_server(rkey, @calling_server)
  end


  it "should be easy to remove a remote service" do
    rkey = @my_session.register_server(@calling_server, @secret, @env)    
    @my_session.register_remote(rkey, @a_service)
    @my_session.service_count.should == 1
    @my_session.remove_remote(rkey, @a_service)
    @my_session.service_count.should == 0
    @my_session.detach_server(rkey, @calling_server)
  end

  it "should do nothing if you remove an unregistered remote service" do
    rkey = @my_session.register_server(@calling_server, @secret, @env)    
    @my_session.register(@my_service)
    @my_session.remove_remote(rkey, @a_service)
    @my_session.service_count.should == 1
    @my_session.detach_server(rkey, @calling_server)
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
