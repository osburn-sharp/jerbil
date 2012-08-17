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
# The purpose of these tests is to check the remote interface to the Jerbil Server
# 

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'jerbil/servers'
require 'jerbil/service'
require 'jerbil/config'
require 'jerbil'
require 'socket'
require 'syslog'
require 'jelly'
require 'rspec/mocks/standalone'

conf_file = File.expand_path(File.dirname(__FILE__) + '/../../test/conf.d/jerbil_test.rb')


describe "A Remote Jerbil Session running under a daemon" do

  before(:all) do |variable|
    @calling_key = 'JKLMNOP'
    @third_key = 'GFHNBDUC'
    @pkey = '123456'
    @calling_server = Jerbil::Servers.new('germanicus.osburn-sharp.ath.cx', @calling_key, :test, 49902)
    @third_server = Jerbil::Servers.new('antonia.osburn-sharp.ath.cx', @third_key, :test, 49902)  
    @my_service = Jerbil::ServiceRecord.new(:rubytest, :dev)
    @another_service = Jerbil::ServiceRecord.new(:rubytest, :test)
    @my_conf = Jerbil::Config.new(conf_file)
    @secret = @my_conf[:secret]
    puts @secret
    @env = @my_conf[:environment]

    test_server = Jerbil::Servers.get_local_server(@my_conf[:environment])
    @my_session = test_server.connect

    @remote_host = 'germanicus.osburn-sharp.ath.cx'
    Socket.stub(:gethostname).and_return(@remote_host)
    @a_service = Jerbil::ServiceRecord.new(:rubytest, :test)
    Socket.stub(:gethostname).and_return('antonia.osburn-sharp.ath.cx')
    @b_service = Jerbil::ServiceRecord.new(:rubytest, :prod)
    Socket.unstub(:gethostname)
    Jelly::Logger.disable_syslog
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
    #lambda{@my_session.register_remote('INVALID', @a_service)}.should raise_error{Jerbil::InvalidServerKey}
    @my_session.register_remote('INVALID', @a_service)
    @my_session.service_count.should == 0
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
    @my_session.remove(@my_service)    
  end
  
  it "should return a locally registered service when asked" do
    @my_session.register(@my_service)
    rkey = @my_session.register_server(@calling_server, @secret, @env)    
    services = @my_session.get_local_services(rkey)
    services[0].should == @my_service
    @my_session.register(@another_service)
    @my_session.local_service_count.should == 2
    services.length.should == 1
    #@my_session.detach_server(rkey, @calling_server)
    @my_session.remove(@my_service)    
    @my_session.remove(@another_service)    
    
  end


end
